-- lib/lora.lua
-- Sonifie l'activite LoRa recue par le norns, via un PONT OSC externe.
-- Le pont (script Python a cote, avec pyserial) lit le module LoRa en USB,
-- dechiffre TES messages (cles cote pont, jamais sur le norns) et envoie :
--   /lora/rx  sender(str)  rssi(int dBm)  snr(float)  len(int)  text(str)
--   /lora/tx  dest(str)    len(int)
-- Ici : ETAT + signature par expediteur + mapping note. Le SON est joue par
-- le script principal (sortie MIDI), qui appelle ces helpers.

local M = {}

M.on          = false     -- opt-in
M.rssi        = -120      -- dBm du dernier message
M.snr         = 0
M.dist        = 1         -- 0 (proche) .. 1 (loin), derive du RSSI -> source MOD
M.energy      = 0         -- 0..1 activite (decroit, bumpee a chaque rx)
M.count       = 0         -- messages recus
M.last_sender = ""
M.last_text   = ""
M.last_len    = 0
M.last_t      = 0
M.tx_t        = 0         -- dernier envoi (pour l'appel-reponse)
M.senders     = {}        -- sender -> { trans, mch, reg, seen }  signature (persistee par le principal)

M.dev  = 1                -- device MIDI de sortie (1..4)
M.ch   = 1                -- canal de base
M.snap = nil              -- callback(midi)->midi (cale sur la gamme MGEN), fourni par le principal

-- RSSI (dBm) -> distance normalisee 0..1  (-40 proche -> 0 ; -120 loin -> 1)
local function rssi_to_dist(rssi)
  local d = (-40 - (rssi or -120)) / 80
  return math.max(0, math.min(1, d))
end

-- cree/retourne la signature d'un expediteur (deterministe a partir du nom)
function M.sig_for(sender)
  sender = sender or ""
  local s = M.senders[sender]
  if not s then
    local h = 0
    for i = 1, #sender do h = (h * 31 + sender:byte(i)) % 100000 end
    s = {
      trans = (h % 12),                              -- transposition 0..11 demi-tons
      mch   = (h % 8) + 1,                           -- canal MIDI propre 1..8
      reg   = 36 + (math.floor(h / 12) % 4) * 12,    -- registre de base (36/48/60/72)
      seen  = 0,
    }
    M.senders[sender] = s
  end
  return s
end

-- octet de payload -> note MIDI calee sur la gamme, dans le registre de l'expediteur
function M.note_for(byte, sig)
  local base = (sig and sig.reg or 48) + (sig and sig.trans or 0)
  local n = base + ((byte or 0) % 24)                -- 2 octaves de plage
  if M.snap then n = M.snap(n) end
  return math.max(0, math.min(127, math.floor(n)))
end

-- appele a chaque message recu (via le principal)
function M.on_rx(sender, rssi, snr, len, text)
  if rssi then M.rssi = rssi end
  if snr  then M.snr  = snr  end
  M.dist        = rssi_to_dist(M.rssi)
  M.last_sender = (sender ~= nil and tostring(sender)) or "?"
  M.last_text   = text or ""
  M.last_len    = len or #M.last_text
  M.last_t      = util.time()
  M.count       = M.count + 1
  M.energy      = 1
  local sig     = M.sig_for(M.last_sender)
  sig.seen      = (sig.seen or 0) + 1
  return sig
end

-- decroissance de l'energie (appele ~30 Hz par le principal)
function M.tick(dt)
  M.energy = math.max(0, M.energy - (dt or 0.03) * 0.4)
end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(2, 8) ; screen.text("LORA")
  screen.level(4)  ; screen.move(72, 8) ; screen.text("D" .. M.dev .. " c" .. M.ch)
  screen.level(M.on and 12 or 3) ; screen.move(126, 8) ; screen.text_right(M.on and "ON" or "off")
  screen.level(6) ; screen.move(2, 21)
  screen.text("from " .. ((M.last_sender == "") and "--" or M.last_sender:sub(1, 12)))
  screen.level(4) ; screen.move(2, 31) ; screen.text("rssi " .. M.rssi .. "dBm")
  -- barre distance (= la source MOD)
  screen.level(4) ; screen.move(2, 43) ; screen.text("dist")
  screen.level(2)  ; screen.rect(34, 38, 80, 4) ; screen.stroke()
  screen.level(11) ; screen.rect(34, 38, 80 * M.dist, 4) ; screen.fill()
  screen.level(4) ; screen.move(2, 53)
  screen.text("rx" .. M.count .. "  msg:" .. ((M.last_text == "") and "-" or M.last_text:sub(1, 11)))
  screen.level(3) ; screen.move(2, 63) ; screen.text("K1 test  K2 dev  K3 on")
  screen.update()
end

return M
