import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/collect_dialog.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';

/// A rep's or driver's money: the cash they hold (to hand in at the factory)
/// and their orders that still have money to collect. Collected is marked here;
/// the owner marks it Settled when the cash is handed in.
class MyCollectionsScreen extends StatefulWidget {
  const MyCollectionsScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<MyCollectionsScreen> createState() => _MyCollectionsScreenState();
}

class _MyCollectionsScreenState extends State<MyCollectionsScreen> {
  late Future<MyCollections> _money = widget.client.myCollections();

  void _reload() {
    setState(() {
      _money = widget.client.myCollections();
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_money);
  }

  Future<void> _collect(OrderMoney o) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final got = await askCollection(
      context,
      title: o.customerName,
      remaining: o.remaining,
    );
    if (got == null || !mounted) return;
    try {
      await widget.client.collectOnOrder(
        o.salesOrder,
        got.amount,
        got.mode,
        got.reference,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.t('Collected ₹ {0} from {1}', [
              got.amount.round().toString(),
              o.customerName,
            ]),
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('My collections')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload<MyCollections>(
        future: _money,
        onRefresh: _refresh,
        isEmpty: (m) => m.orders.isEmpty && m.collections.isEmpty,
        emptyText: s.t('Nothing to collect'),
        emptyKey: const Key('nothing-to-collect'),
        builder: (context, m) => [
          if (m.holding > 0)
            Card(
              key: const Key('holding'),
              color: const Color(0xFFFFF4D6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  s.t(
                    'Cash with you: ₹ {0}. Hand it in at the factory; the owner marks it settled.',
                    [m.holding.round().toString()],
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          for (final o in m.orders)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.customerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(o.salesOrder),
                    const SizedBox(height: 8),
                    Text('${s.t('Billed')}: ${rupees(o.billed)}'),
                    Text('${s.t('Paid')}: ${rupees(o.paid)}'),
                    if (o.withCollector > 0)
                      Text(
                        '${s.t('Collected, not handed in')}: ${rupees(o.withCollector)}',
                      ),
                    Text(
                      '${s.t('Left to pay')}: ${rupees(o.remaining)}',
                      key: Key('left-${o.salesOrder}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (o.remaining > 0) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: Key('collect-${o.salesOrder}'),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(s.t('Collect payment')),
                        onPressed: () => _collect(o),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
