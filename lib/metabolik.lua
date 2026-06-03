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

-- callbacks MIDI (fournis par le script principal)
M.note_on  = nil   -- function(note, vel)
M.note_off = nil   -- function(note)

local feat   = { level=0, bright=0, texture=0, pitchN=0 }
local prevV  = nil
local novAcc = 0

local function clampU(x) if x < 0 then return 0 elseif x > 1 then return 1 else return x end end
local function scale() return M.scales[M.scale_names[M.scale_idx]] end

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

-- joue UNE phrase : notes des voies actives, mono/poly organique
function M.play_phrase()
  local rk = ranked_voices()
  local pool = {}
  for i = 1, math.min(4, #rk) do pool[#pool + 1] = rk[i].b end
  if #pool == 0 then return end
  local pSolo = 0.48 - M.stressFx * 0.28      -- mono/poly non systematique, biaise par le stress
  local size  = (math.random() < pSolo) and 1 or math.min(#pool, 2 + math.random(0, 2))
  local vel   = math.floor(38 + (M.ch.growth * 0.4 + M.stressFx * 0.5) * 55) + math.random(-8, 8)
  if vel < 1 then vel = 1 elseif vel > 127 then vel = 127 end
  local beat  = 60 / M.bpm()
  -- une phrase = 1 a quelques evenements espaces de maniere irreguliere (pas 4/4)
  local events = (math.random() < (0.4 + M.stressFx * 0.4)) and (2 + math.random(0, 2)) or 1
  local subs = { 0.33, 0.5, 0.5, 0.75, 1, 1.5 }
  M.flash = 1
  for e = 1, events do
    for kk = 1, size do
      local b    = pool[(((e + kk) % #pool)) + 1]
      local note = M.bio_note(b)
      local dur  = math.max(0.12, beat * (0.4 + math.random() * 0.4))
      M.note_on(note, vel)
      clock.run(function() clock.sleep(dur); if M.note_off then M.note_off(note) end end)
      if size > 1 then clock.sleep(0.005 + math.random() * 0.012) end   -- leger strum
    end
    if e < events then
      clock.sleep(math.max(0.06, beat * subs[math.random(#subs)] * (0.85 + math.random() * 0.3)))
    end
  end
end

-- ===== boucle : alterne PHRASES et SILENCES (le silence c'est beau) =====
function M.player()
  while true do
    local beat = 60 / M.bpm()
    if M.on and M.note_on and (M.ch.growth or 0) > 0.05 then
      -- jouer ou se taire : calme/sain -> plus de silences ; stress -> joue plus
      local p_play = math.min(0.9, 0.22 + M.stressFx * 0.55 + (M.ch.growth or 0) * 0.15)
      if math.random() < p_play then
        M.play_phrase()
        clock.sleep(math.max(0.1, beat * (0.6 + math.random() * 1.4)))            -- court repos apres la phrase
      else
        local sil = beat * (1.5 + math.random() * 3.0) * (1.4 - M.stressFx)        -- SILENCE : respiration, plus longue si calme
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

  -- voie dominante -> sa note
  local rk = ranked_voices()
  if rk[1] then
    screen.level(15); screen.move(2, 60)
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

-- K3 = ON/OFF du mode METABO
function M.key(n)
  if n == 3 then M.on = not M.on end
end

return M
