import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'orders_test.dart' show demoAs;

void main() {
  testWidgets('loader starts loading, enters the vehicle and marks loaded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await demoAs(tester, 'Mill Warehouse');
    await tester.tap(find.text('Loading queue'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsWidgets);

    // Vehicle number is required
    await tester.tap(find.byKey(const Key('loaded-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the vehicle number'), findsOneWidget);

    await tester.tap(find.byKey(const Key('less-ATTA-50KG')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('qty-ATTA-50KG'))).data,
      '39',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('vehicle-SAL-ORD-0000')),
        matching: find.byType(TextField),
      ),
      'MP09AB1234',
    );
    await tester.tap(find.byKey(const Key('loaded-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.textContaining('MP09AB1234'), findsOneWidget);
    expect(find.byKey(const Key('nothing-to-load')), findsOneWidget);
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
    expect(find.text('इंतज़ार में'), findsOneWidget);
    expect(find.text('लोडिंग शुरू करें'), findsOneWidget);
  });
}
