import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orders_test.dart' show demoAs;

void main() {
  testWidgets('invoice comes first: bill a loaded truck, then it can leave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // Load the demo order, as the warehouse would.
    final state = await demoAs(tester, 'Mill Accounts');
    final client = state.client! as DemoClient;
    final waiting = (await client.loadingQueue()).first;
    final started = await client.startLoading(waiting);
    await client.markLoaded(started, 'MP09AB1234', {
      'ATTA-50KG': 40,
      'ATTA-10KG': 20,
    });

    await tester.tap(find.text('Bills and payments'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.text('Loaded'), findsOneWidget);

    // 40 x 2150 + 20 x 440 = 94,800. No e-way bill number is asked for (v2).
    expect(find.byKey(const Key('eway-SAL-ORD-0000')), findsNothing);
    await tester.tap(find.byKey(const Key('invoice-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-trucks')), findsOneWidget);

    final billed = await client.trucksToDispatch();
    expect(billed.single.total, 94800);
  });

  testWidgets('dispatch sees only billed trucks and lets them leave', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final state = AppState(fixedServer: '');
    await state.load();
    await state.startDemo('Mill Dispatch');
    final client = state.client! as DemoClient;
    final waiting = (await client.loadingQueue()).first;
    final started = await client.startLoading(waiting);
    final loaded = await client.markLoaded(started, 'MP09AB1234', {
      'ATTA-10KG': 20,
    });
    await tester.pumpWidget(MillApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send trucks'));
    await tester.pumpAndSettle();
    // Not billed yet: the truck cannot leave
    expect(find.byKey(const Key('no-trucks')), findsOneWidget);

    await client.invoiceTruck(loaded);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send trucks'));
    await tester.pumpAndSettle();
    expect(find.text('Loaded'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dispatch-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-trucks')), findsOneWidget);
  });
}
