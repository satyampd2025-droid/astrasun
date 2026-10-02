import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';

/// Mill role -> how a person would name their job.
const demoRoles = {
  'Mill Owner': 'Owner',
  'Mill Manager': 'Manager',
  'Mill Sales': 'Sales',
  'Mill Purchase': 'Purchase',
  'Mill Gate': 'Gate / weighbridge',
  'Mill QC': 'Lab',
  'Mill Production': 'Mill operator',
  'Mill Packing': 'Packing',
  'Mill Warehouse': 'Loading',
  'Mill Dispatch': 'Dispatch',
  'Mill Driver': 'Driver',
  'Mill Accounts': 'Accounts',
  'Mill Auditor': 'Auditor',
};

/// Pick a job to see the app the way that person will.
class DemoRoleScreen extends StatelessWidget {
  const DemoRoleScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Who are you?'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in demoRoles.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await state.startDemo(entry.key);
                  navigator.popUntil((route) => route.isFirst);
                },
                child: Text(
                  s.t(entry.value),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
