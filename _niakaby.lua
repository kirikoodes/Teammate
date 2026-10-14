-- lib/niakaby.lua
-- NIAKABY — harmoniseur + PROGRESSION D'ACCORDS. 4 modes (K1) :
--   NOTE   : harmonise en direct la note entendue (comportement d'origine).
--   FOLLOW : DEDUIT l'accord de ce qu'il entend (memoire harmonique/chroma), cale sur la gamme MGEN,
--            change a chaque mesure. Nourri par toutes les sources activees (INPUT/METABO/COMP/MGEN/SNOT).
--   AUTO   : joue une PROGRESSION programmee (presets), calee sur l'horloge (1 accord/mesure).
--   BLEND  : trame AUTO, corrigee par ce qu'il entend quand l'oreille est nette.
-- Accords TRIAD/7e/9e/sus + basse, couleur METABO. Sort via la matrice (stream 7).

local M = {}

M.scale_names = {"MAJOR","MINOR","DORIC","PHRYG","HIJAZ","PENMIN","PENMAJ","HIRA","INSEN"}
M.scales = {
  MAJOR = {0,2,4,5,7,9,11}, MINOR = {0,2,3,5,7,8,10}, DORIC = {0,2,3,5,7,9,10},
  PHRYG = {0,1,3,5,7,8,10}, HIJAZ = {0,1,4,5,7,8,11},
  PENMIN = {0,3,5,7,10}, PENMAJ = {0,2,4,7,9}, HIRA = {0,2,3,7,8}, INSEN = {0,1,5,7,10},
}
M.scale_idx = 1     -- MAJOR par defaut (utilise en mode NOTE ; FOLLOW/AUTO/BLEND suivent MGEN)
M.root      = 48    -- C3 (mode NOTE ; sinon tonique MGEN)
M.octave    = 0     -- -2..+2

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
M.ARP_DIR_NAMES  = { "UP", "DOWN", "UP-DN", "RAND" }
M.ARP_RATE_NAMES = { "1/2", "1/4", "1/8", "1/8T", "1/16", "1/16T", "1/32" }   -- vitesse : lent -> rapide
M.ARP_RATE       = { 2, 1, 0.5, 1/3, 0.25, 1/6, 0.125 }   -- en beats (clock.sync cote script principal)
M.arp_dir        = 1
M.arp_rate_idx   = 3      -- 1/8 par defaut
M.arp_oct        = 2
M.arp_notes      = nil
M.arp_i          = 1
M.arp_bounce     = 1
M.arp_playing    = nil

-- memoire harmonique (classes de hauteur 0..11) : nourrie par ce que NIAKABY entend
M.chroma = {} ; for _i = 0, 11 do M.chroma[_i] = 0 end
M.mgen_key = nil    -- function() return root, scale_table end : cale FOLLOW/AUTO/BLEND sur la gamme+tonique de MGEN
-- TONALITE : d'ou vient la tonique (FOLLOW/AUTO/BLEND/ARP). MGEN, la gamme propre NIAKA, ton INPUT, ou l'IMPRO.
M.KEY_FROM_NAMES = { "MGEN", "NIAKA", "INPUT", "IMPRO" }
M.key_from       = 1     -- 1=MGEN (defaut)
M.last_heard     = {}    -- derniere note entendue par source (pour TONALITE INPUT/IMPRO)
M.det_scale      = "MAJOR"   -- gamme detectee (MAJEUR/MINEUR) pour INPUT/IMPRO, avec hysteresis

-- progressions (AUTO/BLEND) : suites de degres (1 = tonique de la gamme MGEN)
M.progs      = { {1,5,6,4}, {1,6,4,5}, {1,4,5,5}, {6,4,1,5}, {2,5,1,1}, {1,3,4,5}, {1,1,4,5} }
M.prog_names = { "I-V-vi-IV", "I-vi-IV-V", "I-IV-V", "vi-IV-I-V", "ii-V-I", "I-iii-IV-V", "I-IV-V" }
M.prog_idx   = 1

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

local function key_now()
  local kf = M.key_from or 1
  if kf == 1 and M.mgen_key then                      -- MGEN : gamme + tonique de MGEN
    local r, sc = M.mgen_key()
    if r and type(sc) == "table" and #sc > 0 then return r, sc end
  elseif kf == 3 or kf == 4 then                      -- INPUT / IMPRO : tonique + MAJ/MIN detectes de la source
    local ln = M.last_heard[(kf == 3) and "input" or "comp"]
    if ln then
      local root = M.root + ((ln - M.root) % 12)       -- classe de hauteur entendue, ramenee en registre
      return root, detect_scale(root % 12)             -- gamme majeur/mineur detectee
    end
  end
  return M.root, scale()                              -- NIAKA (ou fallback) : gamme + tonique propres
end

local function freq_to_midi(f)
  if not f or f < 30 then return nil end
  return math.floor(69 + 12 * math.log(f / 440) / math.log(2) + 0.5)
end

-- degre de gamme + octave le plus proche d'une note MIDI (mode NOTE)
local function nearest_degree(note)
  local sc = scale() ; local L = #sc
  local best, bestd, bestoct = 1, 999, 0
  for o = -3, 4 do
    for i = 1, L do
      local cand = M.root + o * 12 + sc[i]
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
    local n   = root + (M.octave + oct + o) * 12 + sc[idx]
    while n < 24  do n = n + 12 end
    while n > 100 do n = n - 12 end
    notes[#notes + 1] = n
  end
  for _, st in ipairs(shape) do add_step(st) end
  -- basse a l'octave grave (fondamentale)
  local bass = root + (M.octave + oct - 1) * 12 + sc[((deg - 1) % L) + 1]
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

-- liste de notes de l'arpege : l'accord deploye sur arp_oct octaves, trie ascendant (dedupe)
local function build_arp(deg, root, sc)
  local L = #sc
  local shape = M.CHORD_STEPS[M.chord_names[M.chord_idx]]
  local seen, notes = {}, {}
  for o = 0, (M.arp_oct or 2) - 1 do
    for _, st in ipairs(shape) do
      local d   = (deg - 1) + st
      local idx = (d % L) + 1
      local oo  = math.floor(d / L) + o
      local n   = root + (M.octave + oo) * 12 + sc[idx]
      while n < 24 do n = n + 12 end ; while n > 100 do n = n - 12 end
      if not seen[n] then seen[n] = true ; notes[#notes + 1] = n end
    end
  end
  table.sort(notes)
  return notes
end

local function release()
  if sounding and M.note_off then
    for _, n in ipairs(cur_notes) do M.note_off(n) end
  end
  if M.arp_playing and M.note_off then M.note_off(M.arp_playing) end
  M.arp_playing = nil
  cur_notes = {} ; sounding = false ; cur_deg = nil
end
M.release = release

local function play_chord(deg, oct, vel, root, sc)
  if sounding and M.note_off then
    for _, n in ipairs(cur_notes) do M.note_off(n) end
  end
  cur_notes = build_chord(deg, oct, root, sc)
  if M.note_on then
    for _, n in ipairs(cur_notes) do M.note_on(n, vel) end
  end
  sounding = true ; cur_deg = deg
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
  if key then M.last_heard[key] = note end     -- TONALITE : garde la derniere note de chaque source
  if not M.on or M.mode == 1 then return end
  if not key or (M.src and not M.src[key]) then return end
  M.chroma[note % 12] = (M.chroma[note % 12] or 0) + 1
end

-- pas harmonique (appele a chaque mesure par le script principal, cale sur l'horloge)
function M.harmonic_step(vel)
  if not M.on or M.mode == 1 then return end   -- NOTE : gere par M.update
  vel = vel or 78
  local root, sc = key_now() ; local L = #sc
  -- energie harmonique reellement entendue cette mesure (FOLLOW/BLEND)
  local tot = 0 ; for i = 0, 11 do tot = tot + (M.chroma[i] or 0) end

  if M.mode == 5 then                            -- ARP : deduit l'accord (comme FOLLOW) puis l'ARPEGE (pas de nappe)
    if sounding then release() end               -- jamais d'accord tenu en ARP
    local deg
    if tot < 0.75 then deg = cur_deg or 1
    else
      local best, bs = cur_deg or 1, -1
      for d = 1, L do local s = chord_score(root, sc, d) ; if s > bs then bs = s ; best = d end end
      local cs = cur_deg and chord_score(root, sc, cur_deg) or -1
      deg = (not cur_deg or bs > cs * 1.25) and best or cur_deg
    end
    if deg ~= cur_deg or not M.arp_notes then
      M.arp_notes = build_arp(deg, root, sc) ; M.arp_i = 1 ; M.arp_bounce = 1
    end
    cur_deg = deg
    M.last_root = root + sc[((deg - 1) % L) + 1]
    for i = 0, 11 do M.chroma[i] = (M.chroma[i] or 0) * 0.35 end
    return
  end

  local deg
  local restrike = true                         -- AUTO : re-declenche a chaque mesure (progression rythmee)
  if M.mode == 3 then                          -- AUTO : progression programmee
    local pr = M.progs[M.prog_idx]
    deg = ((pr[prog_pos] - 1) % L) + 1
    prog_pos = (prog_pos % #pr) + 1
  elseif M.mode == 2 then                       -- FOLLOW : deduit du chroma (hysteresis)
    restrike = false                            -- FOLLOW : pad tenu, ne re-declenche QUE si l'accord change
    if tot < 0.75 then
      deg = cur_deg or 1                         -- rien d'audible : on TIENT l'accord (pas de saut arbitraire)
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
  -- ne re-declenche PAS un accord inchange (pad tenu -> ne casse pas le rythme)
  if restrike or deg ~= cur_deg or not sounding then
    play_chord(deg, 0, vel, root, sc)
  end
  M.last_root = root + sc[((deg - 1) % L) + 1]
  for i = 0, 11 do M.chroma[i] = (M.chroma[i] or 0) * 0.35 end   -- oubli progressif
end

-- un pas d'arpege (appele par le script principal, cale sur l'horloge au rythme M.arp_rate_idx)
-- joue UNE note a la fois ; la note precedente est coupee au pas suivant (pas de nappe).
function M.arp_tick(vel)
  if not M.on or M.mode ~= 5 then return end
  local notes = M.arp_notes
  if not notes or #notes == 0 then return end
  if M.arp_playing and M.note_off then M.note_off(M.arp_playing) ; M.arp_playing = nil end
  local n   = #notes
  local dir = M.arp_dir or 1
  local idx = (dir == 4) and math.random(n) or math.max(1, math.min(n, M.arp_i or 1))
  local note = notes[idx]
  if M.note_on then M.note_on(note, vel or 92) end
  M.arp_playing = note
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

-- mise a jour ~30 Hz avec les features audio (mode NOTE uniquement)
function M.update(rms, freq, centroid, flatness, dt)
  dt = dt or (1/30)
  since = since + dt
  if not M.on then if sounding then release() end ; return end
  if M.mode ~= 1 then return end   -- FOLLOW/AUTO/BLEND : gere par M.harmonic_step
  local active = (rms or 0) > M.thr and (freq or 0) > 30
  if active then
    sil_t = 0
    local m = freq_to_midi(freq)
    if m then
      local deg, oct = nearest_degree(m)
      M.last_root = M.root + oct * 12 + scale()[deg]
      if (deg ~= cur_deg or not sounding) and since > 0.08 then   -- debounce anti-flutter
        local vel = math.max(20, math.min(127, math.floor((rms or 0) * 600 + 25)))
        play_chord(deg, oct, vel)
        since = 0
      end
    end
  else
    sil_t = sil_t + dt
    if sounding and sil_t > 0.18 then release() end   -- relache apres un court silence
  end
end

-- ===== ecran (page NIAKABY) =====
local NOTE_NM = { "C","C#","D","D#","E","F","F#","G","G#","A","A#","B" }
local function note_name(n) return NOTE_NM[(n % 12) + 1] .. tostring(math.floor(n / 12) - 1) end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15); screen.move(2, 8);  screen.text("NIAKABY")
  screen.level(M.on and 13 or 5); screen.move(126, 8)
  screen.text_right(M.mode_names[M.mode] .. (M.on and " ON" or " off"))

  if M.mode == 5 then                          -- ARP : direction + rythme
    screen.level(4);  screen.move(2, 22);  screen.text("E2 DIR")
    screen.level(15); screen.move(74, 22); screen.text(M.ARP_DIR_NAMES[M.arp_dir])
    screen.level(4);  screen.move(2, 32);  screen.text("E3 VITESSE")
    screen.level(15); screen.move(74, 32); screen.text(M.ARP_RATE_NAMES[M.arp_rate_idx])
  elseif M.mode == 3 or M.mode == 4 then       -- AUTO / BLEND : progression
    screen.level(4);  screen.move(2, 22);  screen.text("E2 PROG")
    screen.level(15); screen.move(56, 22); screen.text(M.prog_names[M.prog_idx])
    screen.level(4);  screen.move(2, 32);  screen.text("E3 OCT")
    screen.level(15); screen.move(74, 32); screen.text(string.format("%+d", M.octave))
  else                                          -- NOTE / FOLLOW : gamme
    screen.level(4);  screen.move(2, 22);  screen.text("E2 GAMME")
    screen.level(15); screen.move(74, 22); screen.text((M.mode == 2) and "MGEN" or M.scale_names[M.scale_idx])
    screen.level(4);  screen.move(2, 32);  screen.text("E3 OCT")
    screen.level(15); screen.move(74, 32); screen.text(string.format("%+d", M.octave))
  end
  screen.level(4);  screen.move(2, 42);  screen.text("K2 ACCORD")
  screen.level(15); screen.move(74, 42); screen.text(M.chord_names[M.chord_idx])

  -- accord / note courante
  screen.level(4); screen.move(2, 54); screen.text("K1 mode")
  if M.mode == 5 then
    if M.arp_notes and M.arp_notes[1] then
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
      M.arp_dir = util.clamp(M.arp_dir + d, 1, #M.ARP_DIR_NAMES)   -- ARP : direction
    elseif M.mode == 3 or M.mode == 4 then
      M.prog_idx = ((M.prog_idx - 1 + d) % #M.progs) + 1          -- AUTO/BLEND : choisit la progression
    else
      M.scale_idx = ((M.scale_idx - 1 + d) % #M.scale_names) + 1
    end
  elseif n == 3 then
    if M.mode == 5 then
      M.arp_rate_idx = util.clamp(M.arp_rate_idx + d, 1, #M.ARP_RATE)   -- ARP : rythme
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
    local all = true
    for _, k in ipairs(M.src_keys) do if not M.src[k] then all = false end end
    for _, k in ipairs(M.src_keys) do M.src[k] = not all end
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
  if M.key_from == 3 or M.key_from == 4 then kftxt = kftxt .. " " .. (M.det_scale == "MINOR" and "min" or "MAJ") end
  screen.level(15); screen.move(126, 58); screen.text_right(kftxt)
  screen.level(4);  screen.move(2, 64);  screen.text("E2 sel  K3 on  K2 all")
  screen.update()
end

return M
