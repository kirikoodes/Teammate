-- lib/style.lua
-- PROFIL DE STYLE : TEAMMATE apprend TA MANIERE DE JOUER (pas seulement ton son)
-- a partir des notes qu'il enregistre, puis biaise la generation du compagnon
-- pour qu'il joue comme toi. 4 axes :
--   * RYTHME / PHRASE  : vitesse (IOI), densite, longueur de phrase, grille vs rubato
--   * ARTICULATION     : legato (notes liees) vs staccato (notes piquees)
--   * MELODIE          : intervalles (pas vs sauts), direction, registre
--   * DYNAMIQUE        : niveau moyen + amplitude
-- Opt-in (M.on / K3 page STYLE). Observation toujours possible ; seul l'effet
-- sur le compagnon est conditionne a M.on.

local M = {}

M.on       = false
M.ioi      = 0.40   -- intervalle moyen entre attaques (s)
M.density  = 0.0    -- 0..1 (densite de jeu)
M.grid     = 0.0    -- 0 rubato .. 1 sur une grille
M.artic    = 0.6    -- 0 staccato .. 1 legato
M.phrase_n = 3      -- longueur de phrase typique (notes)
M.interval = 0.3    -- 0 pas (petits intervalles) .. 1 sauts
M.dir      = 0.0    -- -1 descendant .. +1 montant
M.reg      = 0.5    -- 0 grave .. 1 aigu
M.vel      = 0.5    -- dynamique moyenne 0..1
M.vel_rng  = 0.3    -- amplitude dynamique 0..1

local last_t, last_midi = nil, nil
local ioi_var = 0.1
local ev_in_phrase = 1

local function f2midi(f) return (f and f > 30) and (69 + 12 * math.log(f / 440) / math.log(2)) or nil end
local function lp(cur, x, k) return cur + (x - cur) * k end
local function cu(x) return x < 0 and 0 or (x > 1 and 1 or x) end

-- appele a chaque note enregistree par le joueur
function M.observe(onset_t, dur, rms, freq)
  if last_t then
    local ioi = onset_t - last_t
    if ioi >= 0.05 and ioi <= 2.0 then
      ioi_var   = lp(ioi_var, math.abs(ioi - M.ioi), 0.2)
      M.ioi     = lp(M.ioi, ioi, 0.2)
      M.density = lp(M.density, cu((1 / ioi) / 8), 0.1)
      M.grid    = cu(1 - ioi_var / math.max(M.ioi, 0.1) * 1.5)        -- faible variance -> grille
      M.artic   = lp(M.artic, cu((dur or 0) / math.max(ioi, 0.05)), 0.2)
      if ioi > 0.6 then                                              -- grand trou = fin de phrase
        M.phrase_n   = lp(M.phrase_n, ev_in_phrase, 0.3)
        ev_in_phrase = 1
      else
        ev_in_phrase = ev_in_phrase + 1
      end
    end
  end
  last_t = onset_t

  local m = f2midi(freq)
  if m then
    if last_midi then
      local d = m - last_midi
      M.interval = lp(M.interval, cu(math.abs(d) / 12), 0.2)
      if d ~= 0 then M.dir = lp(M.dir, (d > 0 and 1 or -1), 0.15) end
    end
    M.reg = lp(M.reg, cu((m - 36) / 60), 0.1)
    last_midi = m
  end

  local v = cu((rms or 0) * 4)
  M.vel     = lp(M.vel, v, 0.2)
  M.vel_rng = lp(M.vel_rng, math.abs(v - M.vel), 0.1)
end

-- ===== biais appliques par le compagnon (quand M.on) =====

-- gap entre notes : ton IOI, quantifie a la subdivision si tu joues "sur la grille"
function M.gap(beat)
  local g = M.ioi
  if M.grid > 0.55 then
    local half, quart = beat / 2, beat / 4
    g = (math.abs(g - quart) < math.abs(g - half)) and quart or half
  end
  return math.max(0.03, g)
end

-- longueur de phrase melangee a la tienne
function M.n(default)
  return math.max(1, math.floor((default or 2) * 0.4 + M.phrase_n * 0.6 + 0.5))
end

-- transposition dans ton esprit melodique (pas vs sauts, direction)
function M.rate()
  local up = (math.random() < (0.5 + M.dir * 0.5))
  local semis
  if math.random() < (1 - M.interval) * 0.6 then
    semis = (math.random() < 0.5) and 0 or (up and 2 or -2)          -- mouvements par pas
  else
    semis = (up and 1 or -1) * math.floor(M.interval * 12 + 0.5)     -- sauts
  end
  local r = 2 ^ (semis / 12)
  if r < 0.25 then r = 0.25 elseif r > 4 then r = 4 end
  return r
end

-- velocite MIDI dans ta dynamique
function M.vel_scale(base)
  local v = M.vel + (math.random() * 2 - 1) * M.vel_rng
  return math.max(1, math.min(127, math.floor((base or 100) * (0.5 + cu(v)))))
end

-- longueur de grain selon ton articulation (staccato -> plus court)
function M.artic_len(len)
  return math.max(0.03, len * (0.35 + cu(M.artic) * 0.65))
end

-- ===== page STYLE =====
local function bar(y, label, v)
  screen.level(4)  ; screen.move(2, y) ; screen.text(label)
  screen.level(2)  ; screen.rect(50, y - 5, 74, 4) ; screen.stroke()
  screen.level(13) ; screen.rect(50, y - 5, 74 * cu(v), 4) ; screen.fill()
end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(2, 8) ; screen.text("STYLE")
  screen.level(12) ; screen.move(126, 8)
  screen.text_right(M.grid > 0.55 and "GRILLE" or "RUBATO")
  bar(18, "densite", M.density)
  bar(26, "legato",  M.artic)
  bar(34, "sauts",   M.interval)
  bar(42, "dynamiq", M.vel)
  screen.level(4)  ; screen.move(2, 52)
  screen.text(string.format("phrase %d  %s", math.floor(M.phrase_n + 0.5), M.dir >= 0 and "monte" or "descend"))
  screen.level(M.on and 12 or 3) ; screen.move(2, 63)
  screen.text(M.on and "K3 JOUE COMME TOI" or "K3 joue comme toi")
  screen.update()
end

return M
