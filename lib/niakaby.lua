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
M.mode_names = { "NOTE", "FOLLOW", "AUTO", "BLEND" }
M.mode = 2          -- FOLLOW par defaut

-- memoire harmonique (classes de hauteur 0..11) : nourrie par ce que NIAKABY entend
M.chroma = {} ; for _i = 0, 11 do M.chroma[_i] = 0 end
M.mgen_key = nil    -- function() return root, scale_table end : cale FOLLOW/AUTO/BLEND sur la gamme+tonique de MGEN

-- progressions (AUTO/BLEND) : suites de degres (1 = tonique de la gamme MGEN)
M.progs      = { {1,5,6,4}, {1,6,4,5}, {1,4,5,5}, {6,4,1,5}, {2,5,1,1}, {1,3,4,5}, {1,1,4,5} }
M.prog_names = { "I-V-vi-IV", "I-vi-IV-V", "I-IV-V", "vi-IV-I-V", "ii-V-I", "I-iii-IV-V", "I-IV-V" }
M.prog_idx   = 1

-- ce que NIAKABY ecoute (combinable) -> harmonisation (NOTE) et memoire harmonique (FOLLOW/BLEND)
M.src        = { input = true, metabo = false, comp = false, mgen = false, snot = false }
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
local function key_now()
  if M.mgen_key then
    local r, sc = M.mgen_key()
    if r and type(sc) == "table" and #sc > 0 then return r, sc end
  end
  return M.root, scale()
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

local function release()
  if sounding and M.note_off then
    for _, n in ipairs(cur_notes) do M.note_off(n) end
  end
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
  if not M.on or M.mode == 1 then return end
  if not key or (M.src and not M.src[key]) then return end
  if type(note) ~= "number" then return end
  M.chroma[note % 12] = (M.chroma[note % 12] or 0) + 1
end

-- pas harmonique (appele a chaque mesure par le script principal, cale sur l'horloge)
function M.harmonic_step(vel)
  if not M.on or M.mode == 1 then return end   -- NOTE : gere par M.update
  vel = vel or 78
  local root, sc = key_now() ; local L = #sc
  local deg
  if M.mode == 3 then                          -- AUTO : progression programmee
    local pr = M.progs[M.prog_idx]
    deg = ((pr[prog_pos] - 1) % L) + 1
    prog_pos = (prog_pos % #pr) + 1
  elseif M.mode == 2 then                       -- FOLLOW : deduit du chroma (hysteresis)
    local best, bs = cur_deg or 1, -1
    for d = 1, L do local s = chord_score(root, sc, d) ; if s > bs then bs = s ; best = d end end
    local cs = cur_deg and chord_score(root, sc, cur_deg) or -1
    deg = (not cur_deg or bs > cs * 1.25) and best or cur_deg
  else                                          -- BLEND : trame AUTO, corrigee si l'oreille est nette
    local pr = M.progs[M.prog_idx]
    local auto_deg = ((pr[prog_pos] - 1) % L) + 1
    prog_pos = (prog_pos % #pr) + 1
    local best, bs = auto_deg, -1
    for d = 1, L do local s = chord_score(root, sc, d) ; if s > bs then bs = s ; best = d end end
    local as = chord_score(root, sc, auto_deg)
    deg = (bs > math.max(as * 1.4, 1.5)) and best or auto_deg
  end
  play_chord(deg, 0, vel, root, sc)
  M.last_root = root + sc[((deg - 1) % L) + 1]
  for i = 0, 11 do M.chroma[i] = (M.chroma[i] or 0) * 0.35 end   -- oubli progressif
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

  if M.mode == 3 or M.mode == 4 then           -- AUTO / BLEND : progression
    screen.level(4);  screen.move(2, 22);  screen.text("E2 PROG")
    screen.level(15); screen.move(56, 22); screen.text(M.prog_names[M.prog_idx])
  else                                          -- NOTE / FOLLOW : gamme
    screen.level(4);  screen.move(2, 22);  screen.text("E2 GAMME")
    screen.level(15); screen.move(74, 22); screen.text((M.mode == 2) and "MGEN" or M.scale_names[M.scale_idx])
  end
  screen.level(4);  screen.move(2, 32);  screen.text("E3 OCT")
  screen.level(15); screen.move(74, 32); screen.text(string.format("%+d", M.octave))
  screen.level(4);  screen.move(2, 42);  screen.text("K2 ACCORD")
  screen.level(15); screen.move(74, 42); screen.text(M.chord_names[M.chord_idx])

  -- accord courant
  screen.level(4); screen.move(2, 54); screen.text("K1 mode")
  if sounding and cur_notes[1] then
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
    if M.mode == 3 or M.mode == 4 then
      M.prog_idx = ((M.prog_idx - 1 + d) % #M.progs) + 1     -- AUTO/BLEND : choisit la progression
    else
      M.scale_idx = ((M.scale_idx - 1 + d) % #M.scale_names) + 1
    end
  elseif n == 3 then
    M.octave = util.clamp(M.octave + d, -2, 2)
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
  if n == 2 or n == 3 then
    M.src_cursor = ((M.src_cursor - 1 + d) % #M.src_keys) + 1
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
  local ys = { 20, 29, 38, 47, 56 }
  for i = 1, #M.src_keys do
    local k   = M.src_keys[i]
    local sel = (i == M.src_cursor)
    screen.level(sel and 15 or (M.src[k] and 10 or 4))
    screen.move(sel and 2 or 10, ys[i])
    screen.text((sel and "> " or "") .. M.src_labels[i])
    screen.level(M.src[k] and 15 or 3)
    screen.move(86, ys[i]); screen.text(M.src[k] and "[X]" or "[ ]")
  end
  screen.level(4); screen.move(2, 63); screen.text("E2 sel  K3 on/off  K2 all")
  screen.update()
end

return M
