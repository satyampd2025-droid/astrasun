import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';

/// Owner / accounts: the cash reps and drivers collected. When it is handed in
/// at the factory (in the evening), mark it settled; that books the payments.
class SettleCashScreen extends StatefulWidget {
  const SettleCashScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<SettleCashScreen> createState() => _SettleCashScreenState();
}

class _SettleCashScreenState extends State<SettleCashScreen> {
  late Future<List<CashHolder>> _holders = widget.client.cashToSettle();

  void _reload() {
    setState(() {
      _holders = widget.client.cashToSettle();
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_holders);
  }

  Future<void> _settle(CashHolder h) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.client.settleCash([for (final c in h.collections) c.name]);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.t('{0} settled: ₹ {1}', [h.name, h.total.round().toString()]),
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
        title: Text(s.t('Settle cash')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<CashHolder>(
        future: _holders,
        onRefresh: _refresh,
        emptyText: s.t('No cash waiting to be settled'),
        emptyKey: const Key('nothing-to-settle'),
        cards: (context, holders) => [
          for (final (i, h) in holders.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          rupees(h.total),
                          key: Key('holder-total-$i'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final c in h.collections)
                      Text(
                        '${c.customerName}  ${rupees(c.amount)}  ${s.t(c.mode)}',
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: Key('settle-$i'),
                      icon: const Icon(Icons.done_all),
                      label: Text(s.t('Cash handed in: mark settled')),
                      onPressed: () => _settle(h),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
