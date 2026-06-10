import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'platform/process_text.dart';
import 'state/app_controller.dart';

/// Shown when launched from another app's text-selection menu (Android
/// PROCESS_TEXT). The user sees the highlighted text, dictates an addition with
/// the active engine, edits if needed, then returns the result to replace the
/// original selection.
class ProcessTextPage extends StatefulWidget {
  const ProcessTextPage({
    super.key,
    required this.initialText,
    this.service = const ProcessTextService(),
  });

  final String initialText;
  final ProcessTextService service;

  @override
  State<ProcessTextPage> createState() => _ProcessTextPageState();
}

class _ProcessTextPageState extends State<ProcessTextPage> {
  late final TextEditingController _text;
  late final AppController _controller;
  String _consumed = '';

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _controller = context.read<AppController>();
    _controller.addListener(_onTranscript);
  }

  /// When a fresh transcription lands, insert it at the end of the field.
  void _onTranscript() {
    final t = _controller.transcript.trim();
    if (t.isNotEmpty && t != _consumed && _controller.status == AppStatus.idle) {
      _consumed = t;
      final base = _text.text;
      final sep = base.isEmpty || base.endsWith(' ') ? '' : ' ';
      _text.text = '$base$sep$t';
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTranscript);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Talk2Text')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.isRecording ? 'Recording…  ${c.timerLabel}' : c.message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Selected text — dictate to add to it',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.isRecording
                              ? const Color(0xFF27ae60)
                              : const Color(0xFFc0392b),
                        ),
                        onPressed: c.isBusy ? null : c.toggleRecord,
                        child: Text(c.isRecording ? 'Stop' : 'Record'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => widget.service.finish(_text.text),
                        child: const Text('Replace'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
