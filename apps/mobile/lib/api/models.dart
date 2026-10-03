/// Plain data the screens show. Built from the server's JSON.
class OrderItem {
  OrderItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    itemCode: j['item_code'] as String,
    itemName: (j['item_name'] as String?) ?? j['item_code'] as String,
    qty: (j['qty'] as num).toDouble(),
    rate: (j['rate'] as num).toDouble(),
  );

  final String itemCode;
  final String itemName;
  final double qty;
  final double rate;
}

/// One row of an order's timeline. [state] is done, current or todo.
class TimelineRow {
  const TimelineRow(this.label, this.state);

  factory TimelineRow.fromJson(Map<String, dynamic> j) =>
      TimelineRow(j['label'] as String, j['state'] as String);

  final String label;
  final String state;
}

class Order {
  /// [stage], [tone] and [timeline] come from the server. A server that sends
  /// none still gets a sensible stage and colour from the approval [status].
  Order({
    required this.name,
    required this.customerName,
    required this.status,
    required this.total,
    required this.items,
    String? stage,
    String? tone,
    this.timeline = const [],
    this.note,
    this.creditOutstanding = 0,
    this.creditLimit = 0,
    this.creditExposure = 0,
    this.creditBreach = false,
    this.stockShort = false,
    this.belowPrice = false,
    this.billed = 0,
    this.paid = 0,
    this.withCollector = 0,
    this.remaining = 0,
  }) : stage =
           stage ??
           (status == 'Pending Approval' ? 'Waiting for approval' : status),
       tone = tone ?? _toneOf(status);

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    name: j['name'] as String,
    customerName: (j['customer_name'] as String?) ?? j['customer'] as String,
    status: j['status'] as String,
    stage: j['stage'] as String?,
    tone: j['tone'] as String?,
    timeline: [
      for (final r in (j['timeline'] as List?) ?? const [])
        TimelineRow.fromJson(r as Map<String, dynamic>),
    ],
    total: (j['total'] as num).toDouble(),
    note: j['note'] as String?,
    creditOutstanding: (j['credit_outstanding'] as num? ?? 0).toDouble(),
    creditLimit: (j['credit_limit'] as num? ?? 0).toDouble(),
    creditExposure: (j['credit_exposure'] as num? ?? 0).toDouble(),
    creditBreach: j['credit_breach'] as bool? ?? false,
    stockShort: j['stock_short'] as bool? ?? false,
    belowPrice: j['below_min_price'] as bool? ?? false,
    billed: (j['billed'] as num? ?? 0).toDouble(),
    paid: (j['paid'] as num? ?? 0).toDouble(),
    withCollector: (j['with_collector'] as num? ?? 0).toDouble(),
    remaining: (j['remaining'] as num? ?? 0).toDouble(),
    items: [
      for (final i in j['items'] as List)
        OrderItem.fromJson(i as Map<String, dynamic>),
    ],
  );

  static String _toneOf(String status) => switch (status) {
    'Approved' => 'go',
    'Rejected' => 'stop',
    'Sent Back' => 'warn',
    _ => 'wait',
  };

  final String name;
  final String customerName;

  /// The approval status: Draft, Pending Approval, Approved, Rejected or Sent Back.
  final String status;

  /// Where the order stands, in the words every screen uses (Waiting for
  /// approval, Loading, On the way, Part paid, Paid ...).
  final String stage;

  /// How to colour the stage: wait, go, warn, done or stop.
  final String tone;

  /// The steps of the order's ladder; empty for an order that is not on it.
  final List<TimelineRow> timeline;
  final double total;
  final String? note;
  final double creditOutstanding;
  final double creditLimit;
  final double creditExposure;
  final bool creditBreach;
  final bool stockShort;
  final bool belowPrice;

  /// Money on the order once it is billed: what was billed, what is paid and
  /// handed in, what a rep or driver has collected but not handed in, and what is left.
  final double billed;
  final double paid;
  final double withCollector;
  final double remaining;
  final List<OrderItem> items;

  Order copyWith({
    String? status,
    String? note,
    String? stage,
    String? tone,
    List<TimelineRow>? timeline,
  }) => Order(
    name: name,
    customerName: customerName,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    tone: tone ?? this.tone,
    timeline: timeline ?? this.timeline,
    total: total,
    items: items,
    note: note ?? this.note,
    creditOutstanding: creditOutstanding,
    creditLimit: creditLimit,
    creditExposure: creditExposure,
    creditBreach: creditBreach,
    stockShort: stockShort,
    belowPrice: belowPrice,
    billed: billed,
    paid: paid,
    withCollector: withCollector,
    remaining: remaining,
  );
}

class Customer {
  const Customer(this.name, this.displayName);
  final String name;
  final String displayName;
}

class CatalogItem {
  const CatalogItem(this.code, this.name, this.rate);
  final String code;
  final String name;
  final double rate;
}

class Catalog {
  const Catalog({required this.customers, required this.items});
  final List<Customer> customers;
  final List<CatalogItem> items;
}

/// A line the sales rep is adding to a new order.
class OrderLine {
  OrderLine(this.item, {this.qty = 1, double? rate}) : rate = rate ?? item.rate;
  final CatalogItem item;
  int qty;
  double rate;
  double get amount => qty * rate;
}

/// A truck-loading job: an approved order that is waiting, being loaded, or loaded.
class LoadingTask {
  const LoadingTask({
    required this.id,
    required this.salesOrder,
    required this.customerName,
    required this.status,
    required this.items,
    this.vehicleNo,
    this.driverName,
    this.driverPhone,
    this.address,
    this.customerPhone,
    this.invoice,
    this.total = 0,
    this.changeRequested = false,
    this.newItems = const [],
    this.reason,
    this.askedBy,
    String? stage,
  }) : _stage = stage;

  factory LoadingTask.fromJson(Map<String, dynamic> json) => LoadingTask(
    id: (json['name'] ?? json['sales_order']) as String,
    salesOrder: json['sales_order'] as String,
    customerName: (json['customer_name'] ?? json['customer']) as String,
    status: json['status'] as String,
    stage: json['stage'] as String?,
    vehicleNo: json['vehicle_no'] as String?,
    driverName: json['driver_name'] as String?,
    driverPhone: json['driver_phone'] as String?,
    address: json['address'] as String?,
    customerPhone: json['customer_phone'] as String?,
    invoice: json['invoice'] as String?,
    total: ((json['total'] as num?) ?? 0).toDouble(),
    changeRequested: (json['change_requested'] as bool?) ?? false,
    newItems: [
      for (final i in (json['new_items'] as List?) ?? const [])
        OrderItem(
          itemCode: i['item_code'] as String,
          itemName: i['item_code'] as String,
          qty: (i['qty'] as num).toDouble(),
          rate: 0,
        ),
    ],
    reason: json['reason'] as String?,
    askedBy: json['asked_by'] as String?,
    items: [
      for (final i in json['items'] as List)
        OrderItem(
          itemCode: i['item_code'] as String,
          itemName: i['item_name'] as String,
          qty: (i['qty'] as num).toDouble(),
          rate: ((i['rate'] as num?) ?? 0).toDouble(),
        ),
    ],
  );

  /// The Delivery Note once loading has started, else the order name.
  final String id;
  final String salesOrder;
  final String customerName;

  /// Waiting, Loading, Loaded or Dispatched.
  final String status;
  final String? _stage;

  /// The word for this truck on the order's ladder (the server sends it; an
  /// older server's status is turned into the same words here).
  String get stage =>
      _stage ??
      switch (status) {
        'Waiting' => 'Approved',
        'Dispatched' => 'On the way',
        _ => status,
      };
  final String? vehicleNo;

  /// The driver or contact person that goes with the vehicle.
  final String? driverName;
  final String? driverPhone;

  /// Where to deliver and who to call there.
  final String? address;
  final String? customerPhone;
  final List<OrderItem> items;

  /// Set once the truck is billed (invoice before dispatch).
  final String? invoice;
  final double total;

  /// The warehouse asked to change the bags after the bill was printed; the
  /// owner has not decided yet. [newItems] are the bags it asked for.
  final bool changeRequested;
  final List<OrderItem> newItems;
  final String? reason;
  final String? askedBy;

  LoadingTask copyWith({
    String? id,
    String? status,
    String? vehicleNo,
    String? driverName,
    String? driverPhone,
    List<OrderItem>? items,
    String? invoice,
    double? total,
    bool? changeRequested,
    bool clearInvoice = false,
  }) => LoadingTask(
    id: id ?? this.id,
    salesOrder: salesOrder,
    customerName: customerName,
    status: status ?? this.status,
    stage: status == null ? _stage : null,
    vehicleNo: vehicleNo ?? this.vehicleNo,
    driverName: driverName ?? this.driverName,
    driverPhone: driverPhone ?? this.driverPhone,
    address: address,
    customerPhone: customerPhone,
    items: items ?? this.items,
    invoice: clearInvoice ? null : invoice ?? this.invoice,
    total: total ?? this.total,
    changeRequested: changeRequested ?? this.changeRequested,
    newItems: newItems,
    reason: reason,
    askedBy: askedBy,
  );
}

/// A truck the mill loads, with the driver who goes with it.
class Vehicle {
  const Vehicle({
    required this.vehicleNo,
    required this.driverName,
    this.driverPhone,
    this.driverUser,
    this.enabled = true,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    vehicleNo: j['vehicle_no'] as String,
    driverName: (j['driver_name'] as String?) ?? '',
    driverPhone: j['driver_phone'] as String?,
    driverUser: j['driver_user'] as String?,
    enabled: (j['enabled'] as bool?) ?? true,
  );

  final String vehicleNo;
  final String driverName;
  final String? driverPhone;

  /// The app login of the driver, if they have one.
  final String? driverUser;
  final bool enabled;
}

/// A customer who owes money, with the number of open bills.
class Due {
  const Due({
    required this.customer,
    required this.customerName,
    required this.due,
    required this.bills,
    this.oldest,
  });

  factory Due.fromJson(Map<String, dynamic> j) {
    final invoices = j['invoices'] as List;
    return Due(
      customer: j['customer'] as String,
      customerName: (j['customer_name'] ?? j['customer']) as String,
      due: (j['due'] as num).toDouble(),
      bills: invoices.length,
      oldest: invoices.isEmpty ? null : invoices.first['date'] as String,
    );
  }

  final String customer;
  final String customerName;
  final double due;
  final int bills;

  /// Date of the oldest unpaid bill.
  final String? oldest;
}

/// What a payment collection did.
class Collected {
  const Collected(this.amount, this.stillDue);
  final double amount;
  final double stillDue;
}

/// One truck of wheat on its way from gate to stock.
class WheatTruck {
  const WheatTruck({
    required this.name,
    required this.supplierName,
    required this.vehicleNo,
    required this.status,
    required this.partyWeightKg,
    this.grossKg = 0,
    this.netKg = 0,
    this.weightGapKg = 0,
    this.weightAlert = false,
    this.moisture = 0,
    this.foreignMatter = 0,
    this.broken = 0,
  });

  factory WheatTruck.fromJson(Map<String, dynamic> j) => WheatTruck(
    name: j['name'] as String,
    supplierName: (j['supplier_name'] ?? j['supplier']) as String,
    vehicleNo: j['vehicle_no'] as String,
    status: j['status'] as String,
    partyWeightKg: (j['party_weight_kg'] as num).toDouble(),
    grossKg: (j['gross_kg'] as num).toDouble(),
    netKg: (j['net_kg'] as num).toDouble(),
    weightGapKg: (j['weight_gap_kg'] as num).toDouble(),
    weightAlert: j['weight_alert'] as bool,
    moisture: (j['moisture_pct'] as num).toDouble(),
    foreignMatter: (j['foreign_matter_pct'] as num).toDouble(),
    broken: (j['broken_pct'] as num).toDouble(),
  );

  final String name;
  final String supplierName;
  final String vehicleNo;

  /// At Gate, Weighed In, On Hold, Released, Rejected or Received.
  final String status;
  final double partyWeightKg;
  final double grossKg;
  final double netKg;
  final double weightGapKg;
  final bool weightAlert;
  final double moisture;
  final double foreignMatter;
  final double broken;

  WheatTruck copyWith({
    String? status,
    double? grossKg,
    double? netKg,
    double? weightGapKg,
    bool? weightAlert,
    double? moisture,
    double? foreignMatter,
    double? broken,
  }) => WheatTruck(
    name: name,
    supplierName: supplierName,
    vehicleNo: vehicleNo,
    status: status ?? this.status,
    partyWeightKg: partyWeightKg,
    grossKg: grossKg ?? this.grossKg,
    netKg: netKg ?? this.netKg,
    weightGapKg: weightGapKg ?? this.weightGapKg,
    weightAlert: weightAlert ?? this.weightAlert,
    moisture: moisture ?? this.moisture,
    foreignMatter: foreignMatter ?? this.foreignMatter,
    broken: broken ?? this.broken,
  );
}

/// What one milling shift gave: flour from wheat, and whether it needs a look.
class MillResult {
  const MillResult({
    required this.extractionPct,
    required this.lossKg,
    required this.lowYield,
  });
  final double extractionPct;
  final double lossKg;
  final bool lowYield;
}

/// A packable bag size with the bulk flour and empty bags on hand.
class PackSku {
  const PackSku({
    required this.code,
    required this.name,
    required this.kg,
    required this.bulkKg,
    required this.emptyBags,
    required this.packedBags,
  });

  factory PackSku.fromJson(Map<String, dynamic> j) => PackSku(
    code: j['item_code'] as String,
    name: j['item_name'] as String,
    kg: (j['kg'] as num).toDouble(),
    bulkKg: (j['bulk_kg'] as num).toDouble(),
    emptyBags: (j['empty_bags'] as num).toDouble(),
    packedBags: (j['packed_bags'] as num).toDouble(),
  );

  final String code;
  final String name;
  final double kg;
  final double bulkKg;
  final double emptyBags;
  final double packedBags;

  /// Most bags that bulk flour and empty bags allow.
  int get canPack {
    final byFlour = (bulkKg / kg).floor();
    final byBags = emptyBags.floor();
    return byFlour < byBags ? byFlour : byBags;
  }

  PackSku after(int bags) => PackSku(
    code: code,
    name: name,
    kg: kg,
    bulkKg: bulkKg - bags * kg,
    emptyBags: emptyBags - bags,
    packedBags: packedBags + bags,
  );
}

/// One line of the stock view.
class StockRow {
  const StockRow(this.code, this.name, this.qty, this.unit, this.kind);

  factory StockRow.fromJson(Map<String, dynamic> j) => StockRow(
    j['item_code'] as String,
    j['item_name'] as String,
    (j['qty'] as num).toDouble(),
    j['unit'] as String,
    j['kind'] as String,
  );

  final String code;
  final String name;
  final double qty;

  /// kg or bags.
  final String unit;

  /// Raw, Bulk or Packed.
  final String kind;
}

/// One thing the owner should look at.
class MillAlert {
  const MillAlert(this.kind, this.text);

  /// weight, yield, downtime or credit.
  final String kind;
  final String text;
}

/// The owner's picture of today.
class DayView {
  const DayView({
    required this.salesBooked,
    required this.invoiced,
    required this.collected,
    required this.duesTotal,
    required this.ageing,
    required this.pendingApprovals,
    required this.trucksInYard,
    required this.trucksToDispatch,
    required this.wheatGroundKg,
    required this.flourMadeKg,
    required this.extractionPct,
    required this.downtimeMin,
    required this.alerts,
  });

  factory DayView.fromJson(Map<String, dynamic> j) => DayView(
    salesBooked: (j['sales_booked'] as num).toDouble(),
    invoiced: (j['invoiced'] as num).toDouble(),
    collected: (j['collected'] as num).toDouble(),
    duesTotal: (j['dues_total'] as num).toDouble(),
    ageing: {
      for (final e in (j['ageing'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toDouble(),
    },
    pendingApprovals: j['pending_approvals'] as int,
    trucksInYard: j['trucks_in_yard'] as int,
    trucksToDispatch: j['trucks_to_dispatch'] as int,
    wheatGroundKg: (j['wheat_ground_kg'] as num).toDouble(),
    flourMadeKg: (j['flour_made_kg'] as num).toDouble(),
    extractionPct: (j['extraction_pct'] as num).toDouble(),
    downtimeMin: (j['downtime_min'] as num).toInt(),
    alerts: [
      for (final a in j['alerts'] as List)
        MillAlert(a['kind'] as String, a['text'] as String),
    ],
  );

  final double salesBooked;
  final double invoiced;
  final double collected;
  final double duesTotal;
  final Map<String, double> ageing;
  final int pendingApprovals;
  final int trucksInYard;
  final int trucksToDispatch;
  final double wheatGroundKg;
  final double flourMadeKg;
  final double extractionPct;
  final int downtimeMin;
  final List<MillAlert> alerts;
}

/// Management P&L for a month, from recorded transactions.
class Pnl {
  const Pnl({
    required this.from,
    required this.to,
    required this.sales,
    required this.cost,
    required this.profit,
    required this.marginPct,
    required this.collected,
  });

  factory Pnl.fromJson(Map<String, dynamic> j) => Pnl(
    from: j['from'] as String,
    to: j['to'] as String,
    sales: (j['sales'] as num).toDouble(),
    cost: (j['cost_of_goods'] as num).toDouble(),
    profit: (j['gross_profit'] as num).toDouble(),
    marginPct: (j['margin_pct'] as num).toDouble(),
    collected: (j['collected'] as num).toDouble(),
  );

  final String from;
  final String to;
  final double sales;
  final double cost;
  final double profit;
  final double marginPct;
  final double collected;
}

/// Opening, received, issued and closing for one item.
class StockLine {
  const StockLine(
    this.code,
    this.opening,
    this.received,
    this.issued,
    this.closing,
  );
  final String code;
  final double opening;
  final double received;
  final double issued;
  final double closing;
}

/// The month's stock statement and whether it matches the ledger.
class StockReport {
  const StockReport(this.lines, this.reconciled);

  factory StockReport.fromJson(Map<String, dynamic> j) => StockReport([
    for (final i in j['items'] as List)
      StockLine(
        i['item_code'] as String,
        (i['opening'] as num).toDouble(),
        (i['received'] as num).toDouble(),
        (i['issued'] as num).toDouble(),
        (i['closing'] as num).toDouble(),
      ),
  ], j['reconciled'] as bool);

  final List<StockLine> lines;
  final bool reconciled;
}

/// Money taken from a shop on an order. It is Collected until the owner marks
/// the cash handed in (Settled).
class Collection {
  const Collection({
    required this.name,
    required this.salesOrder,
    required this.customerName,
    required this.amount,
    required this.mode,
    required this.status,
    this.collectedByName,
  });

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
    name: j['name'] as String,
    salesOrder: j['sales_order'] as String,
    customerName: (j['customer_name'] as String?) ?? '',
    amount: (j['amount'] as num).toDouble(),
    mode: (j['mode'] as String?) ?? 'Cash',
    status: j['status'] as String,
    collectedByName: j['collected_by_name'] as String?,
  );

  final String name;
  final String salesOrder;
  final String customerName;
  final double amount;
  final String mode;
  final String status;
  final String? collectedByName;
}

/// An order that still has money to collect, or money not yet handed in.
class OrderMoney {
  const OrderMoney({
    required this.salesOrder,
    required this.customerName,
    required this.billed,
    required this.paid,
    required this.withCollector,
    required this.remaining,
  });

  factory OrderMoney.fromJson(Map<String, dynamic> j) => OrderMoney(
    salesOrder: j['sales_order'] as String,
    customerName: (j['customer_name'] as String?) ?? '',
    billed: (j['billed'] as num).toDouble(),
    paid: (j['paid'] as num).toDouble(),
    withCollector: (j['with_collector'] as num).toDouble(),
    remaining: (j['remaining'] as num).toDouble(),
  );

  final String salesOrder;
  final String customerName;
  final double billed;
  final double paid;
  final double withCollector;
  final double remaining;
}

/// A rep's or driver's money screen: cash they hold and orders to collect on.
class MyCollections {
  const MyCollections({
    required this.holding,
    required this.collections,
    required this.orders,
  });

  factory MyCollections.fromJson(Map<String, dynamic> j) => MyCollections(
    holding: (j['holding'] as num).toDouble(),
    collections: [
      for (final c in j['collections'] as List)
        Collection.fromJson(c as Map<String, dynamic>),
    ],
    orders: [
      for (final o in j['orders'] as List)
        OrderMoney.fromJson(o as Map<String, dynamic>),
    ],
  );

  final double holding;
  final List<Collection> collections;
  final List<OrderMoney> orders;
}

/// Cash one person holds, waiting for the owner to mark it handed in.
class CashHolder {
  const CashHolder({
    required this.name,
    required this.total,
    required this.collections,
  });

  factory CashHolder.fromJson(Map<String, dynamic> j) => CashHolder(
    name: j['name'] as String,
    total: (j['total'] as num).toDouble(),
    collections: [
      for (final c in j['collections'] as List)
        Collection.fromJson(c as Map<String, dynamic>),
    ],
  );

  final String name;
  final double total;
  final List<Collection> collections;
}
