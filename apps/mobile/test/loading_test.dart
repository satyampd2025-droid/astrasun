import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'orders_test.dart' show demoAs;

void main() {
  testWidgets('loader starts loading, picks the vehicle and marks loaded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await demoAs(tester, 'Mill Warehouse');
    await tester.tap(find.text('Loading queue'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsWidgets);

    // The vehicle must be picked
    await tester.tap(find.byKey(const Key('loaded-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.text('Pick the vehicle'), findsOneWidget);

    // No plus or minus: the warehouse loads what was ordered, or asks to change the order
    expect(find.byKey(const Key('less-ATTA-50KG')), findsNothing);
    expect(find.byKey(const Key('change-SAL-ORD-0000')), findsOneWidget);
    await tester.tap(find.byKey(const Key('vehicle-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP09AB1234 - Ramesh Driver').last);
    await tester.pumpAndSettle();
    // The driver comes with the vehicle
    expect(find.text('Driver Ramesh Driver'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loaded-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.textContaining('MP09AB1234'), findsWidgets);
    // It stays on the warehouse's screen, now to print the bill
    expect(find.byKey(const Key('print-SAL-ORD-0000')), findsOneWidget);
  });

  testWidgets('a change while loading sends the order back to the owner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await demoAs(tester, 'Mill Warehouse');
    await tester.tap(find.text('Loading queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-SAL-ORD-0000')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('change-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    // More than the order asks for is refused
    await tester.enterText(find.byKey(const Key('change-qty-ATTA-50KG')), '99');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('change-reason')),
        matching: find.byType(TextField),
      ),
      'Shop wants fewer',
    );
    await tester.tap(find.byKey(const Key('change-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('change-send')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('change-qty-ATTA-50KG')), '30');
    await tester.tap(find.byKey(const Key('change-send')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('change-waiting-SAL-ORD-0000')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('loaded-SAL-ORD-0000')), findsNothing);
  });

  testWidgets('an order approved by the owner appears for the loader', (
    tester,
  ) async {
    final state = await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Approve orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-SAL-ORD-0001')));
    await tester.pumpAndSettle();
    expect(state.client, isNotNull);
    final queue = await state.client!.loadingQueue();
    expect(queue.map((t) => t.salesOrder), contains('SAL-ORD-0001'));
  });

  testWidgets('loading screen reads in Hindi', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(fixedServer: '');
    await state.load();
    await state.startDemo('Mill Warehouse');
    await tester.pumpWidget(MillApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('लोडिंग सूची'));
    await tester.pumpAndSettle();
    expect(find.text('मंज़ूर'), findsOneWidget);
    expect(find.text('लोडिंग शुरू करें'), findsOneWidget);
  });
}
