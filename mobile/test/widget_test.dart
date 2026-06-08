import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk2text_mobile/audio/recorder.dart';
import 'package:talk2text_mobile/home_page.dart';
import 'package:talk2text_mobile/state/app_controller.dart';
import 'package:talk2text_mobile/storage/transcript_store.dart';
import 'package:talk2text_mobile/stt/transcription_engine.dart';

/// In-memory capture that never touches platform channels, so the controller
/// and UI can be exercised in plain unit/widget tests.
class FakeCapture implements AudioCapture {
  bool _recording = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> start() async {
    _recording = true;
    return true;
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    return '/tmp/fake.wav';
  }

  @override
  Future<bool> isRecording() async => _recording;

  @override
  Future<void> dispose() async {}
}

/// In-memory transcript store for tests (no filesystem / path_provider).
class FakeStore implements TranscriptStore {
  final List<String> saved = [];

  @override
  Future<String?> save(String text, {DateTime? at}) async {
    if (text.trim().isEmpty) return null;
    saved.add(text);
    return '/tmp/transcripts/fake.txt';
  }

  @override
  Future<List<TranscriptFile>> list() async => const [];

  @override
  Future<void> delete(String path) async {}

  @override
  Future<String> read(String path) async => '';
}

AppController _controller() => AppController(
      recorder: FakeCapture(),
      engine: StubEngine(),
      store: FakeStore(),
    );

void main() {
  test('timerLabel formats as MM:SS', () {
    expect(_controller().timerLabel, '00:00');
  });

  test('record then stop transcribes and auto-saves', () async {
    final store = FakeStore();
    final c = AppController(
      recorder: FakeCapture(),
      engine: StubEngine(),
      store: store,
    );

    await c.toggleRecord(); // start
    expect(c.isRecording, isTrue);

    await c.toggleRecord(); // stop + transcribe + save
    expect(c.isRecording, isFalse);
    expect(c.status, AppStatus.idle);
    expect(c.hasTranscript, isTrue);
    expect(c.savedPath, isNotNull);
    expect(store.saved, hasLength(1));
  });

  testWidgets('home screen shows the action buttons', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => _controller(),
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
