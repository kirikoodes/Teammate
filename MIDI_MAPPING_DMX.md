# TEAMMATE.POTO — Feuille de mapping MIDI (pour DMX / QLC+)

> Toutes les sorties MIDI de Teammate, à associer dans QLC+ (apprentissage MIDI) pour piloter ton Enttec DMX USB Pro.
>
> ⚠️ **Tous les canaux indiqués sont les valeurs par DÉFAUT.** Chaque couche a sa page de réglage dans le script (pages MIDI 9-12, 16, 19, 23, 35-38) où tu peux changer le canal et le device de sortie (jusqu'à 4 devices). Le routage de chaque couche s'arme dans la matrice MIDI.

## 🎵 Couches qui envoient des NOTES

| # | Couche | Canal défaut | Ce qu'elle envoie | Idée lumière |
|---|--------|:---:|---|---|
| 1 | **IMPRO** (impulsion) | 1 | note = pitch détecté de ton jeu, déclenché par les attaques | Flash sur attaque / accents |
| 2 | **POtO** (granulaire) | 2 | 3 lecteurs orbitaux (L/A/R), vélocité ∝ volume (127 / 83 / 51) | Nappe de couleur lente, 3 sources |
| 3 | **8OS** (sampler longue mémoire) | 3 | notes n5 / n6 / n3, vélocité ∝ volume (127 / 83 / 51) | Couleur de fond évolutive |
| 4 | **MGEN** (séquenceur) | **par lane : lane _i_ → canal _i_** (1-16) | notes des patterns, 16 lanes indépendantes | Rythme / chase synchronisé au tempo |
| 6 | **METABO** (cellules) | 16 | note_on/off générés par la métabolisation autonome | Mouvements organiques, dimmer pulsé |
| 7 | **NIAKABY** (accords) | 7 | notes d'accords depuis le pitch détecté | Changements de couleur harmoniques |
| — | **AUDIO→MIDI** | 5 | note qui suit le pitch d'entrée en continu | Position/teinte qui suit ton jeu |
| — | **WiFi→MIDI** | 1 | note **84** = nouveau réseau détecté ; notes de trafic | Strobe ponctuel sur événement réseau |
| — | **LoRa** | 1 | notes d'appel / réponse / lecture des messages reçus | Flash sur message entrant |

## 🎛️ Couches qui envoient des CC (contrôle continu — idéal pour dimmer/couleur)

| CC # | Nom standard | Source dans Teammate | Canal défaut | Idée lumière |
|:---:|---|---|:---:|---|
| **11** | Expression | RMS / amplitude d'entrée (×600, clampé) | 5 (AUDIO) | **Intensité (dimmer) globale** = ton volume |
| **74** | Cutoff / Brightness | Centroïde spectral (/80) | 5 (AUDIO) | Brillance / teinte = clarté du son |
| **1** | Modwheel | Trafic WiFi (CC configurable) | 1 (WiFi) | Scintillement / densité ambiante |
| **1-16** | (configurable) | **CC GEN** : 16 lanes continues à sources internes autonomes | 1 (cc_ch) | 16 canaux DMX libres et lissés ! |
| **123** | All Notes Off | Panic / arrêt | tous | (à ignorer côté lumière) |

## ⭐ Le meilleur point d'entrée pour le DMX : **CC GEN**

Les 16 « CC lanes » (`cc_on` armable depuis la page LIVE) sont **faites pour ça** : chacune est un signal continu, lissé, à source intelligente (signaux internes de Teammate ou mouvement autonome), envoyé sur un n° de CC paramétrable. C'est l'équivalent de **16 faders DMX automatiques**.

➡️ Dans QLC+ : crée 16 sliders dans la Virtual Console, fais l'apprentissage MIDI sur CC 1→16 (canal `cc_ch`, déf. 1), et assigne chacun à un canal DMX (dimmer, R, G, B, pan, tilt…).

## Recette de démarrage rapide (QLC+)

1. **Dimmer master** ← apprends le **CC 11** (canal 5) → ton volume pilote l'intensité.
2. **Couleur/teinte** ← apprends le **CC 74** (canal 5) → la brillance du son pilote la couleur.
3. **Strobe / accents** ← apprends la **note IMPRO** (canal 1) ou METABO (canal 16).
4. **16 effets libres** ← arme **CC GEN** et apprends **CC 1→16** (canal 1).

---

### Références code (TEAMMATE.POTO.lua)
- Canaux par défaut : lignes 297-305 (`midi_ch`), 300 (audio = ch 5)
- CC audio (11 & 74) : lignes 2225-2226
- CC GEN (16 lanes) : ligne 3041, déf. ligne 2486+
- WiFi note 84 / CC : lignes 3065-3072 ; `wifi_midi_cc` ligne 2529
- METABO / NIAKABY : lignes 3125-3135
