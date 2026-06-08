import 'package:flutter_test/flutter_test.dart';

import 'package:talk2text_mobile/storage/transcript_store.dart';

void main() {
  test('timestampFor matches the desktop YYYY-MM-DD_HH-MM-SS naming', () {
    final t = DateTime(2026, 2, 9, 7, 5, 3);
    expect(FileTranscriptStore.timestampFor(t), '2026-02-09_07-05-03');
  });
}
