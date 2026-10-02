import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/erpnext_client.dart';

/// Language, server and logged-in user, shared by every screen.
class AppState extends ChangeNotifier {
  AppState({this.clientFactory = _defaultClient});

  static ErpNextClient _defaultClient(String url) => ErpNextClient(url);

  final ErpNextClient Function(String url) clientFactory;

  Locale locale = const Locale('hi');
  String serverUrl = '';
  ErpNextClient? client;
  Me? me;

  bool get loggedIn => me != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    locale = Locale(prefs.getString('language') ?? 'hi');
    serverUrl = prefs.getString('server') ?? _defaultServer();
    notifyListeners();
  }

  /// On the web build the app is served by ERPNext itself, so use that address.
  static String _defaultServer() =>
      Uri.base.isScheme('http') || Uri.base.isScheme('https')
      ? Uri.base.origin
      : '';

  Future<void> setLanguage(String code) async {
    locale = Locale(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    await client?.setLanguage(code);
  }

  Future<void> login(String server, String user, String password) async {
    final c = clientFactory(server);
    me = await c.login(user, password);
    client = c;
    serverUrl = server;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server', server);
    await client!.setLanguage(locale.languageCode);
    notifyListeners();
  }

  Future<void> logout() async {
    await client?.logout();
    client = null;
    me = null;
    notifyListeners();
  }
}
