import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;
import 'wheat_test.dart' show tallPhone;

void main() {
  testWidgets('owner reads the month P&L and a reconciled stock statement', (
    tester,
  ) async {
    tallPhone(tester);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('₹74,000'), findsOneWidget);
    expect(find.text('15.2%'), findsOneWidget);
    expect(find.byKey(const Key('reconciled')), findsOneWidget);
    expect(find.text('ATTA-BULK'), findsOneWidget);
  });

  testWidgets('approver sees a below-list-price warning', (tester) async {
    tallPhone(tester);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Approve orders'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('price-chip')), findsOneWidget);
  });
}
