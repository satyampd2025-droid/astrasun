import 'package:flutter/material.dart';

import '../api/models.dart';
import '../strings.dart';

String rupees(double v) {
  final s = v.round().toString();
  // Indian digit grouping: 12,34,567
  if (s.length <= 3) return '₹$s';
  final head = s.substring(0, s.length - 3);
  final tail = s.substring(s.length - 3);
  final grouped = head.replaceAllMapped(
    RegExp(r'(\d)(?=(\d\d)+$)'),
    (m) => '${m[1]},',
  );
  return '₹$grouped,$tail';
}

/// The colour of a stage, from the tone the server sends: done (green), stop
/// (red), warn (amber), go (blue), else wait (grey).
Color toneColor(String tone) => switch (tone) {
  'done' => const Color(0xFF1E5B45),
  'stop' => const Color(0xFFB23A30),
  'warn' => const Color(0xFF9A6A00),
  'go' => const Color(0xFF2557A7),
  _ => const Color(0xFF5C655E),
};

/// Where something stands, as a coloured chip: the order's stage, or a truck's.
class StageChip extends StatelessWidget {
  const StageChip(this.stage, {super.key, this.tone = 'go'});
  final String stage;
  final String tone;

  @override
  Widget build(BuildContext context) =>
      _Chip(S.of(context).t(stage), toneColor(tone));
}

/// One order: customer, items, total, where it stands and the facts an
/// approver needs. With [onTap] the card opens the order in full.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.actions, this.onTap});
  final Order order;
  final Widget? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Card(
      key: Key('order-${order.name}'),
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    rupees(order.total),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              for (final i in order.items)
                Text(
                  '${i.itemName} × ${i.qty.round()}  @ ${rupees(i.rate)}',
                  style: theme.textTheme.bodyLarge,
                ),
              if (order.billed > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${s.t('Billed')} ${rupees(order.billed)}  ·  '
                  '${s.t('Paid')} ${rupees(order.paid)}'
                  '${order.withCollector > 0 ? '  ·  ${s.t('With collector')} ${rupees(order.withCollector)}' : ''}'
                  '  ·  ${s.t('Left to pay')} ${rupees(order.remaining)}',
                  key: Key('money-${order.name}'),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Chip(
                    s.t(order.stage),
                    toneColor(order.tone),
                    key: const Key('status-chip'),
                  ),
                  if (order.creditBreach)
                    _Chip(
                      s.t('Over credit limit'),
                      const Color(0xFFB23A30),
                      key: const Key('credit-chip'),
                    ),
                  if (order.belowPrice)
                    _Chip(
                      s.t('Below list price'),
                      const Color(0xFF9A6A00),
                      key: const Key('price-chip'),
                    ),
                  if (order.stockShort)
                    _Chip(
                      s.t('Stock is short'),
                      const Color(0xFF9A6A00),
                      key: const Key('stock-chip'),
                    ),
                ],
              ),
              if (order.creditLimit > 0) ...[
                const SizedBox(height: 8),
                Text(
                  s.t('Dues {0} + this order = {1} of limit {2}', [
                    rupees(order.creditOutstanding),
                    rupees(order.creditExposure),
                    rupees(order.creditLimit),
                  ]),
                ),
              ],
              if ((order.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('“${order.note}”'),
              ],
              if (actions != null) ...[const SizedBox(height: 12), actions!],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}
