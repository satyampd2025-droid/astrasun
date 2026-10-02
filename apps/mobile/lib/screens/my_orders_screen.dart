import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';

/// Sales rep: my orders and where each one stands.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('My orders'))),
      body: FutureBuilder<List<Order>>(
        future: client.myOrders(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(s.t('Cannot reach the server. Check the internet.')),
            );
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return Center(child: Text(s.t('No orders yet')));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final o in orders) OrderCard(order: o)],
          );
        },
      ),
    );
  }
}
