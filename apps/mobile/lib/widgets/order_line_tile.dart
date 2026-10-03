import 'package:flutter/material.dart';

import '../api/models.dart';
import 'order_card.dart';

/// One line of an order being built or edited: item, rate, and the bags with plus and minus.
class OrderLineTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${rupees(line.rate)}  =  ${rupees(line.amount)}'),
                ],
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
      ),
    );
  }
}
