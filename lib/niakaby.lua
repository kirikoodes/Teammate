-- lib/niakaby.lua
-- NIAKABY — harmoniseur : prend le PITCH du son entrant et le sort en ACCORDS MIDI.
-- Detecte la note jouee, la cale dans la gamme, construit l'accord diatonique de ce degre
-- (maj/min/dim automatiques) + basse. Sort via la matrice de routage (stream 7).
-- Option LINK : METABO colore les accords (tensions sous stress, doublures si croissance)
-- et NIAKABY nourrit METABO en retour.

local M = {}

M.scale_names = {"MAJOR","MINOR","DORIC","PHRYG","HIJAZ","PENMIN","PENMAJ","HIRA","INSEN"}
M.scales = {
  MAJOR = {0,2,4,5,7,9,11}, MINOR = {0,2,3,5,7,8,10}, DORIC = {0,2,3,5,7,9,10},
  PHRYG = {0,1,3,5,7,8,10}, HIJAZ = {0,1,4,5,7,8,11},
  PENMIN = {0,3,5,7,10}, PENMAJ = {0,2,4,7,9}, HIRA = {0,2,3,7,8}, INSEN = {0,1,5,7,10},
}
M.scale_idx = 1     -- MAJOR par defaut
M.root      = 48    -- C3
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
M.link = false      -- lien avec METABO
M.thr  = 0.01       -- seuil de detection du pitch entrant

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
M.last_root     = nil    -- pour affichage

local function scale() return M.scales[M.scale_names[M.scale_idx]] end

local function freq_to_midi(f)
  if not f or f < 30 then return nil end
  return math.floor(69 + 12 * math.log(f / 440) / math.log(2) + 0.5)
end

-- degre de gamme + octave le plus proche d'une note MIDI
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

-- construit l'accord (notes MIDI) pour un degre, avec couleur METABO si link
local function build_chord(deg, oct)
  local sc = scale() ; local L = #sc
  local shape = M.CHORD_STEPS[M.chord_names[M.chord_idx]]
  local notes = {}
  local function add_step(st)
    local d   = (deg - 1) + st
    local o   = math.floor(d / L)
    local idx = (d % L) + 1
    local n   = M.root + (M.octave + oct + o) * 12 + sc[idx]
    while n < 24  do n = n + 12 end
    while n > 100 do n = n - 12 end
    notes[#notes + 1] = n
  end
  for _, st in ipairs(shape) do add_step(st) end
  -- basse a l'octave grave (fondamentale)
  local bass = M.root + (M.octave + oct - 1) * 12 + sc[((deg - 1) % L) + 1]
  while bass < 24 do bass = bass + 12 end
  notes[#notes + 1] = bass
  -- couleur METABO
  if M.link and M.metabo and M.metabo.on then
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

local function play_chord(deg, oct, vel)
  if sounding and M.note_off then
    for _, n in ipairs(cur_notes) do M.note_off(n) end
  end
  cur_notes = build_chord(deg, oct)
  if M.note_on then
    for _, n in ipairs(cur_notes) do M.note_on(n, vel) end
  end
  sounding = true ; cur_deg = deg
end

-- mise a jour ~30 Hz avec les features audio
function M.update(rms, freq, centroid, flatness, dt)
  dt = dt or (1/30)
  since = since + dt
  if not M.on then if sounding then release() end ; return end
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
        if M.link and M.feed then M.feed(rms, freq, centroid, flatness) end
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
  screen.move(126, 8); screen.text_right(M.on and "ON" or "off")

  screen.level(4);  screen.move(2, 22);  screen.text("E2 GAMME")
  screen.level(15); screen.move(74, 22); screen.text(M.scale_names[M.scale_idx])
  screen.level(4);  screen.move(2, 32);  screen.text("E3 OCT")
  screen.level(15); screen.move(74, 32); screen.text(string.format("%+d", M.octave))
  screen.level(4);  screen.move(2, 42);  screen.text("K2 ACCORD")
  screen.level(15); screen.move(74, 42); screen.text(M.chord_names[M.chord_idx])

  -- accord courant
  screen.level(4); screen.move(2, 54); screen.text("in:")
  screen.level(8); screen.move(22, 54)
  screen.text(M.last_root and note_name(M.last_root) or "--")
  if sounding and cur_notes[1] then
    local s = ""
    for i, n in ipairs(cur_notes) do s = s .. note_name(n) .. " " end
    if #s > 22 then s = string.sub(s, 1, 21) end
    screen.level(15); screen.move(58, 54); screen.text(s)
  end
  screen.level(M.link and 13 or 3); screen.move(2, 63)
  screen.text("LINK " .. (M.link and "METABO" or "off"))
  screen.update()
end

function M.enc(n, d)
  if n == 2 then
    M.scale_idx = ((M.scale_idx - 1 + d) % #M.scale_names) + 1
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
  end
end

return M
