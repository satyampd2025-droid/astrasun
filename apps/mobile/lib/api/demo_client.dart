import 'erpnext_client.dart';

/// Stands in for the server so the app can be tried with no server at all.
/// Each phone screen gets demo data here as it is built.
class DemoClient extends ErpNextClient {
  DemoClient(this.role) : super('demo');

  final String role;

  @override
  Future<Me> login(String user, String password) => me();

  @override
  Future<Me> me() async =>
      Me(user: 'demo', fullName: 'Demo', language: 'hi', millRoles: [role]);

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> logout() async {}
}
