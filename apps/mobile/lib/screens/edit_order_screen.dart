import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/load_error.dart';
import '../widgets/order_card.dart';
import '../widgets/order_line_tile.dart';
import '../widgets/voice_text_field.dart';

/// The sales rep or the warehouse changes an order: bags, items taken off or
/// added. The owner approves the change; nothing can be edited once a truck has left.
/// Pops with the order the server sent back.
class EditOrderScreen extends StatefulWidget {
  const EditOrderScreen({super.key, required this.client, required this.order});
  final ErpNextClient client;
  final Order order;

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  late final Future<Catalog> _catalog = widget.client.catalog();
  final _reason = TextEditingController();
  late final List<OrderLine> _lines = [
    for (final i in widget.order.items)
      OrderLine(
        CatalogItem(i.itemCode, i.itemName, i.rate),
        qty: i.qty.round(),
        rate: i.rate,
      ),
  ];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0, (sum, l) => sum + l.amount);

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

  Future<void> _send() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await widget.client.editOrder(
        widget.order,
        _lines,
        _reason.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(done);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = s.saveFailed(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Change order'))),
      body: FutureBuilder<Catalog>(
        future: _catalog,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return LoadError(snap.error);
          final catalog = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.order.customerName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final l in _lines)
                OrderLineTile(
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
              VoiceTextField(
                key: const Key('edit-reason'),
                controller: _reason,
                label: s.t('Reason'),
              ),
              const SizedBox(height: 16),
              Text(
                '${s.t('Total')}: ${rupees(_total)}',
                key: const Key('total'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'The order goes to the owner for approval. A printed bill is cancelled and loading starts again.',
                ),
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
                key: const Key('send-edit'),
                onPressed:
                    _busy || _lines.isEmpty || _reason.text.trim().isEmpty
                    ? null
                    : _send,
                child: _busy
                    ? const CircularProgressIndicator()
                    : Text(s.t('Send to the owner')),
              ),
            ],
          );
        },
      ),
    );
  }
}
