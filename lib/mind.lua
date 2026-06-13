-- lib/mind.lua
-- Couche d'ECOUTE PARTAGEE de TEAMMATE.
-- Transforme les features audio instantanees (rms/freq/centroide/gate) en une
-- IMAGE MUSICALE DANS LE TEMPS : enveloppe d'energie, montee/chute, densite de
-- jeu, tension lente (arc), registre, etat de phrase (parle / respire / silence)
-- et une "humeur" lisible.
--
-- Pour l'instant : OBSERVATION PURE. Aucun effet sur le son. Le but est de
-- donner une conscience commune que les autres modules pourront consulter plus
-- tard (un seul "musicien" au lieu de plusieurs reacteurs en parallele), et de
-- RENDRE VISIBLE ce que TEAMMATE entend (page MIND).

local M = {}

M.energy    = 0     -- enveloppe rapide (0..1)
M.energy_sl = 0     -- enveloppe lente (contexte, 0..1)
M.build     = 0     -- -1 (chute) .. +1 (montee)
M.density   = 0     -- evenements de jeu / fenetre (0..1)
M.tension   = 0     -- arc lent (0..1) : monte vite, redescend lentement
M.bright    = 0     -- brillance (centroide normalise, 0..1)
M.register  = 0     -- grave 0 .. aigu 1
M.phrase    = "--"  -- SPEAKING / GAP / QUIET
M.phrase_len= 0     -- duree de la phrase en cours (s)
M.gap_len   = 0     -- duree du silence en cours (s)
M.mood      = "--"  -- humeur lisible

local spk     = false
local onset_t = {}  -- horodatages recents (pour la densite)

local function clampU(x) return x < 0 and 0 or (x > 1 and 1 or x) end

-- now = horloge en secondes (util.time), fournie par l'appelant
function M.update(rms, freq, centroid, flatness, gate, dt, now)
  dt  = dt or (1/30)
  now = now or 0
  local lvl = clampU((rms or 0) * 6)

  -- enveloppes : rapide (geste) et lente (contexte)
  M.energy    = M.energy    + (lvl - M.energy) * 0.25
  M.energy_sl = M.energy_sl + (M.energy - M.energy_sl) * 0.02
  M.build     = math.max(-1, math.min(1, (M.energy - M.energy_sl) * 4))

  -- timbre / registre
  M.bright = clampU((centroid or 0) / 5000)
  if freq and freq > 30 then
    local midi = 69 + 12 * math.log(freq / 440) / math.log(2)
    M.register = clampU((midi - 36) / 60)   -- ~C2..C7
  end

  -- densite : fronts montants de jeu sur une fenetre de 2 s
  local speaking = (gate or 0) > 0.5 or M.energy > 0.08
  if speaking and not spk then onset_t[#onset_t + 1] = now end
  spk = speaking
  while onset_t[1] and (now - onset_t[1]) > 2.0 do table.remove(onset_t, 1) end
  M.density = clampU(#onset_t / 8)

  -- machine de phrase : parle -> respire (court silence apres une phrase) -> silence
  if speaking then
    M.phrase = "SPEAKING" ; M.phrase_len = M.phrase_len + dt ; M.gap_len = 0
  else
    M.gap_len = M.gap_len + dt
    if M.phrase_len > 0.15 and M.gap_len < 0.6 then
      M.phrase = "GAP"
    else
      M.phrase = "QUIET" ; M.phrase_len = 0
    end
  end

  -- tension : pousse avec densite + montee + brillance ; redescend lentement
  local push = clampU(M.density * 0.5 + math.max(0, M.build) * 0.3 + M.bright * 0.2)
  M.tension = M.tension + (push - M.tension) * (push > M.tension and 0.05 or 0.012)

  -- humeur lisible (resume de l'intention d'ecoute)
  if M.energy < 0.05 then        M.mood = "ECOUTE"
  elseif M.phrase == "GAP" then  M.mood = "REPONDRE"
  elseif M.build > 0.4 then      M.mood = "MONTE AVEC TOI"
  elseif M.build < -0.4 then     M.mood = "REDESCEND"
  elseif M.density > 0.6 then    M.mood = "DENSE"
  else                           M.mood = "AVEC TOI"
  end
end

-- une fenetre d'opportunite pour repondre : juste apres ta phrase, dans le trou
function M.answer_window()
  return M.phrase == "GAP"
end

-- ===== page MIND : ce que TEAMMATE entend =====
local function bar(y, label, v)
  screen.level(4)  ; screen.move(2, y) ; screen.text(label)
  screen.level(2)  ; screen.rect(46, y - 5, 78, 4) ; screen.stroke()
  screen.level(13) ; screen.rect(46, y - 5, 78 * clampU(v), 4) ; screen.fill()
end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(2, 8) ; screen.text("MIND")
  screen.level(12) ; screen.move(126, 8) ; screen.text_right(M.mood)
  bar(20, "energie", M.energy)
  bar(29, "montee",  (M.build + 1) / 2)
  bar(38, "densite", M.density)
  bar(47, "tension", M.tension)
  screen.level(4)  ; screen.move(2, 60)  ; screen.text("phrase")
  screen.level(10) ; screen.move(46, 60) ; screen.text(M.phrase .. string.format("  %.1fs", M.phrase_len))
  screen.update()
end

return M
