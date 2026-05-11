# TEAMMATE.POTO — Norns

*An improvisation partner, not an accompanist.*  
*Un partenaire d'improvisation, pas un accompagnateur.*

---

## English

Inspired by **Somax2** — a co-improvisation system developed at IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) by the Music Representations research team. Somax introduced the idea that a machine could listen to a musician, build a musical memory from what it hears, and navigate that memory in real time to improvise back. That idea changed how I think about human-machine dialogue in music.

TEAMMATE takes that same core intuition — the machine learns only from you, in the moment — and pushes it toward something rawer and more physical.

Everything you play gets sliced into a memory of 48 sound fragments: pitch, energy, timbre, texture. When you stop, TEAMMATE analyzes the whole phrase and decides what to do. Imitate. Contrast. Densify. Thin out. Stay silent. It never plays something it hasn't heard from you. No generative AI, no presets — pure *remémoration*.

Four layers running in parallel:

- **The dialogue** — phrase by phrase. TEAMMATE waits, listens, builds a portrait of what you just played, and responds from its own memory.
- **POtO** — a granular halo of the last 4 seconds of your performance. Three readers orbiting your sound: one locked to the present, one drifting toward it, one pushed toward the past.
- **8OS** — record a sequence, let it slice itself into analyzed grains. In TRANS mode, three voices scan the bank and pull the grains that match your live pitch and energy in real time.
- **MIDI GEN** — a generative melodic sequencer running in parallel. Up to 16 independent channels, each with its own style, octave, and sequence. 9 styles: Techno, DnB, Jungle, Amapiano, 2-step garage, Brokenbeat, Dumbstep, Trap, Drill. 17 break types. Syncs to external MIDI clock automatically. Sends MIDI to your synths while TEAMMATE improvises.

Running on a Monome Norns. Lua + SuperCollider. Ported from a 12,000-line Python original.

---

## Français

Inspiré par **Somax2** — un système de co-improvisation développé à l'IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) par l'équipe Music Representations. Somax a introduit l'idée qu'une machine pouvait écouter un musicien, construire une mémoire musicale de ce qu'elle entend, et naviguer dans cette mémoire en temps réel pour improviser en retour. Cette idée a changé ma façon de penser le dialogue homme-machine en musique.

TEAMMATE part de la même intuition fondamentale — la machine n'apprend que de toi, dans l'instant — et la pousse vers quelque chose de plus brut et de plus physique.

Tout ce que tu joues est découpé en une mémoire de 48 fragments sonores : pitch, énergie, timbre, texture. Quand tu t'arrêtes, TEAMMATE analyse la phrase entière et décide quoi faire. Imiter. Contraster. Densifier. Espacer. Se taire. Il ne joue jamais quelque chose qu'il n'a pas entendu de toi. Pas d'IA générative, pas de presets — de la **remémoration active**.

Quatre couches en parallèle :

- **Le dialogue** — phrase par phrase. TEAMMATE attend, écoute, construit un portrait de ce que tu viens de jouer, et répond depuis sa propre mémoire.
- **POtO** — un halo granulaire des 4 dernières secondes de ta performance. Trois lecteurs qui orbitent autour de ton son : un ancré dans le présent, un qui dérive vers lui, un poussé vers le passé.
- **8OS** — enregistre une séquence, laisse-la se découper en grains analysés. En mode TRANS, trois voix scannent le bank et tirent les grains qui correspondent à ton pitch et ton énergie live en temps réel.
- **MIDI GEN** — un séquenceur mélodique génératif qui tourne en parallèle. Jusqu'à 16 channels indépendants, chacun avec son style, son octave et sa séquence. 9 styles : Techno, DnB, Jungle, Amapiano, 2-step garage, Brokenbeat, Dumbstep, Trap, Drill. 16 types de break. Sync automatique sur clock MIDI externe. Envoie du MIDI vers tes synthés pendant que TEAMMATE improvise.

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
E1        — previous / next page (loops 1→15)
K3        — main action for current page (see table)
```

---

## The 15 pages

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

### Page 6 — 8OS
Long-memory granular sampler. Records a full sequence, then replays grains selected by pitch + energy matching.

| Encoder / Key | Function |
|---|---|
| E2 | 8OS volume |
| E3 | Grain size (ms) |
| K3 | Cycle OFF → REC → TRANS |
| K2 | Toggle clock sync ON / OFF (TRANS mode) |

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
- **K2 SYNC**: in TRANS mode, grain triggers are quantized to 1/16th note boundaries following the Norns clock — locks 8OS to the same grid as MIDI GEN and any external device (OP-Z, OP-1…). Screen shows `K2 SYNC` when active.

*Sampler granulaire longue mémoire. Enregistre une séquence complète, puis rejoue des grains sélectionnés par matching pitch + énergie.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Volume 8OS |
| E3 | Taille de grain (ms) |
| K3 | Cycle OFF → REC → TRANS |
| K2 | Activer / désactiver la sync clock (mode TRANS) |

- **K2 SYNC** : en mode TRANS, les déclenchements de grains sont quantizés sur les subdivisions 1/16 de la clock Norns — cale le 8OS sur la même grille que le MIDI GEN et tout device externe (OP-Z, OP-1…). L'écran affiche `K2 SYNC` quand actif.

---

### Page 7 — GRAIN
POtO grain parameters.

| Encoder | Function |
|---|---|
| E2 | Grain size (ms) |
| E3 | Spread / detune between readers |
| K3 | Rate preset (0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0) |

---

### Page 8 — CLR8OS
Confirmation page to clear the 8OS bank.

| Key | Function |
|---|---|
| K3 | Clear 8OS bank |

---

### Pages 9–12 — MIDI DEV 1–4
Independent MIDI routing per device. Each page configures one physical MIDI output.

| Encoder | Function |
|---|---|
| E2 | Select stream (IMPRO / POtO / 8OS) |
| E3 | MIDI channel (1–16) for selected stream |
| K3 | Toggle routing ON/OFF for selected stream on this device |

- Each stream (IMPRO, POtO, 8OS) can be routed to any combination of the 4 devices
- Each device has its own independent channel per stream
- `[X]` = stream routed to this device / `[ ]` = not routed

> The 3 MIDI streams send notes tied to grain playback. IMPRO follows the corpus improvisation, POtO follows the granular halo, 8OS follows TRANS mode grain matching.

---

### Page 13 — MGEN GLOBAL
Generative MIDI sequencer — global controls. Runs in parallel with the corpus improvisation.

| Encoder | Function |
|---|---|
| E2 | BPM (60–200) |
| E3 | Scale (MINOR / PHRYG / BLUES / DORIC / MAJOR / PENMIN / PENMAJ) |
| K2 | Tap tempo — tap in rhythm to lock BPM (averages last 4 taps, resets after 3s) |
| K3 | START (generates all sequences + launches) / STOP + all notes off |

- Sends MIDI to **device 1**, one MIDI channel per generator channel (ch1→MIDI ch1, ch2→MIDI ch2…)
- All 16 sequences are generated randomly at startup and on each START
- **External MIDI clock**: TEAMMATE listens for raw 0xF8 clock pulses on any connected USB MIDI device. When a valid pulse stream is detected (after 4 pulses), BPM is calculated automatically (24 pulses per beat) and the sequencer locks step advances directly to incoming pulses — 6 pulses per 1/16 step, phase-aligned. Works on Norns Shield without any `SYSTEM > CLOCK` setting.
- **`EXT 128`** displayed (bright) on this page when external clock is active. **`bpm 128`** (dim) when running on internal clock.
- **Internal BPM**: Use E2 or K2 tap tempo when no external clock is connected. Screen shows `K2:tap` or `TAP n` while tapping.

*Séquenceur MIDI génératif — contrôles globaux. Tourne en parallèle de l'improvisation corpus.*

| Encodeur | Fonction |
|---|---|
| E2 | BPM (60–200) |
| E3 | Gamme (MINOR / PHRYG / BLUES / DORIC / MAJOR / PENMIN / PENMAJ) |
| K2 | Tap tempo — tape en rythme pour verrouiller le BPM (moyenne sur 4 taps, reset après 3s) |
| K3 | START (génère toutes les séquences + lance) / STOP + all notes off |

- Envoie le MIDI sur le **device 1**, un canal MIDI par channel générateur (ch1→MIDI ch1, ch2→MIDI ch2…)
- Les 16 séquences sont générées aléatoirement au démarrage et à chaque START
- **Clock MIDI externe** : TEAMMATE écoute les pulses bruts 0xF8 sur tous les devices USB MIDI connectés. Dès que 4 pulses valides sont reçus, le BPM est calculé et le séquenceur cale chaque step directement sur les pulses entrants — 6 pulses par step 1/16, phase alignée. Fonctionne sur Norns Shield sans réglage `SYSTEM > CLOCK`.
- **`EXT 128`** s'affiche en blanc sur cette page quand la clock externe est active. **`bpm 128`** en gris quand le clock est interne.
- **BPM interne** : utilise E2 ou le tap tempo K2 quand aucune clock externe n'est connectée. L'écran affiche `K2:tap` ou `TAP n` pendant le tap.

---

### Page 14 — MGEN CHANNELS
Per-channel configuration. Shows 4 channels at a time, scrolls automatically with E2.

| Encoder | Function |
|---|---|
| E2 | Select channel (1–16) |
| E3 | Style for selected channel — regenerates its sequence |
| K3 | Toggle selected channel ON / OFF |

**Styles:**

| Style | BPM range | Init octave | Character |
|---|---|---|---|
| **TECH** (Techno) | 130–150 | 2–4 | Ostinato, repetitive, heavy downbeats, tight syncopation |
| **DnB** | 160–180 | 2–4 | Syncopated basslines, half-time feel, interval jumps |
| **JGL** (Jungle) | 165–175 | 2–5 | Chromatic fills, irregular density, Amen-break energy |
| **AMPR** (Amapiano) | 112–116 | 3–5 | Jazz harmonics, log-drum feel, melodic runs, wide gate |
| **2STP** (2-step garage) | 128–135 | 2–4 | Off-beat syncopation, soulful intervals, UK garage feel |
| **BRKN** (Brokenbeat) | 90–108 | 3–5 | Jazz harmony, avoids downbeat, irregular placement, wide gate |
| **DUMB** (Dumbstep) | 138–150 | 3–4 | Half-time, very sparse, heavy hits, long sustain |
| **TRAP** | 130–170 | 3–5 | Sparse hits, short gate, strong 1 and off-beat accents |
| **DRIL** (Drill) | 140–155 | 3–5 | Chromatic dark intervals, syncopated, medium register |

- **Init octave** is set randomly at startup (K3 START) — never overwritten when changing style
- Adjust octave freely per channel with **E3 on page 15** — style changes on page 14 leave octave untouched

*Configuration par channel. Affiche 4 channels à la fois, scroll automatique avec E2.*

| Encodeur | Fonction |
|---|---|
| E2 | Sélectionner le channel (1–16) |
| E3 | Style du channel sélectionné — régénère sa séquence |
| K3 | Activer / désactiver le channel sélectionné |

**Styles :**

| Style | Plage BPM | Octave init | Caractère |
|---|---|---|---|
| **TECH** (Techno) | 130–150 | 2–4 | Ostinato, répétitif, temps forts lourds, syncopes serrées |
| **DnB** | 160–180 | 2–4 | Basslines syncopées, half-time feel, sauts d'intervalles |
| **JGL** (Jungle) | 165–175 | 2–5 | Fills chromatiques, densité irrégulière, énergie Amen-break |
| **AMPR** (Amapiano) | 112–116 | 3–5 | Harmonies jazz, log-drum feel, runs mélodiques, gate large |
| **2STP** (2-step garage) | 128–135 | 2–4 | Syncopes off-beat, intervalles soul, feel UK garage |
| **BRKN** (Brokenbeat) | 90–108 | 3–5 | Harmonie jazz, évite le downbeat, placement irrégulier, gate large |
| **DUMB** (Dumbstep) | 138–150 | 3–4 | Half-time, très sparse, hits lourds, longue tenue |
| **TRAP** | 130–170 | 3–5 | Hits sparse, gate court, fort accent 1 et contretemps |
| **DRIL** (Drill) | 140–155 | 3–5 | Intervalles chromatiques sombres, syncopé, registre médium |

- **Octave init** : tiré aléatoirement au démarrage (K3 START) — jamais écrasé lors d'un changement de style
- Ajuste l'octave librement par channel avec **E3 page 15** — changer de style page 14 ne touche pas à l'octave

---

### Page 15 — MGEN BREAK
One-cycle rupture applied to all active channels simultaneously.

| Encoder | Function |
|---|---|
| E2 | Break type |
| E3 | Octave for channel selected on page 14 — regenerates sequence at new octave |
| K3 | Fire break on all active channels (lasts one full cycle, then resumes) |

**Break types:**

| # | Type | Effect |
|---|---|---|
| 1 | **RAND** | Random step from sequence each tick |
| 2 | **ACNT** | All steps active, velocity max |
| 3 | **STUT** | Loop first 2 steps, gate halved — micro-stutter |
| 4 | **LP1** | Loop on step 1 only |
| 5 | **LP2** | Loop on first 2 steps |
| 6 | **LP3** | Loop on first 3 steps |
| 7 | **LP4** | Loop on first 4 steps |
| 8 | **-OCT** | All notes −1 octave |
| 9 | **+OCT** | All notes +1 octave |
| 10 | **REV** | Sequence plays backward |
| 11 | **F32** | All steps active, very short gate — 32nd flood |
| 12 | **F16** | All steps active, medium gate — 16th flood |
| 13 | **F8** | Odd steps only, long gate — 8th note legato |
| 14 | **F4** | Every 4 steps, very long gate — quarter note legato |
| 15 | **CHOS** | Random note from current scale, original rhythm |
| 16 | **DRNK** | Drunk walk — step index wanders ±2 each tick |
| 17 | **SKIP** | Even steps muted — odd grid only |

*Rupture d'un cycle appliquée à tous les channels actifs simultanément.*

| Encodeur | Fonction |
|---|---|
| E2 | Type de break |
| E3 | Octave du channel sélectionné en page 14 — régénère la séquence au nouvel octave |
| K3 | Déclencher le break sur tous les channels ON (dure un cycle complet, puis reprend) |

**Types de break :**

| # | Type | Effet |
|---|---|---|
| 1 | **RAND** | Step aléatoire dans la séquence à chaque tick |
| 2 | **ACNT** | Tous les steps actifs, velocity max |
| 3 | **STUT** | Boucle 2 premiers steps, gate divisé par 2 — micro-stutter |
| 4 | **LP1** | Boucle sur le step 1 uniquement |
| 5 | **LP2** | Boucle sur les 2 premiers steps |
| 6 | **LP3** | Boucle sur les 3 premiers steps |
| 7 | **LP4** | Boucle sur les 4 premiers steps |
| 8 | **-OCT** | Toutes les notes −1 octave |
| 9 | **+OCT** | Toutes les notes +1 octave |
| 10 | **REV** | Séquence à l'envers |
| 11 | **F32** | Tous les steps actifs, gate très court — flood de croches |
| 12 | **F16** | Tous les steps actifs, gate moyen — flood de doubles croches |
| 13 | **F8** | Steps impairs, gate long — croches en legato |
| 14 | **F4** | Tous les 4 steps, gate très long — noires en legato |
| 15 | **CHOS** | Note aléatoire dans la gamme courante, rythme original |
| 16 | **DRNK** | Drunk walk — index dévie de ±2 à chaque step |
| 17 | **SKIP** | Steps pairs muets — grille impaire seulement |

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
| V3 | Corpus playback (borrowed by 8OS TRANS) |
| V4 | Continuous POtO recording + 8OS recording |
| V5 | POtO LEAD / 8OS LOCK #1 |
| V6 | POtO ATTRACTED / 8OS LOCK #2 |

> POtO and 8OS share voices V3–V6 and cannot run simultaneously.

---

*Norns port (Lua + SuperCollider) of a Python original — NSDOS 2026*
