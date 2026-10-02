import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../app_state.dart';
import '../home/role_tasks.dart';
import '../strings.dart';
import '../widgets/language_switch.dart';
import 'approvals_screen.dart';
import 'coming_soon_screen.dart';
import 'deliveries_screen.dart';
import 'dues_screen.dart';
import 'loading_screen.dart';
import 'my_orders_screen.dart';
import 'new_order_screen.dart';
import 'production_screens.dart';
import 'trucks_screen.dart';
import 'wheat_screens.dart';

/// "What I need to do now": big buttons for the user's mill roles.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tasks = tasksFor(state.me!.millRoles);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Namaste, {0}', [state.me!.fullName])),
        actions: [
          LanguageSwitch(state: state),
          IconButton(
            key: const Key('logout'),
            tooltip: s.t('Log out'),
            icon: const Icon(Icons.logout),
            onPressed: state.logout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.isDemo)
              Container(
                key: const Key('demo-banner'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(s.t('Demo: sample data, nothing is saved')),
              ),
            Text(
              s.t('What to do now'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              Text(
                s.t('No work assigned to your role yet. Ask the manager.'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TaskButton(task: task, client: state.client!),
              ),
          ],
        ),
      ),
    );
  }
}

/// The real screen for a task once it is built, else "coming soon".
Widget _screenFor(Task task, ErpNextClient client, S s) => switch (task.label) {
  'New order' => NewOrderScreen(client: client),
  'My orders' => MyOrdersScreen(client: client),
  'Approve orders' => ApprovalsScreen(client: client),
  'Loading queue' => LoadingScreen(client: client),
  'Bills and payments' => TrucksScreen(client: client, mode: TruckMode.invoice),
  'Send trucks' => TrucksScreen(client: client, mode: TruckMode.dispatch),
  'My deliveries' => DeliveriesScreen(client: client),
  'Collect payment' || 'Customer dues' => DuesScreen(client: client),
  'Truck entry' || 'Wheat purchase' => GateEntryScreen(client: client),
  'Weighbridge' => WeighbridgeScreen(client: client),
  'Check wheat lot' => LabScreen(client: client),
  'Start milling batch' => MillingScreen(client: client),
  'Report downtime' => DowntimeScreen(client: client),
  'Pack bags' => PackScreen(client: client),
  'Stock' => StockScreen(client: client),
  _ => ComingSoonScreen(title: s.t(task.label)),
};

class _TaskButton extends StatelessWidget {
  const _TaskButton({required this.task, required this.client});
  final Task task;
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => _screenFor(task, client, s))),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8DCD4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(task.icon, size: 30, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  s.t(task.label),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 32, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
