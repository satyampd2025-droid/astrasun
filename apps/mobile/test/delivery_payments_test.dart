import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;

void main() {
  testWidgets('driver confirms a delivery with the receiver name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Driver');
    final client = state.client! as DemoClient;
    final waiting = (await client.loadingQueue()).first;
    final started = await client.startLoading(waiting);
    final loaded = await client.markLoaded(started, 'MP09AB1234', {
      'ATTA-10KG': 20,
    });
    await client.invoiceTruck(loaded, '');
    await client.dispatchTruck(loaded);

    await tester.tap(find.text('My deliveries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deliver-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    // A name is required
    await tester.tap(find.byKey(const Key('receiver-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receiver-ok')), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('receiver')),
        matching: find.byType(TextField),
      ),
      'Ramesh',
    );
    await tester.tap(find.byKey(const Key('receiver-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-deliveries')), findsOneWidget);
  });

  testWidgets('driver collects part payment, then the rest', (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Driver');
    await tester.tap(find.text('Collect payment'));
    await tester.pumpAndSettle();
    expect(find.text('Verma Distributors'), findsOneWidget);

    // More than owed is refused
    await tester.tap(find.byKey(const Key('receive-verma')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '70000');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect((await state.client!.dues()).first.due, 60000);

    await tester.tap(find.byKey(const Key('receive-verma')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '25000');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect((await state.client!.dues()).first.due, 35000);

    await tester.tap(find.byKey(const Key('receive-verma')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receive-ok'))); // no UTR: refused
    await tester.pumpAndSettle();
    expect((await state.client!.dues()).first.due, 35000);

    await tester.tap(find.byKey(const Key('receive-verma')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reference')), 'UTR123456');
    await tester.tap(find.byKey(const Key('receive-ok')));
    await tester.pumpAndSettle();
    expect((await state.client!.dues()).map((d) => d.customer), ['sharma']);
  });
}
