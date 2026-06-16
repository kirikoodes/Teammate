-- lib/wifi.lua
-- Capte l'ACTIVITE WIFI autour du norns pour en faire de la musique.
-- Scan des reseaux (nmcli) + debit du trafic (/proc), de maniere NON BLOQUANTE :
-- le scan est lance en arriere-plan (os.execute "... &") et son resultat est lu
-- au tour suivant depuis /tmp -> aucun gel de l'audio.
-- Pour l'instant : CAPTATION + page WIFI (observation). La musique se branche apres.

local M = {}

M.on       = false       -- opt-in (lance des commandes shell)
M.nets     = {}          -- { {sig=0..100, chan=, ssid=}, ... } trie par signal desc
M.count    = 0
M.traffic  = 0           -- 0..1 debit normalise
M.energy   = 0           -- 0..1 activite globale (reseaux + trafic + apparitions)
M.peak     = nil         -- reseau le plus fort
M.newcount = 0           -- nb de reseaux apparus au dernier scan
M.last_new = nil         -- SSID du dernier reseau APPARU (pour l'annonce du visage)
M.last_new_t = 0         -- horodatage de cette apparition

local SCAN_FILE = "/tmp/tm_wifi_scan.txt"
local prev_rx, prev_tx, prev_t = nil, nil, nil
local seen = {}
local primed = false     -- evite de compter tout le 1er scan comme "nouveau"
local scan_pending = false

local function read_file(path)
  local f = io.open(path, "r") ; if not f then return nil end
  local s = f:read("*a") ; f:close() ; return s
end

local function parse_scan(txt)
  local nets = {}
  for line in (txt or ""):gmatch("[^\r\n]+") do
    -- nmcli -t : "SIGNAL:CHAN:SSID"
    local sig, chan, ssid = line:match("^(%d+):(%d+):(.*)$")
    if sig then
      nets[#nets + 1] = { sig = tonumber(sig), chan = tonumber(chan) or 0, ssid = ssid or "" }
    end
  end
  table.sort(nets, function(a, b) return a.sig > b.sig end)
  return nets
end

-- appele ~ toutes les 4 s par le script principal (quand M.on)
function M.poll(now)
  now = now or 0
  -- 1) recupere le resultat du scan lance au tour precedent
  if scan_pending then
    local txt = read_file(SCAN_FILE)
    if txt and #txt > 0 then
      M.nets  = parse_scan(txt)
      M.count = #M.nets
      M.peak  = M.nets[1]
      local nc, cur, firstnew = 0, {}, nil
      for _, n in ipairs(M.nets) do
        cur[n.ssid] = true
        if primed and n.ssid ~= "" and not seen[n.ssid] then
          nc = nc + 1
          if not firstnew then firstnew = n.ssid end   -- le plus fort des nouveaux (nets trie par signal)
        end
      end
      if primed then
        M.newcount = nc
        if firstnew then M.last_new = firstnew ; M.last_new_t = now end
      end
      seen = cur ; primed = true
    end
    scan_pending = false
  end
  -- 2) relance un scan en arriere-plan (non bloquant)
  os.execute("nmcli -t -f SIGNAL,CHAN,SSID dev wifi list > " .. SCAN_FILE .. " 2>/dev/null &")
  scan_pending = true
  -- 3) trafic (lecture instantanee de /proc)
  local rx = tonumber(read_file("/sys/class/net/wlan0/statistics/rx_bytes") or "")
  local tx = tonumber(read_file("/sys/class/net/wlan0/statistics/tx_bytes") or "")
  if rx and tx and prev_rx and prev_t then
    local dt   = math.max(0.5, now - prev_t)
    local rate = ((rx - prev_rx) + (tx - prev_tx)) / dt     -- octets/s
    M.traffic  = math.min(1, math.max(0, rate) / 50000)     -- ~50 ko/s = plein
  end
  prev_rx, prev_tx, prev_t = rx, tx, now
  -- energie globale
  local act = math.min(1, M.count / 12) * 0.4 + M.traffic * 0.5 + math.min(1, M.newcount * 0.5) * 0.3
  M.energy = M.energy + (math.min(1, act) - M.energy) * 0.5
end

-- pitch (note MIDI) d'un reseau : canal -> degre. Mapping musical pilote par le
-- principal (fournit root + scale via M.note_for). Ici un defaut chromatique.
M.root  = 48
M.scale = { 0, 2, 4, 5, 7, 9, 11 }
function M.note_for(n)
  local sc  = M.scale
  local deg = (n.chan or 0) % #sc + 1
  local oct = (n.chan or 0) > 14 and 1 or 0          -- 5 GHz -> une octave au-dessus
  return M.root + oct * 12 + sc[deg]
end

-- frequence (Hz) du reseau le plus fort -> sert de "pitch WiFi" comme source
function M.freq()
  if not M.peak then return 0 end
  local note = M.note_for(M.peak)
  return 440 * 2 ^ ((note - 69) / 12)
end

function M.redraw()
  screen.clear() ; screen.font_size(8)
  screen.level(15) ; screen.move(2, 8)  ; screen.text("WIFI")
  screen.level(M.on and 12 or 3) ; screen.move(40, 8) ; screen.text(M.on and "ON" or "off")
  screen.level(8) ; screen.move(126, 8) ; screen.text_right(M.count .. " res")
  local y = 18
  for i = 1, math.min(4, #M.nets) do
    local n = M.nets[i]
    screen.level(6) ; screen.move(2, y)
    screen.text((((n.ssid == "") and "<cache>") or n.ssid):sub(1, 10))
    screen.level(2)  ; screen.rect(70, y - 5, 54, 4) ; screen.stroke()
    screen.level(13) ; screen.rect(70, y - 5, 54 * ((n.sig or 0) / 100), 4) ; screen.fill()
    y = y + 9
  end
  screen.level(4)  ; screen.move(2, 60) ; screen.text("trafic")
  screen.level(2)  ; screen.rect(44, 55, 80, 4) ; screen.stroke()
  screen.level(11) ; screen.rect(44, 55, 80 * M.traffic, 4) ; screen.fill()
  screen.level(3)  ; screen.move(126, 64) ; screen.text_right("K3 on/off")
  screen.update()
end

return M
