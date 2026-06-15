import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'models/model_catalog.dart';
import 'models/output_languages.dart';
import 'state/app_controller.dart';

/// Settings screen — engine selection, on-device model size, language, and the
/// optional cloud API key. Mirrors the desktop Settings window (mobile subset),
/// persisting via shared_preferences (key via secure storage) on Apply.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _engineId;
  late String _modelSize;
  late String _outputLanguage;
  late String _translationModel;
  late TextEditingController _customLanguage;
  late TextEditingController _language;
  late TextEditingController _cloudUrl;
  late TextEditingController _cloudModel;
  late TextEditingController _apiKey;
  late TextEditingController _claudeKey;

  bool _hasSavedKey = false;
  bool _hasClaudeKey = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    final s = c.settings;
    _engineId = s.engineId;
    _modelSize = s.modelSize;
    _outputLanguage = s.outputLanguage;
    _translationModel = s.translationModel;
    _customLanguage = TextEditingController(text: s.customOutputLanguage);
    _language = TextEditingController(text: s.language);
    _cloudUrl = TextEditingController(text: s.cloudBaseUrl);
    _cloudModel = TextEditingController(text: s.cloudModel);
    _apiKey = TextEditingController();
    _claudeKey = TextEditingController();
    c.hasApiKey().then((v) {
      if (mounted) setState(() => _hasSavedKey = v);
    });
    c.hasTranslatorKey().then((v) {
      if (mounted) setState(() => _hasClaudeKey = v);
    });
  }

  @override
  void dispose() {
    _customLanguage.dispose();
    _language.dispose();
    _cloudUrl.dispose();
    _cloudModel.dispose();
    _apiKey.dispose();
    _claudeKey.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final c = context.read<AppController>();
    final key = _apiKey.text.trim();
    if (key.isEmpty) return;
    await c.setApiKey(key);
    _apiKey.clear();
    if (mounted) {
      setState(() => _hasSavedKey = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key saved')),
      );
    }
  }

  Future<void> _clearKey() async {
    final c = context.read<AppController>();
    await c.clearApiKey();
    if (mounted) setState(() => _hasSavedKey = false);
  }

  Future<void> _saveClaudeKey() async {
    final c = context.read<AppController>();
    final key = _claudeKey.text.trim();
    if (key.isEmpty) return;
    await c.setTranslatorKey(key);
    _claudeKey.clear();
    if (mounted) {
      setState(() => _hasClaudeKey = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claude API key saved')),
      );
    }
  }

  Future<void> _clearClaudeKey() async {
    final c = context.read<AppController>();
    await c.clearTranslatorKey();
    if (mounted) setState(() => _hasClaudeKey = false);
  }

  Future<void> _apply() async {
    final c = context.read<AppController>();
    if (_engineId == 'cloud' && !_hasSavedKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an API key to use the Cloud engine')),
      );
      return;
    }
    final isClaudeTarget =
        _outputLanguage != 'native' && _outputLanguage != 'en';
    if (_outputLanguage == 'custom' && _customLanguage.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a language to translate to')),
      );
      return;
    }
    if (isClaudeTarget && !_hasClaudeKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a Claude API key to translate to that language'),
        ),
      );
      return;
    }
    await c.applySettings(AppSettings(
      engineId: _engineId,
      modelSize: _modelSize,
      language: _language.text.trim(),
      outputLanguage: _outputLanguage,
      customOutputLanguage: _customLanguage.text.trim(),
      translationModel: _translationModel,
      cloudBaseUrl: _cloudUrl.text.trim().isEmpty
          ? AppSettings.defaults.cloudBaseUrl
          : _cloudUrl.text.trim(),
      cloudModel: _cloudModel.text.trim().isEmpty
          ? AppSettings.defaults.cloudModel
          : _cloudModel.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _engineId = AppSettings.defaults.engineId;
      _modelSize = AppSettings.defaults.modelSize;
      _outputLanguage = AppSettings.defaults.outputLanguage;
      _translationModel = AppSettings.defaults.translationModel;
      _customLanguage.text = AppSettings.defaults.customOutputLanguage;
      _language.text = AppSettings.defaults.language;
      _cloudUrl.text = AppSettings.defaults.cloudBaseUrl;
      _cloudModel.text = AppSettings.defaults.cloudModel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    final info = ModelCatalog.infoFor(_modelSize);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionLabel('Engine'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final e in c.engines)
                ButtonSegment(value: e.id, label: Text(e.label)),
            ],
            selected: {_engineId},
            onSelectionChanged: (s) => setState(() => _engineId = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_engineId) {
              'whisper' => 'Runs fully offline on your device.',
              'native' =>
                "Uses your device's built-in speech recognition. No download.",
              _ => 'Sends audio to your configured API. Requires a key.',
            },
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),

          if (_engineId == 'whisper') ...[
            const Divider(height: 32),
            const _SectionLabel('On-device model'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final m in ModelCatalog.models)
                  ButtonSegment(value: m.size, label: Text(m.size)),
              ],
              selected: {_modelSize},
              onSelectionChanged: (s) => setState(() => _modelSize = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              'Disk: ${info.disk}  ·  ${info.note}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 6),
            Text(
              'The model downloads automatically the first time you record.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],

          if (_engineId == 'cloud') ...[
            const Divider(height: 32),
            const _SectionLabel('Cloud API'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _hasSavedKey ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: _hasSavedKey ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(_hasSavedKey ? 'API key saved' : 'No API key set'),
                const Spacer(),
                if (_hasSavedKey)
                  TextButton(onPressed: _clearKey, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Paste API key',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _saveKey, child: const Text('Save')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cloudUrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Base URL',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cloudModel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Model',
                isDense: true,
              ),
            ),
          ],

          const Divider(height: 32),
          const _SectionLabel('Spoken language'),
          const SizedBox(height: 8),
          TextField(
            controller: _language,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. en, fr, de  (leave blank to auto-detect)',
              isDense: true,
            ),
          ),

          const Divider(height: 32),
          const _SectionLabel('Output text'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _outputLanguage,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final l in OutputLanguages.all)
                DropdownMenuItem(value: l.code, child: Text(l.label)),
            ],
            onChanged: (v) =>
                setState(() => _outputLanguage = v ?? 'native'),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_outputLanguage) {
              'native' => 'Transcript stays in whatever language you speak.',
              'en' =>
                'Speak any language — Whisper translates it straight to English, '
                    'offline. (On-device Whisper and Cloud only.)',
              _ =>
                'Speak any language — Claude translates the transcript to '
                    '${OutputLanguages.nameFor(_outputLanguage)}. Only the text '
                    'is sent (never the audio); needs a Claude API key below.',
            },
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),

          if (_outputLanguage == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customLanguage,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Target language',
                hintText: 'e.g. Dutch, Swahili, Tagalog',
                isDense: true,
              ),
            ),
          ],

          if (_outputLanguage != 'native' && _outputLanguage != 'en') ...[
            const SizedBox(height: 16),
            const _SectionLabel('Translation model'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'haiku', label: Text('Fast')),
                ButtonSegment(value: 'sonnet', label: Text('Better')),
                ButtonSegment(value: 'opus', label: Text('Best')),
              ],
              selected: {_translationModel},
              onSelectionChanged: (s) =>
                  setState(() => _translationModel = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              switch (_translationModel) {
                'opus' => 'Opus — highest quality for hard languages; '
                    'slowest and priciest.',
                'sonnet' => 'Sonnet — stronger than Haiku for tricky languages.',
                _ => 'Haiku — fast and cheap; great for common languages.',
              },
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            const _SectionLabel('Claude API key (translation)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _hasClaudeKey ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: _hasClaudeKey ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(_hasClaudeKey ? 'Claude API key saved' : 'No Claude key set'),
                const Spacer(),
                if (_hasClaudeKey)
                  TextButton(
                    onPressed: _clearClaudeKey,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _claudeKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Paste Anthropic API key (sk-ant-…)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveClaudeKey,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset to defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      );
}
