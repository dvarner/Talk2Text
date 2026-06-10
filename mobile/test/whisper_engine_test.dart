import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'package:talk2text_mobile/models/app_settings.dart';
import 'package:talk2text_mobile/stt/whisper_engine.dart';

void main() {
  test('WhisperEngine exposes a stable id and label', () {
    final engine = WhisperEngine();
    expect(engine.id, 'whisper');
    expect(engine.label, 'On-device Whisper');
  });

  test('WhisperEngine defaults to the base model in English', () {
    final engine = WhisperEngine();
    expect(engine.model, WhisperModel.base);
    expect(engine.language, 'en');
  });

  test('modelForSize maps settings sizes to whisper_ggml models', () {
    expect(WhisperEngine.modelForSize('tiny'), WhisperModel.tiny);
    expect(WhisperEngine.modelForSize('base'), WhisperModel.base);
    expect(WhisperEngine.modelForSize('small'), WhisperModel.small);
    expect(WhisperEngine.modelForSize('unknown'), WhisperModel.base);
  });

  test('configure applies model size and language from settings', () {
    final engine = WhisperEngine();
    engine.configure(const AppSettings(modelSize: 'small', language: 'fr'));
    expect(engine.model, WhisperModel.small);
    expect(engine.language, 'fr');
  });
}
