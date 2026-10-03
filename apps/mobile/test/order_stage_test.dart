import 'package:atulyaa_mill/api/models.dart';
import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:atulyaa_mill/screens/order_screen.dart';
import 'package:atulyaa_mill/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orders_test.dart' show demoAs;

const _steps = [
  'Waiting for approval',
  'Approved',
  'Loading',
  'Loaded',
  'On the way',
  'Delivered',
  'Paid',
];

/// The rows the server sends for an order standing at [step] (1 to 7).
List<TimelineRow> timelineAt(int step) => [
  for (var i = 0; i < _steps.length; i++)
    TimelineRow(
      _steps[i],
      i + 1 < step
          ? 'done'
          : i + 1 == step
          ? 'current'
          : 'todo',
    ),
];

Order onTheWay() => Order(
  name: 'SAL-ORD-0042',
  customerName: 'Gupta Traders',
  status: 'Approved',
  stage: 'On the way',
  tone: 'go',
  timeline: timelineAt(5),
  total: 21500,
  items: [
    OrderItem(
      itemCode: 'ATTA-50KG',
      itemName: 'Atta 50 kg',
      qty: 10,
      rate: 2150,
    ),
  ],
);

/// A screen in the app's own languages, so Hindi is picked when asked for.
Widget host(Widget child, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('hi'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

Map<String, dynamic> serverOrder(Map<String, dynamic> more) => {
  'name': 'SAL-ORD-0007',
  'customer_name': 'Verma Distributors',
  'status': 'Approved',
  'total': 1000,
  'items': [
    {
      'item_code': 'ATTA-50KG',
      'item_name': 'Atta 50 kg',
      'qty': 1,
      'rate': 1000,
    },
  ],
  ...more,
};

void main() {
  test('an order from the server carries its stage, colour and timeline', () {
    final order = Order.fromJson(
      serverOrder({
        'stage': 'Part paid',
        'tone': 'warn',
        'timeline': [
          {'label': 'Waiting for approval', 'state': 'done'},
          {'label': 'Part paid', 'state': 'current'},
        ],
      }),
    );
    expect(order.stage, 'Part paid');
    expect(order.tone, 'warn');
    expect(order.timeline.map((r) => (r.label, r.state)), [
      ('Waiting for approval', 'done'),
      ('Part paid', 'current'),
    ]);
  });

  test('a server that sends no stage still gets a sensible one', () {
    final waiting = Order.fromJson(serverOrder({'status': 'Pending Approval'}));
    expect(waiting.stage, 'Waiting for approval');
    expect(waiting.timeline, isEmpty);
    expect(
      Order.fromJson(serverOrder({'status': 'Approved'})).stage,
      'Approved',
    );
    expect(
      Order.fromJson(serverOrder({'status': 'Sent Back'})).stage,
      'Sent Back',
    );
  });

  testWidgets('the card says where the order stands', (tester) async {
    await tester.pumpWidget(host(Scaffold(body: OrderCard(order: onTheWay()))));
    expect(
      find.descendant(
        of: find.byKey(const Key('status-chip')),
        matching: find.text('On the way'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the same chip reads in Hindi', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(body: OrderCard(order: onTheWay())),
        language: 'hi',
      ),
    );
    expect(find.text('रास्ते में'), findsOneWidget);
  });

  test('the chip takes its colour from the tone the server sends', () {
    expect(toneColor('done'), const Color(0xFF1E5B45));
    expect(toneColor('stop'), const Color(0xFFB23A30));
    expect(toneColor('warn'), const Color(0xFF9A6A00));
    expect(toneColor('go'), const Color(0xFF2557A7));
    expect(toneColor('wait'), const Color(0xFF5C655E));
    expect(toneColor('something new'), const Color(0xFF5C655E));
  });

  testWidgets(
    'the order screen shows what is done, where it is and what is left',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(OrderScreen(order: onTheWay())));
      expect(find.text('Order status'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('timeline-$i-done')), findsOneWidget);
      }
      expect(find.byKey(const Key('timeline-4-current')), findsOneWidget);
      expect(find.byKey(const Key('timeline-5-todo')), findsOneWidget);
      expect(find.byKey(const Key('timeline-6-todo')), findsOneWidget);
      expect(find.text('Gupta Traders'), findsOneWidget);
    },
  );

  testWidgets(
    'an order that is not on the ladder shows its reason and no timeline',
    (tester) async {
      final sentBack = Order(
        name: 'SAL-ORD-0043',
        customerName: 'Gupta Traders',
        status: 'Sent Back',
        tone: 'warn',
        note: 'Check the rate',
        total: 1000,
        items: const [],
      );
      await tester.pumpWidget(host(OrderScreen(order: sentBack)));
      expect(find.text('“Check the rate”'), findsOneWidget);
      expect(find.text('Order status'), findsNothing);
      expect(find.byKey(const Key('timeline-0-done')), findsNothing);
    },
  );

  testWidgets('a rep opens an order from My orders and sees its timeline', (
    tester,
  ) async {
    await demoAs(tester, 'Mill Sales');
    await tester.tap(find.text('My orders'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for approval'), findsWidgets);
    expect(find.text('Pending Approval'), findsNothing);

    await tester.tap(find.byKey(const Key('order-SAL-ORD-0001')));
    await tester.pumpAndSettle();
    expect(find.text('Order status'), findsOneWidget);
    expect(find.byKey(const Key('timeline-0-current')), findsOneWidget);
    expect(find.byKey(const Key('timeline-1-todo')), findsOneWidget);
  });

  testWidgets('the owner sees every order and its stage under All orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('All orders'));
    await tester.pumpAndSettle();
    expect(find.text('Sharma Kirana Store'), findsOneWidget);
    expect(find.text('Verma Distributors'), findsOneWidget);
    expect(find.text('Gupta Traders'), findsOneWidget);
    expect(find.text('Waiting for approval'), findsNWidgets(3));
  });

  testWidgets('an approval moves the order up the ladder everywhere', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await demoAs(tester, 'Mill Owner');
    await tester.tap(find.text('Approve orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-SAL-ORD-0001')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('All orders'));
    await tester.pumpAndSettle();
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Waiting for approval'), findsNWidgets(2));
  });

  testWidgets('All orders reads in Hindi', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(fixedServer: '');
    await state.load();
    await state.startDemo('Mill Owner');
    await tester.pumpWidget(MillApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('सभी ऑर्डर'));
    await tester.pumpAndSettle();
    expect(find.text('मंज़ूरी का इंतज़ार'), findsWidgets);
  });
}
