import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../strings.dart';

/// Text box with a big mic button: speak in Hindi or English instead of typing.
/// Used for remarks and reasons (PRD: voice input).
class VoiceTextField extends StatefulWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    required this.label,
    this.speech,
  });
  final TextEditingController controller;
  final String label;
  final SpeechToText? speech;

  @override
  State<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends State<VoiceTextField> {
  late final SpeechToText _speech = widget.speech ?? SpeechToText();
  bool _listening = false;

  Future<void> _toggle() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    if (!available) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(s.t('Voice input is not available on this phone')),
        ),
      );
      return;
    }
    final before = widget.controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: s.languageCode == 'hi' ? 'hi_IN' : 'en_IN',
      ),
      onResult: (r) => widget.controller.text = [
        before,
        r.recognizedWords,
      ].where((t) => t.trim().isNotEmpty).join(' '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: _listening ? s.t('Listening...') : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          height: 64,
          child: IconButton.filled(
            key: const Key('mic'),
            tooltip: s.t('Speak'),
            iconSize: 32,
            onPressed: _toggle,
            icon: Icon(_listening ? Icons.stop : Icons.mic),
            style: _listening
                ? IconButton.styleFrom(backgroundColor: Colors.red)
                : null,
          ),
        ),
      ],
    );
  }
}
