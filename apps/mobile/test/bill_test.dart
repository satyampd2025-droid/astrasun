import 'dart:typed_data';

import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:atulyaa_mill/print_bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;

void main() {
  late List<String> printed;

  setUp(() {
    printed = [];
    billPrinter = (Uint8List pdf, String name) async {
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      printed.add(name);
    };
  });

  Future<void> loadDemoOrder(DemoClient client) async {
    final started = await client.startLoading(
      (await client.loadingQueue()).first,
    );
    await client.markLoaded(started, 'MP09AB1234', {
      'ATTA-50KG': 40,
      'ATTA-10KG': 20,
    });
  }

  testWidgets('the warehouse prints the bill, then the truck can leave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Warehouse');
    final client = state.client! as DemoClient;
    await loadDemoOrder(client);
    await tester.tap(find.text('Loading queue'));
    await tester.pumpAndSettle();

    // No bill yet, so the truck cannot be sent
    expect(find.byKey(const Key('left-SAL-ORD-0000')), findsNothing);
    await tester.tap(find.byKey(const Key('print-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(printed, ['SINV-0000']);
    expect(find.byKey(const Key('left-SAL-ORD-0000')), findsOneWidget);

    // Printing again reprints the same bill
    await tester.tap(find.byKey(const Key('print-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(printed, ['SINV-0000', 'SINV-0000']);

    await tester.tap(find.byKey(const Key('left-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('print-SAL-ORD-0000')), findsNothing);
    expect((await client.myDeliveries()).single.status, 'Dispatched');
  });

  testWidgets('a change after printing goes to the owner, then a new bill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Warehouse');
    final client = state.client! as DemoClient;
    await loadDemoOrder(client);
    await tester.tap(find.text('Loading queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print-SAL-ORD-0000')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('change-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('change-qty-ATTA-50KG')), '39');
    // A reason is needed
    await tester.tap(find.byKey(const Key('change-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('change-send')), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('change-reason')),
        matching: find.byType(TextField),
      ),
      'One bag torn',
    );
    await tester.tap(find.byKey(const Key('change-send')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('change-waiting-SAL-ORD-0000')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('print-SAL-ORD-0000')), findsNothing);

    // The owner sees it and approves
    final changes = await client.loadChanges();
    expect(changes.single.newItems.first.qty, 39);
    expect(changes.single.reason, 'One bag torn');
    await client.decideLoadChange(changes.single, approve: true);
    expect(await client.loadChanges(), isEmpty);

    // The old bill is cancelled: the warehouse prints a new one
    await tester.tap(find.byKey(const Key('refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('left-SAL-ORD-0000')), findsNothing);
    await tester.tap(find.byKey(const Key('print-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(printed.length, 2);
    final bill = (await client.trucksToDispatch()).single;
    expect(bill.items.first.qty, 39);
  });

  testWidgets('the owner approves a load change from the Load changes tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = await demoAs(tester, 'Mill Owner');
    final client = state.client! as DemoClient;
    await loadDemoOrder(client);
    final truck = (await client.loadingQueue()).first;
    await client.invoiceTruck(truck);
    await client.requestLoadChange(truck, {
      'ATTA-50KG': 38,
      'ATTA-10KG': 20,
    }, 'Customer took fewer bags');

    await tester.tap(find.text('Load changes'));
    await tester.pumpAndSettle();
    expect(find.text('Atta 50 kg: 40 -> 38 bags'), findsOneWidget);
    expect(find.text('Reason: Customer took fewer bags'), findsOneWidget);
    await tester.tap(find.byKey(const Key('approve-change-SAL-ORD-0000')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-changes')), findsOneWidget);
    // The bill was cancelled, so Bills and payments lists the truck again
    expect((await client.trucksToInvoice()).single.items.first.qty, 38);
  });

  testWidgets(
    'the owner can also make and print bills (no separate accounts login)',
    (tester) async {
      final state = await demoAs(tester, 'Mill Owner');
      expect(state.client, isNotNull);
      expect(find.text('Bills and payments'), findsOneWidget);
    },
  );
}
