import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';
import 'order_screen.dart';

/// Sales rep: my orders and where each one stands. Tap one for its timeline.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) =>
      _OrderListScreen(title: 'My orders', load: client.myOrders);
}

/// Owner and manager: every order that was sent in, and where each one stands.
class AllOrdersScreen extends StatelessWidget {
  const AllOrdersScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) =>
      _OrderListScreen(title: 'All orders', load: client.allOrders);
}

class _OrderListScreen extends StatefulWidget {
  const _OrderListScreen({required this.title, required this.load});
  final String title;
  final Future<List<Order>> Function() load;

  @override
  State<_OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<_OrderListScreen> {
  late Future<List<Order>> _orders = widget.load();

  Future<void> _refresh() {
    setState(() {
      _orders = widget.load();
    });
    return settled(_orders);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(widget.title)),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<Order>(
        future: _orders,
        onRefresh: _refresh,
        emptyText: s.t('No orders yet'),
        cards: (context, orders) => [
          for (final o in orders)
            OrderCard(
              order: o,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => OrderScreen(order: o)),
              ),
            ),
        ],
      ),
    );
  }
}
