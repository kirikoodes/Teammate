# POSE MIROIR

Tu bouges devant la caméra, une vidéo de danse déjà enregistrée « rejoue » ta pose :
à chaque image, l'appli affiche l'image de la séquence dont la posture ressemble le plus à la tienne.

Deux modes indépendants (boutons **CORPS / VISAGE** ou touche `V`), chacun avec **sa séquence et ses propres réglages** :
tout ce que tu règles en CORPS (inertie, lissage, morph, mélange, fondu, entrée, miroir, tracés…) ne change rien en VISAGE, et inversement.
Chaque mode retrouve ses réglages quand on y revient, même après avoir fermé l'appli.

Lancer : double-clic sur `Lancer_PoseMiroir.bat` (sert le dossier sur `localhost:8790`, la caméra l'exige).

## Interface
Thème « PM//NET », froid et futuriste : fond grille sombre, fenêtres à fin cadre cyan et crochets aux coins
(`SORTIE · OUT-01`, `CONTRÔLE · SYS-02`, `RÉSEAU · CORPUS · NET-03`), sections numérotées `01 //`, curseurs à fil,
police IBM Plex Mono. Barre de menus (Fichier · Séquence · Mode · Affichage) ; case de gauche d'une fenêtre = masquer, de droite = agrandir.
(La police ChicagoFLF de l'ancien thème Macintosh reste dans `fonts/` mais n'est plus utilisée.)

## Fenêtre Réseau · Corpus (touche `N`, menu Affichage)
Toutes les images du corpus, rangées par ressemblance (ACP 2D → grille sans chevauchement : les poses proches sont voisines).
- En direct, chaque vignette s'allume selon sa **ressemblance avec l'entrée** (*Seuil* = activation minimale affichée).
- Les **images choisies** passent en couleur, avec crochets, **ID** (`N0142`), poids, et un lien depuis le nœud **INPUT**.
- À gauche, les **curseurs d'entrée** (bouche, lèvres, yeux, tête… ou angles des membres) : blanc = toi, cyan = image affichée.
- Ligne rose = **trajectoire** de la sortie dans la carte (3 dernières secondes).
- En bas, le **tableau** : ID, passage, temps, ressemblance, poids, fichier (`nom_de_séquence#0142.jpg`).
- Survol = fiche de l'image ; clic (hors jeu) = l'afficher. *Carte* / *Grille* (ordre chronologique). Fenêtre déplaçable, redimensionnable.
- Curseurs *MIX / OUVERTURE / SWAP / ENTRÉE* = les mêmes réglages que le panneau.

## Face swap · entrée
- **Face swap** (mode VISAGE) : ton visage en direct est déformé pour épouser exactement les traits du visage généré
  (même maillage de points), avec bord fondu et correction de couleur de peau. 0 = visage généré, 1 = ton visage (bouche comprise).
- **Entrée** : fondu de ton image entière, calée sur le visage / la silhouette de l'image générée. 0 = 100 % généré, 1 = 100 % entrée.
- Les deux se combinent pour doser librement entre image générée et entrée.

## Utilisation
1. **Enregistrer** (compte à rebours 3 s, puis danse, re-clic pour arrêter) ou **Importer vidéo** (analysée en temps réel).
2. **Sauver** → fichier `.poseseq` (images JPEG + squelettes), **Charger** pour le réutiliser.
3. **JOUER** : la personne devant la caméra pilote la vidéo. `F` plein écran, `H` masque le panneau.

## Entrée écran / onglet (YouTube, vidéos du web…)
Sous l'aperçu : **Caméra | Écran / onglet**. Choisir *Écran / onglet* ouvre le sélecteur du navigateur
(onglet, fenêtre ou écran entier). Ensuite **Enregistrer** et **Enrichir en continu** lisent cette source comme la caméra.
- **Recadrer** : tracer un rectangle sur l'aperçu autour du lecteur / du danseur (enlève l'interface du site). **Plein cadre** l'annule.
- **Changer** : choisir une autre source. Arrêter le partage (bandeau du navigateur) → retour caméra automatique.
- L'appli s'ouvre dans sa propre fenêtre Chrome (profil séparé) : pour une vidéo ouverte dans ton Chrome habituel,
  choisir l'onglet **Fenêtre** (ou Écran entier) dans le sélecteur, puis recadrer.
- Mettre la vidéo en grand / plein écran donne une meilleure détection.
- Combo pratique : lancer une vidéo de danse, **Enrichir en continu** → seuls les mouvements nouveaux sont gardés.
- Pour jouer ensuite avec ton corps, repasser sur **Caméra**.

## Enrichir en continu (touche `E`)
La caméra tourne et chaque image est comparée à **tout** le corpus :
- pose déjà connue (ressemblance ≥ seuil *Nouveau si < %*, 88 % par défaut) → rien n'est enregistré ;
- pose nouvelle → un **passage** s'ouvre : ~0,3 s d'avant (le geste démarre proprement), tant que c'est nouveau, puis ~0,45 s après.
Les passages s'ajoutent à la fin de la séquence (en doré sur la frise), la mémoire geste ne mélange jamais deux passages.
On peut enrichir **pendant qu'on joue** : la vidéo réagit et apprend en même temps.
- Seuil haut (95 %) = on garde beaucoup de variantes ; seuil bas (75 %) = seulement les mouvements vraiment différents.
- **Annuler ajout** retire le dernier passage. Sauver conserve les passages.
- Marche aussi en mode VISAGE (nouvelles expressions).

## Principe
- Détection : MediaPipe Pose Landmarker (33 points 3D), GPU si dispo.
- Comparaison : **direction** de 18 os (bras, jambes, tronc, tête), pas les positions
  → indépendant de la taille, de la place dans l'image et des proportions de la personne.
  Les os peu visibles (jambes hors cadre…) ne comptent pas.
- **Mémoire geste** : compare aussi les poses des ~0,1–0,6 s précédentes avec les images précédentes
  de la séquence → distingue un bras qui monte d'un bras qui descend.
- **Inertie** : pénalise les sauts loin de l'image courante (moins de scintillement).
- **Miroir** : je lève le bras droit → la danseuse lève le gauche.

## Mode VISAGE
- Détection : MediaPipe Face Landmarker (478 points), chargé seulement au premier passage en VISAGE.
- Comparaison : 52 coefficients d'expression (bouche, mâchoire, yeux, sourcils, joues…)
  + orientation de la tête (gauche/droite, haut/bas, inclinaison) → indépendant de la taille du visage et de sa place.
- Poids séparés **bouche / yeux / tête** ; *Zoom sur le visage* recadre la sortie sur la tête (marge réglable).
- Filmer le visage assez gros et bien éclairé ; varier expressions et orientations pendant l'enregistrement.
- Un fichier `.poseseq` retient son mode : le charger bascule automatiquement sur le bon.

### Lip-sync (activé par défaut) — la bouche est la référence
- La forme réelle des **lèvres** est mesurée sur 20 points (ouverture, largeur, coins, moue), dans le repère des yeux :
  indépendante de la taille, de la position et de l'inclinaison de la tête ; calée entre deux visages comme le reste.
- En lip-sync : lèvres prioritaires, yeux/tête presque ignorés, **aucun lissage ni inertie sur la bouche**,
  comparaison sur l'instant présent, pas de ponts, morph ~3× plus rapide → les images enchaînent au rythme de la bouche.
- Hors lip-sync : *Poids lèvres* réglable ; la bouche garde de toute façon 3× moins de lissage que le reste.
- Jauges : « lèvres (écart) » et « lèvres (largeur) » montrent ta bouche (rose) face à l'image choisie (cyan).
- Mesuré (bouche d'une autre personne, simulation) : erreur de forme de bouche 0,134 → 0,088.

### Auto-zoom visage sur l'entrée (activé par défaut)
Sur une capture d'écran, le visage est souvent trop petit pour être détecté. En mode VISAGE :
1. **recherche** (« recherche de visage… » sur l'aperçu) : l'image est fouillée en pleine résolution par fenêtres carrées de plus en plus fines ;
2. **suivi** : dès qu'un visage est trouvé, l'entrée zoome dessus (16:9) et le suit — l'aperçu montre le visage en grand ;
3. visage perdu 0,8 s → nouvelle recherche.
Trouve un visage de ~60-70 px sur une capture 1080p en ~1 s.

### Focus visage à l'enregistrement (activé par défaut)
En mode VISAGE, **Enregistrer** et **Enrichir en continu** ne gardent pas l'image entière :
un cadre suit le visage (pointillés dorés sur l'aperçu) et c'est ce **gros plan 768×768** qui est enregistré.
- Idéal pour les vidéos du web où le visage est petit dans l'image.
- Pas de visage = rien d'enregistré (plans de coupe, visage qui sort du champ…).
- *Marge focus* : 1,5 = serré sur le visage, 3 = tête + épaules.
- Un seul visage suivi à la fois (le plus net).

### Calage entre visages (un visage anime un autre)
Chaque visage a son propre neutre (bouche entrouverte au repos, sourcils bas…) et sa propre amplitude.
Chaque expression est ramenée à *(valeur - neutre) / amplitude*, pour la séquence ET pour toi :
ton sourire maximum = son sourire maximum, ta tête « droite » = sa tête « droite » (même si la caméra est placée autrement).
- Automatique : ton amplitude s'apprend en jouant (quelques secondes de grimaces variées au début aident).
- **Calibrer mon neutre** : 3 s visage détendu → plus précis. **Oublier mon calage** quand une autre personne prend la place.
- **Neutre séquence** : l'image affichée devient le neutre de la séquence (sinon automatique).
- **Gain expr.** : exagère tes expressions si la vidéo réagit trop peu.
- Jauges (avec « Tracés ») : rose = toi, cyan = image choisie, après calage.

## Morphing
Au lieu de sauter d'image en image, la sortie **déforme** l'image précédente vers la nouvelle (maillage WebGL
guidé par les points + fondu) : les changements sont étalés, même lors d'un grand saut dans la séquence.
- **VISAGE** : seul le visage se déforme (ovale + une petite marge front/mâchoire, bord adouci).
  Le décor n'est jamais tordu, il passe en simple fondu dessous.
- **CORPS** : toute l'image suit la silhouette.
*Durée morph* : court = nerveux, long = liquide. *Fondu image* ajoute des traînées par-dessus si on veut.
- **Présence morph** (0,8 par défaut) : sépare la déformation du fondu. Haut = l'image se tord longtemps
  (la silhouette suit la nouvelle pose) avant de se fondre dans la suivante ; 0 = fondu rapide.
- Le morph garde toute sa durée **pendant les ponts** : la silhouette glisse à travers les poses intermédiaires
  pendant que l'image se déforme — les deux effets se cumulent.

## Mélange de plusieurs images (Images mêlées)
Au lieu d'une seule image dominante, la sortie mélange les **N images du corpus qui ressemblent le plus à l'entrée**
(pas voisines entre elles), pondérées par leur ressemblance. Chacune est déformée vers une silhouette commune
(moyenne pondérée de leurs points) puis fondues : image plus riche, plus fluide, jamais figée.
- *Images mêlées* : 1 = une seule image (ponts actifs), 2 à 6 = mélange (4 par défaut).
- *Ouverture mix* : bas = seules les images presque identiques se mélangent ; haut = mélange plus large.
- Les images apparaissent / disparaissent en douceur (vitesse liée à *Durée morph*).

## Transitions par images intermédiaires (ponts)
Quand l'image choisie saute d'un endroit à un autre de la séquence, la sortie ne saute pas directement :
elle **traverse de vraies images du corpus** dont chaque pas est une petite différence de pose, puis arrive sur la cible.
- En tâche de fond, chaque image est reliée à ses voisines dans le temps et à ses 10 images les plus ressemblantes
  (« analyse des transitions… % » sous le réglage). Refait automatiquement quand le corpus change.
- Au saut, plus court chemin (Dijkstra) où les gros pas coûtent très cher ; les images quasi identiques sont sautées, 30 étapes max.
- *Durée transition* : temps pour parcourir le pont (court = vif, long = glissé). Le morph fond chaque étape dans la suivante.
- Hystérésis : la cible ne change que si la nouvelle image est nettement meilleure (moins d'allers-retours).
- Mesuré sur 447 images : écart de pose entre deux images affichées ≈ 13× plus petit qu'un saut direct.
- Plus le corpus est riche (enrichissement continu), plus les ponts sont doux.

## Réglages utiles
- Ça saute trop → monter *Inertie* / *Lissage*.
- Ça colle mal aux gestes rapides → baisser *Lissage*, monter *Mémoire geste*.
- Personne filmée de près (sans jambes) → *Poids jambes* à 0.
- Pour les meilleurs résultats : même cadrage (plein pied) à l'enregistrement et au jeu,
  et une séquence qui couvre beaucoup de postures variées.
