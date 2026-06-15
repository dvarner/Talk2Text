import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'models/model_catalog.dart';
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
  late TextEditingController _language;
  late TextEditingController _cloudUrl;
  late TextEditingController _cloudModel;
  late TextEditingController _apiKey;

  bool _hasSavedKey = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    final s = c.settings;
    _engineId = s.engineId;
    _modelSize = s.modelSize;
    _outputLanguage = s.outputLanguage;
    _language = TextEditingController(text: s.language);
    _cloudUrl = TextEditingController(text: s.cloudBaseUrl);
    _cloudModel = TextEditingController(text: s.cloudModel);
    _apiKey = TextEditingController();
    c.hasApiKey().then((v) {
      if (mounted) setState(() => _hasSavedKey = v);
    });
  }

  @override
  void dispose() {
    _language.dispose();
    _cloudUrl.dispose();
    _cloudModel.dispose();
    _apiKey.dispose();
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

  Future<void> _apply() async {
    final c = context.read<AppController>();
    if (_engineId == 'cloud' && !_hasSavedKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an API key to use the Cloud engine')),
      );
      return;
    }
    await c.applySettings(AppSettings(
      engineId: _engineId,
      modelSize: _modelSize,
      language: _language.text.trim(),
      outputLanguage: _outputLanguage,
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
            items: const [
              DropdownMenuItem(
                value: 'native',
                child: Text('Same as spoken'),
              ),
              DropdownMenuItem(
                value: 'en',
                child: Text('English (translate)'),
              ),
            ],
            onChanged: (v) =>
                setState(() => _outputLanguage = v ?? 'native'),
          ),
          const SizedBox(height: 6),
          Text(
            _outputLanguage == 'en'
                ? "Speak any language — Whisper translates it straight to "
                    'English text. (On-device Whisper and Cloud only; the '
                    'device speech engine outputs the spoken language.)'
                : 'Transcript stays in whatever language you speak.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),

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
