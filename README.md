# TEAMMATE.POTO — Norns

*An improvisation partner, not an accompanist.*  
*Un partenaire d'improvisation, pas un accompagnateur.*

---

## English

Inspired by **Somax2** — a co-improvisation system developed at IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) by the Music Representations research team. Somax introduced the idea that a machine could listen to a musician, build a musical memory from what it hears, and navigate that memory in real time to improvise back. That idea changed how I think about human-machine dialogue in music.

TEAMMATE takes that same core intuition — the machine learns only from you, in the moment — and pushes it toward something rawer and more physical.

Everything you play gets sliced into a memory of 48 sound fragments: pitch, energy, timbre, texture. When you stop, TEAMMATE analyzes the whole phrase and decides what to do. Imitate. Contrast. Densify. Thin out. Stay silent. It never plays something it hasn't heard from you. No generative AI, no presets — pure *remémoration*.

Six layers running in parallel:

- **The dialogue** — phrase by phrase. TEAMMATE waits, listens, builds a portrait of what you just played, and responds from its own memory.
- **POtO** — a granular halo of the last 4 seconds of your performance. Three readers orbiting your sound: one locked to the present, one drifting toward it, one pushed toward the past. Five polyphony modes: MONO / 5th / CHRD / CLST / SMRT.
- **8OS** — record a sequence, let it slice itself into analyzed grains. In TRANS mode, three voices scan the bank and pull the grains that match your live pitch and energy in real time.
- **MIDI GEN** — a generative melodic sequencer running in parallel. Up to 16 independent channels, each with its own style, octave, and sequence. 14 styles: Techno, DnB, Jungle, Amapiano, 2-step, Brokenbeat, Dumbstep, Trap, Drill, Club, Kpop, Oriental, Rave, Trance. 17 break types. Evo mode mutates sequences organically each cycle. Syncs to external MIDI clock automatically.
- **Audio→MIDI** — converts live audio pitch to polyphonic MIDI notes in real time, routable to any of the 4 MIDI devices with configurable channels.
- **METABO** — a separate, autonomous mode (it does **not** touch the companion). Incoming sound feeds a living **cell metabolism**; the cell answers in MIDI notes where the notes **are** its active metabolic pathways. Monotonous, repetitive playing raises the cell's **stress** and the tempo races; varied, rich playing keeps it calm — homeostatic regulation. It breathes: phrases alternate with **silences**, longer when calm. Routed through its own matrix stream (stream 6), on its own channel.

Running on a Monome Norns. Lua + SuperCollider. Ported from a 12,000-line Python original.

---

## Français

Inspiré par **Somax2** — un système de co-improvisation développé à l'IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) par l'équipe Music Representations. Somax a introduit l'idée qu'une machine pouvait écouter un musicien, construire une mémoire musicale de ce qu'elle entend, et naviguer dans cette mémoire en temps réel pour improviser en retour. Cette idée a changé ma façon de penser le dialogue homme-machine en musique.

TEAMMATE part de la même intuition fondamentale — la machine n'apprend que de toi, dans l'instant — et la pousse vers quelque chose de plus brut et de plus physique.

Tout ce que tu joues est découpé en une mémoire de 48 fragments sonores : pitch, énergie, timbre, texture. Quand tu t'arrêtes, TEAMMATE analyse la phrase entière et décide quoi faire. Imiter. Contraster. Densifier. Espacer. Se taire. Il ne joue jamais quelque chose qu'il n'a pas entendu de toi. Pas d'IA générative, pas de presets — de la **remémoration active**.

Six couches en parallèle :

- **Le dialogue** — phrase par phrase. TEAMMATE attend, écoute, construit un portrait de ce que tu viens de jouer, et répond depuis sa propre mémoire.
- **POtO** — un halo granulaire des 4 dernières secondes de ta performance. Trois lecteurs qui orbitent autour de ton son : un ancré dans le présent, un qui dérive vers lui, un poussé vers le passé. Cinq modes de polyphonie : MONO / 5th / CHRD / CLST / SMRT.
- **8OS** — enregistre une séquence, laisse-la se découper en grains analysés. En mode TRANS, trois voix scannent le bank et tirent les grains qui correspondent à ton pitch et ton énergie live en temps réel.
- **MIDI GEN** — un séquenceur mélodique génératif qui tourne en parallèle. Jusqu'à 16 channels indépendants, chacun avec son style, son octave et sa séquence. 14 styles : Techno, DnB, Jungle, Amapiano, 2-step, Brokenbeat, Dumbstep, Trap, Drill, Club, Kpop, Oriental, Rave, Trance. 17 types de break. Mode Evo pour une mutation organique des séquences à chaque cycle. Sync automatique sur clock MIDI externe.
- **Audio→MIDI** — convertit le pitch audio live en notes MIDI polyphoniques en temps réel, routable sur n'importe lequel des 4 devices MIDI avec canal configurable.
- **METABO** — un mode **séparé et autonome** (il ne **touche pas** au compagnon). Le son entrant nourrit un **métabolisme cellulaire** vivant ; la cellule répond en notes MIDI où les notes **sont** ses voies métaboliques actives. Un jeu monotone et répétitif fait monter le **stress** de la cellule et le tempo s'emballe ; un jeu varié et riche la garde calme — régulation homéostatique. Elle respire : les phrases alternent avec des **silences**, plus longs quand elle est calme. Routé via son propre stream de matrice (stream 6), sur son propre canal.

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
E1        — previous / next page (loops 1→19)
K3        — main action for current page (see table)
```

---

## The 19 pages

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

| Encoder / Key | Function |
|---|---|
| E2 | `react` — minimum silence to seal a fragment (default 0.8s) |
| E3 | `init` — minimum silence before TEAMMATE takes initiative (default 1.5s) |
| K2 | Rhythmic phrase probability — cycle 0 / 15 / 30 / 50% |
| K3 | Voice mode ON/OFF |

- **Voice mode**: minimum syllable duration 120ms, adapted for singing and speech
- **Rhy prob**: when > 0, each phrase has a chance of locking its inter-event gaps to a BPM grid subdivision (1/8 or 1/16 note at `mgen_bpm`). Adds rhythmic pulse to the improvisation without being systematic.

---

### Page 5 — POtO
Real-time granular texture over the last 4 seconds.

| Encoder / Key | Function |
|---|---|
| E2 | POtO volume |
| E3 | Monitor level — **or sensitivity in SMRT mode** (see below) |
| K2 | Poly mode — cycle **MONO** / **5th** / **CHRD** / **CLST** / **SMRT** |
| K3 | POtO ON/OFF |

- Three readers: **LEAD** (fresh zone), **ATTRACTED** (drifts toward LEAD), **REPULSED** (pushed toward the past)
- **Poly modes**: MONO = spread only; **5th** = LEAD + fifth above + octave below; **CHRD** = LEAD + minor third + fifth; **CLST** = LEAD + semitone cluster (dense beating)
- **SMRT** — real-time technique detection. Classifies the incoming sound from two timbral descriptors (spectral flatness and brightness ratio) into four categories, then adapts harmonic intervals, grain size and voice balance accordingly:

| Category | Detection | Harmonic intervals | Grain size | Character |
|---|---|---|---|---|
| **TONAL** | Low flatness, moderate brightness | minor 3rd + major 6th | −20% | Warm triad, precise |
| **BRGHT** | High brightness (overtone-rich) | fifth + minor 3rd | ×1 | Open, luminous |
| **NOISY** | High flatness (airy, flutter) | microtonal cluster ± | +40% | Grainy wash |
| **WHSPR** | Very quiet / no gate | major 2nd ± | −40% | Subtle halo |

  In **SMRT** mode, **E3 controls sensitivity** (0–100%, default 50%) instead of monitor level. Lower values make the system harder to trigger (stays TONAL more often — useful for voice or noisy sources). Higher values make it react to subtler timbral variations. The detected category is shown live on screen: `K2 SMRT:TONAL` etc.

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
| E2 | Select stream (IMPRO / POtO / 8OS / MGEN) |
| E3 | MIDI channel (1–16) — active only for streams IMPRO / POtO / 8OS |
| K3 | Toggle routing ON/OFF for selected stream on this device |

- **4 streams**: IMPRO, POtO, 8OS, MGEN — each routable independently to any of the 4 devices
- IMPRO / POtO / 8OS: channel configurable per device via E3
- MGEN: no channel selector in the matrix — MGEN distributes channels 1–16 internally (one per generator channel)
- `[X]` = stream routed to this device / `[ ]` = not routed
- Device name shown on the info line while browsing pages 9–12

> IMPRO follows corpus improvisation, POtO follows the granular halo, 8OS follows TRANS grain matching. MGEN sends its 16-channel sequences to all routed devices.

---

### Page 13 — MGEN GLOBAL
Generative MIDI sequencer — global controls. Runs in parallel with the corpus improvisation.

| Encoder | Function |
|---|---|
| E2 | BPM (60–200) |
| E3 | Scale (MINOR / PHRYG / BLUES / DORIC / MAJOR / PENMIN / PENMAJ) |
| K2 | **Stopped**: tap tempo (averages last 4 taps, resets after 3s) · **Running**: new theme — regenerates all sequences live without stopping |
| K3 | START (generates all sequences + launches) / STOP + all notes off |

- Routes MIDI through **stream 4** of the routing matrix (pages 9–12) — enable MGEN on any device(s) there. One MIDI channel per generator channel (ch1→MIDI ch1, ch2→MIDI ch2…)
- All 16 sequences are generated randomly at startup and on each START
- **External MIDI clock**: TEAMMATE listens for raw 0xF8 clock pulses on any connected USB MIDI device. When a valid pulse stream is detected (after 4 pulses), BPM is calculated automatically (24 pulses per beat) and the sequencer locks step advances directly to incoming pulses — 6 pulses per 1/16 step, phase-aligned. Works on Norns Shield without any `SYSTEM > CLOCK` setting.
- **`EXT 128`** displayed (bright) on this page when external clock is active. **`bpm 128`** (dim) when running on internal clock.
- **Internal BPM**: Use E2 or K2 tap tempo when no external clock is connected. Screen shows `K2:tap` or `TAP n` while tapping.

*Séquenceur MIDI génératif — contrôles globaux. Tourne en parallèle de l'improvisation corpus.*

| Encodeur | Fonction |
|---|---|
| E2 | BPM (60–200) |
| E3 | Gamme (MINOR / PHRYG / BLUES / DORIC / MAJOR / PENMIN / PENMAJ) |
| K2 | **Arrêté** : tap tempo (moyenne 4 taps, reset après 3s) · **En marche** : new theme — régénère toutes les séquences en live sans stopper |
| K3 | START (génère toutes les séquences + lance) / STOP + all notes off |

- Route le MIDI via le **stream 4** de la matrice de routage (pages 9–12) — activer MGEN sur le(s) device(s) souhaités. Un canal MIDI par channel générateur (ch1→MIDI ch1, ch2→MIDI ch2…)
- Les 16 séquences sont générées aléatoirement au démarrage et à chaque START
- **Clock MIDI externe** : TEAMMATE écoute les pulses bruts 0xF8 sur tous les devices USB MIDI connectés. Dès que 4 pulses valides sont reçus, le BPM est calculé et le séquenceur cale chaque step directement sur les pulses entrants — 6 pulses par step 1/16, phase alignée. Fonctionne sur Norns Shield sans réglage `SYSTEM > CLOCK`.
- **`EXT 128`** s'affiche en blanc sur cette page quand la clock externe est active. **`bpm 128`** en gris quand le clock est interne.
- **BPM interne** : utilise E2 ou le tap tempo K2 quand aucune clock externe n'est connectée. L'écran affiche `K2:tap` ou `TAP n` pendant le tap.

---

### Page 14 — MGEN CHANNELS
Per-channel configuration. Shows 4 channels at a time, scrolls automatically with E2.

| Encoder / Key | Function |
|---|---|
| E2 | Select channel (1–16) |
| E3 | Style for selected channel — regenerates its sequence |
| K2 | Evo rate — cycle 0 / 5 / 12 / 22 / 40% mutation per step per cycle |
| K3 | Toggle selected channel ON / OFF |

**Evo mode**: each time a channel completes a full cycle, each step has a chance of mutating — notes drift to an adjacent scale degree, gates and velocities shift slightly. At 12% (default) sequences evolve slowly and organically. At 40% they transform fast. At 0% they stay fixed.

**Styles:**

| Style | Init octave | Character |
|---|---|---|
| **TECH** (Techno) | 2–4 | Ostinato, repetitive, heavy downbeats, tight syncopation |
| **DnB** | 2–4 | Syncopated basslines, half-time feel, interval jumps |
| **JGL** (Jungle) | 2–5 | Chromatic fills, irregular density, Amen-break energy |
| **AMPR** (Amapiano) | 3–5 | Jazz harmonics, log-drum feel, melodic runs, wide gate |
| **2STP** (2-step garage) | 2–4 | Off-beat syncopation, soulful intervals, UK garage feel |
| **BRKN** (Brokenbeat) | 3–5 | Jazz harmony, avoids downbeat, irregular placement, wide gate |
| **DUMB** (Dumbstep) | 3–4 | Half-time, very sparse, heavy hits, long sustain |
| **TRAP** | 3–5 | Sparse hits, short gate, strong 1 and off-beat accents |
| **DRIL** (Drill) | 3–5 | Chromatic dark intervals, syncopated, medium register |
| **CLUB** | 3–5 | Melodic house, legato, full-scale intervals, dense |
| **KPOP** | 3–5 | Pentatonic + extensions, syncopated, punchy |
| **ORNT** (Oriental) | 3–5 | Hijaz intervals (aug 2nd, tritone), ornamental, short gate |
| **RAVE** | 2–4 | Acid/hardcore, ultra-short gate, heavy accents on 1 |
| **TRNC** (Trance) | 3–5 | Flowing, high density, steady melodic pulse |

- **Init octave** is set randomly at startup (K3 START) — never overwritten when changing style
- Adjust octave freely per channel with **E3 on page 15** — style changes on page 14 leave octave untouched

*Configuration par channel. Affiche 4 channels à la fois, scroll automatique avec E2.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Sélectionner le channel (1–16) |
| E3 | Style du channel sélectionné — régénère sa séquence |
| K2 | Taux Evo — cycle 0 / 5 / 12 / 22 / 40% de mutation par step par cycle |
| K3 | Activer / désactiver le channel sélectionné |

**Mode Evo** : à chaque fin de cycle, chaque step a une chance de muter — les notes glissent vers un degré voisin dans la gamme, gates et vélocités dérivent légèrement. À 12% (défaut) les séquences évoluent lentement. À 40% elles se transforment vite. À 0% elles restent fixes.

**Styles :**

| Style | Octave init | Caractère |
|---|---|---|
| **TECH** (Techno) | 2–4 | Ostinato, répétitif, temps forts lourds, syncopes serrées |
| **DnB** | 2–4 | Basslines syncopées, half-time feel, sauts d'intervalles |
| **JGL** (Jungle) | 2–5 | Fills chromatiques, densité irrégulière, énergie Amen-break |
| **AMPR** (Amapiano) | 3–5 | Harmonies jazz, log-drum feel, runs mélodiques, gate large |
| **2STP** (2-step garage) | 2–4 | Syncopes off-beat, intervalles soul, feel UK garage |
| **BRKN** (Brokenbeat) | 3–5 | Harmonie jazz, évite le downbeat, placement irrégulier, gate large |
| **DUMB** (Dumbstep) | 3–4 | Half-time, très sparse, hits lourds, longue tenue |
| **TRAP** | 3–5 | Hits sparse, gate court, fort accent 1 et contretemps |
| **DRIL** (Drill) | 3–5 | Intervalles chromatiques sombres, syncopé, registre médium |
| **CLUB** | 3–5 | House mélodique, legato, intervalles pleine gamme, dense |
| **KPOP** | 3–5 | Pentatonique + extensions, syncopé, punchy |
| **ORNT** (Oriental) | 3–5 | Intervalles hijaz (2nde aug, triton), ornamental, gate court |
| **RAVE** | 2–4 | Acid/hardcore, gate ultra-court, accents lourds sur le 1 |
| **TRNC** (Trance) | 3–5 | Fluide, haute densité, pulse mélodique régulier |

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

### Page 16 — AUDIO→MIDI
Real-time pitch-to-MIDI conversion. Converts live audio into MIDI notes and routes them to any of the 4 MIDI outputs.

| Encoder | Function |
|---|---|
| E2 | Select device (d1–d4) |
| E3 | MIDI channel for selected device (1–16) |
| K3 | Toggle routing ON/OFF for selected device |

- **Polyphonic** (HTML emulator): up to 4 simultaneous pitches detected from the FFT spectrum (peaks above −38 dBFS, minimum 3 semitones apart) → simultaneous note_on messages
- **Monophonic** (Norns): current fundamental pitch → note_on on gate open, note_off on gate close
- Active notes shown on the info line while on this page
- Fully independent routing and channel from the other 4 streams

*Conversion pitch audio → MIDI en temps réel.*

| Encodeur | Fonction |
|---|---|
| E2 | Sélectionner le device (d1–d4) |
| E3 | Canal MIDI pour le device sélectionné (1–16) |
| K3 | Activer / désactiver le routage pour ce device |

- **Polyphonique** (émulateur HTML) : jusqu'à 4 pitchs simultanés détectés par FFT (pics > −38 dBFS, séparation min 3 demi-tons) → note_on simultanées
- **Monophonique** (Norns) : pitch fondamental courant → note_on à l'ouverture du gate, note_off à la fermeture
- Notes actives affichées sur la ligne d'info pendant la navigation sur cette page

---

### Page 17 — SPAT
Cosmic / quantum spatialization. Each sound source gets its own position in the stereo field, animated by one of six orbital or physical movement models.

| Encoder / Key | Function |
|---|---|
| E2 | Mass — movement amplitude (0–100%) |
| E3 | Tempo — movement speed (0–100%) |
| K2 | Cycle mode: **NEBULA** → **ORBIT** → **PULSAR** → **QUANTUM** → **STRANGE** → **ENTANGLE** |
| K3 | SPAT ON / OFF |

The display shows a horizontal spatial field (L ← center → R) with four voice markers:
- `*` asterisk = IMPRO corpus playback
- `O` large letter = POtO LEAD
- `o` small letter = POtO ATTRACTED
- `.` dot = POtO REPULSED

**Movement modes:**

| Mode | Physics | Character |
|---|---|---|
| **NEBULA** | Brownian motion with inertia and boundary reflection | Slow, organic, never repeating — like gas clouds drifting |
| **ORBIT** | Keplerian elliptical orbits (Kepler's second law: faster at periapsis) | Regular but non-uniform — speed varies with distance |
| **PULSAR** | Tanh-shaped arc sweep with phase offsets per voice | Sharp sweeping arcs, like a pulsar beam rotating |
| **QUANTUM** | Stable position + random tunneling triggered by signal energy | Mostly still, then instantaneous jumps — probability driven by RMS |
| **STRANGE** | Two-point Lorenz attractor (σ=10, ρ=28, β=8/3) | Chaotic, deterministic, never repeating — projected from 3D to stereo |
| **ENTANGLE** | Lead drifts (Brownian), Attracted = quantum mirror of Lead, Repulsed orbits independently | Lead and Attracted are entangled — move in opposite directions always |

When **POtO SMRT** mode is active, the movement parameters are modulated automatically by the detected technique:
- **WHSPR** → very subtle, slow movement (mass ×0.25)
- **TONAL** → moderate movement (mass ×0.60)
- **BRGHT** → wide, expressive movement (mass ×0.90)
- **NOISY** → maximum amplitude, slightly faster (mass ×1.0, tempo ×1.15)

*Spatialisation cosmique / quantique. Chaque source reçoit sa propre position dans le champ stéréo, animée par l'un des six modèles de mouvement orbital ou physique.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Masse — amplitude du mouvement (0–100%) |
| E3 | Tempo — vitesse du mouvement (0–100%) |
| K2 | Cycle mode : **NEBULA** → **ORBIT** → **PULSAR** → **QUANTUM** → **STRANGE** → **ENTANGLE** |
| K3 | SPAT ON / OFF |

L'affichage montre le champ stéréo (G ← centre → D) avec quatre marqueurs de voix :
- `*` astérisque = playback corpus IMPRO
- `O` grande lettre = POtO LEAD
- `o` petite lettre = POtO ATTRACTED
- `.` point = POtO REPULSED

**Modes de mouvement :**

| Mode | Physique | Caractère |
|---|---|---|
| **NEBULA** | Mouvement brownien avec inertie et réflexion aux bords | Lent, organique, jamais identique — comme des nuages de gaz |
| **ORBIT** | Orbites képlériennes (2e loi de Kepler : plus vite au périhélie) | Régulier mais non-uniforme — la vitesse varie avec la distance |
| **PULSAR** | Balayage en arc tanh avec déphasages par voix | Arcs nets et nets, comme un pulsar qui balaie |
| **QUANTUM** | Position stable + tunneling aléatoire déclenché par l'énergie | Stable la plupart du temps, puis sauts instantanés — probabilité pilotée par le RMS |
| **STRANGE** | Double attracteur de Lorenz (σ=10, ρ=28, β=8/3) | Chaotique, déterministe, jamais identique — projeté de 3D en stéréo |
| **ENTANGLE** | Lead dérive (Brownien), Attracted = miroir quantique de Lead, Repulsed orbite seul | Lead et Attracted sont intriqués — bougent toujours en sens inverse |

Quand le mode **SMRT de POtO** est actif, les paramètres de mouvement sont modulés automatiquement par la technique détectée.

---

### Page 18 — METABO
A separate, autonomous mode — **independent from the companion**. Incoming sound feeds a living cell metabolism; the cell answers in MIDI notes where **the notes are its active metabolic pathways**.

| Encoder / Key | Function |
|---|---|
| E2 | Scale (PENMIN / PENMAJ / MINOR / HIRA / INSEN / HIJAZ / PHRYG / DORIC / MAJOR) |
| E3 | Octave (−2 … +2) |
| K3 | METABO ON / OFF |

- **The metabolism**: four live audio features (energy, brightness, pitch height, texture) feed seven pathways — `growth`, `glycolysis`, `respiration`, `fermentation`, `byproduct`, `co2`, `lactate`. Each pathway maps to **one fixed note** (a scale degree + octave), so the cell's chemistry *is* the harmony. The most active pathways are the ones voiced.
- **Stress = monotony**: stress is driven by how repetitive your playing is. Monotonous / repetitive input → stress rises; varied, diverse input → stress falls. A homeostatic regulation smooths it (fast rise, slow recovery). Stress sets the tempo: **BPM ≈ 60 + stress × 120**.
- **It breathes**: the voice alternates phrases and **silences** — more silence when the cell is calm, denser when stressed. Mono/poly mix is organic and deliberately non-4/4.
- **Display**: a cell circle pulsing with `growth`, pathway dots brightening with activity, a STRESS bar, the live BPM, the cell state (`STABLE` / `PERTURBE` / `MONOTONE`), and the dominant pathway → its note.
- **Routing**: the METABO voice goes out on **stream 6** of the matrix, configured on page 19 — completely separate from the companion's streams (IMPRO / POtO / 8OS / MGEN) and from Audio→MIDI.

**Inspiration** — METABO grows out of **_Avatar métabolique sonore_**, a collaboration between **NSDOS** and **Damien Eveillard** (Professor of Computer Science at Nantes Université / LS2N–CNRS; a systems-biology and microbial-ecology researcher specialized in **constraint-based metabolic network modeling**). The idea: treat a living cell's metabolism as an instrument. In the full installation, audio drives the nutrient uptake of a real genome-scale metabolic model solved by **Flux Balance Analysis (FBA / COBRA)**, and the resulting metabolic fluxes become sound. On Norns, METABO is a lightweight real-time embodiment of that idea — the pathways are simulated rather than solved by FBA, but the principle is identical: **the cell's chemistry is the music**. ▶ [Avatar métabolique sonore (video)](https://www.youtube.com/watch?v=TbVlwrFNA8E)

*Un mode séparé et autonome — **indépendant du compagnon**. Le son entrant nourrit un métabolisme cellulaire vivant ; la cellule répond en notes MIDI où **les notes sont ses voies métaboliques actives**.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Gamme (PENMIN / PENMAJ / MINOR / HIRA / INSEN / HIJAZ / PHRYG / DORIC / MAJOR) |
| E3 | Octave (−2 … +2) |
| K3 | METABO ON / OFF |

- **Le métabolisme** : quatre descripteurs audio live (énergie, brillance, hauteur, texture) nourrissent sept voies — `growth`, `glycolysis`, `respiration`, `fermentation`, `byproduct`, `co2`, `lactate`. Chaque voie correspond à **une note fixe** (degré de gamme + octave) : la chimie de la cellule *est* l'harmonie. Les voies les plus actives sont celles qui sonnent.
- **Stress = monotonie** : le stress vient de la répétitivité de ton jeu. Entrée monotone / répétitive → le stress monte ; jeu varié, divers → le stress baisse. Une régulation homéostatique le lisse (montée rapide, récupération lente). Le stress fixe le tempo : **BPM ≈ 60 + stress × 120**.
- **Elle respire** : la voix alterne phrases et **silences** — plus de silence quand la cellule est calme, plus dense sous stress. Le mélange mono/poly est organique et volontairement non-4/4.
- **Affichage** : un cercle-cellule qui pulse avec `growth`, des points-voies qui s'illuminent selon l'activité, une barre STRESS, le BPM live, l'état (`STABLE` / `PERTURBE` / `MONOTONE`), et la voie dominante → sa note.
- **Routage** : la voix METABO sort sur le **stream 6** de la matrice, configuré en page 19 — totalement séparé des streams du compagnon (IMPRO / POtO / 8OS / MGEN) et de l'Audio→MIDI.

**Inspiration** — METABO est issu d'**_Avatar métabolique sonore_**, une collaboration entre **NSDOS** et **Damien Eveillard** (professeur d'informatique à Nantes Université / LS2N–CNRS ; chercheur en biologie des systèmes et écologie microbienne, spécialiste de la **modélisation des réseaux métaboliques sous contraintes**). L'idée : faire du métabolisme d'une cellule vivante un instrument. Dans l'installation complète, l'audio pilote l'absorption de nutriments d'un véritable modèle métabolique à l'échelle du génome, résolu par **analyse de balance des flux (FBA / COBRA)**, et les flux métaboliques obtenus deviennent du son. Sur Norns, METABO est une incarnation temps réel allégée de cette idée — les voies sont simulées plutôt que résolues par FBA, mais le principe est identique : **la chimie de la cellule est la musique**. ▶ [Avatar métabolique sonore (vidéo)](https://www.youtube.com/watch?v=TbVlwrFNA8E&t=477s)

---

### Page 19 — METABO MIDI
Routing matrix for the METABO voice (stream 6). Same logic as the device pages — METABO is just its own independent stream.

| Encoder / Key | Function |
|---|---|
| E2 | Select device (d1–d4) |
| E3 | MIDI channel for selected device (1–16) |
| K3 | Toggle METABO routing ON/OFF for selected device |

- Route the METABO voice to any of the 4 MIDI devices, each with its own channel.
- `[X]` = METABO routed to this device / `[ ]` = not routed.
- Fully independent from the companion's routing (pages 9–12) and from Audio→MIDI (page 16). Enable at least one device here to hear METABO.

*Matrice de routage pour la voix METABO (stream 6). Même logique que les pages device — METABO est simplement son propre stream indépendant.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Sélectionner le device (d1–d4) |
| E3 | Canal MIDI pour le device sélectionné (1–16) |
| K3 | Activer / désactiver le routage METABO pour ce device |

- Route la voix METABO sur n'importe lequel des 4 devices MIDI, chacun avec son canal.
- `[X]` = METABO routé sur ce device / `[ ]` = non routé.
- Totalement indépendant du routage du compagnon (pages 9–12) et de l'Audio→MIDI (page 16). Active au moins un device ici pour entendre METABO.

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
