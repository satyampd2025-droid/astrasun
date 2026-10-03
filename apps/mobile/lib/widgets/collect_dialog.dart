import 'package:flutter/material.dart';

import '../strings.dart';

/// What the person entered when taking money from a shop.
class CollectedMoney {
  const CollectedMoney(this.amount, this.mode, this.reference);
  final double amount;
  final String mode;
  final String reference;
}

/// Asks how much was received and how (cash, or bank with the UTR).
/// [remaining] is what is left on the order; it fills the amount to start with.
Future<CollectedMoney?> askCollection(
  BuildContext context, {
  required String title,
  required double remaining,
}) {
  final s = S.of(context);
  final amount = TextEditingController(text: remaining.round().toString());
  final reference = TextEditingController();
  var mode = 'Cash';
  return showDialog<CollectedMoney>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(title),
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
                  helperText: s.t('Left to pay: ₹ {0}', [
                    remaining.round().toString(),
                  ]),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Back')),
          ),
          FilledButton(
            key: const Key('receive-ok'),
            onPressed: () {
              final value = double.tryParse(amount.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(
                context,
                CollectedMoney(value, mode, reference.text.trim()),
              );
            },
            child: Text(s.t('Mark collected')),
          ),
        ],
      ),
    ),
  );
}
