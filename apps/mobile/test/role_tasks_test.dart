import 'package:atulyaa_mill/home/role_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every mill role from the backend has a home screen', () {
    const backendRoles = [
      'Mill Owner',
      'Mill Manager',
      'Mill Sales',
      'Mill Purchase',
      'Mill Gate',
      'Mill QC',
      'Mill Production',
      'Mill Packing',
      'Mill Warehouse',
      'Mill Dispatch',
      'Mill Driver',
      'Mill Accounts',
      'Mill Auditor',
    ];
    for (final role in backendRoles) {
      expect(roleTasks[role], isNotEmpty, reason: role);
    }
  });

  test('a task shared by two roles shows once', () {
    final labels = tasksFor([
      'Mill Sales',
      'Mill Accounts',
    ]).map((t) => t.label).toList();
    expect(labels.where((l) => l == 'Customer dues').length, 1);
  });

  test('unknown roles give no tasks', () {
    expect(tasksFor(['Something Else']), isEmpty);
  });
}
