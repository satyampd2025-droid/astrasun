import 'package:flutter/material.dart';

import '../strings.dart';
import 'load_error.dart';

/// Waits for [load] whatever its outcome, so a pull-down spinner lasts exactly
/// as long as the load. A failure is shown by the screen, not thrown here.
Future<void> settled(Future<Object?> load) async {
  try {
    await load;
  } on Object {
    // the list says why it failed
  }
}

/// The refresh icon in a list screen's app bar, for those who do not know to pull down.
class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key, required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('refresh'),
    tooltip: S.of(context).t('Refresh'),
    icon: const Icon(Icons.refresh),
    onPressed: onPressed,
  );
}

/// The body of a screen that loads something: a spinner, then the content.
/// When the load fails it says why and offers "Try again". Pulling the content
/// down loads again, also when the list is empty or the load failed.
class PullToReload<T> extends StatefulWidget {
  const PullToReload({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.builder,
    this.isEmpty,
    this.emptyText,
    this.emptyKey,
  });

  /// A list of cards, with [emptyText] on screen when there are none.
  static PullToReload<List<E>> list<E>({
    Key? key,
    required Future<List<E>> future,
    required Future<void> Function() onRefresh,
    required List<Widget> Function(BuildContext context, List<E> rows) cards,
    String? emptyText,
    Key? emptyKey,
  }) => PullToReload<List<E>>(
    key: key,
    future: future,
    onRefresh: onRefresh,
    builder: cards,
    isEmpty: (rows) => rows.isEmpty,
    emptyText: emptyText,
    emptyKey: emptyKey,
  );

  /// What the screen is waiting for. The screen owns it and replaces it in [onRefresh].
  final Future<T> future;

  /// Loads again: replaces [future] and waits for the new one.
  final Future<void> Function() onRefresh;

  /// The content, as the children of a scrolling list.
  final List<Widget> Function(BuildContext context, T data) builder;

  final bool Function(T data)? isEmpty;
  final String? emptyText;
  final Key? emptyKey;

  @override
  State<PullToReload<T>> createState() => _PullToReloadState<T>();
}

class _PullToReloadState<T> extends State<PullToReload<T>> {
  bool _pulling = false;

  Future<void> _pull() async {
    setState(() => _pulling = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  /// A message in the middle of the screen that can still be pulled down.
  Widget _message(Widget message) => RefreshIndicator(
    onRefresh: _pull,
    child: LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(child: message),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: widget.future,
    builder: (context, snap) {
      // While a pull loads again the old content stays on screen. A reload after
      // an action shows the spinner, so a card just dealt with cannot be tapped twice.
      if (snap.hasData &&
          (snap.connectionState == ConnectionState.done || _pulling)) {
        final data = snap.data as T;
        if (widget.emptyText != null && (widget.isEmpty?.call(data) ?? false)) {
          return _message(
            Text(
              widget.emptyText!,
              key: widget.emptyKey,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _pull,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: widget.builder(context, data),
          ),
        );
      }
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return _message(LoadError(snap.error, onRetry: _pull));
    },
  );
}
