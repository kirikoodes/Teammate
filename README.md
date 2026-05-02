# TEAMMATE.POTO — Norns

*An improvisation partner, not an accompanist.*  
*Un partenaire d'improvisation, pas un accompagnateur.*

---

## English

Inspired by **Somax2** — a co-improvisation system developed at IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) by the Music Representations research team. Somax introduced the idea that a machine could listen to a musician, build a musical memory from what it hears, and navigate that memory in real time to improvise back. That idea changed how I think about human-machine dialogue in music.

TEAMMATE takes that same core intuition — the machine learns only from you, in the moment — and pushes it toward something rawer and more physical.

Everything you play gets sliced into a memory of 48 sound fragments: pitch, energy, timbre, texture. When you stop, TEAMMATE analyzes the whole phrase and decides what to do. Imitate. Contrast. Densify. Thin out. Stay silent. It never plays something it hasn't heard from you. No generative AI, no presets — pure *remémoration*.

Three layers running in parallel:

- **The dialogue** — phrase by phrase. TEAMMATE waits, listens, builds a portrait of what you just played, and responds from its own memory.
- **POtO** — a granular halo of the last 4 seconds of your performance. Three readers orbiting your sound: one locked to the present, one drifting toward it, one pushed toward the past.
- **8OS** — record a sequence, let it slice itself into analyzed grains. In TRANS mode, three voices scan the bank and pull the grains that match your live pitch and energy in real time.

Running on a Monome Norns. Lua + SuperCollider. Ported from a 12,000-line Python original.

---

## Français

Inspiré par **Somax2** — un système de co-improvisation développé à l'IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) par l'équipe Music Representations. Somax a introduit l'idée qu'une machine pouvait écouter un musicien, construire une mémoire musicale de ce qu'elle entend, et naviguer dans cette mémoire en temps réel pour improviser en retour. Cette idée a changé ma façon de penser le dialogue homme-machine en musique.

TEAMMATE part de la même intuition fondamentale — la machine n'apprend que de toi, dans l'instant — et la pousse vers quelque chose de plus brut et de plus physique.

Tout ce que tu joues est découpé en une mémoire de 48 fragments sonores : pitch, énergie, timbre, texture. Quand tu t'arrêtes, TEAMMATE analyse la phrase entière et décide quoi faire. Imiter. Contraster. Densifier. Espacer. Se taire. Il ne joue jamais quelque chose qu'il n'a pas entendu de toi. Pas d'IA générative, pas de presets — de la **remémoration active**.

Trois couches en parallèle :

- **Le dialogue** — phrase par phrase. TEAMMATE attend, écoute, construit un portrait de ce que tu viens de jouer, et répond depuis sa propre mémoire.
- **POtO** — un halo granulaire des 4 dernières secondes de ta performance. Trois lecteurs qui orbitent autour de ton son : un ancré dans le présent, un qui dérive vers lui, un poussé vers le passé.
- **8OS** — enregistre une séquence, laisse-la se découper en grains analysés. En mode TRANS, trois voix scannent le bank et tirent les grains qui correspondent à ton pitch et ton énergie live en temps réel.

Tourne sur un Monome Norns. Lua + SuperCollider. Porté depuis un original Python de 12 000 lignes.

---

## Install

From **MAIDEN** (Norns web editor), type in the bottom console:

```
;install https://github.com/kirikoodes/Teammate
```

Then **SYSTEM > RESTART** to reload the SuperCollider engines.

---

## Quick start

1. Plug instrument or mic into Norns input
2. Load **TEAMMATE.POTO** from SELECT
3. Page 1 CORPUS: adjust `E3 thr` to your noise floor (start at `0.003`)
4. Play — TEAMMATE listens and starts responding after a few recorded sounds
5. Watch the `c:X/48` counter top left

---

## Navigation

```
E1        — previous / next page (bidirectional, loops 1→11)
K2        — next page
K3        — main action for current page (see table)
```

---

## The 11 pages

### Page 1 — CORPUS
Short-term memory. Everything you play is sliced into events.

| Encoder | Function |
|---|---|
| E2 | Learning rate 0–100% (`FROZEN` at 0) |
| E3 | Gate threshold (noise floor) |
| K3 | Clear corpus |

- **48-slot grid**: each slot = one recorded sound (energy, pitch, duration)
- **FROZEN**: corpus frozen, TEAMMATE plays from memory without learning anything new
- **Red dot** top right: recording in progress

---

### Page 2 — MAIN
Global improvisation behavior.

| Encoder | Function |
|---|---|
| E2 | Response density (events per phrase) |
| E3 | Silence bias (probability of staying silent) |
| K3 | Force immediate response |

---

### Page 3 — RESP
Response quality.

| Encoder | Function |
|---|---|
| E2 | Contrast (0 = imitate, 1 = oppose) |
| E3 | Probability of responding to each phrase |
| K3 | Deaf mode ON/OFF |

- **Deaf mode**: TEAMMATE ignores audio input and improvises autonomously from the corpus

---

### Page 4 — TIME
Exchange timing.

| Encoder | Function |
|---|---|
| E2 | `react` — minimum silence to seal a fragment (default 0.8s) |
| E3 | `init` — minimum silence before TEAMMATE takes initiative (default 1.5s) |
| K3 | Voice mode ON/OFF |

- **Voice mode**: minimum syllable duration 120ms, adapted for singing and speech

---

### Page 5 — POtO
Real-time granular texture over the last 4 seconds.

| Encoder | Function |
|---|---|
| E2 | POtO volume |
| E3 | Monitor (direct signal volume at output) |
| K3 | POtO ON/OFF |

- Three readers: **LEAD** (fresh zone), **ATTRACTED** (drifts toward LEAD), **REPULSED** (pushed toward the past)

---

### Page 6 — GRAIN
POtO grain parameters.

| Encoder | Function |
|---|---|
| E2 | Grain size (ms) |
| E3 | Spread / detune between readers |
| K3 | Rate preset (0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0) |

---

### Page 7 — 8OS
Long-memory granular sampler. Records a full sequence, then replays grains selected by pitch + energy matching.

| Encoder | Function |
|---|---|
| E2 | 8OS volume |
| E3 | Grain size (ms) |
| K3 | Cycle OFF → REC → TRANS |

```
K3 → REC   : continuous recording into 20s buffer
              grains created automatically every [grain ms]

K3 → TRANS : playback — 3 voices search for grains
              closest to your live pitch + energy
              (full MIDI matching with octave)

K3 → OFF   : stop
```

- Grain selection: combined score pitch 55% + energy 35% + timbre 10%
- **3 LOCK voices**: all search for the closest grains (polyphony)
- Bank persists when switching from REC to TRANS

---

### Page 8 — CLR8OS
Confirmation page to clear the 8OS bank.

| Encoder | Function |
|---|---|
| K3 | Clear 8OS bank |

---

### Page 9 — MIDI I
MIDI for TEAMMATE improvisation (notes tied to played grains).

| Encoder | Function |
|---|---|
| E2 | MIDI channel (1–16) |
| E3 | MIDI device (1–4) |
| K3 | MIDI IMPRO ON/OFF |

---

### Page 10 — MIDI P
MIDI for POtO grains.

| Encoder | Function |
|---|---|
| E2 | MIDI channel (1–16) |
| E3 | MIDI device (1–4) |
| K3 | MIDI POtO ON/OFF |

---

### Page 11 — MIDI 8
MIDI for 8OS grains.

| Encoder | Function |
|---|---|
| E2 | MIDI channel (1–16) |
| E3 | MIDI device (1–4) |
| K3 | MIDI 8OS ON/OFF |

> The 3 MIDI streams (IMPRO / POtO / 8OS) each have their own independent device — you can send to 2 different destinations simultaneously.

---

## Screen indicators

| Indicator | Meaning |
|---|---|
| Red `●` (top right) | Corpus recording in progress |
| `FROZEN` (page 1) | Corpus frozen, 0% learning |
| `V` (top right) | Voice mode active |
| `D` (top right) | Deaf mode active |
| `VD` | Both active |

---

## The 5 strategies

TEAMMATE chooses its response strategy probabilistically, weighted by the current musical context:

| Strategy | Intent |
|---|---|
| **IMITATION** | Reproduce the energy and timbre of your phrase |
| **CONTRASTE** | Choose the sound furthest from what you just played |
| **DENSIFICATION** | Respond with more events, more tightly packed |
| **SPARSE** | Slow down, spread out, create space |
| **SILENCE** | Say nothing — a musical gesture in itself |

---

## Softcut layout (technical reference)

| Voice | Role |
|---|---|
| V1 | Corpus recording |
| V2 | Corpus playback |
| V3 | Corpus playback (borrowed by 8OS TRANS or POtO REPULSED) |
| V4 | Continuous POtO recording + 8OS recording |
| V5 | POtO LEAD / 8OS LOCK #1 |
| V6 | POtO ATTRACTED / 8OS LOCK #2 |

---

*Norns port (Lua + SuperCollider) of a Python original — NSDOS 2026*
