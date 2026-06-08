import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A saved transcript on disk, with display metadata for the list view.
class TranscriptFile {
  TranscriptFile(this.path, this.name, this.modified);

  final String path;
  final String name;
  final DateTime modified;
}

/// Persistence seam for transcripts. Kept as an interface so the controller is
/// unit-testable without touching the filesystem / platform channels.
abstract class TranscriptStore {
  /// Saves [text] and returns the saved path, or null on empty/failure.
  Future<String?> save(String text, {DateTime? at});

  /// Saved transcripts, newest first.
  Future<List<TranscriptFile>> list();

  Future<void> delete(String path);

  Future<String> read(String path);
}

/// Saves to `<app documents>/transcripts/YYYY-MM-DD_HH-MM-SS.txt`, mirroring
/// the desktop app's TRANSCRIPTS_DIR and timestamp naming.
class FileTranscriptStore implements TranscriptStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/transcripts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String?> save(String text, {DateTime? at}) async {
    if (text.trim().isEmpty) return null;
    try {
      final dir = await _dir();
      final file = File('${dir.path}/${timestampFor(at ?? DateTime.now())}.txt');
      await file.writeAsString(text);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TranscriptFile>> list() async {
    final dir = await _dir();
    final entries = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .map((f) {
          final modified = f.statSync().modified;
          return TranscriptFile(f.path, f.uri.pathSegments.last, modified);
        })
        .toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    return entries;
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<String> read(String path) => File(path).readAsString();

  /// Desktop-compatible timestamp: `YYYY-MM-DD_HH-MM-SS`. Pure and testable.
  static String timestampFor(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}_'
        '${two(t.hour)}-${two(t.minute)}-${two(t.second)}';
  }
}
