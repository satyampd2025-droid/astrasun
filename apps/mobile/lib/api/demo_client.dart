import 'erpnext_client.dart';
import 'models.dart';

/// Stands in for the server so the app can be tried with no server at all.
/// Keeps orders in memory; each phone screen gets demo data here as it is built.
class DemoClient extends ErpNextClient {
  DemoClient(this.role) : super('demo');

  final String role;
  int _next = 4;

  static const _customers = [
    Customer('sharma', 'Sharma Kirana Store'),
    Customer('gupta', 'Gupta Traders'),
    Customer('verma', 'Verma Distributors'),
  ];
  static const _items = [
    CatalogItem('ATTA-5KG', 'Atta 5 kg', 230),
    CatalogItem('ATTA-10KG', 'Atta 10 kg', 440),
    CatalogItem('ATTA-26KG', 'Atta 26 kg', 1120),
    CatalogItem('ATTA-50KG', 'Atta 50 kg', 2150),
    CatalogItem('MAIDA-50KG', 'Maida 50 kg', 2300),
  ];

  late final List<Order> _orders = [
    Order(
      name: 'SAL-ORD-0001',
      customerName: 'Sharma Kirana Store',
      status: 'Pending Approval',
      total: 21500,
      creditOutstanding: 12000,
      creditLimit: 50000,
      creditExposure: 33500,
      items: [
        OrderItem(
          itemCode: 'ATTA-50KG',
          itemName: 'Atta 50 kg',
          qty: 10,
          rate: 2150,
        ),
      ],
    ),
    Order(
      name: 'SAL-ORD-0002',
      customerName: 'Verma Distributors',
      status: 'Pending Approval',
      total: 112000,
      creditOutstanding: 60000,
      creditLimit: 100000,
      creditExposure: 172000,
      creditBreach: true,
      items: [
        OrderItem(
          itemCode: 'ATTA-26KG',
          itemName: 'Atta 26 kg',
          qty: 100,
          rate: 1120,
        ),
      ],
    ),
    Order(
      name: 'SAL-ORD-0003',
      customerName: 'Gupta Traders',
      status: 'Pending Approval',
      total: 46000,
      creditLimit: 80000,
      creditExposure: 46000,
      stockShort: true,
      items: [
        OrderItem(
          itemCode: 'MAIDA-50KG',
          itemName: 'Maida 50 kg',
          qty: 20,
          rate: 2300,
        ),
      ],
    ),
  ];

  @override
  Future<Me> login(String user, String password) => me();

  @override
  Future<Me> me() async =>
      Me(user: 'demo', fullName: 'Demo', language: 'hi', millRoles: [role]);

  @override
  Future<Catalog> catalog() async =>
      const Catalog(customers: _customers, items: _items);

  @override
  Future<Order> createOrder(
    Customer customer,
    List<OrderLine> lines,
    String remarks,
  ) async {
    final total = lines.fold<double>(0, (sum, l) => sum + l.amount);
    final order = Order(
      name: 'SAL-ORD-${(_next++).toString().padLeft(4, '0')}',
      customerName: customer.displayName,
      status: 'Pending Approval',
      total: total,
      creditLimit: 50000,
      creditExposure: total,
      items: [
        for (final l in lines)
          OrderItem(
            itemCode: l.item.code,
            itemName: l.item.name,
            qty: l.qty.toDouble(),
            rate: l.rate,
          ),
      ],
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<List<Order>> myOrders() async => List.of(_orders);

  @override
  Future<List<Order>> pendingApprovals() async => [
    for (final o in _orders)
      if (o.status == 'Pending Approval') o,
  ];

  Order _set(String name, String status, [String? note]) {
    final i = _orders.indexWhere((o) => o.name == name);
    return _orders[i] = _orders[i].copyWith(status: status, note: note);
  }

  @override
  Future<Order> approve(String name) async {
    final done = _set(name, 'Approved');
    _loading.add(
      LoadingTask(
        id: done.name,
        salesOrder: done.name,
        customerName: done.customerName,
        status: 'Waiting',
        items: done.items,
      ),
    );
    return done;
  }

  final List<LoadingTask> _loading = [
    LoadingTask(
      id: 'SAL-ORD-0000',
      salesOrder: 'SAL-ORD-0000',
      customerName: 'Sharma Kirana Store',
      status: 'Waiting',
      items: [
        OrderItem(
          itemCode: 'ATTA-50KG',
          itemName: 'Atta 50 kg',
          qty: 40,
          rate: 0,
        ),
        OrderItem(
          itemCode: 'ATTA-10KG',
          itemName: 'Atta 10 kg',
          qty: 20,
          rate: 0,
        ),
      ],
    ),
  ];

  LoadingTask _setTask(String id, LoadingTask Function(LoadingTask) change) {
    final i = _loading.indexWhere((t) => t.id == id);
    return _loading[i] = change(_loading[i]);
  }

  @override
  Future<List<LoadingTask>> loadingQueue() async => [
    for (final t in _loading)
      if (t.status != 'Loaded') t,
  ];

  @override
  Future<LoadingTask> startLoading(LoadingTask task) async =>
      _setTask(task.id, (t) => t.copyWith(status: 'Loading'));

  @override
  Future<LoadingTask> markLoaded(
    LoadingTask task,
    String vehicleNo,
    Map<String, int> loaded,
  ) async => _setTask(
    task.id,
    (t) => t.copyWith(
      status: 'Loaded',
      vehicleNo: vehicleNo,
      items: [
        for (final i in t.items)
          if ((loaded[i.itemCode] ?? 0) > 0)
            OrderItem(
              itemCode: i.itemCode,
              itemName: i.itemName,
              qty: loaded[i.itemCode]!.toDouble(),
              rate: 0,
            ),
      ],
    ),
  );

  @override
  Future<Order> reject(String name, String reason) async =>
      _set(name, 'Rejected', reason);

  double _worth(List<OrderItem> items) => items.fold(0, (sum, i) {
    final rate = _items.firstWhere((c) => c.code == i.itemCode).rate;
    return sum + i.qty * rate;
  });

  @override
  Future<List<LoadingTask>> trucksToInvoice() async => [
    for (final t in _loading)
      if (t.status == 'Loaded' && t.invoice == null) t,
  ];

  @override
  Future<List<LoadingTask>> trucksToDispatch() async => [
    for (final t in _loading)
      if (t.status == 'Loaded' && t.invoice != null) t,
  ];

  @override
  Future<LoadingTask> invoiceTruck(LoadingTask task, String ewayBillNo) async {
    final total = _worth(task.items);
    if (total > 50000 && ewayBillNo.trim().isEmpty) throw Exception('eway');
    return _setTask(
      task.id,
      (t) => t.copyWith(
        invoice: 'SINV-${task.id.substring(task.id.length - 4)}',
        total: total,
        ewayNeeded: total > 50000,
        ewayBillNo: ewayBillNo.trim(),
      ),
    );
  }

  @override
  Future<LoadingTask> dispatchTruck(LoadingTask task) async =>
      _setTask(task.id, (t) => t.copyWith(status: 'Dispatched'));

  @override
  Future<List<LoadingTask>> myDeliveries() async => [
    for (final t in _loading)
      if (t.status == 'Dispatched') t,
  ];

  @override
  Future<LoadingTask> deliver(
    LoadingTask task,
    String receivedBy,
    String remarks,
  ) async {
    if (receivedBy.trim().isEmpty) throw Exception('receiver');
    return _setTask(task.id, (t) => t.copyWith(status: 'Delivered'));
  }

  final List<Due> _dues = [
    const Due(
      customer: 'verma',
      customerName: 'Verma Distributors',
      due: 60000,
      bills: 2,
      oldest: '2026-09-12',
    ),
    const Due(
      customer: 'sharma',
      customerName: 'Sharma Kirana Store',
      due: 12000,
      bills: 1,
      oldest: '2026-09-25',
    ),
  ];

  @override
  Future<List<Due>> dues() async => List.of(_dues);

  @override
  Future<Collected> collect(
    Due due,
    double amount,
    String mode,
    String reference,
  ) async {
    if (amount <= 0 || amount > due.due) throw Exception('amount');
    if (mode == 'Bank' && reference.trim().isEmpty) throw Exception('utr');
    final i = _dues.indexWhere((d) => d.customer == due.customer);
    final left = due.due - amount;
    if (left <= 0) {
      _dues.removeAt(i);
    } else {
      _dues[i] = Due(
        customer: due.customer,
        customerName: due.customerName,
        due: left,
        bills: due.bills,
        oldest: due.oldest,
      );
    }
    return Collected(amount, left);
  }

  @override
  Future<Order> sendBack(String name, String reason) async =>
      _set(name, 'Sent Back', reason);

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> logout() async {}
}
