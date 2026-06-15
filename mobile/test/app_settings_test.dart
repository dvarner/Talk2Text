import 'package:flutter_test/flutter_test.dart';
import 'package:talk2text_mobile/models/app_settings.dart';

void main() {
  test('translateViaClaude is false for native and English', () {
    expect(const AppSettings(outputLanguage: 'native').translateViaClaude,
        isFalse);
    expect(const AppSettings(outputLanguage: 'en').translateViaClaude, isFalse);
  });

  test('translateViaClaude is true for presets and filled custom targets', () {
    expect(const AppSettings(outputLanguage: 'es').translateViaClaude, isTrue);
    expect(
      const AppSettings(outputLanguage: 'custom', customOutputLanguage: 'Dutch')
          .translateViaClaude,
      isTrue,
    );
    // 'custom' with no language entered isn't ready to translate.
    expect(const AppSettings(outputLanguage: 'custom').translateViaClaude,
        isFalse);
  });

  test('targetLanguageName resolves presets and trims custom', () {
    expect(const AppSettings(outputLanguage: 'fr').targetLanguageName, 'French');
    expect(
      const AppSettings(
              outputLanguage: 'custom', customOutputLanguage: '  Dutch  ')
          .targetLanguageName,
      'Dutch',
    );
  });

  test('translationModelId maps the choice to a model id', () {
    expect(const AppSettings(translationModel: 'haiku').translationModelId,
        'claude-haiku-4-5');
    expect(const AppSettings(translationModel: 'sonnet').translationModelId,
        'claude-sonnet-4-6');
    expect(const AppSettings(translationModel: 'opus').translationModelId,
        'claude-opus-4-8');
  });
}
