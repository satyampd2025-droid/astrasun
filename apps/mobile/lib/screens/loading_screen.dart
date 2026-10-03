import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../print_bill.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';
import '../widgets/voice_text_field.dart';

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
              onLoaded: (vehicle, loaded) =>
                  _run(() => widget.client.markLoaded(t, vehicle, loaded)),
              onPrint: () => _printBill(t),
              onLeft: () => _run(() => widget.client.dispatchTruck(t)),
              onChange: (bags, reason) =>
                  _run(() => widget.client.requestLoadChange(t, bags, reason)),
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
    required this.onLoaded,
    required this.onPrint,
    required this.onLeft,
    required this.onChange,
  });
  final LoadingTask task;
  final List<Vehicle> vehicles;
  final VoidCallback onStart;
  final void Function(String vehicle, Map<String, int> loaded) onLoaded;
  final VoidCallback onPrint;
  final VoidCallback onLeft;
  final void Function(Map<String, int> bags, String reason) onChange;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  late String? _vehicle =
      widget.vehicles.any((v) => v.vehicleNo == widget.task.vehicleNo)
      ? widget.task.vehicleNo
      : null;
  late final Map<String, int> _qty = {
    for (final i in widget.task.items) i.itemCode: i.qty.round(),
  };
  bool _missing = false;

  void _finish() {
    final s = S.of(context);
    if (_vehicle == null) {
      setState(() => _missing = true);
      return;
    }
    if (!_qty.values.any((q) => q > 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.t('Nothing to load'))));
      return;
    }
    widget.onLoaded(_vehicle!, _qty);
  }

  /// After the bill is printed the bags can still change, with the owner's approval.
  Future<void> _askChange() async {
    final s = S.of(context);
    final bags = {for (final i in widget.task.items) i.itemCode: i.qty.round()};
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(s.t('Change quantity')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final i in widget.task.items)
                  Row(
                    children: [
                      Expanded(child: Text(i.itemName)),
                      IconButton(
                        key: Key('change-less-${i.itemCode}'),
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setLocal(() {
                          if (bags[i.itemCode]! > 0) {
                            bags[i.itemCode] = bags[i.itemCode]! - 1;
                          }
                        }),
                      ),
                      Text(
                        '${bags[i.itemCode]}',
                        key: Key('change-qty-${i.itemCode}'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        key: Key('change-more-${i.itemCode}'),
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setLocal(
                          () => bags[i.itemCode] = bags[i.itemCode]! + 1,
                        ),
                      ),
                    ],
                  ),
                VoiceTextField(
                  key: const Key('change-reason'),
                  controller: reason,
                  label: s.t('Reason'),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t(
                    'The owner has to approve. The printed bill is cancelled and you print a new one.',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('Back')),
            ),
            FilledButton(
              key: const Key('change-send'),
              onPressed: () {
                if (reason.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: Text(s.t('Send to the owner')),
            ),
          ],
        ),
      ),
    );
    if (ok == true) widget.onChange(bags, reason.text.trim());
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
                    if (loading) ...[
                      IconButton(
                        key: Key('less-${i.itemCode}'),
                        iconSize: 32,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          final q = _qty[i.itemCode]!;
                          if (q > 0) _qty[i.itemCode] = q - 1;
                        }),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${_qty[i.itemCode]}',
                          key: Key('qty-${i.itemCode}'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text('/ ${i.qty.round()}'),
                    ] else
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
              if (t.changeRequested)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.t('Change waiting for the owner'),
                    key: Key('change-waiting-${t.id}'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              else ...[
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
                TextButton.icon(
                  key: Key('change-${t.id}'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.t('Change quantity')),
                  onPressed: _askChange,
                ),
              ],
            ],
            if (loading) ...[
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
