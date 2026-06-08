import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'state/app_controller.dart';
import 'storage/transcript_store.dart';

/// Browsable list of auto-saved transcripts — the mobile stand-in for the
/// desktop app's transcripts/ folder (phones have no file explorer).
class TranscriptsPage extends StatefulWidget {
  const TranscriptsPage({super.key});

  @override
  State<TranscriptsPage> createState() => _TranscriptsPageState();
}

class _TranscriptsPageState extends State<TranscriptsPage> {
  late Future<List<TranscriptFile>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppController>().listTranscripts();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved transcripts')),
      body: FutureBuilder<List<TranscriptFile>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <TranscriptFile>[];
          if (items.isEmpty) {
            return const Center(child: Text('No transcripts yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.name),
                subtitle: Text(_formatDate(t.modified)),
                onTap: () => _open(context, c, t),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _onAction(context, c, t, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    AppController c,
    TranscriptFile t,
    String action,
  ) async {
    if (action == 'share') {
      await SharePlus.instance.share(ShareParams(files: [XFile(t.path)]));
    } else if (action == 'delete') {
      await c.deleteTranscript(t.path);
      if (mounted) setState(_reload);
    }
  }

  Future<void> _open(
      BuildContext context, AppController c, TranscriptFile t) async {
    final text = await c.readTranscript(t.path);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.name),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
