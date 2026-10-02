import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../app_state.dart';
import '../home/role_tasks.dart';
import '../strings.dart';
import '../widgets/language_switch.dart';
import 'approvals_screen.dart';
import 'coming_soon_screen.dart';
import 'dashboard_screen.dart';
import 'deliveries_screen.dart';
import 'dues_screen.dart';
import 'loading_screen.dart';
import 'my_orders_screen.dart';
import 'new_order_screen.dart';
import 'production_screens.dart';
import 'reports_screen.dart';
import 'trucks_screen.dart';
import 'wheat_screens.dart';

/// "What I need to do now" for the user's mill roles: a tiles dashboard for
/// office roles, one big "next step" card for floor staff.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final roles = state.me!.millRoles;
    final tasks = tasksFor(roles);
    final client = state.client!;
    final collect = mayCollect(roles);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(s.t('Namaste, {0}', [state.me!.fullName])),
        actions: [
          LanguageSwitch(state: state),
          IconButton(
            key: const Key('logout'),
            tooltip: s.t('Log out'),
            icon: const Icon(Icons.logout),
            onPressed: state.logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (state.isDemo)
              Container(
                key: const Key('demo-banner'),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF8A6100)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.t('Demo: sample data, nothing is saved')),
                    ),
                  ],
                ),
              ),
            if (tasks.isEmpty)
              Text(
                s.t('No work assigned to your role yet. Ask the manager.'),
                style: text.bodyLarge,
              )
            else if (isOffice(roles)) ...[
              _SectionTitle(s.t('What to do now')),
              _TileGrid(tasks: tasks, client: client, collect: collect),
            ] else ...[
              _SectionTitle(s.t('Next for you')),
              _NextStepCard(task: tasks.first, client: client, collect: collect),
              if (tasks.length > 1) ...[
                const SizedBox(height: 24),
                _SectionTitle(s.t('More work')),
                for (final task in tasks.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskRow(task: task, client: client, collect: collect),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

void _open(
  BuildContext context,
  Task task,
  ErpNextClient client,
  bool collect,
) {
  final s = S.of(context);
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => _screenFor(task, client, s, collect)));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Soft colour pairs (background, icon) so each tile is easy to tell apart.
const _tints = [
  (Color(0xFFE3F1EA), Color(0xFF1E5B45)),
  (Color(0xFFFFF0D9), Color(0xFFB26A00)),
  (Color(0xFFE4EDFB), Color(0xFF2557A7)),
  (Color(0xFFFBE6E8), Color(0xFFB0303F)),
  (Color(0xFFEEE7FA), Color(0xFF5B3BA0)),
  (Color(0xFFE0F3F4), Color(0xFF15707A)),
];

class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.tasks,
    required this.client,
    required this.collect,
  });
  final List<Task> tasks;
  final ErpNextClient client;
  final bool collect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 128,
      ),
      itemBuilder: (context, i) {
        final task = tasks[i];
        final (bg, fg) = _tints[i % _tints.length];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context, task, client, collect),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(task.icon, color: fg, size: 26),
                  ),
                  const Spacer(),
                  Text(
                    S.of(context).t(task.label),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The one thing a floor worker should do next, big and green.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.task,
    required this.client,
    required this.collect,
  });
  final Task task;
  final ErpNextClient client;
  final bool collect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, task, client, collect),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(task.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                s.t(task.label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    s.t('Tap to start'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The real screen for a task once it is built, else "coming soon".
Widget _screenFor(Task task, ErpNextClient client, S s, bool collect) =>
    switch (task.label) {
      'New order' => NewOrderScreen(client: client),
      'My orders' => MyOrdersScreen(client: client),
      'Approve orders' => ApprovalsScreen(client: client),
      'Loading queue' => LoadingScreen(client: client),
      'Bills and payments' => TrucksScreen(client: client, mode: TruckMode.invoice),
      'Send trucks' => TrucksScreen(client: client, mode: TruckMode.dispatch),
      'My deliveries' => DeliveriesScreen(client: client),
      'Collect payment' || 'Customer dues' => DuesScreen(
        client: client,
        canCollect: collect,
      ),
      'Truck entry' || 'Wheat purchase' => GateEntryScreen(client: client),
      'Weighbridge' => WeighbridgeScreen(client: client),
      'Check wheat lot' => LabScreen(client: client),
      'Start milling batch' => MillingScreen(client: client),
      'Report downtime' => DowntimeScreen(client: client),
      'Pack bags' => PackScreen(client: client),
      'Stock' => StockScreen(client: client),
      'Today at the mill' => DashboardScreen(client: client),
      'Alerts' => AlertsScreen(client: client),
      'Reports' => ReportsScreen(client: client),
      _ => ComingSoonScreen(title: s.t(task.label)),
    };

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.client,
    required this.collect,
  });
  final Task task;
  final ErpNextClient client;
  final bool collect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(task.icon, color: scheme.primary),
        ),
        title: Text(
          S.of(context).t(task.label),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context, task, client, collect),
      ),
    );
  }
}
