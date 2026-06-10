import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'settings_page.dart';
import 'state/app_controller.dart';
import 'transcripts_page.dart';

/// Main screen: status line, live timer, transcript box, and the action row.
/// Visual language follows the desktop app — dark theme, a prominent record
/// button that turns red→green while recording.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk2Text'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Saved transcripts',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => _push(context, c, const TranscriptsPage()),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(context, c, const SettingsPage()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: c.status == AppStatus.error
                      ? Colors.red.shade300
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    c.isRecording ? c.timerLabel : '',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      c.transcript.isEmpty
                          ? 'Your transcript will appear here.'
                          : c.transcript,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: c.transcript.isEmpty
                            ? Colors.grey.shade600
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionRow(controller: c),
            ],
          ),
        ),
      ),
    );
  }

  /// Pushes [page] while forwarding the existing controller (routes are a
  /// separate subtree and don't inherit the home page's Provider otherwise).
  void _push(BuildContext context, AppController c, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<AppController>.value(
          value: c,
          child: page,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final recording = c.isRecording;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: recording
                    ? const Color(0xFF27ae60)
                    : const Color(0xFFc0392b),
              ),
              onPressed: c.isBusy ? null : c.toggleRecord,
              child: Text(
                recording ? 'Stop Recording' : 'Record',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: c.hasTranscript ? () => _copy(context, c) : null,
              child: const Text('Copy'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: c.hasTranscript ? () => _share(c) : null,
              child: const Text('Share'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, AppController c) async {
    await Clipboard.setData(ClipboardData(text: c.transcript));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Shares the saved .txt file when available (the "Save As" analog — lets the
  /// user file it into Files/Drive/etc.), otherwise falls back to plain text.
  Future<void> _share(AppController c) async {
    final path = c.savedPath;
    final params = path != null
        ? ShareParams(
            text: c.transcript,
            files: [XFile(path)],
            subject: 'Talk2Text transcript',
          )
        : ShareParams(text: c.transcript, subject: 'Talk2Text transcript');
    await SharePlus.instance.share(params);
  }
}
