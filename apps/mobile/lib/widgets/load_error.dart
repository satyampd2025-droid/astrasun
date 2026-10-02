import 'package:flutter/material.dart';

import '../strings.dart';

/// What a screen shows when its list could not be loaded: the server's own
/// reason when it refused, else the plain "cannot reach the server".
class LoadError extends StatelessWidget {
  const LoadError(this.error, {super.key});
  final Object? error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        S.of(context).loadFailed(error),
        key: const Key('load-failed'),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
