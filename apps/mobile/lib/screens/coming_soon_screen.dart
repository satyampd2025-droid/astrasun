import 'package:flutter/material.dart';

import '../strings.dart';
import '../widgets/voice_text_field.dart';

/// Placeholder for screens built in later phases. Has a voice box so the
/// mic can be tried on a real phone now.
class ComingSoonScreen extends StatefulWidget {
  const ComingSoonScreen({super.key, required this.title});
  final String title;

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  final _remarks = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            s.t('Coming soon'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(s.t('This screen is being built.'), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Text(
            s.t('Try voice input'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          VoiceTextField(controller: _remarks, label: s.t('Remarks')),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.t('Back')),
          ),
        ],
      ),
    );
  }
}
