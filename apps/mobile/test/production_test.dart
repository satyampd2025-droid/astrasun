import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'orders_test.dart' show demoAs;
import 'wheat_test.dart' show tallPhone;

void main() {
  testWidgets('milling shows extraction live and flags a low yield', (
    tester,
  ) async {
    tallPhone(tester);
    final state = await demoAs(tester, 'Mill Production');
    await tester.tap(find.text('Start milling batch'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wheat-stock')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('save-batch'))).enabled,
      isFalse,
    );
    Future<void> fill(String w, String a, String m, String so, String c) async {
      await tester.enterText(find.byKey(const Key('wheat')), w);
      await tester.enterText(find.byKey(const Key('atta')), a);
      await tester.enterText(find.byKey(const Key('maida')), m);
      await tester.enterText(find.byKey(const Key('sooji')), so);
      await tester.enterText(find.byKey(const Key('chokar')), c);
      await tester.pump();
    }

    await fill('1000', '700', '100', '50', '140');
    expect(find.textContaining('85.0%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-batch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batch-saved')), findsOneWidget);
    expect(await state.client!.wheatAvailable(), 84000);

    await fill('1000', '600', '80', '40', '140'); // 72% flour
    await tester.tap(find.byKey(const Key('save-batch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('low-yield')), findsOneWidget);

    // More out than in is refused
    await fill('1000', '900', '200', '50', '140');
    await tester.tap(find.byKey(const Key('save-batch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-failed')), findsOneWidget);
  });

  testWidgets('downtime needs machine, minutes and reason', (tester) async {
    tallPhone(tester);
    final state = await demoAs(tester, 'Mill Production');
    final client = state.client! as DemoClient;
    await tester.tap(find.text('Report downtime'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-downtime')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-failed')), findsOneWidget);
    expect(client.downtimes, isEmpty);

    await tester.enterText(find.byKey(const Key('machine')), 'Roller mill 2');
    await tester.enterText(find.byKey(const Key('minutes')), '45');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reason')),
        matching: find.byType(TextField),
      ),
      'Belt broke',
    );
    await tester.tap(find.byKey(const Key('save-downtime')));
    await tester.pumpAndSettle();
    expect(client.downtimes, ['Roller mill 2 45']);
  });

  testWidgets('packing uses bulk flour and shows it in stock', (tester) async {
    tallPhone(tester);
    await demoAs(tester, 'Mill Packing');
    await tester.tap(find.text('Pack bags'));
    await tester.pumpAndSettle();
    // 12,000 kg bulk atta, 600 empty 10 kg bags: flour allows 1200, bags 600
    expect(find.text('Can pack up to 600 bags'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('bags-ATTA-10KG')), '700');
    await tester.tap(find.byKey(const Key('pack-ATTA-10KG')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-failed')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('bags-ATTA-10KG')), '100');
    await tester.tap(find.byKey(const Key('pack-ATTA-10KG')));
    await tester.pumpAndSettle();
    expect(find.text('Can pack up to 500 bags'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock-ATTA-BULK')), findsOneWidget);
    expect(
      find.textContaining('11,000'),
      findsOneWidget,
    ); // bulk atta after 1,000 kg
    expect(find.textContaining('220'), findsOneWidget); // packed 10 kg bags
  });
}
