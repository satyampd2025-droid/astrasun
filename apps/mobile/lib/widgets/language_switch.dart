import 'package:flutter/material.dart';

import '../app_state.dart';

/// हिं / EN toggle, always one tap away.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      key: const Key('language-switch'),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'hi', label: Text('हिं')),
        ButtonSegment(value: 'en', label: Text('EN')),
      ],
      selected: {state.locale.languageCode},
      onSelectionChanged: (s) => state.setLanguage(s.first),
    );
  }
}
