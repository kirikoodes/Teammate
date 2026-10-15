-- lib/niakaby.lua
-- NIAKABY — harmoniseur + PROGRESSION D'ACCORDS. 4 modes (K1) :
--   NOTE   : harmonise en direct la note entendue (comportement d'origine).
--   FOLLOW : DEDUIT l'accord de ce qu'il entend (memoire harmonique/chroma), cale sur la gamme MGEN,
--            change a chaque mesure. Nourri par toutes les sources activees (INPUT/METABO/COMP/MGEN/SNOT).
--   AUTO   : joue une PROGRESSION programmee (presets), calee sur l'horloge (1 accord/mesure).
--   BLEND  : trame AUTO, corrigee par ce qu'il entend quand l'oreille est nette.
-- Accords TRIAD/7e/9e/sus + basse, couleur METABO. Sort via la matrice (stream 7).

local M = {}

M.scale_names = {"MAJOR","MINOR","DORIC","PHRYG","HIJAZ","PENMIN","PENMAJ",
  "HIRA","INSEN","KUMOI","IWATO","PELOG","SLENDRO","SABA","NAHAW","BYZANT"}
M.scales = {
  MAJOR = {0,2,4,5,7,9,11}, MINOR = {0,2,3,5,7,8,10}, DORIC = {0,2,3,5,7,9,10},
  PHRYG = {0,1,3,5,7,8,10}, HIJAZ = {0,1,4,5,7,8,11},
  PENMIN = {0,3,5,7,10}, PENMAJ = {0,2,4,7,9}, HIRA = {0,2,3,7,8}, INSEN = {0,1,5,7,10},
  -- gammes du monde (toniques) : japon, gamelan indonesien, arabo-andalou/maqam
  KUMOI   = {0,2,3,7,9},            -- japon (kumoi)
  IWATO   = {0,1,5,6,10},           -- japon (iwato)
  PELOG   = {0,1,3,7,8},            -- gamelan (pelog, approx. en temperament egal)
  SLENDRO = {0,2,5,7,9},            -- gamelan (slendro, approx.)
  SABA    = {0,2,3,5,6,8,10},       -- arabo (maqam saba, approx. sans quarts de ton)
  NAHAW   = {0,2,3,5,7,8,11},       -- arabo (maqam nahawand)
  BYZANT  = {0,1,4,5,7,8,11},       -- byzantin / double harmonique (arabo-andalou)
}
M.scale_idx = 1     -- MAJOR par defaut (utilise en mode NOTE ; FOLLOW/AUTO/BLEND suivent MGEN)
M.root      = 48    -- C3 (mode NOTE ; sinon tonique MGEN)
M.octave    = 0     -- -2..+2
M.transpose = 0     -- transposition (demi-tons) appliquee a TOUTE la sortie (pilotee par METABO)

M.chord_names = {"TRIAD","7TH","9TH","SUS"}
M.CHORD_STEPS = {
  TRIAD   = {0,2,4},
  ["7TH"] = {0,2,4,6},
  ["9TH"] = {0,2,4,6,8},
  SUS     = {0,3,4},
}
M.chord_idx = 1

M.on   = false
M.thr  = 0.01       -- seuil de detection (mode NOTE)

-- ===== MODES =====
M.mode_names = { "NOTE", "FOLLOW", "AUTO", "BLEND", "ARP" }
M.mode = 2          -- FOLLOW par defaut
-- ARP (facon CHORDimist, Leestrument) : arpege l'accord deduit, PAS de nappe tenue. Direction + rythme.
M.ARP_DIR_NAMES  = { "UP", "DOWN", "UP-DN", "RAND", "CHORD" }   -- CHORD : accords de la progression (comme AUTO) en pulse rythme
M.ARP_RATE_NAMES = { "1/2", "1/4", "1/8", "1/8T", "1/16", "1/16T", "1/32" }   -- vitesse : lent -> rapide
M.ARP_RATE       = { 2, 1, 0.5, 1/3, 0.25, 1/6, 0.125 }   -- en beats (clock.sync cote script principal)
M.arp_dir        = 1
M.arp_rate_idx   = 3      -- 1/8 par defaut
M.arp_oct        = 2
M.arp_notes      = nil
M.arp_i          = 1
M.arp_bounce     = 1
M.arp_playing    = nil
M.arp_gate       = 0.8    -- GATE/SUSTAIN de l'arp (fraction du pas) : <1 = NIAKABY relache la note TOT
                          -- -> c'est la RELEASE de TON synthe qui sonne ensuite (tu la regles toi-meme) ;
                          -- 1 ou + = legato (notes enchainees). Reglable : page ARP, K2 maintenu + E3.

-- ===== SEQUENCEUR DE GROOVE (en mode ARP) : grille de pas, cale sur l'horloge master (OP-XY) =====
-- chaque pas : 0 = espace (rest), 1 = joue, 2 = double (ratchet x2), 3 = triple. + swing.
M.seq_on    = false
M.seq_len   = 16          -- nombre de pas (1..32)
M.seq_pat   = {}          -- valeurs par pas (nil = 1 = joue)
M.seq_swing = 0.0         -- swing : retarde les pas PAIRS (0..0.6 du pas)
M.seq_i     = 0           -- pas courant (tete de lecture)
M.seq_cur   = 1           -- curseur d'edition
M.SEQ_VAL_NAMES = { "·", "x", "xx", "xxx" }   -- rest / joue / double / triple (affichage cellule)

-- memoire harmonique (classes de hauteur 0..11) : nourrie par ce que NIAKABY entend
M.chroma = {} ; for _i = 0, 11 do M.chroma[_i] = 0 end
M.mgen_key = nil    -- function() return root, scale_table end : cale FOLLOW/AUTO/BLEND sur la gamme+tonique de MGEN
-- TONALITE : d'ou vient la tonique (FOLLOW/AUTO/BLEND/ARP). MGEN, la gamme propre NIAKA, ton INPUT, ou l'IMPRO.
M.KEY_FROM_NAMES = { "AUTO", "MGEN", "NIAKA", "INPUT", "IMPRO" }
M.key_from       = 1     -- 1=AUTO (suit la source COCHEE dans SRC : MGEN si coche, sinon INPUT/COMP, sinon NIAKA)
M.last_heard     = {}    -- derniere note entendue par source (pour TONALITE INPUT/IMPRO)
M.det_scale      = "MAJOR"   -- gamme detectee (MAJEUR/MINEUR) pour INPUT/IMPRO, avec hysteresis
M.heard_new      = false     -- une nouvelle note a ete entendue depuis le dernier pas (FOLLOW/ARP : sinon on GARDE l'accord)
M.hold           = false      -- HOLD/GEL : ignore TOUT l'input -> NIAKABY continue de tourner sans etre influence (tu joues librement)
M.release_t      = 0.28       -- chevauchement/release des notes sortantes (laisse l'ADSR du synthe sonner)
M.sil_rel        = 0.45       -- silence avant de relacher l'accord en NOTE (plus long = ne coupe pas sur un micro-silence)

-- progressions (AUTO/BLEND/ARP-CHORD) : suites de degres (1 = tonique de la gamme active).
-- Longueurs variees (3,4,5,6,8,12) = patterns differents ; le degre s'adapte a la gamme (meme penta).
M.progs = {
  {1,5,6,4},                      -- POP     I-V-vi-IV
  {6,4,1,5},                      -- POP2    vi-IV-I-V
  {1,6,4,5},                      -- 50s     I-vi-IV-V (doo-wop)
  {1,4,5},                        -- 3CH     I-IV-V
  {1,5,4,5},                      -- POPV    I-V-IV-V
  {1,4,1,5},                      -- GOSPEL  I-IV-I-V
  {2,5,1},                        -- 251     ii-V-I (jazz)
  {2,5,1,6},                      -- 251vi   ii-V-I-vi
  {1,6,2,5},                      -- RHYTHM  I-vi-ii-V (rhythm changes)
  {3,6,2,5},                      -- 3625    iii-vi-ii-V
  {1,4,3,6,2,5},                  -- JAZZ6   I-IV-iii-vi-ii-V
  {1,1,1,1,4,4,1,1,5,4,1,5},      -- BLUES12 blues 12 mesures
  {1,4,1,1,4,4,1,1,5,4,1,1},      -- BLUESqk quick-change
  {1,5,6,3,4,1,4,5},              -- CANON   Pachelbel
  {1,7,6,5},                      -- ANDAL   i-VII-VI-V (andalou)
  {1,6,3,7},                      -- EPIC    i-VI-III-VII
  {1,7,6,7},                      -- EPIC2   i-VII-VI-VII
  {1,4,7,3},                      -- MINjz   i-iv-VII-III
  {1,6,7},                        -- MIN67   i-VI-VII
  {6,5,4,5},                      -- viV     vi-V-IV-V
  {1,3,4,5},                      -- I-iii   I-iii-IV-V
  {1,2,3,4,5,6,7,1},              -- CLIMB   gamme montante
  {1,7,6,5,4,3,2,1},              -- DESCEND run descendant
  {1,5,2,6,3,7,4,1},              -- CIRCLE  quintes descendantes
  {1,1,4,4},                      -- FUNK    vamp I -> IV
  {2,5,2,5},                      -- FUNK2   vamp ii-V
  {1,7,4,1},                      -- FUNKmx  I-bVII-IV-I (mixolydien)
  {1,2,5,1},                      -- BOSSA   I-II-V-I
  {6,2,5,1},                      -- BOSSAm  vi-ii-V-I
  {3,6,2,5,1,4,2,5},              -- BOSSAjz chaine de ii-V
  {1,6,5,7},                      -- TRAP    i-VI-v-VII (sombre)
  {6,7,1,1},                      -- TRAP2   VI-VII-i
  {1,4,6,7},                      -- TRAP3   i-iv-VI-VII
}
M.prog_names = {
  "POP","POP2","50s","3CH","POPV","GOSPEL","251","251vi","RHYTHM","3625","JAZZ6",
  "BLUES12","BLUESqk","CANON","ANDAL","EPIC","EPIC2","MINjz","MIN67","viV","I-iii",
  "CLIMB","DESCEND","CIRCLE",
  "FUNK","FUNK2","FUNKmx","BOSSA","BOSSAm","BOSSAjz","TRAP","TRAP2","TRAP3",
}
M.prog_idx   = 1
-- vitesse de changement d'accord (FOLLOW/AUTO/BLEND) : toutes les X beats (du lent au tres rapide ~arpege)
M.HARM_RATE_NAMES = { "2 mes", "1 mes", "1/2", "1 tps", "1/8", "1/8T", "1/16", "1/32" }
M.HARM_RATE       = { 8, 4, 2, 1, 0.5, 1/3, 0.25, 0.125 }   -- en beats (clock.sync cote script principal)
M.harm_rate_idx   = 2                -- 1 mesure (4 beats) = comportement d'origine

-- ce que NIAKABY ecoute (combinable) -> harmonisation (NOTE) et memoire harmonique (FOLLOW/BLEND)
M.src        = { input = true, metabo = false, comp = false, mgen = true, snot = false }  -- ecoute MGEN par defaut (FOLLOW suit MGEN)
M.src_keys   = { "input", "metabo", "comp", "mgen", "snot" }
M.src_labels = { "INPUT", "METABO", "COMP", "MGEN", "SNOT" }
M.src_cursor = 1

-- callbacks fournis par le script principal
M.note_on  = nil    -- function(note, vel)
M.note_off = nil    -- function(note)
M.metabo   = nil    -- reference table metabolik (lecture, pour le link)
M.feed     = nil    -- function(rms,freq,centroid,flatness) : nourrit METABO si link

-- etat
local cur_notes = {}
local cur_deg   = nil
local sounding  = false
local sil_t     = 0
local since     = 0
local prog_pos  = 1
local pend_deg  = nil    -- degre candidat (confirmation anti-saut d'harmonique)
local pend_oct  = 0
local pend_cnt  = 0
M.last_root     = nil    -- pour affichage

local function scale() return M.scales[M.scale_names[M.scale_idx]] end

-- tonique + gamme actives : MGEN si cale (FOLLOW/AUTO/BLEND), sinon les reglages NIAKABY (NOTE)
-- detecte MAJEUR/MINEUR a partir du chroma entendu, relatif a la tonique pc (hysteresis)
local function detect_scale(pc)
  local maj = (M.chroma[(pc + 4) % 12] or 0) + (M.chroma[(pc + 9) % 12] or 0) * 0.5   -- tierce + sixte majeures
  local min = (M.chroma[(pc + 3) % 12] or 0) + (M.chroma[(pc + 8) % 12] or 0) * 0.5   -- tierce + sixte mineures
  if maj + min > 0.3 then                              -- assez d'evidence pour trancher
    if      min > maj * 1.2 then M.det_scale = "MINOR"
    elseif  maj > min * 1.2 then M.det_scale = "MAJOR" end
  end
  return M.scales[M.det_scale] or M.scales.MAJOR
end

-- tonique + gamme a partir d'une note entendue d'une source (classe de hauteur + maj/min detecte)
local function key_from_heard(ln)
  local root = M.root + ((ln - M.root) % 12)
  return root, detect_scale(root % 12)
end

local function key_now()
  local kf = M.key_from or 1
  if kf == 1 then                                     -- AUTO : suit la SOURCE COCHEE (SRC)
    local s = M.src or {}
    if s.mgen and M.mgen_key then                     -- MGEN coche + en train de jouer -> clef de MGEN
      local r, sc = M.mgen_key()
      if r and type(sc) == "table" and #sc > 0 then return r, sc end
    end
    if s.input and M.last_heard.input then return key_from_heard(M.last_heard.input) end
    if s.comp  and M.last_heard.comp  then return key_from_heard(M.last_heard.comp)  end
    return M.root, scale()                            -- rien de coche/entendu -> NIAKA
  elseif kf == 2 and M.mgen_key then                  -- MGEN force
    local r, sc = M.mgen_key()
    if r and type(sc) == "table" and #sc > 0 then return r, sc end
  elseif kf == 4 or kf == 5 then                      -- INPUT / IMPRO force
    local ln = M.last_heard[(kf == 4) and "input" or "comp"]
    if ln then return key_from_heard(ln) end
  end
  return M.root, scale()                              -- NIAKA (kf==3) ou fallback
end

-- clef JOUEE actuellement (tonique MIDI + gamme), transposition incluse : pour que MGEN/METABO
-- se calent sur NIAKABY quand il est le lead harmonique.
function M.cur_key()
  local r, sc = key_now()
  return (r or M.root) + (M.transpose or 0), sc
end

local function freq_to_midi(f)
  if not f or f < 30 then return nil end
  return math.floor(69 + 12 * math.log(f / 440) / math.log(2) + 0.5)
end

-- degre de gamme + octave le plus proche d'une note MIDI, dans une tonalite (root, sc).
-- Par defaut la gamme NIAKA ; en ARP on passe la tonalite RESOLUE (key_now) pour suivre la source.
local function nearest_degree(note, root, sc)
  root = root or M.root ; sc = sc or scale() ; local L = #sc
  local best, bestd, bestoct = 1, 999, 0
  for o = -3, 4 do
    for i = 1, L do
      local cand = root + o * 12 + sc[i]
      local dd = math.abs(cand - note)
      if dd < bestd then bestd = dd ; best = i ; bestoct = o end
    end
  end
  return best, bestoct
end

-- construit l'accord (notes MIDI) pour un degre, dans (root, sc), avec couleur METABO
local function build_chord(deg, oct, root, sc)
  root = root or M.root ; sc = sc or scale()
  local L = #sc
  local shape = M.CHORD_STEPS[M.chord_names[M.chord_idx]]
  local notes = {}
  local function add_step(st)
    local d   = (deg - 1) + st
    local o   = math.floor(d / L)
    local idx = (d % L) + 1
    local n   = root + (M.octave + oct + o) * 12 + sc[idx] + (M.transpose or 0)
    while n < 24  do n = n + 12 end
    while n > 100 do n = n - 12 end
    notes[#notes + 1] = n
  end
  for _, st in ipairs(shape) do add_step(st) end
  -- basse a l'octave grave (fondamentale)
  local bass = root + (M.octave + oct - 1) * 12 + sc[((deg - 1) % L) + 1] + (M.transpose or 0)
  while bass < 24 do bass = bass + 12 end
  notes[#notes + 1] = bass
  -- couleur METABO (quand la cellule est active)
  if M.metabo and M.metabo.on then
    local st = M.metabo.stressFx or 0
    local gr = (M.metabo.ch and M.metabo.ch.growth) or 0
    if st > 0.5  and #shape < 4 then add_step(6) end   -- 7e sous stress
    if st > 0.75 then add_step(8) end                  -- 9e si tres stresse
    if gr > 0.5  then add_step(7) end                  -- doublure octave si croissance
  end
  return notes
end

-- liste de notes de l'arpege : l'accord (degre deg, octave oct) deploye sur arp_oct octaves, trie/dedupe
local function build_arp(deg, oct, root, sc)
  root = root or M.root ; sc = sc or scale()
  local L = #sc
  local shape = M.CHORD_STEPS[M.chord_names[M.chord_idx]]
  local seen, notes = {}, {}
  for o = 0, (M.arp_oct or 2) - 1 do
    for _, st in ipairs(shape) do
      local d   = (deg - 1) + st
      local idx = (d % L) + 1
      local oo  = math.floor(d / L) + o + (oct or 0)
      local n   = root + (M.octave + oo) * 12 + sc[idx] + (M.transpose or 0)
      while n < 24 do n = n + 12 end ; while n > 100 do n = n - 12 end
      if not seen[n] then seen[n] = true ; notes[#notes + 1] = n end
    end
  end
  table.sort(notes)
  return notes
end

-- duree d'un pas d'arpege en secondes (pour appliquer le GATE/sustain)
local function arp_step_sec()
  local beats = (M.ARP_RATE and M.ARP_RATE[M.arp_rate_idx or 3]) or 0.5
  local tempo = (clock and clock.tempo) or 120
  if not tempo or tempo <= 0 then tempo = 120 end
  return beats * 60 / tempo
end

-- joue UNE note d'arpege avec le GATE choisi : si gate < 1, on programme un note_off
-- TOT (a gate*pas) -> le reste du pas laisse sonner la RELEASE de ton synthe.
-- gate >= 1 : pas de coupe anticipee -> legato (la note tient jusqu'au pas suivant).
-- duree d'un note_on selon le GATE : g<=0.12 = TRIG (impulsion fixe 30ms, TON synthe
-- fait tout le reste de l'enveloppe) ; sinon fraction du pas.
local function gate_dur(g)
  if g <= 0.12 then return 0.03 end
  return arp_step_sec() * g
end

local function arp_fire(note, vel)
  if M.note_on then M.note_on(note, vel or 92) end
  M.arp_playing = note
  local g = M.arp_gate or 0.8
  if g < 1.0 and M.note_off and clock and clock.run then
    local held = note ; local dur = gate_dur(g)
    clock.run(function()
      clock.sleep(dur)
      if M.arp_playing == held and M.note_off then M.note_off(held) ; M.arp_playing = nil end
    end)
  end
end

-- idem pour un ACCORD (gait CHORD) : coupe anticipee de tout le bloc si gate < 1
local function arp_fire_block(notes, vel)
  M.arp_block = {}
  if M.note_on then
    for _, n in ipairs(notes) do M.note_on(n, vel or 92) ; M.arp_block[#M.arp_block + 1] = n end
  end
  local g = M.arp_gate or 0.8
  if g < 1.0 and M.note_off and clock and clock.run then
    local blk = M.arp_block ; local dur = gate_dur(g)
    clock.run(function()
      clock.sleep(dur)
      if M.arp_block == blk and M.note_off then
        for _, n in ipairs(blk) do M.note_off(n) end ; M.arp_block = nil
      end
    end)
  end
end

-- GATE/sustain reglable par l'utilisateur (page ARP : K2 maintenu + E3)
function M.enc_gate(d)
  M.arp_gate = util.clamp((M.arp_gate or 0.8) + d * 0.05, 0.05, 1.3)
end

local function release()
  if sounding and M.note_off then
    for _, n in ipairs(cur_notes) do M.note_off(n) end
  end
  if M.arp_playing and M.note_off then M.note_off(M.arp_playing) end
  if M.arp_block and M.note_off then
    for _, n in ipairs(M.arp_block) do M.note_off(n) end
  end
  M.arp_playing = nil ; M.arp_block = nil
  cur_notes = {} ; sounding = false ; cur_deg = nil
end
M.release = release

-- GATE pour les accords (NOTE/FOLLOW/AUTO/BLEND) : duree du note_on avant de relacher.
-- g<=0.12 = TRIG (30ms) ; sinon fraction d'un pas d'accord (HARM_RATE) ; plafonne a 2s.
local function chord_gate_dur(g)
  if g <= 0.12 then return 0.03 end
  local beats = (M.HARM_RATE and M.HARM_RATE[M.harm_rate_idx or 2]) or 4
  local tempo = (clock and clock.tempo) or 120
  if not tempo or tempo <= 0 then tempo = 120 end
  return math.min(2.0, beats * 60 / tempo * g)
end

local function play_chord(deg, oct, vel, root, sc)
  local newn = build_chord(deg, oct, root, sc)
  local g = M.arp_gate or 0.8
  if g < 1.0 then
    -- GATE/STAB : coupe l'accord precedent, joue le nouveau EN ENTIER, puis programme
    -- son note_off apres gate -> c'est la RELEASE de TON synthe qui sonne ensuite.
    if sounding and M.note_off then for _, n in ipairs(cur_notes) do M.note_off(n) end end
    if M.note_on then for _, n in ipairs(newn) do M.note_on(n, vel) end end
    cur_notes = newn ; sounding = true ; cur_deg = deg ; M.cur_root = root
    if M.note_off and clock and clock.run then
      local blk = newn ; local dur = chord_gate_dur(g)
      clock.run(function()
        clock.sleep(dur)
        if cur_notes == blk and M.note_off then
          for _, n in ipairs(blk) do M.note_off(n) end
          cur_notes = {} ; sounding = false ; cur_deg = nil
        end
      end)
    end
    return
  end
  -- LEG (gate >= 1) : comportement d'origine (pad tenu, voice leading).
  -- VOICE LEADING : garde les notes communes TENUES (pas de re-declenchement = plus de coupure),
  -- ne coupe que les notes qui partent (avec un leger chevauchement = release plus longue),
  -- ne declenche que les nouvelles notes.
  local newset = {} ; for _, n in ipairs(newn) do newset[n] = true end
  local oldset = {} ; for _, n in ipairs(cur_notes) do oldset[n] = true end
  if sounding and M.note_off then
    for _, n in ipairs(cur_notes) do
      if not newset[n] then
        local off = n
        clock.run(function()
          clock.sleep(M.release_t or 0.28)               -- chevauchement/release : la note sortante tient pour laisser l'ADSR du synthe sonner
          for _, cn in ipairs(cur_notes) do if cn == off then return end end   -- revenue dans l'accord : ne pas couper
          if M.note_off then M.note_off(off) end
        end)
      end
    end
  end
  if M.note_on then
    for _, n in ipairs(newn) do
      if not (sounding and oldset[n]) then M.note_on(n, vel) end   -- seulement les notes vraiment nouvelles
    end
  end
  cur_notes = newn ; sounding = true ; cur_deg = deg ; M.cur_root = root
end

-- adequation de la triade du degre d (dans root, sc) au chroma (memoire harmonique)
local function chord_score(root, sc, d)
  local L = #sc ; local s = 0
  for _, off in ipairs({0, 2, 4}) do
    local idx = ((d - 1 + off) % L) + 1
    s = s + (M.chroma[(root + sc[idx]) % 12] or 0)
  end
  return s
end

-- une source genere une note -> nourrit la memoire harmonique (si ecoutee ; FOLLOW/BLEND)
function M.hear(key, note)
  if type(note) ~= "number" then return end
  if M.hold then return end     -- HOLD : on ignore l'input (NIAKABY garde son accord/arpege)
  if not M.on or M.mode == 1 then return end
  if not key or (M.src and not M.src[key]) then return end   -- SWITCH : la case SRC coupe toute l'influence de cette source
  M.last_heard[key] = note     -- TONALITE : derniere note de la source ECOUTEE (donc coupable via SRC)
  if M.mode == 5 then          -- ARP : construit l'arpege sur la NOTE ENTENDUE (meme chemin fiable que FOLLOW)
    if M.arp_dir == 5 then return end   -- CHORD : avance la progression (comme AUTO), pas pilote par l'input
    local r, sc = key_now()             -- tonalite RESOLUE (AUTO -> suit la source cochee, ex. MGEN)
    local deg, oct = nearest_degree(note, r, sc)
    if deg ~= M.arp_deg or oct ~= M.arp_octd then
      -- On NE COUPE PAS la note en cours : elle FINIT proprement (son gate), puis l'arp
      -- enchaine sur le nouvel accord au pas suivant, depuis la fondamentale (arp_i=1).
      M.arp_notes = build_arp(deg, oct, r, sc)
      M.arp_i = 1
      M.arp_deg = deg ; M.arp_octd = oct
      M.last_root = r + oct * 12 + sc[deg]
    end
    return
  end
  M.chroma[note % 12] = (M.chroma[note % 12] or 0) + 1
  M.heard_new = true           -- nouvelle note d'une source ecoutee -> autorise un changement d'accord
end

-- pas harmonique (appele a chaque mesure par le script principal, cale sur l'horloge)
function M.harmonic_step(vel)
  if not M.on or M.mode == 1 or M.mode == 5 then return end   -- NOTE et ARP : geres par M.update (suivi direct de la note)
  vel = vel or 78
  local root, sc = key_now() ; local L = #sc
  -- energie harmonique reellement entendue cette mesure (FOLLOW/BLEND)
  local tot = 0 ; for i = 0, 11 do tot = tot + (M.chroma[i] or 0) end
  local newd = M.heard_new ; M.heard_new = false   -- une nouvelle note depuis le dernier pas ? (LATCH FOLLOW)
  -- TONALITE INPUT/IMPRO (forcee) : l'accord est bati DIRECTEMENT sur la note jouee (deg 1 = reconnaissable).
  local direct = (M.key_from == 4 or M.key_from == 5)
  -- NB : le mode ARP (5) ne passe PAS par ici -> il suit la note jouee en direct dans M.update (comme NOTE)

  local deg
  local restrike = true                         -- AUTO : re-declenche a chaque mesure (progression rythmee)
  if M.mode == 3 then                          -- AUTO : progression programmee
    local pr = M.progs[M.prog_idx]
    deg = ((pr[prog_pos] - 1) % L) + 1
    prog_pos = (prog_pos % #pr) + 1
  elseif M.mode == 2 then                       -- FOLLOW : accord sur ta note (INPUT/IMPRO) ou deduit (MGEN)
    restrike = false                            -- pad tenu, ne re-declenche QUE si l'accord change
    if direct then
      deg = 1                                    -- accord bati sur TA note (tonique = last_heard)
    elseif (not newd) or tot < 0.3 then
      deg = cur_deg or 1                         -- rien de NOUVEAU entendu : on GARDE le dernier accord joue
    else
      local best, bs = cur_deg or 1, -1
      for d = 1, L do local s = chord_score(root, sc, d) ; if s > bs then bs = s ; best = d end end
      local cs = cur_deg and chord_score(root, sc, cur_deg) or -1
      deg = (not cur_deg or bs > cs * 1.25) and best or cur_deg
    end
  else                                          -- BLEND : trame AUTO, corrigee si l'oreille est nette
    local pr = M.progs[M.prog_idx]
    local auto_deg = ((pr[prog_pos] - 1) % L) + 1
    prog_pos = (prog_pos % #pr) + 1
    if tot < 0.75 then
      deg = auto_deg
    else
      local best, bs = auto_deg, -1
      for d = 1, L do local s = chord_score(root, sc, d) ; if s > bs then bs = s ; best = d end end
      local as = chord_score(root, sc, auto_deg)
      deg = (bs > math.max(as * 1.4, 1.5)) and best or auto_deg
    end
  end
  -- ne re-declenche PAS un accord inchange (pad tenu -> ne casse pas le rythme) ; mais SI la tonique change (INPUT), rejoue
  if restrike or deg ~= cur_deg or root ~= (M.cur_root or -999) or not sounding then
    play_chord(deg, 0, vel, root, sc)
  end
  M.last_root = root + sc[((deg - 1) % L) + 1]
  for i = 0, 11 do M.chroma[i] = (M.chroma[i] or 0) * 0.35 end   -- oubli progressif
end

-- un pas d'arpege (appele par le script principal, cale sur l'horloge au rythme M.arp_rate_idx)
-- joue UNE note a la fois ; la note precedente est coupee au pas suivant (pas de nappe).
function M.arp_tick(vel)
  if not M.on or M.mode ~= 5 then return end
  -- CHORD : joue des ACCORDS (pas note par note), en suivant la progression comme AUTO,
  -- mais re-declenches sur la grille rapide de l'arpege -> "accords par accord".
  if M.arp_dir == 5 then
    if M.arp_block and M.note_off then                       -- coupe l'accord precedent
      for _, n in ipairs(M.arp_block) do M.note_off(n) end
    end
    local root, sc = key_now() ; local L = #sc
    local pr = M.progs[M.prog_idx]
    M.arp_ci = ((M.arp_ci or 0) % #pr) + 1                    -- pas suivant de la progression
    local deg = ((pr[M.arp_ci] - 1) % L) + 1
    local notes = build_chord(deg, 0, root, sc)
    arp_fire_block(notes, vel)                               -- joue l'accord avec le GATE choisi
    M.last_root = root + sc[((deg - 1) % L) + 1]
    return
  end
  if M.arp_block and M.note_off then                         -- sortie de CHORD : nettoie l'accord tenu
    for _, n in ipairs(M.arp_block) do M.note_off(n) end ; M.arp_block = nil
  end
  local notes = M.arp_notes
  if not notes or #notes == 0 then return end
  if M.arp_playing and M.note_off then M.note_off(M.arp_playing) ; M.arp_playing = nil end
  local n   = #notes
  local dir = M.arp_dir or 1
  local idx = (dir == 4) and math.random(n) or math.max(1, math.min(n, M.arp_i or 1))
  local note = notes[idx]
  arp_fire(note, vel)                              -- joue la note avec le GATE choisi (sustain)
  if dir == 1 then                                 -- UP
    M.arp_i = (idx % n) + 1
  elseif dir == 2 then                             -- DOWN
    local ni = idx - 1 ; M.arp_i = (ni < 1) and n or ni
  elseif dir == 3 then                             -- UP-DOWN (rebond)
    if n <= 1 then M.arp_i = 1
    else
      local step = M.arp_bounce or 1 ; local ni = idx + step
      if ni > n then ni = n - 1 ; step = -1 elseif ni < 1 then ni = 2 ; step = 1 end
      M.arp_bounce = step ; M.arp_i = ni
    end
  end
end

-- SEQUENCEUR : appele a chaque pas de grille (clock.sync cote main, = horloge master OP-XY).
-- Lit le pattern : espace = silence, joue = 1 note/accord d'arpege, double/triple = ratchet.
-- Swing : retarde les pas pairs d'une fraction du pas. Ne joue qu'en mode ARP.
function M.seq_step(vel)
  if not M.on or M.mode ~= 5 then return end
  local n = M.seq_len or 16 ; if n < 1 then n = 1 end
  M.seq_i = (M.seq_i % n) + 1
  local v = M.seq_pat[M.seq_i] ; if v == nil then v = 1 end
  if v <= 0 then return end                       -- espace (rest)
  local step = arp_step_sec()
  local function fire()
    M.arp_tick(vel or 96)
    if v >= 2 and clock and clock.run then         -- DOUBLE/TRIPLE : ratchet
      clock.run(function()
        local hits = (v >= 3) and 2 or 1
        local gap  = step / (v >= 3 and 3 or 2)
        for _ = 1, hits do clock.sleep(gap) ; M.arp_tick(vel or 96) end
      end)
    end
  end
  local sw = M.seq_swing or 0
  if sw > 0 and (M.seq_i % 2) == 0 and clock and clock.run then
    clock.run(function() clock.sleep(step * sw) ; fire() end)   -- swing : pas pair en retard
  else
    fire()
  end
end

-- ===== page SEQUENCEUR : edition de la grille =====
function M.seq_enc(n, d, shift)
  if shift then
    if n == 2 then M.seq_len = util.clamp((M.seq_len or 16) + d, 1, 32)
    elseif n == 3 then M.seq_swing = util.clamp((M.seq_swing or 0) + d * 0.02, 0, 0.6) end
    return
  end
  if n == 2 then
    M.seq_cur = util.clamp((M.seq_cur or 1) + d, 1, M.seq_len or 16)
  elseif n == 3 then
    local cur = M.seq_cur or 1
    local v = M.seq_pat[cur] ; if v == nil then v = 1 end
    M.seq_pat[cur] = util.clamp(v + d, 0, 3)
  end
end

function M.seq_key(n, shift)
  if n == 3 then
    M.seq_on = not M.seq_on ; M.seq_i = 0
    if not M.seq_on then release() end
  elseif n == 2 then                               -- K2 : cycle la valeur du pas courant (· -> x -> xx -> xxx)
    local cur = M.seq_cur or 1
    local v = M.seq_pat[cur] ; if v == nil then v = 1 end
    M.seq_pat[cur] = (v + 1) % 4
  end
end

function M.redraw_seq()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(0, 8) ; screen.text("NIAKABY SEQ")
  screen.level(M.seq_on and 13 or 5) ; screen.move(126, 8) ; screen.text_right(M.seq_on and "ON" or "off")
  -- infos : longueur + swing
  screen.level(4) ; screen.move(0, 18) ; screen.text("LEN " .. (M.seq_len or 16))
  screen.level(4) ; screen.move(60, 18) ; screen.text("SWING " .. math.floor((M.seq_swing or 0) * 100) .. "%")
  if M.mode ~= 5 then screen.level(12) ; screen.move(126, 18) ; screen.text_right("mode ARP!") end
  -- grille : 16 pas par rangee, 2 rangees (jusqu'a 32)
  local n = M.seq_len or 16
  local cw = 8
  for i = 1, n do
    local col = (i - 1) % 16 ; local row = math.floor((i - 1) / 16)
    local x = col * cw ; local y = 26 + row * 16
    local v = M.seq_pat[i] ; if v == nil then v = 1 end
    local cur = (i == M.seq_cur) ; local ph = (i == M.seq_i) and M.seq_on
    -- cellule : hauteur selon valeur (rest bas, joue/double/triple + haut)
    if v > 0 then
      local h = 2 + v * 3
      screen.level(ph and 15 or 10) ; screen.rect(x + 1, y + 10 - h, cw - 2, h) ; screen.fill()
    else
      screen.level(3) ; screen.rect(x + 1, y + 8, cw - 2, 2) ; screen.fill()   -- espace : trait bas
    end
    if cur then screen.level(15) ; screen.rect(x, y - 2, cw, 14) ; screen.stroke() end
    if ph and not cur then screen.level(6) ; screen.rect(x, y - 2, cw, 14) ; screen.stroke() end
  end
  screen.level(4) ; screen.move(0, 63) ; screen.text("E2pas E3val K2cyc K3on")
  screen.update()
end

-- mise a jour ~30 Hz avec les features audio (mode NOTE uniquement)
function M.update(rms, freq, centroid, flatness, dt)
  dt = dt or (1/30)
  since = since + dt
  if not M.on then if sounding then release() end ; return end
  if M.hold then return end        -- HOLD : ignore l'input (NOTE garde son accord)
  if M.mode ~= 1 then return end   -- ARP : gere par M.hear (onset) ; FOLLOW/AUTO/BLEND : M.harmonic_step
  local active = (rms or 0) > M.thr and (freq or 0) > 30
  if active then
    sil_t = 0
    local m = freq_to_midi(freq)
    if m then
      local deg, oct = nearest_degree(m)
      M.last_root = M.root + oct * 12 + scale()[deg]
      -- CONFIRMATION anti-saut d'harmonique : les sons forts/aigus accrochent
      -- une harmonique une frame -> le degre saute -> ca re-declenchait et COUPAIT
      -- la note (DSR coupee). On ne change de degre que s'il est confirme 3 frames.
      if deg == pend_deg then pend_cnt = pend_cnt + 1
      else pend_deg, pend_oct, pend_cnt = deg, oct, 1 end
      local same   = (deg == cur_deg)
      local stable = (not sounding) or same or (pend_cnt >= 3)   -- 1re note instant ; changement = ~100ms confirme
      if ((deg ~= cur_deg) or not sounding) and stable and since > 0.08 then
        local vel = math.max(20, math.min(127, math.floor((rms or 0) * 600 + 25)))
        play_chord(deg, pend_oct, vel)
        since = 0
      end
    end
  else
    sil_t = sil_t + dt
    if sounding and sil_t > (M.sil_rel or 0.45) then release() end   -- relache apres un silence (plus long -> pas de coupe sur micro-silence)
  end
end

-- ===== ecran (page NIAKABY) =====
local NOTE_NM = { "C","C#","D","D#","E","F","F#","G","G#","A","A#","B" }
local function note_name(n) return NOTE_NM[(n % 12) + 1] .. tostring(math.floor(n / 12) - 1) end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15); screen.move(2, 8);  screen.text("NIAKABY")
  if M.hold then screen.level(15); screen.move(60, 8); screen.text("[HOLD]") end   -- gel : ignore l'input
  screen.level(M.on and 13 or 5); screen.move(126, 8)
  screen.text_right(M.mode_names[M.mode] .. (M.on and " ON" or " off"))

  if M.mode == 5 then                          -- ARP : direction (ou progression en CHORD) + rythme
    if M.arp_dir == 5 then                     -- CHORD : E2 choisit la PROGRESSION
      screen.level(4);  screen.move(2, 22);  screen.text("E2 PROG")
      screen.level(15); screen.move(126, 22); screen.text_right("CH " .. (M.prog_names[M.prog_idx] or "?"))
    else
      screen.level(4);  screen.move(2, 22);  screen.text("E2 DIR")
      screen.level(15); screen.move(74, 22); screen.text(M.ARP_DIR_NAMES[M.arp_dir])
    end
    screen.level(4);  screen.move(2, 32);  screen.text("E3 VITESSE")
    screen.level(15); screen.move(74, 32); screen.text(M.ARP_RATE_NAMES[M.arp_rate_idx])
  elseif M.mode == 3 or M.mode == 4 then       -- AUTO / BLEND : progression
    screen.level(4);  screen.move(2, 22);  screen.text("E2 PROG")
    screen.level(15); screen.move(56, 22); screen.text(M.prog_names[M.prog_idx])
    screen.level(4);  screen.move(2, 32);  screen.text("E3 VITESSE")
    screen.level(15); screen.move(74, 32); screen.text(M.HARM_RATE_NAMES[M.harm_rate_idx])
  else                                          -- NOTE / FOLLOW : gamme
    screen.level(4);  screen.move(2, 22);  screen.text("E2 GAMME")
    screen.level(15); screen.move(74, 22); screen.text((M.mode == 2) and "MGEN" or M.scale_names[M.scale_idx])
    screen.level(4);  screen.move(2, 32);  screen.text("E3 OCT")
    screen.level(15); screen.move(74, 32); screen.text(string.format("%+d", M.octave))
  end
  -- K2 accord (abrege) + GATE/sustain (K2 maintenu + E3) : affiche dans TOUS les modes
  screen.level(4);  screen.move(2, 42);  screen.text("K2")
  screen.level(15); screen.move(20, 42); screen.text(M.chord_names[M.chord_idx])
  do
    local g = M.arp_gate or 0.8
    screen.level(4);  screen.move(66, 42);  screen.text("GATE")
    screen.level(15); screen.move(126, 42)
    screen.text_right((g <= 0.12) and "TRIG" or ((g >= 1.0) and "LEG" or (math.floor(g * 100) .. "%")))
  end

  -- accord / note courante
  screen.level(4); screen.move(2, 54); screen.text("K1 mode")
  if M.mode == 5 then
    if M.arp_dir == 5 then                       -- CHORD : montre la progression + l'accord courant
      screen.level(15); screen.move(52, 54)
      local pr = M.progs[M.prog_idx]
      screen.text((M.prog_names and M.prog_names[M.prog_idx] or "") ..
        (pr and (" " .. tostring(pr[M.arp_ci or 1] or "")) or ""))
    elseif M.arp_notes and M.arp_notes[1] then
      screen.level(15); screen.move(52, 54)
      screen.text((M.arp_playing and (note_name(M.arp_playing) .. " ") or "") .. "(" .. #M.arp_notes .. ")")
    end
  elseif sounding and cur_notes[1] then
    local s = ""
    for i, n in ipairs(cur_notes) do s = s .. note_name(n) .. " " end
    if #s > 20 then s = string.sub(s, 1, 20) end
    screen.level(15); screen.move(52, 54); screen.text(s)
  end
  local on = {}
  for i, k in ipairs(M.src_keys) do if M.src[k] then on[#on + 1] = M.src_labels[i] end end
  screen.level(8); screen.move(2, 63)
  screen.text("ecoute " .. (#on > 0 and table.concat(on, "+") or "--"))
  screen.update()
end

function M.enc(n, d)
  if n == 2 then
    if M.mode == 5 then
      -- E2 : liste a plat = 4 directions de notes, puis UNE entree CHORD par progression
      -- (UP, DOWN, UP-DN, RAND, CH:prog1, CH:prog2, ...). Scroller au-dela de CHORD
      -- change donc la PROGRESSION (partagee avec AUTO via M.prog_idx).
      local nprog = #M.progs
      local flat  = (M.arp_dir < 5) and M.arp_dir or (4 + (M.prog_idx or 1))
      flat = util.clamp(flat + d, 1, 4 + nprog)
      if flat <= 4 then M.arp_dir = flat
      else M.arp_dir = 5 ; M.prog_idx = flat - 4 end
    elseif M.mode == 3 or M.mode == 4 then
      M.prog_idx = ((M.prog_idx - 1 + d) % #M.progs) + 1          -- AUTO/BLEND : choisit la progression
    else
      M.scale_idx = ((M.scale_idx - 1 + d) % #M.scale_names) + 1
    end
  elseif n == 3 then
    if M.mode == 5 then
      M.arp_rate_idx = util.clamp(M.arp_rate_idx + d, 1, #M.ARP_RATE)       -- ARP : vitesse d'arpege
    elseif M.mode == 3 or M.mode == 4 then
      M.harm_rate_idx = util.clamp(M.harm_rate_idx + d, 1, #M.HARM_RATE)    -- AUTO/BLEND : vitesse d'accord
    else
      M.octave = util.clamp(M.octave + d, -2, 2)
    end
  end
end

function M.key(n)
  if n == 3 then
    M.on = not M.on
    if not M.on then release() end
  elseif n == 2 then
    M.chord_idx = (M.chord_idx % #M.chord_names) + 1
  elseif n == 1 then
    M.mode = (M.mode % #M.mode_names) + 1        -- K1 : cycle NOTE / FOLLOW / AUTO / BLEND
    prog_pos = 1 ; release()
  end
end

-- ===== page SRC : 5 sources independantes (E2 curseur, K3 toggle, K2 tout/rien) =====
function M.enc_src(n, d)
  if n == 2 then
    M.src_cursor = ((M.src_cursor - 1 + d) % #M.src_keys) + 1
  elseif n == 3 then
    M.key_from = ((M.key_from - 1 + d) % #M.KEY_FROM_NAMES) + 1   -- TONALITE : MGEN/NIAKA/INPUT/IMPRO
  end
end

function M.key_src(n)
  if n == 3 then
    local k = M.src_keys[M.src_cursor]
    M.src[k] = not M.src[k]
  elseif n == 2 then
    M.hold = not M.hold     -- K2 : HOLD/GEL = NIAKABY ignore l'input et continue tout seul
  end
end

function M.redraw_src()
  screen.clear() ; screen.font_size(8)
  screen.level(15); screen.move(2, 8); screen.text("NIAKABY SRC")
  screen.move(126, 8); screen.text_right(M.on and "ON" or "off")
  local ys = { 18, 26, 34, 42, 50 }
  for i = 1, #M.src_keys do
    local k   = M.src_keys[i]
    local sel = (i == M.src_cursor)
    screen.level(sel and 15 or (M.src[k] and 10 or 4))
    screen.move(sel and 2 or 10, ys[i])
    screen.text((sel and "> " or "") .. M.src_labels[i])
    screen.level(M.src[k] and 15 or 3)
    screen.move(86, ys[i]); screen.text(M.src[k] and "[X]" or "[ ]")
  end
  -- TONALITE (E3) : d'ou vient la cle (accords/arpege) ; + gamme detectee en INPUT/IMPRO
  screen.level(4);  screen.move(2, 58);  screen.text("E3 TONALITE")
  local kftxt = M.KEY_FROM_NAMES[M.key_from]
  if M.key_from == 4 or M.key_from == 5 then kftxt = kftxt .. " " .. (M.det_scale == "MINOR" and "min" or "MAJ") end
  screen.level(15); screen.move(126, 58); screen.text_right(kftxt)
  screen.level(4);  screen.move(2, 64);  screen.text("E2 sel  K3 src")
  screen.level(M.hold and 15 or 5);  screen.move(126, 64);  screen.text_right("K2 HOLD " .. (M.hold and "ON" or "off"))
  screen.update()
end

return M
