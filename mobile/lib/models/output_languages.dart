/// Output-language options for the transcript.
///
/// - `native`  — keep the spoken language (no translation).
/// - `en`      — English via Whisper's offline translate task (no key needed).
/// - anything else — translated by Claude Haiku (needs an Anthropic key).
class OutputLanguage {
  const OutputLanguage(this.code, this.label);
  final String code;
  final String label;
}

class OutputLanguages {
  static const native = OutputLanguage('native', 'Same as spoken');

  /// Translation targets. `en` is special-cased to the offline Whisper path;
  /// every other entry goes through [ClaudeTranslator].
  static const targets = <OutputLanguage>[
    OutputLanguage('en', 'English'),
    OutputLanguage('es', 'Spanish'),
    OutputLanguage('fr', 'French'),
    OutputLanguage('de', 'German'),
    OutputLanguage('it', 'Italian'),
    OutputLanguage('pt', 'Portuguese'),
    OutputLanguage('ja', 'Japanese'),
    OutputLanguage('ko', 'Korean'),
    OutputLanguage('zh', 'Chinese'),
  ];

  static const all = <OutputLanguage>[native, ...targets];

  /// Human-readable name for a code (e.g. 'es' → 'Spanish'); the code itself if
  /// it isn't recognized.
  static String nameFor(String code) {
    for (final l in all) {
      if (l.code == code) return l.label;
    }
    return code;
  }
}
