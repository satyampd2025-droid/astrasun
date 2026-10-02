import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class LoginFailed implements Exception {}

class ServerUnreachable implements Exception {}

/// The server understood the request and refused it, with its own reason
/// (for example "Please enter Delivery Date"). Screens show the reason as it is.
class ServerRefused implements Exception {
  ServerRefused(this.reason);
  final String reason;

  @override
  String toString() => 'ServerRefused: $reason';
}

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
    if (res.statusCode != 200) throw _refusal(res) ?? ServerUnreachable();
    return jsonDecode(res.body)['message'];
  }

  /// The server's own words from a failed answer, or null when it gave none
  /// (a proxy error page, a timeout).
  ServerRefused? _refusal(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['_server_messages'];
      for (final item in raw is String ? jsonDecode(raw) as List : const []) {
        final message = (item is String ? jsonDecode(item) : item)['message'];
        if (message is String && _plain(message).isNotEmpty) {
          return ServerRefused(_plain(message));
        }
      }
      final exception = body['exception'];
      if (exception is String && _plain(exception).isNotEmpty) {
        return ServerRefused(_plain(exception.split('\n').first));
      }
    } on Object {
      // not the server's JSON; fall through
    }
    return null;
  }

  /// Frappe messages carry a little HTML (bold names, line breaks) and, for
  /// uncaught errors, the Python exception path in front of the text.
  static String _plain(String text) => text
      .replaceAll(RegExp(r'<br\s*/?>'), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceFirst(RegExp(r'^[\w.]+(Error|Exception): '), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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

  Future<List<LoadingTask>> myDeliveries() async =>
      _trucks(_message(await _post('astrasun.delivery.my_deliveries', {})));

  Future<LoadingTask> deliver(
    LoadingTask task,
    String receivedBy,
    String remarks,
  ) async => LoadingTask.fromJson(
    _message(
          await _post('astrasun.delivery.deliver', {
            'name': task.id,
            'received_by': receivedBy,
            'remarks': remarks,
          }),
        )
        as Map<String, dynamic>,
  );

  Future<List<Due>> dues() async => [
    for (final d in _message(await _post('astrasun.payments.dues', {})) as List)
      Due.fromJson(d as Map<String, dynamic>),
  ];

  /// Money is matched to the customer's oldest bills first on the server.
  Future<Collected> collect(
    Due due,
    double amount,
    String mode,
    String reference,
  ) async {
    final m =
        _message(
              await _post('astrasun.payments.collect', {
                'customer': due.customer,
                'amount': amount,
                'mode': mode,
                'reference': reference,
              }),
            )
            as Map<String, dynamic>;
    return Collected(
      (m['amount'] as num).toDouble(),
      (m['still_due'] as num).toDouble(),
    );
  }

  WheatTruck _truck(dynamic j) =>
      WheatTruck.fromJson(_message(j) as Map<String, dynamic>);

  Future<List<Customer>> suppliers() async => [
    for (final c
        in _message(await _post('astrasun.wheat.suppliers', {})) as List)
      Customer(c['name'] as String, c['supplier_name'] as String),
  ];

  Future<List<WheatTruck>> wheatTrucks() async => [
    for (final t in _message(await _post('astrasun.wheat.trucks', {})) as List)
      WheatTruck.fromJson(t as Map<String, dynamic>),
  ];

  Future<WheatTruck> gateIn(
    Customer supplier,
    String vehicleNo,
    double slipKg,
    double ratePerQuintal,
  ) async => _truck(
    await _post('astrasun.wheat.gate_in', {
      'supplier': supplier.name,
      'vehicle_no': vehicleNo,
      'party_weight_kg': slipKg,
      'rate_per_quintal': ratePerQuintal,
    }),
  );

  Future<WheatTruck> weighIn(WheatTruck t, double grossKg) async => _truck(
    await _post('astrasun.wheat.weigh_in', {
      'name': t.name,
      'gross_kg': grossKg,
    }),
  );

  /// [decision] is Release, Hold or Reject.
  Future<WheatTruck> checkWheat(
    WheatTruck t, {
    required double moisture,
    required double foreignMatter,
    required double broken,
    required String decision,
    String remarks = '',
  }) async => _truck(
    await _post('astrasun.wheat.check', {
      'name': t.name,
      'moisture_pct': moisture,
      'foreign_matter_pct': foreignMatter,
      'broken_pct': broken,
      'decision': decision,
      'remarks': remarks,
    }),
  );

  Future<WheatTruck> weighOut(WheatTruck t, double tareKg) async => _truck(
    await _post('astrasun.wheat.weigh_out', {
      'name': t.name,
      'tare_kg': tareKg,
    }),
  );

  Future<double> wheatAvailable() async =>
      (_message(await _post('astrasun.milling.wheat_available', {})) as num)
          .toDouble();

  Future<MillResult> recordBatch({
    required String shift,
    required double wheatKg,
    required double waterKg,
    required double attaKg,
    required double maidaKg,
    required double soojiKg,
    required double chokarKg,
  }) async {
    final m =
        _message(
              await _post('astrasun.milling.record_batch', {
                'shift': shift,
                'wheat_kg': wheatKg,
                'water_kg': waterKg,
                'atta_kg': attaKg,
                'maida_kg': maidaKg,
                'sooji_kg': soojiKg,
                'chokar_kg': chokarKg,
              }),
            )
            as Map<String, dynamic>;
    return MillResult(
      extractionPct: (m['extraction_pct'] as num).toDouble(),
      lossKg: (m['loss_kg'] as num).toDouble(),
      lowYield: m['low_yield'] as bool,
    );
  }

  Future<void> reportDowntime(
    String machine,
    int minutes,
    String reason,
  ) async {
    _message(
      await _post('astrasun.milling.report_downtime', {
        'machine': machine,
        'minutes': minutes,
        'reason': reason,
      }),
    );
  }

  Future<List<PackSku>> packSkus() async => [
    for (final j in _message(await _post('astrasun.packing.skus', {})) as List)
      PackSku.fromJson(j as Map<String, dynamic>),
  ];

  Future<void> pack(PackSku sku, int bags) async {
    _message(
      await _post('astrasun.packing.pack', {
        'item_code': sku.code,
        'bags': bags,
      }),
    );
  }

  Future<List<StockRow>> stock() async => [
    for (final j in _message(await _post('astrasun.packing.stock', {})) as List)
      StockRow.fromJson(j as Map<String, dynamic>),
  ];

  Future<DayView> today() async => DayView.fromJson(
    _message(await _post('astrasun.dashboard.today', {}))
        as Map<String, dynamic>,
  );

  Future<Pnl> profitAndLoss() async => Pnl.fromJson(
    _message(await _post('astrasun.reports.profit_and_loss', {}))
        as Map<String, dynamic>,
  );

  Future<StockReport> stockStatement() async => StockReport.fromJson(
    _message(await _post('astrasun.reports.stock_statement', {}))
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
