import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/voice_text_field.dart';

/// Sales rep: pick customer, pick bags, set quantity, send for approval.
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late final Future<Catalog> _catalog = widget.client.catalog();
  final _remarks = TextEditingController();
  final _lines = <OrderLine>[];
  Customer? _customer;
  bool _busy = false;
  Order? _sent;
  String? _error;

  double get _total => _lines.fold(0, (sum, l) => sum + l.amount);

  Future<void> _send() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await widget.client.createOrder(
        _customer!,
        _lines,
        _remarks.text.trim(),
      );
      setState(() => _sent = order);
    } on Exception catch (e) {
      setState(() => _error = s.saveFailed(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem(Catalog catalog) async {
    final item = await showModalBottomSheet<CatalogItem>(
      context: context,
      builder: (context) => ListView(
        children: [
          for (final i in catalog.items)
            ListTile(
              key: Key('item-${i.code}'),
              minTileHeight: 64,
              title: Text(i.name, style: const TextStyle(fontSize: 20)),
              trailing: Text(rupees(i.rate)),
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
    if (item == null) return;
    final existing = _lines.where((l) => l.item.code == item.code);
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty++;
      } else {
        _lines.add(OrderLine(item));
      }
    });
  }

  Future<void> _pickCustomer(Catalog catalog) async {
    final c = await showModalBottomSheet<Customer>(
      context: context,
      builder: (context) => ListView(
        children: [
          for (final c in catalog.customers)
            ListTile(
              key: Key('customer-${c.name}'),
              minTileHeight: 64,
              title: Text(c.displayName, style: const TextStyle(fontSize: 20)),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
    if (c != null) setState(() => _customer = c);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_sent != null) return _SentView(order: _sent!);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('New order'))),
      body: FutureBuilder<Catalog>(
        future: _catalog,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(s.t('Cannot reach the server. Check the internet.')),
            );
          }
          final catalog = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                key: const Key('pick-customer'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  alignment: Alignment.centerLeft,
                ),
                icon: const Icon(Icons.storefront_outlined),
                label: Text(
                  _customer?.displayName ?? s.t('Choose customer'),
                  style: const TextStyle(fontSize: 20),
                ),
                onPressed: () => _pickCustomer(catalog),
              ),
              const SizedBox(height: 16),
              for (final l in _lines)
                _LineTile(
                  line: l,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _lines.remove(l)),
                ),
              OutlinedButton.icon(
                key: const Key('add-item'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  s.t('Add bags'),
                  style: const TextStyle(fontSize: 20),
                ),
                onPressed: () => _addItem(catalog),
              ),
              const SizedBox(height: 16),
              VoiceTextField(controller: _remarks, label: s.t('Remarks')),
              const SizedBox(height: 16),
              Text(
                '${s.t('Total')}: ${rupees(_total)}',
                key: const Key('total'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('send-order'),
                onPressed: _busy || _customer == null || _lines.isEmpty
                    ? null
                    : _send,
                child: _busy
                    ? const CircularProgressIndicator()
                    : Text(s.t('Send for approval')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
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

class _SentView extends StatelessWidget {
  const _SentView({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('New order'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            Icons.check_circle,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(
            s.t('Sent for approval'),
            key: const Key('sent'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          OrderCard(order: order),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.t('Back')),
          ),
        ],
      ),
    );
  }
}
