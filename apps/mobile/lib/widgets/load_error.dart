import 'package:flutter/material.dart';

import '../strings.dart';

/// What a screen shows when its list could not be loaded: the server's own
/// reason when it refused, else the plain "cannot reach the server", and a
/// button to try again when [onRetry] is given.
class LoadError extends StatelessWidget {
  const LoadError(this.error, {super.key, this.onRetry});
  final Object? error;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.loadFailed(error),
              key: const Key('load-failed'),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('try-again'),
                icon: const Icon(Icons.refresh),
                label: Text(s.t('Try again')),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
