import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';

/// Sales rep: my orders and where each one stands.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Order>> _orders = widget.client.myOrders();

  Future<void> _refresh() {
    setState(() {
      _orders = widget.client.myOrders();
    });
    return settled(_orders);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('My orders')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<Order>(
        future: _orders,
        onRefresh: _refresh,
        emptyText: s.t('No orders yet'),
        cards: (context, orders) => [
          for (final o in orders) OrderCard(order: o),
        ],
      ),
    );
  }
}
