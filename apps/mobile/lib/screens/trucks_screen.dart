import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/load_error.dart';
import '../widgets/order_card.dart';

enum TruckMode { invoice, dispatch }

/// Accounts bills loaded trucks; dispatch lets billed trucks leave.
/// The invoice always comes first (DECISIONS D5).
class TrucksScreen extends StatefulWidget {
  const TrucksScreen({super.key, required this.client, required this.mode});
  final ErpNextClient client;
  final TruckMode mode;

  @override
  State<TrucksScreen> createState() => _TrucksScreenState();
}

class _TrucksScreenState extends State<TrucksScreen> {
  late Future<List<LoadingTask>> _trucks = _fetch();

  Future<List<LoadingTask>> _fetch() => widget.mode == TruckMode.invoice
      ? widget.client.trucksToInvoice()
      : widget.client.trucksToDispatch();

  Future<void> _run(Future<LoadingTask> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S.of(context);
    try {
      final t = await action();
      messenger.showSnackBar(
        SnackBar(content: Text('${t.customerName}: ${s.t(done)}')),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.saveFailed(e),
            key: const Key('save-failed'),
          ),
        ),
      );
    }
    setState(() {
      _trucks = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final invoicing = widget.mode == TruckMode.invoice;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(invoicing ? 'Bills and payments' : 'Send trucks')),
      ),
      body: FutureBuilder<List<LoadingTask>>(
        future: _trucks,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return LoadError(snap.error);
          final trucks = snap.data!;
          if (trucks.isEmpty) {
            return Center(
              child: Text(
                s.t('No trucks waiting'),
                key: const Key('no-trucks'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final t in trucks)
                _TruckCard(
                  key: ValueKey(t.id),
                  task: t,
                  mode: widget.mode,
                  onInvoice: (eway) => _run(
                    () => widget.client.invoiceTruck(t, eway),
                    'Invoice made',
                  ),
                  onDispatch: () =>
                      _run(() => widget.client.dispatchTruck(t), 'Truck left'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TruckCard extends StatefulWidget {
  const _TruckCard({
    super.key,
    required this.task,
    required this.mode,
    required this.onInvoice,
    required this.onDispatch,
  });
  final LoadingTask task;
  final TruckMode mode;
  final void Function(String eway) onInvoice;
  final VoidCallback onDispatch;

  @override
  State<_TruckCard> createState() => _TruckCardState();
}

class _TruckCardState extends State<_TruckCard> {
  final _eway = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = widget.task;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.customerName, style: Theme.of(context).textTheme.titleLarge),
            Text(s.t('Vehicle {0}', [t.vehicleNo ?? '-'])),
            const SizedBox(height: 8),
            for (final i in t.items)
              Text(
                '${i.itemName}: ${i.qty.round()} ${s.t('bags')}',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 12),
            if (widget.mode == TruckMode.invoice) ...[
              TextField(
                key: Key('eway-${t.id}'),
                controller: _eway,
                decoration: InputDecoration(
                  labelText: s.t('E-way bill number'),
                  helperText: s.t('Needed when goods are over ₹50,000'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: Key('invoice-${t.id}'),
                icon: const Icon(Icons.receipt_long),
                label: Text(s.t('Make invoice')),
                onPressed: () => widget.onInvoice(_eway.text.trim()),
              ),
            ] else ...[
              Text(
                '${s.t('Invoice')} ${t.invoice}  ${rupees(t.total)}',
                style: const TextStyle(fontSize: 18),
              ),
              if (t.ewayBillNo != null && t.ewayBillNo!.isNotEmpty)
                Text('${s.t('E-way bill number')}: ${t.ewayBillNo}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: Key('dispatch-${t.id}'),
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(s.t('Let truck leave')),
                onPressed: widget.onDispatch,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
