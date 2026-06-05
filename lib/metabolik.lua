-- lib/metabolik.lua
-- AVATAR METABOLIK — mode "METABO" pour TEAMMATE norns (couche autonome).
-- Le son entrant nourrit une cellule (metabolisme) ; la cellule repond en
-- notes MIDI : les NOTES = les voies metaboliques actives.
-- Jeu varie/riche = sain ; monotone/repetitif = stress -> tempo qui s'emballe.
-- Ne touche pas au compagnon TEAMMATE : voix MIDI dediee sur son propre canal.

local M = {}

-- ===== gammes (degres en demi-tons depuis la fondamentale) =====
M.scale_names = {"PENMIN","PENMAJ","MINOR","HIRA","INSEN","HIJAZ","PHRYG","DORIC","MAJOR"}
M.scales = {
  PENMIN = {0,3,5,7,10},  PENMAJ = {0,2,4,7,9},   MINOR = {0,2,3,5,7,8,10},
  HIRA   = {0,2,3,7,8},   INSEN  = {0,1,5,7,10},  HIJAZ = {0,1,4,5,7,8,11},
  PHRYG  = {0,1,3,5,7,8,10}, DORIC = {0,2,3,5,7,9,10}, MAJOR = {0,2,4,5,7,9,11},
}
M.scale_idx = 1
M.root      = 48     -- C3
M.octave    = 0      -- -2..+2 (choisi a l'encodeur)
M.midi_ch   = 16     -- canal MIDI de la voix metabolique

-- ===== chaque voie metabolique -> UNE note fixe (degre + octave) : fidele =====
M.BIO = {
  { ch = "growth",       deg = 1, oct = 0 },
  { ch = "glycolysis",   deg = 2, oct = 0 },
  { ch = "respiration",  deg = 3, oct = 0 },
  { ch = "fermentation", deg = 4, oct = 0 },
  { ch = "byproduct",    deg = 5, oct = 0 },
  { ch = "co2",          deg = 1, oct = 1 },
  { ch = "lactate",      deg = 2, oct = 1 },
}

-- ===== etat =====
M.on       = false
M.ch       = { growth=0, glycolysis=0, respiration=0, fermentation=0, byproduct=0, co2=0, lactate=0 }
M.stress   = 0
M.stressFx = 0
M.stress_min = 0
M.stress_max = 1
M.flash    = 0
M.state    = "—"

-- densite globale (reglee a K2) + memoire de motif (patterns qui reviennent puis mutent)
M.density_names = {"SPARSE","FLOW","DENSE"}
M.density_idx   = 2
M.motif     = nil
M.rhythm    = nil
M.motif_age = 0

-- suivi du son entrant : joue dans le meme registre + echo de ta note (recalee dans la gamme)
M.follow   = true     -- suit la hauteur du son joue
M.in_note  = nil      -- note MIDI live de l'entree (nil si pas de pitch)
M.center   = 60       -- centre tonal lisse (suit doucement l'entree)

-- callbacks MIDI (fournis par le script principal)
M.note_on  = nil   -- function(note, vel)
M.note_off = nil   -- function(note)

local feat   = { level=0, bright=0, texture=0, pitchN=0 }
local prevV  = nil
local novAcc = 0

local function clampU(x) if x < 0 then return 0 elseif x > 1 then return 1 else return x end end
local function scale() return M.scales[M.scale_names[M.scale_idx]] end

-- recale une note MIDI sur la note la plus proche de la gamme courante (rootee sur M.root)
local function snap_to_scale(note)
  local sc = scale() ; local L = #sc
  local best, bestd = note, 999
  for o = -4, 5 do
    for i = 1, L do
      local cand = M.root + o * 12 + sc[i]
      local d = math.abs(cand - note)
      if d < bestd then bestd = d ; best = cand end
    end
  end
  return best
end

function M.bio_note(b)
  local sc = scale()
  local L  = #sc
  local deg = ((b.deg - 1) % L) + 1
  local n = M.root + (M.octave + b.oct) * 12 + sc[deg]
  if n < 24 then n = 24 elseif n > 96 then n = 96 end
  return n
end

-- ===== mise a jour ~30 Hz (appelee par le script principal avec les features audio) =====
function M.update(rms, freq, centroid, flatness, dt)
  dt = dt or (1/30)
  local level   = math.min(1, (rms or 0) * 8)
  local bright  = math.min(1, (centroid or 0) / 4000)
  local texture = math.min(1, flatness or 0)
  local pitchN  = 0
  if (freq or 0) > 30 then
    pitchN = math.log(freq / 55) / math.log(3000 / 55)
    if pitchN < 0 then pitchN = 0 elseif pitchN > 1 then pitchN = 1 end
  end
  local k = 0.3
  feat.level   = feat.level   + (level   - feat.level)   * k
  feat.bright  = feat.bright  + (bright  - feat.bright)  * k
  feat.texture = feat.texture + (texture - feat.texture) * k
  feat.pitchN  = feat.pitchN  + (pitchN  - feat.pitchN)  * k

  -- metabolisme (demo)
  local glc, o2, am, lip = feat.level, feat.bright, feat.pitchN, feat.texture
  local c = M.ch
  c.glycolysis   = clampU(glc)
  c.respiration  = clampU(math.min(glc, o2) * (0.4 + 0.6 * o2))
  c.fermentation = clampU(glc * (1 - o2))
  c.co2          = c.respiration
  c.lactate      = c.fermentation
  c.byproduct    = clampU(am * 0.7 + lip * 0.3)
  c.growth       = clampU(c.respiration * 0.55 + am * 0.4 + lip * 0.3 + glc * 0.15)

  -- diversite / monotonie -> stress (monotone = stress, varie = calme ; regulation)
  local v = { feat.level, feat.bright, feat.texture, feat.pitchN }
  if prevV then
    local d = 0
    for i = 1, 4 do d = d + math.abs(v[i] - prevV[i]) end
    novAcc = novAcc * math.exp(-dt / 0.7) + d / 4
  end
  prevV = v
  local novelty   = math.min(1, novAcc * 5.5)
  local active    = feat.level > 0.04
  local monotony  = active and (1 - clampU(novelty)) or 0
  local imbalance = math.abs(c.fermentation - c.respiration)
  local perturb   = clampU(monotony * 0.6 + imbalance * 0.3 + (1 - c.growth) * 0.2)
  local rate = (perturb > M.stress) and 2.4 or 0.45
  M.stress   = M.stress + (perturb - M.stress) * math.min(1, dt * rate)
  M.stressFx = M.stress_min + M.stress * (M.stress_max - M.stress_min)

  -- suivi du pitch entrant : note live + centre tonal lisse (pour jouer "proche" du son)
  if (freq or 0) > 30 and feat.level > 0.03 then
    local n = math.floor(69 + 12 * math.log(freq / 440) / math.log(2) + 0.5)
    if n >= 12 and n <= 108 then
      M.in_note = n
      M.center  = M.center + (n - M.center) * math.min(1, dt * 4)
    end
  else
    M.in_note = nil
  end

  if M.flash > 0 then M.flash = math.max(0, M.flash - dt * 3) end
  M.state = (M.stressFx > 0.66 and "MONOTONE") or (M.stressFx > 0.33 and "PERTURBE") or "STABLE"
end

function M.bpm() return 60 + M.stressFx * 120 end

local function ranked_voices()
  local t = {}
  for _, b in ipairs(M.BIO) do t[#t + 1] = { b = b, v = M.ch[b.ch] or 0 } end
  table.sort(t, function(a, c) return a.v > c.v end)
  return t
end

-- ===== motifs : cellules melodiques & rythmiques (patterns reconnaissables qui evoluent) =====
local function new_motif()
  -- contour melodique : offsets de degres (marche conjointe + petits sauts)
  local n   = 3 + math.random(0, 4)
  local m   = { 0 }
  local dir = (math.random() < 0.5) and 1 or -1
  for i = 2, n do
    local r, step = math.random()
    if     r < 0.55 then step = dir
    elseif r < 0.80 then step = dir * 2
    elseif r < 0.92 then step = -dir
    else                 step = dir * 3 end
    m[i] = m[i - 1] + step
    if math.random() < 0.28 then dir = -dir end
  end
  return m
end

local RHYTHM_CELLS = {
  {1, 1, 1, 1},
  {0.5, 0.5, 1, 1},
  {0.75, 0.25, 1},
  {0.5, 0.5, 0.5, 0.5},
  {1, 0.5, 0.5, 1},
  {0.25, 0.25, 0.5, 1},
  {1.5, 0.5, 1},
  {0.5, 0, 0.5, 1},            -- repos interne (le silence aussi dans le pattern)
  {0.33, 0.33, 0.34, 1},       -- triolet
  {0.25, 0.25, 0.25, 0.25, 1},
}
local function new_rhythm() return RHYTHM_CELLS[math.random(#RHYTHM_CELLS)] end

-- joue UNE phrase : accord / arpege / melodie / ostinato bati sur les voies actives
function M.play_phrase()
  local rk   = ranked_voices()
  local pool = {}
  for i = 1, math.min(6, #rk) do
    if (rk[i].v or 0) > 0.02 then pool[#pool + 1] = rk[i].b end
  end
  if #pool == 0 then pool = { (rk[1] and rk[1].b) or M.BIO[1] } end

  -- (re)genere le motif/rythme courant -> des patterns reviennent puis mutent
  M.motif_age = M.motif_age + 1
  if (not M.motif) or (not M.rhythm) or M.motif_age > (3 + math.random(0, 3)) or math.random() < 0.15 then
    M.motif = new_motif() ; M.rhythm = new_rhythm() ; M.motif_age = 0
  end

  local sc   = scale() ; local L = #sc
  local beat = 60 / M.bpm()
  local dens = M.density_idx                       -- 1 sparse / 2 flow / 3 dense
  local densMul = (dens == 1) and 0.6 or (dens == 3 and 1.7 or 1.0)
  local nbase = 2 + math.floor((M.stressFx * 3 + (M.ch.growth or 0) * 2) * densMul + 0.5)
  nbase = math.max(1, math.min(12, nbase))
  M.flash = 1

  -- suivi du son entrant : transpose le registre vers le pitch joue (octaves entieres,
  -- la gamme reste intacte) + note-echo de l'entree recalee dans la gamme
  local follow_oct = 0
  if M.follow and M.center then
    follow_oct = math.max(-2, math.min(3, math.floor((M.center - M.root) / 12 + 0.5)))
  end
  local in_n = (M.follow and M.in_note) and snap_to_scale(M.in_note) or nil

  -- note depuis une voie + offset de degre dans la gamme (gere les octaves + suivi)
  local function deg_note(b, off)
    local d   = ((b.deg - 1) % L) + (off or 0)
    local oct = math.floor(d / L)
    local deg = (d % L) + 1
    local n   = M.root + (M.octave + b.oct + oct + follow_oct) * 12 + sc[deg]
    while n < 24 do n = n + 12 end
    while n > 96 do n = n - 12 end
    return n
  end
  local function vel_at(i)
    local v = math.floor(40 + ((M.ch.growth or 0) * 0.35 + M.stressFx * 0.5) * 60)
            + ((i == 1) and 18 or 0) + math.random(-6, 6)
    return math.max(1, math.min(127, v))
  end
  local function hit(notes, vel, dur)
    for _, nn in ipairs(notes) do
      M.note_on(nn, vel)
      clock.run(function() clock.sleep(dur) ; if M.note_off then M.note_off(nn) end end)
    end
  end

  -- type de phrase, biaise par le stress (calme -> plus d'accords/melodie posee)
  local r, kind = math.random()
  if     r < 0.28 then kind = "chord"
  elseif r < 0.60 then kind = "arp"
  elseif r < 0.85 then kind = "melody"
  else                 kind = "ostinato" end

  if kind == "chord" then
    -- empile des voies actives + parfois une note de tete melodique
    local size  = math.min(#pool, 2 + math.random(0, (dens == 3) and 3 or 2))
    local notes = {}
    for k = 1, size do notes[#notes + 1] = M.bio_note(pool[k]) end
    if in_n and math.random() < 0.6 then notes[#notes + 1] = in_n end          -- echo de ta note
    if math.random() < 0.5 then notes[#notes + 1] = deg_note(pool[1], M.motif[#M.motif] or 2) end
    local reps = 1 + ((dens == 3) and math.random(0, 2) or 0)
    for _ = 1, reps do
      hit(notes, vel_at(1), math.max(0.18, beat * (0.6 + math.random() * 0.6)))
      clock.sleep(math.max(0.12, beat * (0.8 + math.random() * 0.8)))
    end

  elseif kind == "arp" then
    -- arpege les voies du pool selon un contour (up / down / up-down)
    local order = {}
    for k = 1, #pool do order[k] = k end
    local mode = math.random(3)
    if mode == 2 then
      for k = 1, math.floor(#order / 2) do order[k], order[#order - k + 1] = order[#order - k + 1], order[k] end
    elseif mode == 3 and #pool > 1 then
      for k = #pool - 1, 2, -1 do order[#order + 1] = k end
    end
    local steps = math.max(2, math.min(nbase, #order * 2))
    local gaps  = { 0.25, 0.33, 0.5, 0.5, 1 }
    local gap   = beat * gaps[math.random(#gaps)]
    for i = 1, steps do
      local b   = pool[order[((i - 1) % #order) + 1]]
      local off = (math.random() < 0.30) and (M.motif[((i - 1) % #M.motif) + 1]) or 0
      local nn  = (in_n and i == 1 and math.random() < 0.5) and in_n or deg_note(b, off)
      hit({ nn }, vel_at(i), math.max(0.06, gap * 0.9))
      clock.sleep(math.max(0.05, gap))
    end

  elseif kind == "melody" then
    -- ligne melodique : contour de motif + cellule rythmique (avec repos internes)
    local rh    = M.rhythm
    local steps = math.max(3, math.min(nbase + #M.motif, 12))
    for i = 1, steps do
      local cell = rh[((i - 1) % #rh) + 1]
      if cell > 0 then
        local off = M.motif[((i - 1) % #M.motif) + 1]
        local b   = pool[((i - 1) % #pool) + 1]
        local nn  = (in_n and math.random() < 0.3) and in_n or deg_note(b, off)   -- echo occasionnel
        hit({ nn }, vel_at(i), math.max(0.06, beat * cell * 0.85))
      end
      clock.sleep(math.max(0.05, beat * (cell > 0 and cell or 0.5)))
    end

  else  -- ostinato : repete une cellule melodico-rythmique qui mute legerement
    local rh   = M.rhythm
    local reps = 2 + ((dens == 3) and math.random(1, 2) or math.random(0, 1))
    for rep = 1, reps do
      for i = 1, #rh do
        local cell = rh[i]
        if cell > 0 then
          local off = M.motif[((i - 1) % #M.motif) + 1]
          if rep > 1 and math.random() < 0.2 then off = off + (math.random() < 0.5 and 1 or -1) end
          local b = pool[((i - 1) % #pool) + 1]
          hit({ deg_note(b, off) }, vel_at(i), math.max(0.06, beat * cell * 0.8))
        end
        clock.sleep(math.max(0.05, beat * (cell > 0 and cell or 0.4)))
      end
    end
  end
end

-- ===== boucle : alterne PHRASES et SILENCES (le silence c'est beau) =====
function M.player()
  while true do
    local beat = 60 / M.bpm()
    if M.on and M.note_on and (M.ch.growth or 0) > 0.05 then
      -- jouer ou se taire : calme/sain -> plus de silences ; stress -> joue plus
      local dmul   = (M.density_idx == 1) and 0.7 or (M.density_idx == 3 and 1.3 or 1.0)
      local p_play = math.min(0.93, (0.22 + M.stressFx * 0.5 + (M.ch.growth or 0) * 0.15) * dmul)
      if math.random() < p_play then
        M.play_phrase()
        local rest = beat * (0.4 + math.random() * 1.2) * (M.density_idx == 3 and 0.7 or 1.0)
        clock.sleep(math.max(0.08, rest))                                          -- court repos apres la phrase
      else
        -- SILENCE : respiration, plus longue si calme / sparse (le silence c'est beau)
        local sil = beat * (1.3 + math.random() * 3.0) * (1.4 - M.stressFx) * (M.density_idx == 1 and 1.3 or 1.0)
        clock.sleep(math.max(0.4, sil))
      end
    else
      clock.sleep(0.3)   -- off / pas d'entree : on ecoute en silence (miroir)
    end
  end
end

-- ===== ecran (page METABO) =====
local NOTE_NM = { "C","C#","D","D#","E","F","F#","G","G#","A","A#","B" }
local function note_name(n) return NOTE_NM[(n % 12) + 1] .. tostring(math.floor(n / 12) - 1) end

function M.redraw()
  screen.clear()
  screen.font_size(8)
  screen.level(15); screen.move(2, 8);   screen.text("METABO")
  screen.move(126, 8); screen.text_right(M.on and "ON" or "off")
  if M.follow and M.in_note then           -- note entrante suivie (echo)
    screen.level(6); screen.move(56, 8); screen.text("in " .. note_name(M.in_note))
  end

  -- cellule : cercle qui pulse avec la croissance
  local cx, cy = 98, 36
  local r = 5 + M.ch.growth * 13 + M.flash * 3
  screen.level(M.flash > 0.2 and 15 or (3 + math.floor(M.ch.growth * 9)))
  screen.circle(cx, cy, r); screen.stroke()
  -- voies = points autour, brillance selon activite
  local ang = 0
  for _, b in ipairs(M.BIO) do
    local vv = M.ch[b.ch] or 0
    local px = cx + math.cos(ang) * (r + 4)
    local py = cy + math.sin(ang) * (r + 4)
    screen.level(2 + math.floor(vv * 13))
    screen.rect(px - 1, py - 1, 2, 2); screen.fill()
    ang = ang + math.pi * 2 / #M.BIO
  end

  -- stress + bpm + etat
  screen.level(8); screen.move(2, 22); screen.text("STRESS")
  screen.level(4); screen.rect(2, 25, 52, 4); screen.stroke()
  screen.level(M.stressFx > 0.5 and 15 or 10); screen.rect(2, 25, 52 * M.stressFx, 4); screen.fill()
  screen.level(12); screen.move(2, 40); screen.text("BPM " .. math.floor(M.bpm()))
  screen.move(2, 49); screen.text(M.state)
  screen.level(8); screen.move(46, 49); screen.text("K2 " .. M.density_names[M.density_idx])

  -- reglages encodeurs : retour visuel E2 gamme / E3 octave
  screen.level(10); screen.move(2, 57)
  screen.text(string.format("E2 %s  o%+d", M.scale_names[M.scale_idx], M.octave))

  -- voie dominante -> sa note
  local rk = ranked_voices()
  if rk[1] then
    screen.level(15); screen.move(2, 64)
    screen.text(string.upper(string.sub(rk[1].b.ch, 1, 5)) .. " " .. note_name(M.bio_note(rk[1].b)))
  end
  screen.update()
end

-- E2 = gamme, E3 = octave
function M.enc(n, d)
  if n == 2 then
    M.scale_idx = ((M.scale_idx - 1 + d) % #M.scale_names) + 1
  elseif n == 3 then
    M.octave = util.clamp(M.octave + d, -2, 2)
  end
end

-- K3 = ON/OFF du mode METABO ; K2 = densite (SPARSE / FLOW / DENSE)
function M.key(n)
  if n == 3 then
    M.on = not M.on
  elseif n == 2 then
    M.density_idx = (M.density_idx % #M.density_names) + 1
  end
end

return M
