import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show startApp, logIn;

Future<void> logInAs(WidgetTester tester, List<String> roles) async {
  await startApp(tester, roles);
  await tester.tap(find.text('EN'));
  await tester.pumpAndSettle();
  await logIn(tester);
}

void main() {
  testWidgets('office roles get a tiles dashboard', (tester) async {
    await logInAs(tester, ['Mill Owner']);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('What to do now'), findsOneWidget);
    expect(find.text('Next for you'), findsNothing);
  });

  testWidgets('floor staff get one big next step, then the rest', (
    tester,
  ) async {
    await logInAs(tester, ['Mill Gate']);
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Next for you'), findsOneWidget);
    expect(find.text('Truck entry'), findsOneWidget);
    expect(find.text('More work'), findsOneWidget);
    expect(find.text('Weighbridge'), findsOneWidget);
  });
}
