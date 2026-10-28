import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;

void main() {
  testWidgets('the bell shows unread alerts and clears them once opened', (
    tester,
  ) async {
    await demoAs(tester, 'Mill Owner');
    expect(find.byKey(const Key('bell-badge')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alert-A1')), findsOneWidget);
    expect(find.textContaining('Sharma Kirana Store'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
}
