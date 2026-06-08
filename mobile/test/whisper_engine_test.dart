import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

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
}
