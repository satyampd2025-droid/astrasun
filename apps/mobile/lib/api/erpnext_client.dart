import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class LoginFailed implements Exception {}

class ServerUnreachable implements Exception {}

/// Who is logged in, from astrasun.api.me.
class Me {
  Me({
    required this.user,
    required this.fullName,
    required this.language,
    required this.millRoles,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    user: json['user'] as String,
    fullName: (json['full_name'] as String?) ?? json['user'] as String,
    language: (json['language'] as String?) ?? 'en',
    millRoles: List<String>.from(json['mill_roles'] as List? ?? const []),
  );

  final String user;
  final String fullName;
  final String language;
  final List<String> millRoles;
}

/// Talks to ERPNext over its REST API with a session cookie.
class ErpNextClient {
  ErpNextClient(String baseUrl, {http.Client? httpClient})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _sid;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    // In a browser the cookie is sent by the browser itself.
    if (!kIsWeb && _sid != null) 'Cookie': 'sid=$_sid',
  };

  Future<http.Response> _post(String method, Map<String, dynamic> body) async {
    try {
      return await _http.post(
        Uri.parse('$baseUrl/api/method/$method'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } on Exception {
      throw ServerUnreachable();
    }
  }

  Future<Me> login(String user, String password) async {
    final res = await _post('login', {'usr': user, 'pwd': password});
    if (res.statusCode == 401) throw LoginFailed();
    if (res.statusCode != 200) throw ServerUnreachable();
    final cookie = res.headers['set-cookie'];
    final match = cookie == null
        ? null
        : RegExp(r'sid=([^;]+)').firstMatch(cookie);
    _sid = match?.group(1);
    return me();
  }

  Future<Me> me() async {
    final res = await _post('astrasun.api.me', {});
    if (res.statusCode == 401 || res.statusCode == 403) throw LoginFailed();
    if (res.statusCode != 200) throw ServerUnreachable();
    return Me.fromJson(jsonDecode(res.body)['message'] as Map<String, dynamic>);
  }

  dynamic _message(http.Response res) {
    if (res.statusCode == 403) throw LoginFailed();
    if (res.statusCode != 200) throw ServerUnreachable();
    return jsonDecode(res.body)['message'];
  }

  Future<Catalog> catalog() async {
    final m = _message(await _post('astrasun.orders.catalog', {}));
    return Catalog(
      customers: [
        for (final c in m['customers'] as List)
          Customer(c['name'] as String, c['customer_name'] as String),
      ],
      items: [
        for (final i in m['items'] as List)
          CatalogItem(
            i['item_code'] as String,
            i['item_name'] as String,
            (i['rate'] as num).toDouble(),
          ),
      ],
    );
  }

  Future<Order> createOrder(
    Customer customer,
    List<OrderLine> lines,
    String remarks,
  ) async {
    final res = await _post('astrasun.orders.create_order', {
      'customer': customer.name,
      'items': [
        for (final l in lines)
          {'item_code': l.item.code, 'qty': l.qty, 'rate': l.rate},
      ],
      'remarks': remarks,
    });
    return Order.fromJson(_message(res) as Map<String, dynamic>);
  }

  Future<List<Order>> myOrders() async =>
      _orders(_message(await _post('astrasun.orders.my_orders', {})));

  Future<List<Order>> pendingApprovals() async =>
      _orders(_message(await _post('astrasun.orders.pending_approvals', {})));

  List<Order> _orders(dynamic list) => [
    for (final o in list as List) Order.fromJson(o as Map<String, dynamic>),
  ];

  Future<Order> approve(String name) async => Order.fromJson(
    _message(await _post('astrasun.orders.approve', {'name': name}))
        as Map<String, dynamic>,
  );

  Future<Order> reject(String name, String reason) async => Order.fromJson(
    _message(
          await _post('astrasun.orders.reject', {
            'name': name,
            'reason': reason,
          }),
        )
        as Map<String, dynamic>,
  );

  Future<Order> sendBack(String name, String reason) async => Order.fromJson(
    _message(
          await _post('astrasun.orders.send_back', {
            'name': name,
            'reason': reason,
          }),
        )
        as Map<String, dynamic>,
  );

  Future<List<LoadingTask>> loadingQueue() async {
    final m = _message(await _post('astrasun.loading.queue', {}));
    return [
      for (final t in [...m['loading'] as List, ...m['waiting'] as List])
        LoadingTask.fromJson(t as Map<String, dynamic>),
    ];
  }

  Future<LoadingTask> startLoading(LoadingTask task) async =>
      LoadingTask.fromJson(
        _message(
              await _post('astrasun.loading.start', {
                'sales_order': task.salesOrder,
              }),
            )
            as Map<String, dynamic>,
      );

  /// [loaded] maps item code to the bags actually put on the truck.
  Future<LoadingTask> markLoaded(
    LoadingTask task,
    String vehicleNo,
    Map<String, int> loaded,
  ) async => LoadingTask.fromJson(
    _message(
          await _post('astrasun.loading.mark_loaded', {
            'name': task.id,
            'vehicle_no': vehicleNo,
            'items': [
              for (final e in loaded.entries)
                {'item_code': e.key, 'qty': e.value},
            ],
          }),
        )
        as Map<String, dynamic>,
  );

  List<LoadingTask> _trucks(dynamic list) => [
    for (final t in list as List)
      LoadingTask.fromJson(t as Map<String, dynamic>),
  ];

  /// Loaded trucks with no bill yet.
  Future<List<LoadingTask>> trucksToInvoice() async =>
      _trucks(_message(await _post('astrasun.invoicing.to_invoice', {})));

  /// Billed trucks that have not left.
  Future<List<LoadingTask>> trucksToDispatch() async =>
      _trucks(_message(await _post('astrasun.invoicing.to_dispatch', {})));

  Future<LoadingTask> invoiceTruck(LoadingTask task, String ewayBillNo) async =>
      LoadingTask.fromJson(
        _message(
              await _post('astrasun.invoicing.invoice', {
                'name': task.id,
                'eway_bill_no': ewayBillNo,
              }),
            )
            as Map<String, dynamic>,
      );

  Future<LoadingTask> dispatchTruck(LoadingTask task) async =>
      LoadingTask.fromJson(
        _message(await _post('astrasun.invoicing.dispatch', {'name': task.id}))
            as Map<String, dynamic>,
      );

  Future<void> setLanguage(String language) async {
    await _post('astrasun.api.set_language', {'language': language});
  }

  Future<void> logout() async {
    await _post('logout', {});
    _sid = null;
  }
}
