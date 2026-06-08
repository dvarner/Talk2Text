import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk2text_mobile/audio/recorder.dart';
import 'package:talk2text_mobile/home_page.dart';
import 'package:talk2text_mobile/state/app_controller.dart';
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

void main() {
  test('timerLabel formats as MM:SS', () {
    final c = AppController(recorder: FakeCapture(), engine: StubEngine());
    expect(c.timerLabel, '00:00');
  });

  test('record then stop runs the engine and fills the transcript', () async {
    final c = AppController(recorder: FakeCapture(), engine: StubEngine());

    await c.toggleRecord(); // start
    expect(c.isRecording, isTrue);

    await c.toggleRecord(); // stop + transcribe
    expect(c.isRecording, isFalse);
    expect(c.status, AppStatus.idle);
    expect(c.hasTranscript, isTrue);
  });

  testWidgets('home screen shows the Record button', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            AppController(recorder: FakeCapture(), engine: StubEngine()),
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });
}
