import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/pull_to_reload.dart';

/// Owner / manager: the warehouse changed the bags after the bill was printed.
/// Approving cancels that bill; the warehouse then prints a new one.
class LoadChangesScreen extends StatefulWidget {
  const LoadChangesScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<LoadChangesScreen> createState() => _LoadChangesScreenState();
}

class _LoadChangesScreenState extends State<LoadChangesScreen> {
  late Future<List<LoadingTask>> _changes = widget.client.loadChanges();

  void _reload() {
    setState(() {
      _changes = widget.client.loadChanges();
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_changes);
  }

  Future<void> _decide(LoadingTask t, {required bool approve}) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.client.decideLoadChange(t, approve: approve);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${t.customerName}: ${s.t(approve ? 'Change approved' : 'Change turned down')}',
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
        title: Text(s.t('Load changes')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<LoadingTask>(
        future: _changes,
        onRefresh: _refresh,
        emptyText: s.t('No changes waiting'),
        emptyKey: const Key('no-changes'),
        cards: (context, tasks) => [
          for (final t in tasks)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.customerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(s.t('Vehicle {0}', [t.vehicleNo ?? '-'])),
                    const SizedBox(height: 8),
                    for (final i in t.items)
                      Text(
                        '${i.itemName}: ${i.qty.round()} -> '
                        '${_asked(t, i.itemCode).round()} ${s.t('bags')}',
                        key: Key('change-${t.id}-${i.itemCode}'),
                        style: const TextStyle(fontSize: 18),
                      ),
                    if ((t.reason ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${s.t('Reason')}: ${t.reason}'),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            key: Key('approve-change-${t.id}'),
                            onPressed: () => _decide(t, approve: true),
                            child: Text(s.t('Approve')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            key: Key('turn-down-${t.id}'),
                            onPressed: () => _decide(t, approve: false),
                            child: Text(s.t('Turn down')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _asked(LoadingTask t, String code) {
    for (final i in t.newItems) {
      if (i.itemCode == code) return i.qty;
    }
    return 0;
  }
}
