import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../app_state.dart';
import '../strings.dart';
import '../widgets/language_switch.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _server = TextEditingController(text: widget.state.serverUrl);
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.login(
        _server.text.trim(),
        _user.text.trim(),
        _password.text,
      );
    } on LoginFailed {
      _error = s.t('Wrong user ID or password');
    } on ServerUnreachable {
      _error = s.t('Cannot reach the server. Check the internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: LanguageSwitch(state: widget.state),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.grain,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            Text(
              s.t('Atulyaa Mill'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              key: const Key('server'),
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: s.t('Server address')),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('user'),
              controller: _user,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: s.t('User ID')),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(labelText: s.t('Password')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 18,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('login'),
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const CircularProgressIndicator()
                  : Text(s.t('Log in')),
            ),
          ],
        ),
      ),
    );
  }
}
