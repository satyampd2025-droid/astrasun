import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../print_bill.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';
import 'edit_order_screen.dart';

/// Warehouse: approved orders to load onto trucks.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  late Future<List<LoadingTask>> _tasks = widget.client.loadingQueue();
  List<Vehicle> _vehicles = const [];

  @override
  void initState() {
    super.initState();
    // The list is only needed once a load is marked done; if it cannot be
    // fetched the card says so instead of offering a vehicle.
    widget.client
        .vehicles()
        .then((v) {
          if (mounted) setState(() => _vehicles = v);
        })
        .catchError((_) {});
  }

  void _reload() {
    setState(() {
      _tasks = widget.client.loadingQueue();
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_tasks);
  }

  Future<void> _run(Future<LoadingTask> Function() action) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await action();
      if (done.status == 'Loaded') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${done.customerName}: ${s.t('Vehicle {0}', [done.vehicleNo ?? ''])}',
            ),
          ),
        );
      }
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    }
    _reload();
  }

  /// Print bill: bills the truck if it has no bill yet, then opens the print screen.
  Future<void> _printBill(LoadingTask t) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final billed = t.invoice == null
          ? await widget.client.invoiceTruck(t)
          : t;
      final pdf = await widget.client.billPdf(billed);
      await billPrinter(pdf, billed.invoice ?? billed.id);
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    }
    _reload();
  }

  /// The warehouse edits the whole order; the owner has to approve.
  Future<void> _edit(LoadingTask t) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final order = await widget.client.order(t.salesOrder);
      if (!mounted) return;
      final done = await Navigator.of(context).push<Order>(
        MaterialPageRoute(
          builder: (_) => EditOrderScreen(client: widget.client, order: order),
        ),
      );
      if (done != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.t('Change sent to the owner'))),
        );
      }
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
        title: Text(s.t('Loading queue')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<LoadingTask>(
        future: _tasks,
        onRefresh: _refresh,
        emptyText: s.t('Nothing to load'),
        emptyKey: const Key('nothing-to-load'),
        cards: (context, tasks) => [
          for (final t in tasks)
            _TaskCard(
              key: ValueKey('${t.id}-${t.status}'),
              task: t,
              vehicles: _vehicles,
              onStart: () => _run(() => widget.client.startLoading(t)),
              loadBatches: widget.client.batchesInStock,
              onLoaded: (vehicle, loaded, batches) => _run(
                () => widget.client.markLoaded(
                  t,
                  vehicle,
                  loaded,
                  batches: batches,
                ),
              ),
              onPrint: () => _printBill(t),
              onLeft: () => _run(() => widget.client.dispatchTruck(t)),
              onChange: () => _edit(t),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.vehicles,
    required this.onStart,
    required this.loadBatches,
    required this.onLoaded,
    required this.onPrint,
    required this.onLeft,
    required this.onChange,
  });
  final LoadingTask task;
  final List<Vehicle> vehicles;
  final VoidCallback onStart;
  final Future<List<BatchStock>> Function(String itemCode) loadBatches;
  final void Function(
    String vehicle,
    Map<String, int> loaded,
    Map<String, String> batches,
  )
  onLoaded;
  final VoidCallback onPrint;
  final VoidCallback onLeft;
  final VoidCallback onChange;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  late String? _vehicle =
      widget.vehicles.any((v) => v.vehicleNo == widget.task.vehicleNo)
      ? widget.task.vehicleNo
      : null;
  bool _missing = false;
  bool _batchMissing = false;

  /// Batches in stock per item, and the one the warehouse chose for each.
  final Map<String, List<BatchStock>> _stock = {};
  final Map<String, String> _batch = {};

  @override
  void initState() {
    super.initState();
    if (widget.task.status != 'Loading') return;
    for (final i in widget.task.items) {
      widget
          .loadBatches(i.itemCode)
          .then((b) {
            if (mounted) setState(() => _stock[i.itemCode] = b);
          })
          .catchError((_) {});
    }
  }

  void _finish() {
    final noBatch = widget.task.items.any(
      (i) =>
          (_stock[i.itemCode] ?? []).isNotEmpty && _batch[i.itemCode] == null,
    );
    if (_vehicle == null || noBatch) {
      setState(() {
        _missing = _vehicle == null;
        _batchMissing = noBatch;
      });
      return;
    }
    widget.onLoaded(
      _vehicle!,
      {for (final i in widget.task.items) i.itemCode: i.qty.round()},
      {..._batch},
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = widget.task;
    final loading = t.status == 'Loading';
    return Card(
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
            Text(t.salesOrder),
            const SizedBox(height: 8),
            for (final i in t.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.itemName,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    Text(
                      '${i.qty.round()} ${s.t('bags')}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (t.status == 'Waiting')
              FilledButton.icon(
                key: Key('start-${t.id}'),
                icon: const Icon(Icons.forklift),
                label: Text(s.t('Start loading')),
                onPressed: widget.onStart,
              ),
            if (t.status == 'Loaded') ...[
              if ((t.vehicleNo ?? '').isNotEmpty)
                Text(
                  '${s.t('Vehicle {0}', [t.vehicleNo!])}'
                  '${(t.driverName ?? '').isEmpty ? '' : ' - ${t.driverName}'}',
                ),
              if (!t.changeRequested) ...[
                FilledButton.icon(
                  key: Key('print-${t.id}'),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(s.t('Print bill')),
                  onPressed: widget.onPrint,
                ),
                if (t.invoice != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    key: Key('left-${t.id}'),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(s.t('Truck left')),
                    onPressed: widget.onLeft,
                  ),
                ],
              ],
            ],
            if (t.changeRequested)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s.t('Change waiting for the owner'),
                  key: Key('change-waiting-${t.id}'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              TextButton.icon(
                key: Key('change-${t.id}'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.t('Change order')),
                onPressed: widget.onChange,
              ),
            if (loading && !t.changeRequested) ...[
              for (final i in t.items)
                if ((_stock[i.itemCode] ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DropdownButtonFormField<String>(
                      key: Key('batch-${t.id}-${i.itemCode}'),
                      initialValue: _batch[i.itemCode],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '${s.t('Batch')} - ${i.itemName}',
                      ),
                      items: [
                        for (final b in _stock[i.itemCode]!)
                          DropdownMenuItem(
                            value: b.batchNo,
                            enabled: b.qty >= i.qty,
                            child: Text(
                              '${b.batchNo} (${b.qty.round()} ${s.t('bags')})',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _batch[i.itemCode] = v!;
                        _batchMissing = false;
                      }),
                    ),
                  ),
              if (_batchMissing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.t('Pick the batch'),
                    key: Key('batch-missing-${t.id}'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (widget.vehicles.isEmpty)
                Text(
                  s.t('No vehicles yet. Ask the owner to add them.'),
                  key: Key('no-vehicles-${t.id}'),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: Key('vehicle-${t.id}'),
                  initialValue: _vehicle,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s.t('Vehicle')),
                  items: [
                    for (final v in widget.vehicles)
                      DropdownMenuItem(
                        value: v.vehicleNo,
                        child: Text('${v.vehicleNo} - ${v.driverName}'),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _vehicle = v;
                    _missing = false;
                  }),
                ),
                if (_vehicle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      s.t('Driver {0}', [
                        widget.vehicles
                            .firstWhere((v) => v.vehicleNo == _vehicle)
                            .driverName,
                      ]),
                      key: Key('driver-${t.id}'),
                    ),
                  ),
              ],
              if (_missing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.t('Pick the vehicle'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: Key('loaded-${t.id}'),
                icon: const Icon(Icons.check),
                label: Text(s.t('Mark loaded')),
                onPressed: _finish,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
