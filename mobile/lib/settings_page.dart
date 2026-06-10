import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'models/model_catalog.dart';
import 'state/app_controller.dart';

/// Settings screen — Whisper model size and language, mirroring the desktop
/// app's Settings window (minus desktop-only bits). Changes persist via
/// shared_preferences and reconfigure the active engine on Apply.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _modelSize;
  late TextEditingController _language;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppController>().settings;
    _modelSize = s.modelSize;
    _language = TextEditingController(text: s.language);
  }

  @override
  void dispose() {
    _language.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final settings = AppSettings(
      modelSize: _modelSize,
      language: _language.text.trim(),
    );
    await context.read<AppController>().applySettings(settings);
    if (mounted) Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _modelSize = AppSettings.defaults.modelSize;
      _language.text = AppSettings.defaults.language;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = ModelCatalog.infoFor(_modelSize);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionLabel('Model'),
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
            'The model downloads automatically the first time you record with it.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const Divider(height: 32),
          const _SectionLabel('Language'),
          const SizedBox(height: 8),
          TextField(
            controller: _language,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. en, fr, de  (leave blank to auto-detect)',
              isDense: true,
            ),
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
