# Talk2Text

Local speech-to-text desktop app. Record, speak, get text. No cloud, no API keys — runs entirely on your machine using [faster-whisper](https://github.com/SYSTRAN/faster-whisper).

## Features

- **Record & Transcribe** — Click record or press a global hotkey, speak, get transcribed text
- **Global Hotkey** — Dictate directly into any input field in any app
  - Windows: `Ctrl+Alt+D` (default)
  - macOS: `Cmd+Option+D` (default)
  - Configurable in Settings
- **Multiple Models** — Choose from tiny, base, small, medium, or large Whisper models
- **Auto-Save** — Transcripts saved automatically to `transcripts/` with timestamps
- **Settings** — Model selection, hotkey config, language, VAD filter, beam size, temperature
- **Cross-Platform** — Windows and macOS

## Download

Pre-built binaries available on the [Releases](https://github.com/dvarner/Talk2Text/releases) page:

- **Windows:** Download `Talk2Text.exe`
- **macOS:** Download `Talk2Text`

## Run from Source

```bash
# Clone
git clone https://github.com/dvarner/Talk2Text.git
cd Talk2Text

# Install dependencies
pip install -r requirements.txt

# Run
python talk2text.py
```

First launch downloads the selected Whisper model automatically (~465MB for small).

### Requirements

- Python 3.10+
- macOS: PortAudio (`brew install portaudio`)

## How It Works

1. Click **Record** (or press the hotkey from any app)
2. Speak
3. Click **Stop** (or press the hotkey again)
4. Text appears in the app and auto-saves to `transcripts/`
5. When using the hotkey, text is also pasted into the active input field

## Models

| Model | Disk | RAM | Speed | Accuracy |
|-------|------|-----|-------|----------|
| tiny | ~75 MB | 1 GB | Fastest | Low |
| base | ~145 MB | 1 GB | Fast | Good |
| **small** | **~465 MB** | **2 GB** | **Moderate** | **Better** (default) |
| medium | ~1.5 GB | 4 GB | Slow | High |
| large | ~3 GB | 8+ GB | Slowest | Best |

Models download on first use. Change the model in Settings.

## Stack

| Package | Purpose |
|---------|---------|
| [customtkinter](https://github.com/TomSchimansky/CustomTkinter) | GUI framework |
| [faster-whisper](https://github.com/SYSTRAN/faster-whisper) | Local Whisper STT (CPU, int8) |
| [sounddevice](https://python-sounddevice.readthedocs.io/) | Microphone input |
| [pynput](https://github.com/moses-palmer/pynput) | Global hotkey listener |
| numpy / scipy | Audio processing |

## License

[MIT](LICENSE)
