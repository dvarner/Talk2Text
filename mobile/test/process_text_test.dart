import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk2text_mobile/process_text_page.dart';
import 'package:talk2text_mobile/state/app_controller.dart';
import 'package:talk2text_mobile/stt/transcription_engine.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dictation appends the transcript to the selected text',
      (tester) async {
    final c = AppController(
      recorder: FakeCapture(),
      engines: {'stub': StubEngine()},
      store: FakeStore(),
      settingsStore: FakeSettingsStore(),
      secretStore: FakeSecretStore(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: const MaterialApp(
          home: ProcessTextPage(initialText: 'Hello'),
        ),
      ),
    );

    expect(find.text('Record'), findsOneWidget);

    await tester.tap(find.text('Record')); // start
    await tester.pump();
    await tester.tap(find.text('Stop')); // stop + transcribe (Stub)
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, startsWith('Hello '));
    expect(field.controller!.text, contains('Recording captured.'));
  });

  testWidgets('Replace returns the field text via the platform channel',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('talk2text/process_text'),
      (call) async {
        calls.add(call);
        return true;
      },
    );

    final c = AppController(
      recorder: FakeCapture(),
      engines: {'stub': StubEngine()},
      store: FakeStore(),
      settingsStore: FakeSettingsStore(),
      secretStore: FakeSecretStore(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: const MaterialApp(
          home: ProcessTextPage(initialText: 'Edit me'),
        ),
      ),
    );

    await tester.tap(find.text('Replace'));
    await tester.pump();

    expect(calls.single.method, 'finishWithText');
    expect((calls.single.arguments as Map)['text'], 'Edit me');
  });
}
