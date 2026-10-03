import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;

void main() {
  testWidgets(
    'owner adds a vehicle with its driver and the warehouse can pick it',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final state = await demoAs(tester, 'Mill Owner');
      await tester.tap(find.text('Vehicles'));
      await tester.pumpAndSettle();
      expect(find.text('MP09AB1234'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-vehicle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('vehicle-number')),
        'mp 09 ef 9999',
      );
      await tester.enterText(find.byKey(const Key('driver-name')), 'Mohan Lal');
      await tester.tap(find.byKey(const Key('vehicle-save')));
      await tester.pumpAndSettle();
      expect(find.text('MP09EF9999'), findsOneWidget);
      expect(find.text('Mohan Lal'), findsOneWidget);

      final listed = await state.client!.vehicles();
      expect(listed.map((v) => v.vehicleNo), contains('MP09EF9999'));
    },
  );

  testWidgets('a vehicle switched off is not offered for loading', (
    tester,
  ) async {
    final state = await demoAs(tester, 'Mill Owner');
    final client = state.client! as DemoClient;
    await client.saveVehicle(
      vehicleNo: 'MP09CD5678',
      driverName: 'Suresh Kumar',
      enabled: false,
    );
    expect(
      (await client.vehicles()).map((v) => v.vehicleNo),
      isNot(contains('MP09CD5678')),
    );
    expect(
      (await client.vehicles(all: true)).map((v) => v.vehicleNo),
      contains('MP09CD5678'),
    );
  });

  testWidgets('the driver sees where the order goes and what is in it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Driver');
    final client = state.client! as DemoClient;
    final started = await client.startLoading(
      (await client.loadingQueue()).first,
    );
    await client.markLoaded(started, 'MP09AB1234', {
      'ATTA-50KG': 40,
      'ATTA-10KG': 20,
    });

    await tester.tap(find.text('My deliveries'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.text('Shop 4, Main Bazaar, Indore'), findsOneWidget);
    expect(find.text('9800000002'), findsOneWidget);
    expect(find.text('Atta 50 kg: 40 bags'), findsOneWidget);
    expect(find.text('Rs 86000'), findsOneWidget);
    expect(find.text('Total: Rs 94800'), findsOneWidget);
    // It has not left yet, so there is nothing to confirm
    expect(find.byKey(const Key('not-left-SAL-ORD-0000')), findsOneWidget);
    expect(find.byKey(const Key('deliver-SAL-ORD-0000')), findsNothing);
  });
}
