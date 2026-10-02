import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';

/// Owner: the month's profit and loss and the stock statement.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<Object>> _reports = _fetch();

  Future<List<Object>> _fetch() => Future.wait<Object>([
    widget.client.profitAndLoss(),
    widget.client.stockStatement(),
  ]);

  Future<void> _refresh() {
    setState(() {
      _reports = _fetch();
    });
    return settled(_reports);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Reports')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload<List<Object>>(
        future: _reports,
        onRefresh: _refresh,
        builder: (context, data) {
          final pnl = data[0] as Pnl;
          final stock = data[1] as StockReport;
          Widget row(String label, String value, {Key? key}) => ListTile(
            dense: true,
            title: Text(label, style: const TextStyle(fontSize: 18)),
            trailing: Text(
              value,
              key: key,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          );
          return [
            Text(
              '${s.t('Profit and loss')}  ${pnl.from} – ${pnl.to}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  row(s.t('Sales'), rupees(pnl.sales)),
                  row(s.t('Cost of goods'), rupees(pnl.cost)),
                  row(
                    s.t('Profit'),
                    rupees(pnl.profit),
                    key: const Key('profit'),
                  ),
                  row(s.t('Margin'), '${pnl.marginPct.toStringAsFixed(1)}%'),
                  row(s.t('Collected'), rupees(pnl.collected)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.t('Stock statement'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              s.t(
                stock.reconciled
                    ? 'Matches the stock ledger'
                    : 'Does not match the ledger',
              ),
              key: Key(stock.reconciled ? 'reconciled' : 'not-reconciled'),
              style: TextStyle(
                color: stock.reconciled
                    ? const Color(0xFF1E5B45)
                    : const Color(0xFFB23A30),
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final l in stock.lines)
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.code,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${s.t('Opening')} ${l.opening.round()}   '
                        '${s.t('In')} +${l.received.round()}   '
                        '${s.t('Out')} -${l.issued.round()}   '
                        '${s.t('Closing')} ${l.closing.round()}',
                      ),
                    ],
                  ),
                ),
              ),
          ];
        },
      ),
    );
  }
}
