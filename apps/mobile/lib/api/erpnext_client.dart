import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class LoginFailed implements Exception {}

class ServerUnreachable implements Exception {}

/// Who is logged in, from astrasun.api.me.
class Me {
  Me({
    required this.user,
    required this.fullName,
    required this.language,
    required this.millRoles,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    user: json['user'] as String,
    fullName: (json['full_name'] as String?) ?? json['user'] as String,
    language: (json['language'] as String?) ?? 'en',
    millRoles: List<String>.from(json['mill_roles'] as List? ?? const []),
  );

  final String user;
  final String fullName;
  final String language;
  final List<String> millRoles;
}

/// Talks to ERPNext over its REST API with a session cookie.
class ErpNextClient {
  ErpNextClient(String baseUrl, {http.Client? httpClient})
    : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _sid;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    // In a browser the cookie is sent by the browser itself.
    if (!kIsWeb && _sid != null) 'Cookie': 'sid=$_sid',
  };

  Future<http.Response> _post(String method, Map<String, dynamic> body) async {
    try {
      return await _http.post(
        Uri.parse('$baseUrl/api/method/$method'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } on Exception {
      throw ServerUnreachable();
    }
  }

  Future<Me> login(String user, String password) async {
    final res = await _post('login', {'usr': user, 'pwd': password});
    if (res.statusCode == 401) throw LoginFailed();
    if (res.statusCode != 200) throw ServerUnreachable();
    final cookie = res.headers['set-cookie'];
    final match = cookie == null
        ? null
        : RegExp(r'sid=([^;]+)').firstMatch(cookie);
    _sid = match?.group(1);
    return me();
  }

  Future<Me> me() async {
    final res = await _post('astrasun.api.me', {});
    if (res.statusCode == 401 || res.statusCode == 403) throw LoginFailed();
    if (res.statusCode != 200) throw ServerUnreachable();
    return Me.fromJson(jsonDecode(res.body)['message'] as Map<String, dynamic>);
  }

  Future<void> setLanguage(String language) async {
    await _post('astrasun.api.set_language', {'language': language});
  }

  Future<void> logout() async {
    await _post('logout', {});
    _sid = null;
  }
}
