import 'package:flutter/material.dart';

import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';

/// One order in full: what it is, where it stands, and the steps it has been through.
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(order.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OrderCard(order: order),
          if (order.timeline.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                s.t('Order status'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (var i = 0; i < order.timeline.length; i++)
                      _Step(
                        index: i,
                        row: order.timeline[i],
                        tone: order.tone,
                        last: i == order.timeline.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the timeline: a tick for what is done, a filled dot for where
/// the order is now, an empty circle for what is still to come.
class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.row,
    required this.tone,
    required this.last,
  });
  final int index;
  final TimelineRow row;
  final String tone;
  final bool last;

  static const _green = Color(0xFF1E5B45);
  static const _quiet = Color(0xFFB8BEB9);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final done = row.state == 'done';
    final current = row.state == 'current';
    final colour = done
        ? _green
        : current
        ? toneColor(tone)
        : _quiet;
    return IntrinsicHeight(
      key: Key('timeline-$index-${row.state}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: colour,
                  size: 26,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? _green : const Color(0xFFD9DDDA),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: last ? 0 : 18),
              child: Text(
                s.t(row.label),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: row.state == 'todo'
                      ? const Color(0xFF7A827C)
                      : const Color(0xFF1B211D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
