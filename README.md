# TEAMMATE.POTO — Norns

*Un partenaire d'improvisation, pas un accompagnateur.*

---

## Philosophie

La plupart des systèmes audio "intelligents" écoutent pour répondre.  
TEAMMATE écoute pour **comprendre** — puis décide s'il veut répondre, et comment.

L'idée de départ est simple : un musicien improvise seul depuis trop longtemps. Il a besoin d'une présence qui l'écoute vraiment — qui capte l'énergie d'un geste, la couleur d'un timbre, la densité d'une phrase — et qui engage le dialogue à partir de ce qu'elle a entendu, pas d'une bibliothèque préréglée.

TEAMMATE ne joue pas *avec* toi au sens d'un accompagnement. Il joue *à toi* — il te répond, te conteste, t'imite, se tait, prend l'initiative quand tu t'arrêtes. Comme un partenaire humain, il a ses propres intentions. Il peut couper la parole. Il peut rester silencieux pendant longtemps, puis exploser. Il peut choisir de faire exactement le contraire de ce que tu fais.

Ce n'est pas de la génération. C'est de la **remémoration active** : TEAMMATE ne crée rien qu'il n'a pas entendu de toi — il réorganise, déforme, et recontextualise ta propre matière sonore pour te la renvoyer sous une forme nouvelle.

---

## Installation

```bash
scp "TEAMMATE_PC.POTO/teammate_norns/teammate.lua" we@norns.local:"/home/we/dust/code/TEAMMATE.POTO/teammate.lua"
scp "TEAMMATE_PC.POTO/teammate_norns/lib/Engine_Teammate.sc" we@norns.local:"/home/we/dust/code/TEAMMATE.POTO/lib/Engine_Teammate.sc"
```

Mot de passe : `sleep`

Puis depuis MAIDEN ou SYSTEM > RESTART pour recharger le script.

Lien Maiden direct : `http://norns.local/maiden/#edit/dust/code/TEAMMATE.POTO/teammate.lua`

---

## Démarrage rapide

1. Brancher l'instrument ou le micro en entrée Norns
2. Charger le script **TEAMMATE.POTO** depuis SELECT
3. Page 1 CORPUS : régler `E3 thr` selon ton niveau de bruit de fond (commence à `0.003`)
4. Jouer — TEAMMATE écoute et commence à répondre après quelques sons enregistrés
5. Surveiller le compteur `corpus X/48` en bas à gauche

---

## Navigation

```
E1        — page précédente / suivante (bidirectionnel, boucle 1→11)
K2        — page suivante
K3        — action principale de la page (voir tableau)
```

---

## Les 11 pages

### Page 1 — CORPUS
Mémoire à court terme. Tout ce que tu joues y est découpé en événements.

| Encodeur | Fonction |
|---|---|
| E2 | Taux d'apprentissage 0–100% (`FROZEN` à 0) |
| E3 | Seuil de gate (bruit de fond) |
| K3 | Effacer le corpus |

- **Grille 48 cases** : chaque case = un son enregistré (énergie, pitch, durée)
- **FROZEN** : corpus gelé, TEAMMATE joue depuis ce qu'il a mémorisé sans rien apprendre de nouveau
- **Point rouge** en haut à droite : enregistrement en cours

---

### Page 2 — MAIN
Comportement global de l'improvisation.

| Encodeur | Fonction |
|---|---|
| E2 | Densité de réponse (nombre d'événements par phrase) |
| E3 | Biais de silence (probabilité de se taire) |
| K3 | Forcer une réponse immédiate |

---

### Page 3 — RESP
Qualité de la réponse.

| Encodeur | Fonction |
|---|---|
| E2 | Contraste (0 = imiter, 1 = s'opposer) |
| E3 | Probabilité de répondre à chaque phrase |
| K3 | Mode sourd ON/OFF |

- **Mode sourd** : TEAMMATE ignore l'entrée audio et improvise de manière autonome depuis le corpus

---

### Page 4 — TIME
Timing de l'échange.

| Encodeur | Fonction |
|---|---|
| E2 | `react` — silence minimum pour sceller un fragment (défaut 0.8s) |
| E3 | `init` — silence minimum avant que TEAMMATE prenne l'initiative (défaut 1.5s) |
| K3 | Mode voix ON/OFF |

- **Mode voix** : durée minimale des syllabes 120ms, adapté au chant et à la parole

---

### Page 5 — POtO
Texture granulaire en temps réel sur les 4 dernières secondes.

| Encodeur | Fonction |
|---|---|
| E2 | Volume POtO |
| E3 | Monitor (volume du signal direct en sortie) |
| K3 | POtO ON/OFF |

- Trois lecteurs : **LEAD** (zone fraîche), **ATTRACTED** (dérive vers LEAD), **REPULSED** (poussé vers le passé)
- Crée un halo sonore autour de ta performance en temps réel

---

### Page 6 — GRAIN
Paramètres des grains POtO.

| Encodeur | Fonction |
|---|---|
| E2 | Taille du grain (ms) |
| E3 | Spread / detune entre les lecteurs |
| K3 | Preset de rate (0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0) |

---

### Page 7 — 8OS
Sampler granulaire à mémoire longue. Enregistre une séquence entière, puis rejoue des grains sélectionnés par correspondance pitch + énergie.

| Encodeur | Fonction |
|---|---|
| E2 | Volume 8OS |
| E3 | Taille des grains de lecture (ms) |
| K3 | Cycle OFF → REC → TRANS |

#### Flux de travail

```
K3 → REC   : enregistrement continu dans le buffer 20s
              les grains se créent automatiquement toutes les [grain ms]
              le compteur monte en temps réel

K3 → TRANS : lecture — 3 voix cherchent les grains
              les plus proches de ton pitch + énergie live
              (matching MIDI complet avec octave)

K3 → OFF   : arrêt
```

- **Sélection des grains** : score combiné pitch 55% + énergie 35% + timbre 10%
- **3 voix LOCK** : toutes cherchent les grains les plus proches (polyphonie, pas de voix opposée)
- Le bank persiste quand on passe de REC à TRANS

---

### Page 8 — CLR8OS
Page de confirmation pour vider le bank 8OS.

| Encodeur | Fonction |
|---|---|
| K3 | Effacer le bank 8OS |

---

### Page 9 — MIDI I
MIDI pour l'improvisation TEAMMATE (notes calées sur les grains joués).

| Encodeur | Fonction |
|---|---|
| E2 | Canal MIDI (1–16) |
| E3 | Device MIDI (index) |
| K3 | MIDI IMPRO ON/OFF |

---

### Page 10 — MIDI P
MIDI pour les grains POtO.

| Encodeur | Fonction |
|---|---|
| E2 | Canal MIDI (1–16) |
| K3 | MIDI POtO ON/OFF |

---

### Page 11 — MIDI 8
MIDI pour les grains 8OS.

| Encodeur | Fonction |
|---|---|
| E2 | Canal MIDI (1–16) |
| K3 | MIDI 8OS ON/OFF |

---

## Indicateurs écran

| Indicateur | Signification |
|---|---|
| `●` rouge (haut droite) | Enregistrement corpus en cours |
| `FROZEN` (page 1) | Corpus gelé, apprentissage à 0% |
| `V` (haut droite) | Mode voix actif |
| `D` (haut droite) | Mode sourd actif |
| `VD` | Les deux actifs |
| Barre `ctr` / `flat` | Centroïde spectral / flatness live |

---

## Le corpus — mémoire à court terme

Tout ce que tu joues est découpé en événements sonores et stocké dans un corpus circulaire de **48 cases**. Chaque événement est caractérisé par :

- son **énergie** (RMS)
- sa **hauteur** (pitch fondamental)
- son **timbre** (centroïde spectral)
- sa **texture** (flatness spectrale)
- sa **durée**

Quand TEAMMATE cherche à répondre, il calcule la distance entre ces portraits sonores pour trouver ce qui ressemble à ce que tu viens de jouer — ou ce qui s'en éloigne le plus, selon la stratégie choisie.

Le corpus est **volontairement court** (96 secondes max). Ce qu'il joue vient toujours de ce moment présent de la session.

---

## Les 5 stratégies

TEAMMATE choisit sa stratégie de réponse de façon probabiliste, pondérée par le contexte musical en cours :

| Stratégie | Intention |
|---|---|
| **IMITATION** | Reproduire l'énergie et le timbre de ta phrase |
| **CONTRASTE** | Choisir le son le plus éloigné de ce que tu viens de jouer |
| **DENSIFICATION** | Répondre avec plus d'événements, plus rapprochés |
| **SPARSE** | Ralentir, espacer, créer du vide |
| **SILENCE** | Ne rien dire — un geste musical à part entière |

---

## L'initiative

Après `init` secondes de silence de ta part, TEAMMATE ne attend plus. Il choisit un événement "intéressant" du corpus et part en improvisation spontanée. Plus le silence dure, plus la probabilité augmente.

---

## POtO — présence continue

En parallèle du dialogue, POtO est une texture granulaire construite sur les 4 dernières secondes de ta performance :

- **LEAD** — colle à la zone la plus fraîche
- **ATTRACTED** — dérive lentement vers LEAD, légèrement désaccordé au-dessus
- **REPULSED** — poussé vers le passé du buffer, désaccordé en dessous

L'ensemble crée un halo sonore — une résonance de toi-même décalée dans le temps et la hauteur.

---

## 8OS — mémoire longue granulaire

8OS enregistre une longue séquence (jusqu'à 20 secondes) et la découpe en grains analysés. En mode TRANS, trois lecteurs cherchent en permanence les grains dont le **pitch** et l'**énergie** correspondent le mieux à ce que tu joues en live :

- V5 LOCK : grain #1 le plus proche, volume 100%
- V6 LOCK : grain #2 le plus proche, volume 65%
- V3 LOCK : grain #3 le plus proche, volume 40%

La sélection utilise le numéro MIDI complet (avec octave) — chanter grave donne des grains graves, chanter aigu donne des grains aigus.

---

## Softcut layout (référence technique)

| Voix | Rôle |
|---|---|
| V1 | Enregistrement corpus |
| V2 | Lecture corpus |
| V3 | Lecture corpus (emprunté par 8OS TRANS ou POtO REPULSED) |
| V4 | Enregistrement POtO continu + enregistrement 8OS |
| V5 | POtO LEAD / 8OS LOCK #1 |
| V6 | POtO ATTRACTED / 8OS LOCK #2 |

---

## Ce projet n'est pas

- Un générateur de musique autonome
- Un effet audio
- Un looper intelligent

C'est un interlocuteur. Il a besoin de toi pour exister.

---

*Port Norns (Lua + SuperCollider) d'un moteur Python original — NSDOS 2026*
