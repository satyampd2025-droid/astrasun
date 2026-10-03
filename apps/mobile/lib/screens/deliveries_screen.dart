import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/collect_dialog.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';
import '../widgets/voice_text_field.dart';

/// Driver: every order on their vehicle, from loading until delivered, with
/// where it goes and what is in it. Confirm each delivery with the receiver's name.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  late Future<List<LoadingTask>> _trucks = widget.client.myDeliveries();

  Future<void> _deliver(LoadingTask t) async {
    final s = S.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.customerName),
        content: VoiceTextField(
          key: const Key('receiver'),
          controller: controller,
          label: s.t('Received by'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Back')),
          ),
          FilledButton(
            key: const Key('receiver-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(s.t('Confirm delivery')),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.client.deliver(t, name, '');
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('Delivered to {0}', [name]))),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    }
    _reload();
  }

  Future<void> _collect(LoadingTask t) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final got = await askCollection(
      context,
      title: t.customerName,
      remaining: _total(t),
    );
    if (got == null || !mounted) return;
    try {
      await widget.client.collectOnOrder(
        t.salesOrder,
        got.amount,
        got.mode,
        got.reference,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.t('Collected ₹ {0} from {1}', [
              got.amount.round().toString(),
              t.customerName,
            ]),
          ),
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    }
  }

  /// The bill total once billed, else what the items add up to.
  double _total(LoadingTask t) => t.total > 0
      ? t.total
      : t.items.fold(0.0, (sum, i) => sum + i.qty * i.rate);

  void _reload() {
    setState(() {
      _trucks = widget.client.myDeliveries();
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_trucks);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('My deliveries')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<LoadingTask>(
        future: _trucks,
        onRefresh: _refresh,
        emptyText: s.t('No deliveries waiting'),
        emptyKey: const Key('no-deliveries'),
        cards: (context, trucks) => [
          for (final t in trucks)
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
                            t.customerName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StageChip(t.stage, key: Key('stage-${t.id}')),
                      ],
                    ),
                    Text(s.t('Vehicle {0}', [t.vehicleNo ?? '-'])),
                    if ((t.address ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place_outlined, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t.address!,
                                key: Key('address-${t.id}'),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((t.customerPhone ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.call_outlined, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              t.customerPhone!,
                              key: Key('phone-${t.id}'),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(t.salesOrder, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    for (final i in t.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i.itemName}: ${i.qty.round()} ${s.t('bags')}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            if (i.rate > 0)
                              Text(
                                'Rs ${(i.qty * i.rate).round()}',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                        ),
                      ),
                    if (t.total > 0 || t.items.any((i) => i.rate > 0))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${s.t('Total')}: Rs ${_total(t).round()}',
                          key: Key('total-${t.id}'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (t.invoice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          key: Key('collect-${t.id}'),
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(s.t('Collect payment')),
                          onPressed: () => _collect(t),
                        ),
                      ),
                    if (t.status == 'Dispatched')
                      FilledButton.icon(
                        key: Key('deliver-${t.id}'),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(s.t('Confirm delivery')),
                        onPressed: () => _deliver(t),
                      )
                    else
                      Text(
                        s.t('Waiting for the truck to leave'),
                        key: Key('not-left-${t.id}'),
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
