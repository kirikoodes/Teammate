-- ============================================================================
-- tmg_test  —  HARNAIS DE TEST du moteur granulaire (Phase A)
-- ----------------------------------------------------------------------------
-- Script Norns SEPARE (ne touche pas a TEAMMATE.POTO). Sert a valider :
--   1. l'enregistrement du corpus dans le Buffer SC (corpus_rec / corpus_rec_stop)
--   2. le nuage granulaire (cloud) qui relit le buffer
--   3. le curseur pondere (les slots proches jouent plus fort)
--
-- Installation Norns : dossier dust/code/tmg_test/ avec :
--   tmg_test.lua  +  lib/Engine_TeammateGranular.sc
--
-- Jeu :
--   K2 (maintenu) = enregistre le slot courant (fais du son pendant ce temps),
--                   relache = grain capture, passe au slot suivant.
--   K3            = lance / arrete le NUAGE.
--   E2            = deplace le curseur le long des 8 slots (quels grains jouent).
--   E3            = densite du nuage.
--   E1            = duree de grain.
-- ============================================================================

engine.name = "Atlas"

local NSRC     = 8
local cursor   = 0.5
local density  = 40
local grainDur = 0.12
local recslot  = 0
local recording = false
local cloud_on  = false
local recorded  = {}   -- [slot 0..7] = true si enregistre

-- ----- MANETTE (HID) -----
local pad
local last_hid = "-"   -- dernier evenement brut (debug : pour voir les codes de TA manette)

local function positions()
  local p = {}
  for i = 0, NSRC - 1 do p[i + 1] = i * 2.0 + 0.10 end   -- centre approx du slot i (secondes)
  return p
end

local function gains()
  local g = {}
  for i = 0, NSRC - 1 do
    local sx = (NSRC > 1) and (i / (NSRC - 1)) or 0      -- position 0..1 du slot
    local w  = math.max(0, 1 - math.abs(sx - cursor) * 4) -- falloff autour du curseur
    if not recorded[i] then w = 0 end                     -- slot vide = muet
    g[i + 1] = w
  end
  return g
end

local function send_cloud()
  local p, g = positions(), gains()
  engine.cloud(0, 0.5, density, grainDur, 1.0,
    p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8],
    g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8])
end

-- MANETTE : dernier evenement brut affiche (debug) ; stick gauche X -> curseur
local function hid_event(typ, code, value)
  last_hid = "t" .. typ .. " c" .. code .. " v" .. value
  if typ == 3 and code == 0 then                          -- EV_ABS, ABS_X (a ajuster selon la manette)
    cursor = util.clamp((value + 32768) / 65535, 0, 1)    -- suppose signe 16 bits
    if cloud_on then send_cloud() end
  end
  redraw()
end

function key(n, z)
  if n == 2 then
    if z == 1 then
      engine.corpus_rec(recslot) ; recording = true
    else
      engine.corpus_rec_stop() ; recording = false
      recorded[recslot] = true ; recslot = (recslot + 1) % NSRC
    end
  elseif n == 3 and z == 1 then
    cloud_on = not cloud_on
    if cloud_on then send_cloud() else engine.cloud_free(0) end
  end
  redraw()
end

function enc(n, d)
  if     n == 2 then cursor   = util.clamp(cursor + d * 0.02, 0, 1)
  elseif n == 3 then density  = util.clamp(density + d, 5, 200)
  elseif n == 1 then grainDur = util.clamp(grainDur + d * 0.01, 0.02, 0.5) end
  if cloud_on then send_cloud() end
  redraw()
end

function redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(2, 8) ; screen.text("ATLAS")
  screen.level(recording and 15 or 5) ; screen.move(2, 19)
  screen.text("K2 REC slot " .. recslot .. (recording and "  *REC*" or ""))
  screen.level(cloud_on and 12 or 5) ; screen.move(2, 29)
  screen.text("K3 nuage " .. (cloud_on and "ON" or "off") .. "   gDur " .. string.format("%.2f", grainDur))
  -- les 8 slots + le curseur
  for i = 0, NSRC - 1 do
    local x = 8 + i * 14
    screen.level(recorded[i] and 12 or 3)
    screen.rect(x, 40, 8, 8)
    if recorded[i] then screen.fill() else screen.stroke() end
  end
  local cx = 8 + cursor * (NSRC - 1) * 14 + 4
  screen.level(15) ; screen.move(cx, 37) ; screen.line(cx, 53) ; screen.stroke()
  screen.level(4) ; screen.move(2, 57) ; screen.text("E2/stick curseur  E3 dens " .. density)
  screen.level(6) ; screen.move(2, 63) ; screen.text("HID " .. (pad and "OK" or "--") .. "  " .. last_hid)
  screen.update()
end

function init()
  pcall(function() pad = hid.connect(1) ; pad.event = hid_event end)   -- manette sur le vport HID 1
  redraw()
end
