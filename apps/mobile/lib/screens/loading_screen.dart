import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
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

  void _reload() {
    setState(() {
      _tasks = widget.client.loadingQueue();
    });
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
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('Could not save. Try again.'))),
      );
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Loading queue'))),
      body: FutureBuilder<List<LoadingTask>>(
        future: _tasks,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(s.t('Cannot reach the server. Check the internet.')),
            );
          }
          final tasks = snap.data!;
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                s.t('Nothing to load'),
                key: const Key('nothing-to-load'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final t in tasks)
                _TaskCard(
                  key: ValueKey('${t.id}-${t.status}'),
                  task: t,
                  onStart: () => _run(() => widget.client.startLoading(t)),
                  onLoaded: (vehicle, loaded) =>
                      _run(() => widget.client.markLoaded(t, vehicle, loaded)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.onStart,
    required this.onLoaded,
  });
  final LoadingTask task;
  final VoidCallback onStart;
  final void Function(String vehicle, Map<String, int> loaded) onLoaded;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  late final _vehicle = TextEditingController(text: widget.task.vehicleNo);
  late final Map<String, int> _qty = {
    for (final i in widget.task.items) i.itemCode: i.qty.round(),
  };
  bool _missing = false;

  void _finish() {
    final s = S.of(context);
    if (_vehicle.text.trim().isEmpty) {
      setState(() => _missing = true);
      return;
    }
    if (!_qty.values.any((q) => q > 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.t('Nothing to load'))));
      return;
    }
    widget.onLoaded(_vehicle.text.trim(), _qty);
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
                Chip(label: Text(s.t(t.status))),
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
            if (loading) ...[
              VoiceTextField(
                key: Key('vehicle-${t.id}'),
                controller: _vehicle,
                label: s.t('Vehicle number'),
              ),
              if (_missing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.t('Enter the vehicle number'),
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
