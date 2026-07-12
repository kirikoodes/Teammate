-- lib/bt.lua
-- Sonifie la PRESENCE Bluetooth/BLE autour de toi, via un PONT OSC externe.
-- Le pont (tools/bt_bridge.py, en USB serie depuis le M5StickC Plus 2 sous
-- ESP32 Bus Pirate) lit le scan BT et envoie au norns :
--   /sniff/bt  mac(str)  name(str)  rssi(int dBm)
-- Ici : ETAT + signature par appareil + mapping note. Le SON est joue par le
-- script principal (sortie MIDI), qui appelle ces helpers. Meme philosophie
-- que lib/lora.lua : un appareil = "un personnage" musical reconnaissable.

local M = {}

M.on        = false     -- opt-in
M.rssi      = -120      -- dBm du dernier appareil vu
M.dist      = 1         -- 0 (proche) .. 1 (loin), derive du RSSI -> source MOD
M.energy    = 0         -- 0..1 activite (decroit, bumpee a chaque detection)
M.count     = 0         -- detections totales
M.last_mac  = ""
M.last_name = ""
M.last_t    = 0
M.devices   = {}        -- mac -> { trans, mch, reg, seen, first_t }  signature

M.dev  = 1              -- device MIDI de sortie (1..4)
M.ch   = 1              -- canal de base
M.snap = nil            -- callback(midi)->midi (cale sur la gamme MGEN), fourni par le principal

-- RSSI (dBm) -> distance normalisee 0..1  (-40 proche -> 0 ; -120 loin -> 1)
local function rssi_to_dist(rssi)
  local d = (-40 - (rssi or -120)) / 80
  return math.max(0, math.min(1, d))
end

-- cree/retourne la signature d'un appareil (deterministe a partir de la MAC)
function M.sig_for(mac)
  mac = mac or ""
  local s = M.devices[mac]
  if not s then
    local h = 0
    for i = 1, #mac do h = (h * 31 + mac:byte(i)) % 100000 end
    s = {
      trans   = (h % 12),                              -- transposition 0..11 demi-tons
      mch     = (h % 8) + 1,                           -- canal MIDI propre 1..8
      reg     = 36 + (math.floor(h / 12) % 4) * 12,    -- registre de base (36/48/60/72)
      seen    = 0,
      first_t = util.time(),
    }
    M.devices[mac] = s
  end
  return s
end

-- nombre d'appareils distincts vus
function M.known()
  local n = 0
  for _ in pairs(M.devices) do n = n + 1 end
  return n
end

-- octet (issu de la MAC) -> note MIDI calee sur la gamme, dans le registre du device
function M.note_for(byte, sig)
  local base = (sig and sig.reg or 48) + (sig and sig.trans or 0)
  local n = base + ((byte or 0) % 24)                  -- 2 octaves de plage
  if M.snap then n = M.snap(n) end
  return math.max(0, math.min(127, math.floor(n)))
end

-- appele a chaque appareil detecte (via le principal). Retourne (sig, is_new).
function M.on_rx(mac, name, rssi)
  if rssi then M.rssi = rssi end
  M.dist     = rssi_to_dist(M.rssi)
  M.last_mac  = (mac ~= nil and tostring(mac)) or "?"
  M.last_name = (name ~= nil and tostring(name)) or ""
  M.last_t    = util.time()
  M.count     = M.count + 1
  M.energy    = 1
  local is_new = (M.devices[M.last_mac] == nil)
  local sig    = M.sig_for(M.last_mac)
  sig.seen     = (sig.seen or 0) + 1
  return sig, is_new
end

-- decroissance de l'energie (appele ~30 Hz par le principal)
function M.tick(dt)
  M.energy = math.max(0, M.energy - (dt or 0.03) * 0.4)
end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(2, 8) ; screen.text("BT")
  screen.level(4)  ; screen.move(72, 8) ; screen.text("D" .. M.dev .. " c" .. M.ch)
  screen.level(M.on and 12 or 3) ; screen.move(126, 8) ; screen.text_right(M.on and "ON" or "off")
  screen.level(6) ; screen.move(2, 21)
  local who = (M.last_name ~= "" and M.last_name) or M.last_mac
  screen.text("seen " .. ((who == "") and "--" or who:sub(1, 14)))
  screen.level(4) ; screen.move(2, 31) ; screen.text("rssi " .. M.rssi .. "dBm")
  -- barre distance (= la source MOD)
  screen.level(4) ; screen.move(2, 43) ; screen.text("dist")
  screen.level(2)  ; screen.rect(34, 38, 80, 4) ; screen.stroke()
  screen.level(11) ; screen.rect(34, 38, 80 * M.dist, 4) ; screen.fill()
  screen.level(4) ; screen.move(2, 53)
  screen.text("hits" .. M.count .. "  devices:" .. M.known())
  screen.level(3) ; screen.move(2, 63) ; screen.text("K1 test  K2 dev  K3 on")
  screen.update()
end

return M
