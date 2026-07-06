# TEAMMATE.POTO — Norns

*An improvisation partner, not an accompanist.*  
*Un partenaire d'improvisation, pas un accompagnateur.*

---

## English

Inspired by **Somax2** — a co-improvisation system developed at IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) by the Music Representations research team. Somax introduced the idea that a machine could listen to a musician, build a musical memory from what it hears, and navigate that memory in real time to improvise back. That idea changed how I think about human-machine dialogue in music.

TEAMMATE takes that same core intuition — the machine learns only from you, in the moment — and pushes it toward something rawer and more physical.

Everything you play gets sliced into a memory of 48 sound fragments: pitch, energy, timbre, texture. When you stop, TEAMMATE analyzes the whole phrase and decides what to do. Imitate. Contrast. Densify. Thin out. Stay silent. It never plays something it hasn't heard from you. No generative AI, no presets — pure *remémoration*.

Seven layers running in parallel:

- **The dialogue** — phrase by phrase. TEAMMATE waits, listens, builds a portrait of what you just played, and responds from its own memory.
- **POtO** — a granular halo of the last 4 seconds of your performance. Three readers orbiting your sound: one locked to the present, one drifting toward it, one pushed toward the past. Five polyphony modes: MONO / 5th / CHRD / CLST / SMRT.
- **8OS** — record a sequence, let it slice itself into analyzed grains. In TRANS mode, three voices scan the bank and pull the grains that match your live pitch and energy in real time.
- **MIDI GEN** — a generative melodic sequencer running in parallel. Up to 16 independent channels, each with its own style, octave, and sequence. 14 styles: Techno, DnB, Jungle, Amapiano, 2-step, Brokenbeat, Dumbstep, Trap, Drill, Club, Kpop, Oriental, Rave, Trance. 17 break types. Evo mode mutates sequences organically each cycle. Syncs to external MIDI clock automatically.
- **Audio→MIDI** — converts live audio pitch to polyphonic MIDI notes in real time, routable to any of the 4 MIDI devices with configurable channels.
- **METABO** — a separate, autonomous mode (it does **not** touch the companion). Incoming sound feeds a living **cell metabolism**; the cell answers in MIDI notes where the notes **are** its active metabolic pathways. Monotonous, repetitive playing raises the cell's **stress** and the tempo races; varied, rich playing keeps it calm — homeostatic regulation. It breathes: phrases alternate with **silences**, longer when calm. Routed through its own matrix stream (stream 6), on its own channel.
- **NIAKABY** — a harmonizer: it turns a melodic line into **MIDI chords** (diatonic triads/7ths/9ths/sus, snapped to a scale, with a bass note), routed on its own matrix stream (stream 7). Its **source** can be the live **input**, **METABO** (the cell's notes drive the chords) or the **companion** — and when METABO is on it **colours** the chords (tensions under stress, octave doublings on growth).

- **PERU** — a gravity toy: grains from the corpus become **diamonds** in a box that fall, bounce off the walls and **trigger their sound on every collision** (panned by the impact point). Their agitation can be **auto-shaken** by your input, METABO or the impro. Own MIDI stream (8), armable from LIVE.

On top of these, a **living layer** makes it feel like a partner: **MIND** (shared listening — it follows your dynamics, builds a long arc, recalls your motifs), **STYLE** (it learns and plays in your manner), an **agent** with a face that grows, has opinions and recognizes places, and a **WiFi** dimension that turns the networks in the room into a playable source. See the dedicated sections below.

Running on a Monome Norns. Lua + SuperCollider. Ported from a 12,000-line Python original.

---

## Français

Inspiré par **Somax2** — un système de co-improvisation développé à l'IRCAM (Institut de Recherche et Coordination Acoustique/Musique, Paris) par l'équipe Music Representations. Somax a introduit l'idée qu'une machine pouvait écouter un musicien, construire une mémoire musicale de ce qu'elle entend, et naviguer dans cette mémoire en temps réel pour improviser en retour. Cette idée a changé ma façon de penser le dialogue homme-machine en musique.

TEAMMATE part de la même intuition fondamentale — la machine n'apprend que de toi, dans l'instant — et la pousse vers quelque chose de plus brut et de plus physique.

Tout ce que tu joues est découpé en une mémoire de 48 fragments sonores : pitch, énergie, timbre, texture. Quand tu t'arrêtes, TEAMMATE analyse la phrase entière et décide quoi faire. Imiter. Contraster. Densifier. Espacer. Se taire. Il ne joue jamais quelque chose qu'il n'a pas entendu de toi. Pas d'IA générative, pas de presets — de la **remémoration active**.

Sept couches en parallèle :

- **Le dialogue** — phrase par phrase. TEAMMATE attend, écoute, construit un portrait de ce que tu viens de jouer, et répond depuis sa propre mémoire.
- **POtO** — un halo granulaire des 4 dernières secondes de ta performance. Trois lecteurs qui orbitent autour de ton son : un ancré dans le présent, un qui dérive vers lui, un poussé vers le passé. Cinq modes de polyphonie : MONO / 5th / CHRD / CLST / SMRT.
- **8OS** — enregistre une séquence, laisse-la se découper en grains analysés. En mode TRANS, trois voix scannent le bank et tirent les grains qui correspondent à ton pitch et ton énergie live en temps réel.
- **MIDI GEN** — un séquenceur mélodique génératif qui tourne en parallèle. Jusqu'à 16 channels indépendants, chacun avec son style, son octave et sa séquence. 14 styles : Techno, DnB, Jungle, Amapiano, 2-step, Brokenbeat, Dumbstep, Trap, Drill, Club, Kpop, Oriental, Rave, Trance. 17 types de break. Mode Evo pour une mutation organique des séquences à chaque cycle. Sync automatique sur clock MIDI externe.
- **Audio→MIDI** — convertit le pitch audio live en notes MIDI polyphoniques en temps réel, routable sur n'importe lequel des 4 devices MIDI avec canal configurable.
- **METABO** — un mode **séparé et autonome** (il ne **touche pas** au compagnon). Le son entrant nourrit un **métabolisme cellulaire** vivant ; la cellule répond en notes MIDI où les notes **sont** ses voies métaboliques actives. Un jeu monotone et répétitif fait monter le **stress** de la cellule et le tempo s'emballe ; un jeu varié et riche la garde calme — régulation homéostatique. Elle respire : les phrases alternent avec des **silences**, plus longs quand elle est calme. Routé via son propre stream de matrice (stream 6), sur son propre canal.
- **NIAKABY** — un harmoniseur : il transforme une ligne mélodique en **accords MIDI** (triades / 7e / 9e / sus diatoniques calés dans une gamme, avec une basse), routés sur son propre stream de matrice (stream 7). Sa **source** peut être l'**entrée** live, **METABO** (les notes de la cellule pilotent les accords) ou le **compagnon** — et quand METABO est actif il **colore** les accords (tensions sous stress, doublures si croissance).

- **PERU** — un jouet gravitationnel : les grains du corpus deviennent des **diamants** dans une boîte qui tombent, rebondissent sur les bords et **déclenchent leur son à chaque choc** (spatialisés selon le point d'impact). Leur agitation peut être **auto-secouée** par ton entrée, METABO ou l'impro. Son propre stream MIDI (8), armable depuis LIVE.

Par-dessus, une **couche vivante** en fait un vrai partenaire : **MIND** (écoute partagée — il suit ta dynamique, construit un arc long, rappelle tes motifs), **STYLE** (il apprend et joue à ta manière), un **agent** à visage qui grandit, a des opinions et reconnaît les lieux, et une dimension **WiFi** qui transforme les réseaux de la salle en source jouable. Voir les sections dédiées plus bas.

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

Teammate opens on the **MENU** — a hub that lists every mode. Navigation is **two-level**: pick a mode on the menu, dive into its pages, loop back.

**On the MENU (hub):**
```
E1 / E2   — move the cursor through the modes
E3 →      — enter the highlighted mode (jumps to its first page)
K3        — arm / disarm that mode (shows on / -)
K2        — FREEZE (MGEN patterns)
```

**Inside a mode:**
```
E1        — scroll this mode's pages; past the last one, loop back to the MENU
E2/E3/K1-K3 — the page's own controls (unchanged)
```

The settings-page header shows the mode + your position, e.g. `POtO 2/4`. Modes: **IMPRO · POtO · 8OS · MGEN · AUDIO · SPAT · METABO · NIAKABY · PERU · WIFI · CC · SAMT** (motion sensors) **· MIDI** (routing) **· AGENT** (agent/MIND/STYLE). The page numbers in the section titles below are the original **logical IDs** (unchanged).

*Teammate ouvre sur le **MENU** — un hub qui liste tous les modes. Navigation à **deux niveaux** : choisis un mode, entre dans ses pages, reboucle.*

**Sur le MENU (hub) :**
```
E1 / E2   — déplacer le curseur dans les modes
E3 →      — entrer dans le mode surligné (saute à sa 1re page)
K3        — armer / couper ce mode (affiche on / -)
K2        — FREEZE (patterns MGEN)
```

**Dans un mode :**
```
E1        — défiler les pages du mode ; après la dernière, retour au MENU
E2/E3/K1-K3 — les contrôles propres de la page (inchangés)
```

*L'en-tête des pages de réglages affiche le mode + ta position, ex. `POtO 2/4`.*

---

## The pages

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

### Page 8 — 8OS SRC
The **TRANS source router** (combinable), a **PITCH** improvement and a stereo **spread**.

| Encoder / Key | Function |
|---|---|
| E2 | Move cursor (INPUT / METABO / COMP / MGEN / PITCH) |
| E3 | Stereo spread of the 3 TRANS voices (0–100%) |
| K3 | Toggle the highlighted item ON/OFF |
| K2 | All sources on / off |

- **TRANS sources** (combinable): in TRANS mode the grains are matched to a "live voice" (pitch + energy + gate). Toggle any combination of **INPUT** (audio), **METABO** (the cell), **COMP** (the companion's improv), **MGEN** — when several are active, the **loudest leads**. Default INPUT only = unchanged behaviour.
- **PITCH** (improvement): when on, each grain is **transposed to match the target note** (±2 octaves) — 8OS *sings the source's melody* with its sampled material, instead of only picking the nearest grain. Off = grains play at their original pitch.
- **Spread** (E3): static stereo spread of the 3 TRANS voices — V5 left, V6 right, V3 centre, by the chosen amount. (When SPAT is ON it takes over the panning instead.)

*Le **routeur de source TRANS** (combinable), une amélioration **PITCH** et un **spread** stéréo.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Déplacer le curseur (INPUT / METABO / COMP / MGEN / PITCH) |
| E3 | Spread stéréo des 3 voix TRANS (0–100%) |
| K3 | Activer / couper l'élément surligné |
| K2 | Toutes les sources on / off |

- **Sources TRANS** (combinables) : en TRANS, les grains sont matchés sur une « voix live » (pitch + énergie + gate). Active n'importe quelle combinaison de **INPUT** (audio), **METABO** (la cellule), **COMP** (l'impro du compagnon), **MGEN** — quand plusieurs sont actives, la **plus forte mène**. Défaut INPUT seul = inchangé.
- **PITCH** (amélioration) : activé, chaque grain est **transposé pour coller à la note cible** (±2 octaves) — 8OS *chante la mélodie de la source* avec sa matière échantillonnée, au lieu de juste choisir le grain le plus proche. Off = grains à leur hauteur d'origine.
- **Spread** (E3) : spread stéréo statique des 3 voix TRANS — V5 à gauche, V6 à droite, V3 au centre, selon le réglage. (Quand SPAT est ON, c'est lui qui gère le pan à la place.)

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
| K2 | Evo rate — cycle 0 / 5 / 12 / 22 / 40% / **META** mutation per step per cycle |
| K3 | Toggle selected channel ON / OFF |

**Evo mode**: each time a channel completes a full cycle, each step has a chance of mutating — notes drift to an adjacent scale degree, gates and velocities shift slightly. At 12% (default) sequences evolve slowly and organically. At 40% they transform fast. At 0% they stay fixed. **META** (last step of the K2 cycle) connects the evolution to METABO: the live mutation rate follows the **cell's stress** (calm = frozen, stressed = mutates a lot) — toggleable by cycling K2 off META.

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
| K2 | Taux Evo — cycle 0 / 5 / 12 / 22 / 40% / **META** de mutation par step par cycle |
| K3 | Activer / désactiver le channel sélectionné |

**Mode Evo** : à chaque fin de cycle, chaque step a une chance de muter — les notes glissent vers un degré voisin dans la gamme, gates et vélocités dérivent légèrement. À 12% (défaut) les séquences évoluent lentement. À 40% elles se transforment vite. À 0% elles restent fixes. **META** (dernier cran du cycle K2) connecte l'évolution à METABO : le taux de mutation suit le **stress de la cellule** (calme = figé, stressé = mute beaucoup) — désactivable en cyclant K2 hors META.

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

> **8OS** is spatialized too: in TRANS mode its three grain voices get their **own independent SPAT trajectories**, distinct from POtO. While 8OS TRANS is active, the `O o .` markers show the **8OS** positions (not POtO's).

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

> **8OS** est spatialisé aussi : en mode TRANS, ses trois voix de grain ont leurs **propres trajectoires SPAT indépendantes**, distinctes de POtO. Quand 8OS TRANS est actif, les marqueurs `O o .` montrent les positions **8OS** (pas celles de POtO).

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
| K2 | Density — cycle **SPARSE** / **FLOW** / **DENSE** |
| K3 | METABO ON / OFF |

- **The metabolism**: four live audio features (energy, brightness, pitch height, texture) feed seven pathways — `growth`, `glycolysis`, `respiration`, `fermentation`, `byproduct`, `co2`, `lactate`. Each pathway maps to **one fixed note** (a scale degree + octave), so the cell's chemistry *is* the harmony. The most active pathways are the ones voiced.
- **Stress = monotony**: stress is driven by how repetitive your playing is. Monotonous / repetitive input → stress rises; varied, diverse input → stress falls. A homeostatic regulation smooths it (fast rise, slow recovery).
- **Tempo locked to MGEN**: METABO's BPM follows the **global MGEN tempo** (the master clock — also driven by tap tempo / external MIDI clock). Stress just picks the musical multiple: **half-time** when calm, **on-grid** at medium, **double-time** when stressed — so METABO always stays in time with the rest.
- **It breathes**: the voice alternates phrases and **silences** — more silence when the cell is calm, denser when stressed. Mono/poly mix is organic and deliberately non-4/4.
- **Phrasing**: METABO doesn't just stack notes — it builds **chords, arpeggios, melodic lines and ostinatos** from the active pathways, following melodic contours (motifs) and rhythmic cells that recur for a few phrases then mutate. Note count and density follow stress and growth; **K2** sets an overall density (SPARSE / FLOW / DENSE).
- **Follows your pitch**: METABO tracks the pitch of the incoming sound — it transposes its register to sing in the same range as what you play, and now and then echoes **your note** (snapped to the current scale) as one of its voices. The live input note is shown top-center (`in C4`). The metabolic pathways still set the harmony; the input only anchors the register and adds occasional echoes.
- **Display**: a cell circle pulsing with `growth`, pathway dots brightening with activity, a STRESS bar, the live BPM, the cell state (`STABLE` / `PERTURBE` / `MONOTONE`), and the dominant pathway → its note.
- **Routing**: the METABO voice goes out on **stream 6** of the matrix, configured on page 19 — completely separate from the companion's streams (IMPRO / POtO / 8OS / MGEN) and from Audio→MIDI.

**Inspiration** — METABO grows out of **_Avatar métabolique sonore_**, a collaboration between **NSDOS** and **Damien Eveillard** (Professor of Computer Science at Nantes Université / LS2N–CNRS; a systems-biology and microbial-ecology researcher specialized in **constraint-based metabolic network modeling**). The idea: treat a living cell's metabolism as an instrument. In the full installation, audio drives the nutrient uptake of a real genome-scale metabolic model solved by **Flux Balance Analysis (FBA / COBRA)**, and the resulting metabolic fluxes become sound. On Norns, METABO is a lightweight real-time embodiment of that idea — the pathways are simulated rather than solved by FBA, but the principle is identical: **the cell's chemistry is the music**. ▶ [Avatar métabolique sonore (video)](https://www.youtube.com/watch?v=TbVlwrFNA8E)

*Un mode séparé et autonome — **indépendant du compagnon**. Le son entrant nourrit un métabolisme cellulaire vivant ; la cellule répond en notes MIDI où **les notes sont ses voies métaboliques actives**.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Gamme (PENMIN / PENMAJ / MINOR / HIRA / INSEN / HIJAZ / PHRYG / DORIC / MAJOR) |
| E3 | Octave (−2 … +2) |
| K2 | Densité — cycle **SPARSE** / **FLOW** / **DENSE** |
| K3 | METABO ON / OFF |

- **Le métabolisme** : quatre descripteurs audio live (énergie, brillance, hauteur, texture) nourrissent sept voies — `growth`, `glycolysis`, `respiration`, `fermentation`, `byproduct`, `co2`, `lactate`. Chaque voie correspond à **une note fixe** (degré de gamme + octave) : la chimie de la cellule *est* l'harmonie. Les voies les plus actives sont celles qui sonnent.
- **Stress = monotonie** : le stress vient de la répétitivité de ton jeu. Entrée monotone / répétitive → le stress monte ; jeu varié, divers → le stress baisse. Une régulation homéostatique le lisse (montée rapide, récupération lente).
- **Tempo calé sur MGEN** : le BPM de METABO suit le **tempo global de MGEN** (l'horloge maître — aussi pilotée par le tap tempo / la clock MIDI externe). Le stress choisit juste le multiple musical : **half-time** quand calme, **sur la grille** au milieu, **double-time** sous stress — METABO reste donc toujours dans le tempo.
- **Elle respire** : la voix alterne phrases et **silences** — plus de silence quand la cellule est calme, plus dense sous stress. Le mélange mono/poly est organique et volontairement non-4/4.
- **Phrasé** : METABO n'empile pas que des notes — il construit **accords, arpèges, lignes mélodiques et ostinatos** à partir des voies actives, en suivant des contours mélodiques (motifs) et des cellules rythmiques qui reviennent quelques phrases puis mutent. Le nombre de notes et la densité suivent le stress et la croissance ; **K2** règle une densité globale (SPARSE / FLOW / DENSE).
- **Suit ta hauteur** : METABO suit le pitch du son entrant — il transpose son registre pour chanter dans la même zone que ce que tu joues, et glisse de temps en temps **ta note** (recalée dans la gamme) parmi ses voix. La note entrante live est affichée en haut au centre (`in C4`). Les voies métaboliques fixent toujours l'harmonie ; l'entrée ne fait qu'ancrer le registre et ajouter des échos occasionnels.
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

### Page 20 — METABO PLAY
The **musician entity**. The metabolism decides *what* to play (active pathways, stress); the **persona** decides *how* — the instrumental idiom.

| Encoder / Key | Function |
|---|---|
| E2 | Persona — **CELL** / **PIANO** / **POLY** / **BASS** |
| E3 | Follow — how much METABO follows the incoming pitch (0–100%) |
| K2 | Density — SPARSE / FLOW / DENSE |
| K3 | METABO ON / OFF |

**Personas:**

| Persona | Plays like | Detail |
|---|---|---|
| **CELL** | the organic default | Pathways → chords / arpeggios / melodies / ostinatos, non-4/4 |
| **PIANO** | a pianist | Rolled chords with a left-hand bass note, legato arpeggios and melodic lines |
| **POLY** | polyrhythmic melodic layers | Each pathway has its own cycle length (4 vs 3 vs 5 vs 7 vs 6 vs 8 vs 2 steps) so the layers phase against each other → organic polyrhythm. Each layer plays **its pathway's note, in scale**, following the incoming pitch (register + echoes); activity gates each layer, stress drives density. |
| **BASS** | a bassist | Low mono line, syncopated — root / fifth / octave of the dominant pathway |

- **Follow** (E3): at 0% METABO ignores your pitch (pure metabolism); higher values transpose its register toward what you play and add note-echoes (your note, snapped to the scale). The live input note shows as `in C4`.

*L'**entité musicienne**. Le métabolisme décide *quoi* jouer (voies actives, stress) ; la **persona** décide *comment* — l'idiome instrumental.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Persona — **CELL** / **PIANO** / **POLY** / **BASS** |
| E3 | Follow — à quel point METABO suit le pitch entrant (0–100%) |
| K2 | Densité — SPARSE / FLOW / DENSE |
| K3 | METABO ON / OFF |

**Personas :**

| Persona | Joue comme | Détail |
|---|---|---|
| **CELL** | l'organique par défaut | Voies → accords / arpèges / mélodies / ostinatos, non-4/4 |
| **PIANO** | un pianiste | Accords roulés avec note de basse (main gauche), arpèges et lignes legato |
| **POLY** | couches polyrythmiques mélodiques | Chaque voie a sa propre période (4 contre 3 contre 5 contre 7 contre 6 contre 8 contre 2 pas) → les couches se déphasent → polyrythmie organique. Chaque couche joue **sa note, dans la gamme**, en suivant le pitch entrant (registre + échos) ; l'activité ouvre chaque couche, le stress pilote la densité. |
| **BASS** | un bassiste | Ligne grave mono, syncopée — fondamentale / quinte / octave de la voie dominante |

- **Follow** (E3) : à 0% METABO ignore ta hauteur (métabolisme pur) ; plus haut, il transpose son registre vers ce que tu joues et ajoute des notes-écho (ta note, recalée dans la gamme). La note entrante live s'affiche `in C4`.

---

### Page 21 — METABO FEED
What feeds the cell, and how strongly it reacts to the companion.

| Encoder / Key | Function |
|---|---|
| E2 | Feed source — **INPUT** / **COMP** / **MIX** (companion → METABO) |
| E3 | Reaction — how strongly/fast METABO reacts to the companion (0–100%) |
| K2 | Influence — **OFF** / **LOW** / **MID** / **HIGH** (METABO → companion) |
| K3 | METABO ON / OFF |

This page is the **two-way link** between the companion and the cell.

- **Feed source** (E2): **INPUT** = live audio (mic/line) · **COMP** = **the companion feeds METABO** (the companion's corpus improvisation drives the metabolism, so METABO breathes with it and falls silent when it rests) · **MIX** = both (the louder leads).
- **Reaction** (E3): low = smooth/slow (the cell glides, fairly independent); high = snappy/tight (the cell tracks every companion event, energy decays fast → more silences between phrases). Controls both the companion-energy decay and the sensitivity.
- **Influence** (K2): the reverse direction — **the cell nudges the companion's choices**. Opt-in and non-destructive (your manual settings aren't changed; it only biases the strategy weights at decision time). A **stressed** cell (monotony) pushes the companion toward **CONTRASTE / DENSIFICATION** (to break the monotony); a **calm** cell gives more **space** (SPARSE / SILENCE). **OFF** = companion completely untouched.

*Ce qui nourrit la cellule, et à quel point elle réagit au compagnon.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Source — **INPUT** / **COMP** / **MIX** (compagnon → METABO) |
| E3 | Réaction — à quel point / quelle vitesse METABO réagit au compagnon (0–100%) |
| K2 | Influence — **OFF** / **LOW** / **MID** / **HIGH** (METABO → compagnon) |
| K3 | METABO ON / OFF |

Cette page est le **lien bidirectionnel** entre le compagnon et la cellule.

- **Source** (E2) : **INPUT** = audio live (micro/ligne) · **COMP** = **le compagnon nourrit METABO** (l'impro corpus du compagnon pilote le métabolisme, donc METABO respire avec lui et se tait quand il se repose) · **MIX** = les deux (le plus fort mène).
- **Réaction** (E3) : bas = lisse/lent (la cellule glisse, assez indépendante) ; haut = vif/serré (la cellule suit chaque événement du compagnon, l'énergie décroît vite → plus de silences entre les phrases). Agit sur le decay de l'énergie compagnon et la sensibilité.
- **Influence** (K2) : le sens inverse — **la cellule infléchit les choix du compagnon**. Opt-in et non destructif (tes réglages manuels ne changent pas ; ça ne fait que biaiser les poids de stratégie au moment de décider). Une cellule **stressée** (monotonie) pousse le compagnon vers **CONTRASTE / DENSIFICATION** (pour casser la monotonie) ; une cellule **calme** laisse plus d'**espace** (SPARSE / SILENCE). **OFF** = compagnon totalement inchangé.

---

### Page 22 — NIAKABY
A harmonizer: the **pitch of the incoming sound** is detected, snapped to a scale, and turned into a **diatonic MIDI chord** for that scale degree (maj/min/dim follow the scale automatically) plus a bass note — with anti-flutter debounce and release on silence.

| Encoder / Key | Function |
|---|---|
| E2 | Scale / key (MAJOR / MINOR / DORIC / PHRYG / HIJAZ / PENMIN / PENMAJ / HIRA / INSEN) |
| E3 | Octave (−2 … +2) |
| K2 | Chord type — **TRIAD** / **7TH** / **9TH** / **SUS** |
| K3 | NIAKABY ON / OFF |

- Plays the chord while you sustain a pitch; re-voices when the detected scale degree changes; releases shortly after you stop.
- Output goes through the routing matrix on **stream 7** — set it up on page 23.
- The screen shows the detected input note (`in`) and the current chord notes.

*Un harmoniseur : le **pitch du son entrant** est détecté, calé dans une gamme, et transformé en **accord MIDI diatonique** du degré (maj/min/dim suivent la gamme) + une basse — avec anti-flutter et relâche au silence.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Gamme / tonalité (MAJOR / MINOR / DORIC / PHRYG / HIJAZ / PENMIN / PENMAJ / HIRA / INSEN) |
| E3 | Octave (−2 … +2) |
| K2 | Type d'accord — **TRIAD** / **7TH** / **9TH** / **SUS** |
| K3 | NIAKABY ON / OFF |

- Joue l'accord tant que tu tiens une note ; ré-harmonise quand le degré change ; relâche peu après l'arrêt.
- Sort par la matrice de routage sur le **stream 7** — à configurer page 23.
- L'écran montre la note entrante détectée (`in`) et les notes de l'accord en cours.

---

### Page 23 — NIAKABY MIDI
Routing matrix for NIAKABY (stream 7) + the **LINK** to METABO.

| Encoder / Key | Function |
|---|---|
| E2 | Select device (d1–d4) |
| E3 | MIDI channel for selected device (1–16) |
| K3 | Toggle NIAKABY routing ON/OFF for selected device |

- The harmonized **source** is chosen on **page 24** (the active sources are shown at the top of this page). Whatever the source, when METABO is ON it also **colours** the chords (7th/9th under stress, octave doubling on growth).

*Matrice de routage pour NIAKABY (stream 7) + le **LINK** vers METABO.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Sélectionner le device (d1–d4) |
| E3 | Canal MIDI pour le device sélectionné (1–16) |
| K3 | Activer / désactiver le routage NIAKABY pour ce device |

- La **source** harmonisée se choisit en **page 24** (les sources actives sont affichées en haut de cette page). Quelle que soit la source, quand METABO est ON il **colore** aussi les accords (7e/9e sous stress, doublure si croissance).

---

### Page 24 — NIAKABY SRC
Choose **what NIAKABY harmonizes** — the three sources are **independent toggles**, freely combinable.

| Encoder / Key | Function |
|---|---|
| E2 | Move cursor (INPUT / METABO / COMP / MGEN) |
| K3 | Toggle the highlighted source ON/OFF |
| K2 | All on / all off |

- **INPUT** — the live audio (mic/line).
- **METABO** — the cell's notes feed NIAKABY (METABO drives the chords).
- **COMP** — the companion's corpus improvisation.
- **MGEN** — the generative MIDI sequencer.
- Enable **any combination** (e.g. INPUT + MGEN, or all four). When several are active, the **loudest source leads** at each moment. `[X]` = active.

*Choisis **ce que NIAKABY harmonise** — les trois sources sont des **cases indépendantes**, librement combinables.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Déplacer le curseur (INPUT / METABO / COMP / MGEN) |
| K3 | Activer / désactiver la source surlignée |
| K2 | Tout activer / tout couper |

- **INPUT** — l'audio live (micro/ligne).
- **METABO** — les notes de la cellule alimentent NIAKABY (METABO pilote les accords).
- **COMP** — l'improvisation corpus du compagnon.
- **MGEN** — le séquenceur MIDI génératif.
- Active **n'importe quelle combinaison** (ex. INPUT + MGEN, ou les quatre). Quand plusieurs sont actives, la **plus forte mène** à chaque instant. `[X]` = active.

---

### Page 25 — METABO>MGEN
A mode where **METABO triggers MGEN's random "new theme"** (the K2-on-page-13 regeneration) by itself, driven by the cell. Opt-in (DRIVE 0 = off, MGEN untouched).

| Encoder / Key | Function |
|---|---|
| E2 | Drive — how often METABO fires a new theme, 0–100% (0 = off) |
| E3 | Note — METABO imposes its notes on MGEN 0–100% |
| K2 | Scope — **LIGHT** / **FULL** |
| K3 | New theme now (manual trigger) |

- **Drive** (E2): how often METABO fires a **new theme** = the random full regeneration (same as **K2 on page 13**). Frequency = drive × the cell's **stress** — calm cell rarely regenerates, stressed cell regenerates often. Only while MGEN is running.
- **Note** (E3): how much **METABO drives the actual pitches** of MGEN. At each MGEN note, with probability = this amount, the note is replaced by **METABO's current note** (snapped to the MGEN scale, kept in MGEN's register). 0 = MGEN keeps its own notes.
- **Scope**: **LIGHT** = just new themes. **FULL** = mostly new themes + occasional **breaks** / scale changes.
- **K3** fires a new theme immediately (works anytime). The last action is shown (`last: …`).

*Un mode où **METABO déclenche le « new theme » aléatoire de MGEN** (le K2 de la page 13) tout seul, piloté par la cellule. Opt-in (DRIVE 0 = off, MGEN intact).*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Drive — à quelle fréquence METABO lance un new theme 0–100% (0 = off) |
| E3 | Note — METABO impose ses notes à MGEN 0–100% |
| K2 | Portée — **LIGHT** / **FULL** |
| K3 | New theme maintenant (déclenche à la main) |

- **Drive** (E2) : à quelle fréquence METABO lance un **new theme** = la régénération aléatoire complète (comme **K2 page 13**). Fréquence = drive × le **stress** de la cellule — calme = rare, stressée = souvent. N'agit que si MGEN tourne.
- **Note** (E3) : à quel point **METABO impose les hauteurs** de MGEN. À chaque note de MGEN, avec une probabilité = cette valeur, la note est remplacée par **la note courante de METABO** (recalée dans la gamme MGEN, registre gardé). 0 = MGEN garde ses notes.
- **Portée** : **LIGHT** = juste des new themes. **FULL** = surtout des new themes + parfois un **break** / changement de gamme.
- **K3** déclenche un new theme tout de suite (à tout moment). La dernière action est affichée (`last: …`).

---

### Page 27 — LIVE (last page)
A single page to **arm / disarm the modes** during a set. Dial in each mode's parameters on its own page, then come here to toggle them live.

| Encoder / Key | Function |
|---|---|
| E2 | Move cursor through the modes |
| K3 | Toggle the highlighted mode (8OS toggles OFF ↔ TRANS only — never re-records) |
| K2 | **ALL OFF** — panic: stops every mode + all-notes-off on every stream |

- Modes listed: **POtO**, **8OS**, **MGEN**, **SPAT**, **METABO**, **NIAKABY**, **AUDIO** (Audio→MIDI), **IMPRO** (the companion), **WIFI**, **CC**, **PERU** (grain gravity box). Each shows its live state (`ON` / `off`, or `OFF/REC/TRANS` for 8OS). Active modes are brighter. (MIDI modes still need their stream routed once — pages 9–12 / 16 / 19 / 23.)
- **IMPRO** off = the companion keeps **listening and memorizing** but **stops responding** (goes silent); toggle it back on to bring the dialogue back.

*Une seule page pour **armer / couper les modes** en live. Règle les paramètres de chaque mode sur sa page, puis viens ici pour les activer pendant le set.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Déplacer le curseur dans la liste |
| K3 | Activer / couper le mode surligné (8OS bascule OFF ↔ TRANS seulement — ne ré-enregistre jamais) |
| K2 | **ALL OFF** — panic : coupe tous les modes + all-notes-off sur tous les streams |

- Modes listés : **POtO**, **8OS**, **MGEN**, **SPAT**, **METABO**, **NIAKABY**, **AUDIO** (Audio→MIDI), **IMPRO** (le compagnon), **WIFI**, **CC**, **PERU** (bac à grains). Chacun affiche son état live. Les modes actifs sont plus lumineux. (Les modes MIDI doivent rester routés une fois — pages 9–12 / 16 / 19 / 23.)
- **IMPRO** off = le compagnon continue d'**écouter et mémoriser** mais **arrête de répondre** (se tait) ; rallume-le pour relancer le dialogue.

---

### Page 39 — PERU
A gravity toy: drop **grains from the corpus** into a box as little **diamonds**. They fall, bounce off the walls and **trigger their sound on every collision** — panned by where they hit. A physical, playable grain sequencer. Runs continuously while diamonds are in the box.

| Encoder / Key | Function |
|---|---|
| E2 | Select the grain (corpus slot) to drop |
| E3 | Gravity |
| K1 | Drop the selected grain (a diamond falls in) |
| K2 | **Auto-shake** source / amount: `OFF → IN 50/100% → MB 50/100% → IM 50/100%` |
| K3 | Empty the box (clear + stop) |

- **Auto-shake** links the agitation to a signal: **IN** = your input dynamics (continuous), **MB** = METABO (one diamond sings per cell note), **IM** = the impro's activity (continuous). The louder/busier the source, the more the diamonds bounce → more grains fire.
- Diamond size ∝ grain duration · flashes on impact · max 16 (oldest drops when full).
- Own MIDI routing on **stream 8** (page PERU MIDI). Armable from **LIVE**. Dropping a grain arms it; clearing stops it.
- Plays on its **own audio voices** (5-6), so the agent / impro keeps sounding alongside it. **Mutually exclusive with POtO / 8OS** (they share the granular voices — arming one auto-disarms the others).

*Un jouet gravitationnel : dépose des **grains du corpus** dans une boîte sous forme de **diamants**. Ils tombent, rebondissent sur les bords et **déclenchent leur son à chaque choc** — spatialisés selon le point d'impact. Un séquenceur de grains physique et jouable. Tourne en continu tant qu'il y a des diamants.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Choisir le grain (slot du corpus) à lâcher |
| E3 | Gravité |
| K1 | Lâcher le grain sélectionné (un diamant tombe) |
| K2 | **Auto-secousse** source / dose : `OFF → IN 50/100% → MB 50/100% → IM 50/100%` |
| K3 | Vider la boîte (clear + stop) |

- L'**auto-secousse** lie l'agitation à un signal : **IN** = ta dynamique d'entrée (continu), **MB** = METABO (un diamant chante par note de cellule), **IM** = l'activité de l'impro (continu). Plus la source est forte/active, plus les diamants rebondissent → plus de grains.
- Taille du diamant ∝ durée du grain · clignote au choc · max 16 (le plus vieux part quand c'est plein).
- Routage MIDI propre sur le **stream 8** (page PERU MIDI). Armable depuis **LIVE**. Lâcher un grain l'active ; vider l'arrête.
- Joue sur ses **propres voix audio** (5-6), donc l'agent / impro continue de sonner à côté. **Exclusif avec POtO / 8OS** (ils partagent les voix granulaires — armer l'un désarme les autres).

---

### Page 26 — MGEN TASTE
MGEN learns the **genre combinations** you like — the full layout of genres across the 16 channels (a global view), not single notes. It keeps a **bank of liked combinations** and reuses/varies them.

| Encoder / Key | Function |
|---|---|
| E2 | Browse the bank — load the selected liked combination live (0 = leave current) |
| E3 | **Recall** — probability a new theme reuses a liked combination (0% = off, fresh themes) |
| K3 | **LIKE** — save the current combination (the 16-channel genre layout) to the bank |
| K2 | **DISLIKE** — forget the closest liked combination |

- A **combination** = the genre (style) of each of the 16 channels. LIKE snapshots it (up to 24 stored, near-duplicates skipped); DISLIKE removes the most similar one.
- **Recall is an option (E3, default off)**: when a new theme is generated (page 13 **K3 START** / **K2 new theme**, or via METABO>MGEN), MGEN recalls a liked combination (with a slight variation) **with the E3 probability** — otherwise it generates a fresh fully-diverse theme. At 0% themes are always fresh; raise E3 to bring back the layouts you liked.
- The page shows how many combos are saved and a **genre-frequency profile** across all your liked combinations (which genres dominate the layouts you like).
- **Persistent memory**: the bank is saved to the norns SD card (`dust/data/TEAMMATE.POTO/mgen_combos.data`) and reloaded on startup.

*MGEN apprend les **combinaisons de genres** que tu aimes — la répartition complète des genres sur les 16 channels (vision globale), pas des notes isolées. Il garde une **banque de combinaisons aimées** et les réutilise/varie.*

| Encodeur / Touche | Fonction |
|---|---|
| E2 | Parcourt la banque — charge en direct la combinaison sélectionnée (0 = laisse le live) |
| E3 | **Recall** — probabilité qu'un new theme réutilise une combo aimée (0% = off, thèmes frais) |
| K3 | **LIKE** — mémorise la combinaison courante (la répartition genre des 16 channels) |
| K2 | **DISLIKE** — oublie la combinaison aimée la plus proche |

- Une **combinaison** = le genre (style) de chacun des 16 channels. LIKE en fait un snapshot (jusqu'à 24, quasi-doublons ignorés) ; DISLIKE retire la plus proche.
- **Le rappel est une option (E3, off par défaut)** : à chaque nouveau thème (page 13 **K3 START** / **K2 new theme**, ou via METABO>MGEN), MGEN rappelle une combinaison aimée (avec une légère variation) **avec la probabilité E3** — sinon il génère un thème frais pleinement diversifié. À 0% les thèmes sont toujours frais ; monte E3 pour faire revenir tes combos aimées.
- La page affiche le nombre de combos mémorisées et un **profil de fréquence des genres** sur toutes tes combinaisons aimées (quels genres dominent les répartitions que tu aimes).
- **Mémoire persistante** : la banque est sauvegardée sur la carte SD (`dust/data/TEAMMATE.POTO/mgen_combos.data`) et rechargée au démarrage.

---

## Modulation — 8OS MOD / POtO MOD

Internal modulation: a **source** drives a granular engine's sound in real time, like METABO colours NIAKABY. Each page (one for 8OS, one for POtO): **E3** picks the source — **METABO** (stress/growth) · **AUDIO** (live rms/centroid) · **MGEN** (energy/freq) · **COMP** (companion) · **WIFI** (network activity) — **E2** sets depth, **K3** on/off. Two signals are extracted (energy + brightness): energy → shorter grains, brightness → pitch up, energy → spread. Live VU-meters show the source.

*Modulation interne : une **source** pilote en continu le son d'un moteur granulaire. Une page pour le 8OS, une pour le POtO : **E3** choisit la source (METABO / AUDIO / MGEN / COMP / WIFI), **E2** la profondeur, **K3** on/off. Énergie → grains plus courts, brillance → pitch, énergie → spread.*

---

## Sources — WiFi everywhere

Beyond INPUT / METABO / COMP / MGEN, **WiFi** is now a selectable **input source** wherever a source is chosen: **POtO SRC**, **8OS SRC** (grain matching / pitch follow), **METABO FEED** (the cell feeds on network activity), and the MOD pages above. The "WiFi pitch" = the note of the **strongest network** (its channel → a note, **snapped to the MGEN scale**); the energy = WiFi activity. So the granular engines, the cell and the harmonizer can all **follow the WiFi landscape**.

*Au-delà de INPUT / METABO / COMP / MGEN, le **WiFi** est désormais une **source d'entrée** partout où on choisit une source (POtO SRC, 8OS SRC, METABO FEED, pages MOD). Le « pitch WiFi » = la note du réseau le plus fort (canal → note, **calée sur la gamme MGEN**) ; l'énergie = l'activité WiFi.*

---

## The living layer — MIND & STYLE

Two opt-in layers (each a page with a **K3** toggle) that make the companion feel like a partner, not a reactor. Off by default — your patch is unchanged until you enable them.

### MIND — shared listening
A page that **shows what TEAMMATE hears**: energy, density, tension, a slow **macro arc** (CALM → BUILD → PEAK → RELEASE over minutes), phrase state (SPEAKING / GAP / QUIET) and a readable **mood**. With **K3** on, this drives behaviour: the companion **follows your dynamics** (you charge → denser answers; soft → space), your intensity **agitates METABO** (which cascades to the companion, NIAKABY, MGEN — one breathing organism), the macro arc shapes a **long-form set**, and it **recalls your motifs** (transformed) in the gaps.

### STYLE — it plays your way
Learns your **playing style** from every recorded note — tempo (inter-onset), grid vs rubato, **articulation** (legato/staccato), phrase length, **intervals** (steps vs leaps) + direction, register, **dynamics**. With **K3** on, it biases the companion's generation — timing, phrase length, transpositions, articulation, velocity — so it plays *in your manner*, not just with your sound. The page shows the learned profile.

*Deux couches opt-in (chacune une page, toggle **K3**, off par défaut). **MIND** : montre ce que TEAMMATE entend (énergie / densité / tension / arc macro / phrase / humeur) ; activée, le compagnon suit ta dynamique, ton intensité agite METABO (et tout le reste), un arc long structure le set, et il rappelle tes motifs dans les silences. **STYLE** : apprend ta manière de jouer (rythme, grille/rubato, articulation, intervalles, dynamique) et fait jouer le compagnon à ta façon.*

---

## The agent — a Pwnagotchi for music

A **creature** with a face (page **FACE**) whose ASCII expression and one-liners are driven by everything inside — mood, METABO stress, your style, motif recall, and the **WiFi around it**. It speaks in English and calls you **agent**.

- **Recognizes places** by their WiFi fingerprint: *"new place agent"*, then *"welcome back agent"* when you re-arm WiFi somewhere it knows (up to 12 places, **persisted across sessions**).
- **Has opinions** on your playing: *"too repetitive"*, *"breathe agent!"*, *"nice agent!"*, *"my turn!"*.
- **XP & levels**: it grows from networks discovered, places found, motifs learned and time played — announces *"level N agent!"* and shows **Lv N**. Persisted.
- **Autonomy** (**K3** = AUTO, off by default): when you stop, it **dreams** — replaying your motifs on its own (*"dreaming…"*), **with your own phrasing** (their real note timing, not a metronome), from a bank of your last **10 phrases**, never the same twice in a row (sometimes just a fragment); when METABO gets monotonous, it **decides** to change the MGEN theme by itself.

*Une **créature** à visage (page FACE), pilotée par tout l'état interne + le **WiFi** autour. Elle parle anglais et t'appelle **agent**. Elle **reconnaît les lieux** par leur empreinte WiFi (« welcome back agent » au rallumage, jusqu'à 12 lieux persistés), a des **opinions** sur ton jeu, gagne de l'**XP / niveaux**, et — sous **AUTO (K3)** — **rêve** tes motifs quand tu t'arrêtes (avec **ton propre phrasé**, banque de 10 phrases, jamais deux fois le même, parfois un fragment) et **décide** de changer le thème MGEN quand c'est monotone.*

---

## WiFi — the room is an instrument

TEAMMATE can listen to the **WiFi activity** around it and make music from it (Norns only — needs the hardware). Passive scanning only: nearby networks (signal, channel, appearances) + traffic rate. Arm it from the **LIVE** page (9th mode).

- **WiFi page** — monitor (signal bars per network + traffic) **and** per-network MIDI routing.
- **Feeds the brain** — WiFi activity agitates METABO → the whole instrument reacts; also a MOD/input source (above).
- **WiFi → MIDI (notes only)**:
  - **WIFI MIDI** — a global **arpeggio** of the networks (channel → pitch, signal → velocity), a ping on each new network, on a chosen device + channel.
  - **WiFi LINK** — assign **each network** to its own device + channel (**E2** select · **E3** channel · **K2** device · **K3** link). Each linked network plays its **own euclidean rhythm** over 16 steps (signal → density 2–8 hits, channel → offset) → a **polyrhythm drawn by the WiFi landscape**.
- All WiFi notes are **clock-synced** (`clock.sync`, follows MGEN BPM and external MIDI clock) and **snapped to the MGEN scale**.

*TEAMMATE peut écouter l'**activité WiFi** autour de lui et en faire de la musique (Norns seulement). Scan passif : réseaux (signal / canal / apparitions) + débit. Armé depuis la page **LIVE**. Page **WIFI** = moniteur + routage par réseau. Il **nourrit le cerveau** (agite METABO) et sert de source MOD/entrée. **WIFI MIDI** = arpège global des réseaux ; **WiFi LINK** = chaque réseau → son device/canal avec son **rythme euclidien** (signal → densité, canal → décalage) → polyrythme du paysage WiFi. Notes **calées sur l'horloge** et **sur la gamme MGEN**.*

> **Not** included: SSID broadcasting / beacon-flooding (the Norns Wi-Fi chip has no monitor mode) — WiFi here is **read-only** observation.

---

## SAMT (السمت) — motion sensors & dancer interaction

Feed **motion sensors** into Teammate over **OSC** — send to `norns.local:10111` (a stable local name, so there's no IP to chase). The **SAMT** page (arm it from **LIVE**) captures *any* incoming OSC, auto-normalizes each numeric value to an **axis**, and lets you map it.

- **Learn a sensor**: E2 pick a slot **MO1–4**, K3 **learn**, move the sensor → the moving axis binds to the slot (K1 clears). E3 sets the slot's **destination**: `cc` (a CC source), or **`X` / `Y`** (the axis steers PERU's diamonds horizontally / vertically — assign one MO to X and another to Y for 2D trajectory control).
- **MO1–4 are CC sources** (CC page) → motion drives any MIDI CC (synth, choir, DMX…).
- **Dancer ↔ agent interaction**: motion energy agitates METABO → the whole brain → the agent reacts (mood, *decides*, grows in XP). A **sharp gesture** shakes the grains **you** placed in PERU **and** the agent answers by replaying one of your motifs; while the dancer moves, the agent shows a dedicated face (*"i feel you move"*). Two axes assigned to **X** and **Y** steer the PERU diamonds' trajectory in 2D. You choose the grains yourself — nothing is generated randomly.

*SAMT (السمت) — capteurs de mouvement en **OSC** (envoie vers `norns.local:10111`, nom local stable = plus d'IP à chasser). La page **SAMT** (armée depuis **LIVE**) capte n'importe quel OSC, auto-normalise chaque valeur en **axe** mappable. **Learn** : E2 slot **MO1-4**, K3 learn, bouge le capteur → l'axe se lie (K1 efface) ; E3 = destination (`cc` = source CC, ou `X` / `Y` = l'axe pilote la trajectoire horizontale / verticale des diamants PERU). **MO1-4 = sources CC** → le mouvement pilote n'importe quel CC MIDI. **Interaction danseur ↔ agent** : le mouvement agite METABO → tout le cerveau → l'agent réagit (humeur, décide, grandit) ; un **geste sec** secoue les grains que TU as placés dans PERU et l'agent répond en rejouant un de tes motifs ; quand le danseur bouge, l'agent affiche un visage dédié ; deux axes en **X** et **Y** pilotent la trajectoire 2D des diamants. Tu choisis les grains — rien n'est généré au hasard.*

---

## Memory / persistence

All your settings persist across reloads and reboots. They're saved to the norns SD card (`dust/data/TEAMMATE.POTO/`) — automatically every 30 s, on exit, and reloaded on startup. This covers the companion, POtO (incl. SRC / MOD), 8OS (incl. SRC / MOD), MGEN (BPM / scale / evo / channels / routing), METABO, NIAKABY, SPAT, the MIDI routing matrix, the MGEN taste bank, the **MIND / STYLE / AUTO** toggles, the **WiFi → MIDI** settings and per-network links, and the **agent's XP & level**. The agent's **known WiFi places** are saved in their own file (`wifi_places.data`, isolated so it can never corrupt the main save). Live run-states (which modes are playing) are **not** restored — the script starts clean and you arm modes from the LIVE page.

*Tous tes réglages persistent entre les rechargements et les reboots — carte SD (`dust/data/TEAMMATE.POTO/`), toutes les 30 s, à la fermeture, rechargés au démarrage. Couvre le compagnon, POtO (SRC / MOD), 8OS (SRC / MOD), MGEN, METABO, NIAKABY, SPAT, la matrice MIDI, la banque de goûts MGEN, les toggles **MIND / STYLE / AUTO**, les réglages **WiFi → MIDI** et liens par réseau, et l'**XP / niveau de l'agent**. Les **lieux WiFi** connus sont dans leur propre fichier (`wifi_places.data`, isolé). Les états de jeu ne sont pas restaurés.*

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
