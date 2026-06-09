--  48.816113, 2.410577
-- ḫe₂-a-ni-ì-du₁₀-ga-zu-ne
-- ki-tuš-a-ni-ir
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
local p_rhythm_idx  = 2
local RHYTHM_RATES  = {0, 0.15, 0.30, 0.50}
local p_rhythm      = RHYTHM_RATES[p_rhythm_idx]
local p_poto_on     = false
local p_poto_vol    = 0.5
local p_poto_rate   = 1.0    -- vitesse lecture grain (0.5-2.0)
local p_poto_spread = 0.05   -- ecart detune entre voix (0.0-0.30)
local p_poto_size   = 0.15   -- taille grain en secondes (0.05-0.40)
local p_monitor          = 1.0
local p_poto_smrt_sens   = 0.5   -- sensibilité SMRT : 0=sourd, 1=très réactif

-- modes polyphoniques POtO : multiplicateurs de rate [lead, attracted, repulsed]
-- nil = garder la logique spread d'origine
local POTO_POLY_RATES = {
  {1.0, nil,   nil  },   -- 1 MONO  : spread
  {1.0, 1.498, 0.5  },   -- 2 5th   : fondamentale + quinte + octave basse
  {1.0, 1.260, 1.498},   -- 3 CHRD  : root + tierce majeure + quinte
  {1.0, 1.059, 0.944},   -- 4 CLST  : cluster serre +1st / -1st (effet vocoder)
}
local POTO_POLY_NAMES = {"MONO", "5th", "CHRD", "CLST", "SMRT"}
local p_poto_poly = 1

-- 8OS : sampler grain avec matching pitch/timbre temps reel
-- mutually exclusive avec POtO (memes voix V3,V4,V5,V6)
local OS8_OFFSET  = 200.0   -- zone buffer (apres corpus 96s et POtO 104s)
local OS8_DUR     = 20.0    -- 20s de buffer
local OS8_MAX     = 64      -- grains max
local os8_mode    = "OFF"   -- OFF / REC / TRANS
local os8_sync    = false   -- sync grains TRANS sur clock Norns
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

---------------------------------------------------------------------
-- MIDI GEN
---------------------------------------------------------------------
local MGEN_SCALE_NAMES = {"MINOR","PHRYG","BLUES","DORIC","MAJOR","PENMIN","PENMAJ"}
local MGEN_SCALES = {
  MINOR  = {0,2,3,5,7,8,10},
  PHRYG  = {0,1,3,5,7,8,10},
  BLUES  = {0,3,5,6,7,10},
  DORIC  = {0,2,3,5,7,9,10},
  MAJOR  = {0,2,4,5,7,9,11},
  PENMIN = {0,3,5,7,10},
  PENMAJ = {0,2,4,7,9},
}
local MGEN_STYLE_NAMES = {"TECHNO","DnB","JUNGLE","AMAPIANO","2STEP","BRKN","DUMB","TRAP","DRIL","CLUB","KPOP","ORNTL","RAVE","TRNCE"}
local MGEN_STYLE_DEF = {
  TECHNO   = { steps=16, density=0.50, oct_lo=2, oct_hi=4,
               intervals={0,0,2,3,5,7}, gate=0.45,
               vel=function(s)
                 if s%4==1 then return math.random(100,127)
                 elseif s%2==1 then return math.random(70,95)
                 else return math.random(50,75) end
               end },
  DnB      = { steps=32, density=0.35, oct_lo=2, oct_hi=4,
               intervals={0,2,3,5,7,12}, gate=0.28,
               vel=function(s)
                 return s%8==1 and math.random(100,127) or math.random(60,100)
               end },
  JUNGLE   = { steps=32, density=0.42, oct_lo=2, oct_hi=5,
               intervals={0,1,2,3,5,7,10}, gate=0.22,
               vel=function(s) return math.random(55,115) end },
  AMAPIANO = { steps=16, density=0.55, oct_lo=3, oct_hi=5,
               intervals={0,2,4,5,7,9}, gate=0.65,
               vel=function(s)
                 if s%4==1 then return math.random(90,120)
                 elseif s%4==3 then return math.random(75,100)
                 else return math.random(55,85) end
               end },
  -- 2-step garage : syncopation off-beat, intervalles soulful
  ["2STEP"]  = { steps=32, density=0.35, oct_lo=2, oct_hi=4,
               intervals={0,2,3,5,7,10}, gate=0.32,
               vel=function(s)
                 if s%8==3 or s%8==7 then return math.random(90,118)
                 elseif s%16==1      then return math.random(78,105)
                 else                     return math.random(45,72) end
               end },
  -- brokenbeat : jazz, evite le downbeat, placement irregulier
  BRKN       = { steps=32, density=0.27, oct_lo=3, oct_hi=5,
               intervals={0,2,4,5,7,9,11,14}, gate=0.58,
               vel=function(s) return math.random(52,112) end },
  -- dumbstep : dubstep half-time, tres sparse, bass lourde
  DUMB       = { steps=32, density=0.20, oct_lo=3, oct_hi=4,
               intervals={0,0,0,5,12}, gate=0.78,
               vel=function(s)
                 if s==1 or s==17 then return math.random(108,127)
                 else return math.random(50,82) end
               end },
  -- trap : 808 sparse, gate court, accents kick 1 et contretemps
  TRAP       = { steps=32, density=0.18, oct_lo=3, oct_hi=5,
               intervals={0,0,2,3,5,7}, gate=0.14,
               vel=function(s)
                 if s%32==1   then return math.random(105,127)
                 elseif s%16==9 then return math.random(80,105)
                 else            return math.random(38,78) end
               end },
  -- drill : chromatique sombre, 808 syncopee, registre moyen
  DRIL       = { steps=32, density=0.28, oct_lo=3, oct_hi=5,
               intervals={0,1,2,3,5,7}, gate=0.18,
               vel=function(s)
                 if s%16==1  then return math.random(100,127)
                 elseif s%8==5 then return math.random(68,95)
                 else            return math.random(38,73) end
               end },
  CLUB       = { steps=16, density=0.62, oct_lo=3, oct_hi=5,
               intervals={0,2,4,5,7,9,12}, gate=0.72,
               vel=function(s)
                 if s%4==1 then return math.random(100,120)
                 elseif s%2==1 then return math.random(75,95)
                 else return math.random(55,78) end
               end },
  KPOP       = { steps=32, density=0.60, oct_lo=3, oct_hi=5,
               intervals={0,2,4,7,9,12,14}, gate=0.48,
               vel=function(s)
                 if s%8==1 then return math.random(100,120)
                 elseif s%4==3 then return math.random(80,105)
                 else return math.random(58,82) end
               end },
  ORNTL      = { steps=16, density=0.45, oct_lo=3, oct_hi=5,
               intervals={0,1,3,5,6,8,11}, gate=0.35,
               vel=function(s)
                 return s%4==1 and math.random(95,120) or math.random(48,88)
               end },
  RAVE       = { steps=32, density=0.42, oct_lo=2, oct_hi=4,
               intervals={0,0,0,3,5,7,12}, gate=0.14,
               vel=function(s)
                 if s%16==1 then return math.random(118,127)
                 elseif s%8==1 then return math.random(90,115)
                 else return math.random(52,82) end
               end },
  TRNCE      = { steps=16, density=0.70, oct_lo=3, oct_hi=5,
               intervals={0,2,4,7,9,12}, gate=0.55,
               vel=function(s)
                 if s%4==1 then return math.random(95,118)
                 elseif s%2==0 then return math.random(72,95)
                 else return math.random(58,78) end
               end },
}
local MGEN_BREAK_NAMES = {
  "RAND","ACNT","STUT",
  "LP1","LP2","LP3","LP4",
  "-OCT","+OCT","REV",
  "F32","F16","F8","F4",
  "CHOS","DRNK","SKIP",
}
local MGEN_BREAK_DESCS = {
  "random step","all notes max vel","loop 2 + gate/2",
  "loop step 1","loop 2 steps","loop 3 steps","loop 4 steps",
  "-1 octave","+1 octave","seq backward",
  "32nd flood","16th flood","8th legato","4th legato",
  "random note","drunk ±2 steps","odd steps only",
}

local mgen_running   = false
local mgen_bpm       = 128
local mgen_scale_idx = 1
local mgen_root      = 60   -- C4 fixe
local mgen_sel_ch    = 1
local mgen_break_idx = 1
local mgen_clock_co  = nil
local mgen_gen_id    = 0
local mgen_tap_times = {}   -- tap tempo : horodatages des derniers taps
local mgen_mut_idx   = 3
local MGEN_MUT_RATES = {0, 0.05, 0.12, 0.22, 0.40}
local mgen_mut_rate  = MGEN_MUT_RATES[mgen_mut_idx]
local mclk_t           = {}   -- MIDI clock in : horodatages des pulses recus
local mclk_active      = false
local mclk_pulse_count = 0    -- compteur brut de pulses 0xF8 recus

local mgen_ch = {}
for i = 1, 16 do
  mgen_ch[i] = {
    on        = false,
    style_idx = 1,
    octave    = 3,
    steps     = 16,
    seq       = {},
    midi_ch   = i,
    step_cur  = 1,
    brk       = false,
    brk_type  = 1,
  }
end

local splash_active = false

-- MIDI routing [stream 1-4][device 1-4] : 1=IMPRO 2=POtO 3=8OS 4=MGEN
local midi_outs  = {}
local midi_route = {{false,false,false,false},{false,false,false,false},{false,false,false,false},{false,false,false,false},{false,false,false,false}}
local midi_ch    = {{1,1,1,1},{2,2,2,2},{3,3,3,3}}  -- canal par stream x device (streams 1-3)
local midi_cur_stream    = 1   -- stream selectionne sur pages 9-12
local midi_cur_dev       = 1   -- inutilise (ancienne nav colonne)
local midi_ch_audio      = {5,5,5,5}  -- canal par device pour stream AUDIO
midi_route[6] = {false, false, false, false}   -- METABO = stream 6 (matrice de routage)
midi_ch[6]    = {16, 16, 16, 16}               -- canal METABO par device
metabo_cur_dev = 1                              -- device selectionne (page 19 METABO MIDI ; global)
midi_route[7] = {false, false, false, false}   -- NIAKABY = stream 7 (accords MIDI)
midi_ch[7]    = {7, 7, 7, 7}                    -- canal NIAKABY par device
niaka_cur_dev = 1                               -- device selectionne (page 23 NIAKABY MIDI ; global)
local midi_audio_cur_dev = 1          -- device selectionne sur page 16
local midi_audio_note    = nil        -- note MIDI audio active courante

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

local function midi_note_on(stream, note, vel)
  for d = 1, 4 do
    if midi_route[stream][d] and midi_outs[d] then
      midi_outs[d]:note_on(note, vel, midi_ch[stream][d])
    end
  end
end
local function midi_note_off(stream, note)
  for d = 1, 4 do
    if midi_route[stream][d] and midi_outs[d] then
      midi_outs[d]:note_off(note, 0, midi_ch[stream][d])
    end
  end
end
local function midi_cc_all(stream, cc, val)
  for d = 1, 4 do
    if midi_route[stream][d] and midi_outs[d] then
      midi_outs[d]:cc(cc, val, midi_ch[stream][d])
    end
  end
end
local function audio_midi_note_on(note, vel)
  for d = 1, 4 do
    if midi_route[5][d] and midi_outs[d] then
      midi_outs[d]:note_on(note, vel, midi_ch_audio[d])
    end
  end
end
local function audio_midi_note_off(note)
  for d = 1, 4 do
    if midi_route[5][d] and midi_outs[d] then
      midi_outs[d]:note_off(note, 0, midi_ch_audio[d])
    end
  end
end

---------------------------------------------------------------------
-- SPAT : declarations (fonctions definies plus bas, apres poto_set)
---------------------------------------------------------------------
local TAU        = math.pi * 2
local SPAT_MODES = {"NEBULA","ORBIT","PULSAR","QUANTUM","STRANGE","ENTANGLE"}
local spat = {
  mode = 1, mass = 0.6, tempo = 0.4, on = false, co = nil,
  DT   = 0.08,
  -- impro/lead/av/rv = corpus + POtO ; o5/o6/o3 = 8OS (trajectoires propres)
  KEYS = {"impro","lead","av","rv","o5","o6","o3"},
  az   = {impro=0.0, lead=0.0, av=0.0, rv=0.0, o5=0.0, o6=0.0, o3=0.0},
  dz   = {impro=0.0, lead=0.3, av=-0.2, rv=0.5, o5=0.2, o6=-0.3, o3=0.4},
  s    = {
    neb_vel = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
    orb_th  = {0.0, TAU*0.16, TAU*0.49, TAU*0.83, TAU*0.30, TAU*0.62, TAU*0.95},
    puls_t  = 0.0,
    q_tgt   = {0.0, 0.3, -0.5, 0.7, -0.3, 0.5, -0.7},
    q_lerp  = {1.0, 1.0,  1.0, 1.0, 1.0, 1.0, 1.0},
    lx=0.1, ly=0.0, lz=20.0,
    lx2=1.5, ly2=0.8, lz2=19.5,
    ent_th  = 0.0,
    dz_vel  = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
  }
}
local spat_depth_mult  -- forward ref : definie apres poto_set
local spat_eff_pan     -- forward ref

-- METABO « feed COMP » : ce que joue le compagnon nourrit la cellule.
-- Variables + fonction en GLOBAL (evite la limite de locals du chunk).
comp_rms = 0 ; comp_freq = 0 ; comp_centroid = 0 ; comp_flatness = 0
meta_freq = 0 ; meta_energy = 0   -- derniere note de METABO (pour alimenter NIAKABY)
mgen_nfreq = 0 ; mgen_nenergy = 0 -- derniere note de MGEN (pour alimenter NIAKABY)
function companion_feed(rms, freq, centroid, flatness)
  if (rms or 0) > comp_rms then comp_rms = rms end        -- attaque (le decay est dans la boucle metabo)
  if freq and freq > 0 then comp_freq = freq end
  if centroid and centroid > 0 then comp_centroid = centroid end
  if flatness then comp_flatness = flatness end
end

local function play_event(ev, rate_mult)
  local vi  = ply_idx
  local v   = PLY_V[vi]
  ply_idx   = (ply_idx % #PLY_V) + 1
  ply_tokens[vi] = ply_tokens[vi] + 1
  local tok = ply_tokens[vi]

  -- pre-silence uniquement si voix unique (POtO actif)
  if #PLY_V == 1 then
    softcut.play(v, 0)
    clock.sleep(0.022)
  end

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

  softcut.level(v, spat.on and spat_depth_mult("impro") or 1.0)
  if spat.on then softcut.pan(v, spat_eff_pan("impro")) end
  softcut.loop(v, 0)
  softcut.loop_start(v, base)
  softcut.loop_end(v, base + len)

  if math.random() < REV_PROB then
    rate = -1.0
    softcut.position(v, base + len - 0.001)
  else
    softcut.position(v, base)
  end

  softcut.fade_time(v, math.min(0.050, len * 0.18))
  softcut.rate(v, rate * rate_mult)
  softcut.play(v, 1)

  local f = ev.freq > 0 and ev.freq or cur_freq
  local imp_note = freq_to_midi(f) or 60
  local imp_vel  = math.max(1, math.min(127, math.floor(ev.rms * 800)))
  midi_note_on(1, imp_note, imp_vel)
  companion_feed(ev.rms, f, ev.centroid, ev.flatness)   -- nourrit METABO (mode COMP)

  clock.run(function()
    clock.sleep(math.max(0.04, len - 0.025))
    midi_note_off(1, imp_note)
    if ply_tokens[vi] == tok then
      softcut.play(v, 0)
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
      softcut.play(v, 0)
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
      softcut.loop(v, 0)
      softcut.level(v, 0)
      softcut.rate(v, 1.0)
      softcut.fade_time(v, 0.02)
      softcut.level_slew_time(v, 0.01)   -- enveloppe volume = attaque/release doux (anti-clic)
    end
    os8_pos_v5 = nil ; os8_pos_v6 = nil ; os8_pos_v3 = nil

    -- sleep interruptible : sort des que le gate tombe ou que le mode change
    -- si os8_sync : quantize au prochain 1/16 sur la clock active
    local function grain_sleep(dur)
      if os8_sync then
        clock.sleep(60.0 / mgen_bpm / 4)   -- suit le BPM du MGEN
      else
        local t = 0
        while t < dur and os8_mode == "TRANS" and cur_gate > 0.5 do
          local step = math.min(0.02, dur - t)
          clock.sleep(step) ; t = t + step
        end
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
            softcut.fade_time(5, math.min(0.02, gs * 0.5))
            softcut.loop(5, 1)                              -- boucle le grain (crossfade aux bornes)
            softcut.loop_start(5, g.pos)
            softcut.loop_end(5,   g.pos + gs)
            softcut.position(5, g.pos)
            softcut.rate(5, 1.0)
            softcut.play(5, 1)
            softcut.level(5, os8_vol)                       -- attaque douce (slew)
            local n5 = freq_to_midi(g.pitch)
            if n5 then midi_note_on(3, n5, math.floor(os8_vol * 127)) end
            grain_sleep(math.max(0.04, gs - 0.02))
            softcut.level(5, 0)                             -- release doux -> pas de clic
            if n5 then midi_note_off(3, n5) end
            clock.sleep(0.02) ; softcut.play(5, 0) ; clock.sleep(0.02)
          else
            clock.sleep(0.05)
          end
        else
          softcut.play(5, 0)
          clock.sleep(0.05)
        end
      end
      softcut.play(5, 0)
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
            softcut.fade_time(6, math.min(0.02, gs * 0.5))
            softcut.loop(6, 1)
            softcut.loop_start(6, g.pos)
            softcut.loop_end(6,   g.pos + gs)
            softcut.position(6, g.pos)
            softcut.rate(6, 1.0)
            softcut.play(6, 1)
            softcut.level(6, os8_vol * 0.65)               -- attaque douce (slew)
            local n6 = freq_to_midi(g.pitch)
            if n6 then midi_note_on(3, n6, math.floor(os8_vol * 83)) end
            grain_sleep(math.max(0.04, gs - 0.02))
            softcut.level(6, 0)                            -- release doux
            if n6 then midi_note_off(3, n6) end
            clock.sleep(0.02) ; softcut.play(6, 0) ; clock.sleep(0.02)
          else
            clock.sleep(0.05)
          end
        else
          softcut.play(6, 0)
          clock.sleep(0.05)
        end
      end
      softcut.play(6, 0)
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
            softcut.fade_time(3, math.min(0.02, gs * 0.5))
            softcut.loop(3, 1)
            softcut.loop_start(3, g.pos)
            softcut.loop_end(3,   g.pos + gs)
            softcut.position(3, g.pos)
            softcut.rate(3, 1.0)
            softcut.play(3, 1)
            softcut.level(3, os8_vol * 0.40)               -- attaque douce (slew)
            local n3 = freq_to_midi(g.pitch)
            if n3 then midi_note_on(3, n3, math.floor(os8_vol * 51)) end
            grain_sleep(math.max(0.04, gs - 0.02))
            softcut.level(3, 0)                            -- release doux
            if n3 then midi_note_off(3, n3) end
            clock.sleep(0.02) ; softcut.play(3, 0) ; clock.sleep(0.02)
          else
            clock.sleep(0.05)
          end
        else
          softcut.play(3, 0)
          clock.sleep(0.05)
        end
      end
      softcut.play(3, 0)
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

-- Mode SMRT : hystérèse sur la détection de technique de jeu
-- Inspiré de la section 3.2 du papier Fiorini & Brochec (SMC 2024) :
-- ne basculer vers une nouvelle catégorie que si elle est soutenue ~300ms
-- (SMRT_HOLD_N ticks × p_poto_size ≈ 2 × 150ms = 300ms par défaut)
local poto_smrt_tech = "TONAL"   -- technique confirmée (change avec délai)
local poto_smrt_cand = "TONAL"   -- candidat en attente de confirmation
local poto_smrt_hold = 0         -- ticks consécutifs pour le candidat
local SMRT_HOLD_N    = 2         -- ticks nécessaires pour confirmer un changement

-- Détection brute instantanée (jamais appelée directement hors de poto_smrt_update)
local function poto_detect_raw()
  if cur_gate < 0.3 or cur_rms < 0.005 then return "WHSPR" end
  local f          = math.min(1.0, cur_flatness)
  local b          = cur_centroid / math.max(cur_freq, 50)
  local flat_thr   = 0.30 + (1.0 - p_poto_smrt_sens) * 0.50
  local bright_thr = 2.0  + (1.0 - p_poto_smrt_sens) * 4.0
  if f > flat_thr   then return "NOISY" end
  if b > bright_thr then return "BRGHT" end
  return "TONAL"
end

-- Mise à jour de l'hystérèse — appelée une fois par cycle grain (boucle LEAD)
local function poto_smrt_update()
  local raw = poto_detect_raw()
  if raw == poto_smrt_tech then
    poto_smrt_cand = raw ; poto_smrt_hold = 0
  elseif raw == poto_smrt_cand then
    poto_smrt_hold = poto_smrt_hold + 1
    if poto_smrt_hold >= SMRT_HOLD_N then
      poto_smrt_tech = poto_smrt_cand ; poto_smrt_hold = 0
    end
  else
    poto_smrt_cand = raw ; poto_smrt_hold = 1
  end
end

-- Paramètres grain basés sur la technique *confirmée* (lecture seule, sans effet de bord)
local function poto_smart_params()
  local tech = poto_smrt_tech
  if tech == "WHSPR" then
    return {r2=1.122, r3=0.891, size=math.max(0.05, p_poto_size*0.60),
            av_lv=0.50, rv_lv=0.22, tech="WHSPR"}
  elseif tech == "NOISY" then
    local spread = 0.04 + math.min(1.0, cur_flatness) * 0.06
    return {r2=1.0+spread, r3=math.max(0.5, 1.0-spread*0.6),
            size=math.min(0.40, p_poto_size*1.40),
            av_lv=0.58, rv_lv=0.52, tech="NOISY"}
  elseif tech == "BRGHT" then
    return {r2=1.498, r3=1.260, size=p_poto_size,
            av_lv=0.65, rv_lv=0.44, tech="BRGHT"}
  else
    return {r2=1.260, r3=0.794, size=math.max(0.05, p_poto_size*0.80),
            av_lv=0.72, rv_lv=0.36, tech="TONAL"}
  end
end


local function poto_set(on)
  if on == p_poto_on then return end
  -- POtO et 8OS sont mutuellement exclusifs
  if on and os8_mode ~= "OFF" then os8_set("OFF") end
  p_poto_on = on

  if on then
    -- V3 emprunte : une seule voix corpus pendant POtO
    PLY_V = {2} ; ply_idx = 1
    softcut.play(3, 0)

    poto_lead_zone = 0.0

    local lv = POTO_PLY_V[1]   -- V5 LEAD
    local av = POTO_PLY_V[2]   -- V6 ATTRACTED
    local rv = 3                -- V3 REPULSED

    for _, v in ipairs({lv, av, rv}) do
      softcut.buffer(v, 1)
      softcut.loop(v, 0)
      softcut.play(v, 0)
      softcut.rate(v, 1.0)
      softcut.fade_time(v, 0.02)
    end

    -- LEAD : colle a la zone la plus fraiche (< 100ms du present)
    clock.run(function()
      local zone   = 0.0
      local active = false
      while p_poto_on do
        if p_poto_poly == 5 then poto_smrt_update() end
        local gs  = (p_poto_poly == 5) and poto_smart_params().size or p_poto_size
        local wp  = poto_write_pos_rel()
        local tgt = (wp - 0.10 + POTO_DUR) % POTO_DUR
        zone = (zone * 0.85 + tgt * 0.15) % POTO_DUR
        if zone + gs > POTO_DUR then zone = POTO_DUR - gs - 0.01 end
        poto_lead_zone = zone
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > gs + 0.05 then
          local bp = POTO_OFFSET + zone
          local ft = math.min(0.020, gs * 0.15)
          softcut.fade_time(lv, ft)
          softcut.loop_start(lv, bp)
          softcut.loop_end(lv, bp + gs)
          softcut.level(lv, p_poto_vol * (spat.on and spat_depth_mult("lead") or 1.0))
          if spat.on then softcut.pan(lv, spat_eff_pan("lead")) end
          if not active then
            softcut.loop(lv, 1)
            softcut.position(lv, bp)
            softcut.rate(lv, p_poto_rate)
            softcut.play(lv, 1)
            active = true
          end
          local pn_lv = cur_freq > 0 and freq_to_midi(cur_freq) or nil
          if pn_lv then midi_note_on(2, pn_lv, math.floor(p_poto_vol * 127)) end
          clock.sleep(gs)
          if pn_lv then midi_note_off(2, pn_lv) end
        else
          if active then softcut.play(lv, 0) ; active = false end
          clock.sleep(gs)
        end
      end
      if active then softcut.play(lv, 0) end
    end)

    -- ATTRACTED : derive lentement vers la zone LEAD
    clock.run(function()
      local zone   = POTO_DUR * 0.25
      local active = false
      while p_poto_on do
        local wp  = poto_write_pos_rel()
        local tgt = (poto_lead_zone - 0.05 + POTO_DUR) % POTO_DUR
        zone = (zone * 0.92 + tgt * 0.08) % POTO_DUR
        if zone + p_poto_size > POTO_DUR then zone = POTO_DUR - p_poto_size - 0.01 end
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > p_poto_size + 0.05 then
          local bp = POTO_OFFSET + zone
          local r_av, av_vol_mult
          if p_poto_poly == 5 then
            local sp = poto_smart_params()
            r_av = p_poto_rate * sp.r2 ; av_vol_mult = sp.av_lv
          else
            local tbl = POTO_POLY_RATES[p_poto_poly][2]
            r_av = tbl and (p_poto_rate * tbl) or (p_poto_rate * (1 + p_poto_spread))
            av_vol_mult = 0.65
          end
          local ft = math.min(0.020, p_poto_size * 0.15)
          softcut.fade_time(av, ft)
          softcut.loop_start(av, bp)
          softcut.loop_end(av, bp + p_poto_size)
          softcut.level(av, p_poto_vol * av_vol_mult * (spat.on and spat_depth_mult("av") or 1.0))
          if spat.on then softcut.pan(av, spat_eff_pan("av")) end
          if not active then
            softcut.loop(av, 1)
            softcut.position(av, bp)
            softcut.rate(av, r_av)
            softcut.play(av, 1)
            active = true
          else
            softcut.rate(av, r_av)
          end
          local pn_av = cur_freq > 0 and freq_to_midi(cur_freq) or nil
          if pn_av then midi_note_on(2, pn_av, math.floor(p_poto_vol * 83)) end
          clock.sleep(p_poto_size)
          if pn_av then midi_note_off(2, pn_av) end
        else
          if active then softcut.play(av, 0) ; active = false end
          clock.sleep(p_poto_size + 0.03)
        end
      end
      if active then softcut.play(av, 0) end
    end)

    -- REPULSED : pousse vers le cote oppose de LEAD dans le buffer
    clock.run(function()
      local zone   = POTO_DUR * 0.5
      local active = false
      while p_poto_on do
        local wp  = poto_write_pos_rel()
        local tgt = (poto_lead_zone + POTO_DUR * 0.5) % POTO_DUR
        zone = (zone * 0.95 + tgt * 0.05) % POTO_DUR
        if zone + p_poto_size > POTO_DUR then zone = POTO_DUR - p_poto_size - 0.01 end
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > p_poto_size + 0.05 then
          local bp = POTO_OFFSET + zone
          local r_rv, rv_vol_mult
          if p_poto_poly == 5 then
            local sp = poto_smart_params()
            r_rv = p_poto_rate * sp.r3 ; rv_vol_mult = sp.rv_lv
          else
            local tbl = POTO_POLY_RATES[p_poto_poly][3]
            r_rv = tbl and (p_poto_rate * tbl) or math.max(0.5, p_poto_rate * (1 - p_poto_spread * 2))
            rv_vol_mult = 0.40
          end
          local ft = math.min(0.020, p_poto_size * 0.15)
          softcut.fade_time(rv, ft)
          softcut.loop_start(rv, bp)
          softcut.loop_end(rv, bp + p_poto_size)
          softcut.level(rv, p_poto_vol * rv_vol_mult * (spat.on and spat_depth_mult("rv") or 1.0))
          if spat.on then softcut.pan(rv, spat_eff_pan("rv")) end
          if not active then
            softcut.loop(rv, 1)
            softcut.position(rv, bp)
            softcut.rate(rv, r_rv)
            softcut.play(rv, 1)
            active = true
          else
            softcut.rate(rv, r_rv)
          end
          local pn_rv = cur_freq > 0 and freq_to_midi(cur_freq) or nil
          if pn_rv then midi_note_on(2, pn_rv, math.floor(p_poto_vol * 51)) end
          clock.sleep(p_poto_size)
          if pn_rv then midi_note_off(2, pn_rv) end
        else
          if active then softcut.play(rv, 0) ; active = false end
          clock.sleep(p_poto_size + 0.05)
        end
      end
      if active then softcut.play(rv, 0) end
    end)

  else
    -- arret immediat, les boucles grain s'arretent au prochain tour
    for _, v in ipairs({POTO_PLY_V[1], POTO_PLY_V[2], 3}) do
      softcut.play(v, 0)
      softcut.loop(v, 0)
    end
    if os8_mode == "OFF" then PLY_V = {2, 3} else PLY_V = {2} end
    ply_idx = 1
    softcut.loop(3, 0)
    softcut.fade_time(3, 0.02)
  end
end

---------------------------------------------------------------------
-- SPAT : moteur spatial 6 modes
---------------------------------------------------------------------
spat_depth_mult = function(k)
  return 0.55 + 0.45 * (spat.dz[k] + 1) * 0.5
end

spat_eff_pan = function(k)
  local w = 0.40 + 0.60 * (spat.dz[k] + 1) * 0.5
  return spat.az[k] * w
end

local function spat_apply()
  for _, v in ipairs(PLY_V) do
    softcut.pan(v, spat_eff_pan("impro"))
  end
  if p_poto_on then
    softcut.pan(POTO_PLY_V[1], spat_eff_pan("lead"))
    softcut.pan(POTO_PLY_V[2], spat_eff_pan("av"))
    softcut.pan(3,              spat_eff_pan("rv"))
  elseif os8_mode == "TRANS" then
    -- 8OS : trajectoires SPAT propres (distinctes de POtO)
    softcut.pan(5, spat_eff_pan("o5"))
    softcut.pan(6, spat_eff_pan("o6"))
    softcut.pan(3, spat_eff_pan("o3"))
  end
end

local function spat_update()
  local s    = spat.s
  local dt   = spat.DT
  local keys = spat.KEYS
  local m    = spat.mode
  -- valeurs effectives : modulees par SMRT si POtO SMRT actif
  local mass, tempo = spat.mass, spat.tempo
  if p_poto_on and p_poto_poly == 5 then
    local mm = {WHSPR=0.25, TONAL=0.60, BRGHT=0.90, NOISY=1.0}
    local tm = {WHSPR=0.70, TONAL=0.85, BRGHT=1.00, NOISY=1.15}
    mass  = mass  * (mm[poto_smrt_tech]  or 1.0)
    tempo = tempo * (tm[poto_smrt_tech] or 1.0)
  end

  if m == 1 then  -- NEBULA : brownien avec inertie
    local damp = 1.0 - mass * 0.4
    local kick = tempo * 0.6
    for i, k in ipairs(keys) do
      s.neb_vel[i] = s.neb_vel[i] * damp + (math.random() * 2 - 1) * kick * dt
      spat.az[k]   = math.max(-1, math.min(1, spat.az[k] + s.neb_vel[i]))
      s.dz_vel[i]  = s.dz_vel[i] * damp + (math.random() * 2 - 1) * kick * 0.5 * dt
      spat.dz[k]   = math.max(-1, math.min(1, spat.dz[k] + s.dz_vel[i]))
    end

  elseif m == 2 then  -- ORBIT : keplerienne vitesse 1/r^2
    local spd = tempo * 4.0
    for i, k in ipairs(keys) do
      local r = 0.3 + mass * 0.7 * (0.5 + 0.5 * math.sin(i * 1.3))
      s.orb_th[i] = s.orb_th[i] + (spd / (r * r)) * dt
      spat.az[k]  = math.sin(s.orb_th[i]) * r
      spat.dz[k]  = math.cos(s.orb_th[i]) * r * 0.5
    end

  elseif m == 3 then  -- PULSAR : arc tanh avec dephasages
    local spd = tempo * 5.0
    s.puls_t = s.puls_t + spd * dt
    for i, k in ipairs(keys) do
      local ph = s.puls_t + (i - 1) * (TAU / #keys)
      spat.az[k] = math.tanh(math.sin(ph) * (1 + mass * 3.0))
      spat.dz[k] = math.tanh(math.cos(ph) * mass) * 0.6
    end

  elseif m == 4 then  -- QUANTUM : stable + tunneling RMS
    for i, k in ipairs(keys) do
      local rms_trig = rms_smooth > 0.08 + mass * 0.1
      if rms_trig and s.q_lerp[i] >= 0.98 then
        s.q_tgt[i]  = math.random() * 2 - 1
        s.q_lerp[i] = 0.0
      end
      s.q_lerp[i] = math.min(1.0, s.q_lerp[i] + tempo * dt * 8)
      spat.az[k]  = spat.az[k] + (s.q_tgt[i] - spat.az[k]) * s.q_lerp[i] * dt * 5
      spat.dz[k]  = math.max(-1, math.min(1, spat.dz[k] + (0 - spat.dz[k]) * 0.1))
    end

  elseif m == 5 then  -- STRANGE : double attracteur de Lorenz
    local sig, rho, beta = 10.0, 28.0, 8.0 / 3.0
    local sc  = tempo * 0.5
    local dx  = sig * (s.ly - s.lx)
    local dy  = s.lx * (rho - s.lz) - s.ly
    local dz_ = s.lx * s.ly - beta * s.lz
    s.lx = s.lx + dx * dt * sc
    s.ly = s.ly + dy * dt * sc
    s.lz = s.lz + dz_ * dt * sc
    local dx2 = sig * (s.ly2 - s.lx2)
    local dy2 = s.lx2 * (rho - s.lz2) - s.ly2
    local dz2 = s.lx2 * s.ly2 - beta * s.lz2
    s.lx2 = s.lx2 + dx2 * dt * sc
    s.ly2 = s.ly2 + dy2 * dt * sc
    s.lz2 = s.lz2 + dz2 * dt * sc
    spat.az[keys[1]] = math.tanh(s.lx  * 0.05)
    spat.az[keys[2]] = math.tanh(s.ly  * 0.05)
    spat.az[keys[3]] = math.tanh(s.lx2 * 0.05)
    spat.az[keys[4]] = math.tanh(s.ly2 * 0.05)
    spat.dz[keys[1]] = math.tanh(s.lz  * 0.01 - 1)
    spat.dz[keys[2]] = math.tanh(s.lz  * 0.01 - 1) * 0.7
    spat.dz[keys[3]] = math.tanh(s.lz2 * 0.01 - 1) * 0.5
    spat.dz[keys[4]] = math.tanh(s.lz2 * 0.01 - 1) * 0.3
    -- 8OS : projections distinctes du double attracteur
    spat.az[keys[5]] = math.tanh((s.lx - s.lx2) * 0.04)
    spat.az[keys[6]] = math.tanh((s.ly + s.ly2) * 0.03)
    spat.az[keys[7]] = math.tanh((s.lx2 - s.ly) * 0.04)
    spat.dz[keys[5]] = math.tanh((s.lz + s.lz2) * 0.005 - 1) * 0.4
    spat.dz[keys[6]] = math.tanh(s.lz2 * 0.01 - 1) * 0.6
    spat.dz[keys[7]] = math.tanh(s.lz  * 0.01 - 1) * 0.5

  elseif m == 6 then  -- ENTANGLE : LEAD brownien, ATTRACTED miroir, REPULSED orbite
    local damp = 1.0 - mass * 0.35
    local kick = tempo * 0.7
    s.neb_vel[1] = s.neb_vel[1] * damp + (math.random() * 2 - 1) * kick * dt
    spat.az.lead  = math.max(-1, math.min(1, spat.az.lead + s.neb_vel[1]))
    spat.az.av    = -spat.az.lead
    s.dz_vel[1]   = s.dz_vel[1] * damp + (math.random() * 2 - 1) * kick * 0.3 * dt
    spat.dz.lead  = math.max(-1, math.min(1, spat.dz.lead + s.dz_vel[1]))
    spat.dz.av    = spat.dz.lead
    s.ent_th      = s.ent_th + tempo * 3.0 * dt
    spat.az.rv    = math.sin(s.ent_th) * (0.4 + mass * 0.5)
    spat.dz.rv    = math.cos(s.ent_th * 0.7) * 0.4
    spat.az.impro = spat.az.impro + (spat.az.lead * 0.5 - spat.az.impro) * 0.05
    -- 8OS : trio intrique a part (orbites dephasees)
    spat.az.o5 = math.sin(s.ent_th * 1.3) * (0.4 + mass * 0.4)
    spat.dz.o5 = math.cos(s.ent_th * 1.1) * 0.4
    spat.az.o6 = -spat.az.o5
    spat.dz.o6 = spat.dz.o5
    spat.az.o3 = math.sin(s.ent_th * 0.6 + 1.0) * 0.5
    spat.dz.o3 = math.cos(s.ent_th * 0.5) * 0.4
  end
end

local function spat_stop()
  if spat.co then clock.cancel(spat.co) ; spat.co = nil end
  clock.run(function()
    for step = 1, 6 do
      local t = 1 - step / 6
      for _, k in ipairs(spat.KEYS) do
        spat.az[k] = spat.az[k] * t
        spat.dz[k] = spat.dz[k] * t
      end
      spat_apply()
      clock.sleep(0.08)
    end
    for _, k in ipairs(spat.KEYS) do spat.az[k] = 0 ; spat.dz[k] = 0 end
    spat_apply()
  end)
end

local function spat_start()
  if spat.co then clock.cancel(spat.co) end
  spat.co = clock.run(function()
    while spat.on do
      spat_update()
      spat_apply()
      clock.sleep(spat.DT)
    end
  end)
end

---------------------------------------------------------------------
-- MIDI GEN : sequenceur melodique generatif (pages 13-15)
---------------------------------------------------------------------
local function mgen_gen_seq(ci)
  local ch  = mgen_ch[ci]
  local sn  = MGEN_STYLE_NAMES[ch.style_idx]
  local def = MGEN_STYLE_DEF[sn]
  local sc  = MGEN_SCALES[MGEN_SCALE_NAMES[mgen_scale_idx]]
  -- octave inchange : fixe par gen_all a l'init ou par E3 (page 15)
  ch.steps  = def.steps
  ch.seq    = {}
  local root    = mgen_root + (ch.octave - 4) * 12
  local cur_deg = math.random(#sc)
  for s = 1, def.steps do
    local note = math.max(0, math.min(127, root + sc[cur_deg]))
    table.insert(ch.seq, {
      active = math.random() < def.density,
      note   = note,
      vel    = def.vel(s),
      gate   = def.gate,
    })
    if math.random() < 0.55 then
      local iv = def.intervals[math.random(#def.intervals)]
      if math.random() < 0.5 then iv = -iv end
      local tgt = note + iv
      local bd, bd_d = math.huge, cur_deg
      for d2, semi in ipairs(sc) do
        for o = -2, 2 do
          local nn = root + semi + o * 12
          if math.abs(nn - tgt) < bd then bd = math.abs(nn - tgt) ; bd_d = d2 end
        end
      end
      cur_deg = bd_d
    end
  end
  ch.step_cur = 1
end

local function mgen_gen_all(keep_pos)
  -- soit on RAPPELLE une combinaison aimee (avec une legere variation), soit theme frais diversifie
  local recall = (#mgen_liked > 0 and mgen_recall > 0 and math.random() < mgen_recall) and mgen_liked[math.random(#mgen_liked)] or nil
  for i = 1, 16 do
    local si
    if recall then
      si = recall[i] or math.random(#MGEN_STYLE_NAMES)
      if math.random() < 0.12 then si = math.random(#MGEN_STYLE_NAMES) end   -- variation legere
    else
      si = math.random(#MGEN_STYLE_NAMES)                                    -- vision globale : tous les genres
    end
    local def = MGEN_STYLE_DEF[MGEN_STYLE_NAMES[si]]
    mgen_ch[i].style_idx = si
    -- octave initialise ici (seul endroit), jamais ecrase par gen_seq
    mgen_ch[i].octave = def.oct_lo + math.random(0, def.oct_hi - def.oct_lo)
    local saved = mgen_ch[i].step_cur
    mgen_gen_seq(i)
    if keep_pos then mgen_ch[i].step_cur = math.min(saved, mgen_ch[i].steps) end
  end
end

local function mgen_mutate_seq(ci)
  local ch  = mgen_ch[ci]
  local sn  = MGEN_STYLE_NAMES[ch.style_idx]
  local def = MGEN_STYLE_DEF[sn]
  local sc  = MGEN_SCALES[MGEN_SCALE_NAMES[mgen_scale_idx]]
  for s = 1, #ch.seq do
    if math.random() > mgen_mut_rate then goto next_step end
    local step = ch.seq[s]
    local r = math.random()
    if r < 0.38 then
      step.active = math.random() < def.density
    elseif r < 0.72 then
      local nm = ((step.note - mgen_root) % 12 + 12) % 12
      local bd, bd_deg = math.huge, 1
      for d, semi in ipairs(sc) do
        local dd = math.min(math.abs(semi - nm), math.abs(semi - nm + 12), math.abs(semi - nm - 12))
        if dd < bd then bd = dd ; bd_deg = d end
      end
      local dir = math.random() < 0.5 and 1 or -1
      local nd  = ((bd_deg - 1 + dir) % #sc) + 1
      local oct = math.floor((step.note - mgen_root) / 12)
      step.note = math.max(0, math.min(127, mgen_root + oct * 12 + sc[nd]))
    elseif r < 0.88 then
      step.gate = math.max(0.05, math.min(2.5, step.gate * (0.75 + math.random() * 0.5)))
    else
      step.vel = def.vel(s)
    end
    ::next_step::
  end
end

local function mgen_stop()
  mgen_running = false
  for d = 1, 4 do
    if midi_route[4][d] and midi_outs[d] then
      for mc = 1, 16 do midi_outs[d]:cc(123, 0, mc) end
    end
  end
end

local function mgen_start()
  if mgen_running then return end
  mgen_running = true
  mgen_gen_id  = mgen_gen_id + 1
  local my_id  = mgen_gen_id
  for i = 1, 16 do mgen_ch[i].step_cur = 1 ; mgen_ch[i].brk = false end
  clock.run(function()
    -- si clock externe active, attendre le prochain pulse avant le 1er step
    -- garantit que le debut tombe sur une frontiere de pulse
    if mclk_active then
      local p0 = mclk_pulse_count
      while mclk_pulse_count == p0 and mgen_running and mgen_gen_id == my_id do
        clock.sleep(0.001)
      end
    end
    while mgen_running and mgen_gen_id == my_id do
      local sd = 60.0 / mgen_bpm / 4   -- 1/16 note (pour gate duration)
      for i = 1, 16 do
        local ch = mgen_ch[i]
        if ch.on and #ch.seq > 0 then
          local sv = ch.seq[ch.step_cur]
          if sv then
            local active, note, vel, gate = sv.active, sv.note, sv.vel, sv.gate
            if ch.brk then
              local bt  = ch.brk_type
              local s   = ch.step_cur
              if bt == 1 then          -- RAND : step aleatoire
                local rs = ch.seq[math.random(ch.steps)]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 2 then      -- ACNT : toutes les notes, vel max
                active = true ; vel = math.random(108, 127)
              elseif bt == 3 then      -- STUT : boucle 2 premiers steps, gate reduit
                local rs = ch.seq[(s - 1) % 2 + 1]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
                gate = gate * 0.5
              elseif bt == 4 then      -- LP1 : boucle step 1
                local rs = ch.seq[1]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 5 then      -- LP2 : boucle 2 steps
                local rs = ch.seq[(s - 1) % 2 + 1]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 6 then      -- LP3 : boucle 3 steps
                local rs = ch.seq[(s - 1) % 3 + 1]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 7 then      -- LP4 : boucle 4 steps
                local rs = ch.seq[(s - 1) % 4 + 1]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 8 then      -- -OCT
                note = math.max(0, note - 12)
              elseif bt == 9 then      -- +OCT
                note = math.min(127, note + 12)
              elseif bt == 10 then     -- REV : sequence a l'envers
                local rs = ch.seq[ch.steps - s + 1]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 11 then     -- F32 : flood de croches (gate tres court)
                active = true ; gate = 0.20 ; vel = math.random(75, 115)
              elseif bt == 12 then     -- F16 : flood de doubles croches
                active = true ; gate = 0.52 ; vel = math.random(75, 115)
              elseif bt == 13 then     -- F8 : notes aux temps pairs, gate legato 8th
                if s % 2 == 1 then active = true ; gate = 1.80 ; vel = math.random(80,115)
                else active = false end
              elseif bt == 14 then     -- F4 : notes au quart, gate legato 4th
                if s % 4 == 1 then active = true ; gate = 3.70 ; vel = math.random(85,120)
                else active = false end
              elseif bt == 15 then     -- CHOS : note aleatoire dans la gamme
                local sc = MGEN_SCALES[MGEN_SCALE_NAMES[mgen_scale_idx]]
                local root = mgen_root + (ch.octave - 4) * 12
                note = math.max(0, math.min(127, root + sc[math.random(#sc)]))
              elseif bt == 16 then     -- DRNK : drunk walk +-2 steps
                local si = (s - 1 + math.random(-2, 2) + ch.steps) % ch.steps + 1
                local rs = ch.seq[si]
                if rs then active,note,vel,gate = rs.active,rs.note,rs.vel,rs.gate end
              elseif bt == 17 then     -- SKIP : steps impairs seulement
                if s % 2 == 0 then active = false end
              end
            end
            if active then
              local nn, gd = note, sd * gate
              local mc = ch.midi_ch
              -- METABO impose sa note (recalee gamme MGEN, registre garde) selon meta_note_inf
              if meta_note_inf > 0 and metabolik.on and meta_freq > 30
                 and math.random() < meta_note_inf then
                local cnote = math.floor(69 + 12 * math.log(meta_freq / 440) / math.log(2) + 0.5)
                while cnote < nn - 6 do cnote = cnote + 12 end
                while cnote > nn + 6 do cnote = cnote - 12 end
                nn = mgen_snap(cnote)
              end
              -- capture pour NIAKABY (source MGEN) UNIQUEMENT
              -- (pas de companion_feed ici : COMP = impro du compagnon seulement, distinct de MGEN)
              mgen_nfreq = 440 * 2 ^ ((nn - 69) / 12)
              if vel / 127 > mgen_nenergy then mgen_nenergy = vel / 127 end
              for d = 1, 4 do
                if midi_route[4][d] and midi_outs[d] then
                  local out = midi_outs[d]
                  out:note_on(nn, vel, mc)
                  clock.run(function()
                    clock.sleep(gd)
                    if out then out:note_off(nn, 0, mc) end
                  end)
                end
              end
            end
          end
          ch.step_cur = (ch.step_cur % ch.steps) + 1
          if ch.step_cur == 1 then
            if ch.brk then ch.brk = false end
            if mgen_mut_rate > 0 then mgen_mutate_seq(i) end
          end
        end
      end
      -- sync : attend exactement 6 pulses MIDI si clock externe active
      -- sinon sleep interne base sur mgen_bpm
      if mclk_active then
        local target = mclk_pulse_count + 6
        while mclk_pulse_count < target
              and mgen_running
              and mgen_gen_id == my_id do
          clock.sleep(0.001)
        end
      else
        clock.sleep(sd)
      end
    end
  end)
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

  -- influence METABO -> compagnon (opt-in, non destructif) :
  -- cellule stressee (monotonie) -> contraste/densifie pour casser la monotonie ;
  -- cellule calme/saine -> plus d'espace (sparse/silence). 0 => compagnon inchange.
  local inf = (metabolik and metabolik.on and metabolik.INFLU_AMT
               and metabolik.INFLU_AMT[metabolik.influence_idx or 1]) or 0
  if inf > 0 then
    local st = metabolik.stressFx or 0
    local gr = (metabolik.ch and metabolik.ch.growth) or 0
    w.CONTRASTE     = w.CONTRASTE     + inf * st * 0.5
    w.DENSIFICATION = w.DENSIFICATION + inf * st * 0.3
    w.SPARSE        = w.SPARSE        + inf * (1 - st) * 0.3
    w.SILENCE       = w.SILENCE       + inf * (1 - st) * 0.2
    w.IMITATION     = w.IMITATION     + inf * gr * 0.2
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
  local rhythmic = p_rhythm > 0 and math.random() < p_rhythm
  local beat     = 60.0 / mgen_bpm
  local subdiv   = math.random() < 0.5 and (beat / 2) or (beat / 4)
  local gap
  if rhythmic then
    gap = subdiv
  elseif strategy == "IMITATION" and phrase_analysis and phrase_analysis.density > 0 then
    gap = math.max(0.02, 1.0 / phrase_analysis.density * 0.6)
  else
    gap = math.max(0.02, (1.0 - p_density) * 0.18)
  end
  for i, ev in ipairs(phrase) do
    local rm = improv_rate(strategy, i, #phrase)
    play_event(ev, rm)
    mark_played(ev.slot)
    last_slot = ev.slot
    if i < #phrase then clock.sleep(math.max(0.02, gap)) end
  end
end

---------------------------------------------------------------------
-- respond
---------------------------------------------------------------------
local function respond(ref_n)
  if not comp_on then return end          -- compagnon coupe (LIVE) : ecoute mais se tait
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
    midi_cc_all(3, 123, 0)
    midi_cc_all(2, 123, 0)
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
-- MIDI clock reader : recoit 0xF8 depuis n'importe quel device connecte
-- calcule le BPM a partir de l'intervalle moyen entre pulses (24 PPQ)
-- met a jour mgen_bpm en temps reel si le resultat est dans [60, 200]
---------------------------------------------------------------------
local function midi_clock_in(data)
  local b = data[1]
  if b == 0xFA then                -- transport start
    mclk_t           = {}
    mclk_pulse_count = 0
    mclk_active      = true
  elseif b == 0xFC then            -- transport stop
    mclk_t           = {}
    mclk_pulse_count = 0
    mclk_active      = false
  elseif b == 0xF8 then            -- timing clock pulse (24 par noire)
    mclk_pulse_count = mclk_pulse_count + 1
    local now = util.time()
    table.insert(mclk_t, now)
    if #mclk_t > 12 then table.remove(mclk_t, 1) end
    if #mclk_t >= 4 then
      local total = 0
      for i = 2, #mclk_t do total = total + (mclk_t[i] - mclk_t[i-1]) end
      local avg_pulse = total / (#mclk_t - 1)
      local bpm = 60.0 / (avg_pulse * 24)
      if bpm >= 60 and bpm <= 200 then
        mgen_bpm    = math.floor(bpm + 0.5)
        clock.tempo = mgen_bpm
        mclk_active = true   -- active des que des pulses valides arrivent
      end
    end
  end
end

---------------------------------------------------------------------
-- norns
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Audio -> MIDI : suivi continu pitch + CC energie/timbre
---------------------------------------------------------------------
local function audio_midi_loop()
  while true do
    clock.sleep(0.05)   -- 50 ms
    local any = false
    if audio_midi_on then
      for d = 1, 4 do
        if midi_route[5][d] and midi_outs[d] then any = true ; break end
      end
    end
    if not any then
      if midi_audio_note then
        audio_midi_note_off(midi_audio_note)
        midi_audio_note = nil
      end
    elseif cur_gate > 0.5 and cur_freq > 20 then
      local new_note = freq_to_midi(cur_freq)
      if new_note then
        if new_note ~= midi_audio_note then
          if midi_audio_note then audio_midi_note_off(midi_audio_note) end
          local vel = math.max(1, math.min(127, math.floor(cur_rms * 800 + 20)))
          audio_midi_note_on(new_note, vel)
          midi_audio_note = new_note
        end
        -- CC11 = expression (energie) / CC74 = brillance (centroide)
        for d = 1, 4 do
          if midi_route[5][d] and midi_outs[d] then
            local ch = midi_ch_audio[d]
            midi_outs[d]:cc(11, math.max(0, math.min(127, math.floor(cur_rms * 600))), ch)
            midi_outs[d]:cc(74, math.max(0, math.min(127, math.floor(cur_centroid / 80))), ch)
          end
        end
      end
    else
      if midi_audio_note then
        audio_midi_note_off(midi_audio_note)
        midi_audio_note = nil
      end
    end
  end
end

-- AVATAR METABOLIK (mode METABO) : chargement DEFENSIF.
-- Si lib/metabolik.lua manque sur le norns ou contient une erreur, TEAMMATE
-- doit continuer a tourner normalement (on ne casse JAMAIS le compagnon).
-- Variables temporaires en GLOBAL pour ne pas toucher a la limite de locals.
metabolik = nil
_metabo_ok, _metabo_mod = pcall(include, 'lib/metabolik')
if _metabo_ok and type(_metabo_mod) == "table" then
  metabolik = _metabo_mod
else
  print("METABO indisponible (lib/metabolik.lua manquant ou en erreur) : " .. tostring(_metabo_mod))
  metabolik = {
    on = false, scale_idx = 1, octave = 0, ok = false,
    update = function() end,
    player = function() end,
    enc    = function() end,
    key    = function() end,
    enc_play = function() end,
    key_play = function() end,
    enc_feed = function() end,
    key_feed = function() end,
    redraw_feed = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("METABO FEED")
      screen.level(4)
      screen.move(2, 36) ; screen.text("lib/metabolik.lua absent")
      screen.update()
    end,
    redraw_play = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("METABO PLAY")
      screen.level(4)
      screen.move(2, 36) ; screen.text("lib/metabolik.lua absent")
      screen.update()
    end,
    redraw = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("METABO")
      screen.level(4)
      screen.move(2, 36) ; screen.text("lib/metabolik.lua")
      screen.move(2, 46) ; screen.text("absent sur le norns")
      screen.update()
    end,
  }
end
_metabo_ok = nil ; _metabo_mod = nil

-- NIAKABY (harmoniseur audio->accords MIDI) : chargement defensif aussi.
niakaby = nil
_niaka_ok, _niaka_mod = pcall(include, 'lib/niakaby')
if _niaka_ok and type(_niaka_mod) == "table" then
  niakaby = _niaka_mod
else
  print("NIAKABY indisponible (lib/niakaby.lua manquant ou en erreur) : " .. tostring(_niaka_mod))
  niakaby = {
    on = false, scale_idx = 1, octave = 0, chord_idx = 1,
    src = { input = true, metabo = false, comp = false, mgen = false },
    src_keys = {"input","metabo","comp","mgen"}, src_cursor = 1,
    update = function() end,
    enc    = function() end,
    key    = function() end,
    enc_src = function() end,
    key_src = function() end,
    release = function() end,
    redraw_src = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("NIAKABY SRC")
      screen.level(4) ; screen.move(2, 36) ; screen.text("lib/niakaby.lua absent")
      screen.update()
    end,
    redraw = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("NIAKABY")
      screen.level(4) ; screen.move(2, 36) ; screen.text("lib/niakaby.lua absent")
      screen.update()
    end,
  }
end
_niaka_ok = nil ; _niaka_mod = nil

-- ===== METABO >>> MGEN : la cellule secoue le sequenceur au hasard (opt-in) =====
meta_mgen_drive = 0      -- 0..1 intensite (0 = off)
meta_mgen_scope = 1      -- 1 = LIGHT (regen/gamme) , 2 = FULL (+ themes, breaks, styles)
meta_mgen_last  = "--"
meta_note_inf   = 0      -- 0..1 : METABO impose ses notes a MGEN (page 25 E3)

-- ===== MGEN apprend tes COMBINAISONS : banque des reparitions de genres aimees (page 27) =====
-- une "combinaison" = le genre des 16 channels (vision globale). LIKE memorise la combo,
-- DISLIKE oublie la plus proche. Les new themes rappellent/varient tes combos aimees.
mgen_liked      = {}     -- liste de combos ; chaque combo = { style_idx x16 }
mgen_taste_last = "--"
mgen_browse     = 0       -- 0 = live ; 1..N = combo selectionnee (chargee)
mgen_recall     = 0       -- 0..1 : proba qu'un new theme rappelle une combo aimee (0 = off, themes frais)

-- charge une combinaison : applique le genre de chaque channel + regenere les sequences
function mgen_load_combo(c)
  if type(c) ~= "table" then return end
  for i = 1, 16 do
    local si = c[i] or mgen_ch[i].style_idx
    if si < 1 or si > #MGEN_STYLE_NAMES then si = 1 end
    local def = MGEN_STYLE_DEF[MGEN_STYLE_NAMES[si]]
    mgen_ch[i].style_idx = si
    mgen_ch[i].octave = def.oct_lo + math.random(0, def.oct_hi - def.oct_lo)
    mgen_gen_seq(i)
  end
end

local function mgen_capture_combo()
  local c = {} ; for i = 1, 16 do c[i] = mgen_ch[i].style_idx end ; return c
end
local function mgen_combo_dist(a, b)
  local d = 0 ; for i = 1, 16 do if a[i] ~= b[i] then d = d + 1 end end ; return d
end

function mgen_taste_save()
  pcall(function()
    if norns and norns.state and norns.state.data then
      util.make_dir(norns.state.data)
      tab.save(mgen_liked, norns.state.data .. "mgen_combos.data")
    end
  end)
end

function mgen_taste_load()
  pcall(function()
    if norns and norns.state and norns.state.data then
      local t = tab.load(norns.state.data .. "mgen_combos.data")
      if type(t) == "table" then mgen_liked = t end
    end
  end)
end

-- LIKE = memorise la combinaison de genres courante ; DISLIKE = oublie la plus proche
function mgen_taste(like)
  if like then
    local c = mgen_capture_combo()
    for _, e in ipairs(mgen_liked) do
      if mgen_combo_dist(e, c) <= 1 then mgen_taste_last = "deja aimee" ; return end
    end
    mgen_liked[#mgen_liked + 1] = c
    while #mgen_liked > 24 do table.remove(mgen_liked, 1) end
    mgen_taste_last = "LIKE (" .. #mgen_liked .. ")"
  else
    local cur, bi, bd = mgen_capture_combo(), nil, 99
    for i, e in ipairs(mgen_liked) do
      local dd = mgen_combo_dist(e, cur)
      if dd < bd then bd = dd ; bi = i end
    end
    if bi then table.remove(mgen_liked, bi) ; mgen_taste_last = "forget (" .. #mgen_liked .. ")"
    else mgen_taste_last = "rien" end
  end
  mgen_taste_save()
end

-- note la plus proche dans la gamme MGEN courante (rootee sur mgen_root)
function mgen_snap(note)
  local sc = MGEN_SCALES[MGEN_SCALE_NAMES[mgen_scale_idx]]
  local L = #sc
  local best, bd = note, 999
  for o = -2, 8 do
    for i = 1, L do
      local cand = mgen_root + o * 12 + sc[i]
      local dd = math.abs(cand - note)
      if dd < bd then bd = dd ; best = cand end
    end
  end
  return best
end
function meta_shake_mgen()
  local r = math.random()
  if meta_mgen_scope == 1 then
    if r < 0.7 then
      local ci = math.random(16) ; mgen_gen_seq(ci) ; meta_mgen_last = "regen ch" .. ci
    else
      mgen_scale_idx = math.random(#MGEN_SCALE_NAMES) ; meta_mgen_last = "gamme " .. MGEN_SCALE_NAMES[mgen_scale_idx]
    end
  else
    if r < 0.30 then
      local ci = math.random(16) ; mgen_gen_seq(ci) ; meta_mgen_last = "regen ch" .. ci
    elseif r < 0.50 then
      mgen_scale_idx = math.random(#MGEN_SCALE_NAMES) ; meta_mgen_last = "gamme " .. MGEN_SCALE_NAMES[mgen_scale_idx]
    elseif r < 0.70 then
      mgen_gen_all(true) ; meta_mgen_last = "new theme"
    elseif r < 0.88 then
      local bt = math.random(#MGEN_BREAK_NAMES)
      for i = 1, 16 do if mgen_ch[i].on then mgen_ch[i].brk = true ; mgen_ch[i].brk_type = bt end end
      meta_mgen_last = "break " .. MGEN_BREAK_NAMES[bt]
    else
      local ci = math.random(16) ; mgen_ch[ci].style_idx = math.random(#MGEN_STYLE_NAMES) ; mgen_gen_seq(ci)
      meta_mgen_last = "style ch" .. ci
    end
  end
end

-- ===== PAGE LIVE : armer/couper les modes en un seul endroit (set live) =====
audio_midi_on = true     -- Audio->MIDI actif (si route page 16) ; armable depuis LIVE
comp_on = true           -- compagnon (impro corpus) repond ; off = ecoute mais se tait
live_cursor = 1
LIVE_NAMES  = { "POtO", "8OS", "MGEN", "SPAT", "METABO", "NIAKABY", "AUDIO", "IMPRO" }

function live_toggle(i)
  if i == 1 then
    poto_set(not p_poto_on)
  elseif i == 2 then
    local seq = { "OFF", "REC", "TRANS" } ; local nxt = 1
    for k, m in ipairs(seq) do if m == os8_mode then nxt = (k % #seq) + 1 end end
    os8_set(seq[nxt])
  elseif i == 3 then
    if mgen_running then mgen_stop() else mgen_gen_all() ; mgen_start() end
  elseif i == 4 then
    spat.on = not spat.on
    if spat.on then spat_start() else spat_stop() end
  elseif i == 5 then
    metabolik.on = not metabolik.on
  elseif i == 6 then
    niakaby.on = not niakaby.on
    if not niakaby.on then niakaby.release() end
  elseif i == 7 then
    audio_midi_on = not audio_midi_on
  elseif i == 8 then
    comp_on = not comp_on
    if not comp_on then midi_cc_all(1, 123, 0) end   -- relache l'impro
  end
end

function live_all_off()
  if p_poto_on then poto_set(false) end
  if os8_mode ~= "OFF" then os8_set("OFF") end
  if mgen_running then mgen_stop() end
  if spat.on then spat.on = false ; spat_stop() end
  metabolik.on = false
  if niakaby.on then niakaby.on = false ; niakaby.release() end
  audio_midi_on = false
  comp_on = false
  for st = 1, 7 do midi_cc_all(st, 123, 0) end   -- all notes off sur tous les streams
end

function init()
  math.randomseed(os.time())
  mgen_taste_load()        -- recharge les gouts MGEN appris (memoire persistante)
  mgen_gen_all()
  last_sound_t = util.time()
  splash_active = true
  clock.run(function() clock.sleep(3.0) ; splash_active = false end)
  clock.run(audio_midi_loop)
  for d = 1, 4 do
    local ok, md = pcall(midi.connect, d)
    if ok then
      midi_outs[d] = md
      md.event = midi_clock_in   -- ecoute les pulses 0xF8 entrants
    end
  end
  audio.level_adc(1.0)
  audio.level_monitor(1.0)
  sc_init()
  poto_start_t = util.time()

  local pa = poll.set("amp_in_l",   on_rms)
  local pp = poll.set("pitch_in_l", on_freq)
  pa.time = 1/60.0 ; pa:start()
  pp.time = 1/30.0 ; pp:start()

  -- polls du MOTEUR SC : attendre que le moteur les ait enregistres (evite le flood "couldn't find poll")
  clock.run(function()
    clock.sleep(1.0)
    local pc  = poll.set("tm_centroid", on_centroid)
    local pfl = poll.set("tm_flatness", on_flatness)
    if pc  then pc.time  = 1/30.0 ; pc:start()  end
    if pfl then pfl.time = 1/30.0 ; pfl:start() end
  end)

  silence_loop()

  -- AVATAR METABOLIK (mode METABO) : voix routee par la MATRICE (stream 6) + maj ~30 Hz
  metabolik.note_on  = function(note, vel)
    midi_note_on(6, note, vel)
    meta_freq = 440 * 2 ^ ((note - 69) / 12)        -- capture pour NIAKABY (source METABO)
    if vel / 127 > meta_energy then meta_energy = vel / 127 end
  end
  metabolik.note_off = function(note)      midi_note_off(6, note) end
  clock.run(metabolik.player)

  -- NIAKABY (harmoniseur) : accords routes par la MATRICE (stream 7) + lien METABO
  niakaby.note_on  = function(note, vel) midi_note_on(7, note, vel) end
  niakaby.note_off = function(note)      midi_note_off(7, note) end
  niakaby.metabo   = metabolik           -- lecture stress/croissance pour colorer les accords

  -- METABO >>> MGEN : secousses aleatoires, frequence = intensite x stress de la cellule
  clock.run(function()
    while true do
      clock.sleep(60.0 / math.max(40, mgen_bpm))   -- ~1 temps
      if meta_mgen_drive > 0 and mgen_running then
        local st = metabolik.stressFx or 0
        if math.random() < meta_mgen_drive * (0.10 + st * 0.5) then meta_shake_mgen() end
      end
    end
  end)
  clock.run(function()
    while true do
      clock.sleep(1/30)
      meta_energy  = meta_energy  * 0.90   -- decay de l'energie METABO (suit ses silences)
      mgen_nenergy = mgen_nenergy * 0.88   -- decay de l'energie MGEN
      -- sources actives (INPUT/METABO/COMP/MGEN, combinables) : on prend la plus FORTE
      local s = niakaby.src or { input = true }
      local br, bf, bc, bfl = 0, 0, 0, 0
      if s.input  and cur_rms      > br and (cur_freq   or 0) > 30 then br=cur_rms ;      bf=cur_freq ;   bc=cur_centroid ;  bfl=cur_flatness end
      if s.metabo and meta_energy  > br and (meta_freq  or 0) > 30 then br=meta_energy ;  bf=meta_freq ;  bc=meta_freq * 3 ;  bfl=0.05 end
      if s.comp   and comp_rms     > br and (comp_freq  or 0) > 30 then br=comp_rms ;     bf=comp_freq ;  bc=comp_centroid ; bfl=comp_flatness end
      if s.mgen   and mgen_nenergy > br and (mgen_nfreq or 0) > 30 then br=mgen_nenergy ; bf=mgen_nfreq ; bc=mgen_nfreq * 3 ; bfl=0.05 end
      niakaby.update(br, bf, bc, bfl, 1/30)
    end
  end)
  clock.run(function()
    while true do
      clock.sleep(1/30)
      metabolik.bpm_ref = mgen_bpm                     -- METABO cale son tempo sur le BPM global MGEN
      local react = metabolik.react or 0.5
      comp_rms = comp_rms * (0.965 - react * 0.165)   -- react haut -> decay rapide -> plus reactif
      local fi = metabolik.feed_idx or 1
      local ce = comp_rms * (0.6 + react * 1.2)        -- sensibilite au compagnon
      if fi == 2 then        -- COMP : le compagnon nourrit la cellule
        metabolik.update(ce, comp_freq, comp_centroid, comp_flatness, 1/30)
      elseif fi == 3 then    -- MIX : entree + compagnon
        metabolik.update(math.max(cur_rms, ce),
                         (comp_freq > 0 and ce > cur_rms) and comp_freq or cur_freq,
                         math.max(cur_centroid, comp_centroid),
                         math.max(cur_flatness, comp_flatness), 1/30)
      else                   -- INPUT : micro / ligne (defaut)
        metabolik.update(cur_rms, cur_freq, cur_centroid, cur_flatness, 1/30)
      end
    end
  end)

  clock.run(function()
    while true do
      clock.sleep(0.1)
      redraw()
    end
  end)
end

function cleanup()
  mgen_taste_save()        -- sauve les gouts MGEN
  mgen_stop()
  for v = 1, 6 do
    softcut.rec(v, 0)
    softcut.play(v, 0)
    softcut.level(v, 0)
  end
end

---------------------------------------------------------------------
-- navigation pages (17 pages)
-- Page  1  CORPUS   : E2 learn%     | E3 gate thr   | K3 clear corpus
-- Page  2  MAIN     : E2 density    | E3 sil bias   | K3 force reply
-- Page  3  RESP     : E2 contrast   | E3 reply%     | K3 deaf on/off
-- Page  4  TIME     : E2 react      | E3 init       | K2 rhy prob 0/15/30/50% | K3 voice mode
-- Page  5  POtO     : E2 vol        | E3 monitor    | K2 poly MONO/5th/CHRD/CLST/SMRT | K3 on/off
-- Page  6  8OS      : E2 vol        | E3 grain ms   | K3 OFF->REC->TRANS | K2 clock sync
-- Page  7  GRAIN    : E2 grain ms   | E3 spread     | K3 rate preset
-- Page  8  CLR8OS   : ---           | ---           | K3 clear bank
-- Page  9  MIDI DEV1: E2 stream     | E3 ch         | K3 route on/off
-- Page 10  MIDI DEV2: E2 stream     | E3 ch         | K3 route on/off
-- Page 11  MIDI DEV3: E2 stream     | E3 ch         | K3 route on/off
-- Page 12  MIDI DEV4: E2 stream     | E3 ch         | K3 route on/off
-- Page 13  MGEN     : E2 BPM        | E3 gamme      | K2 tap/new theme | K3 start/stop
-- Page 14  MGEN CH  : E2 channel    | E3 style      | K2 evo rate      | K3 on/off channel
--          14 styles : TECHNO DnB JUNGLE AMAPIANO 2STEP BRKN DUMB TRAP DRIL
--                      CLUB KPOP ORNTL RAVE TRNCE
-- Page 15  MGEN BRK : E2 break type | E3 octave ch  | K3 fire break
-- Page 16  AUDIO>MIDI: E2 device   | E3 channel    | K3 toggle route
-- Page 17  SPAT      : E2 masse    | E3 tempo      | K2 mode | K3 ON/OFF
-- E1 : navigation pages (1->17->1)
---------------------------------------------------------------------
function enc(n, d)
  if n == 1 then
    page = ((page - 1 + d) % 27) + 1
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
      os8_vol       = util.clamp(os8_vol       + d * 0.05, 0.0, 1.0)
    elseif page == 7 then
      p_poto_size   = util.clamp(p_poto_size   + d * 0.01, 0.05, 0.40)
    elseif page >= 9 and page <= 12 then
      midi_cur_stream = util.clamp(midi_cur_stream + d, 1, 4)
    elseif page == 13 then
      mgen_bpm    = util.clamp(mgen_bpm + d, 60, 200)
      clock.tempo = mgen_bpm
    elseif page == 14 then
      mgen_sel_ch = util.clamp(mgen_sel_ch + d, 1, 16)
    elseif page == 15 then
      mgen_break_idx = ((mgen_break_idx - 1 + d) % #MGEN_BREAK_NAMES) + 1
    elseif page == 16 then
      midi_audio_cur_dev = util.clamp(midi_audio_cur_dev + d, 1, 4)
    elseif page == 17 then
      spat.mass = util.clamp(spat.mass + d * 0.05, 0.0, 1.0)
    elseif page == 18 then
      metabolik.enc(2, d)
    elseif page == 19 then
      metabo_cur_dev = util.clamp(metabo_cur_dev + d, 1, 4)
    elseif page == 20 then
      metabolik.enc_play(2, d)
    elseif page == 21 then
      metabolik.enc_feed(2, d)
    elseif page == 22 then
      niakaby.enc(2, d)
    elseif page == 23 then
      niaka_cur_dev = util.clamp(niaka_cur_dev + d, 1, 4)
    elseif page == 24 then
      niakaby.enc_src(2, d)
    elseif page == 25 then
      meta_mgen_drive = util.clamp(meta_mgen_drive + d * 0.05, 0, 1)
    elseif page == 26 then
      live_cursor = ((live_cursor - 1 + d) % #LIVE_NAMES) + 1
    elseif page == 27 then
      mgen_browse = util.clamp(mgen_browse + d, 0, #mgen_liked)
      if mgen_browse >= 1 and mgen_liked[mgen_browse] then mgen_load_combo(mgen_liked[mgen_browse]) end
    end
  elseif n == 3 then
    if page == 25 then meta_note_inf = util.clamp(meta_note_inf + d * 0.05, 0, 1) end
    if page == 27 then mgen_recall = util.clamp(mgen_recall + d * 0.05, 0, 1) end
    if page == 1 then
      p_gate_thr    = util.clamp(p_gate_thr    + d * 0.001, 0.0001, 0.05)
    elseif page == 2 then
      p_sil_bias    = util.clamp(p_sil_bias    + d * 0.05, 0.0, 1.0)
    elseif page == 3 then
      p_reply       = util.clamp(p_reply       + d * 0.05, 0.0, 1.0)
    elseif page == 4 then
      p_sil_max     = util.clamp(p_sil_max     + d * 0.1,  0.5, 8.0)
    elseif page == 5 then
      if p_poto_poly == 5 then
        p_poto_smrt_sens = util.clamp(p_poto_smrt_sens + d * 0.05, 0.0, 1.0)
      else
        p_monitor = util.clamp(p_monitor + d * 0.05, 0.0, 1.0)
        audio.level_monitor(p_monitor)
      end
    elseif page == 6 then
      os8_size      = util.clamp(os8_size      + d * 0.01, 0.02, 0.50)
    elseif page == 7 then
      p_poto_spread = util.clamp(p_poto_spread + d * 0.01, 0.0, 0.30)
    elseif page >= 9 and page <= 12 then
      if midi_cur_stream <= 3 then
        local dev = page - 8
        midi_ch[midi_cur_stream][dev] = util.clamp(midi_ch[midi_cur_stream][dev] + d, 1, 16)
      end
    elseif page == 16 then
      midi_ch_audio[midi_audio_cur_dev] = util.clamp(midi_ch_audio[midi_audio_cur_dev] + d, 1, 16)
    elseif page == 17 then
      spat.tempo = util.clamp(spat.tempo + d * 0.05, 0.0, 1.0)
    elseif page == 13 then
      mgen_scale_idx = ((mgen_scale_idx - 1 + d) % #MGEN_SCALE_NAMES) + 1
    elseif page == 14 then
      local ch = mgen_ch[mgen_sel_ch]
      ch.style_idx = ((ch.style_idx - 1 + d) % #MGEN_STYLE_NAMES) + 1
      mgen_gen_seq(mgen_sel_ch)
    elseif page == 15 then
      local ch = mgen_ch[mgen_sel_ch]
      ch.octave = util.clamp(ch.octave + d, 1, 7)
      mgen_gen_seq(mgen_sel_ch)
    elseif page == 18 then
      metabolik.enc(3, d)
    elseif page == 19 then
      midi_ch[6][metabo_cur_dev] = util.clamp(midi_ch[6][metabo_cur_dev] + d, 1, 16)
    elseif page == 20 then
      metabolik.enc_play(3, d)
    elseif page == 21 then
      metabolik.enc_feed(3, d)
    elseif page == 22 then
      niakaby.enc(3, d)
    elseif page == 23 then
      midi_ch[7][niaka_cur_dev] = util.clamp(midi_ch[7][niaka_cur_dev] + d, 1, 16)
    elseif page == 24 then
      niakaby.enc_src(3, d)
    end
  end
  redraw()
end

function key(n, z)
  if z == 0 then return end
  if page == 18 then metabolik.key(n) ; redraw() ; return end
  if page == 20 then metabolik.key_play(n) ; redraw() ; return end
  if page == 21 then metabolik.key_feed(n) ; redraw() ; return end
  if page == 22 then niakaby.key(n) ; redraw() ; return end
  if page == 23 then
    if n == 3 then midi_route[7][niaka_cur_dev] = not midi_route[7][niaka_cur_dev] end
    redraw() ; return
  end
  if page == 24 then niakaby.key_src(n) ; redraw() ; return end
  if page == 25 then
    if n == 2 then meta_mgen_scope = (meta_mgen_scope == 1) and 2 or 1
    elseif n == 3 then meta_shake_mgen() end
    redraw() ; return
  end
  if page == 26 then
    if n == 3 then live_toggle(live_cursor)
    elseif n == 2 then live_all_off() end
    redraw() ; return
  end
  if page == 27 then
    if n == 3 then mgen_taste(true)
    elseif n == 2 then mgen_taste(false) end
    redraw() ; return
  end
  if page == 19 then
    if n == 3 then midi_route[6][metabo_cur_dev] = not midi_route[6][metabo_cur_dev] end
    redraw() ; return
  end
  if n == 2 and page == 4 then
    p_rhythm_idx = (p_rhythm_idx % #RHYTHM_RATES) + 1
    p_rhythm     = RHYTHM_RATES[p_rhythm_idx]
  elseif n == 2 and page == 5 then
    p_poto_poly = (p_poto_poly % #POTO_POLY_NAMES) + 1
  elseif n == 2 and page == 6 then
    os8_sync = not os8_sync
  elseif n == 2 and page == 14 then
    mgen_mut_idx  = (mgen_mut_idx % #MGEN_MUT_RATES) + 1
    mgen_mut_rate = MGEN_MUT_RATES[mgen_mut_idx]
  elseif n == 2 and page == 17 then
    spat.mode = (spat.mode % #SPAT_MODES) + 1
  elseif n == 2 and page == 13 then
    if mgen_running then
      mgen_gen_all(true)
    else
      local now = util.time()
      if #mgen_tap_times > 0 and (now - mgen_tap_times[#mgen_tap_times]) > 3.0 then
        mgen_tap_times = {}
      end
      table.insert(mgen_tap_times, now)
      if #mgen_tap_times > 4 then table.remove(mgen_tap_times, 1) end
      if #mgen_tap_times >= 2 then
        local total = 0
        for i = 2, #mgen_tap_times do
          total = total + (mgen_tap_times[i] - mgen_tap_times[i-1])
        end
        local avg   = total / (#mgen_tap_times - 1)
        mgen_bpm    = math.max(60, math.min(200, math.floor(60.0 / avg + 0.5)))
        clock.tempo = mgen_bpm
      end
    end
  end
  if n == 3 then
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
      local seq = {"OFF", "REC", "TRANS"}
      local nxt = 1
      for i, m in ipairs(seq) do if m == os8_mode then nxt = (i % #seq) + 1 end end
      os8_set(seq[nxt])
    elseif page == 7 then
      rate_pidx = (rate_pidx % #RATE_PRESETS) + 1
      p_poto_rate = RATE_PRESETS[rate_pidx]
    elseif page == 8 then
      os8_bank = {} ; os8_rec_n = 0
    elseif page >= 9 and page <= 12 then
      local dev = page - 8
      midi_route[midi_cur_stream][dev] = not midi_route[midi_cur_stream][dev]
    elseif page == 16 then
      midi_route[5][midi_audio_cur_dev] = not midi_route[5][midi_audio_cur_dev]
    elseif page == 17 then
      spat.on = not spat.on
      if spat.on then spat_start() else spat_stop() end
    elseif page == 13 then
      if mgen_running then mgen_stop() else mgen_gen_all() ; mgen_start() end
    elseif page == 14 then
      mgen_ch[mgen_sel_ch].on = not mgen_ch[mgen_sel_ch].on
    elseif page == 15 then
      for i = 1, 16 do
        if mgen_ch[i].on then
          mgen_ch[i].brk = true ; mgen_ch[i].brk_type = mgen_break_idx
        end
      end
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

  if page == 27 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("MGEN TASTE")
    screen.level(8)  ; screen.move(126, 8)
    screen.text_right(mgen_browse >= 1 and ("combo " .. mgen_browse .. "/" .. #mgen_liked) or (#mgen_liked .. " combos"))
    -- frequence des genres dans tes COMBINAISONS aimees (vision globale de ce que tu aimes)
    local freq = {}
    for i = 1, #MGEN_STYLE_NAMES do freq[i] = 0 end
    for _, c in ipairs(mgen_liked) do
      for i = 1, 16 do if c[i] then freq[c[i]] = freq[c[i]] + 1 end end
    end
    local t = {}
    for i = 1, #MGEN_STYLE_NAMES do t[#t + 1] = { n = MGEN_STYLE_NAMES[i], w = freq[i] } end
    table.sort(t, function(a, b) return a.w > b.w end)
    local maxw = math.max(1, t[1] and t[1].w or 1)
    if #mgen_liked == 0 then
      screen.level(4) ; screen.move(2, 32) ; screen.text("aucune combo aimee")
      screen.move(2, 44) ; screen.text("K3 = aimer le theme courant")
    else
      local ys = { 18, 25, 32, 39, 46, 53 }
      for k = 1, 6 do
        local row = t[k]
        if row and row.w > 0 then
          screen.level(8) ; screen.move(2, ys[k]) ; screen.text(row.n)
          screen.level(4) ; screen.rect(62, ys[k] - 4, 56, 3) ; screen.stroke()
          screen.level(13) ; screen.rect(62, ys[k] - 4, 56 * (row.w / maxw), 3) ; screen.fill()
        end
      end
    end
    screen.level(mgen_recall > 0 and 12 or 4) ; screen.move(2, 63)
    screen.text(string.format("E3 recall %d%%   E2 parcourt", math.floor(mgen_recall * 100)))
    screen.update() ; return
  end
  if page == 26 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("LIVE")
    screen.level(4)  ; screen.move(126, 8) ; screen.text_right("K3 tgl  K2 panic")
    local states = { p_poto_on and "ON" or "off", os8_mode, mgen_running and "ON" or "off",
                     spat.on and "ON" or "off", metabolik.on and "ON" or "off",
                     niakaby.on and "ON" or "off", audio_midi_on and "ON" or "off",
                     comp_on and "ON" or "off" }
    local ons    = { p_poto_on, os8_mode ~= "OFF", mgen_running, spat.on, metabolik.on,
                     niakaby.on, audio_midi_on, comp_on }
    local ys     = { 14, 21, 28, 35, 42, 49, 56, 63 }
    for i = 1, #LIVE_NAMES do
      local sel = (i == live_cursor)
      screen.level(sel and 15 or (ons[i] and 11 or 4))
      screen.move(2, ys[i]) ; screen.text((sel and ">" or " ") .. LIVE_NAMES[i])
      screen.level(ons[i] and 15 or 3)
      screen.move(78, ys[i]) ; screen.text(states[i])
    end
    screen.update() ; return
  end
  if page == 18 then metabolik.redraw() ; return end
  if page == 19 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("METABO MIDI")
    screen.level(4)  ; screen.move(126, 8) ; screen.text_right("str6")
    local ys = {22, 33, 44, 55}
    for d = 1, 4 do
      local sel    = (d == metabo_cur_dev)
      local routed = midi_route[6][d]
      local dname  = (midi.vports[d] and midi.vports[d].name) or ("DEV " .. d)
      if #dname > 8 then dname = string.sub(dname, 1, 7) .. "~" end
      screen.level(sel and 15 or (routed and 9 or 4))
      screen.move(2, ys[d]) ; screen.text(string.format("%sd%d %s", sel and ">" or " ", d, dname))
      screen.level(routed and 15 or 3)
      screen.move(86, ys[d]) ; screen.text(routed and "[X]" or "[ ]")
      screen.level(sel and 12 or 5)
      screen.move(108, ys[d]) ; screen.text("c" .. midi_ch[6][d])
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text("E2 dev  E3 ch  K3 route")
    screen.update() ; return
  end
  if page == 20 then metabolik.redraw_play() ; return end
  if page == 21 then metabolik.redraw_feed() ; return end
  if page == 22 then niakaby.redraw() ; return end
  if page == 24 then niakaby.redraw_src() ; return end
  if page == 25 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("METABO>MGEN")
    screen.move(126, 8) ; screen.text_right(mgen_running and "RUN" or "off")
    screen.level(4)  ; screen.move(2, 20) ; screen.text("E2 DRIVE")
    screen.level(15) ; screen.move(74, 20) ; screen.text(string.format("%d%%", math.floor(meta_mgen_drive * 100)))
    screen.level(4)  ; screen.rect(2, 23, 120, 2) ; screen.stroke()
    screen.level(12) ; screen.rect(2, 23, 120 * meta_mgen_drive, 2) ; screen.fill()
    screen.level(4)  ; screen.move(2, 34) ; screen.text("E3 NOTE")
    screen.level(15) ; screen.move(74, 34) ; screen.text(string.format("%d%%", math.floor(meta_note_inf * 100)))
    screen.level(4)  ; screen.rect(2, 37, 120, 2) ; screen.stroke()
    screen.level(12) ; screen.rect(2, 37, 120 * meta_note_inf, 2) ; screen.fill()
    screen.level(4)  ; screen.move(2, 48) ; screen.text("K2 SCOPE")
    screen.level(15) ; screen.move(74, 48) ; screen.text(meta_mgen_scope == 2 and "FULL" or "LIGHT")
    screen.level(4)  ; screen.move(2, 58) ; screen.text("last:")
    screen.level(10) ; screen.move(32, 58) ; screen.text(meta_mgen_last or "--")
    screen.level(4)  ; screen.move(2, 64) ; screen.text("K3 shake now")
    screen.update() ; return
  end

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




  -- ligne 1 : etat | corpus | page | dot rec
  screen.level(15)
  screen.move(0, 8)
  screen.text(state)

  screen.level(5)
  screen.move(42, 8)
  screen.text(string.format("c:%d/%d", count, CORPUS_SLOTS))

  screen.level(5)
  screen.move(100, 8)
  screen.text(page .. "/27")

  if rec_on then
    screen.level(15)
    screen.circle(124, 5, 3)
    screen.fill()
  end

  -- ligne 2 : strategie | silence / fragment
  screen.level(state == "THINK" and 15 or 5)
  screen.move(0, 18)
  screen.text(strat_name)

  if #phrase_buf > 0 then
    screen.level(10)
    screen.move(76, 18)
    screen.text("+" .. #phrase_buf)
  elseif sil_sec > 0.5 then
    screen.level(4)
    screen.move(76, 18)
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

  -- timbre live / portrait fragment (ou nom du device sur pages 9-12)
  screen.level(4)
  screen.move(0, 37)
  if page >= 9 and page <= 12 then
    local dev   = page - 8
    local dname = (midi.vports[dev] and midi.vports[dev].name) or ("DEV " .. dev)
    if #dname > 21 then dname = string.sub(dname, 1, 20) .. "~" end
    screen.text(string.format("d%d %s", dev, dname))
  elseif page == 16 then
    local an = midi_audio_note and string.format("n%d", midi_audio_note) or "---"
    screen.text(string.format("AUDIO>MIDI  live:%s  E2 dev  E3 ch", an))
  elseif page == 23 then
    local on = {}
    local s = niakaby.src or {}
    if s.input then on[#on+1]="IN" end
    if s.metabo then on[#on+1]="ME" end
    if s.comp then on[#on+1]="CO" end
    if s.mgen then on[#on+1]="MG" end
    screen.level(10)
    screen.text("NIAKABY>MIDI  src:" .. (#on>0 and table.concat(on,"+") or "--") .. " (p.24)")
  elseif page == 17 then
    screen.level(spat.on and 15 or 6)
    screen.text(SPAT_MODES[spat.mode])
  elseif phrase_analysis then
    screen.text(string.format("ph rms%.2f  %devs/s",
      phrase_analysis.rms,
      math.floor(phrase_analysis.density)))
  else
    screen.text(string.format("ctr %dkHz  flat %d%%",
      math.floor(cur_centroid / 1000),
      math.floor(cur_flatness * 100)))
  end
  -- indicateurs de mode sur la meme ligne, a droite
  if page == 14 then
    screen.level(mgen_mut_rate > 0 and 9 or 3)
    screen.move(84, 37)
    screen.text(string.format("~%d%% K2", math.floor(mgen_mut_rate * 100)))
  elseif p_voice or p_deaf then
    screen.level(12)
    screen.move(104, 37)
    screen.text((p_voice and "V" or "") .. (p_deaf and "D" or ""))
  end

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
    screen.move(0, 50)
    screen.text(string.format("E2 react %.1fs", p_sil_min))
    screen.move(0, 57)
    screen.text(string.format("E3 init  %.1fs", p_sil_max))
    screen.level(p_voice and 12 or 5)
    screen.move(0, 64)
    screen.text(string.format("K3 voice %s", p_voice and "ON" or "off"))
    screen.level(p_rhythm > 0 and 9 or 3)
    screen.move(70, 64)
    screen.text(string.format("K2 rhy %d%%", math.floor(p_rhythm * 100)))

  elseif page == 5 then
    local col = p_poto_on and 15 or 5
    screen.level(col)
    screen.font_size(16)
    screen.move(0, 56)
    screen.text(p_poto_on and "ON" or "off")
    screen.font_size(8)
    screen.level(4)
    screen.move(0, 64)
    screen.text("POtO")
    screen.level(5)
    screen.move(60, 44)
    screen.level(p_poto_poly > 1 and 12 or 4)
    if p_poto_poly == 5 then
      local sp = poto_smart_params()
      screen.text(string.format("K2 SMRT:%s", sp.tech))
    else
      screen.text(string.format("K2 %s", POTO_POLY_NAMES[p_poto_poly]))
    end
    screen.level(5)
    screen.move(60, 50)
    screen.text(string.format("vol  %d%%", math.floor(p_poto_vol * 100)))
    screen.move(60, 57)
    if p_poto_poly == 5 then
      screen.text(string.format("sen  %d%%", math.floor(p_poto_smrt_sens * 100)))
    else
      screen.text(string.format("mon  %d%%", math.floor(p_monitor * 100)))
    end
    screen.move(60, 64)
    screen.text("K3 on/off")

  elseif page == 6 then
    local col = os8_mode == "TRANS" and 15 or (os8_mode == "REC" and 12 or 5)
    screen.level(col)
    screen.font_size(16)
    screen.move(0, 56)
    screen.text(os8_mode)
    screen.font_size(8)
    screen.level(4)
    screen.move(0, 64)
    screen.text("8OS")
    screen.level(os8_sync and 12 or 3)
    screen.move(0, 44)
    screen.text(os8_sync and "K2 SYNC" or "K2 sync")
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

  elseif page == 7 then
    screen.level(p_poto_on and 10 or 5)
    screen.move(0, 57)
    screen.text(string.format("E2 grain %dms  E3 sprd %d%%",
      math.floor(p_poto_size * 1000),
      math.floor(p_poto_spread * 100)))
    screen.move(0, 64)
    screen.text(string.format("K3 rate x%.2f", p_poto_rate))

  elseif page == 8 then
    screen.level(os8_rec_n > 0 and 12 or 5)
    screen.move(0, 57)
    screen.text(string.format("8OS bank  %d grains", os8_rec_n))
    screen.level(5)
    screen.move(0, 64)
    screen.text("K3 : clear bank")

  elseif page >= 9 and page <= 12 then
    local dev    = page - 8
    local labels = {"IMPRO", "POtO ", "8OS  ", "MGEN "}
    local y      = {44, 51, 57, 64}
    for s = 1, 4 do
      local sel    = (s == midi_cur_stream)
      local routed = midi_route[s][dev]
      screen.level(sel and 15 or (routed and 10 or 4))
      screen.move(0, y[s])
      screen.text(labels[s])
      screen.level(routed and 15 or 3)
      screen.move(40, y[s])
      screen.text(routed and "[X]" or "[ ]")
      if s <= 3 then
        screen.level(sel and 10 or 4)
        screen.move(70, y[s])
        screen.text(string.format("ch:%2d", midi_ch[s][dev]))
      end
    end

  elseif page == 13 then
    screen.level(mgen_running and 15 or 6)
    screen.font_size(16)
    screen.move(0, 56)
    screen.text(mgen_running and "RUN" or "off")
    screen.font_size(8)
    screen.level(4)
    screen.move(0, 64)
    screen.text("MGEN")
    local n_on = 0
    for i = 1, 16 do if mgen_ch[i].on then n_on = n_on + 1 end end
    screen.level(mclk_active and 15 or 10)
    screen.move(48, 50)
    screen.text(string.format("%s %d", mclk_active and "EXT" or "bpm", mgen_bpm))
    screen.level(8)
    screen.move(48, 57)
    screen.text(MGEN_SCALE_NAMES[mgen_scale_idx])
    screen.level(5)
    screen.move(48, 64)
    screen.text(string.format("%d/16 ch  K3:go", n_on))
    if mgen_running then
      screen.level(10) ; screen.move(0, 44) ; screen.text("K2:new")
    elseif mclk_active then
      screen.level(12) ; screen.move(0, 44) ; screen.text("EXT CLK")
    else
      screen.level(#mgen_tap_times >= 2 and 12 or 3)
      screen.move(0, 44)
      screen.text(#mgen_tap_times >= 2 and
        string.format("TAP %d", #mgen_tap_times) or "K2:tap")
    end
    screen.level(mgen_mut_rate > 0 and 8 or 3)
    screen.move(80, 44)
    screen.text(string.format("~%d%%", math.floor(mgen_mut_rate * 100)))

  elseif page == 14 then
    local abbrev = {"TECH","DnB ","JGL ","AMPR","2STP","BRKN","DUMB","TRAP","DRIL","CLUB","KPOP","ORNT","RAVE","TRNC"}
    local vs = math.floor((mgen_sel_ch - 1) / 4) * 4 + 1
    local ys = {44, 50, 57, 64}
    for ri = 0, 3 do
      local ci = vs + ri
      if ci <= 16 then
        local ch  = mgen_ch[ci]
        local sel = (ci == mgen_sel_ch)
        screen.level(sel and 15 or (ch.on and 8 or 3))
        screen.move(0, ys[ri + 1])
        screen.text(string.format("%sch%02d %s o%d %s",
          sel and ">" or " ", ci,
          abbrev[ch.style_idx], ch.octave,
          ch.on and "[X]" or "[ ]"))
      end
    end

  elseif page == 15 then
    screen.level(12)
    screen.move(0, 50)
    screen.text("BREAK: " .. MGEN_BREAK_NAMES[mgen_break_idx])
    screen.level(5)
    screen.move(0, 57)
    screen.text(MGEN_BREAK_DESCS[mgen_break_idx])
    screen.level(8)
    screen.move(0, 64)
    local ch = mgen_ch[mgen_sel_ch]
    screen.text(string.format("ch%02d oct%d  K3:fire", mgen_sel_ch, ch.octave))

  elseif page == 16 then
    local ys = {44, 51, 57, 64}
    for d = 1, 4 do
      local sel    = (d == midi_audio_cur_dev)
      local routed = midi_route[5][d]
      local dname  = (midi.vports[d] and midi.vports[d].name) or ("DEV " .. d)
      if #dname > 12 then dname = string.sub(dname, 1, 11) .. "~" end
      screen.level(sel and 15 or (routed and 10 or 4))
      screen.move(0, ys[d])
      screen.text(string.format("d%d %s", d, dname))
      screen.level(routed and 15 or 3)
      screen.move(80, ys[d])
      screen.text(routed and "[X]" or "[ ]")
      screen.level(sel and 10 or 4)
      screen.move(100, ys[d])
      screen.text(string.format("ch%2d", midi_ch_audio[d]))
    end

  elseif page == 23 then
    local ys = {44, 51, 57, 64}
    for d = 1, 4 do
      local sel    = (d == niaka_cur_dev)
      local routed = midi_route[7][d]
      local dname  = (midi.vports[d] and midi.vports[d].name) or ("DEV " .. d)
      if #dname > 12 then dname = string.sub(dname, 1, 11) .. "~" end
      screen.level(sel and 15 or (routed and 10 or 4))
      screen.move(0, ys[d])
      screen.text(string.format("d%d %s", d, dname))
      screen.level(routed and 15 or 3)
      screen.move(80, ys[d])
      screen.text(routed and "[X]" or "[ ]")
      screen.level(sel and 10 or 4)
      screen.move(100, ys[d])
      screen.text(string.format("ch%2d", midi_ch[7][d]))
    end

  elseif page == 17 then
    screen.level(6)
    screen.move(0, 46)
    screen.text(string.format("mass:%.2f  spd:%.2f", spat.mass, spat.tempo))
    screen.level(3)
    screen.move(4, 54) ; screen.line(124, 54) ; screen.stroke()
    local function smark(k, ch, hi)
      local x = math.floor((spat_eff_pan(k) + 1) * 0.5 * 118) + 5
      screen.level(spat.on and (hi and 15 or 10) or 4)
      screen.move(x, 54) ; screen.text(ch)
    end
    smark("impro", "*")
    if os8_mode == "TRANS" then
      smark("o5", "O", true) ; smark("o6", "o") ; smark("o3", ".")   -- positions 8OS
    else
      smark("lead", "O", true) ; smark("av", "o") ; smark("rv", ".") -- positions POtO
    end
    screen.level(spat.on and 15 or 4)
    screen.move(100, 63)
    screen.text(spat.on and "ON" or "off")
    screen.level(4)
    screen.move(0, 63)
    screen.text(string.format("K2:mode K3:%s", spat.on and "off" or "on"))

  end

  screen.update()
end
