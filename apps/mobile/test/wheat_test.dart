import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;

void tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('gate enters a truck once everything is filled in', (
    tester,
  ) async {
    tallPhone(tester);
    final state = await demoAs(tester, 'Mill Gate');
    await tester.tap(find.text('Truck entry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('save-truck'))).enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('pick-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('supplier-farmer1')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vehicle')), 'mp09ab1111');
    await tester.enterText(find.byKey(const Key('slip')), '18000');
    await tester.enterText(find.byKey(const Key('rate')), '2600');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-truck')));
    await tester.pumpAndSettle();
    final trucks = await state.client!.wheatTrucks();
    expect(trucks.map((t) => t.vehicleNo), contains('MP09AB1111'));
    expect(trucks.last.status, 'At Gate');
  });

  testWidgets('weighbridge weighs in, then flags a weight gap on the way out', (
    tester,
  ) async {
    tallPhone(tester);
    final state = await demoAs(tester, 'Mill Gate');
    final client = state.client! as DemoClient;
    final seeded = (await client.wheatTrucks()).first;
    await client.checkWheat(
      seeded,
      moisture: 12,
      foreignMatter: 1,
      broken: 1,
      decision: 'Release',
    );
    await tester.tap(find.text('Weighbridge'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reading-WL-26-0001')),
      '8300', // net 19,700 against a 20,000 slip
    );
    await tester.tap(find.byKey(const Key('weigh-WL-26-0001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weight-alert')), findsOneWidget);
    expect(find.byKey(const Key('no-trucks')), findsOneWidget);
  });

  testWidgets('lab cannot release wet wheat, can hold it, then release', (
    tester,
  ) async {
    tallPhone(tester);
    final state = await demoAs(tester, 'Mill QC');
    await tester.tap(find.text('Check wheat lot'));
    await tester.pumpAndSettle();
    Future<void> fill(String m, String reason) async {
      await tester.enterText(find.byKey(const Key('moisture-WL-26-0001')), m);
      await tester.enterText(find.byKey(const Key('foreign-WL-26-0001')), '1');
      await tester.enterText(find.byKey(const Key('broken-WL-26-0001')), '1');
      if (reason.isNotEmpty) {
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('remarks-WL-26-0001')),
            matching: find.byType(TextField),
          ),
          reason,
        );
      }
    }

    await fill('16', '');
    await tester.tap(find.byKey(const Key('release-WL-26-0001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-failed')), findsOneWidget);
    expect((await state.client!.wheatTrucks()).first.status, 'Weighed In');

    await fill('16', 'Too wet, dry it');
    await tester.tap(find.byKey(const Key('hold-WL-26-0001')));
    await tester.pumpAndSettle();
    expect((await state.client!.wheatTrucks()).first.status, 'On Hold');

    await fill('12.5', '');
    await tester.tap(find.byKey(const Key('release-WL-26-0001')));
    await tester.pumpAndSettle();
    expect((await state.client!.wheatTrucks()).first.status, 'Released');
    expect(find.byKey(const Key('no-trucks')), findsOneWidget);
  });
}
