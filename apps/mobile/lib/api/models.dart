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

class Order {
  Order({
    required this.name,
    required this.customerName,
    required this.status,
    required this.total,
    required this.items,
    this.note,
    this.creditOutstanding = 0,
    this.creditLimit = 0,
    this.creditExposure = 0,
    this.creditBreach = false,
    this.stockShort = false,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    name: j['name'] as String,
    customerName: (j['customer_name'] as String?) ?? j['customer'] as String,
    status: j['status'] as String,
    total: (j['total'] as num).toDouble(),
    note: j['note'] as String?,
    creditOutstanding: (j['credit_outstanding'] as num? ?? 0).toDouble(),
    creditLimit: (j['credit_limit'] as num? ?? 0).toDouble(),
    creditExposure: (j['credit_exposure'] as num? ?? 0).toDouble(),
    creditBreach: j['credit_breach'] as bool? ?? false,
    stockShort: j['stock_short'] as bool? ?? false,
    items: [
      for (final i in j['items'] as List)
        OrderItem.fromJson(i as Map<String, dynamic>),
    ],
  );

  final String name;
  final String customerName;
  final String status;
  final double total;
  final String? note;
  final double creditOutstanding;
  final double creditLimit;
  final double creditExposure;
  final bool creditBreach;
  final bool stockShort;
  final List<OrderItem> items;

  Order copyWith({String? status, String? note}) => Order(
    name: name,
    customerName: customerName,
    status: status ?? this.status,
    total: total,
    items: items,
    note: note ?? this.note,
    creditOutstanding: creditOutstanding,
    creditLimit: creditLimit,
    creditExposure: creditExposure,
    creditBreach: creditBreach,
    stockShort: stockShort,
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
  });

  factory LoadingTask.fromJson(Map<String, dynamic> json) => LoadingTask(
    id: (json['name'] ?? json['sales_order']) as String,
    salesOrder: json['sales_order'] as String,
    customerName: (json['customer_name'] ?? json['customer']) as String,
    status: json['status'] as String,
    vehicleNo: json['vehicle_no'] as String?,
    items: [
      for (final i in json['items'] as List)
        OrderItem(
          itemCode: i['item_code'] as String,
          itemName: i['item_name'] as String,
          qty: (i['qty'] as num).toDouble(),
          rate: 0,
        ),
    ],
  );

  /// The Delivery Note once loading has started, else the order name.
  final String id;
  final String salesOrder;
  final String customerName;

  /// Waiting, Loading or Loaded.
  final String status;
  final String? vehicleNo;
  final List<OrderItem> items;

  LoadingTask copyWith({
    String? id,
    String? status,
    String? vehicleNo,
    List<OrderItem>? items,
  }) => LoadingTask(
    id: id ?? this.id,
    salesOrder: salesOrder,
    customerName: customerName,
    status: status ?? this.status,
    vehicleNo: vehicleNo ?? this.vehicleNo,
    items: items ?? this.items,
  );
}
