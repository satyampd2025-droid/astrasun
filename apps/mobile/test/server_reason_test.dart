import 'dart:convert';

import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:atulyaa_mill/api/erpnext_client.dart';
import 'package:atulyaa_mill/api/models.dart';
import 'package:atulyaa_mill/screens/dues_screen.dart';
import 'package:atulyaa_mill/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// What the phone shows when the server refuses a save: the server's own words.
Future<Object?> sendOrderAnswered(http.Response answer) async {
  final client = ErpNextClient(
    'https://mill.example.com',
    httpClient: MockClient((_) async => answer),
  );
  try {
    await client.createOrder(
      const Customer('c1', 'Gautam'),
      [OrderLine(const CatalogItem('ATTA-50KG', 'Atta 50 kg', 1025))],
      '',
    );
    return null;
  } on Exception catch (e) {
    return e;
  }
}

/// A server that refuses to list customer dues, whatever the reason.
class _RefusingClient extends DemoClient {
  _RefusingClient(this.error) : super('Mill Sales');
  final Object error;

  @override
  Future<List<Due>> dues() async => throw error;
}

Future<void> showDues(WidgetTester tester, Object error) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      home: DuesScreen(client: _RefusingClient(error), canCollect: false),
    ),
  );
  await tester.pumpAndSettle();
}

String frappeMessages(String message) => jsonEncode([
  jsonEncode({'message': message, 'indicator': 'red'}),
]);

void main() {
  test('a refused order carries the server reason, without markup', () async {
    final error = await sendOrderAnswered(
      http.Response(
        jsonEncode({
          'exc_type': 'ValidationError',
          'exception': 'frappe.exceptions.ValidationError: Row 1',
          '_server_messages': frappeMessages(
            'Row #1: <strong>Warehouse</strong> is required &amp; missing<br>Fix it',
          ),
        }),
        417,
      ),
    );
    expect(error, isA<ServerRefused>());
    expect(
      (error as ServerRefused).reason,
      'Row #1: Warehouse is required & missing Fix it',
    );
  });

  test('a permission refusal is shown, not mistaken for a wrong login', () async {
    final error = await sendOrderAnswered(
      http.Response(
        jsonEncode({
          'exc_type': 'PermissionError',
          '_server_messages': frappeMessages('No permission for Sales Order'),
        }),
        403,
      ),
    );
    expect(error, isA<ServerRefused>());
    expect((error as ServerRefused).reason, 'No permission for Sales Order');
  });

  test('an uncaught server error shows its text without the Python path', () async {
    final error = await sendOrderAnswered(
      http.Response(
        jsonEncode({
          'exc_type': 'TypeError',
          'exception': "builtins.TypeError: 'NoneType' object is not iterable\nmore",
        }),
        500,
      ),
    );
    expect(error, isA<ServerRefused>());
    expect(
      (error as ServerRefused).reason,
      "'NoneType' object is not iterable",
    );
  });

  test('a proxy error page is just unreachable', () async {
    final error = await sendOrderAnswered(
      http.Response('<html><body>502 Bad Gateway</body></html>', 502),
    );
    expect(error, isA<ServerUnreachable>());
  });

  test('screens show the reason, or the plain try-again when there is none', () {
    final s = S('en');
    expect(s.saveFailed(ServerRefused('Customer is disabled')), 'Customer is disabled');
    expect(s.saveFailed(ServerUnreachable()), 'Could not save. Try again.');
    expect(S('hi').saveFailed(ServerUnreachable()), 'सेव नहीं हुआ। दोबारा कोशिश करें।');
  });

  test('lists show the reason too, or the plain check-the-internet', () {
    final s = S('en');
    expect(s.loadFailed(ServerRefused('No access')), 'No access');
    expect(
      s.loadFailed(ServerUnreachable()),
      'Cannot reach the server. Check the internet.',
    );
    expect(s.loadFailed(null), 'Cannot reach the server. Check the internet.');
  });

  testWidgets('a list the server refuses shows why, not "cannot reach"', (
    tester,
  ) async {
    const reason = 'Only sales, drivers and accounts staff can see customer dues';
    await showDues(tester, ServerRefused(reason));
    expect(find.byKey(const Key('load-failed')), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(find.textContaining('Cannot reach the server'), findsNothing);
  });

  testWidgets('a list that cannot be loaded at all says to check the internet', (
    tester,
  ) async {
    await showDues(tester, ServerUnreachable());
    expect(
      find.text('Cannot reach the server. Check the internet.'),
      findsOneWidget,
    );
  });
}
