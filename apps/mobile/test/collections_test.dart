import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_stage_test.dart' show host;
import 'orders_test.dart' show demoAs;
import 'package:atulyaa_mill/screens/settle_cash_screen.dart';

/// The demo order loaded and billed: 40 x 2150 + 20 x 440 = Rs 94,800.
Future<void> billedOrder(DemoClient client) async {
  final started = await client.startLoading(
    (await client.loadingQueue()).first,
  );
  final loaded = await client.markLoaded(started, 'MP09AB1234', {
    'ATTA-50KG': 40,
    'ATTA-10KG': 20,
  });
  await client.invoiceTruck(loaded);
}

void main() {
  testWidgets('a rep collects part of the money; it shows as with them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Sales');
    await billedOrder(state.client! as DemoClient);

    await tester.tap(find.text('My collections'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('left-SAL-ORD-0000'))).data,
      contains('94,800'),
    );

    await tester.tap(find.byKey(const Key('collect-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    // More than is left is refused
    await tester.enterText(find.byKey(const Key('amount')), '100000');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-failed')), findsNothing);
    expect(find.text('Sharma Kirana Store'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collect-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '50000');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('holding')), findsOneWidget);
    expect(find.textContaining('50000'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('left-SAL-ORD-0000'))).data,
      contains('44,800'),
    );
  });

  testWidgets('bank money needs the UTR', (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Sales');
    final client = state.client! as DemoClient;
    await billedOrder(client);
    await tester.tap(find.text('My collections'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collect-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect((await client.myCollections()).holding, 0);
    await tester.tap(find.byKey(const Key('collect-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reference')), 'UTR123456');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect((await client.myCollections()).holding, 94800);
  });

  testWidgets('the owner settles the cash that was handed in', (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final client = DemoClient('Mill Sales');
    await billedOrder(client);
    await client.collectOnOrder('SAL-ORD-0000', 30000, 'Cash', '');
    await tester.pumpWidget(host(SettleCashScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Rep'), findsOneWidget);
    expect(find.text('₹30,000'), findsWidgets);
    await tester.tap(find.byKey(const Key('settle-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nothing-to-settle')), findsOneWidget);
    // Now it counts as paid on the order
    final money = (await client.myCollections()).orders.single;
    expect(money.paid, 30000);
    expect(money.withCollector, 0);
    expect(money.remaining, 64800);
  });

  testWidgets('the owner recording money directly settles it at once', (
    tester,
  ) async {
    final client = DemoClient('Mill Owner');
    await billedOrder(client);
    final c = await client.collectOnOrder('SAL-ORD-0000', 1000, 'Cash', '');
    expect(c.status, 'Settled');
    expect(await client.cashToSettle(), isEmpty);
  });

  testWidgets('a driver collects from the delivery card', (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Driver');
    final client = state.client! as DemoClient;
    await billedOrder(client);
    await tester.tap(find.text('My deliveries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collect-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '20000');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect((await client.myCollections()).holding, 20000);
  });

  testWidgets('every field role has a money screen and the owner can settle', (
    tester,
  ) async {
    final state = await demoAs(tester, 'Mill Owner');
    expect(state.client, isNotNull);
    expect(find.text('Settle cash'), findsOneWidget);
  });
}
