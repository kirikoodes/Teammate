# TEAMMATE.POTO

**by NSDOS / KOODES — 2026**

---

*There is a presence in the room with you.*  
*It does not play what you tell it to play.*  
*It plays what you already played — broken open, rearranged,*  
*sent back to you as something almost familiar.*

---

TEAMMATE.POTO is a real-time audio improvisation engine with granular sampling (POtO), multi-layer AI analysis, and stereo output. It listens to you, builds a corpus of your sound in real time, and responds — in grains, in fragments, in strategies.

Feed it noise. Feed it music. Feed it silence.

---

## What it does

- **Listens** to your audio input and builds an ephemeral corpus in real time
- **Responds** using granular synthesis (POtO) — fragments of your own sound, rearranged
- **Adapts** its strategy: IMITATION / CONTRASTE / DENSIFICATION / SPARSE / SILENCE
- **Learns** your playing habits across sessions (style profiling)
- **Detects** musical structure in real time (INTRO / BUILD / PEAK / DECAY / SILENCE)
- **Transforms** audio neurally via RAVE TorchScript models (optional)
- **Controls** over MIDI in/out, XY mouse controller, and ASCII interactive menu

---

## Installation

### PC — Windows (build your own exe)

**Requirements:** Python 3.10, 3.11 or 3.12 — [python.org](https://python.org)  
During install, check **"Add Python to PATH"**.

1. Download the `PC/` folder
2. Double-click `build_pc.bat`
3. Wait — the exe is generated in `PC/dist/TEAMMATE.POTO.exe`
4. Copy `dist/TEAMMATE.POTO.exe` wherever you want and run it

The build script installs all dependencies and PyInstaller automatically.

> To run from source without building:
> ```
> python TEAMMATE_PC.POTO run
> ```

### Mac — macOS

1. Download the `MAC/` folder
2. Double-click `TEAMMATE.POTO.command`

That's it. The launcher installs everything automatically on first run (Python deps + portaudio via Homebrew).

**Requirements:** Python 3.10 or 3.11 — [python.org](https://python.org)

If double-click is blocked by macOS (security prompt):
```bash
chmod +x TEAMMATE.POTO.command
```

If you don't have Homebrew:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## Essential commands

```
r                    random parameters (feel + swarm)
/help                full command list
/status              system state
/menu                interactive parameter matrix
0                    clear corpus
/quit                quit cleanly

/teammate-on/off     enable/disable TEAMMATE response
/audio-on/off        enable/disable audio output
/capture-on/off      enable/disable mic capture
/ghost-on/off        mute your playback — TEAMMATE keeps going
```

---

## POtO — Granular engine

```
o    rec grains ON/OFF
p    granular performance ON/OFF
l    clear grain cloud
m    status

/poto-voices 3             chord voices (1–8)
/poto-gain 0.7             output gain
/poto-grain-ms 80          grain size in ms (20–500)
/poto-input mic|teammate|both
```

---

## RAVE — Neural transformation (optional)

Place your `.ts` TorchScript models in a `rave_models/` folder next to the script.

```
/rave-models        list available models
/rave-load 0        load model #0
/rave-on / off      enable/disable
/rave-status        loaded model info
```

---

## AI layers (all optional, graceful fallback)

| Library | Features |
|---------|----------|
| `aubio` | YIN pitch, onset detection, BPM |
| `librosa` | MFCC, chroma, spectral analysis |
| `torch` | required for RAVE |

```bash
pip install aubio librosa
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

```
/lib-status    check all AI layers
```

---

## Session recording (for RAVE training)

```
/rec-start [name]    record stereo 48kHz WAV
/rec-stop
/rec-status          elapsed time, file size
```

---

## Quick profiles

```
/profile ambient        dense, swarm active, light compression
/profile acoustique     balanced, natural response (default)
/profile rythmique      high density, strong contrast, short phrases
```

---

## Saves

```
/save [name]    save parameters to saves/name.json
/load [name]    load
/saves          list saves
```

---

NSDOS / KOODES — 2026
