"""Talk2Text - Click record, speak, get a text file."""

import json
import sys
import threading
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Callable, Optional

import customtkinter as ctk

# ── Constants ──────────────────────────────────────────────────────────────────
SAMPLE_RATE = 16000

# PyInstaller --onefile: __file__ points inside a temp extraction dir; use the
# real executable's location instead so models/ and transcripts/ stay persistent.
_BASE = Path(sys.executable).parent if getattr(sys, "frozen", False) else Path(__file__).parent

TRANSCRIPTS_DIR = _BASE / "transcripts"
MODELS_DIR      = _BASE / "models"
SETTINGS_PATH   = _BASE / "settings.json"

MODEL_SIZES = ["tiny", "base", "small", "medium", "large"]

MODEL_HW: dict = {
    "tiny":   ("~75 MB",  "1 GB",   "Any CPU",             "Not needed", "Fastest, least accurate"),
    "base":   ("~145 MB", "1 GB",   "Any CPU",             "Not needed", "Good balance of speed & accuracy"),
    "small":  ("~465 MB", "2 GB",   "Modern CPU (4+ cores)", "Optional",   "Better accuracy, ~2× slower than base"),
    "medium": ("~1.5 GB", "4 GB",   "Fast CPU (6+ cores)", "Recommended","High accuracy, noticeably slow on CPU"),
    "large":  ("~3 GB",   "8+ GB",  "Fast CPU (8+ cores)", "Required",   "Best accuracy, very slow without GPU"),
}

DEFAULT_CONFIG: dict = {
    "model_size":                "small",
    "language":                  "en",
    "vad_filter":                False,
    "beam_size":                 5,
    "temperature":               0.0,
    "condition_on_previous_text": False,
    "hotkey_enabled":            True,
    "hotkey":                    "<ctrl>+<shift>+space",
}


def _format_hotkey(hotkey: str) -> str:
    """'<ctrl>+<shift>+space' → 'Ctrl+Shift+Space' for display."""
    parts = hotkey.split("+")
    out = []
    for p in parts:
        p = p.strip()
        out.append(p[1:-1].capitalize() if p.startswith("<") and p.endswith(">") else p.capitalize())
    return "+".join(out)

# ── Config ─────────────────────────────────────────────────────────────────────

def load_config() -> dict:
    config = DEFAULT_CONFIG.copy()
    try:
        if SETTINGS_PATH.exists():
            data = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
            for key in DEFAULT_CONFIG:
                if key in data:
                    config[key] = data[key]
    except Exception as e:
        print(f"[Config] Load failed: {e}")
    return config


def save_config(config: dict) -> None:
    try:
        SETTINGS_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
    except Exception as e:
        print(f"[Config] Save failed: {e}")


# ── Model Manager ──────────────────────────────────────────────────────────────

class ModelManager:
    """Checks download status and downloads faster-whisper models into MODELS_DIR."""

    @staticmethod
    def is_downloaded(model_size: str) -> bool:
        """True if model.bin exists inside any matching HF cache folder in MODELS_DIR."""
        if not MODELS_DIR.exists():
            return False
        # Use a wildcard so "large" matches both large and large-v3 etc.
        pattern = f"models--Systran--faster-whisper-{model_size}*"
        for d in MODELS_DIR.glob(pattern):
            if any(d.rglob("model.bin")):
                return True
        return False

    @staticmethod
    def download_async(
        model_size: str,
        on_progress: Callable[[str], None],
        on_done: Callable[[bool, Optional[str]], None],
    ) -> None:
        """Download model to MODELS_DIR without loading it into memory."""
        def _thread():
            try:
                from huggingface_hub import snapshot_download
                MODELS_DIR.mkdir(parents=True, exist_ok=True)
                on_progress(f"Downloading {model_size} model…")
                snapshot_download(
                    repo_id=f"Systran/faster-whisper-{model_size}",
                    cache_dir=str(MODELS_DIR),
                )
                on_done(True, None)
            except Exception as e:
                on_done(False, str(e))

        threading.Thread(target=_thread, daemon=True).start()


# ── Hotkey Listener ───────────────────────────────────────────────────────────

class HotkeyListener:
    """Global hotkey listener using pynput. Runs in its own daemon thread."""

    def __init__(self):
        self._listener = None

    def start(self, hotkey: str, callback: Callable) -> bool:
        self.stop()
        try:
            from pynput import keyboard
            self._listener = keyboard.GlobalHotKeys({hotkey: callback})
            self._listener.start()
            print(f"[Hotkey] Listening for {hotkey}")
            return True
        except Exception as e:
            print(f"[Hotkey] Failed to start: {e}")
            self._listener = None
            return False

    def stop(self) -> None:
        if self._listener:
            try:
                self._listener.stop()
                self._listener.join(timeout=0.5)  # wait for hook to fully unregister
            except Exception:
                pass
            self._listener = None


# ── Audio Recorder ─────────────────────────────────────────────────────────────

class AudioRecorder:
    def __init__(self, sample_rate: int = SAMPLE_RATE):
        self.sample_rate = sample_rate
        self.recording = False
        self.audio_data: list = []
        self.stream = None

    def start(self) -> bool:
        if self.recording:
            return False
        try:
            import sounddevice as sd
            self.recording = True
            self.audio_data = []

            def callback(indata, frames, time, status):
                if self.recording:
                    self.audio_data.append(indata.copy())

            self.stream = sd.InputStream(
                samplerate=self.sample_rate,
                channels=1,
                dtype="float32",
                callback=callback,
            )
            self.stream.start()
            return True
        except Exception as e:
            print(f"[Recorder] Failed to start: {e}")
            self.recording = False
            return False

    def stop(self) -> Optional[str]:
        if not self.recording:
            return None
        try:
            import numpy as np
            import scipy.io.wavfile as wav

            self.recording = False
            if self.stream:
                self.stream.stop()
                self.stream.close()
                self.stream = None

            if not self.audio_data:
                return None

            audio = np.concatenate(self.audio_data, axis=0).flatten()
            peak = np.abs(audio).max()
            if peak > 0:
                audio = audio / peak * 0.95

            audio_int16 = (audio * 32767).astype(np.int16)
            tmp = Path(tempfile.gettempdir()) / "talk2text_recording.wav"
            wav.write(str(tmp), self.sample_rate, audio_int16)
            return str(tmp)
        except Exception as e:
            print(f"[Recorder] Failed to stop: {e}")
            self.recording = False
            return None

    def duration(self) -> float:
        if not self.audio_data:
            return 0.0
        try:
            import numpy as np
            total = sum(c.shape[0] for c in self.audio_data)
            return total / self.sample_rate
        except Exception:
            return 0.0


# ── Whisper Transcriber ────────────────────────────────────────────────────────

class Transcriber:
    def __init__(self):
        self.model = None
        self.loading = False
        self._loaded_size: Optional[str] = None

    def load(self, model_size: str, on_done: Optional[Callable] = None) -> None:
        if self.loading:
            return
        if self.model and self._loaded_size == model_size:
            if on_done:
                on_done(True, None)
            return

        self.model = None
        self._loaded_size = None
        self.loading = True

        def _thread():
            try:
                from faster_whisper import WhisperModel
                MODELS_DIR.mkdir(parents=True, exist_ok=True)
                self.model = WhisperModel(
                    model_size,
                    device="cpu",
                    compute_type="int8",
                    download_root=str(MODELS_DIR),
                )
                self._loaded_size = model_size
                if on_done:
                    on_done(True, None)
            except Exception as e:
                if on_done:
                    on_done(False, str(e))
            finally:
                self.loading = False

        threading.Thread(target=_thread, daemon=True).start()

    def transcribe_async(
        self,
        audio_path: str,
        config: dict,
        on_done: Callable[[str], None],
        on_error: Callable[[str], None],
    ) -> None:
        def _thread():
            try:
                if not self.model:
                    raise RuntimeError("Model not loaded yet")
                segments, _ = self.model.transcribe(
                    audio_path,
                    beam_size=int(config.get("beam_size", 5)),
                    language=config.get("language", "en") or None,
                    vad_filter=bool(config.get("vad_filter", False)),
                    temperature=float(config.get("temperature", 0.0)),
                    condition_on_previous_text=bool(
                        config.get("condition_on_previous_text", False)
                    ),
                )
                text = " ".join(s.text.strip() for s in segments).strip()
                on_done(text)
            except Exception as e:
                on_error(str(e))

        threading.Thread(target=_thread, daemon=True).start()

    def ready(self) -> bool:
        return self.model is not None and not self.loading


# ── Settings Window ────────────────────────────────────────────────────────────

class SettingsWindow(ctk.CTkToplevel):
    def __init__(self, parent, config: dict, on_apply: Callable[[dict], None]):
        super().__init__(parent)
        self.title("Settings")
        self.geometry("460x720")
        self.resizable(False, False)
        self.transient(parent)

        self._config = config.copy()
        self._on_apply = on_apply
        self._downloading = False
        self._adv_widgets: dict = {}  # key -> (kind, var)

        self._build_ui()
        self._refresh_model_status()
        self.grab_set()
        self.after(50, self._center_on_parent)

    def _center_on_parent(self):
        self.update_idletasks()
        px = self.master.winfo_x() + self.master.winfo_width() // 2
        py = self.master.winfo_y() + self.master.winfo_height() // 2
        self.geometry(f"460x720+{px - 230}+{py - 360}")

    # ── UI ─────────────────────────────────────────────────────────────────────

    def _build_ui(self):
        self.grid_columnconfigure(0, weight=1)

        r = 0

        # ── Model section ──────────────────────────────────────────────────────
        ctk.CTkLabel(
            self, text="Model", font=ctk.CTkFont(size=14, weight="bold")
        ).grid(row=r, column=0, padx=20, pady=(20, 6), sticky="w"); r += 1

        self._model_seg = ctk.CTkSegmentedButton(
            self, values=MODEL_SIZES, command=lambda _: self._refresh_model_status()
        )
        self._model_seg.set(self._config["model_size"])
        self._model_seg.grid(row=r, column=0, padx=20, pady=(0, 8), sticky="ew"); r += 1

        # Hardware requirements for selected model
        self._hw_label = ctk.CTkLabel(
            self, text="", font=ctk.CTkFont(size=11),
            text_color="gray", justify="left", anchor="w",
        )
        self._hw_label.grid(row=r, column=0, padx=20, pady=(0, 8), sticky="ew"); r += 1

        # Status + download button side by side
        dl_row = ctk.CTkFrame(self, fg_color="transparent")
        dl_row.grid(row=r, column=0, padx=20, pady=(0, 4), sticky="ew"); r += 1
        dl_row.grid_columnconfigure(0, weight=1)

        self._model_status = ctk.CTkLabel(dl_row, text="", font=ctk.CTkFont(size=12))
        self._model_status.grid(row=0, column=0, sticky="w")

        self._download_btn = ctk.CTkButton(
            dl_row, text="Download", width=110, height=30,
            command=self._start_download,
        )
        self._download_btn.grid(row=0, column=1, sticky="e")

        # Progress bar (hidden until downloading)
        self._progress = ctk.CTkProgressBar(self, mode="indeterminate")
        self._progress.grid(row=r, column=0, padx=20, pady=(0, 2), sticky="ew"); r += 1
        self._progress.grid_remove()

        self._dl_label = ctk.CTkLabel(
            self, text="", font=ctk.CTkFont(size=11), text_color="gray"
        )
        self._dl_label.grid(row=r, column=0, padx=20, pady=(0, 8), sticky="w"); r += 1
        self._dl_label.grid_remove()

        # Divider
        ctk.CTkFrame(self, height=1, fg_color="gray30").grid(
            row=r, column=0, padx=20, pady=(0, 12), sticky="ew"
        ); r += 1

        # ── Hotkey section ─────────────────────────────────────────────────────
        ctk.CTkLabel(
            self, text="Dictate Hotkey", font=ctk.CTkFont(size=14, weight="bold")
        ).grid(row=r, column=0, padx=20, pady=(0, 6), sticky="w"); r += 1

        hk_row = ctk.CTkFrame(self, fg_color="transparent")
        hk_row.grid(row=r, column=0, padx=20, pady=(0, 4), sticky="ew"); r += 1
        hk_row.grid_columnconfigure(1, weight=1)

        self._hotkey_enabled_var = ctk.BooleanVar(
            value=bool(self._config.get("hotkey_enabled", True))
        )
        ctk.CTkSwitch(
            hk_row, text="Enable", variable=self._hotkey_enabled_var,
            onvalue=True, offvalue=False,
        ).grid(row=0, column=0, padx=(0, 12), sticky="w")

        self._hotkey_var = ctk.StringVar(
            value=self._config.get("hotkey", DEFAULT_CONFIG["hotkey"])
        )
        ctk.CTkEntry(hk_row, textvariable=self._hotkey_var).grid(
            row=0, column=1, sticky="ew"
        )

        ctk.CTkLabel(
            self,
            text="Use pynput format, e.g.  <ctrl>+<shift>+space  or  <alt>+r",
            font=ctk.CTkFont(size=10), text_color="gray",
        ).grid(row=r, column=0, padx=20, pady=(0, 10), sticky="w"); r += 1

        # Divider
        ctk.CTkFrame(self, height=1, fg_color="gray30").grid(
            row=r, column=0, padx=20, pady=(0, 12), sticky="ew"
        ); r += 1

        # ── Advanced section ───────────────────────────────────────────────────
        ctk.CTkLabel(
            self, text="Advanced Settings", font=ctk.CTkFont(size=14, weight="bold")
        ).grid(row=r, column=0, padx=20, pady=(0, 4), sticky="w"); r += 1

        ctk.CTkLabel(
            self,
            text="⚠  Only change these if you know what you're doing.\n"
                 "Wrong values can make transcription worse or break it.",
            font=ctk.CTkFont(size=11),
            text_color="#e67e22",
            justify="left",
        ).grid(row=r, column=0, padx=20, pady=(0, 8), sticky="w"); r += 1

        adv = ctk.CTkFrame(self)
        adv.grid(row=r, column=0, padx=20, pady=(0, 16), sticky="ew"); r += 1
        adv.grid_columnconfigure(0, weight=1)

        self._adv_row(adv, 0, "Language  (e.g. en, fr, de)", "language",   "entry")
        self._adv_row(adv, 1, "VAD Filter",                  "vad_filter", "switch")
        self._adv_row(adv, 2, "Beam Size  (1–10)",           "beam_size",  "entry")
        self._adv_row(adv, 3, "Temperature  (0.0–1.0)",      "temperature","entry")
        self._adv_row(adv, 4, "Condition on prev. text",
                      "condition_on_previous_text", "switch")

        # ── Bottom buttons ─────────────────────────────────────────────────────
        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.grid(row=r, column=0, padx=20, pady=(0, 20), sticky="ew")
        btn_frame.grid_columnconfigure((0, 1), weight=1)

        ctk.CTkButton(
            btn_frame, text="Reset to Defaults",
            fg_color="gray30", hover_color="gray25",
            command=self._reset_defaults,
        ).grid(row=0, column=0, padx=(0, 8), sticky="ew")

        ctk.CTkButton(
            btn_frame, text="Apply",
            command=self._apply,
        ).grid(row=0, column=1, padx=(8, 0), sticky="ew")

    def _adv_row(self, parent, row, label, key, kind):
        ctk.CTkLabel(parent, text=label, anchor="w").grid(
            row=row, column=0, padx=(12, 8), pady=7, sticky="w"
        )
        if kind == "entry":
            var = ctk.StringVar(value=str(self._config[key]))
            w = ctk.CTkEntry(parent, textvariable=var, width=88)
        else:
            var = ctk.BooleanVar(value=bool(self._config[key]))
            w = ctk.CTkSwitch(parent, text="", variable=var,
                              onvalue=True, offvalue=False)
        w.grid(row=row, column=1, padx=(0, 12), pady=7, sticky="e")
        self._adv_widgets[key] = (kind, var)

    # ── Download logic ─────────────────────────────────────────────────────────

    def _refresh_model_status(self):
        model = self._model_seg.get()
        if ModelManager.is_downloaded(model):
            self._model_status.configure(text="● Downloaded", text_color="#27ae60")
            self._download_btn.configure(
                state="disabled", text="Downloaded ✓",
                fg_color="gray30", hover_color="gray30",
            )
        else:
            self._model_status.configure(text="● Not downloaded", text_color="gray")
            self._download_btn.configure(
                state="disabled" if self._downloading else "normal",
                text="Download",
                fg_color=["#3a7ebf", "#1f538d"],
                hover_color=["#325882", "#14375e"],
            )

        # Update hardware info
        disk, ram, cpu, gpu, note = MODEL_HW[model]
        self._hw_label.configure(
            text=f"Disk: {disk}  ·  RAM: {ram}  ·  {cpu}  ·  GPU: {gpu}\n{note}"
        )

    def _start_download(self):
        if self._downloading:
            return
        self._downloading = True
        self._download_btn.configure(state="disabled")
        self._progress.grid()
        self._progress.start()
        self._dl_label.grid()

        model = self._model_seg.get()

        def _on_progress(msg: str):
            self.after(0, lambda: self._dl_label.configure(text=msg))

        def _on_done(success: bool, error: Optional[str]):
            def _update():
                self._downloading = False
                self._progress.stop()
                self._progress.grid_remove()
                if success:
                    self._dl_label.configure(
                        text=f"{model} model downloaded.", text_color="#27ae60"
                    )
                    self._refresh_model_status()
                else:
                    self._dl_label.configure(
                        text=f"Download failed: {error}", text_color="#e74c3c"
                    )
                    self._refresh_model_status()
            self.after(0, _update)

        ModelManager.download_async(model, _on_progress, _on_done)

    # ── Apply / Reset ──────────────────────────────────────────────────────────

    def _reset_defaults(self):
        self._model_seg.set(DEFAULT_CONFIG["model_size"])
        self._hotkey_enabled_var.set(DEFAULT_CONFIG["hotkey_enabled"])
        self._hotkey_var.set(DEFAULT_CONFIG["hotkey"])
        for key, (kind, var) in self._adv_widgets.items():
            var.set(DEFAULT_CONFIG[key])
        self._refresh_model_status()

    def _apply(self):
        new_config = {
            "model_size":     self._model_seg.get(),
            "hotkey_enabled": bool(self._hotkey_enabled_var.get()),
            "hotkey":         self._hotkey_var.get().strip() or DEFAULT_CONFIG["hotkey"],
        }
        for key, (kind, var) in self._adv_widgets.items():
            if kind == "entry":
                raw = var.get().strip()
                if key == "beam_size":
                    try:
                        new_config[key] = max(1, min(10, int(raw)))
                    except ValueError:
                        new_config[key] = DEFAULT_CONFIG[key]
                elif key == "temperature":
                    try:
                        new_config[key] = max(0.0, min(1.0, float(raw)))
                    except ValueError:
                        new_config[key] = DEFAULT_CONFIG[key]
                else:
                    new_config[key] = raw  # language — empty string = auto-detect
            else:
                new_config[key] = bool(var.get())

        save_config(new_config)
        self._on_apply(new_config)
        self.destroy()


# ── Main App ───────────────────────────────────────────────────────────────────

class Talk2TextApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Talk2Text")
        self.geometry("680x520")
        self.minsize(500, 420)
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        self._config = load_config()
        self.recorder = AudioRecorder()
        self.transcriber = Transcriber()
        self.hotkey_listener = HotkeyListener()
        self._dictate_target_hwnd: Optional[int] = None
        self._timer_job = None
        self._last_save_path: Optional[str] = None
        self._settings_win: Optional[SettingsWindow] = None

        self._build_ui()
        self._load_model(self._config["model_size"])
        self._apply_hotkey(self._config)

    # ── UI Construction ────────────────────────────────────────────────────────

    def _build_ui(self):
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        # Status bar
        self.status_label = ctk.CTkLabel(
            self, text="Loading model...", font=ctk.CTkFont(size=13), text_color="gray"
        )
        self.status_label.grid(row=0, column=0, padx=20, pady=(16, 4), sticky="ew")

        # Timer
        self.timer_label = ctk.CTkLabel(
            self, text="", font=ctk.CTkFont(size=28, weight="bold")
        )
        self.timer_label.grid(row=1, column=0, padx=20, pady=(0, 8))

        # Transcript box
        self.text_box = ctk.CTkTextbox(self, font=ctk.CTkFont(size=14), wrap="word")
        self.text_box.grid(row=2, column=0, padx=20, pady=0, sticky="nsew")

        # Button row — 4 columns
        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.grid(row=3, column=0, padx=20, pady=16, sticky="ew")
        btn_frame.grid_columnconfigure(0, weight=2)
        btn_frame.grid_columnconfigure(1, weight=1)
        btn_frame.grid_columnconfigure(2, weight=1)
        btn_frame.grid_columnconfigure(3, weight=1)

        self.record_btn = ctk.CTkButton(
            btn_frame,
            text="Record",
            height=48,
            font=ctk.CTkFont(size=16, weight="bold"),
            fg_color="#c0392b",
            hover_color="#922b21",
            command=self._toggle_record,
            state="disabled",
        )
        self.record_btn.grid(row=0, column=0, padx=(0, 8), sticky="ew")

        self.copy_btn = ctk.CTkButton(
            btn_frame,
            text="Copy",
            height=48,
            font=ctk.CTkFont(size=14),
            fg_color="#2c3e50",
            hover_color="#1a252f",
            command=self._copy_to_clipboard,
            state="disabled",
        )
        self.copy_btn.grid(row=0, column=1, padx=(0, 8), sticky="ew")

        self.save_btn = ctk.CTkButton(
            btn_frame,
            text="Save As...",
            height=48,
            font=ctk.CTkFont(size=14),
            fg_color="#2c3e50",
            hover_color="#1a252f",
            command=self._save_as,
            state="disabled",
        )
        self.save_btn.grid(row=0, column=2, padx=(0, 8), sticky="ew")

        ctk.CTkButton(
            btn_frame,
            text="Settings",
            height=48,
            font=ctk.CTkFont(size=14),
            fg_color="#2c3e50",
            hover_color="#1a252f",
            command=self._open_settings,
        ).grid(row=0, column=3, sticky="ew")

        # Save path display
        self.save_path_label = ctk.CTkLabel(
            self, text="", font=ctk.CTkFont(size=11), text_color="gray", wraplength=620
        )
        self.save_path_label.grid(row=4, column=0, padx=20, pady=(0, 12))

    # ── Hotkey ────────────────────────────────────────────────────────────────

    def _idle_status(self) -> str:
        size = self._config["model_size"]
        if self._config.get("hotkey_enabled") and self._config.get("hotkey"):
            hk = _format_hotkey(self._config["hotkey"])
            return f"Ready ({size}) · {hk} to dictate"
        return f"Ready ({size}) — press Record to start"

    def _apply_hotkey(self, config: dict) -> None:
        if config.get("hotkey_enabled") and config.get("hotkey"):
            def _on_hotkey():
                # Capture active window NOW before anything changes (Windows only).
                # On other platforms use -1 as a sentinel so clipboard copy still fires.
                if sys.platform == "win32":
                    import ctypes
                    hwnd = ctypes.windll.user32.GetForegroundWindow()
                else:
                    hwnd = -1
                self.after(0, lambda: self._toggle_record_via_hotkey(hwnd))
            self.hotkey_listener.start(config["hotkey"], _on_hotkey)
        else:
            self.hotkey_listener.stop()

    def _toggle_record_via_hotkey(self, hwnd: int) -> None:
        if self.recorder.recording:
            self._stop_record()
        elif self.record_btn.cget("state") == "normal":
            # Guard: if button is disabled (model loading or transcribing), ignore.
            # pynput fires this callback twice per keypress on Windows — the second
            # fire would otherwise restart recording mid-transcription, causing a
            # second paste when that accidental recording finishes.
            self._dictate_target_hwnd = hwnd or None
            self._start_record()

    def _paste_to_dictate_target(self, text: str) -> None:
        hwnd = self._dictate_target_hwnd
        self._dictate_target_hwnd = None
        if not hwnd:
            return
        if sys.platform != "win32":
            # On Mac put text in clipboard; user pastes manually with Cmd+V.
            self.clipboard_clear()
            self.clipboard_append(text)
            return

        def _do_paste():
            import ctypes
            import ctypes.wintypes as wt
            import time
            user32 = ctypes.windll.user32
            kernel32 = ctypes.windll.kernel32
            if not user32.IsWindow(hwnd):
                print("[Paste] Target window no longer exists")
                return
            # Restore and bring target window to front
            user32.ShowWindow(hwnd, 9)   # SW_RESTORE
            user32.SetForegroundWindow(hwnd)
            time.sleep(0.15)             # let focus settle

            # Set clipboard via Win32 API directly — avoids Tkinter releasing
            # ownership when its window loses focus (which would empty the clipboard
            # before the paste fires).
            CF_UNICODETEXT = 13
            GMEM_MOVEABLE = 0x0002
            text_bytes = (text + "\0").encode("utf-16-le")
            h = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(text_bytes))
            p = kernel32.GlobalLock(h)
            ctypes.memmove(p, text_bytes, len(text_bytes))
            kernel32.GlobalUnlock(h)
            user32.OpenClipboard(0)
            user32.EmptyClipboard()
            user32.SetClipboardData(CF_UNICODETEXT, h)
            user32.CloseClipboard()

            # Send Ctrl+V via SendInput — bypasses pynput's hook pipeline.
            # INPUT must be exactly 40 bytes on 64-bit Windows; including MOUSEINPUT
            # in the union ensures the union is 32 bytes so INPUT = 4+4+32 = 40.
            VK_CONTROL, VK_V, KEYEVENTF_KEYUP, INPUT_KEYBOARD = 0x11, 0x56, 0x0002, 1

            class KEYBDINPUT(ctypes.Structure):
                _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD),
                            ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                            ("dwExtraInfo", ctypes.c_uint64)]  # ULONG_PTR

            class MOUSEINPUT(ctypes.Structure):
                _fields_ = [("dx", wt.LONG), ("dy", wt.LONG),
                            ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD),
                            ("time", wt.DWORD), ("dwExtraInfo", ctypes.c_uint64)]

            class _INPUTunion(ctypes.Union):
                _fields_ = [("ki", KEYBDINPUT), ("mi", MOUSEINPUT)]

            class INPUT(ctypes.Structure):
                _fields_ = [("type", wt.DWORD), ("_input", _INPUTunion)]

            def mk(vk, flags=0):
                i = INPUT(type=INPUT_KEYBOARD)
                i._input.ki = KEYBDINPUT(wVk=vk, dwFlags=flags)
                return i

            seq = (INPUT * 4)(mk(VK_CONTROL), mk(VK_V),
                              mk(VK_V, KEYEVENTF_KEYUP), mk(VK_CONTROL, KEYEVENTF_KEYUP))
            user32.SendInput(4, seq, ctypes.sizeof(INPUT))
            print(f"[Paste] Pasted into window {hwnd}")

        threading.Thread(target=_do_paste, daemon=True).start()

    # ── Model Loading ──────────────────────────────────────────────────────────

    def _load_model(self, model_size: str) -> None:
        self.record_btn.configure(state="disabled")
        self.status_label.configure(
            text=f"Loading {model_size} model...", text_color="gray"
        )
        self.transcriber.load(model_size, on_done=self._on_model_loaded)

    def _on_model_loaded(self, success: bool, error: Optional[str]) -> None:
        def _update():
            if success:
                self.status_label.configure(text=self._idle_status(), text_color="gray")
                self.record_btn.configure(state="normal")
            else:
                self.status_label.configure(
                    text=f"Model load failed: {error}", text_color="#e74c3c"
                )
        self.after(0, _update)

    # ── Settings ──────────────────────────────────────────────────────────────

    def _open_settings(self) -> None:
        if self._settings_win and self._settings_win.winfo_exists():
            self._settings_win.focus()
            return
        self._settings_win = SettingsWindow(
            self, self._config, on_apply=self._on_settings_applied
        )

    def _on_settings_applied(self, new_config: dict) -> None:
        old_model = self._config.get("model_size")
        self._config = new_config
        self._apply_hotkey(new_config)
        if new_config["model_size"] != old_model:
            self._load_model(new_config["model_size"])
        else:
            self.status_label.configure(text=self._idle_status(), text_color="gray")

    # ── Recording ─────────────────────────────────────────────────────────────

    def _toggle_record(self):
        if self.recorder.recording:
            self._stop_record()
        else:
            self._start_record()

    def _start_record(self):
        ok = self.recorder.start()
        if not ok:
            self.status_label.configure(
                text="Could not open microphone. Check permissions.",
                text_color="#e74c3c",
            )
            return

        self.record_btn.configure(
            text="Stop Recording", fg_color="#27ae60", hover_color="#1e8449"
        )
        self.save_btn.configure(state="disabled")
        self.copy_btn.configure(state="disabled")
        self.text_box.delete("1.0", "end")
        self.save_path_label.configure(text="")
        self._last_save_path = None
        self.status_label.configure(text="Recording...", text_color="#e74c3c")
        self._tick_timer()

    def _stop_record(self):
        self._cancel_timer()
        audio_path = self.recorder.stop()

        self.record_btn.configure(
            text="Record", fg_color="#c0392b", hover_color="#922b21", state="disabled"
        )
        self.timer_label.configure(text="")
        self.status_label.configure(text="Transcribing...", text_color="gray")

        if audio_path:
            self.transcriber.transcribe_async(
                audio_path,
                config=self._config,
                on_done=self._on_transcribed,
                on_error=self._on_transcribe_error,
            )
        else:
            self.status_label.configure(
                text="No audio captured. Try again.", text_color="#e74c3c"
            )
            self.record_btn.configure(state="normal")

    # ── Timer ─────────────────────────────────────────────────────────────────

    def _tick_timer(self):
        elapsed = self.recorder.duration()
        self.timer_label.configure(
            text=f"{int(elapsed) // 60:02d}:{int(elapsed) % 60:02d}"
        )
        self._timer_job = self.after(200, self._tick_timer)

    def _cancel_timer(self):
        if self._timer_job:
            self.after_cancel(self._timer_job)
            self._timer_job = None

    # ── Transcription ─────────────────────────────────────────────────────────

    def _on_transcribed(self, text: str):
        def _update():
            self.text_box.delete("1.0", "end")
            self.text_box.insert("1.0", text)
            self.record_btn.configure(state="normal")

            save_path = self._auto_save(text)
            if save_path:
                self.status_label.configure(text="Done! Saved automatically.", text_color="#27ae60")
                self.save_path_label.configure(text=save_path)
                self._last_save_path = save_path
            else:
                self.status_label.configure(text="Done! (auto-save failed)", text_color="gray")

            self.save_btn.configure(state="normal" if text else "disabled")
            self.copy_btn.configure(state="normal" if text else "disabled")

            # If triggered via hotkey, paste into the original window
            if self._dictate_target_hwnd and text:
                self._paste_to_dictate_target(text)

        self.after(0, _update)

    def _on_transcribe_error(self, error: str):
        def _update():
            self.status_label.configure(
                text=f"Transcription failed: {error}", text_color="#e74c3c"
            )
            self.record_btn.configure(state="normal")
        self.after(0, _update)

    # ── Saving ────────────────────────────────────────────────────────────────

    def _auto_save(self, text: str) -> Optional[str]:
        try:
            TRANSCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
            path = TRANSCRIPTS_DIR / f"{timestamp}.txt"
            path.write_text(text, encoding="utf-8")
            return str(path)
        except Exception as e:
            print(f"[Save] Auto-save failed: {e}")
            return None

    def _copy_to_clipboard(self):
        text = self.text_box.get("1.0", "end").strip()
        if text:
            self.clipboard_clear()
            self.clipboard_append(text)
            self.status_label.configure(text="Copied to clipboard!", text_color="#27ae60")
            self.after(2000, lambda: self.status_label.configure(
                text=self._idle_status(), text_color="gray"
            ))

    def _save_as(self):
        from tkinter import filedialog
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        initial = self._last_save_path or str(TRANSCRIPTS_DIR / f"{timestamp}.txt")
        path = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")],
            initialfile=Path(initial).name,
            initialdir=str(TRANSCRIPTS_DIR),
            title="Save Transcript As",
        )
        if path:
            try:
                text = self.text_box.get("1.0", "end").strip()
                Path(path).write_text(text, encoding="utf-8")
                self.save_path_label.configure(text=path)
                self.status_label.configure(text="Saved!", text_color="#27ae60")
            except Exception as e:
                self.status_label.configure(text=f"Save failed: {e}", text_color="#e74c3c")


# ── Entry Point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    app = Talk2TextApp()
    app.mainloop()
