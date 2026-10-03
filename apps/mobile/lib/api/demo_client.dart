import 'dart:typed_data';

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

  static const _ladder = [
    'Waiting for approval',
    'Approved',
    'Loading',
    'Loaded',
    'On the way',
    'Delivered',
    'Paid',
  ];

  /// The rows the server sends for an order standing at [step] (1 to 7).
  static List<TimelineRow> _rows(int step, String label) => [
    for (var i = 0; i < _ladder.length; i++)
      TimelineRow(
        i + 1 == step ? label : _ladder[i],
        i + 1 < step
            ? 'done'
            : i + 1 == step
            ? 'current'
            : 'todo',
      ),
  ];

  /// [order] moved to [step] of the ladder, in the words the server would use.
  static Order _at(
    Order order,
    int step, {
    String? label,
    String tone = 'go',
    String? status,
  }) {
    final word = label ?? _ladder[step - 1];
    return order.copyWith(
      status: status,
      stage: word,
      tone: tone,
      timeline: _rows(step, word),
    );
  }

  /// [order] taken off the ladder: rejected or sent back.
  static Order _off(Order order, String status, String reason, String tone) =>
      order.copyWith(
        status: status,
        note: reason,
        stage: status,
        tone: tone,
        timeline: const [],
      );

  late final List<Order> _orders = [
    Order(
      name: 'SAL-ORD-0001',
      customerName: 'Sharma Kirana Store',
      status: 'Pending Approval',
      timeline: _rows(1, _ladder[0]),
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
      timeline: _rows(1, _ladder[0]),
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
      timeline: _rows(1, _ladder[0]),
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
      timeline: _rows(1, _ladder[0]),
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
  Future<List<Order>> allOrders() async => [
    for (final o in _orders)
      if (o.status != 'Draft') o,
  ];

  @override
  Future<List<Order>> pendingApprovals() async => [
    for (final o in _orders)
      if (o.status == 'Pending Approval') o,
  ];

  Order _change(String name, Order Function(Order) change) {
    final i = _orders.indexWhere((o) => o.name == name);
    return _orders[i] = change(_orders[i]);
  }

  /// A truck of [salesOrder] moved on; the order follows it up the ladder.
  /// The demo's own first job has no order behind it, so it is left alone.
  void _follow(
    String salesOrder,
    int step, {
    String? label,
    String tone = 'go',
  }) {
    if (_orders.any((o) => o.name == salesOrder)) {
      _change(salesOrder, (o) => _at(o, step, label: label, tone: tone));
    }
  }

  @override
  Future<Order> approve(String name) async {
    final done = _change(name, (o) => _at(o, 2, status: 'Approved'));
    _loading.add(
      LoadingTask(
        id: done.name,
        salesOrder: done.name,
        customerName: done.customerName,
        status: 'Waiting',
        address: 'Main Bazaar, Indore',
        customerPhone: '9800000002',
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
      address: 'Shop 4, Main Bazaar, Indore',
      customerPhone: '9800000002',
      items: [
        OrderItem(
          itemCode: 'ATTA-50KG',
          itemName: 'Atta 50 kg',
          qty: 40,
          rate: 2150,
        ),
        OrderItem(
          itemCode: 'ATTA-10KG',
          itemName: 'Atta 10 kg',
          qty: 20,
          rate: 440,
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
      if (t.status == 'Waiting' ||
          t.status == 'Loading' ||
          t.status == 'Loaded')
        t,
  ];

  @override
  Future<LoadingTask> startLoading(LoadingTask task) async {
    _follow(task.salesOrder, 3);
    return _setTask(task.id, (t) => t.copyWith(status: 'Loading'));
  }

  final List<Vehicle> _vehicles = [
    const Vehicle(
      vehicleNo: 'MP09AB1234',
      driverName: 'Ramesh Driver',
      driverPhone: '9800000001',
      driverUser: 'ramesh',
    ),
    const Vehicle(
      vehicleNo: 'MP09CD5678',
      driverName: 'Suresh Kumar',
      driverPhone: '9800000003',
    ),
  ];

  @override
  Future<List<Vehicle>> vehicles({bool all = false}) async => [
    for (final v in _vehicles)
      if (all || v.enabled) v,
  ];

  @override
  Future<Vehicle> saveVehicle({
    required String vehicleNo,
    required String driverName,
    String? driverPhone,
    String? driverUser,
    bool enabled = true,
  }) async {
    final key = vehicleNo.replaceAll(RegExp(r'[\s-]+'), '').toUpperCase();
    if (key.isEmpty || driverName.trim().isEmpty) throw Exception('vehicle');
    final v = Vehicle(
      vehicleNo: key,
      driverName: driverName.trim(),
      driverPhone: driverPhone,
      driverUser: driverUser,
      enabled: enabled,
    );
    final i = _vehicles.indexWhere((x) => x.vehicleNo == key);
    if (i < 0) {
      _vehicles.add(v);
    } else {
      _vehicles[i] = v;
    }
    return v;
  }

  @override
  Future<LoadingTask> markLoaded(
    LoadingTask task,
    String vehicleNo,
    Map<String, int> loaded,
  ) async {
    final vehicle = _vehicles.firstWhere(
      (v) => v.enabled && v.vehicleNo == vehicleNo,
      orElse: () => throw Exception('vehicle'),
    );
    _follow(task.salesOrder, 4);
    return _setTask(
      task.id,
      (t) => t.copyWith(
        status: 'Loaded',
        vehicleNo: vehicle.vehicleNo,
        driverName: vehicle.driverName,
        driverPhone: vehicle.driverPhone,
        items: [
          for (final i in t.items)
            if ((loaded[i.itemCode] ?? 0) > 0)
              OrderItem(
                itemCode: i.itemCode,
                itemName: i.itemName,
                qty: loaded[i.itemCode]!.toDouble(),
                rate: i.rate,
              ),
        ],
      ),
    );
  }

  @override
  Future<Order> reject(String name, String reason) async =>
      _change(name, (o) => _off(o, 'Rejected', reason, 'stop'));

  double _worth(List<OrderItem> items) => items.fold(0, (sum, i) {
    final rate = _items.firstWhere((c) => c.code == i.itemCode).rate;
    return sum + i.qty * rate;
  });

  @override
  Future<List<LoadingTask>> trucksToInvoice() async => [
    for (final t in _loading)
      if (t.status == 'Loaded' && t.invoice == null && !t.changeRequested) t,
  ];

  @override
  Future<List<LoadingTask>> trucksToDispatch() async => [
    for (final t in _loading)
      if (t.status == 'Loaded' && t.invoice != null && !t.changeRequested) t,
  ];

  @override
  Future<LoadingTask> invoiceTruck(LoadingTask task) async {
    if (task.changeRequested) throw Exception('change waiting');
    return _setTask(
      task.id,
      (t) => t.copyWith(
        invoice: 'SINV-${task.id.substring(task.id.length - 4)}',
        total: _worth(t.items),
      ),
    );
  }

  /// A one-page PDF with the bill number, so the print screen has something to show.
  @override
  Future<Uint8List> billPdf(LoadingTask task) async => Uint8List.fromList(
    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
            '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
            '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\n'
            'trailer<</Root 1 0 R>>\n%%EOF'
        .codeUnits,
  );

  @override
  Future<LoadingTask> requestLoadChange(
    LoadingTask task,
    Map<String, int> bags,
    String reason,
  ) async {
    if (reason.trim().isEmpty) throw Exception('reason');
    return _setTask(
      task.id,
      (t) => LoadingTask(
        id: t.id,
        salesOrder: t.salesOrder,
        customerName: t.customerName,
        status: t.status,
        vehicleNo: t.vehicleNo,
        driverName: t.driverName,
        address: t.address,
        customerPhone: t.customerPhone,
        invoice: t.invoice,
        total: t.total,
        items: t.items,
        changeRequested: true,
        newItems: [
          for (final e in bags.entries)
            OrderItem(
              itemCode: e.key,
              itemName: e.key,
              qty: e.value.toDouble(),
              rate: 0,
            ),
        ],
        reason: reason.trim(),
        askedBy: 'warehouse',
      ),
    );
  }

  @override
  Future<List<LoadingTask>> loadChanges() async => [
    for (final t in _loading)
      if (t.changeRequested) t,
  ];

  @override
  Future<LoadingTask> decideLoadChange(
    LoadingTask task, {
    required bool approve,
  }) async => _setTask(task.id, (t) {
    final bags = {for (final i in t.newItems) i.itemCode: i.qty};
    final changed = LoadingTask(
      id: t.id,
      salesOrder: t.salesOrder,
      customerName: t.customerName,
      status: t.status,
      vehicleNo: t.vehicleNo,
      driverName: t.driverName,
      address: t.address,
      customerPhone: t.customerPhone,
      // Approving cancels the printed bill; the warehouse prints a new one
      invoice: approve ? null : t.invoice,
      total: approve ? 0 : t.total,
      items: approve
          ? [
              for (final i in t.items)
                if ((bags[i.itemCode] ?? 0) > 0)
                  OrderItem(
                    itemCode: i.itemCode,
                    itemName: i.itemName,
                    qty: bags[i.itemCode]!,
                    rate: i.rate,
                  ),
            ]
          : t.items,
    );
    return changed;
  });

  @override
  Future<LoadingTask> dispatchTruck(LoadingTask task) async {
    _follow(task.salesOrder, 5);
    return _setTask(task.id, (t) => t.copyWith(status: 'Dispatched'));
  }

  @override
  Future<List<LoadingTask>> myDeliveries() async => [
    for (final t in _loading)
      if (const ['Loading', 'Loaded', 'Dispatched'].contains(t.status) &&
          t.vehicleNo != null)
        t,
  ];

  @override
  Future<LoadingTask> deliver(
    LoadingTask task,
    String receivedBy,
    String remarks,
  ) async {
    if (receivedBy.trim().isEmpty) throw Exception('receiver');
    _follow(
      task.salesOrder,
      6,
      label: 'Delivered, payment pending',
      tone: 'warn',
    );
    return _setTask(task.id, (t) => t.copyWith(status: 'Delivered'));
  }

  /// Money collected on demo orders, and which of it the owner has settled.
  final List<Collection> _collections = [];
  int _collectionNo = 0;

  OrderMoney _moneyOn(String salesOrder, String customerName) {
    final truck = _loading.where((t) => t.salesOrder == salesOrder).firstOrNull;
    final billed = truck?.invoice == null ? 0.0 : _worth(truck!.items);
    final mine = _collections.where((c) => c.salesOrder == salesOrder);
    double sum(bool settled) => mine
        .where((c) => (c.status == 'Settled') == settled)
        .fold(0.0, (a, c) => a + c.amount);
    return OrderMoney(
      salesOrder: salesOrder,
      customerName: customerName,
      billed: billed,
      paid: sum(true),
      withCollector: sum(false),
      remaining: billed - sum(true) - sum(false),
    );
  }

  @override
  Future<Collection> collectOnOrder(
    String salesOrder,
    double amount,
    String mode,
    String reference,
  ) async {
    final truck = _loading.firstWhere(
      (t) => t.salesOrder == salesOrder,
      orElse: () => throw Exception('order'),
    );
    final left = _moneyOn(salesOrder, truck.customerName).remaining;
    if (amount <= 0 || amount > left) throw Exception('amount');
    if (mode == 'Bank' && reference.trim().isEmpty) throw Exception('utr');
    final office = role == 'Mill Owner' || role == 'Mill Accounts';
    final c = Collection(
      name: 'COL-${++_collectionNo}',
      salesOrder: salesOrder,
      customerName: truck.customerName,
      amount: amount,
      mode: mode,
      status: office ? 'Settled' : 'Collected',
      collectedByName: 'You',
    );
    _collections.add(c);
    return c;
  }

  @override
  Future<MyCollections> myCollections() async {
    final held = [
      for (final c in _collections)
        if (c.status == 'Collected') c,
    ];
    final orders = [
      for (final t in _loading)
        if (t.invoice != null) _moneyOn(t.salesOrder, t.customerName),
    ].where((o) => o.remaining > 0 || o.withCollector > 0).toList();
    return MyCollections(
      holding: held.fold(0.0, (a, c) => a + c.amount),
      collections: held,
      orders: orders,
    );
  }

  @override
  Future<List<CashHolder>> cashToSettle() async {
    final held = [
      for (final c in _collections)
        if (c.status == 'Collected') c,
    ];
    if (held.isEmpty) return [];
    return [
      CashHolder(
        name: 'Rep',
        total: held.fold(0.0, (a, c) => a + c.amount),
        collections: held,
      ),
    ];
  }

  @override
  Future<void> settleCash(List<String> names) async {
    for (var i = 0; i < _collections.length; i++) {
      final c = _collections[i];
      if (names.contains(c.name)) {
        _collections[i] = Collection(
          name: c.name,
          salesOrder: c.salesOrder,
          customerName: c.customerName,
          amount: c.amount,
          mode: c.mode,
          status: 'Settled',
          collectedByName: c.collectedByName,
        );
      }
    }
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
      _change(name, (o) => _off(o, 'Sent Back', reason, 'warn'));

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> logout() async {}
}
