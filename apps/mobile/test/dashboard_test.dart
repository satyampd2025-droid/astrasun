import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'orders_test.dart' show demoAs;
import 'wheat_test.dart' show tallPhone;

void main() {
  testWidgets('owner sees the day, dues by age and alerts', (tester) async {
    tallPhone(tester);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Today at the mill'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-sales')), findsOneWidget);
    expect(find.text('₹1,86,500'), findsOneWidget);
    expect(find.text('₹72,000'), findsOneWidget); // dues 60,000 + 12,000
    expect(find.text('0-30 days'), findsOneWidget);
    expect(find.text('Alerts (3)'), findsOneWidget);
    expect(find.textContaining('MP04AB9999'), findsOneWidget);
  });

  testWidgets('alerts screen lists everything unusual', (tester) async {
    tallPhone(tester);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('extraction 72.0%'), findsOneWidget);
    expect(find.textContaining('over the credit limit'), findsOneWidget);
  });

  testWidgets('dashboard reads in Hindi', (tester) async {
    tallPhone(tester);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(fixedServer: '');
    await state.load();
    await state.startDemo('Mill Owner');
    await tester.pumpWidget(MillApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('आज मिल में'));
    await tester.pumpAndSettle();
    expect(find.text('आज की बिक्री'), findsOneWidget);
    expect(find.text('अलर्ट (3)'), findsOneWidget);
  });
}
