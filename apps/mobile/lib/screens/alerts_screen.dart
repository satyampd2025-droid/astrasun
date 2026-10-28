import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/pull_to_reload.dart';

/// The bell in the home bar: a bell with the number of alerts not yet seen.
class BellButton extends StatefulWidget {
  const BellButton({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<BellButton> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await widget.client.unreadAlerts();
      if (mounted) setState(() => _unread = n);
    } on Exception {
      // The bell is a convenience: a failed count just shows no number.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlertListScreen(client: widget.client),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('bell'),
    tooltip: S.of(context).t('Notifications'),
    onPressed: _open,
    icon: Badge(
      key: const Key('bell-badge'),
      isLabelVisible: _unread > 0,
      label: Text('$_unread'),
      child: const Icon(Icons.notifications_outlined),
    ),
  );
}

/// What happened lately: orders placed, decided and money collected.
class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> {
  late Future<List<AppAlert>> _alerts = _load();

  /// Opening the list shows the alerts as they were, then marks them read.
  Future<List<AppAlert>> _load() async {
    final list = await widget.client.alerts();
    if (list.any((a) => !a.read)) {
      await widget.client.markAlertsRead();
    }
    return list;
  }

  Future<void> _refresh() async {
    setState(() => _alerts = _load());
    await _alerts;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Notifications')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<AppAlert>(
        future: _alerts,
        onRefresh: _refresh,
        emptyText: s.t('No alerts yet'),
        emptyKey: const Key('no-alerts'),
        cards: (context, list) => [
          for (final a in list)
            Card(
              key: Key('alert-${a.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              color: a.read ? Colors.white : const Color(0xFFEAF2FF),
              child: ListTile(
                leading: Icon(
                  a.subject.contains('collected')
                      ? Icons.payments_outlined
                      : Icons.receipt_long_outlined,
                ),
                title: Text(a.subject),
                subtitle: Text(
                  '${a.at.day}/${a.at.month} '
                  '${a.at.hour.toString().padLeft(2, '0')}:'
                  '${a.at.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
