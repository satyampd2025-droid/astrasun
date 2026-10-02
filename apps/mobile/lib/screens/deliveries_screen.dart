import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/load_error.dart';
import '../widgets/voice_text_field.dart';

/// Driver: trucks on the road. Confirm each one with the receiver's name.
class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  late Future<List<LoadingTask>> _trucks = widget.client.myDeliveries();

  Future<void> _deliver(LoadingTask t) async {
    final s = S.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.customerName),
        content: VoiceTextField(
          key: const Key('receiver'),
          controller: controller,
          label: s.t('Received by'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Back')),
          ),
          FilledButton(
            key: const Key('receiver-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(s.t('Confirm delivery')),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.client.deliver(t, name, '');
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('Delivered to {0}', [name]))),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.saveFailed(e))),
      );
    }
    setState(() {
      _trucks = widget.client.myDeliveries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('My deliveries'))),
      body: FutureBuilder<List<LoadingTask>>(
        future: _trucks,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return LoadError(snap.error);
          final trucks = snap.data!;
          if (trucks.isEmpty) {
            return Center(
              child: Text(
                s.t('No deliveries waiting'),
                key: const Key('no-deliveries'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final t in trucks)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.customerName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(s.t('Vehicle {0}', [t.vehicleNo ?? '-'])),
                        const SizedBox(height: 8),
                        for (final i in t.items)
                          Text(
                            '${i.itemName}: ${i.qty.round()} ${s.t('bags')}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: Key('deliver-${t.id}'),
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(s.t('Confirm delivery')),
                          onPressed: () => _deliver(t),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
