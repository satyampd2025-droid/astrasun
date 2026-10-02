import 'dart:convert';

import 'package:atulyaa_mill/api/erpnext_client.dart';
import 'package:atulyaa_mill/app_state.dart';
import 'package:atulyaa_mill/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake ERPNext: one user, password "secret", with the given mill roles.
http.Client fakeErpNext(List<String> roles, {List<String>? languageCalls}) {
  return MockClient((req) async {
    switch (req.url.path) {
      case '/api/method/login':
        final body = jsonDecode(req.body) as Map;
        if (body['pwd'] != 'secret') {
          return http.Response('{}', 401);
        }
        return http.Response(
          '{"message":"Logged In"}',
          200,
          headers: {'set-cookie': 'sid=abc123; Path=/; HttpOnly'},
        );
      case '/api/method/astrasun.api.me':
        if (req.headers['Cookie'] != 'sid=abc123') {
          return http.Response('{}', 403);
        }
        return http.Response(
          jsonEncode({
            'message': {
              'user': 'ramesh@mill',
              'full_name': 'Ramesh',
              'language': 'hi',
              'mill_roles': roles,
            },
          }),
          200,
        );
      case '/api/method/astrasun.api.set_language':
        languageCalls?.add((jsonDecode(req.body) as Map)['language'] as String);
        return http.Response('{"message":"ok"}', 200);
      case '/api/method/logout':
        return http.Response('{}', 200);
    }
    return http.Response('not found', 404);
  });
}

Future<AppState> startApp(
  WidgetTester tester,
  List<String> roles, {
  List<String>? languageCalls,
  String fixedServer = 'https://mill.example.com',
}) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(
    fixedServer: fixedServer,
    clientFactory: (url) => ErpNextClient(
      url,
      httpClient: fakeErpNext(roles, languageCalls: languageCalls),
    ),
  );
  await state.load();
  await tester.pumpWidget(MillApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> logIn(WidgetTester tester, {String password = 'secret'}) async {
  await tester.enterText(find.byKey(const Key('user')), 'ramesh@mill');
  await tester.enterText(find.byKey(const Key('password')), password);
  await tester.tap(find.byKey(const Key('login')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens in Hindi and switches to English', (tester) async {
    await startApp(tester, ['Mill Sales']);
    expect(find.text('लॉग इन करें'), findsOneWidget);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('wrong password shows an error in Hindi', (tester) async {
    await startApp(tester, ['Mill Sales']);
    await logIn(tester, password: 'wrong');
    expect(find.text('यूज़र आईडी या पासवर्ड गलत है'), findsOneWidget);
  });

  testWidgets('loader sees only the loading queue', (tester) async {
    await startApp(tester, ['Mill Warehouse']);
    await logIn(tester);
    expect(find.text('नमस्ते, Ramesh'), findsOneWidget);
    expect(find.text('लोडिंग सूची'), findsOneWidget);
    expect(find.text('नया ऑर्डर'), findsNothing);
  });

  testWidgets('purchase sees tasks and can open one', (tester) async {
    await startApp(tester, ['Mill Purchase']);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await logIn(tester);
    expect(find.text('Wheat purchase'), findsOneWidget);
    await tester.tap(find.text('Wheat purchase'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byKey(const Key('mic')), findsOneWidget);
  });

  testWidgets('language choice is saved on the server', (tester) async {
    final calls = <String>[];
    await startApp(tester, ['Mill Sales'], languageCalls: calls);
    await logIn(tester);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(calls, ['hi', 'en']);
  });

  testWidgets('log out returns to the login screen', (tester) async {
    await startApp(tester, ['Mill Owner']);
    await logIn(tester);
    expect(find.text('ऑर्डर मंज़ूर करें'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('लॉग इन करें'), findsOneWidget);
  });

  testWidgets('staff are not asked for a server address', (tester) async {
    await startApp(tester, ['Mill Sales']);
    expect(find.byKey(const Key('server')), findsNothing);
  });

  testWidgets('developer builds ask for the server address', (tester) async {
    await startApp(tester, ['Mill Sales'], fixedServer: '');
    expect(find.byKey(const Key('server')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('server')),
      'https://mill.example.com',
    );
    await logIn(tester);
    expect(find.text('नया ऑर्डर'), findsOneWidget);
  });

  testWidgets('demo works with no server', (tester) async {
    await startApp(tester, const []);
    await tester.tap(find.byKey(const Key('demo')));
    await tester.pumpAndSettle();
    expect(find.text('आप कौन हैं?'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('लोडिंग'), 200);
    await tester.tap(find.text('लोडिंग'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(find.text('लोडिंग सूची'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.text('लॉग इन करें'), findsOneWidget);
  });

  testWidgets('a real login shows no demo banner', (tester) async {
    await startApp(tester, ['Mill Owner']);
    await logIn(tester);
    expect(find.byKey(const Key('demo-banner')), findsNothing);
  });

  testWidgets('staff build without a server offers only the demo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(fixedServer: '', developerBuild: false);
    await state.load();
    await tester.pumpWidget(MillApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no-server')), findsOneWidget);
    expect(find.byKey(const Key('login')), findsNothing);
    expect(find.byKey(const Key('demo')), findsOneWidget);
  });
}
