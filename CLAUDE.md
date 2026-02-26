# Talk2Text

Simple talk-to-text desktop app. Click record, speak, stop, get a text file.

---

## Project Status

**Phase:** MVP
**Stack:** Python, CustomTkinter (GUI), faster-whisper (STT), sounddevice (mic)
**Reference:** Audio + Whisper code ported from `an earlier local prototype`

---

## MVP Scope

1. Single window GUI
2. "Record" button — toggles to "Stop Recording"
3. Live recording timer display
4. Transcribes on stop (faster-whisper, base model)
5. Shows transcript in text area
6. Auto-saves to `Talk2Text\transcripts\YYYY-MM-DD_HH-MM-SS.txt`
7. "Save As..." button to pick custom path

**Out of scope for MVP:** Real-time streaming, copy/paste toolbar, API output, settings panel.

---

## File Structure

```
Talk2Text\
├── CLAUDE.md
├── requirements.txt
└── talk2text.py        ← entire app, single file
    transcripts\        ← auto-created, output goes here
```

---

## Stack & Dependencies

| Package | Purpose |
|---------|---------|
| `customtkinter` | GUI framework |
| `faster-whisper` | Local Whisper STT (CPU, int8) |
| `sounddevice` | Microphone input stream |
| `numpy` | Audio buffer handling |
| `scipy` | WAV file writing |

Install: `pip install -r requirements.txt`

---

## Key Design Decisions

- **Single file** (`talk2text.py`) — no src/ subfolders, no packages, MVP simplicity
- **faster-whisper base model** — good balance of speed vs accuracy on CPU
- **Auto-save to transcripts/** — always saves, "Save As" is optional rename
- **Threading** — model loading + transcription run in daemon threads so GUI stays responsive
- **No real-time** — record full clip, then transcribe (simpler, more accurate than streaming)

---

## Running

```bash
python talk2text.py
```

First launch downloads the Whisper base model (~74MB) automatically.

---

*Last updated: 2026-02-21*
