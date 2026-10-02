import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> demoAs(WidgetTester tester, String role) async {
  SharedPreferences.setMockInitialValues({'language': 'en'});
  final state = AppState(fixedServer: '');
  await state.load();
  await state.startDemo(role);
  await tester.pumpWidget(MillApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('sales rep books an order and sends it for approval', (
    tester,
  ) async {
    await demoAs(tester, 'Mill Sales');
    await tester.tap(find.text('New order'));
    await tester.pumpAndSettle();

    // Cannot send before choosing a customer and bags
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('send-order'))).enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('pick-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-gupta')));
    await tester.pumpAndSettle();
    expect(find.text('Gupta Traders'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-ATTA-50KG')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plus-ATTA-50KG')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qty-ATTA-50KG')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Total: ₹4,300'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('send-order')));
    await tester.tap(find.byKey(const Key('send-order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sent')), findsOneWidget);
    expect(find.text('Gupta Traders'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
  });

  testWidgets('quantity can be lowered and a line removed', (tester) async {
    await demoAs(tester, 'Mill Sales');
    await tester.tap(find.text('New order'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-ATTA-5KG')));
    await tester.pumpAndSettle();
    expect(find.text('Total: ₹230'), findsOneWidget);
    await tester.tap(find.byKey(const Key('minus-ATTA-5KG')));
    await tester.pumpAndSettle();
    expect(find.text('Total: ₹0'), findsOneWidget);
    expect(find.byKey(const Key('qty-ATTA-5KG')), findsNothing);
  });

  testWidgets('owner sees credit and stock warnings and approves in one tap', (
    tester,
  ) async {
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Approve orders'));
    await tester.pumpAndSettle();

    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.byKey(const Key('credit-chip')), findsOneWidget);
    expect(find.text('Over credit limit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-SAL-ORD-0001')));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsNothing);
    expect(find.text('Verma Distributors'), findsOneWidget);
  });

  testWidgets('send back needs a reason, then the order leaves the list', (
    tester,
  ) async {
    // A tall phone, so all three orders are on screen
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Approve orders'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reject-SAL-ORD-0003')));
    await tester.pumpAndSettle();
    // Empty reason does nothing
    await tester.tap(find.byKey(const Key('reason-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reason-ok')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Customer cancelled');
    await tester.tap(find.byKey(const Key('reason-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Gupta Traders'), findsNothing);
  });

  testWidgets('rep sees their orders and the owner’s decision', (tester) async {
    await demoAs(tester, 'Mill Sales');
    await tester.tap(find.text('My orders'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.text('Pending Approval'), findsWidgets);
  });

  testWidgets('orders screens read in Hindi', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(fixedServer: '');
    await state.load();
    await state.startDemo('Mill Owner');
    await tester.pumpWidget(MillApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ऑर्डर मंज़ूर करें'));
    await tester.pumpAndSettle();
    expect(find.text('उधार सीमा से ऊपर'), findsOneWidget);
    expect(find.text('मंज़ूर करें'), findsWidgets);
  });
}
