import 'package:flutter/material.dart';

/// One big button on a role's home screen. [phase] is the build-plan phase
/// that delivers the screen; until then it opens a "coming soon" page.
class Task {
  const Task(this.label, this.icon, this.phase);
  final String label;
  final IconData icon;
  final int phase;
}

/// "What I need to do now", per mill role (PRD: role-based home screen).
const Map<String, List<Task>> roleTasks = {
  'Mill Owner': [
    Task('Approve orders', Icons.verified_outlined, 2),
    Task('Today at the mill', Icons.dashboard_outlined, 5),
    Task('Customer dues', Icons.account_balance_wallet_outlined, 2),
    Task('Alerts', Icons.notifications_active_outlined, 5),
    Task('Reports', Icons.bar_chart, 5),
  ],
  'Mill Manager': [
    Task('Plan production', Icons.event_note_outlined, 4),
    Task('Trucks at the mill', Icons.local_shipping_outlined, 3),
    Task('Stock', Icons.inventory_2_outlined, 2),
  ],
  'Mill Sales': [
    Task('New order', Icons.add_shopping_cart, 2),
    Task('My orders', Icons.receipt_long_outlined, 2),
    Task('Customer dues', Icons.account_balance_wallet_outlined, 2),
  ],
  'Mill Purchase': [
    Task('Wheat purchase', Icons.agriculture_outlined, 3),
    Task('Supplier rates', Icons.price_change_outlined, 3),
  ],
  'Mill Gate': [
    Task('Truck entry', Icons.local_shipping_outlined, 3),
    Task('Weighbridge', Icons.scale_outlined, 3),
  ],
  'Mill QC': [
    Task('Check wheat lot', Icons.science_outlined, 3),
    Task('Check flour', Icons.biotech_outlined, 4),
  ],
  'Mill Production': [
    Task('Start milling batch', Icons.precision_manufacturing_outlined, 4),
    Task('Report downtime', Icons.report_problem_outlined, 4),
  ],
  'Mill Packing': [
    Task('Pack bags', Icons.shopping_bag_outlined, 4),
    Task('Stock', Icons.inventory_2_outlined, 2),
  ],
  'Mill Warehouse': [Task('Loading queue', Icons.forklift, 2)],
  'Mill Dispatch': [Task('Send trucks', Icons.local_shipping_outlined, 2)],
  'Mill Driver': [
    Task('My deliveries', Icons.delivery_dining_outlined, 2),
    Task('Collect payment', Icons.payments_outlined, 2),
  ],
  'Mill Accounts': [
    Task('Bills and payments', Icons.request_quote_outlined, 2),
    Task('Customer dues', Icons.account_balance_wallet_outlined, 2),
  ],
  'Mill Auditor': [Task('Change log', Icons.history, 1)],
};

/// Tasks for someone with several roles, without repeating a task.
List<Task> tasksFor(List<String> roles) {
  final seen = <String>{};
  return [
    for (final role in roles)
      for (final task in roleTasks[role] ?? const <Task>[])
        if (seen.add(task.label)) task,
  ];
}
