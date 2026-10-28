import 'package:flutter/material.dart';

import '../api/models.dart';
import 'order_card.dart';

/// One line of an order being built or edited: item, the price the rep types, and the bags with plus and minus.
class OrderLineTile extends StatefulWidget {
  const OrderLineTile({
    super.key,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });
  final OrderLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<OrderLineTile> createState() => _OrderLineTileState();
}

class _OrderLineTileState extends State<OrderLineTile> {
  late final _rate = TextEditingController(
    text: widget.line.rate > 0 ? _plain(widget.line.rate) : '',
  );

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  OrderLine get line => widget.line;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onRemove => widget.onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  key: Key('minus-${line.item.code}'),
                  iconSize: 28,
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (line.qty > 1) {
                      line.qty--;
                      onChanged();
                    } else {
                      onRemove();
                    }
                  },
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${line.qty}',
                    key: Key('qty-${line.item.code}'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton.filled(
                  key: Key('plus-${line.item.code}'),
                  iconSize: 28,
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    line.qty++;
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: Key('rate-${line.item.code}'),
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: 'Price',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      line.rate = double.tryParse(v) ?? 0;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('= ${rupees(line.amount)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
