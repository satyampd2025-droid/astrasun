import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/demo_client.dart';
import 'api/erpnext_client.dart';

/// The mill's server, set when the app is built:
/// `flutter build apk --dart-define=SERVER_URL=https://mill.example.in`
const builtInServer = String.fromEnvironment('SERVER_URL');

/// Language, server and logged-in user, shared by every screen.
class AppState extends ChangeNotifier {
  AppState({
    this.clientFactory = _defaultClient,
    String? fixedServer,
    this.developerBuild = kDebugMode,
  }) : fixedServer = fixedServer ?? _fixedServer();

  static ErpNextClient _defaultClient(String url) => ErpNextClient(url);

  final ErpNextClient Function(String url) clientFactory;

  /// Server address staff never have to type. Empty until the mill server exists.
  final String fixedServer;
  final bool developerBuild;

  /// Only developers type a server address.
  bool get askForServer => fixedServer.isEmpty && developerBuild;

  /// A staff build with no server yet can only show the demo.
  bool get canLogIn => fixedServer.isNotEmpty || askForServer;

  Locale locale = const Locale('hi');
  String serverUrl = '';
  ErpNextClient? client;
  Me? me;

  bool get loggedIn => me != null;
  bool get isDemo => client is DemoClient;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    locale = Locale(prefs.getString('language') ?? 'hi');
    serverUrl = askForServer ? (prefs.getString('server') ?? '') : fixedServer;
    notifyListeners();
  }

  static String _fixedServer() {
    if (builtInServer.isNotEmpty) return builtInServer;
    // The web build is served by ERPNext itself, so use that address.
    if (Uri.base.isScheme('http') || Uri.base.isScheme('https')) {
      return Uri.base.origin;
    }
    return '';
  }

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

  /// Try the app as any mill role, with sample data and no server.
  Future<void> startDemo(String role) async {
    client = DemoClient(role);
    me = await client!.me();
    notifyListeners();
  }

  Future<void> logout() async {
    await client?.logout();
    client = null;
    me = null;
    notifyListeners();
  }
}
