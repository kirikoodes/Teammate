-- teammate.lua — NSDOS 2026
-- Norns port of TEAMMATE.POTO (Python)

engine.name = "Teammate"

---------------------------------------------------------------------
-- layout Softcut  (350s buffer total)
-- V1    : enregistrement corpus
-- V2    : lecture corpus
-- V3    : lecture corpus / REPULSED (POtO) / CONTRAST (8OS)
-- V4    : capture POtO continue / capture 8OS (exclusif)
-- V5    : POtO LEAD / 8OS LOCK (exclusif)
-- V6    : POtO ATTRACTED / 8OS ECHO (exclusif)
--
-- Buffer: 0..96s corpus | 100..104s POtO | 200..220s 8OS
---------------------------------------------------------------------
local CORPUS_SLOTS  = 48
local CORPUS_DUR    = 2.0
local CORPUS_OFFSET = 0.0
local POTO_OFFSET   = 100.0
local POTO_DUR      = 4.0

local REC_V      = 1
local PLY_V      = {2, 3}   -- V3 emprunte au REPULSED grain quand POtO ON
local POTO_REC_V = 4
local POTO_PLY_V = {5, 6}

---------------------------------------------------------------------
-- parametres (cales sur les defauts Python)
---------------------------------------------------------------------
local MIN_DUR    = 0.06
local MAX_DUR    = 1.2
local MIN_CORPUS = 4
local MIN_DELAY  = 0.15
local MAX_DELAY  = 0.70
local PHRASE_MIN = 2
local PHRASE_MAX = 6
local SLICE_PROB = 0.25
local REV_PROB   = 0.05
local SLICE_MIN  = 0.20
local SLICE_MAX  = 0.80

local page       = 1       -- page UI courante (1-9)

---------------------------------------------------------------------
-- etat
---------------------------------------------------------------------
local state       = "LISTEN"
local corpus      = {}
local head        = 1
local count       = 0
local last_slot   = 0

local phrase_buf      = {}
local phrase_analysis = nil
local recent_slots    = {}
local RECENT_MAX      = 4
local INTERRUPT_PROB  = 0.12
local p_sil_min  = 0.8   -- silence min avant sceller fragment (0.2-3.0s)
local p_sil_max  = 1.5   -- silence min avant initiative (0.5-8.0s)

local GATE_HOLD_N = 6
local p_gate_thr  = 0.003   -- seuil de gate (reglable page 6 E3)
local gate_hold   = 0

local rec_on      = false
local rec_slot    = 0
local rec_t0      = 0
local rms_sum     = 0
local rms_n       = 0

local cur_rms      = 0
local cur_freq     = 0
local cur_centroid = 0
local cur_flatness = 0
local cur_gate     = 0
local last_rms     = 0
local last_freq    = 0
local last_centroid= 0
local last_flatness= 0

local consec_sil  = 0
local last_strat  = "---"
local strat_name  = "---"
local sil_sec     = 0.0
local last_sound_t= 0.0

local p_density   = 0.55
local p_sil_bias  = 0.14
local p_contrast  = 0.5
local p_reply     = 0.75
local p_rec_prob  = 1.0   -- taux d'apprentissage (0=gele, 1=tout enregistre)
local p_voice     = false  -- mode voix : syllabes min 120ms, pas de transposition
local p_deaf      = false  -- mode sourd : ignore l'entree, impro autonome
local p_poto_on     = false
local p_poto_vol    = 0.5
local p_poto_rate   = 1.0    -- vitesse lecture grain (0.5-2.0)
local p_poto_spread = 0.05   -- ecart detune entre voix (0.0-0.30)
local p_poto_size   = 0.15   -- taille grain en secondes (0.05-0.40)
local p_monitor     = 1.0

-- 8OS : sampler grain avec matching pitch/timbre temps reel
-- mutually exclusive avec POtO (memes voix V3,V4,V5,V6)
local OS8_OFFSET  = 200.0   -- zone buffer (apres corpus 96s et POtO 104s)
local OS8_DUR     = 20.0    -- 20s de buffer
local OS8_MAX     = 64      -- grains max
local os8_mode    = "OFF"   -- OFF / REC / TRANS
local os8_bank    = {}      -- {pos, dur, pitch, centroid, note}
local os8_rec_n   = 0
local os8_start_t = 0.0
local os8_onset_p = 0.0
local os8_rec_on  = false
local os8_vol     = 0.7
local os8_size    = 0.15    -- taille grain lecture (s)
local os8_pitch_acc = 0 ; local os8_pitch_n = 0
local os8_ctr_acc   = 0 ; local os8_ctr_n   = 0
local os8_rms_acc   = 0 ; local os8_rms_n   = 0
local os8_pos_v5  = nil    -- position du grain joue par chaque voix
local os8_pos_v6  = nil
local os8_pos_v3  = nil

local splash_active = false

-- MIDI output (3 streams independants)
local midi_out_impro = nil ; local midi_dev_impro = 1
local midi_out_poto  = nil ; local midi_dev_poto  = 1
local midi_out_8os   = nil ; local midi_dev_8os   = 1
local midi_impro_on = false
local midi_impro_ch = 1
local midi_poto_on  = false
local midi_poto_ch  = 2
local midi_8os_on   = false
local midi_8os_ch   = 3

local rms_smooth     = 0
local ply_idx        = 1
local ply_tokens     = {0, 0}
local poto_start_t   = 0.0
local poto_lead_zone = 0.0   -- zone actuelle du LEAD dans [0, POTO_DUR)

-- presets de rate grain, cycles avec K3 sur page 4
local RATE_PRESETS = {0.5, 0.75, 1.0, 1.25, 1.5, 2.0}
local rate_pidx    = 3   -- index par defaut = 1.0

---------------------------------------------------------------------
-- softcut
---------------------------------------------------------------------
local function slot_pos(s)
  return CORPUS_OFFSET + (s - 1) * CORPUS_DUR
end

local function sc_init()
  audio.level_cut(1.0)
  softcut.buffer_clear()

  for v = 1, 6 do
    softcut.enable(v, 1)
    softcut.buffer(v, 1)
    softcut.level(v, 0)
    softcut.rate(v, 1.0)
    softcut.loop(v, 0)
    softcut.play(v, 0)
    softcut.rec(v, 0)
    softcut.rec_level(v, 1.0)
    softcut.pre_level(v, 0.0)
    softcut.fade_time(v, 0.02)
  end

  softcut.level_input_cut(1, REC_V, 1.0)
  softcut.level_input_cut(2, REC_V, 1.0)
  softcut.level_input_cut(1, POTO_REC_V, 1.0)
  softcut.level_input_cut(2, POTO_REC_V, 1.0)

  -- POtO : capture continue en boucle
  softcut.loop(POTO_REC_V, 1)
  softcut.loop_start(POTO_REC_V, POTO_OFFSET)
  softcut.loop_end(POTO_REC_V, POTO_OFFSET + POTO_DUR)
  softcut.position(POTO_REC_V, POTO_OFFSET)
  softcut.rec(POTO_REC_V, 1)
  softcut.play(POTO_REC_V, 1)

  for i, v in ipairs(POTO_PLY_V) do
    softcut.loop(v, 1)
    softcut.loop_start(v, POTO_OFFSET)
    softcut.loop_end(v, POTO_OFFSET + POTO_DUR)
    softcut.position(v, POTO_OFFSET + (i - 1) * (POTO_DUR / #POTO_PLY_V))
  end
end

local function rec_start(slot)
  local p = slot_pos(slot)
  softcut.loop(REC_V, 0)
  softcut.loop_start(REC_V, p)
  softcut.loop_end(REC_V, p + CORPUS_DUR)
  softcut.position(REC_V, p)
  softcut.rec(REC_V, 1)
  softcut.play(REC_V, 1)
end

local function rec_stop()
  softcut.rec(REC_V, 0)
  softcut.play(REC_V, 0)
end

local function freq_to_midi(freq)
  if not freq or freq < 20 then return nil end
  local n = math.floor(69 + 12 * math.log(freq / 440) / math.log(2) + 0.5)
  return (n >= 0 and n <= 127) and n or nil
end

local function play_event(ev, rate_mult)
  local vi  = ply_idx
  local v   = PLY_V[vi]
  ply_idx   = (ply_idx % #PLY_V) + 1
  ply_tokens[vi] = ply_tokens[vi] + 1
  local tok = ply_tokens[vi]

  -- pre-silence : fade out du grain precedent avant le saut de position
  softcut.level(v, 0)
  clock.sleep(0.03)

  rate_mult = rate_mult or 1.0
  local p   = slot_pos(ev.slot)
  local dur = math.min(ev.duration, MAX_DUR)
  local base, len, rate = p, dur, 1.0

  if math.random() < SLICE_PROB and dur > SLICE_MIN then
    local sl = SLICE_MIN + math.random() * (dur * SLICE_MAX - SLICE_MIN)
    sl   = math.max(SLICE_MIN, math.min(sl, dur - 0.02))
    base = p + math.random() * math.max(0, dur - sl)
    len  = sl
  end

  softcut.loop(v, 1)
  softcut.loop_start(v, base)
  softcut.loop_end(v, base + len)

  if math.random() < REV_PROB then
    rate = -1.0
    softcut.position(v, base + len - 0.001)
  else
    softcut.position(v, base)
  end

  softcut.rate(v, rate * rate_mult)
  softcut.play(v, 1)
  softcut.level(v, 1.0)   -- fade in (fade_time = 20ms)

  local imp_note = nil
  if midi_impro_on and midi_out_impro then
    local f = ev.freq > 0 and ev.freq or cur_freq
    imp_note = freq_to_midi(f) or 60
    local vel = math.max(1, math.min(127, math.floor(ev.rms * 800)))
    midi_out_impro:note_on(imp_note, vel, midi_impro_ch)
  end

  clock.run(function()
    clock.sleep(len + 0.05)
    if ply_tokens[vi] == tok then
      softcut.level(v, 0)     -- fade out
      clock.sleep(0.03)
      softcut.play(v, 0)
      softcut.loop(v, 0)
      if imp_note and midi_out_impro then midi_out_impro:note_off(imp_note, 0, midi_impro_ch) end
    end
  end)

  return len
end

---------------------------------------------------------------------
-- 8OS : sampler grain + matching temps reel
-- V4 rec | V5 LOCK (match) | V6 ECHO (2e match) | V3 CONTRAST (oppose)
---------------------------------------------------------------------

local function os8_write_pos_rel()
  return (util.time() - os8_start_t) % OS8_DUR
end

-- note chromatique live depuis cur_freq (0-11, -1 si pas de pitch) — pour affichage
local function cur_note_class()
  if cur_freq < 20 then return -1 end
  return math.floor(69 + 12 * math.log(cur_freq / 440) / math.log(2) + 0.5) % 12
end

-- note MIDI complete live (0-127, -1 si pas de pitch) — pour matching 8OS
local function cur_midi_note()
  if cur_freq < 20 then return -1 end
  return math.floor(69 + 12 * math.log(cur_freq / 440) / math.log(2) + 0.5)
end

-- cherche le grain le plus proche (attract=true) ou le plus eloigne (false)
-- skip1/skip2 : positions a ignorer pour eviter les doublons entre voix
-- score combine : pitch 0.55 + energie 0.35 + centroide 0.10
local function os8_find_grain(attract, skip1, skip2)
  if #os8_bank == 0 then return nil end
  local live_midi = cur_midi_note()
  local best, bs  = nil, attract and math.huge or -math.huge
  for _, g in ipairs(os8_bank) do
    if g.pos ~= skip1 and g.pos ~= skip2 then
      -- distance MIDI complete avec octave (0=meme note, 1=4 octaves d'ecart)
      local dn
      if live_midi >= 0 and g.note >= 0 then
        dn = math.min(math.abs(live_midi - g.note) / 48.0, 1.0)
      else
        dn = 0.5
      end
      -- distance energie (0=meme rms, 1=tres different)
      local g_rms  = g.rms or 0.0
      local mx_rms = math.max(rms_smooth, g_rms, 0.001)
      local de     = math.abs(rms_smooth - g_rms) / mx_rms
      -- distance timbre centroide
      local dc = math.abs(g.centroid - cur_centroid) / 8000.0
      local score = dn * 0.55 + de * 0.35 + dc * 0.10 + math.random() * 0.03
      if attract  and score < bs then bs = score ; best = g end
      if not attract and score > bs then bs = score ; best = g end
    end
  end
  return best
end

local function os8_set(mode)
  -- arret propre de l'etat precedent
  if os8_mode == "REC" then
    softcut.rec(4, 0) ; softcut.play(4, 0)
    softcut.level_input_cut(1, 4, 0.0)
    softcut.level_input_cut(2, 4, 0.0)
    -- rebranche POtO rec
    softcut.loop(POTO_REC_V, 1)
    softcut.loop_start(POTO_REC_V, POTO_OFFSET)
    softcut.loop_end(POTO_REC_V,   POTO_OFFSET + POTO_DUR)
    softcut.position(POTO_REC_V, POTO_OFFSET)
    softcut.level_input_cut(1, POTO_REC_V, 1.0)
    softcut.level_input_cut(2, POTO_REC_V, 1.0)
    softcut.rec(POTO_REC_V, 1) ; softcut.play(POTO_REC_V, 1)
  end
  if os8_mode == "TRANS" then
    for _, v in ipairs({3, 5, 6}) do
      softcut.level(v, 0) ; softcut.play(v, 0)
    end
    -- rebranche POtO rec (arrete lors du passage en TRANS)
    softcut.loop(POTO_REC_V, 1)
    softcut.loop_start(POTO_REC_V, POTO_OFFSET)
    softcut.loop_end(POTO_REC_V,   POTO_OFFSET + POTO_DUR)
    softcut.position(POTO_REC_V, POTO_OFFSET)
    softcut.level_input_cut(1, POTO_REC_V, 1.0)
    softcut.level_input_cut(2, POTO_REC_V, 1.0)
    softcut.rec(POTO_REC_V, 1) ; softcut.play(POTO_REC_V, 1)
  end

  os8_mode = mode

  if mode == "OFF" then
    -- libere V3 pour le corpus (sauf si POtO l'utilise deja)
    if not p_poto_on then PLY_V = {2, 3} ; ply_idx = 1 end
  else
    -- REC ou TRANS : restreint le corpus a V2 seul, V3 reserve a 8OS
    PLY_V = {2} ; ply_idx = 1
  end

  if mode == "REC" then
    -- debranche POtO rec et prend V4 pour 8OS
    softcut.rec(POTO_REC_V, 0) ; softcut.play(POTO_REC_V, 0)
    softcut.level_input_cut(1, POTO_REC_V, 0.0)
    softcut.level_input_cut(2, POTO_REC_V, 0.0)
    softcut.buffer(4, 1)
    softcut.loop(4, 1)
    softcut.loop_start(4, OS8_OFFSET)
    softcut.loop_end(4,   OS8_OFFSET + OS8_DUR)
    softcut.position(4, OS8_OFFSET)
    softcut.rec_level(4, 1.0) ; softcut.pre_level(4, 0.0)
    softcut.fade_time(4, 0.02) ; softcut.rate(4, 1.0)
    softcut.level_input_cut(1, 4, 1.0)
    softcut.level_input_cut(2, 4, 1.0)
    softcut.rec(4, 1) ; softcut.play(4, 1)
    os8_start_t = util.time()
    os8_bank = {} ; os8_rec_n = 0
    os8_pitch_acc = 0 ; os8_pitch_n = 0
    os8_ctr_acc   = 0 ; os8_ctr_n   = 0
    os8_rms_acc   = 0 ; os8_rms_n   = 0
    -- decoupage temporel : un grain toutes les os8_size secondes
    clock.run(function()
      while os8_mode == "REC" do
        clock.sleep(os8_size)
        if os8_mode ~= "REC" then break end
        local wp = os8_write_pos_rel()
        if wp >= os8_size then
          local avg_p = os8_pitch_n > 0 and (os8_pitch_acc / os8_pitch_n) or 0
          local avg_c = os8_ctr_n   > 0 and (os8_ctr_acc   / os8_ctr_n)   or cur_centroid
          local avg_r = os8_rms_n   > 0 and (os8_rms_acc   / os8_rms_n)   or 0
          local note  = -1
          if avg_p > 20 then
            note = math.floor(69 + 12 * math.log(avg_p / 440) / math.log(2) + 0.5)
          end
          table.insert(os8_bank, {
            pos      = OS8_OFFSET + wp - os8_size,
            dur      = os8_size,
            pitch    = avg_p,
            note     = note,
            centroid = avg_c,
            rms      = avg_r,
          })
          if #os8_bank > OS8_MAX then table.remove(os8_bank, 1) end
          os8_rec_n     = #os8_bank
          os8_pitch_acc = 0 ; os8_pitch_n = 0
          os8_ctr_acc   = 0 ; os8_ctr_n   = 0
          os8_rms_acc   = 0 ; os8_rms_n   = 0
        end
      end
    end)

  elseif mode == "TRANS" then
    -- arret enregistrement
    softcut.rec(4, 0)
    softcut.level_input_cut(1, 4, 0.0)
    softcut.level_input_cut(2, 4, 0.0)
    -- config voix lecture
    for _, v in ipairs({3, 5, 6}) do
      softcut.buffer(v, 1)
      softcut.loop(v, 1)
      softcut.level(v, 0)
      softcut.rate(v, 1.0)
      softcut.fade_time(v, 0.02)
    end
    os8_pos_v5 = nil ; os8_pos_v6 = nil ; os8_pos_v3 = nil

    -- sleep interruptible : sort des que le gate tombe ou que le mode change
    local function grain_sleep(dur)
      local t = 0
      while t < dur and os8_mode == "TRANS" and cur_gate > 0.5 do
        local step = math.min(0.02, dur - t)
        clock.sleep(step) ; t = t + step
      end
    end

    -- boucle grain V5 LOCK (grain le plus proche, gate-driven)
    clock.run(function()
      while os8_mode == "TRANS" do
        if cur_gate > 0.5 then
          local g = os8_find_grain(true, nil, nil)
          if g then
            os8_pos_v5 = g.pos
            local gs = math.min(os8_size, g.dur)
            softcut.loop_start(5, g.pos)
            softcut.loop_end(5,   g.pos + gs)
            softcut.position(5, g.pos)
            softcut.rate(5, 1.0)
            softcut.level(5, os8_vol)
            softcut.play(5, 1)
            local n5 = nil
            if midi_8os_on and midi_out_8os then
              n5 = freq_to_midi(g.pitch)
              if n5 then midi_out_8os:note_on(n5, math.floor(os8_vol * 127), midi_8os_ch) end
            end
            grain_sleep(gs)
            if n5 and midi_out_8os then midi_out_8os:note_off(n5, 0, midi_8os_ch) end
            softcut.level(5, 0) ; clock.sleep(0.02)
          else
            clock.sleep(0.05)
          end
        else
          softcut.level(5, 0) ; softcut.play(5, 0)
          clock.sleep(0.05)
        end
      end
      softcut.level(5, 0) ; softcut.play(5, 0)
    end)
    -- boucle grain V6 ECHO (2e match, gate-driven)
    clock.run(function()
      clock.sleep(os8_size * 0.33)  -- decalage de phase
      while os8_mode == "TRANS" do
        if cur_gate > 0.5 then
          local g = os8_find_grain(true, os8_pos_v5, nil)
          if not g then g = os8_find_grain(true, nil, nil) end
          if g then
            os8_pos_v6 = g.pos
            local gs = math.min(os8_size, g.dur)
            softcut.loop_start(6, g.pos)
            softcut.loop_end(6,   g.pos + gs)
            softcut.position(6, g.pos)
            softcut.rate(6, 1.0)
            softcut.level(6, os8_vol * 0.65)
            softcut.play(6, 1)
            local n6 = nil
            if midi_8os_on and midi_out_8os then
              n6 = freq_to_midi(g.pitch)
              if n6 then midi_out_8os:note_on(n6, math.floor(os8_vol * 83), midi_8os_ch) end
            end
            grain_sleep(gs)
            if n6 and midi_out_8os then midi_out_8os:note_off(n6, 0, midi_8os_ch) end
            softcut.level(6, 0) ; clock.sleep(0.02)
          else
            clock.sleep(0.05)
          end
        else
          softcut.level(6, 0) ; softcut.play(6, 0)
          clock.sleep(0.05)
        end
      end
      softcut.level(6, 0) ; softcut.play(6, 0)
    end)
    -- boucle grain V3 LOCK (3e grain le plus proche, gate-driven)
    clock.run(function()
      clock.sleep(os8_size * 0.66)  -- decalage de phase
      while os8_mode == "TRANS" do
        if cur_gate > 0.5 then
          local g = os8_find_grain(true, os8_pos_v5, os8_pos_v6)
          if not g then g = os8_find_grain(true, nil, nil) end
          if g then
            os8_pos_v3 = g.pos
            local gs = math.min(os8_size, g.dur)
            softcut.loop_start(3, g.pos)
            softcut.loop_end(3,   g.pos + gs)
            softcut.position(3, g.pos)
            softcut.rate(3, 1.0)
            softcut.level(3, os8_vol * 0.40)
            softcut.play(3, 1)
            local n3 = nil
            if midi_8os_on and midi_out_8os then
              n3 = freq_to_midi(g.pitch)
              if n3 then midi_out_8os:note_on(n3, math.floor(os8_vol * 51), midi_8os_ch) end
            end
            grain_sleep(gs)
            if n3 and midi_out_8os then midi_out_8os:note_off(n3, 0, midi_8os_ch) end
            softcut.level(3, 0) ; clock.sleep(0.02)
          else
            clock.sleep(0.05)
          end
        else
          softcut.level(3, 0) ; softcut.play(3, 0)
          clock.sleep(0.05)
        end
      end
      softcut.level(3, 0) ; softcut.play(3, 0)
    end)
  end
end

---------------------------------------------------------------------
-- POtO grain : 3 lecteurs avec attraction / repulsion
-- V5 LEAD      : zone fraiche (proche tete d'ecriture), gain 100%
-- V6 ATTRACTED : attire vers LEAD, gain 65%, legere detune +spread
-- V3 REPULSED  : pousse a l'oppose de LEAD, gain 40%, detune -spread
---------------------------------------------------------------------

-- position relative de la tete d'ecriture V4 dans [0, POTO_DUR)
local function poto_write_pos_rel()
  return (util.time() - poto_start_t) % POTO_DUR
end

local function poto_set(on)
  if on == p_poto_on then return end
  -- POtO et 8OS sont mutuellement exclusifs
  if on and os8_mode ~= "OFF" then os8_set("OFF") end
  p_poto_on = on

  if on then
    -- V3 emprunte : une seule voix corpus pendant POtO
    PLY_V = {2} ; ply_idx = 1
    softcut.level(3, 0) ; softcut.play(3, 0)

    poto_lead_zone = 0.0

    local lv = POTO_PLY_V[1]   -- V5 LEAD
    local av = POTO_PLY_V[2]   -- V6 ATTRACTED
    local rv = 3                -- V3 REPULSED

    for _, v in ipairs({lv, av, rv}) do
      softcut.buffer(v, 1)
      softcut.loop(v, 1)
      softcut.play(v, 0)
      softcut.level(v, 0)
      softcut.rate(v, 1.0)
      softcut.fade_time(v, 0.02)
    end

    -- LEAD : colle a la zone la plus fraiche (< 100ms du present)
    clock.run(function()
      local zone = 0.0
      while p_poto_on do
        local wp  = poto_write_pos_rel()
        local tgt = (wp - 0.10 + POTO_DUR) % POTO_DUR
        zone = (zone * 0.85 + tgt * 0.15) % POTO_DUR
        if zone + p_poto_size > POTO_DUR then zone = POTO_DUR - p_poto_size - 0.01 end
        poto_lead_zone = zone
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > p_poto_size + 0.05 then
          local bp = POTO_OFFSET + zone
          softcut.loop_start(lv, bp)
          softcut.loop_end(lv, bp + p_poto_size)
          softcut.position(lv, bp)
          softcut.rate(lv, p_poto_rate)
          softcut.level(lv, p_poto_vol)
          softcut.play(lv, 1)
          local pn_lv = nil
          if midi_poto_on and midi_out_poto and cur_freq > 0 then
            pn_lv = freq_to_midi(cur_freq)
            if pn_lv then midi_out_poto:note_on(pn_lv, math.floor(p_poto_vol * 127), midi_poto_ch) end
          end
          clock.sleep(p_poto_size)
          if pn_lv and midi_out_poto then midi_out_poto:note_off(pn_lv, 0, midi_poto_ch) end
          softcut.level(lv, 0)
          clock.sleep(0.02)
        else
          clock.sleep(p_poto_size + 0.02)
        end
      end
      softcut.level(lv, 0) ; softcut.play(lv, 0)
    end)

    -- ATTRACTED : derive lentement vers la zone LEAD
    clock.run(function()
      local zone = POTO_DUR * 0.25
      while p_poto_on do
        local wp  = poto_write_pos_rel()
        local tgt = (poto_lead_zone - 0.05 + POTO_DUR) % POTO_DUR
        zone = (zone * 0.92 + tgt * 0.08) % POTO_DUR
        if zone + p_poto_size > POTO_DUR then zone = POTO_DUR - p_poto_size - 0.01 end
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > p_poto_size + 0.05 then
          local bp = POTO_OFFSET + zone
          softcut.loop_start(av, bp)
          softcut.loop_end(av, bp + p_poto_size)
          softcut.position(av, bp)
          softcut.rate(av, p_poto_rate * (1 + p_poto_spread))
          softcut.level(av, p_poto_vol * 0.65)
          softcut.play(av, 1)
          local pn_av = nil
          if midi_poto_on and midi_out_poto and cur_freq > 0 then
            pn_av = freq_to_midi(cur_freq)
            if pn_av then midi_out_poto:note_on(pn_av, math.floor(p_poto_vol * 83), midi_poto_ch) end
          end
          clock.sleep(p_poto_size + 0.01)
          if pn_av and midi_out_poto then midi_out_poto:note_off(pn_av, 0, midi_poto_ch) end
          softcut.level(av, 0)
          clock.sleep(0.02)
        else
          clock.sleep(p_poto_size + 0.03)
        end
      end
      softcut.level(av, 0) ; softcut.play(av, 0)
    end)

    -- REPULSED : pousse vers le cote oppose de LEAD dans le buffer
    clock.run(function()
      local zone = POTO_DUR * 0.5
      while p_poto_on do
        local wp  = poto_write_pos_rel()
        local tgt = (poto_lead_zone + POTO_DUR * 0.5) % POTO_DUR
        zone = (zone * 0.95 + tgt * 0.05) % POTO_DUR
        if zone + p_poto_size > POTO_DUR then zone = POTO_DUR - p_poto_size - 0.01 end
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > p_poto_size + 0.05 then
          local bp = POTO_OFFSET + zone
          softcut.loop_start(rv, bp)
          softcut.loop_end(rv, bp + p_poto_size)
          softcut.position(rv, bp)
          softcut.rate(rv, math.max(0.5, p_poto_rate * (1 - p_poto_spread * 2)))
          softcut.level(rv, p_poto_vol * 0.40)
          softcut.play(rv, 1)
          local pn_rv = nil
          if midi_poto_on and midi_out_poto and cur_freq > 0 then
            pn_rv = freq_to_midi(cur_freq)
            if pn_rv then midi_out_poto:note_on(pn_rv, math.floor(p_poto_vol * 51), midi_poto_ch) end
          end
          clock.sleep(p_poto_size + 0.03)
          if pn_rv and midi_out_poto then midi_out_poto:note_off(pn_rv, 0, midi_poto_ch) end
          softcut.level(rv, 0)
          clock.sleep(0.02)
        else
          clock.sleep(p_poto_size + 0.05)
        end
      end
      softcut.level(rv, 0) ; softcut.play(rv, 0)
    end)

  else
    -- arret immediat, les boucles grain s'arretent au prochain tour
    for _, v in ipairs({POTO_PLY_V[1], POTO_PLY_V[2], 3}) do
      softcut.level(v, 0)
      softcut.play(v, 0)
    end
    if os8_mode == "OFF" then PLY_V = {2, 3} else PLY_V = {2} end
    ply_idx = 1
    softcut.loop(3, 0)
    softcut.fade_time(3, 0.02)
  end
end

---------------------------------------------------------------------
-- distance (Python: energy=0.45x4, pitch=0.35/1000,
--           timbre=1.0/4000, duration=0.25/1.2)
---------------------------------------------------------------------
local function distance(ev, ref)
  local dr  = math.abs(ev.rms - ref.rms) * 1.8
  local df
  if ev.freq > 0 and ref.freq > 0 then
    df = math.abs(ev.freq - ref.freq) * 0.35 / 1000.0
  else
    df = 0.35
  end
  local dc  = math.abs(ev.centroid - ref.centroid) / 4000.0
  local dfl = math.abs(ev.flatness - ref.flatness) * 0.5
  local dd  = math.abs(ev.duration - ref.duration) * 0.25 / 1.2
  return dr + df + dc + dfl + dd
end

---------------------------------------------------------------------
-- analyseur de fragment
---------------------------------------------------------------------
local function analyze_phrase(buf)
  local n = #buf
  if n == 0 then return nil end
  local s_rms, s_freq, s_ctr, s_flat, s_dur = 0, 0, 0, 0, 0
  local n_freq = 0
  for _, ev in ipairs(buf) do
    s_rms  = s_rms  + ev.rms
    s_ctr  = s_ctr  + ev.centroid
    s_flat = s_flat + ev.flatness
    s_dur  = s_dur  + ev.duration
    if ev.freq > 0 then s_freq = s_freq + ev.freq ; n_freq = n_freq + 1 end
  end
  return {
    rms      = s_rms / n,
    freq     = n_freq > 0 and (s_freq / n_freq) or 0,
    centroid = s_ctr / n,
    flatness = s_flat / n,
    duration = s_dur / n,
    density  = n / math.max(s_dur, 0.1),
    n        = n,
  }
end

---------------------------------------------------------------------
-- corpus queries
---------------------------------------------------------------------
local function ref_target()
  if phrase_analysis then return phrase_analysis end
  return {
    rms=last_rms, freq=last_freq,
    centroid=last_centroid, flatness=last_flatness,
    duration=0.5,
  }
end

local function is_recent(slot)
  for _, s in ipairs(recent_slots) do
    if s == slot then return true end
  end
  return false
end

local function mark_played(slot)
  table.insert(recent_slots, slot)
  while #recent_slots > RECENT_MAX do table.remove(recent_slots, 1) end
end

local function pick_best(invert, used)
  local best, bd = nil, invert and 0 or math.huge
  local ref = ref_target()
  for _, ev in pairs(corpus) do
    if not is_recent(ev.slot) and (used == nil or not used[ev.slot]) then
      local d = distance(ev, ref)
      if invert then
        if d > bd then bd = d ; best = ev end
      else
        if d < bd then bd = d ; best = ev end
      end
    end
  end
  return best
end

local function pick_random(used)
  local pool = {}
  for _, ev in pairs(corpus) do
    if not is_recent(ev.slot) and (used == nil or not used[ev.slot]) then
      table.insert(pool, ev)
    end
  end
  if #pool == 0 then return nil end
  return pool[math.random(#pool)]
end

local function pick_initiative()
  local best, best_score = nil, -math.huge
  for _, ev in pairs(corpus) do
    if not is_recent(ev.slot) then
      local score = ev.rms * 2.0
      if ev.freq > 100 then score = score + 0.15 end
      score = score + (1.0 - (ev.flatness or 0)) * 0.3
      score = score + ev.duration * 0.1
      if score > best_score then best_score = score ; best = ev end
    end
  end
  return best
end

---------------------------------------------------------------------
-- strategies
---------------------------------------------------------------------
local function pick_strat()
  local ref      = phrase_analysis or {}
  local energy   = math.min(1.0, (ref.rms or last_rms) * 10.0)
  local brightness = math.min(1.0, (ref.centroid or last_centroid) / 4000.0)
  local ph_density = ref.density or 1.0

  local w = {
    IMITATION     = 0.25 + energy * 0.12,
    CONTRASTE     = 0.15 + p_contrast * 0.35 + brightness * 0.1,
    DENSIFICATION = 0.12 + p_density * 0.35 + math.min(0.25, ph_density * 0.05),
    SPARSE        = 0.18 + p_sil_bias * 0.2 + math.min(0.2, 1.0 / math.max(ph_density, 0.5) * 0.1),
    SILENCE       = p_sil_bias,
  }

  if consec_sil >= 2 then
    w.SILENCE = w.SILENCE * 0.15
  elseif consec_sil == 1 then
    w.SILENCE = w.SILENCE * 0.45
  end

  if sil_sec > 3.0 then
    w.SILENCE       = w.SILENCE + 0.25
    w.IMITATION     = w.IMITATION * 0.4
    w.DENSIFICATION = w.DENSIFICATION * 0.3
  elseif sil_sec > 1.5 then
    w.SILENCE = w.SILENCE + 0.1
  end

  if last_strat == "DENSIFICATION" then
    w.SPARSE        = w.SPARSE + 0.25
    w.SILENCE       = w.SILENCE + 0.18
    w.DENSIFICATION = w.DENSIFICATION * 0.2
  end

  if count < 8 then
    w.IMITATION     = w.IMITATION + 0.15
    w.DENSIFICATION = math.max(0, w.DENSIFICATION - 0.06)
  end

  local total = 0
  for _, wv in pairs(w) do total = total + math.max(0, wv) end
  if total == 0 then return "SILENCE" end
  local r   = math.random() * total
  local acc = 0
  local ord = {"IMITATION","CONTRASTE","DENSIFICATION","SPARSE","SILENCE"}
  for _, s in ipairs(ord) do
    acc = acc + math.max(0, w[s])
    if r <= acc then return s end
  end
  return "SILENCE"
end

---------------------------------------------------------------------
-- phrase
---------------------------------------------------------------------
local function build_phrase(strategy, ref_n)
  ref_n = ref_n or 2
  local n_min = math.max(PHRASE_MIN, math.floor(ref_n * 0.5))
  local n_max = math.min(PHRASE_MAX, ref_n + 2)
  local n = math.random(n_min, n_max)
  if strategy == "SPARSE"        then n = math.min(n, 2) end
  if strategy == "DENSIFICATION" then n = math.max(n, 4) end

  local phrase, used = {}, {}
  for _ = 1, n do
    local ev
    if strategy == "IMITATION" or strategy == "DENSIFICATION" then
      ev = pick_best(false, used)
    elseif strategy == "CONTRASTE" then
      ev = pick_best(true, used)
    else
      ev = pick_random(used)
    end
    if ev then
      table.insert(phrase, ev)
      used[ev.slot] = true
    end
  end
  return phrase
end

local function improv_rate(strategy, i, n)
  if p_voice then
    -- voix : pas de transposition, micro-variations seulement
    return 0.97 + math.random() * 0.06
  end
  if strategy == "CONTRASTE" then
    local intervals = {0.84, 0.89, 1.0, 1.12, 1.33}
    return intervals[math.random(#intervals)]
  elseif strategy == "DENSIFICATION" then
    return 0.95 + math.random() * 0.10
  elseif strategy == "SPARSE" then
    return math.random() < 0.5 and 0.75 or 1.5
  else
    return 0.98 + math.random() * 0.04
  end
end

local function play_phrase(phrase, strategy)
  local gap
  if strategy == "IMITATION" and phrase_analysis and phrase_analysis.density > 0 then
    gap = math.max(0.02, 1.0 / phrase_analysis.density * 0.6)
  else
    gap = math.max(0.02, (1.0 - p_density) * 0.18)
  end
  for i, ev in ipairs(phrase) do
    local rm = improv_rate(strategy, i, #phrase)
    play_event(ev, rm)
    mark_played(ev.slot)
    last_slot = ev.slot
    if i < #phrase then clock.sleep(gap) end
  end
end

---------------------------------------------------------------------
-- respond
---------------------------------------------------------------------
local function respond(ref_n)
  local s = pick_strat()
  strat_name = s
  last_strat = s

  if s == "SILENCE" then
    consec_sil = consec_sil + 1
    return
  end
  consec_sil = 0
  if count < MIN_CORPUS then return end

  local phrase = build_phrase(s, ref_n)
  if #phrase > 0 then play_phrase(phrase, s) end
end

---------------------------------------------------------------------
-- polls SC
---------------------------------------------------------------------
local function on_freq(v)     cur_freq     = v end
local function on_centroid(v) cur_centroid = v end
local function on_flatness(v) cur_flatness = v end

local function process_gate(new_gate)
  if new_gate > 0.5 and cur_gate < 0.5 and not rec_on and state ~= "REST" then
    last_sound_t = util.time()
    rec_slot = head
    rec_t0   = util.time()
    rms_sum  = 0 ; rms_n = 0
    rec_start(rec_slot)
    rec_on = true
  end

  if new_gate < 0.5 and cur_gate > 0.5 then
    if midi_8os_on  and midi_out_8os  then midi_out_8os:cc(123,  0, midi_8os_ch)  end
    if midi_poto_on and midi_out_poto then midi_out_poto:cc(123, 0, midi_poto_ch) end
  end

  if new_gate < 0.5 and cur_gate > 0.5 and rec_on then
    local dur = util.time() - rec_t0
    rec_stop()
    rec_on = false

    local min_dur = p_voice and 0.12 or MIN_DUR
    if dur >= min_dur and dur <= MAX_DUR and math.random() < p_rec_prob then
      local avg = rms_n > 0 and (rms_sum / rms_n) or 0
      corpus[rec_slot] = {
        slot=rec_slot, rms=avg, duration=dur,
        freq=cur_freq, centroid=cur_centroid, flatness=cur_flatness,
      }
      last_rms=avg ; last_freq=cur_freq
      last_centroid=cur_centroid ; last_flatness=cur_flatness
      head  = (head % CORPUS_SLOTS) + 1
      count = math.min(count + 1, CORPUS_SLOTS)
      table.insert(phrase_buf, corpus[rec_slot])
    end

  end
end

local function on_rms(v)
  cur_rms    = v
  rms_smooth = rms_smooth * 0.92 + v * 0.08

  if p_deaf then return end   -- mode sourd : ignore tout le reste

  local new_gate
  local hold_n = p_voice and 12 or GATE_HOLD_N
  if v > p_gate_thr then
    gate_hold = hold_n
    new_gate  = 1.0
  elseif gate_hold > 0 then
    gate_hold = gate_hold - 1
    new_gate  = 1.0
  else
    new_gate  = 0.0
  end

  if new_gate ~= cur_gate then
    process_gate(new_gate)
    cur_gate = new_gate
  end

  if rec_on then
    rms_sum = rms_sum + v ; rms_n = rms_n + 1
    if os8_mode == "REC" then
      if cur_freq > 0 then os8_pitch_acc = os8_pitch_acc + cur_freq ; os8_pitch_n = os8_pitch_n + 1 end
      os8_ctr_acc = os8_ctr_acc + cur_centroid ; os8_ctr_n = os8_ctr_n + 1
      os8_rms_acc = os8_rms_acc + v           ; os8_rms_n = os8_rms_n + 1
    end
  end

  if v > p_gate_thr and phrase_analysis then
    local blend = 0.04
    phrase_analysis.rms      = phrase_analysis.rms      * (1-blend) + v             * blend
    phrase_analysis.centroid = phrase_analysis.centroid * (1-blend) + cur_centroid  * blend
    phrase_analysis.flatness = phrase_analysis.flatness * (1-blend) + cur_flatness  * blend
    if cur_freq > 0 and phrase_analysis.freq > 0 then
      phrase_analysis.freq = phrase_analysis.freq * (1-blend) + cur_freq * blend
    end
  end
end

---------------------------------------------------------------------
-- silence tracker + reponse spontanee
---------------------------------------------------------------------
local function do_respond(ref_n, rest_base)
  state = "THINK"
  clock.run(function()
    clock.sleep(MIN_DELAY + math.random() * (MAX_DELAY - MIN_DELAY))
    local ok, err = pcall(respond, ref_n)
    if not ok then print("tm respond: " .. tostring(err)) end
    state = "REST"
    local rest
    if last_strat == "DENSIFICATION" then
      rest = 1.5 + math.random() * 2.5
    elseif sil_sec > 2.0 then
      rest = 0.4 + math.random() * 0.8
    else
      rest = (rest_base or 0.3) + math.random() * 1.5
    end
    clock.sleep(rest)
    state = "LISTEN"
  end)
end

local function silence_loop()
  clock.run(function()
    while true do
      clock.sleep(0.5)

      if cur_gate < 0.5 and not rec_on then
        sil_sec = util.time() - last_sound_t
      else
        sil_sec = 0.0
        last_sound_t = util.time()
      end

      if state ~= "LISTEN" then goto continue end

      if #phrase_buf > 0 and sil_sec < 0.1 and count >= MIN_CORPUS then
        if math.random() < INTERRUPT_PROB then
          local n_phrase = #phrase_buf
          phrase_analysis = analyze_phrase(phrase_buf)
          phrase_buf = {}
          do_respond(n_phrase, 0.1)
          goto continue
        end
      end

      if #phrase_buf > 0 and sil_sec >= p_sil_min then
        local n_phrase = #phrase_buf
        phrase_analysis = analyze_phrase(phrase_buf)
        phrase_buf = {}
        if count >= MIN_CORPUS and math.random() < p_reply then
          do_respond(n_phrase, 0.3)
        end

      elseif #phrase_buf == 0 and sil_sec > p_sil_max and count >= MIN_CORPUS then
        local prob
        if    sil_sec > 8.0 then prob = 0.50
        elseif sil_sec > 4.0 then prob = 0.30
        else                      prob = 0.15
        end
        if math.random() < prob then
          local seed = pick_initiative()
          if seed then
            phrase_analysis = {
              rms=seed.rms, freq=seed.freq,
              centroid=seed.centroid, flatness=seed.flatness or 0,
              duration=seed.duration, density=2.0, n=1,
            }
            local n_ev = math.random(2, 5)
            do_respond(n_ev, 0.5)
          end
        end
      end

      ::continue::
    end
  end)
end

---------------------------------------------------------------------
-- norns
---------------------------------------------------------------------
function init()
  math.randomseed(os.time())
  last_sound_t = util.time()
  splash_active = true
  clock.run(function() clock.sleep(3.0) ; splash_active = false end)
  local ok1, md1 = pcall(midi.connect, midi_dev_impro) ; if ok1 then midi_out_impro = md1 end
  local ok2, md2 = pcall(midi.connect, midi_dev_poto)  ; if ok2 then midi_out_poto  = md2 end
  local ok3, md3 = pcall(midi.connect, midi_dev_8os)   ; if ok3 then midi_out_8os   = md3 end
  audio.level_adc(1.0)
  audio.level_monitor(1.0)
  sc_init()
  poto_start_t = util.time()

  local pa = poll.set("amp_in_l",   on_rms)
  local pp = poll.set("pitch_in_l", on_freq)
  pa.time = 1/60.0 ; pa:start()
  pp.time = 1/30.0 ; pp:start()

  local pc  = poll.set("tm_centroid", on_centroid)
  local pfl = poll.set("tm_flatness", on_flatness)
  if pc  then pc.time  = 1/30.0 ; pc:start()  end
  if pfl then pfl.time = 1/30.0 ; pfl:start() end

  silence_loop()

  clock.run(function()
    while true do
      clock.sleep(0.1)
      redraw()
    end
  end)
end

function cleanup()
  for v = 1, 6 do
    softcut.rec(v, 0)
    softcut.play(v, 0)
    softcut.level(v, 0)
  end
end

---------------------------------------------------------------------
-- navigation pages (11 pages)
-- Page 1  CORPUS : E2 learn    | E3 thr       | K3 clear corpus
-- Page 2  MAIN   : E2 density  | E3 sil_bias  | K3 force reply
-- Page 3  RESP   : E2 contrast | E3 reply     | K3 deaf on/off
-- Page 4  TIME   : E2 react    | E3 init      | K3 voice mode
-- Page 5  POtO   : E2 vol      | E3 monitor   | K3 POtO on/off
-- Page 6  GRAIN  : E2 grain ms | E3 spread    | K3 rate preset
-- Page 7  8OS    : E2 vol      | E3 grain ms  | K3 OFF->REC->TRANS
-- Page 8  CLR8OS : ---         | ---          | K3 clear bank 8OS
-- Page 9  MIDI I : E2 ch       | E3 dev       | K3 on/off
-- Page 10 MIDI P : E2 ch       | ---          | K3 on/off
-- Page 11 MIDI 8 : E2 ch       | ---          | K3 on/off
-- E1 : navigation pages | K2 : page suivante
---------------------------------------------------------------------
function enc(n, d)
  if n == 1 then
    page = ((page - 1 + d) % 11) + 1
  elseif n == 2 then
    if page == 1 then
      p_rec_prob    = util.clamp(p_rec_prob    + d * 0.05, 0.0, 1.0)
    elseif page == 2 then
      p_density     = util.clamp(p_density     + d * 0.05, 0.0, 1.0)
    elseif page == 3 then
      p_contrast    = util.clamp(p_contrast    + d * 0.05, 0.0, 1.0)
    elseif page == 4 then
      p_sil_min     = util.clamp(p_sil_min     + d * 0.05, 0.2, 3.0)
    elseif page == 5 then
      p_poto_vol    = util.clamp(p_poto_vol    + d * 0.05, 0.0, 1.0)
    elseif page == 6 then
      p_poto_size   = util.clamp(p_poto_size   + d * 0.01, 0.05, 0.40)
    elseif page == 7 then
      os8_vol       = util.clamp(os8_vol       + d * 0.05, 0.0, 1.0)
    elseif page == 9 then
      midi_impro_ch = util.clamp(midi_impro_ch + d, 1, 16)
    elseif page == 10 then
      midi_poto_ch  = util.clamp(midi_poto_ch  + d, 1, 16)
    elseif page == 11 then
      midi_8os_ch   = util.clamp(midi_8os_ch   + d, 1, 16)
    end
  elseif n == 3 then
    if page == 1 then
      p_gate_thr    = util.clamp(p_gate_thr    + d * 0.001, 0.0001, 0.05)
    elseif page == 2 then
      p_sil_bias    = util.clamp(p_sil_bias    + d * 0.05, 0.0, 1.0)
    elseif page == 3 then
      p_reply       = util.clamp(p_reply       + d * 0.05, 0.0, 1.0)
    elseif page == 4 then
      p_sil_max     = util.clamp(p_sil_max     + d * 0.1,  0.5, 8.0)
    elseif page == 5 then
      p_monitor     = util.clamp(p_monitor     + d * 0.05, 0.0, 1.0)
      audio.level_monitor(p_monitor)
    elseif page == 6 then
      p_poto_spread = util.clamp(p_poto_spread + d * 0.01, 0.0, 0.30)
    elseif page == 7 then
      os8_size      = util.clamp(os8_size      + d * 0.01, 0.02, 0.50)
    elseif page == 9 then
      midi_dev_impro = util.clamp(midi_dev_impro + d, 1, 4)
      local ok2, md2 = pcall(midi.connect, midi_dev_impro)
      if ok2 then midi_out_impro = md2 end
    elseif page == 10 then
      midi_dev_poto  = util.clamp(midi_dev_poto  + d, 1, 4)
      local ok3, md3 = pcall(midi.connect, midi_dev_poto)
      if ok3 then midi_out_poto = md3 end
    elseif page == 11 then
      midi_dev_8os   = util.clamp(midi_dev_8os   + d, 1, 4)
      local ok4, md4 = pcall(midi.connect, midi_dev_8os)
      if ok4 then midi_out_8os = md4 end
    end
  end
  redraw()
end

function key(n, z)
  if z == 0 then return end
  if n == 2 then
    page = (page % 11) + 1
  elseif n == 3 then
    if page == 1 then
      corpus = {} ; count = 0 ; head = 1 ; last_slot = 0
    elseif page == 2 then
      if count >= MIN_CORPUS and state == "LISTEN" then
        state = "THINK"
        clock.run(function()
          respond()
          state = "REST"
          clock.sleep(0.5 + math.random() * 1.0)
          state = "LISTEN"
        end)
      end
    elseif page == 3 then
      p_deaf = not p_deaf
      if p_deaf then
        if rec_on then rec_stop() ; rec_on = false end
        cur_gate = 0 ; gate_hold = 0
      else
        last_sound_t = util.time()
      end
    elseif page == 4 then
      p_voice = not p_voice
    elseif page == 5 then
      poto_set(not p_poto_on)
    elseif page == 6 then
      rate_pidx = (rate_pidx % #RATE_PRESETS) + 1
      p_poto_rate = RATE_PRESETS[rate_pidx]
    elseif page == 7 then
      local seq = {"OFF", "REC", "TRANS"}
      local nxt = 1
      for i, m in ipairs(seq) do if m == os8_mode then nxt = (i % #seq) + 1 end end
      os8_set(seq[nxt])
    elseif page == 8 then
      os8_bank = {} ; os8_rec_n = 0
    elseif page == 9 then
      midi_impro_on = not midi_impro_on
    elseif page == 10 then
      midi_poto_on = not midi_poto_on
    elseif page == 11 then
      midi_8os_on = not midi_8os_on
    end
  end
  redraw()
end

---------------------------------------------------------------------
-- ecran
---------------------------------------------------------------------
function redraw()
  screen.clear()
  screen.aa(0)

  if splash_active then
    screen.font_size(16)
    screen.level(15)
    screen.move(2, 24)
    screen.text("TEAMMATE")
    screen.level(8)
    screen.move(2, 44)
    screen.text(".POTO")
    screen.level(2)
    screen.font_size(8)
    screen.move(2, 58)
    screen.text("norns / nsdos 2026")
    screen.level(3)
    screen.move(0, 30) ; screen.line(128, 30) ; screen.stroke()
    screen.update()
    return
  end

  screen.font_size(8)




  -- ligne 1 : etat | strategie (abbrev) | page | dot rec
  local STRAT_ABB = {
    IMITATION="IMIT", CONTRASTE="CNTR", DENSIFICATION="DENS",
    SPARSE="SPRS", SILENCE="SIL", ["---"]="---"
  }
  screen.level(15)
  screen.move(0, 8)
  screen.text(state)

  screen.level(state == "THINK" and 15 or 5)
  screen.move(40, 8)
  screen.text(STRAT_ABB[strat_name] or strat_name)

  screen.level(5)
  screen.move(100, 8)
  screen.text(page .. "/12")

  if rec_on then
    screen.level(15)
    screen.circle(124, 5, 3)
    screen.fill()
  end

  -- ligne 2 : corpus | silence / fragment
  screen.level(5)
  screen.move(0, 18)
  screen.text(string.format("c:%d/%d", count, CORPUS_SLOTS))

  if #phrase_buf > 0 then
    screen.level(10)
    screen.move(52, 18)
    screen.text("+" .. #phrase_buf)
  elseif sil_sec > 0.5 then
    screen.level(4)
    screen.move(52, 18)
    screen.text(string.format("%.1fs", sil_sec))
  end


  -- barre RMS
  screen.level(4)
  screen.move(0, 27)
  screen.text(string.format("in %.3f", cur_rms))
  local bw = math.min(math.floor(rms_smooth * 400), 96)
  screen.level(cur_gate > 0.5 and 12 or 4)
  screen.rect(32, 22, bw, 4)
  screen.fill()

  -- timbre live / portrait fragment
  screen.level(4)
  screen.move(0, 37)
  if phrase_analysis then
    screen.text(string.format("ph rms%.2f  %devs/s",
      phrase_analysis.rms,
      math.floor(phrase_analysis.density)))
  else
    screen.text(string.format("ctr %dkHz  flat %d%%",
      math.floor(cur_centroid / 1000),
      math.floor(cur_flatness * 100)))
  end
  -- indicateurs de mode sur la meme ligne, a droite
  if p_voice or p_deaf then
    screen.level(12)
    screen.move(104, 37)
    screen.text((p_voice and "V" or "") .. (p_deaf and "D" or ""))
  end

  -- separator
  screen.level(2)
  screen.move(0, 41) ; screen.line(128, 41) ; screen.stroke()

  -- parametres specifiques a la page
  if page == 1 then
    -- CORPUS : grille + learn + seuil
    local rec_pct = math.floor(p_rec_prob * 100)
    screen.level(rec_pct == 0 and 15 or 10)
    screen.move(0, 44)
    screen.text(rec_pct == 0 and "E2 FROZEN" or string.format("E2 learn %d%%", rec_pct))
    screen.level(5)
    screen.move(72, 44)
    screen.text(string.format("E3 thr %.3f", p_gate_thr))
    screen.level(7)
    screen.move(0, 50)
    screen.text(string.format("corpus %d/%d", count, CORPUS_SLOTS))
    screen.level(3)
    screen.move(96, 50)
    screen.text("K3:clr")
    for i = 1, CORPUS_SLOTS do
      local col = (i - 1) % 16
      local row = math.floor((i - 1) / 16)
      local x   = col * 8
      local y   = 53 + row * 4
      if corpus[i] then
        local lv = math.min(math.floor(corpus[i].rms * 200) + 5, 15)
        screen.level(lv)
      else
        screen.level(2)
      end
      screen.rect(x, y, 6, 3)
      screen.fill()
    end

  elseif page == 2 then
    screen.level(10)
    screen.move(0, 57)
    screen.text(string.format("E2 density %d%%", math.floor(p_density * 100)))
    screen.move(0, 64)
    screen.text(string.format("E3 silence %d%%", math.floor(p_sil_bias * 100)))
    screen.level(3)
    screen.move(90, 64) ; screen.text("K3:go")

  elseif page == 3 then
    screen.level(10)
    screen.move(0, 57)
    screen.text(string.format("E2 contrast %d%%  E3 reply %d%%",
      math.floor(p_contrast * 100), math.floor(p_reply * 100)))
    screen.level(p_deaf and 12 or 5)
    screen.move(0, 64)
    screen.text(string.format("K3 deaf  %s", p_deaf and "ON" or "off"))

  elseif page == 4 then
    screen.level(10)
    screen.move(0, 57)
    screen.text(string.format("E2 react %.1fs  E3 init %.1fs", p_sil_min, p_sil_max))
    screen.level(p_voice and 12 or 5)
    screen.move(0, 64)
    screen.text(string.format("K3 voice %s", p_voice and "ON" or "off"))

  elseif page == 5 then
    screen.level(p_poto_on and 12 or 5)
    screen.move(0, 57)
    screen.text(string.format("K3 POtO %s  E2 %d%%",
      p_poto_on and "ON" or "off", math.floor(p_poto_vol * 100)))
    screen.level(p_monitor > 0 and 10 or 5)
    screen.move(0, 64)
    screen.text(string.format("E3 monitor %d%%", math.floor(p_monitor * 100)))

  elseif page == 6 then
    screen.level(p_poto_on and 10 or 5)
    screen.move(0, 57)
    screen.text(string.format("E2 grain %dms  E3 sprd %d%%",
      math.floor(p_poto_size * 1000),
      math.floor(p_poto_spread * 100)))
    screen.move(0, 64)
    screen.text(string.format("K3 rate x%.2f", p_poto_rate))

  elseif page == 7 then
    local col = os8_mode == "TRANS" and 15 or (os8_mode == "REC" and 12 or 5)
    screen.level(col)
    screen.font_size(16)
    screen.move(0, 56)
    screen.text(os8_mode)
    screen.font_size(8)
    screen.level(5)
    screen.move(60, 50)
    screen.text(string.format("bank %d", os8_rec_n))
    screen.move(60, 57)
    screen.text(string.format("vol  %d%%", math.floor(os8_vol * 100)))
    screen.move(60, 64)
    if os8_mode == "TRANS" then
      local note_names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
      local ln = cur_note_class()
      screen.text("note " .. (ln >= 0 and note_names[ln + 1] or "--"))
    else
      screen.text(string.format("sz  %dms", math.floor(os8_size * 1000)))
    end

  elseif page == 8 then
    screen.level(os8_rec_n > 0 and 12 or 5)
    screen.move(0, 57)
    screen.text(string.format("8OS bank  %d grains", os8_rec_n))
    screen.level(5)
    screen.move(0, 64)
    screen.text("K3 : clear bank")

  elseif page == 9 then
    screen.level(midi_impro_on and 15 or 8)
    screen.move(0, 50)
    screen.text(string.format("MIDI IMPRO  %s", midi_impro_on and "ON" or "off"))
    screen.level(10)
    screen.move(0, 57)
    screen.text(string.format("E2 ch %d   E3 dev %d", midi_impro_ch, midi_dev_impro))
    screen.level(7)
    screen.move(0, 64)
    screen.text("K3 on/off")

  elseif page == 10 then
    screen.level(midi_poto_on and 15 or 8)
    screen.move(0, 50)
    screen.text(string.format("MIDI POTO  %s", midi_poto_on and "ON" or "off"))
    screen.level(10)
    screen.move(0, 57)
    screen.text(string.format("E2 ch %d   E3 dev %d", midi_poto_ch, midi_dev_poto))
    screen.level(7)
    screen.move(0, 64)
    screen.text("K3 on/off")

  elseif page == 11 then
    screen.level(midi_8os_on and 15 or 8)
    screen.move(0, 50)
    screen.text(string.format("MIDI 8OS  %s", midi_8os_on and "ON" or "off"))
    screen.level(10)
    screen.move(0, 57)
    screen.text(string.format("E2 ch %d   E3 dev %d", midi_8os_ch, midi_dev_8os))
    screen.level(7)
    screen.move(0, 64)
    screen.text("K3 on/off")
  end

  -- dots de page (11 points)
  for i = 1, 11 do
    screen.level(i == page and 12 or 3)
    screen.circle(39 + (i - 1) * 5, 62, 1)
    screen.fill()
  end

  screen.update()
end
