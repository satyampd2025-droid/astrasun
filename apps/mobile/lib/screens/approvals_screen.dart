import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/voice_text_field.dart';

/// Owner / manager: orders waiting for a decision, one tap to approve.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late Future<List<Order>> _orders = widget.client.pendingApprovals();

  void _reload() {
    setState(() {
      _orders = widget.client.pendingApprovals();
    });
  }

  Future<void> _run(Future<Order> Function() action) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await action();
      messenger.showSnackBar(
        SnackBar(content: Text('${done.customerName}: ${s.t(done.status)}')),
      );
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('Could not save. Try again.'))),
      );
    }
    _reload();
  }

  /// Asks for a reason (spoken or typed), then runs [action] with it.
  Future<void> _withReason(
    String title,
    Future<Order> Function(String reason) action,
  ) async {
    final s = S.of(context);
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: VoiceTextField(controller: controller, label: s.t('Reason')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Back')),
          ),
          FilledButton(
            key: const Key('reason-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(s.t('Done')),
          ),
        ],
      ),
    );
    if (reason != null) await _run(() => action(reason));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Approve orders'))),
      body: FutureBuilder<List<Order>>(
        future: _orders,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(s.t('Cannot reach the server. Check the internet.')),
            );
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return Center(
              child: Text(
                s.t('No orders waiting for you'),
                key: const Key('no-pending'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final o in orders)
                OrderCard(
                  order: o,
                  actions: Column(
                    children: [
                      FilledButton.icon(
                        key: Key('approve-${o.name}'),
                        icon: const Icon(Icons.check),
                        label: Text(s.t('Approve')),
                        onPressed: () =>
                            _run(() => widget.client.approve(o.name)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: Key('sendback-${o.name}'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              onPressed: () => _withReason(
                                s.t('Send back'),
                                (r) => widget.client.sendBack(o.name, r),
                              ),
                              child: Text(s.t('Send back')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              key: Key('reject-${o.name}'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                foregroundColor: const Color(0xFFB23A30),
                              ),
                              onPressed: () => _withReason(
                                s.t('Reject'),
                                (r) => widget.client.reject(o.name, r),
                              ),
                              child: Text(s.t('Reject')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
