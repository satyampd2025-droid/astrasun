import 'dart:convert';

import 'package:atulyaa_mill/api/erpnext_client.dart';
import 'package:atulyaa_mill/api/models.dart';
import 'package:atulyaa_mill/strings.dart';
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
}
