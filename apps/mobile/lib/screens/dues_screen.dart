import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/pull_to_reload.dart';

/// Who owes money. Driver and accounts receive payment here; it is matched
/// to the customer's oldest bills first.
class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key, required this.client, this.canCollect = true});
  final ErpNextClient client;

  /// Drivers, accounts staff, managers and the owner receive money; anyone
  /// else (a sales rep checking what a customer owes) only looks.
  final bool canCollect;

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  late Future<List<Due>> _dues = widget.client.dues();

  Future<void> _receive(Due due) async {
    final s = S.of(context);
    final amount = TextEditingController(text: due.due.round().toString());
    final reference = TextEditingController();
    var mode = 'Cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(due.customerName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('amount'),
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.t('Amount received'),
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'Cash', label: Text(s.t('Cash'))),
                    ButtonSegment(value: 'Bank', label: Text(s.t('Bank'))),
                  ],
                  selected: {mode},
                  onSelectionChanged: (v) => setLocal(() => mode = v.first),
                ),
                if (mode == 'Bank') ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('reference'),
                    controller: reference,
                    decoration: InputDecoration(
                      labelText: s.t('UTR or cheque number'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(s.t('Money goes to the oldest bill first')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('Back')),
            ),
            FilledButton(
              key: const Key('receive-ok'),
              style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.t('Receive payment')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await widget.client.collect(
        due,
        double.tryParse(amount.text.trim()) ?? 0,
        mode,
        reference.text.trim(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.t('Received {0}, still due {1}', [
              rupees(done.amount),
              rupees(done.stillDue),
            ]),
          ),
        ),
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
    _reload();
  }

  void _reload() {
    setState(() {
      _dues = widget.client.dues();
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_dues);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Customer dues')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      body: PullToReload.list<Due>(
        future: _dues,
        onRefresh: _refresh,
        emptyText: s.t('Nobody owes money'),
        emptyKey: const Key('no-dues'),
        cards: (context, dues) => [
          for (final d in dues)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.customerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      rupees(d.due),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      s.t('{0} bills, oldest {1}', [d.bills, d.oldest ?? '-']),
                    ),
                    if (widget.canCollect) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: Key('receive-${d.customer}'),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(s.t('Receive payment')),
                        onPressed: () => _receive(d),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
