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
      belowPrice: true,
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

  static const _suppliers = [
    Customer('mandi1', 'Ram Lal Mandi Traders'),
    Customer('farmer1', 'Kisan Agro Supplies'),
  ];
  final List<WheatTruck> _wheat = [
    const WheatTruck(
      name: 'WL-26-0001',
      supplierName: 'Ram Lal Mandi Traders',
      vehicleNo: 'MP04AB9999',
      status: 'Weighed In',
      partyWeightKg: 20000,
      grossKg: 28000,
    ),
  ];

  @override
  Future<List<Customer>> suppliers() async => _suppliers;

  @override
  Future<List<WheatTruck>> wheatTrucks() async => [
    for (final t in _wheat)
      if (t.status != 'Received' && t.status != 'Rejected') t,
  ];

  @override
  Future<WheatTruck> gateIn(
    Customer supplier,
    String vehicleNo,
    double slipKg,
    double ratePerQuintal,
  ) async {
    if (vehicleNo.trim().isEmpty || slipKg <= 0 || ratePerQuintal <= 0) {
      throw Exception('gate');
    }
    final truck = WheatTruck(
      name: 'WL-26-${(_wheat.length + 1).toString().padLeft(4, '0')}',
      supplierName: supplier.displayName,
      vehicleNo: vehicleNo.trim().toUpperCase(),
      status: 'At Gate',
      partyWeightKg: slipKg,
    );
    _wheat.add(truck);
    return truck;
  }

  WheatTruck _setWheat(String name, WheatTruck Function(WheatTruck) change) {
    final i = _wheat.indexWhere((t) => t.name == name);
    return _wheat[i] = change(_wheat[i]);
  }

  @override
  Future<WheatTruck> weighIn(WheatTruck t, double grossKg) async {
    if (grossKg <= 0) throw Exception('gross');
    return _setWheat(
      t.name,
      (x) => x.copyWith(status: 'Weighed In', grossKg: grossKg),
    );
  }

  @override
  Future<WheatTruck> checkWheat(
    WheatTruck t, {
    required double moisture,
    required double foreignMatter,
    required double broken,
    required String decision,
    String remarks = '',
  }) async {
    final bad = moisture > 14 || foreignMatter > 2;
    // The lab alone cannot release wheat that is over the limits
    if (decision == 'Release' && bad && role == 'Mill QC') {
      throw Exception('limits');
    }
    if (decision != 'Release' && remarks.trim().isEmpty) {
      throw Exception('reason');
    }
    return _setWheat(
      t.name,
      (x) => x.copyWith(
        status: {
          'Release': 'Released',
          'Hold': 'On Hold',
          'Reject': 'Rejected',
        }[decision],
        moisture: moisture,
        foreignMatter: foreignMatter,
        broken: broken,
      ),
    );
  }

  @override
  Future<WheatTruck> weighOut(WheatTruck t, double tareKg) async {
    final x = _wheat.firstWhere((w) => w.name == t.name);
    if (tareKg <= 0 || tareKg >= x.grossKg) throw Exception('tare');
    final net = x.grossKg - tareKg;
    final gap = net - x.partyWeightKg;
    return _setWheat(
      t.name,
      (w) => w.copyWith(
        status: 'Received',
        netKg: net,
        weightGapKg: gap,
        weightAlert: gap.abs() / w.partyWeightKg * 100 > 0.5,
      ),
    );
  }

  double _wheatStock = 85000;
  final Map<String, double> _bulk = {
    'ATTA-BULK': 12000,
    'MAIDA-BULK': 2500,
    'SOOJI-BULK': 800,
    'CHOKAR-BULK': 3000,
  };

  @override
  Future<double> wheatAvailable() async => _wheatStock;

  @override
  Future<MillResult> recordBatch({
    required String shift,
    required double wheatKg,
    required double waterKg,
    required double attaKg,
    required double maidaKg,
    required double soojiKg,
    required double chokarKg,
  }) async {
    final out = attaKg + maidaKg + soojiKg + chokarKg;
    if (wheatKg <= 0 || out <= 0 || out > wheatKg * 1.05) {
      throw Exception('numbers');
    }
    if (wheatKg > _wheatStock) throw Exception('stock');
    _wheatStock -= wheatKg;
    _bulk['ATTA-BULK'] = _bulk['ATTA-BULK']! + attaKg;
    _bulk['MAIDA-BULK'] = _bulk['MAIDA-BULK']! + maidaKg;
    _bulk['SOOJI-BULK'] = _bulk['SOOJI-BULK']! + soojiKg;
    _bulk['CHOKAR-BULK'] = _bulk['CHOKAR-BULK']! + chokarKg;
    final flour = attaKg + maidaKg + soojiKg;
    final loss = wheatKg > out ? wheatKg - out : 0.0;
    final extraction = flour / wheatKg * 100;
    return MillResult(
      extractionPct: extraction,
      lossKg: loss,
      lowYield: extraction < 78 || loss / wheatKg * 100 > 2,
    );
  }

  final List<String> downtimes = [];

  @override
  Future<void> reportDowntime(
    String machine,
    int minutes,
    String reason,
  ) async {
    if (machine.trim().isEmpty || minutes <= 0 || reason.trim().isEmpty) {
      throw Exception('downtime');
    }
    downtimes.add('$machine $minutes');
  }

  final Map<String, PackSku> _skus = {
    'ATTA-10KG': const PackSku(
      code: 'ATTA-10KG',
      name: 'Atta 10 kg',
      kg: 10,
      bulkKg: 0,
      emptyBags: 600,
      packedBags: 120,
    ),
    'ATTA-50KG': const PackSku(
      code: 'ATTA-50KG',
      name: 'Atta 50 kg',
      kg: 50,
      bulkKg: 0,
      emptyBags: 300,
      packedBags: 80,
    ),
  };

  @override
  Future<List<PackSku>> packSkus() async => [
    for (final s in _skus.values)
      PackSku(
        code: s.code,
        name: s.name,
        kg: s.kg,
        bulkKg: _bulk['ATTA-BULK']!,
        emptyBags: s.emptyBags,
        packedBags: s.packedBags,
      ),
  ];

  @override
  Future<void> pack(PackSku sku, int bags) async {
    final s = _skus[sku.code]!;
    if (bags <= 0 || bags > sku.canPack) throw Exception('pack');
    _bulk['ATTA-BULK'] = _bulk['ATTA-BULK']! - bags * s.kg;
    _skus[sku.code] = PackSku(
      code: s.code,
      name: s.name,
      kg: s.kg,
      bulkKg: 0,
      emptyBags: s.emptyBags - bags,
      packedBags: s.packedBags + bags,
    );
  }

  @override
  Future<List<StockRow>> stock() async => [
    StockRow('WHEAT', 'Wheat', _wheatStock, 'kg', 'Raw'),
    StockRow('ATTA-BULK', 'Atta (bulk)', _bulk['ATTA-BULK']!, 'kg', 'Bulk'),
    StockRow('MAIDA-BULK', 'Maida (bulk)', _bulk['MAIDA-BULK']!, 'kg', 'Bulk'),
    StockRow('SOOJI-BULK', 'Sooji (bulk)', _bulk['SOOJI-BULK']!, 'kg', 'Bulk'),
    StockRow(
      'CHOKAR-BULK',
      'Chokar (bulk)',
      _bulk['CHOKAR-BULK']!,
      'kg',
      'Bulk',
    ),
    for (final s in _skus.values)
      StockRow(s.code, s.name, s.packedBags, 'bags', 'Packed'),
  ];

  @override
  Future<DayView> today() async => DayView(
    salesBooked: 186500,
    invoiced: 94800,
    collected: 40000,
    duesTotal: _dues.fold<double>(0, (a, d) => a + d.due),
    ageing: const {'0-30': 52000, '31-60': 20000, '61+': 0},
    pendingApprovals: _orders
        .where((o) => o.status == 'Pending Approval')
        .length,
    trucksInYard: _wheat.where((t) => t.status != 'Received').length,
    trucksToDispatch: _loading.where((t) => t.status == 'Loaded').length,
    wheatGroundKg: 16000,
    flourMadeKg: 13600,
    extractionPct: 85,
    downtimeMin: 45,
    alerts: const [
      MillAlert('weight', 'MP04AB9999 Ram Lal Mandi Traders: -300 kg (1.5%)'),
      MillAlert('yield', 'Night shift: extraction 72.0%, loss 20 kg'),
      MillAlert(
        'credit',
        'Verma Distributors: order of 112,000 is over the credit limit',
      ),
    ],
  );

  @override
  Future<Pnl> profitAndLoss() async => const Pnl(
    from: '2026-10-01',
    to: '2026-10-31',
    sales: 486000,
    cost: 412000,
    profit: 74000,
    marginPct: 15.2,
    collected: 310000,
  );

  @override
  Future<StockReport> stockStatement() async => StockReport(const [
    StockLine('WHEAT', 60000, 40000, 15000, 85000),
    StockLine('ATTA-BULK', 8000, 10500, 6500, 12000),
    StockLine('ATTA-10KG', 100, 300, 280, 120),
  ], true);

  @override
  Future<Order> sendBack(String name, String reason) async =>
      _set(name, 'Sent Back', reason);

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> logout() async {}
}
