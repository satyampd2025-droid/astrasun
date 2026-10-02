import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';

const _alertIcons = {
  'weight': Icons.scale_outlined,
  'yield': Icons.trending_down,
  'downtime': Icons.report_problem_outlined,
  'credit': Icons.credit_score_outlined,
};

Widget _alertTile(MillAlert a) => Card(
  color: const Color(0xFFFBE9E7),
  child: ListTile(
    leading: Icon(_alertIcons[a.kind] ?? Icons.warning_amber),
    title: Text(a.text, style: const TextStyle(fontSize: 17)),
  ),
);

class _Loader extends StatefulWidget {
  const _Loader({
    required this.client,
    required this.title,
    required this.children,
    this.emptyText,
    this.emptyKey,
  });
  final ErpNextClient client;
  final String title;
  final List<Widget> Function(BuildContext, DayView) children;

  /// Shown instead of the children when there are no alerts (the Alerts screen).
  final String? emptyText;
  final Key? emptyKey;

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late Future<DayView> _day = widget.client.today();

  Future<void> _refresh() {
    setState(() {
      _day = widget.client.today();
    });
    return settled(_day);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(widget.title)),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload<DayView>(
        future: _day,
        onRefresh: _refresh,
        isEmpty: (d) => d.alerts.isEmpty,
        emptyText: widget.emptyText == null ? null : s.t(widget.emptyText!),
        emptyKey: widget.emptyKey,
        builder: widget.children,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Owner: today's sales, money, production and what needs a look.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) => _Loader(
    client: client,
    title: 'Today at the mill',
    children: (context, d) {
      final s = S.of(context);
      return [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            _Tile(
              s.t('Sales booked'),
              rupees(d.salesBooked),
              key: const Key('tile-sales'),
            ),
            _Tile(s.t('Invoiced'), rupees(d.invoiced)),
            _Tile(
              s.t('Collected'),
              rupees(d.collected),
              key: const Key('tile-collected'),
            ),
            _Tile(
              s.t('Dues'),
              rupees(d.duesTotal),
              key: const Key('tile-dues'),
            ),
            _Tile(s.t('Wheat ground'), '${d.wheatGroundKg.round()} kg'),
            _Tile(s.t('Extraction'), '${d.extractionPct.toStringAsFixed(1)}%'),
            _Tile(
              s.t('Orders to approve'),
              '${d.pendingApprovals}',
              key: const Key('tile-approvals'),
            ),
            _Tile(s.t('Wheat trucks in yard'), '${d.trucksInYard}'),
          ],
        ),
        const SizedBox(height: 8),
        Text(s.t('Dues by age'), style: Theme.of(context).textTheme.titleMedium),
        for (final e in d.ageing.entries)
          ListTile(
            dense: true,
            title: Text('${e.key} ${s.t('days')}'),
            trailing: Text(
              rupees(e.value),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '${s.t('Alerts')} (${d.alerts.length})',
          key: const Key('alerts-title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (d.alerts.isEmpty) Text(s.t('Nothing needs a look')),
        for (final a in d.alerts.take(3)) _alertTile(a),
      ];
    },
  );
}

/// Owner: everything unusual from the last week.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) => _Loader(
    client: client,
    title: 'Alerts',
    emptyText: 'Nothing needs a look',
    emptyKey: const Key('no-alerts'),
    children: (context, d) => [for (final a in d.alerts) _alertTile(a)],
  );
}
