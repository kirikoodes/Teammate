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

local page       = 27      -- page UI courante (demarre sur le MENU / hub)

---------------------------------------------------------------------
-- etat
---------------------------------------------------------------------
local state       = "LISTEN"
local corpus      = {}
local head        = 1
local count       = 0
local last_slot   = 0
-- MODE au demarrage : RECHERCHE (nav libre, normal) ou PERFORMANCE (auto-paging agent/corpus/PERU)
perf_mode = false ; boot_choose = false
perf_last_input = 0 ; perf_last_count = 0 ; perf_corpus_t = 0 ; perf_had_diamonds = false

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
mgen_evo_meta        = false   -- Evo pilote par METABO (mode META, global)
mgen_freeze          = false   -- FREEZE : fige les patterns (stop mutation + regen auto), global
local mclk_t           = {}   -- MIDI clock in : horodatages des pulses recus
local mclk_active      = false
local mclk_pulse_count = 0    -- compteur brut de pulses 0xF8 recus
-- GLOBALES (hors limite des 200 locals du chunk) : robustesse horloge externe (OP-XY & co)
mclk_src         = 0    -- port MIDI verrouille : on ne suit QU'UN port (evite le double comptage si un device expose plusieurs ports)
mclk_last_t      = 0    -- horodatage du dernier pulse (watchdog + re-verrouillage)
mclk_bpm_f       = 0    -- BPM lisse (passe-bas) : absorbe la gigue de l'USB MIDI
mclk_src_name    = "?"  -- nom du device verrouille (affiche sur MGEN)

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
midi_route[8] = {false, false, false, false}   -- PERU = stream 8 (grains gravitationnels)
midi_ch[8]    = {8, 8, 8, 8}                    -- canal PERU par device
peru_cur_dev  = 1                               -- device selectionne (page PERU MIDI)
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
  if stream_energy and stream_energy[stream] then   -- suit l'activite du mode (meme sans device MIDI) -> source CC/OSC
    stream_energy[stream] = math.max(stream_energy[stream], (vel or 0) / 127)
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
impro_energy = 0                  -- enveloppe d'activite de l'impro (pour PERU src=IMPRO, continu)
stream_energy = {0,0,0,0,0,0,0,0} -- enveloppe d'activite par stream MIDI (POtO=2, 8OS=3, NIAKA=7...) -> sources CC/OSC
audio_pitch_cv = 0                -- AUDIO->CV : hauteur en 1V/oct (tenue pendant les silences)
mgen_nfreq = 0 ; mgen_nenergy = 0 -- derniere note de MGEN (pour alimenter NIAKABY)
function companion_feed(rms, freq, centroid, flatness)
  if (rms or 0) > comp_rms then comp_rms = rms end        -- attaque (le decay est dans la boucle metabo)
  if freq and freq > 0 then comp_freq = freq end
  if centroid and centroid > 0 then comp_centroid = centroid end
  if flatness then comp_flatness = flatness end
end

local function play_event(ev, rate_mult, mstream, pan)
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

  if style.on then len = style.artic_len(len) end          -- STYLE : articulation (staccato/legato)

  local fade = math.max(0.010, math.min(0.050, len * 0.3))    -- fondu proportionnel a la taille du grain (plancher anti-clic)
  softcut.level_slew_time(v, fade)                            -- rampe d'amplitude : fade-IN au depart, fade-OUT a l'arret (anti-clic)
  softcut.level(v, spat.on and spat_depth_mult("impro") or 1.0)
  if pan then softcut.pan(v, pan)                           -- PERU : spatialise selon le point de collision
  elseif spat.on then softcut.pan(v, spat_eff_pan("impro")) end
  softcut.loop(v, 0)
  softcut.loop_start(v, base)
  softcut.loop_end(v, base + len)

  if math.random() < REV_PROB then
    rate = -1.0
    softcut.position(v, base + len - 0.001)
  else
    softcut.position(v, base)
  end

  softcut.fade_time(v, fade)
  softcut.rate(v, rate * rate_mult)
  softcut.play(v, 1)

  local f = ev.freq > 0 and ev.freq or cur_freq
  local imp_note = freq_to_midi(f) or 60
  local imp_vel  = math.max(1, math.min(127, math.floor(ev.rms * 800)))
  if style.on then imp_vel = style.vel_scale(imp_vel) end   -- STYLE : ta dynamique
  midi_note_on(mstream or 1, imp_note, imp_vel)         -- stream 1 = IMPRO ; 8 = PERU
  companion_feed(ev.rms, f, ev.centroid, ev.flatness)   -- nourrit METABO (mode COMP)
  if (mstream or 1) == 1 then impro_energy = math.max(impro_energy, imp_vel / 127) end   -- suivi d'enveloppe de l'impro (pour PERU src=IMPRO, continu)

  clock.run(function()
    clock.sleep(math.max(0.04, len))              -- joue le grain
    midi_note_off(mstream or 1, imp_note)
    if ply_tokens[vi] == tok then
      softcut.level(v, 0)                          -- fade-OUT via le level slew (rampe douce, pas de coupe seche)
      clock.sleep(fade + 0.005)
      if ply_tokens[vi] == tok then softcut.play(v, 0) end   -- coupe seulement apres le fondu, si la voix n'a pas ete reprise
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

-- ===== ROUTEUR 8OS TRANS : sources combinables qui pilotent le matching (la "voix live") =====
os8_src        = { input = true, metabo = false, comp = false, mgen = false, wifi = false }
os8_src_keys   = { "input", "metabo", "comp", "mgen", "wifi" }
os8_src_labels = { "INPUT", "METABO", "COMP", "MGEN", "WIFI" }
os8_src_cursor = 1
os8_pitch      = false  -- ameliore : transpose le grain pour coller a la note cible (suit la melodie)
os8_trans      = 0      -- transposition manuelle en demi-tons (-24..+24), appliquee toujours
os8_spread     = 0      -- 0..1 : spread stereo des 3 voix (V5 gauche, V6 droite, V3 centre)
os8_in_gate   = false   -- voix live routee : gate
os8_in_midi   = -1      -- note MIDI cible (-1 = pas de pitch)
os8_in_rms    = 0       -- energie
os8_in_centroid = 0     -- timbre

-- ===== MODULATION INTERNE : une source pilote en continu les parametres d'un mode =====
-- comme METABO colore NIAKABY / pilote MGEN. Source au choix, profondeur reglable.
MOD_SRC_NAMES = { "METABO", "AUDIO", "MGEN", "COMP", "WIFI", "LORA" }

-- signaux normalises d'une source (act = energie/mouvement, tone = brillance/tension)
function mod_signals(src)
  if src == 1 then
    if not (metabolik and metabolik.on) then return 0, 0 end
    return (metabolik.stressFx or 0), ((metabolik.ch and metabolik.ch.growth) or 0)
  elseif src == 2 then
    return math.min(1, (rms_smooth or 0) * 8), math.min(1, (cur_centroid or 0) / 4000)
  elseif src == 3 then
    return math.min(1, mgen_nenergy or 0), math.min(1, (mgen_nfreq or 0) / 1000)
  elseif src == 4 then
    return math.min(1, (comp_rms or 0) * 8), math.min(1, (comp_centroid or 0) / 4000)
  elseif src == 5 then
    local fl = wifi_new_flash or 0   -- WIFI : activite reseaux + trafic + PIC sur nouveau reseau
    return math.max((wifi and wifi.energy) or 0, fl), math.max((wifi and wifi.traffic) or 0, fl)
  else
    -- LORA : act = energie radio (pic a chaque message) ; tone = DISTANCE du signal (proche->0, loin->1)
    return (lora and lora.energy) or 0, (lora and lora.dist) or 0
  end
end

-- --- modulation 8OS ---
os8_mod_on        = false          -- modulation active
os8_mod           = 0.5            -- profondeur 0..1
os8_mod_src       = 1              -- 1=METABO 2=AUDIO 3=MGEN
os8_mod_src_names = MOD_SRC_NAMES  -- compat
function os8_mod_sig()
  if not os8_mod_on then return 0, 0 end
  return mod_signals(os8_mod_src)
end

-- --- modulation POtO ---
poto_mod_on  = false
poto_mod     = 0.5
poto_mod_src = 1
function poto_mod_sig()
  if not poto_mod_on then return 0, 0 end
  return mod_signals(poto_mod_src)
end
-- act -> grains plus courts (jeu plus nerveux)
function poto_size_mod(base)
  if not poto_mod_on then return base end
  local act = poto_mod_sig()
  local s = base * (1 - poto_mod * act * 0.7)
  return s < 0.03 and 0.03 or s
end
-- tone -> pitch monte (jusqu'a +1 octave a fond), clamp 0.25..4
function poto_rate()
  local r = p_poto_rate
  if poto_mod_on then local _, tone = poto_mod_sig() ; r = r * (2 ^ (poto_mod * tone)) end
  if r < 0.25 then r = 0.25 elseif r > 4 then r = 4 end
  return r
end

local function os8_f2midi(f) return (f and f > 30) and math.floor(69 + 12*math.log(f/440)/math.log(2) + 0.5) or -1 end

-- met a jour la voix live : parmi les sources actives, la PLUS FORTE mene (appelee ~30 Hz)
function os8_route()
  os8_in_gate = false ; os8_in_midi = -1 ; os8_in_rms = 0 ; os8_in_centroid = 0
  local best = -1
  local s = os8_src
  if s.input and cur_gate > 0.5 and rms_smooth > best then
    best = rms_smooth ; os8_in_gate = true ; os8_in_midi = os8_f2midi(cur_freq) ; os8_in_rms = rms_smooth ; os8_in_centroid = cur_centroid
  end
  if s.metabo then local e = meta_energy or 0
    if e > 0.05 and e > best then best = e ; os8_in_gate = true ; os8_in_midi = os8_f2midi(meta_freq) ; os8_in_rms = e ; os8_in_centroid = (meta_freq or 0)*3 end
  end
  if s.comp then local e = comp_rms or 0
    if e > 0.02 and e > best then best = e ; os8_in_gate = true ; os8_in_midi = os8_f2midi(comp_freq) ; os8_in_rms = e ; os8_in_centroid = comp_centroid or 0 end
  end
  if s.mgen then local e = mgen_nenergy or 0
    if e > 0.05 and e > best then best = e ; os8_in_gate = true ; os8_in_midi = os8_f2midi(mgen_nfreq) ; os8_in_rms = e ; os8_in_centroid = (mgen_nfreq or 0)*3 end
  end
  if s.wifi then local e = wifi.energy or 0
    if e > 0.05 and e > best then best = e ; os8_in_gate = true ; os8_in_midi = os8_f2midi(wifi.freq()) ; os8_in_rms = e ; os8_in_centroid = 3000 end
  end
end

-- ===== SOURCE POtO : sources combinables (comme le 8OS) =====
-- audio (INPUT, COMP) -> enregistrees dans le buffer ; toutes -> suivi de hauteur (note MIDI)
poto_src        = { input = true, metabo = false, comp = false, mgen = false, wifi = false }
poto_src_keys   = { "input", "metabo", "comp", "mgen", "wifi" }
poto_src_labels = { "INPUT", "METABO", "COMP", "MGEN", "WIFI" }
poto_src_cursor = 1
poto_in_midi    = -1   -- hauteur suivie (la source active la PLUS FORTE mene)

-- met a jour la hauteur suivie par le POtO (~30 Hz)
function poto_route()
  poto_in_midi = -1
  local best, bf = -1, 0
  local s = poto_src
  if s.input and (cur_freq or 0) > 30 and rms_smooth > best then best = rms_smooth ; bf = cur_freq end
  if s.metabo then local e = meta_energy or 0 ; if e > 0.05 and e > best then best = e ; bf = meta_freq end end
  if s.comp   then local e = comp_rms or 0    ; if e > 0.02 and e > best then best = e ; bf = comp_freq end end
  if s.mgen   then local e = mgen_nenergy or 0; if e > 0.05 and e > best then best = e ; bf = mgen_nfreq end end
  if s.wifi   then local e = wifi.energy or 0 ; if e > 0.05 and e > best then best = e ; bf = wifi.freq() end end
  poto_in_midi = (bf and bf > 30) and freq_to_midi(bf) or -1
end

-- routage d'enregistrement du buffer POtO selon les sources audio actives
-- INPUT -> entree hardware ; COMP -> sortie du compagnon (voix 2). Ne touche pas
-- la voix 4 quand le 8OS l'utilise (modes mutuellement exclusifs).
function poto_rec_route()
  if os8_mode ~= "OFF" then return end
  local lin = poto_src.input and 1.0 or 0.0
  softcut.level_input_cut(1, POTO_REC_V, lin)
  softcut.level_input_cut(2, POTO_REC_V, lin)
  softcut.level_cut_cut(2, POTO_REC_V, poto_src.comp and 1.0 or 0.0)
  softcut.rec(POTO_REC_V, (poto_src.input or poto_src.comp) and 1 or 0)   -- gel si aucune source audio
end

-- application IMMEDIATE (mid-grain) du rate + detune spread sur les voix POtO en cours.
-- Appele ~30 Hz : pitch/spread reagissent sans attendre le prochain grain. (la taille
-- de grain, elle, ne peut changer qu'au prochain grain : elle definit la boucle.)
function poto_live_update()
  if not p_poto_on then return end
  local lv, av, rv = POTO_PLY_V[1], POTO_PLY_V[2], 3
  local base = poto_rate()
  softcut.rate(lv, base)
  local r_av, r_rv
  if p_poto_poly == 5 then
    local sp = poto_smart_params()
    r_av = base * sp.r2 ; r_rv = base * sp.r3
  else
    local t2 = POTO_POLY_RATES[p_poto_poly][2]
    local t3 = POTO_POLY_RATES[p_poto_poly][3]
    r_av = t2 and (base * t2) or (base * (1 + p_poto_spread))
    r_rv = t3 and (base * t3) or math.max(0.5, base * (1 - p_poto_spread * 2))
  end
  softcut.rate(av, r_av) ; softcut.rate(rv, r_rv)
end

-- pan stereo d'une voix TRANS selon le spread (V5 gauche / V6 droite / V3 centre)
-- MOD : l'energie de la source elargit le spread.
function os8_pan(v)
  local s = os8_spread or 0
  if os8_mod_on then local act = os8_mod_sig() ; s = math.min(1, s + os8_mod * act * 0.8) end
  if v == 5 then return -s elseif v == 6 then return s else return 0 end
end

-- rate de lecture du grain : transpo manuelle (os8_trans) TOUJOURS appliquee,
-- + suivi de la note cible quand PITCH est actif, + MOD (brillance/tension monte le pitch).
function os8_grain_rate(g)
  local semi = os8_trans or 0
  if os8_pitch and os8_in_midi >= 0 and g.note and g.note >= 0 then
    semi = semi + (os8_in_midi - g.note)
  end
  if os8_mod_on then local _, tone = os8_mod_sig() ; semi = semi + os8_mod * tone * 12 end
  local r = 2 ^ (semi / 12)
  if r < 0.25 then r = 0.25 elseif r > 4 then r = 4 end
  return r
end

-- longueur de lecture du grain : pilotee en LIVE par os8_size, INDEPENDANTE de la
-- duree enregistree (bornee au buffer) -> grains plus courts ET plus longs.
-- MOD : l'energie de la source raccourcit les grains (jeu plus nerveux).
function os8_play_len(g)
  local gs = os8_size
  if os8_mod_on then local act = os8_mod_sig() ; gs = gs * (1 - os8_mod * act * 0.7) end
  local maxlen = (OS8_OFFSET + OS8_DUR) - g.pos
  if gs > maxlen then gs = maxlen end
  if gs < 0.02 then gs = 0.02 end
  return gs
end

-- cherche le grain le plus proche (attract=true) ou le plus eloigne (false)
-- skip1/skip2 : positions a ignorer pour eviter les doublons entre voix
-- score combine : pitch 0.55 + energie 0.35 + centroide 0.10 ; pilote par la voix routee
local function os8_find_grain(attract, skip1, skip2)
  if #os8_bank == 0 then return nil end
  local live_midi = os8_in_midi
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
      local mx_rms = math.max(os8_in_rms, g_rms, 0.001)
      local de     = math.abs(os8_in_rms - g_rms) / mx_rms
      -- distance timbre centroide
      local dc = math.abs(g.centroid - os8_in_centroid) / 8000.0
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
  if mode ~= "OFF" and peru_on then peru_on = false end       -- PERU partage les voix -> exclusif

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
        while t < dur and os8_mode == "TRANS" and os8_in_gate do
          local step = math.min(0.02, dur - t)
          clock.sleep(step) ; t = t + step
        end
      end
    end

    -- boucle grain V5 LOCK (grain le plus proche, gate-driven)
    clock.run(function()
      while os8_mode == "TRANS" do
        if os8_in_gate then
          local g = os8_find_grain(true, nil, nil)
          if g then
            os8_pos_v5 = g.pos
            local gs = os8_play_len(g)
            softcut.fade_time(5, math.min(0.02, gs * 0.5))
            softcut.loop(5, 1)                              -- boucle le grain (crossfade aux bornes)
            softcut.loop_start(5, g.pos)
            softcut.loop_end(5,   g.pos + gs)
            softcut.position(5, g.pos)
            softcut.rate(5, os8_grain_rate(g))
            if not spat.on then softcut.pan(5, os8_pan(5)) end
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
        if os8_in_gate then
          local g = os8_find_grain(true, os8_pos_v5, nil)
          if not g then g = os8_find_grain(true, nil, nil) end
          if g then
            os8_pos_v6 = g.pos
            local gs = os8_play_len(g)
            softcut.fade_time(6, math.min(0.02, gs * 0.5))
            softcut.loop(6, 1)
            softcut.loop_start(6, g.pos)
            softcut.loop_end(6,   g.pos + gs)
            softcut.position(6, g.pos)
            softcut.rate(6, os8_grain_rate(g))
            if not spat.on then softcut.pan(6, os8_pan(6)) end
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
        if os8_in_gate then
          local g = os8_find_grain(true, os8_pos_v5, os8_pos_v6)
          if not g then g = os8_find_grain(true, nil, nil) end
          if g then
            os8_pos_v3 = g.pos
            local gs = os8_play_len(g)
            softcut.fade_time(3, math.min(0.02, gs * 0.5))
            softcut.loop(3, 1)
            softcut.loop_start(3, g.pos)
            softcut.loop_end(3,   g.pos + gs)
            softcut.position(3, g.pos)
            softcut.rate(3, os8_grain_rate(g))
            if not spat.on then softcut.pan(3, os8_pan(3)) end
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
  if on and peru_on then peru_on = false end                 -- PERU partage les voix 5,6 -> exclusif
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
        gs = poto_size_mod(gs)
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
          softcut.rate(lv, poto_rate())                    -- live : le rate suit le reglage en continu
          if spat.on then softcut.pan(lv, spat_eff_pan("lead")) end
          if not active then
            softcut.loop(lv, 1)
            softcut.position(lv, bp)
            softcut.play(lv, 1)
            active = true
          end
          local pn_lv = poto_in_midi >= 0 and poto_in_midi or nil
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
        local gs  = poto_size_mod(p_poto_size)
        local tgt = (poto_lead_zone - 0.05 + POTO_DUR) % POTO_DUR
        zone = (zone * 0.92 + tgt * 0.08) % POTO_DUR
        if zone + gs > POTO_DUR then zone = POTO_DUR - gs - 0.01 end
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > gs + 0.05 then
          local bp = POTO_OFFSET + zone
          local r_av, av_vol_mult
          if p_poto_poly == 5 then
            local sp = poto_smart_params()
            r_av = poto_rate() * sp.r2 ; av_vol_mult = sp.av_lv
          else
            local tbl = POTO_POLY_RATES[p_poto_poly][2]
            r_av = tbl and (poto_rate() * tbl) or (poto_rate() * (1 + p_poto_spread))
            av_vol_mult = 0.65
          end
          local ft = math.min(0.020, gs * 0.15)
          softcut.fade_time(av, ft)
          softcut.loop_start(av, bp)
          softcut.loop_end(av, bp + gs)
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
          local pn_av = poto_in_midi >= 0 and poto_in_midi or nil
          if pn_av then midi_note_on(2, pn_av, math.floor(p_poto_vol * 83)) end
          clock.sleep(gs)
          if pn_av then midi_note_off(2, pn_av) end
        else
          if active then softcut.play(av, 0) ; active = false end
          clock.sleep(gs + 0.03)
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
        local gs  = poto_size_mod(p_poto_size)
        local tgt = (poto_lead_zone + POTO_DUR * 0.5) % POTO_DUR
        zone = (zone * 0.95 + tgt * 0.05) % POTO_DUR
        if zone + gs > POTO_DUR then zone = POTO_DUR - gs - 0.01 end
        local dist = (wp - zone + POTO_DUR) % POTO_DUR
        if dist > gs + 0.05 then
          local bp = POTO_OFFSET + zone
          local r_rv, rv_vol_mult
          if p_poto_poly == 5 then
            local sp = poto_smart_params()
            r_rv = poto_rate() * sp.r3 ; rv_vol_mult = sp.rv_lv
          else
            local tbl = POTO_POLY_RATES[p_poto_poly][3]
            r_rv = tbl and (poto_rate() * tbl) or math.max(0.5, poto_rate() * (1 - p_poto_spread * 2))
            rv_vol_mult = 0.40
          end
          local ft = math.min(0.020, gs * 0.15)
          softcut.fade_time(rv, ft)
          softcut.loop_start(rv, bp)
          softcut.loop_end(rv, bp + gs)
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
          local pn_rv = poto_in_midi >= 0 and poto_in_midi or nil
          if pn_rv then midi_note_on(2, pn_rv, math.floor(p_poto_vol * 51)) end
          clock.sleep(gs)
          if pn_rv then midi_note_off(2, pn_rv) end
        else
          if active then softcut.play(rv, 0) ; active = false end
          clock.sleep(gs + 0.05)
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

-- taux d'evolution effectif : soit le reglage manuel, soit pilote par METABO (mode META)
function mgen_eff_mut()
  if mgen_freeze then return 0 end          -- FREEZE : aucune mutation, patterns figes
  if mgen_evo_meta then
    return (metabolik and metabolik.on) and (metabolik.stressFx or 0) * 0.5 or 0
  end
  return mgen_mut_rate
end

local function mgen_mutate_seq(ci)
  local ch  = mgen_ch[ci]
  local sn  = MGEN_STYLE_NAMES[ch.style_idx]
  local def = MGEN_STYLE_DEF[sn]
  local sc  = MGEN_SCALES[MGEN_SCALE_NAMES[mgen_scale_idx]]
  local mr  = mgen_eff_mut()
  for s = 1, #ch.seq do
    if math.random() > mr then goto next_step end
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
    if mclk_active then clock.sync(1/4) end   -- depart cale sur la grille (tempo = horloge externe), natif sans busy-wait
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
              if vel / 127 > (ch.energy or 0) then ch.energy = vel / 127 end   -- activite PAR PISTE (sources MG1-8)
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
            if mgen_eff_mut() > 0 then mgen_mutate_seq(i) end
          end
        end
      end
      -- sync : attend exactement 6 pulses MIDI si clock externe active
      -- sinon sleep interne base sur mgen_bpm
      if mclk_active then
        clock.sync(1/4)     -- 1/16 note calee sur la grille Norns (tempo suit l'horloge externe) : natif, ZERO busy-wait, fiable 40-220 BPM
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

  -- influence MIND -> compagnon (DYNAMIQUE : il suit ton volume/densite de jeu).
  -- tu charges (fort/dense) -> reponses plus actives/denses ; doux/clairseme ->
  -- plus d'espace. Opt-in (K3 page MIND), non destructif : off => compagnon inchange.
  if mind and mind.on then
    local act = math.max(mind.energy or 0, mind.density or 0, (mind.drive or 0) * 0.85)
    w.DENSIFICATION = w.DENSIFICATION + act * 0.5
    w.IMITATION     = w.IMITATION     + act * 0.2
    w.SPARSE        = w.SPARSE        + (1 - act) * 0.4
    w.SILENCE       = w.SILENCE       + (1 - act) * 0.3
  end

  -- IDENTITE DE LA CREATURE -> compagnon (TOUJOURS actif, subtil) : l'agent et le
  -- compagnon sont UN seul etre. Son humeur colore le jeu, son niveau lui donne
  -- de l'aplomb avec le temps. excite -> dense ; repos -> espace ; ennui -> contraste.
  do
    local e   = (mind and mind.energy) or 0
    local b   = (mind and mind.build) or 0
    local stc = (metabolik and metabolik.on and metabolik.stressFx) or 0
    local amt = 0.20 + math.min(1, (creature_level or 1) / 10) * 0.25   -- s'affirme avec le niveau
    w.DENSIFICATION = w.DENSIFICATION + math.max(0, b) * amt
    w.IMITATION     = w.IMITATION     + e * amt * 0.5
    w.SPARSE        = w.SPARSE        + (1 - e) * amt * 0.5
    w.CONTRASTE     = w.CONTRASTE     + stc * amt * 0.6
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
  if style.on then n = style.n(n) end                       -- STYLE : longueur de phrase a ta maniere
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
  if style.on and math.random() < 0.7 then return style.rate() end  -- STYLE : intervalles a ta maniere
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
  if style.on then gap = style.gap(beat) end                -- STYLE : ton timing (IOI / grille-rubato)
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
      style.observe(rec_t0, dur, avg, cur_freq)   -- apprend ta maniere de jouer
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
-- ===== MEMOIRE DE MOTIFS : TEAMMATE se souvient de tes phrases et les ramene, transformees =====
-- (globals : la limite Lua de 200 locals dans le chunk principal est atteinte)
motifs = {}                -- banque des phrases marquantes du joueur (max 10)
motif_last_t = 0
motif_last_i = 0           -- dernier motif joue (anti-repetition)

function capture_motif(buf)
  if #buf < 2 then return end
  local e = 0 ; for _, ev in ipairs(buf) do e = e + (ev.rms or 0) end ; e = e / #buf
  if e < 0.02 then return end                       -- ignore les phrases trop faibles
  local copy = {} ; for i, ev in ipairs(buf) do copy[i] = ev end
  motifs[#motifs + 1] = { evs = copy, energy = e }
  while #motifs > 10 do table.remove(motifs, 1) end
  if creature_xp_add then creature_xp_add(5) end   -- motif appris -> XP
end

-- choisit un motif AU HASARD mais evite de rejouer le meme deux fois de suite
function motif_pick()
  if #motifs == 0 then return nil end
  if #motifs == 1 then motif_last_i = 1 ; return motifs[1] end
  local i ; repeat i = math.random(#motifs) until i ~= motif_last_i
  motif_last_i = i ; return motifs[i]
end

MOTIF_SEMIS = { 0, 0, 7, 12, -12, 5, -5 }
function play_motif(m)
  if not m then return end
  local semis = MOTIF_SEMIS[math.random(#MOTIF_SEMIS)]   -- transpose
  local rate  = 2 ^ (semis / 12)
  local order = {}
  for i = 1, #m.evs do order[i] = i end
  if math.random() < 0.3 then                            -- parfois renverse (developpe au lieu de copier)
    local r = {} ; for i = #order, 1, -1 do r[#r + 1] = order[i] end ; order = r
  end
  if #order > 3 and math.random() < 0.35 then            -- parfois un FRAGMENT (pas toute la phrase)
    local len   = 2 + math.random(#order - 2)
    local start = math.random(#order - len + 1)
    local frag  = {} ; for i = start, start + len - 1 do frag[#frag + 1] = order[i] end
    order = frag
  end
  strat_name = "MOTIF"
  for k, idx in ipairs(order) do
    local ev = m.evs[idx]
    play_event(ev, rate)
    mark_played(ev.slot)
    last_slot = ev.slot
    if k < #order then
      -- TON rythme : l'ecart suit la DUREE de ta note (au lieu d'un metronome fixe), legerement humanise
      local gap = math.max(0.04, math.min(1.2, (ev.duration or 0.15)))
      clock.sleep(gap * (0.9 + math.random() * 0.2))
    end
  end
end

-- rappel d'un motif pendant un creux, plus probable en phase de montee. Opt-in (mind.on).
function maybe_recall_motif()
  if not comp_on then return false end
  if not (mind and mind.on) then return false end
  if #motifs == 0 then return false end
  local now = util.time()
  if now - motif_last_t < 6.0 then return false end
  local arc = (mind.arc or 0)
  if math.random() > (0.15 + arc * 0.5) then return false end
  motif_last_t = now
  local m = motif_pick()
  state = "THINK"
  clock.run(function()
    local ok, err = pcall(play_motif, m)
    if not ok then print("tm motif: " .. tostring(err)) end
    state = "REST" ; clock.sleep(0.4 + math.random()) ; state = "LISTEN"
  end)
  return true
end

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
        capture_motif(phrase_buf)
        phrase_buf = {}
        if count >= MIN_CORPUS and math.random() < p_reply then
          do_respond(n_phrase, 0.3)
        end

      elseif #phrase_buf == 0 and sil_sec > p_sil_max and count >= MIN_CORPUS then
        if maybe_recall_motif() then goto continue end   -- il ramene une de tes phrases (transformee)
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
local function midi_clock_in(data, src)
  local b = data[1]
  if b and b >= 0xB0 and b <= 0xBF then   -- Control Change : moniteur + learn
    cc_rx_cc = data[2] or -1
    cc_rx_ch = (b - 0xB0) + 1
    cc_rx_t  = util.time()
    if cc_learn and cc_cursor >= 1 and cc_lanes[cc_cursor] then
      cc_lanes[cc_cursor].num = cc_rx_cc
      cc_ch    = cc_rx_ch
      cc_learn = false                     -- one-shot
    end
    return
  end
  -- Messages d'horloge : VERROUILLAGE SUR UN SEUL PORT.
  -- Un device qui expose plusieurs ports USB (ex. OP-XY) peut envoyer les pulses en double
  -- sur 2 ports -> comptage x2 -> BPM faux et instable. On ne suit qu'UNE source a la fois ;
  -- on ne re-verrouille sur un autre port que si l'ancien s'est tu (>0.3 s sans pulse).
  if b == 0xFA or b == 0xFC or b == 0xF8 then
    if src then
      if mclk_src == 0 or (src ~= mclk_src and (util.time() - mclk_last_t) > 0.3) then
        mclk_src = src ; mclk_t = {} ; mclk_pulse_count = 0 ; mclk_bpm_f = 0   -- (re)verrouille
        mclk_src_name = (midi.vports[src] and midi.vports[src].name) or ("DEV " .. src)
      elseif src ~= mclk_src then
        return   -- pulse d'un AUTRE port (doublon) -> ignore
      end
    end
  end
  if b == 0xFA then                -- transport start
    mclk_t           = {}
    mclk_pulse_count = 0
    mclk_active      = true
    mclk_last_t      = util.time()
    mclk_bpm_f       = 0
  elseif b == 0xFC then            -- transport stop
    mclk_t           = {}
    mclk_pulse_count = 0
    mclk_active      = false
  elseif b == 0xF8 then            -- timing clock pulse (24 par noire)
    mclk_pulse_count = mclk_pulse_count + 1
    local now = util.time()
    mclk_last_t      = now
    table.insert(mclk_t, now)
    if #mclk_t > 48 then table.remove(mclk_t, 1) end   -- fenetre longue (~2 noires) : moyenne la gigue USB
    if #mclk_t >= 24 then                              -- attend ~1 noire de pulses avant d'estimer
      local avg_pulse = (mclk_t[#mclk_t] - mclk_t[1]) / (#mclk_t - 1)
      local bpm = 60.0 / (avg_pulse * 24)
      if bpm >= 30 and bpm <= 300 then
        mclk_bpm_f  = (mclk_bpm_f <= 0) and bpm or (mclk_bpm_f + (bpm - mclk_bpm_f) * 0.15)   -- passe-bas
        mgen_bpm    = math.floor(mclk_bpm_f + 0.5)
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

-- MIND : couche d'ecoute partagee (observation). Chargement defensif aussi.
mind = nil
_mind_ok, _mind_mod = pcall(include, 'lib/mind')
if _mind_ok and type(_mind_mod) == "table" then
  mind = _mind_mod
else
  print("MIND indisponible (lib/mind.lua manquant) : " .. tostring(_mind_mod))
  mind = {
    energy=0, build=0, density=0, tension=0, phrase="--", phrase_len=0, mood="--",
    update = function() end,
    answer_window = function() return false end,
    redraw = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("MIND")
      screen.level(4) ; screen.move(2, 36) ; screen.text("lib/mind.lua absent")
      screen.update()
    end,
  }
end
_mind_ok = nil ; _mind_mod = nil

-- STYLE : profil de jeu du joueur (apprend ta maniere). Chargement defensif.
style = nil
_style_ok, _style_mod = pcall(include, 'lib/style')
if _style_ok and type(_style_mod) == "table" then
  style = _style_mod
else
  print("STYLE indisponible (lib/style.lua manquant) : " .. tostring(_style_mod))
  style = {
    on = false, ioi = 0.4, density = 0, grid = 0, artic = 0.6, phrase_n = 3,
    interval = 0.3, dir = 0, reg = 0.5, vel = 0.5, vel_rng = 0.3,
    observe = function() end,
    gap = function(b) return math.max(0.03, b or 0.1) end,
    n = function(d) return d or 2 end,
    rate = function() return 1.0 end,
    vel_scale = function(b) return b or 100 end,
    artic_len = function(l) return l end,
    redraw = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("STYLE")
      screen.level(4) ; screen.move(2, 36) ; screen.text("lib/style.lua absent")
      screen.update()
    end,
  }
end
_style_ok = nil ; _style_mod = nil

-- WIFI : activite des reseaux autour du norns -> musique. Chargement defensif.
wifi = nil
_wifi_ok, _wifi_mod = pcall(include, 'lib/wifi')
if _wifi_ok and type(_wifi_mod) == "table" then
  wifi = _wifi_mod
else
  print("WIFI indisponible (lib/wifi.lua manquant) : " .. tostring(_wifi_mod))
  wifi = {
    on = false, nets = {}, count = 0, traffic = 0, energy = 0, newcount = 0,
    poll = function() end,
    note_for = function() return 60 end,
    redraw = function()
      screen.clear() ; screen.level(15)
      screen.move(2, 20) ; screen.text("WIFI")
      screen.level(4) ; screen.move(2, 36) ; screen.text("lib/wifi.lua absent")
      screen.update()
    end,
  }
end
_wifi_ok = nil ; _wifi_mod = nil

-- les notes WiFi sont calees sur la GAMME et la tonalite de MGEN (degre le plus proche)
wifi.snap = function(midi)
  local sc = MGEN_SCALES[MGEN_SCALE_NAMES[mgen_scale_idx]]
  if not sc then return midi end
  local rel = ((midi - mgen_root) % 12 + 12) % 12
  local best, bd = sc[1], 999
  for _, s in ipairs(sc) do local dd = math.abs(s - rel) ; if dd < bd then bd = dd ; best = s end end
  local oct = math.floor((midi - mgen_root) / 12)
  return math.max(0, math.min(127, mgen_root + oct * 12 + best))
end

-- ===== LORA : sonification de l'activite radio (via pont OSC) =====
lora = nil
_lora_ok, _lora_mod = pcall(include, 'lib/lora')
if _lora_ok and type(_lora_mod) == "table" then
  lora = _lora_mod
else
  print("LORA indisponible (lib/lora.lua manquant) : " .. tostring(_lora_mod))
  lora = {
    on = false, rssi = -120, dist = 1, energy = 0, count = 0,
    last_sender = "", last_text = "", senders = {},
    dev = 1, ch = 1,
    sig_for = function() return { trans = 0, mch = 1, reg = 48, seen = 0 } end,
    note_for = function() return 60 end,
    on_rx = function() end, tick = function() end,
    redraw = function()
      screen.clear() ; screen.level(15) ; screen.move(2, 20) ; screen.text("LORA")
      screen.level(4) ; screen.move(2, 36) ; screen.text("lib/lora.lua absent") ; screen.update()
    end,
  }
end
_lora_ok = nil ; _lora_mod = nil
-- les notes LoRa sont calees sur la GAMME et la tonalite de MGEN (comme le WiFi)
lora.snap = wifi.snap

-- sauvegarde isolee des signatures d'expediteurs (fichier separe, comme les lieux WiFi)
function lora_senders_save()
  pcall(function()
    if norns and norns.state and norns.state.data then
      tab.save(lora.senders, norns.state.data .. "lora_senders.data")
    end
  end)
end

-- emet une note sur la sortie MIDI LoRa et programme son note_off
function lora_emit_note(note, vel, ch, dur)
  local out = midi_outs[lora.dev]
  if not out then return end
  out:note_on(note, vel or 90, ch or lora.ch)
  clock.run(function() clock.sleep(dur or 0.25) ; out:note_off(note, 0, ch or lora.ch) end)
end

-- contenu du message -> melodie : chaque octet devient une note (gamme MGEN)
function lora_play_text(text, sig)
  if not text or #text == 0 then return end
  clock.run(function()
    local ch   = (sig and sig.mch) or lora.ch
    local nmax = math.min(#text, 24)                  -- borne la phrase
    for i = 1, nmax do
      local b = text:byte(i)
      lora_emit_note(lora.note_for(b, sig), 70 + (b % 40), ch, 0.18)
      clock.sleep(0.12)
    end
  end)
end

-- MESSAGE RECU : geste d'accueil + melodie du contenu + appel-reponse
function lora_rx(sender, rssi, snr, len, text)
  local sig = lora.sig_for(sender or "?")
  lora.on_rx(sender, rssi, snr, len, text)
  lora_senders_save()
  if not lora.on then return end
  lora_emit_note(lora.note_for(60, sig), 112, (sig and sig.mch) or lora.ch, 0.2)   -- accent = on te parle
  lora_play_text(text, sig)                                                         -- le message se joue
  if (util.time() - (lora.tx_t or 0)) < 8 then                                      -- c'est une REPONSE a ton envoi
    clock.run(function() clock.sleep(0.6 + (len or #(text or "")) * 0.12) ; pcall(maybe_recall_motif) end)
  end
end

-- TU ENVOIES : petit arpege montant = l'appel (ouvre la fenetre d'appel-reponse)
function lora_tx(dest, len)
  lora.tx_t = util.time()
  if not lora.on then return end
  local sig = lora.sig_for(dest or "out")
  clock.run(function()
    for i = 0, 3 do
      lora_emit_note(lora.note_for(48 + i * 5, sig), 96, (sig and sig.mch) or lora.ch, 0.16)
      clock.sleep(0.1)
    end
  end)
end

-- simulateur : declenche un faux message recu (test SANS materiel)
function lora_test()
  local names = { "alice", "node-7", "bob", "sensor", "KO" }
  local msgs  = { "hello", "ping", "ca va ?", "data:42", "<3 du large" }
  local k     = (lora.count % #names) + 1
  lora_rx(names[k], -40 - math.random(0, 70), 8, nil, msgs[(lora.count % #msgs) + 1])
end

-- ===== CC GEN : 16 CC (1..16) avec une INTELLIGENCE INDEPENDANTE par CC =====
-- chaque CC choisit sa source (signal interne de TEAMMATE ou mouvement autonome),
-- est lisse, et envoye sur un device + canal MIDI (pour piloter les CC d'un OP-1).
cc_on     = false      -- master : armable depuis LIVE (gate tout le moteur CC)
cc_rx_cc  = -1         -- moniteur : dernier numero de CC recu en entree
cc_rx_ch  = 0          -- canal de ce CC
cc_rx_t   = 0          -- horodatage (pour l'affichage "recent")
cc_learn  = false      -- si vrai, le prochain CC recu se copie dans la lane selectionnee
cc_k1_down = false ; cc_k1_moved = false   -- K1 maintenu + E3 = mode CC/TRIG/GATE (tap = learn)
cc_dev    = 1          -- device MIDI de sortie (1..4)
cc_ch     = 1          -- canal MIDI
cc_cursor = 0          -- 0 = ligne OUT (device/canal), 1..16 = les CC
CC_SRC    = { "OFF", "ENRG", "TENS", "ARC", "DENS", "STRS", "WIFI", "STYL", "LFO", "WALK", "MO1", "MO2", "MO3", "MO4",
              "IMPR", "POTO", "8OS", "MGEN", "AUD", "PERU", "NIAK", "MOVE",   -- tous les modes comme sources
              "MG1", "MG2", "MG3", "MG4", "MG5", "MG6", "MG7", "MG8",         -- pistes MGEN individuelles
              "TIMB", "PTCH", "AGT" }                                          -- AUDIO -> CV : timbre, hauteur 1V/oct, gate
cc_lanes  = {}         -- rempli dans init : { src, on, val, phase, walk } par CC

-- ===== OSC OUT (page 45) : pilote un module externe en OSC (ex. HAT CV/Gate sur un Pi separe) =====
-- 8 sorties, chacune = une adresse /cv/N + une source (memes que la CC). Envoie float 0..1 vers host:port.
OSCO_PAGE   = 45
OSCO_N      = 8
osco_lanes  = {}                    -- rempli dans init : { src, on, val, phase, walk } par sortie CV
osco_on     = false                 -- arme depuis LIVE : envoie l'OSC (sinon la page anime mais n'envoie rien)
osco_host   = "pigeons.local"       -- hote du module externe (ip ou nom .local)
osco_port   = 9000                  -- port OSC d'ecoute du module
osco_cursor = 0                     -- 0 = ligne destination (host:port), 1..8 = les sorties CV

-- ===== SAMT (السمت) : capteurs de mouvement via OSC (port 10111) =====
-- Capte TOUT OSC numerique -> chaque valeur = un axe auto-normalise 0..1. 4 slots
-- MO1-4 apprennent un axe (bouge le capteur) et deviennent des sources CC (page CC).
samt_mon   = {}                            -- key "path#i" -> { lo, hi, val, raw, t }
samt_last  = { key = "", val = 0, t = 0 }  -- dernier axe recu (moniteur RX)
samt_slot  = { {dest=1}, {dest=1}, {dest=1}, {dest=1} }   -- 4 slots MO : .key .val + .dest (1=cc 2=TILT 3=GRAIN)
SAMT_DEST  = { "cc", "X", "Y", "ROT" }     -- destination : cc / axe X PERU / axe Y PERU / ROTATION -> grain suivant-precedent
samt_learn = 0                             -- >0 : le prochain axe qui bouge se lie a ce slot
samt_cur   = 1                             -- slot selectionne sur la page
samt_mon_off = 0                           -- MONITOR (page 43) : offset de defilement de la liste des axes
-- SNOT (page 44) : instrument gestuel -> 1 axe declenche une note, 1 axe donne la hauteur, vers un device/canal MIDI.
-- 4 SNOT INDEPENDANTS = un par capteur/danseur (chacun son axe trigger, son axe hauteur, son device/canal, sa plage).
samt_notes = {
  { trig = nil, pitch = nil, dev = 1, ch = 1, lo = 36, hi = 84, thr = 0.30, on = false, learn = 0, pv = 0, last_t = 0, play_t = 0 },
  { trig = nil, pitch = nil, dev = 1, ch = 2, lo = 36, hi = 84, thr = 0.30, on = false, learn = 0, pv = 0, last_t = 0, play_t = 0 },
  { trig = nil, pitch = nil, dev = 1, ch = 3, lo = 36, hi = 84, thr = 0.30, on = false, learn = 0, pv = 0, last_t = 0, play_t = 0 },
  { trig = nil, pitch = nil, dev = 1, ch = 4, lo = 36, hi = 84, thr = 0.30, on = false, learn = 0, pv = 0, last_t = 0, play_t = 0 },
}
samt_note_cur = 1   -- SNOT selectionne (1..4)
samt_note_fld = 1   -- champ : 1=SNOT# 2=TRIG 3=PITCH 4=DEV 5=CH 6=LO 7=HI 8=THR
samt_on    = false                         -- arme depuis LIVE : ON = les capteurs pilotent les sources MO
samt_energy = 0                            -- energie de mouvement globale (0..1, decroit) — le danseur
samt_move   = 0                            -- pic de mouvement instantane (consomme par la boucle 30Hz)
samt_trig_t = 0                            -- horodatage du dernier trigger (pic de geste)
samt_thr    = 0.08                         -- threshold / deadzone : ignore le bruit du capteur au repos (E3 sur la page)
-- ANALYSE du mouvement (comme MIND pour le son) : arc long, brusquerie, immobilite
samt_build  = 0                            -- niveau soutenu / arc (mouvement dans la duree)
samt_jerk   = 0                            -- brusquerie (geste sec/staccato vs fluide)
samt_still  = 0                            -- duree d'immobilite (s)
samt_pmm    = 0                            -- mouvement du tick precedent (pour la brusquerie)
samt_mind_on = false                       -- MOVE : l'agent ECOUTE le mouvement (equivalent de MIND pour le geste)
peru_spawn   = false                       -- MOVE : le mouvement fait APPARAITRE des grains (le grain selectionne) dans PERU
peru_still   = 0                            -- duree d'immobilite des diamants (pour le clear auto a 4 s)
samt_penergy = 0                            -- energie du tick precedent (detection de CHANGEMENT -> spawn)
peru_spawn_t = 0                            -- horodatage du dernier spawn (anti-rafale)
function samt_rx(path, args)
  for i = 1, #(args or {}) do
    local x = tonumber(args[i])
    if x then
      local key = (path or "?") .. "#" .. i
      local a = samt_mon[key]
      if not a then a = { lo = x, hi = x, val = 0.5 } ; samt_mon[key] = a end
      if x < a.lo then a.lo = x end
      if x > a.hi then a.hi = x end
      local span = a.hi - a.lo
      local norm = (span > 1e-6) and ((x - a.lo) / span) or 0.5    -- auto-normalise 0..1
      a.val = (a.val or 0.5) + (norm - (a.val or 0.5)) * 0.3        -- lissage anti-jitter (repos)
      a.raw = x ; a.t = util.time()
      local mv = math.abs(a.val - (a.pv or a.val)) ; a.pv = a.val   -- variation = mouvement
      if mv > samt_move then samt_move = mv end
      samt_last = { key = key, val = a.val, t = a.t }
      if samt_learn >= 1 and span > 0.05 then samt_slot[samt_learn].key = key ; samt_learn = 0 end  -- LEARN slot MO
      if span > 0.05 then   -- LEARN SNOT : lie l'axe qui bouge au TRIG (1) ou PITCH (2) du SNOT en apprentissage
        for ni = 1, 4 do local sn = samt_notes[ni]
          if sn.learn == 1 then sn.trig = key ; sn.learn = 0
          elseif sn.learn == 2 then sn.pitch = key ; sn.learn = 0 end
        end
      end
      for s = 1, 4 do if samt_slot[s].key == key then samt_slot[s].val = a.val end end
    end
  end
end

-- geste sec du danseur = evenement : SECOUE les diamants deja places (ceux que TU as choisis
-- sur la page PERU) pour qu'ils rebondissent et jouent. Ne CREE aucun grain.
function samt_trigger()
  -- l'agent REPOND au geste : joue un de tes motifs (si il ECOUTE le mouvement : MOVE + AUTO + motifs)
  if samt_mind_on and creature_auto and comp_on and #motifs > 0 and math.random() < 0.4 then
    clock.run(function() pcall(play_motif, motif_pick()) end)
  end
  -- et secoue les diamants deja places dans PERU
  if peru_on then
    for _, d in ipairs(peru_dia) do
      d.vy = d.vy - (1.5 + math.random() * 2.0)
      d.vx = d.vx + (math.random() * 2 - 1) * 2.0
    end
  end
end

-- valeur cible 0..1 d'une ligne selon sa source (nil = OFF, ne rien envoyer)
function cc_target(lane, i)
  local s = lane.src or 1
  if s == 1 then return nil end
  if s == 9 then                                   -- LFO autonome (vitesse propre par CC)
    lane.phase = (lane.phase or 0) + 0.012 + i * 0.0009
    return 0.5 + 0.5 * math.sin(lane.phase)
  elseif s == 10 then                              -- WALK : marche aleatoire (drunk)
    lane.walk = math.max(0, math.min(1, (lane.walk or 0.5) + (math.random() * 2 - 1) * 0.07))
    return lane.walk
  end
  local v = 0
  if     s == 2 then v = (mind and mind.energy) or 0
  elseif s == 3 then v = (mind and mind.tension) or 0
  elseif s == 4 then v = (mind and mind.arc) or 0
  elseif s == 5 then v = (mind and mind.density) or 0
  elseif s == 6 then v = (metabolik and metabolik.on and metabolik.stressFx) or 0
  elseif s == 7 then v = (wifi and wifi.energy) or 0
  elseif s == 8 then v = (style and style.density) or 0
  elseif s == 11 then v = (samt_on and samt_slot[1].val) or 0   -- capteur SAMT (OSC) ; actif si arme depuis LIVE
  elseif s == 12 then v = (samt_on and samt_slot[2].val) or 0
  elseif s == 13 then v = (samt_on and samt_slot[3].val) or 0
  elseif s == 14 then v = (samt_on and samt_slot[4].val) or 0
  elseif s == 15 then v = impro_energy or 0                            -- IMPRO : l'agent qui joue
  elseif s == 16 then v = stream_energy[2] or 0                        -- POtO : activite
  elseif s == 17 then v = stream_energy[3] or 0                        -- 8OS : activite
  elseif s == 18 then v = math.min(1, mgen_nenergy or 0)               -- MGEN : energie des notes generees
  elseif s == 19 then v = math.min(1, (rms_smooth or 0) * 8)           -- AUDIO : niveau de l'entree
  elseif s == 20 then v = peru_energy or 0                             -- PERU : PIC a chaque collision (impact)
  elseif s == 21 then v = stream_energy[7] or 0                        -- NIAKABY : activite des accords
  elseif s == 22 then v = samt_energy or 0                             -- MOVE : mouvement global du danseur
  elseif s >= 23 and s <= 30 then v = (mgen_ch[s - 22] and mgen_ch[s - 22].energy) or 0   -- MG1-8 : pistes MGEN
  -- ===== AUDIO -> CV (convertisseur type Eurorack : l'entree audio traduite en tensions) =====
  elseif s == 31 then v = math.min(1, (cur_centroid or 0) / 4000)      -- TIMB : timbre / brillance (centroide spectral)
  elseif s == 32 then                                                  -- PTCH : hauteur en 1V/oct (0..1 -> 0..10V, C1 = 0V)
    if (cur_freq or 0) > 20 then
      local semi = 12 * math.log(cur_freq / 32.703) / math.log(2)      -- demi-tons depuis C1
      semi = math.floor(semi + 0.5)                                    -- QUANTIFIE au demi-ton le plus proche -> note juste
      audio_pitch_cv = math.max(0, math.min(1, semi / 120))            -- 120 demi-tons = 10 octaves = 0..10V (1V/oct)
    end
    v = audio_pitch_cv or 0                                            -- tient la derniere hauteur pendant le silence
  elseif s == 33 then v = ((cur_rms or 0) > p_gate_thr) and 1 or 0     -- AGT : gate SNAPPY (amplitude brute, sans le hold de cur_gate)
  end
  return math.max(0, math.min(1, v))
end

wifi_new_flash = 0      -- pic de modulation a chaque nouveau reseau decouvert (decroit)

-- ===== ROUTAGE WIFI -> MIDI : les reseaux jouent des notes, le trafic un CC =====
wifi_midi_on  = false   -- sortie MIDI du WiFi active
wifi_midi_dev = 1       -- device 1..4
wifi_midi_ch  = 1       -- canal 1..16
wifi_midi_cc  = 1       -- CC pour le trafic (1 = modwheel)

-- routage PAR RESEAU : chaque SSID -> sa voix MIDI (device + canal). Le signal
-- du reseau pilote velocite/CC ; present = note tenue, absent = note off.
wifi_links    = {}      -- ssid -> { dev=1..4, ch=1..16, on=bool }
wifi_link_cur = 1       -- curseur dans la liste des reseaux scannes

-- ===== PERU : bac a grains gravitationnel =====
-- On depose des grains du corpus sous forme de diamants dans une boite. Ils tombent
-- (gravite), rebondissent sur les bords, et DECLENCHENT leur son a chaque choc.
-- E2 choisit le grain, E3 la gravite. K1 lache, K2 secoue, K3 vide (clear).
-- La physique tourne en continu tant qu'il y a des diamants (comme les autres modes).
PERU_PAGE   = 39
PERU_MAX    = 16              -- nombre max de diamants
PERU_BX0, PERU_BY0 = 3, 12    -- coin haut-gauche de la boite
PERU_BX1, PERU_BY1 = 125, 56  -- coin bas-droit
peru_dia    = {}              -- { slot, x, y, vx, vy, r, flash }
peru_on     = false           -- actif (armable depuis LIVE ; s'active en lachant un grain)
peru_sel    = 1              -- grain selectionne (slot) pour l'ajout
peru_grav   = 0.12          -- gravite (E3)
peru_bounce = 0.90          -- restitution au rebond
peru_energy = 0             -- enveloppe : PIC a chaque collision (selon la force), decroit -> source CC/OSC "PERU"
-- auto-secousse : l'INPUT (ton son) ou METABO agite les diamants, dose en % (K2)
peru_rmodes = { {src=0, amt=0}, {src=1, amt=0.5}, {src=1, amt=1.0}, {src=2, amt=0.5}, {src=2, amt=1.0}, {src=3, amt=0.5}, {src=3, amt=1.0}, {src=4, amt=0.5}, {src=4, amt=1.0} }
peru_rmode  = 1
peru_k2_down = false ; peru_k2_moved = false   -- K2 maintenu sur PERU = shift (E3 -> threshold SAMT)
PERU_RLBL   = { "OFF", "IN 50%", "IN 100%", "MB 50%", "MB 100%", "IM 50%", "IM 100%", "SM 50%", "SM 100%" }

function peru_add(slot)
  if not corpus[slot] then return end                        -- slot vide : rien
  peru_on = true                                             -- lacher un grain active PERU
  if p_poto_on then poto_set(false) end                      -- PERU partage les voix 5,6 -> exclusif avec POtO
  if os8_mode ~= "OFF" then os8_set("OFF") end               --                          -> et avec 8OS
  if #peru_dia >= PERU_MAX then table.remove(peru_dia, 1) end -- FIFO si plein
  local g = corpus[slot]
  peru_dia[#peru_dia + 1] = {
    slot = slot,
    x  = PERU_BX0 + math.random() * (PERU_BX1 - PERU_BX0),
    y  = PERU_BY0 + 3,
    vx = (math.random() * 2 - 1) * 1.5,
    vy = 0,
    r  = 2 + math.floor(math.min(1, (g.duration or 0.1) * 3) * 2),  -- taille ~ duree
    flash = 0,
  }
end

-- fait "chanter" UN diamant (coup cible) : influence musicale event-driven (METABO ou IMPRO)
function peru_kick(strength)
  if #peru_dia == 0 then return end
  local d = peru_dia[math.random(#peru_dia)]
  d.vy = d.vy - (1.0 + strength * 3.0)
  d.vx = d.vx + (math.random() * 2 - 1) * (1.0 + strength * 2.0)
end

-- PERU joue sur SES PROPRES voix (5,6), separees de l'impro/reve de l'agent (2,3),
-- pour ne pas lui voler ses voix. Anti-clic (level slew) + MIDI stream 8 + pan conserves.
PERU_V = { 5, 6 }
peru_v_idx = 0
peru_v_tok = { 0, 0 }
function peru_play(ev, pan)
  if not ev then return end
  peru_v_idx = (peru_v_idx % #PERU_V) + 1
  local vi   = peru_v_idx
  local v    = PERU_V[vi]
  peru_v_tok[vi] = peru_v_tok[vi] + 1
  local tok  = peru_v_tok[vi]
  local base = slot_pos(ev.slot)
  local len  = math.min(ev.duration or 0.15, MAX_DUR)
  local fade = math.max(0.010, math.min(0.050, len * 0.3))
  softcut.buffer(v, 1)
  softcut.level_slew_time(v, fade)
  softcut.level(v, 1.0)
  softcut.pan(v, pan or 0)
  softcut.loop(v, 0)
  softcut.loop_start(v, base) ; softcut.loop_end(v, base + len)
  softcut.position(v, base)
  softcut.fade_time(v, fade) ; softcut.rate(v, 1.0)
  softcut.play(v, 1)
  local f    = (ev.freq and ev.freq > 0) and ev.freq or cur_freq
  local note = freq_to_midi(f) or 60
  local vel  = math.max(1, math.min(127, math.floor((ev.rms or 0) * 800)))
  midi_note_on(8, note, vel)                              -- MIDI PERU (stream 8)
  clock.run(function()
    clock.sleep(math.max(0.04, len))
    midi_note_off(8, note)
    if peru_v_tok[vi] == tok then
      softcut.level(v, 0)                                 -- fondu de sortie (anti-clic)
      clock.sleep(fade + 0.005)
      if peru_v_tok[vi] == tok then softcut.play(v, 0) end
    end
  end)
end

function peru_step()
  -- INPUT et IMPRO : agitation continue (dynamique). METABO = event-driven (via note_on), pas ici.
  local m = peru_rmodes[peru_rmode]
  local drive = 0
  if     m.src == 1 then drive = math.min(1, (cur_rms or 0) * 8) * m.amt   -- INPUT : ta dynamique de jeu
  elseif m.src == 3 then drive = math.min(1, impro_energy) * m.amt         -- IMPRO : dynamique de l'impro
  elseif m.src == 4 then drive = math.min(1, samt_energy) * m.amt end       -- SM : le DANSEUR (capteur SAMT)
  local gx, gy = 0, 0
  if samt_on then for s = 1, 4 do   -- axes X/Y du capteur -> pilotent la trajectoire des diamants
    local sl = samt_slot[s]
    local dst = sl.dest or 1
    if sl.key and (dst == 2 or dst == 3) then
      local dd = (sl.val or 0.5) - 0.5
      if math.abs(dd) < samt_thr then dd = 0 end                 -- deadzone : repos = neutre
      if dst == 2 then gx = dd * 0.6 else gy = dd * 0.6 end
    end
  end end
  for _, d in ipairs(peru_dia) do
    if drive > 0 and math.random() < drive then          -- auto-secousse : coup de fouet proportionnel au signal
      d.vy = d.vy - (0.6 + math.random() * 0.9)
      d.vx = d.vx + (math.random() * 2 - 1) * 0.9
    end
    d.vy = d.vy + peru_grav + gy                        -- gravite + axe Y du capteur
    d.vx = d.vx + gx                                    -- axe X du capteur : le danseur pilote la trajectoire
    d.x  = d.x + d.vx
    d.y  = d.y + d.vy
    local hit, speed = false, 0
    if d.x < PERU_BX0 then d.x = PERU_BX0 ; d.vx = -d.vx * peru_bounce ; hit = true ; speed = math.abs(d.vx) end
    if d.x > PERU_BX1 then d.x = PERU_BX1 ; d.vx = -d.vx * peru_bounce ; hit = true ; speed = math.abs(d.vx) end
    if d.y < PERU_BY0 then d.y = PERU_BY0 ; d.vy = -d.vy * peru_bounce ; hit = true ; speed = math.max(speed, math.abs(d.vy)) end
    if d.y > PERU_BY1 then
      d.y = PERU_BY1 ; d.vy = -d.vy * peru_bounce ; hit = true ; speed = math.max(speed, math.abs(d.vy))
      if math.abs(d.vy) < 0.6 then d.vy = 0 ; d.vx = d.vx * 0.8 end   -- repos au sol (evite le mitraillage)
    end
    if hit and speed > 0.5 then
      d.flash = 3
      peru_energy = math.max(peru_energy, math.min(1, speed / 4))   -- PIC de collision (source PERU) selon la force
      local pan = math.max(-1, math.min(1, (d.x - (PERU_BX0 + PERU_BX1) / 2) / ((PERU_BX1 - PERU_BX0) / 2)))  -- pan = position horizontale du choc
      pcall(peru_play, corpus[d.slot], pan)   -- choc = joue le grain sur les voix PERU (5,6), spatialise, sans voler l'agent
    elseif d.flash > 0 then d.flash = d.flash - 1 end
  end
  -- CHAQUE diamant immobile depuis 1 s disparait (propriete du diamant, independant du capteur)
  for i = #peru_dia, 1, -1 do
    local d = peru_dia[i]
    if math.abs(d.vx) + math.abs(d.vy) > 0.35 then d.still = 0
    else d.still = (d.still or 0) + 1/30 ; if d.still > 1 then table.remove(peru_dia, i) end end
  end
end

-- ===== FACE : une "creature" a la Pwnagotchi (humeur + lieux WiFi + opinions + autonomie) =====
face_blink     = 0
creature_auto  = false   -- AUTO (K3) : la creature AGIT (reve + decide). off = affichage seul.
creature_dream = false   -- en train de rever (idle profond + auto)
face_notes = {}          -- particules "notes" qui s'envolent du visage (anim de jeu)
face_prev_act = 0        -- activite du frame precedent (detection des attaques)

-- #2 XP / NIVEAU : l'agent grandit (reseaux, lieux, motifs, jeu). Persiste.
creature_xp    = 0
creature_level = 1
creature_lvl_t = 0       -- horodatage du dernier level up (pour l'annonce)
function creature_xp_add(amt)
  creature_xp = creature_xp + (amt or 0)
  local nl = 1 + math.floor(creature_xp / 200)
  if nl > creature_level then creature_level = nl ; creature_lvl_t = util.time() end
end

-- MEMOIRE DES LIEUX : empreinte WiFi (ensemble des SSID) -> reconnait les endroits
wifi_places      = {}    -- { { list = {ssid,...}, n = vues }, ... }
wifi_place_state = "--"  -- "KNOWN" / "NEW" / "--"
wifi_place_id    = nil
wifi_unknown_n   = 0
wifi_place_back_t= 0     -- horodatage du "welcome back" (salut ponctuel a l'armement)
wifi_greet       = false -- WiFi vient d'etre (r)allume : saluer au prochain lieu reconnu
wifi_prev_on     = false
wifi_place_name  = ""    -- nom du lieu reconnu (= son reseau dominant)

function wifi_places_save()   -- fichier separe, isole : ne touche pas la sauvegarde principale
  pcall(function()
    if norns and norns.state and norns.state.data then
      tab.save(wifi_places, norns.state.data .. "wifi_places.data")
    end
  end)
end

function wifi_place_update()
  if not (wifi and wifi.on) or #wifi.nets < 2 then wifi_place_state = "--" ; return end
  local cur, curlist, nc = {}, {}, 0
  for _, nn in ipairs(wifi.nets) do
    if nn.ssid ~= "" then cur[nn.ssid] = true ; curlist[#curlist + 1] = nn.ssid ; nc = nc + 1 end
  end
  -- meilleure similarite (Jaccard) avec les lieux connus
  local best, bi = 0, nil
  for i, pl in ipairs(wifi_places) do
    local inter, seen = 0, {}
    for _, s in ipairs(pl.list) do seen[s] = true ; if cur[s] then inter = inter + 1 end end
    for s in pairs(cur) do seen[s] = true end
    local u = 0 ; for _ in pairs(seen) do u = u + 1 end
    local j = u > 0 and inter / u or 0
    if j > best then best = j ; bi = i end
  end
  if best >= 0.5 then
    wifi_place_state = "KNOWN" ; wifi_place_id = bi
    wifi_places[bi].n = (wifi_places[bi].n or 0) + 1
    wifi_place_name = wifi_places[bi].name or (wifi_places[bi].list and wifi_places[bi].list[1]) or ""
    wifi_unknown_n = 0
  else
    wifi_place_state = "NEW"
    wifi_unknown_n = wifi_unknown_n + 1
    if wifi_unknown_n >= 3 and nc >= 3 then            -- nouveau lieu confirme -> memorise
      wifi_places[#wifi_places + 1] = { list = curlist, n = 1, name = curlist[1] or "?" }
      while #wifi_places > 12 do table.remove(wifi_places, 1) end
      wifi_unknown_n = 0 ; wifi_place_id = #wifi_places ; wifi_place_name = curlist[1] or "?"
      wifi_places_save() ; creature_xp_add(20)   -- nouveau lieu decouvert
    end
  end
  -- salut ponctuel : seulement si on vient de (r)allumer le WiFi ET qu'on reconnait l'endroit
  if wifi_greet then
    if wifi_place_state == "KNOWN" then wifi_place_back_t = util.time() end
    wifi_greet = false
  end
end

-- choisit une replique dans une liste, stable ~4 s puis change (vivant sans clignoter)
function face_vary(list, salt)
  local b = math.floor((util.time() or 0) / 4)
  return list[(((salt or 0) + b) % #list) + 1]
end

function face_state()
  local m   = mind
  local sil = sil_sec or 0
  local stress = (metabolik and metabolik.on and metabolik.stressFx) or 0
  local nm  = (wifi_place_name ~= "" and wifi_place_name:sub(1, 9)) or "this spot"
  -- #2 LEVEL UP : annonce 4 s
  if creature_lvl_t > 0 and (util.time() - creature_lvl_t < 4) then
    return "(^o^)", "level " .. creature_level .. " agent!"
  end
  -- reaction AU MOUVEMENT du danseur (SAMT) : prioritaire quand il bouge
  if samt_mind_on and (samt_energy or 0) > 0.15 then      -- l'agent LIT la qualite du mouvement du danseur (MOVE)
    if     (samt_jerk or 0) > 0.35 then return "(>_<)", face_vary({"sharp!", "staccato agent", "hit me"}, 12)
    elseif (samt_build or 0) > 0.45 then return "(O_O)", face_vary({"building...", "here it comes", "rising agent"}, 13)
    else                                 return "(o_o)", face_vary({"flowing", "so smooth", "with you agent", "i feel you move"}, 14) end
  end
  -- EXPRESSIONS DE JEU : le visage exprime ce que l'agent JOUE (impro / METABO / NIAKABY), varie ; meme en reve
  do
    local ie, me, ne = impro_energy or 0, meta_energy or 0, (stream_energy and stream_energy[7]) or 0
    local top = math.max(ie, me, ne)
    if top > 0.22 then
      if creature_dream then                       -- il rejoue en revant : expressif mais reveur
        return face_vary({"(u_o)", "(o_u)", "(~_o)", "(u o)", "(^u^)", "(-_o)"}, 19),
               face_vary({"dreaming loud...", "echoes of you", "replaying...", "singing in my sleep"}, 19)
      elseif me >= ie and me >= ne then             -- METABO domine : intense, electrique
        return face_vary({"(>_<)", "(@_@)", "(>o<)", "(x_x)", "(>.<)", "(O_O)", "(*_*)"}, 20),
               face_vary({"metabolik!", "it pulses", "electric agent", "so intense", "can't stop"}, 20)
      elseif ne >= ie and ne >= me then             -- NIAKABY domine : harmonieux, chaud
        return face_vary({"(^_^)", "(^v^)", "(n_n)", "(^u^)", "(=v=)", "(^o^)", "(~_~)"}, 21),
               face_vary({"harmonizing", "chords bloom", "so warm agent", "layering", "resonating"}, 21)
      else                                          -- IMPRO domine : chante
        return face_vary({"(^o^)", "(*o*)", "(^0^)", "(o_o)", "(>o<)", "(^v^)", "(O_O)"}, 22),
               face_vary({"singing!", "riffing agent", "melody flows", "hear me go", "in the zone"}, 22)
      end
    end
  end
  -- #3 REVE (autonomie + silence profond, sans jouer)
  if creature_dream then
    return "(u_u)", face_vary({"dreaming... agent", "drifting away...", "i hear echoes", "replaying you..."}, 1)
  end
  -- #1 LIEUX + reseaux (Pwnagotchi)
  if wifi and wifi.on then
    local nowt = util.time()
    if wifi.last_new and (nowt - (wifi.last_new_t or 0) < 5) then
      return "(O_O)", "found " .. (((wifi.last_new == "") and "<hidden>") or wifi.last_new):sub(1, 11)
    end
    if wifi_place_state == "NEW" then
      return "(o_o)", face_vary({"new place agent", "never been here", "fresh ground agent", "where are we?"}, 2)
    end
    if wifi_place_state == "KNOWN" and (util.time() - (wifi_place_back_t or 0)) < 5 then
      return "(^_^)", face_vary({"welcome back " .. nm, "good to see " .. nm, "back at " .. nm .. " agent"}, 3)
    end
    if (wifi.count or 0) == 0 then return "(-_-)", "no signal agent" end
    if (wifi.traffic or 0) > 0.5 then
      return "(>_<)", face_vary({"busy traffic!", "it's buzzing here", "lots of chatter"}, 4)
    end
    return "(o_o)", face_vary({(wifi.count or 0) .. " networks", "i feel " .. (wifi.count or 0) .. " around", "scanning, agent"}, 5)
  end
  -- #4 OPINIONS sur ton jeu (chaleureux, varie)
  if strat_name == "MOTIF" then return "(^_~)", face_vary({"heard that agent", "deja vu agent", "bringing it back"}, 6) end
  if count < 4 then return "(o_o)", face_vary({"learning you agent", "i'm all ears", "show me more"}, 7) end
  if stress > 0.72 then return "(>_<)", face_vary({"getting repetitive", "loosen up agent", "shake it up"}, 8) end
  if (m.density or 0) > 0.8 and (m.arc or 0) > 0.7 then return "(@_@)", face_vary({"breathe agent!", "easy now", "so much going on"}, 9) end
  if m.energy < 0.04 then
    if sil > 6 then return "(-_-)", face_vary({"zzZ", "resting agent", "i'll wait"}, 10)
    else return face_vary({"(o_o)", "(._.)", "(o.o)", "(-_o)", "(^_^)"}, 11), face_vary({"listening agent", "go on agent", "i'm with you", "all ears agent"}, 11) end
  end
  if m.arc_phase == "PEAK" or m.build > 0.5 then return "(*o*)", face_vary({"nice agent!", "yes! keep going", "loving this", "that's it agent"}, 12) end
  if m.phrase == "GAP" then return "(o_o)", face_vary({"my turn agent", "let me agent", "here i go"}, 13) end
  if style and style.on then return "(^_^)", face_vary({"playing your way", "in your style agent", "like you taught me"}, 14) end
  return face_vary({"(^_^)", "(^-^)", "(._.)", "(o_o)", "(^v^)", "(n_n)"}, 15), face_vary({"with you agent", "at your service", "ready agent", "right here agent"}, 15)
end

function face_redraw()
  screen.clear()
  local f, quip = face_state()
  -- ACTIVITE de jeu de l'agent : impro / METABO / NIAKABY (et en reve, l'impro rejoue -> ca vit)
  local act = math.max(impro_energy or 0, meta_energy or 0, (stream_energy and stream_energy[7]) or 0)
  -- une NOTE s'envole a chaque attaque (front montant d'activite)
  if act > (face_prev_act or 0) + 0.10 and #face_notes < 16 then
    face_notes[#face_notes + 1] = { x = 64 + math.random(-20, 20), y = 34, vy = -(0.7 + act * 1.4), life = 1.0 }
  end
  face_prev_act = act
  for i = #face_notes, 1, -1 do
    local p = face_notes[i]
    p.y = p.y + p.vy ; p.life = p.life - 0.03
    if p.life <= 0 or p.y < 4 then table.remove(face_notes, i) end
  end
  -- respiration + rebond du visage selon l'activite
  local bob = math.sin((util.time() or 0) * 3.2) * (1.2 + act * 4.5)
  -- bouche : cligne, sinon s'OUVRE quand ca joue fort
  if face_blink > 0 then face_blink = face_blink - 1 ; f = f:gsub("[oO%^%*@>]", "-")
  elseif act > 0.30 then f = f:gsub("_", (act > 0.6) and "O" or "o") end
  screen.font_size(31) ; screen.level(15)
  screen.move(64, 38 + bob) ; screen.text_center(f)
  for _, p in ipairs(face_notes) do          -- les notes qui montent
    screen.level(math.max(1, math.floor(p.life * 13))) ; screen.rect(p.x, p.y, 2, 2) ; screen.fill()
  end
  screen.font_size(8)
  screen.level(9) ; screen.move(64, 52) ; screen.text_center(quip)
  -- entete : autonomie + niveau de l'agent + contexte
  screen.level(creature_auto and 12 or 3) ; screen.move(2, 8) ; screen.text(creature_auto and "AUTO" or "auto")
  screen.level(10) ; screen.move(58, 8) ; screen.text("Lv" .. creature_level)
  if wifi and wifi.on then
    screen.level(3) ; screen.move(126, 8) ; screen.text_right((wifi.count or 0) .. "r")
  else
    screen.level(3) ; screen.move(126, 8) ; screen.text_right("c:" .. count)
  end
  -- pied : K3 + lieu connu/nouveau
  screen.level(4) ; screen.move(2, 63) ; screen.text("K3 auto")
  if wifi and wifi.on and wifi_place_state ~= "--" then
    local lbl = (wifi_place_state == "KNOWN" and wifi_place_name ~= "" and wifi_place_name:sub(1, 9)) or wifi_place_state
    screen.level(6) ; screen.move(126, 63) ; screen.text_right(lbl)
  end
  screen.update()
end

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
-- METABO declenche le RANDOM de MGEN = un "new theme" (comme K2 page 13, regenere tout)
function meta_shake_mgen()
  if meta_mgen_scope == 1 then
    mgen_gen_all(true) ; meta_mgen_last = "new theme"   -- LIGHT : juste le new theme (le random page 13)
  else
    -- FULL : new theme la plupart du temps + parfois un break / un changement de gamme
    local r = math.random()
    if r < 0.72 then
      mgen_gen_all(true) ; meta_mgen_last = "new theme"
    elseif r < 0.88 then
      local bt = math.random(#MGEN_BREAK_NAMES)
      for i = 1, 16 do if mgen_ch[i].on then mgen_ch[i].brk = true ; mgen_ch[i].brk_type = bt end end
      meta_mgen_last = "break " .. MGEN_BREAK_NAMES[bt]
    else
      mgen_scale_idx = math.random(#MGEN_SCALE_NAMES) ; meta_mgen_last = "gamme " .. MGEN_SCALE_NAMES[mgen_scale_idx]
    end
  end
end

-- ===== PAGE LIVE : armer/couper les modes en un seul endroit (set live) =====
audio_midi_on = true     -- Audio->MIDI actif (si route page 16) ; armable depuis LIVE
comp_on = true           -- compagnon (impro corpus) repond ; off = ecoute mais se tait
live_cursor = 1
LIVE_NAMES  = { "POtO", "8OS", "MGEN", "SPAT", "METABO", "NIAKABY", "AUDIO", "IMPRO", "WIFI", "CC", "PERU" }
-- ===== MENU HIERARCHIQUE : la page 27 = HUB. Chaque categorie regroupe ses pages.
-- HUB : E1/E2 deplacent le curseur, K1 entre, K3 arme (si armable). Dans une
-- categorie : E1 defile ses pages puis reboucle sur le HUB. arm = index live_toggle.
NAV_CATS = {
  { n = "IMPRO",  pg = {1,2,3,4},        arm = 8  },
  { n = "POtO",   pg = {5,7,30,29},      arm = 1  },
  { n = "8OS",    pg = {6,8,28},         arm = 2  },
  { n = "MGEN",   pg = {13,14,15,25,26}, arm = 3  },
  { n = "AUDIO",  pg = {16},             arm = 7  },
  { n = "SPAT",   pg = {17},             arm = 4  },
  { n = "METABO", pg = {18,19,20,21},    arm = 5  },
  { n = "NIAKA",  pg = {22,23,24},       arm = 6  },
  { n = "PERU",   pg = {39,40},          arm = 11 },
  { n = "WIFI",   pg = {36,35},          arm = 9  },
  { n = "CC",     pg = {37,45},          arm = 10 },
  { n = "SAMT",   pg = {41,43,44},       arm = 12 },
  { n = "MIDI",   pg = {9,10,11,12},     arm = nil },
  { n = "AGENT",  pg = {33,31,32,42},    arm = nil },
}
home_cursor = 1
function nav_cat_of(p)
  for ci, c in ipairs(NAV_CATS) do
    for _, pg in ipairs(c.pg) do if pg == p then return ci, c end end
  end
  return nil
end

function live_toggle(i)
  if i == 1 then
    poto_set(not p_poto_on)
  elseif i == 2 then
    -- en LIVE : OFF <-> TRANS uniquement (joue le bank existant, ne relance PAS le REC)
    os8_set(os8_mode == "OFF" and "TRANS" or "OFF")
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
  elseif i == 9 then
    wifi.on = not wifi.on
  elseif i == 10 then
    cc_on = not cc_on
  elseif i == 11 then
    peru_on = not peru_on
    if peru_on then                                          -- armer PERU desarme POtO/8OS (voix partagees)
      if p_poto_on then poto_set(false) end
      if os8_mode ~= "OFF" then os8_set("OFF") end
    end
  elseif i == 12 then
    samt_on = not samt_on                                    -- SAMT : capteurs de mouvement OSC
  elseif i == 13 then
    osco_on = not osco_on                                    -- OSC OUT : envoi vers un module externe
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
  wifi.on = false
  cc_on = false
  peru_on = false
  samt_on = false
  osco_on = false
  for st = 1, 8 do midi_cc_all(st, 123, 0) end   -- all notes off sur tous les streams
end

-- etat ON/OFF de chaque mode (index live_toggle) : pour SAUVER puis RESTAURER les modes ouverts
function live_is_on(i)
  if     i == 1 then return p_poto_on
  elseif i == 2 then return os8_mode ~= "OFF"
  elseif i == 3 then return mgen_running
  elseif i == 4 then return spat.on
  elseif i == 5 then return metabolik.on
  elseif i == 6 then return niakaby.on
  elseif i == 7 then return audio_midi_on
  elseif i == 8 then return comp_on
  elseif i == 9 then return wifi.on
  elseif i == 10 then return cc_on
  elseif i == 11 then return peru_on
  elseif i == 12 then return samt_on
  elseif i == 13 then return osco_on end
  return false
end
live_restore = nil   -- rempli au chargement : { [i]=bool } des modes a rallumer au demarrage
function live_apply_restore()
  if type(live_restore) ~= "table" then return end
  for i = 1, 13 do
    local want = live_restore[i] and true or false
    if want ~= (live_is_on(i) and true or false) then pcall(live_toggle, i) end   -- ne toggle que si different
  end
end

-- ===== MEMOIRE GLOBALE : sauve/recharge TOUS les reglages =====
function state_save()
  pcall(function()
    if not (norns and norns.state and norns.state.data) then return end
    util.make_dir(norns.state.data)
    local mon, mmch = {}, {}
    for i = 1, 16 do mon[i] = mgen_ch[i].on ; mmch[i] = mgen_ch[i].midi_ch end
    local cc_src, cc_lon, cc_num, cc_tmd = {}, {}, {}, {}
    for i = 1, 16 do cc_src[i] = cc_lanes[i].src ; cc_lon[i] = cc_lanes[i].on ; cc_num[i] = cc_lanes[i].num ; cc_tmd[i] = cc_lanes[i].tmode end
    local samt = {}
    for s = 1, 4 do samt[s] = { key = samt_slot[s].key, dest = samt_slot[s].dest } end   -- mappings capteurs
    local snots = {}
    for s = 1, 4 do local sn = samt_notes[s]                                              -- 4 instruments SNOT
      snots[s] = { trig = sn.trig, pitch = sn.pitch, dev = sn.dev, ch = sn.ch, lo = sn.lo, hi = sn.hi, thr = sn.thr } end
    local osco = { host = osco_host, port = osco_port, armed = osco_on, src = {}, on = {}, tmode = {} } -- config OSC OUT (armed persiste)
    for i = 1, OSCO_N do osco.src[i] = osco_lanes[i].src ; osco.on[i] = osco_lanes[i].on ; osco.tmode[i] = osco_lanes[i].tmode end
    local live = {} ; for i = 1, 13 do live[i] = live_is_on(i) end   -- etat ON/OFF de TOUS les modes (a rallumer au boot)
    local st = {
      p_density=p_density, p_sil_bias=p_sil_bias, p_contrast=p_contrast, p_reply=p_reply,
      p_rec_prob=p_rec_prob, p_voice=p_voice, p_deaf=p_deaf, p_rhythm_idx=p_rhythm_idx,
      p_gate_thr=p_gate_thr, p_sil_min=p_sil_min, p_sil_max=p_sil_max, comp_on=comp_on,
      p_poto_vol=p_poto_vol, p_poto_spread=p_poto_spread, p_poto_size=p_poto_size,
      p_poto_poly=p_poto_poly, p_monitor=p_monitor, p_poto_smrt_sens=p_poto_smrt_sens, rate_pidx=rate_pidx,
      os8_vol=os8_vol, os8_size=os8_size, os8_sync=os8_sync, os8_src=os8_src, os8_pitch=os8_pitch, os8_spread=os8_spread, os8_trans=os8_trans,
      os8_mod_on=os8_mod_on, os8_mod=os8_mod, os8_mod_src=os8_mod_src,
      poto_mod_on=poto_mod_on, poto_mod=poto_mod, poto_mod_src=poto_mod_src, poto_src=poto_src,
      mind_on=mind.on, style_on=style.on, wifi_on=wifi.on, creature_auto=creature_auto,
      creature_xp=creature_xp, creature_level=creature_level,
      wifi_midi_on=wifi_midi_on, wifi_midi_dev=wifi_midi_dev, wifi_midi_ch=wifi_midi_ch, wifi_midi_cc=wifi_midi_cc, wifi_links=wifi_links,
      cc_master=cc_on, cc_dev=cc_dev, cc_ch=cc_ch, cc_src=cc_src, cc_lon=cc_lon, cc_num=cc_num, cc_tmd=cc_tmd,
      samt=samt, samt_thr=samt_thr, samt_mind_on=samt_mind_on, peru_spawn=peru_spawn, peru_grav=peru_grav, peru_rmode=peru_rmode, peru_sel=peru_sel,
      samt_notes=snots, osco=osco, perf_mode=perf_mode, live=live,
      lora_on=lora.on, lora_dev=lora.dev, lora_ch=lora.ch,
      mgen_bpm=mgen_bpm, mgen_scale_idx=mgen_scale_idx, mgen_mut_idx=mgen_mut_idx,
      mgen_evo_meta=mgen_evo_meta, mgen_freeze=mgen_freeze, mgen_recall=mgen_recall, mgen_on=mon, mgen_mch=mmch,
      midi_route=midi_route, midi_ch=midi_ch, midi_ch_audio=midi_ch_audio, audio_midi_on=audio_midi_on,
      meta_drive=meta_mgen_drive, meta_scope=meta_mgen_scope, meta_note=meta_note_inf,
      spat_mode=spat.mode, spat_mass=spat.mass, spat_tempo=spat.tempo,
      m_scale=metabolik.scale_idx, m_oct=metabolik.octave, m_dens=metabolik.density_idx,
      m_pers=metabolik.persona_idx, m_follow=metabolik.follow_amt, m_feed=metabolik.feed_idx,
      m_react=metabolik.react, m_infl=metabolik.influence_idx,
      n_scale=niakaby.scale_idx, n_oct=niakaby.octave, n_chord=niakaby.chord_idx, n_src=niakaby.src,
    }
    tab.save(st, norns.state.data .. "state.data")
  end)
end

function state_load()
  pcall(function()
    if not (norns and norns.state and norns.state.data) then return end
    local st = tab.load(norns.state.data .. "state.data")
    if type(st) ~= "table" then return end
    local function g(v, cur) if v ~= nil then return v else return cur end end
    p_density=g(st.p_density,p_density) ; p_sil_bias=g(st.p_sil_bias,p_sil_bias)
    p_contrast=g(st.p_contrast,p_contrast) ; p_reply=g(st.p_reply,p_reply)
    p_rec_prob=g(st.p_rec_prob,p_rec_prob) ; p_voice=g(st.p_voice,p_voice) ; p_deaf=g(st.p_deaf,p_deaf)
    p_gate_thr=g(st.p_gate_thr,p_gate_thr) ; p_sil_min=g(st.p_sil_min,p_sil_min) ; p_sil_max=g(st.p_sil_max,p_sil_max)
    comp_on=g(st.comp_on,comp_on)
    if st.p_rhythm_idx then p_rhythm_idx=st.p_rhythm_idx ; p_rhythm=RHYTHM_RATES[p_rhythm_idx] or p_rhythm end
    p_poto_vol=g(st.p_poto_vol,p_poto_vol) ; p_poto_spread=g(st.p_poto_spread,p_poto_spread)
    p_poto_size=g(st.p_poto_size,p_poto_size) ; p_poto_poly=g(st.p_poto_poly,p_poto_poly)
    p_monitor=g(st.p_monitor,p_monitor) ; p_poto_smrt_sens=g(st.p_poto_smrt_sens,p_poto_smrt_sens)
    if st.rate_pidx then rate_pidx=st.rate_pidx ; p_poto_rate=RATE_PRESETS[rate_pidx] or p_poto_rate end
    os8_vol=g(st.os8_vol,os8_vol) ; os8_size=g(st.os8_size,os8_size) ; os8_sync=g(st.os8_sync,os8_sync)
    os8_pitch=g(st.os8_pitch,os8_pitch) ; os8_spread=g(st.os8_spread,os8_spread) ; os8_trans=g(st.os8_trans,os8_trans)
    os8_mod_on=g(st.os8_mod_on,os8_mod_on) ; os8_mod=g(st.os8_mod,os8_mod) ; os8_mod_src=g(st.os8_mod_src,os8_mod_src)
    poto_mod_on=g(st.poto_mod_on,poto_mod_on) ; poto_mod=g(st.poto_mod,poto_mod) ; poto_mod_src=g(st.poto_mod_src,poto_mod_src)
    if type(st.poto_src)=="table" then for k,v in pairs(st.poto_src) do poto_src[k]=v end end
    if st.mind_on ~= nil then mind.on = st.mind_on end
    if st.style_on ~= nil then style.on = st.style_on end
    if st.wifi_on ~= nil then wifi.on = st.wifi_on end
    if st.lora_on ~= nil then lora.on = st.lora_on end
    if st.lora_dev then lora.dev = st.lora_dev end ; if st.lora_ch then lora.ch = st.lora_ch end
    if st.creature_auto ~= nil then creature_auto = st.creature_auto end
    creature_xp=g(st.creature_xp,creature_xp) ; creature_level=g(st.creature_level,creature_level)
    wifi_midi_on=g(st.wifi_midi_on,wifi_midi_on) ; wifi_midi_dev=g(st.wifi_midi_dev,wifi_midi_dev)
    wifi_midi_ch=g(st.wifi_midi_ch,wifi_midi_ch) ; wifi_midi_cc=g(st.wifi_midi_cc,wifi_midi_cc)
    if type(st.wifi_links)=="table" then wifi_links=st.wifi_links end
    if st.cc_master ~= nil then cc_on = st.cc_master end
    cc_dev=g(st.cc_dev,cc_dev) ; cc_ch=g(st.cc_ch,cc_ch)
    if type(st.cc_src)=="table" then for i=1,16 do if st.cc_src[i] then cc_lanes[i].src=st.cc_src[i] end end end
    local lon = (type(st.cc_lon)=="table" and st.cc_lon) or (type(st.cc_on)=="table" and st.cc_on) or nil
    if lon then for i=1,16 do cc_lanes[i].on=lon[i] and true or false end end
    if type(st.cc_num)=="table" then for i=1,16 do if st.cc_num[i] then cc_lanes[i].num=st.cc_num[i] end end end
    if type(st.cc_tmd)=="table" then for i=1,16 do cc_lanes[i].tmode=st.cc_tmd[i] or 0 end end
    if type(st.samt)=="table" then for s=1,4 do if st.samt[s] then samt_slot[s].key=st.samt[s].key ; samt_slot[s].dest=st.samt[s].dest or 1 end end end
    peru_grav=g(st.peru_grav,peru_grav) ; peru_sel=g(st.peru_sel,peru_sel) ; samt_thr=g(st.samt_thr,samt_thr)
    if st.samt_mind_on ~= nil then samt_mind_on = st.samt_mind_on end
    if type(st.samt_notes)=="table" then for s=1,4 do local d=st.samt_notes[s] ; local sn=samt_notes[s]
      if d then sn.trig=d.trig ; sn.pitch=d.pitch
        sn.dev=g(d.dev,sn.dev) ; sn.ch=g(d.ch,sn.ch)
        sn.lo=g(d.lo,sn.lo) ; sn.hi=g(d.hi,sn.hi) ; sn.thr=g(d.thr,sn.thr) end end end
    if type(st.osco)=="table" then
      if st.osco.host then osco_host = st.osco.host end ; osco_port = g(st.osco.port, osco_port)
      if type(st.osco.src)=="table" then for i=1,OSCO_N do if st.osco.src[i] then osco_lanes[i].src=st.osco.src[i] end end end
      if type(st.osco.on)=="table"  then for i=1,OSCO_N do osco_lanes[i].on = st.osco.on[i] and true or false end end
      if type(st.osco.tmode)=="table" then for i=1,OSCO_N do osco_lanes[i].tmode = st.osco.tmode[i] or 0 end
      elseif type(st.osco.trig)=="table" then for i=1,OSCO_N do osco_lanes[i].tmode = st.osco.trig[i] and 1 or 0 end end   -- migre l'ancien booleen
      if st.osco.armed ~= nil then osco_on = st.osco.armed end   -- l'armement OSC OUT est restaure au demarrage
    end
    if st.perf_mode ~= nil then perf_mode = st.perf_mode end      -- mode RECHERCHE/PERFORMANCE memorise
    if type(st.live)=="table" then live_restore = st.live end     -- modes ouverts a rallumer (applique apres le boot)
    if st.peru_spawn ~= nil then peru_spawn = st.peru_spawn end
    peru_rmode=util.clamp(g(st.peru_rmode,peru_rmode), 1, #peru_rmodes)
    if type(st.os8_src)=="table" then for _,k in ipairs(os8_src_keys) do if st.os8_src[k]~=nil then os8_src[k]=st.os8_src[k] end end end
    if st.mgen_bpm then mgen_bpm=st.mgen_bpm ; clock.tempo=mgen_bpm end
    mgen_scale_idx=g(st.mgen_scale_idx,mgen_scale_idx)
    if st.mgen_mut_idx then mgen_mut_idx=st.mgen_mut_idx ; mgen_mut_rate=MGEN_MUT_RATES[mgen_mut_idx] or mgen_mut_rate end
    mgen_evo_meta=g(st.mgen_evo_meta,mgen_evo_meta) ; mgen_recall=g(st.mgen_recall,mgen_recall)
    if st.mgen_freeze ~= nil then mgen_freeze = st.mgen_freeze end
    audio_midi_on=g(st.audio_midi_on,audio_midi_on)
    if type(st.mgen_on)=="table" then for i=1,16 do
      if st.mgen_on[i]~=nil then mgen_ch[i].on=st.mgen_on[i] end
      if st.mgen_mch and st.mgen_mch[i] then mgen_ch[i].midi_ch=st.mgen_mch[i] end
    end end
    if type(st.midi_route)=="table" then for s=1,8 do if type(st.midi_route[s])=="table" and midi_route[s] then
      for d=1,4 do if st.midi_route[s][d]~=nil then midi_route[s][d]=st.midi_route[s][d] end end end end end
    if type(st.midi_ch)=="table" then for s=1,8 do if type(st.midi_ch[s])=="table" and midi_ch[s] then
      for d=1,4 do if st.midi_ch[s][d] then midi_ch[s][d]=st.midi_ch[s][d] end end end end end
    if type(st.midi_ch_audio)=="table" then for d=1,4 do if st.midi_ch_audio[d] then midi_ch_audio[d]=st.midi_ch_audio[d] end end end
    meta_mgen_drive=g(st.meta_drive,meta_mgen_drive) ; meta_mgen_scope=g(st.meta_scope,meta_mgen_scope) ; meta_note_inf=g(st.meta_note,meta_note_inf)
    spat.mode=g(st.spat_mode,spat.mode) ; spat.mass=g(st.spat_mass,spat.mass) ; spat.tempo=g(st.spat_tempo,spat.tempo)
    metabolik.scale_idx=g(st.m_scale,metabolik.scale_idx) ; metabolik.octave=g(st.m_oct,metabolik.octave)
    metabolik.density_idx=g(st.m_dens,metabolik.density_idx) ; metabolik.persona_idx=g(st.m_pers,metabolik.persona_idx)
    metabolik.follow_amt=g(st.m_follow,metabolik.follow_amt) ; metabolik.feed_idx=g(st.m_feed,metabolik.feed_idx)
    metabolik.react=g(st.m_react,metabolik.react) ; metabolik.influence_idx=g(st.m_infl,metabolik.influence_idx)
    niakaby.scale_idx=g(st.n_scale,niakaby.scale_idx) ; niakaby.octave=g(st.n_oct,niakaby.octave)
    niakaby.chord_idx=g(st.n_chord,niakaby.chord_idx)
    if type(st.n_src)=="table" and niakaby.src then for k,v in pairs(st.n_src) do niakaby.src[k]=v end end
  end)
end

function init()
  math.randomseed(os.time())
  mgen_taste_load()        -- recharge les gouts MGEN appris (memoire persistante)
  pcall(function() local t = tab.load(norns.state.data .. "wifi_places.data") ; if type(t) == "table" then wifi_places = t end end)  -- lieux WiFi memorises
  pcall(function() local t = tab.load(norns.state.data .. "lora_senders.data") ; if type(t) == "table" then lora.senders = t end end)  -- signatures d'expediteurs LoRa
  for i = 1, 16 do cc_lanes[i] = { src = 1, on = false, val = 0, phase = i * 0.4, walk = 0.5, num = i, tmode = 0 } end  -- 16 CC (num, tmode 0=CC 1=TRIG 2=GATE)
  for i = 1, OSCO_N do osco_lanes[i] = { src = 1, on = false, val = 0, phase = i * 0.5, walk = 0.5, tmode = 0 } end  -- 8 sorties OSC /cv/N (tmode 0=CV 1=TRIG 2=GATE)
  mgen_gen_all()
  state_load()             -- recharge TOUS les reglages sauvegardes
  pcall(function() audio.level_monitor(p_monitor) end)
  clock.run(function() while true do clock.sleep(30) ; state_save() end end)  -- sauvegarde periodique
  last_sound_t = util.time()
  -- LORA : reception des messages depuis le pont OSC externe (port OSC du norns : 10111)
  osc.event = function(path, args)
    if path == "/lora/rx" then
      lora_rx(args[1], tonumber(args[2]), tonumber(args[3]), tonumber(args[4]), args[5])
    elseif path == "/lora/tx" then
      lora_tx(args[1], tonumber(args[2]))
    else
      samt_rx(path, args)   -- SAMT : capteurs de mouvement (tout autre OSC numerique)
    end
  end
  splash_active = true
  boot_choose   = true   -- apres le splash : ecran de choix RECHERCHE / PERFORMANCE
  clock.run(function()
    clock.sleep(3.0) ; splash_active = false      -- fin du splash
    redraw()                                      -- AFFICHE l'ecran de choix (il attend K2/K3)
  end)
  -- RESTAURE les modes qui etaient ouverts : apres le choix du mode ET que le moteur SC/softcut soit pret
  clock.run(function()
    while boot_choose do clock.sleep(0.2) end
    clock.sleep(1.2)
    pcall(live_apply_restore)
    if perf_mode then page = 33 ; redraw() end   -- perf : revient sur AGENT une fois les modes lances
  end)
  clock.run(audio_midi_loop)
  -- MODE PERFORMANCE : suit l'action tout seul (agent par defaut ; nouveau son -> corpus ; diamants -> PERU)
  clock.run(function()
    while true do
      clock.sleep(0.1)
      if perf_mode and not boot_choose and not splash_active then
        local now = util.time()
        local diamonds = peru_on and #peru_dia > 0
        if count > perf_last_count then perf_last_count = count ; perf_corpus_t = now ; perf_last_input = 0 end   -- nouveau son capte
        if diamonds and not perf_had_diamonds then perf_last_input = 0 end   -- des diamants viennent d'apparaitre
        perf_had_diamonds = diamonds
        local target
        if now - (perf_corpus_t or 0) < 2.0 then target = 1          -- CORPUS : un son vient d'etre capte
        elseif diamonds then target = 39                             -- PERU : des diamants sont vivants
        else target = 33 end                                         -- AGENT : au repos
        if page ~= target and (now - (perf_last_input or 0)) > 3.0 then page = target ; redraw() end
      end
    end
  end)
  for d = 1, 4 do
    local ok, md = pcall(midi.connect, d)
    if ok then
      midi_outs[d] = md
      md.event = function(data) midi_clock_in(data, d) end   -- ecoute les pulses + retient le port source
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

  -- WIFI : scan non bloquant + trafic, toutes les 4 s (seulement si active)
  clock.run(function()
    while true do
      clock.sleep(4)
      if wifi.on and not wifi_prev_on then wifi_greet = true end   -- WiFi (r)allume -> saluer une fois
      wifi_prev_on = wifi.on
      if wifi.on then
        pcall(wifi.poll, util.time()) ; pcall(wifi_place_update) ; creature_xp_add((wifi.newcount or 0) * 2)
        if (wifi.newcount or 0) > 0 then wifi_new_flash = 1 end   -- nouveau reseau -> pic de modulation
      end
    end
  end)

  -- CREATURE : autonomie (reve quand idle + decisions quand monotone). Opt-in (AUTO).
  clock.run(function()
    while true do
      clock.sleep(2.5)
      local idle = (sil_sec or 0) > 8 and (mind.energy or 0) < 0.04
      creature_dream = creature_auto and idle and (#motifs > 0) and comp_on   -- reve = silencieux si IMPRO coupe
      if (mind.energy or 0) > 0.1 then creature_xp_add(1) end   -- jouer fait grandir l'agent
      if samt_mind_on and (samt_energy or 0) > 0.1 then creature_xp_add(1) end   -- le danseur fait grandir l'agent (si MOVE)
      if creature_auto then
        if idle then
          -- #3 REVE : rejoue un de tes motifs, transforme, tout seul (respecte le mute IMPRO)
          if comp_on and #motifs > 0 and math.random() < 0.35 then
            clock.run(function() local ok = pcall(play_motif, motif_pick()) end)
          end
        elseif metabolik.on and (metabolik.stressFx or 0) > 0.72 and mgen_running and not mgen_freeze then
          -- #5 DECIDE : la monotonie l'ennuie -> il change le theme MGEN (sauf si FREEZE)
          if math.random() < 0.2 then mgen_gen_all(true) end
        end
      else
        creature_dream = false
      end
    end
  end)

  -- CC GEN : 16 CC pilotes chacun par leur source, lisses, envoyes si la valeur change
  clock.run(function()
    local last = {}
    while true do
      clock.sleep(0.04)                              -- ~25 Hz
      local out = cc_on and midi_outs[cc_dev] or nil  -- arme depuis LIVE (mais on calcule tjrs -> page vivante)
      for i = 1, 16 do
        local lane = cc_lanes[i]
        if lane and lane.on then
          local tgt = cc_target(lane, i)
          local tm  = lane.tmode or 0
          local v
          if tm == 2 then                                        -- GATE : 127 tant que la source depasse le seuil
            lane.val = ((tgt or 0) > 0.25) and 1 or 0 ; v = lane.val * 127
          elseif tm == 1 then                                    -- TRIGGER : pic de CC sur front montant OU nouvelle attaque (tout BPM)
            local src = tgt or 0
            local hi  = src > 0.25
            if (hi and not lane.armed_hi) or (src - (lane.psrc or 0)) > 0.08 then lane.pulse = 2 end
            lane.armed_hi = hi ; lane.psrc = src
            if (lane.pulse or 0) > 0 then lane.val = 1 ; lane.pulse = lane.pulse - 1 else lane.val = 0 end
            v = lane.val * 127
          elseif tgt then                                        -- CC continu lisse
            lane.val = (lane.val or 0) + (tgt - (lane.val or 0)) * 0.2 ; v = math.floor(lane.val * 127 + 0.5)
          end
          if out and v and v ~= last[i] then out:cc(lane.num or i, v, cc_ch) ; last[i] = v end
        end
      end
    end
  end)

  -- OSC OUT : 8 sorties pilotees par leur source -> envoi OSC /cv/1..8 vers un module externe (ex. HAT CV/Gate)
  clock.run(function()
    local last = {}
    local tick = 0
    while true do
      clock.sleep(0.01)                                 -- 100 Hz : TRIG/GATE reactifs (le poll audio tourne a 60 Hz)
      tick = tick + 1
      local cv_tick = (tick % 4 == 0)                   -- CV : ~25 Hz -> trafic OSC inchange
      local dest = osco_on and { osco_host, osco_port } or nil
      for i = 1, OSCO_N do
        local lane = osco_lanes[i]
        if lane then
          local tm = lane.tmode or 0
          if tm == 1 then                               -- TRIGGER (100 Hz) : /trig/N -> le Pi fait l'impulsion 5 ms
            local src  = cc_target(lane, i) or 0
            local hi   = src > 0.25
            local fire = (hi and not lane.armed_hi) or (src - (lane.psrc or 0)) > 0.08   -- seuil OU re-attaque (tout BPM)
            lane.armed_hi = hi ; lane.psrc = src
            lane.val = fire and 1 or (lane.val or 0) * 0.85       -- affichage : flash a chaque trig
            if dest and lane.on and fire then pcall(osc.send, dest, "/trig/" .. (i - 1), { 1.0 }) end
          elseif tm == 2 then                           -- GATE (100 Hz) : /gate/N sur les FRONTS -> le Pi tient la tension
            local hi = (cc_target(lane, i) or 0) > 0.25
            lane.val = hi and 1 or 0
            if hi ~= lane.ghi then                       -- n'envoie qu'aux changements d'etat
              lane.ghi = hi
              if dest and lane.on then pcall(osc.send, dest, "/gate/" .. (i - 1), { hi and 1.0 or 0.0 }) end
            end
          elseif cv_tick then                           -- CV continu (~25 Hz) : /cv/N
            local tgt = cc_target(lane, i)
            if tgt then
              local sid = lane.src or 1
              if sid == 32 or sid == 33 then lane.val = tgt            -- PTCH / AGT : AUCUN lissage (saut net, pas de glide)
              else lane.val = (lane.val or 0) + (tgt - (lane.val or 0)) * 0.2 end   -- les autres : lissage
            else
              lane.val = (lane.val or 0) * 0.9          -- source OFF : retombe a 0
            end
            if dest and lane.on then
              local v = math.floor(lane.val * 4095 + 0.5) / 4095       -- precision 12 bits = resolution exacte du DAC
              if v ~= last[i] then pcall(osc.send, dest, "/cv/" .. (i - 1), { v }) ; last[i] = v end
            end
          end
        end
      end
    end
  end)

  -- SAMT : energie de mouvement du danseur (decroit) + detection de TRIGGER (pic de geste)
  clock.run(function()
    while true do
      clock.sleep(1/30)
      samt_energy = samt_energy * 0.88
      local mm = 0
      if samt_move > samt_thr then   -- deadzone : ignore le bruit du capteur au repos
        mm = math.min(1, (samt_move - samt_thr) * 14)
        if mm > samt_energy then samt_energy = mm end
        if samt_on and mm > 0.45 and (util.time() - samt_trig_t) > 0.15 then   -- geste sec = trigger
          samt_trig_t = util.time() ; pcall(samt_trigger)
        end
      end
      samt_move = 0
      -- ANALYSE : arc long, brusquerie, immobilite
      samt_build = samt_build + (samt_energy - samt_build) * 0.03
      samt_jerk  = samt_jerk + (math.abs(mm - samt_pmm) - samt_jerk) * 0.25 ; samt_pmm = mm
      if samt_energy > 0.12 then samt_still = 0 else samt_still = math.min(20, samt_still + 1/30) end
      -- MOVE : un CHANGEMENT d'energie (le danseur accelere/bouge d'un coup) fait APPARAITRE un grain
      if peru_spawn and samt_mind_on and peru_on and #peru_dia < PERU_MAX
         and (samt_energy - samt_penergy) > 0.15 and (util.time() - peru_spawn_t) > 0.12 then
        peru_spawn_t = util.time()
        local has_rot = false
        for s = 1, 4 do if samt_slot[s].key and (samt_slot[s].dest or 1) == 4 then has_rot = true ; break end end
        if not has_rot then   -- pas d'axe ROT -> cycle tout seul vers le prochain grain rempli (varie sans toi)
          for _ = 1, CORPUS_SLOTS do peru_sel = (peru_sel % CORPUS_SLOTS) + 1 ; if corpus[peru_sel] then break end end
        end
        peru_add(peru_sel)   -- avec ROT : le grain choisi par la rotation du danseur ; sinon : cycle auto
      end
      samt_penergy = samt_energy
      -- ROT : la rotation du danseur change le grain selectionne (jog suivant / precedent)
      if samt_on then for s = 1, 4 do
        local sl = samt_slot[s]
        if sl.key and (sl.dest or 1) == 4 then
          local rd = (sl.val or 0.5) - 0.5
          if math.abs(rd) > samt_thr then
            sl.rot_acc = (sl.rot_acc or 0) + rd
            while sl.rot_acc >  6.0 do peru_sel = (peru_sel % CORPUS_SLOTS) + 1        ; sl.rot_acc = sl.rot_acc - 6.0 end  -- grain suivant
            while sl.rot_acc < -6.0 do peru_sel = ((peru_sel - 2) % CORPUS_SLOTS) + 1  ; sl.rot_acc = sl.rot_acc + 6.0 end  -- grain precedent
          else sl.rot_acc = 0 end
        end
      end end
      -- SNOT x4 : pour chaque instrument, geste sur son axe TRIG -> note MIDI ; hauteur depuis son axe PITCH
      for ni = 1, 4 do
        local sn = samt_notes[ni]
        if sn.on and sn.trig and samt_mon[sn.trig] then
          local ta = samt_mon[sn.trig]
          local dv = math.abs((ta.val or 0) - (sn.pv or 0)) ; sn.pv = ta.val or 0
          local now = util.time()
          if dv > sn.thr and (now - (sn.last_t or 0)) > 0.12 then
            sn.last_t = now
            local pv = 0.5
            if sn.pitch and samt_mon[sn.pitch] then pv = samt_mon[sn.pitch].val or 0.5 end
            local lo, hi = sn.lo, sn.hi ; if hi < lo then lo, hi = hi, lo end
            local note = math.floor(lo + pv * (hi - lo) + 0.5)
            local vel  = math.floor(util.clamp(dv * 260, 64, 127))   -- velocite : plancher 64
            local out  = midi_outs[sn.dev]
            if out then
              if sn.playing then out:note_off(sn.playing, 0, sn.ch) end
              out:note_on(note, vel, sn.ch)
              sn.playing = note ; sn.play_t = now
            end
          end
          if sn.playing and (util.time() - (sn.play_t or 0)) > 0.30 then   -- gate court
            local out = midi_outs[sn.dev]
            if out then out:note_off(sn.playing, 0, sn.ch) end
            sn.playing = nil
          end
        end
      end
    end
  end)

  -- PERU : boucle physique (~30 Hz). Redessine la page si elle est affichee (anim fluide).
  clock.run(function()
    while true do
      clock.sleep(1/30)
      -- WATCHDOG horloge externe : si le flux de pulses s'arrete (sans Stop) -> on coupe l'horloge
      -- externe et on libere le verrou de port, pour ne pas figer les sequenceurs ni rester bloque.
      if mclk_active and (util.time() - mclk_last_t) > 0.5 then mclk_active = false ; mclk_src = 0 end
      impro_energy = impro_energy * 0.90                  -- decroissance de l'enveloppe impro
      for s = 1, 8 do stream_energy[s] = (stream_energy[s] or 0) * 0.90 end   -- decroissance activite par mode
      peru_energy = (peru_energy or 0) * 0.85                                 -- pic de collision PERU : retombe vite
      if peru_on and #peru_dia > 0 then peru_step() end
      if page == PERU_PAGE or page == 33 then redraw() end   -- PERU anime + AGENT (visage vivant)
    end
  end)

  -- WIFI -> MIDI : arpege des reseaux (canal->hauteur, signal->velocite) + accent
  -- sur nouveau reseau + CC continu du trafic. Sort sur device/canal choisis.
  clock.run(function()
    local idx, prevnew, lastnote = 0, 0, nil
    while true do
      clock.sync(1/2)                               -- 1/8 note : suit clock.tempo (externe ou interne), natif sans busy-wait
      local out = midi_outs[wifi_midi_dev]
      if wifi.on and wifi_midi_on and out and #wifi.nets > 0 then
        if lastnote then out:note_off(lastnote, 0, wifi_midi_ch) ; lastnote = nil end
        if (wifi.last_new_t or 0) > prevnew then    -- accent : nouveau reseau apparu
          prevnew = wifi.last_new_t
          out:note_on(84, 110, wifi_midi_ch)
          clock.run(function() clock.sleep(0.12) ; out:note_off(84, 0, wifi_midi_ch) end)
        end
        idx = (idx % #wifi.nets) + 1                 -- arpege un reseau a la fois
        local n    = wifi.nets[idx]
        local note = wifi.note_for(n)
        local vel  = math.max(1, math.min(127, math.floor((n.sig or 50) * 1.27)))
        out:note_on(note, vel, wifi_midi_ch)
        lastnote = note
      elseif lastnote and out then
        out:note_off(lastnote, 0, wifi_midi_ch) ; lastnote = nil
      end
    end
  end)

  -- WIFI LINK : chaque reseau LIE joue son PROPRE RYTHME EUCLIDIEN (16 pas) :
  -- signal -> densite (2..8 frappes), canal -> decalage. Polyrythme du paysage WiFi.
  clock.run(function()
    local step, playing = 0, {}
    local function euclid(k, n, i)                  -- la frappe i (1..n) est-elle active ?
      if k <= 0 then return false end
      if k >= n then return true end
      return math.floor(i * k / n) ~= math.floor((i - 1) * k / n)
    end
    while true do
      clock.sync(1/4)                               -- 1/16 note : suit clock.tempo (externe ou interne), natif sans busy-wait
      step = (step + 1) % 16
      for _, p in ipairs(playing) do
        local out = midi_outs[p.dev] ; if out then out:note_off(p.note, 0, p.ch) end
      end
      playing = {}
      if wifi.on then
        local present = {}
        for _, n in ipairs(wifi.nets) do present[n.ssid] = n end
        for ssid, link in pairs(wifi_links) do
          local n = present[ssid]
          if link.on and n then
            local k   = 2 + math.floor((n.sig or 50) / 100 * 6)        -- signal -> 2..8 frappes/16
            local off = (n.chan or 0) % 16                              -- canal -> decalage du motif
            if euclid(k, 16, (step + off) % 16 + 1) then
              local out = midi_outs[link.dev]
              if out then
                local note = wifi.note_for(n)
                local vel  = math.max(1, math.min(127, math.floor((n.sig or 50) * 1.27)))
                out:note_on(note, vel, link.ch)
                playing[#playing + 1] = { note = note, dev = link.dev, ch = link.ch }
              end
            end
          end
        end
      end
    end
  end)

  -- AVATAR METABOLIK (mode METABO) : voix routee par la MATRICE (stream 6) + maj ~30 Hz
  metabolik.note_on  = function(note, vel)
    midi_note_on(6, note, vel)
    meta_freq = 440 * 2 ^ ((note - 69) / 12)        -- capture pour NIAKABY (source METABO)
    if vel / 127 > meta_energy then meta_energy = vel / 127 end
    if peru_on and #peru_dia > 0 then               -- PERU : chaque note de METABO fait chanter un diamant (musical)
      local m = peru_rmodes[peru_rmode]
      if m.src == 2 and m.amt > 0 then peru_kick((vel / 127) * m.amt) end
    end
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
      if meta_mgen_drive > 0 and mgen_running and not mgen_freeze then
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
      for i = 1, 8 do mgen_ch[i].energy = (mgen_ch[i].energy or 0) * 0.88 end   -- decay activite par piste MG1-8
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
      os8_route()                                      -- met a jour la voix live du routeur 8OS TRANS
      poto_route() ; poto_rec_route()                  -- source POtO : suivi de hauteur + routage d'enregistrement
      poto_live_update()                               -- POtO : rate/spread appliques mid-grain (immediat)
      mind.update(rms_smooth, cur_freq, cur_centroid, cur_flatness, cur_gate, 1/30, util.time())  -- ecoute partagee (observation)
      metabolik.ext_press = math.max((mind.on and mind.drive) or 0, (wifi.on and wifi.energy) or 0, (lora.on and lora.energy) or 0, (samt_mind_on and samt_energy) or 0)  -- coherence : geste/arc, WiFi, LoRa ET le DANSEUR (MOVE) agitent METABO -> tout le cerveau de l'agent
      wifi_new_flash = (wifi_new_flash or 0) * 0.93   -- decroissance du pic de decouverte (~1 s)
      lora.tick(1/30)                                  -- decroissance de l'energie radio LoRa
      if math.random() < 0.008 then face_blink = 4 end      -- la creature cligne des yeux de temps en temps
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
      elseif fi == 4 then    -- WIFI : l'activite des reseaux nourrit la cellule
        metabolik.update(wifi.energy or 0, wifi.freq(), 3000, 0.1, 1/30)
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
  state_save()             -- sauve tous les reglages
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
-- ordre d'affichage des pages (les IDs logiques ne changent pas) :
-- regroupe par mode : POtO (granular/grain/SRC/MOD), puis 8OS (looper/SRC/MOD),
-- puis MIDI, MGEN, audio, SPAT, METABO, NIAKABY, META>MGEN, TASTE, LIVE, MIND.
-- (les IDs logiques ne changent pas : seul l'ordre d'affichage est regroupe)
PAGE_ORDER = {1,2,3,4, 5,7,30,29, 6,8,28, 9,10,11,12, 13,14,15,25,26, 16,17, 18,19,20,21, 22,23,24, 27, 39,40, 36,35,37,41,43,44,45, 33,31,32,42}
function page_pos(p)
  for i, q in ipairs(PAGE_ORDER) do if q == p then return i end end
  return 1
end

function enc(n, d)
  if boot_choose then return end                                  -- ecran de choix : ignore les encodeurs
  if perf_mode then perf_last_input = util.time() end             -- input manuel = grace anti-yank
  if n == 1 then
    if page == 27 then
      home_cursor = ((home_cursor - 1 + d) % #NAV_CATS) + 1        -- HUB : deplace le curseur
    else
      local _, c = nav_cat_of(page)
      if not c then page = 27 else
        local i = 1
        for k, pg in ipairs(c.pg) do if pg == page then i = k end end
        i = i + d
        if i < 1 or i > #c.pg then page = 27 else page = c.pg[i] end  -- au bout de la zone : retour au HUB
      end
    end
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
    elseif page == 8 then
      os8_src_cursor = util.clamp(os8_src_cursor + d, 1, #os8_src_keys + 1)   -- 4 sources + PITCH
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
    elseif page == 27 then
      home_cursor = ((home_cursor - 1 + d) % #NAV_CATS) + 1
    elseif page == 26 then
      mgen_browse = util.clamp(mgen_browse + d, 0, #mgen_liked)
      if mgen_browse >= 1 and mgen_liked[mgen_browse] then mgen_load_combo(mgen_liked[mgen_browse]) end
    elseif page == 28 then
      os8_mod = util.clamp(os8_mod + d * 0.05, 0, 1)
    elseif page == 29 then
      poto_mod = util.clamp(poto_mod + d * 0.05, 0, 1)
    elseif page == 30 then
      poto_src_cursor = ((poto_src_cursor - 1 + d) % #poto_src_keys) + 1
    elseif page == 35 then
      wifi_midi_dev = util.clamp(wifi_midi_dev + d, 1, 4)
    elseif page == 36 then
      wifi_link_cur = util.clamp(wifi_link_cur + d, 1, math.max(1, #wifi.nets))
    elseif page == 37 then
      cc_cursor = util.clamp(cc_cursor + d, 0, 16)
    elseif page == PERU_PAGE then
      peru_sel = util.clamp(peru_sel + d, 1, CORPUS_SLOTS)   -- choisit le grain a lacher
    elseif page == 40 then
      peru_cur_dev = util.clamp(peru_cur_dev + d, 1, 4)      -- PERU MIDI : device
    elseif page == 41 then
      samt_cur = util.clamp(samt_cur + d, 1, 4)              -- SAMT : slot MO selectionne
    elseif page == 43 then
      samt_mon_off = math.max(0, samt_mon_off + d)          -- MONITOR : defiler la liste des axes
    elseif page == 44 then
      samt_note_fld = util.clamp(samt_note_fld + d, 1, 8)   -- SNOT : champ selectionne (1=SNOT# ...)
    elseif page == 45 then
      osco_cursor = util.clamp(osco_cursor + d, 0, OSCO_N)  -- OSC OUT : 0=dest, 1..8=sorties
    end
  elseif n == 3 then
    if page == 27 then                                        -- HUB : E3 vers la droite = entrer dans la categorie
      if d > 0 then local c = NAV_CATS[home_cursor] ; if c then page = c.pg[1] end end
    end
    if page == 28 then os8_mod_src = util.clamp(os8_mod_src + d, 1, #MOD_SRC_NAMES) end
    if page == 29 then poto_mod_src = util.clamp(poto_mod_src + d, 1, #MOD_SRC_NAMES) end
    if page == 35 then wifi_midi_ch = util.clamp(wifi_midi_ch + d, 1, 16) end
    if page == 37 then
      if cc_k1_down and cc_cursor >= 1 then
        local lane = cc_lanes[cc_cursor]
        lane.tmode = util.clamp((lane.tmode or 0) + d, 0, 2) ; cc_k1_moved = true   -- K1+E3 : CC/TRIG/GATE
      elseif cc_cursor == 0 then
        cc_ch = util.clamp(cc_ch + d, 1, 16)
      else
        local lane = cc_lanes[cc_cursor]
        lane.num = util.clamp((lane.num or cc_cursor) + d, 0, 127)   -- numero CC vise (0..127)
      end
    end
    if page == 36 then
      local net = wifi.nets[wifi_link_cur]
      if net then
        local L = wifi_links[net.ssid] or { dev = 1, ch = 1, on = false }
        L.ch = util.clamp(L.ch + d, 1, 16) ; wifi_links[net.ssid] = L
      end
    end
    if page == 25 then meta_note_inf = util.clamp(meta_note_inf + d * 0.05, 0, 1) end
    if page == 26 then mgen_recall = util.clamp(mgen_recall + d * 0.05, 0, 1) end
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
    elseif page == 8 then
      if os8_src_cursor > #os8_src_keys then
        os8_trans = util.clamp(os8_trans + d, -24, 24)   -- curseur sur PITCH : E3 = transpo
      else
        os8_spread = util.clamp(os8_spread + d * 0.05, 0.0, 1.0)
      end
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
    elseif page == PERU_PAGE then
      if peru_k2_down then samt_thr = util.clamp(samt_thr + d * 0.01, 0, 0.4) ; peru_k2_moved = true   -- K2 maintenu : threshold SAMT
      else peru_grav = util.clamp(peru_grav + d * 0.01, 0.0, 0.5) end                                  -- sinon : gravite
    elseif page == 40 then
      midi_ch[8][peru_cur_dev] = util.clamp(midi_ch[8][peru_cur_dev] + d, 1, 16)   -- PERU MIDI : canal
    elseif page == 41 then
      samt_thr = util.clamp(samt_thr + d * 0.01, 0, 0.4)   -- SAMT : threshold / deadzone (anti-bruit)
    elseif page == 44 then                                 -- SNOT : regle le champ du SNOT selectionne
      local c = samt_note_fld ; local sn = samt_notes[samt_note_cur]
      if     c == 1 then samt_note_cur = util.clamp(samt_note_cur + d, 1, 4)   -- choisit le SNOT (1..4)
      elseif c == 4 then sn.dev = util.clamp(sn.dev + d, 1, 4)
      elseif c == 5 then sn.ch  = util.clamp(sn.ch  + d, 1, 16)
      elseif c == 6 then sn.lo  = util.clamp(sn.lo  + d, 0, 127)
      elseif c == 7 then sn.hi  = util.clamp(sn.hi  + d, 0, 127)
      elseif c == 8 then sn.thr = util.clamp(sn.thr + d * 0.01, 0.02, 0.6) end
    elseif page == 45 then
      if osco_cursor == 0 then osco_port = util.clamp(osco_port + d, 1, 65535)       -- OSC OUT dest : port
      else local L = osco_lanes[osco_cursor] ; L.tmode = util.clamp((L.tmode or 0) + d, 0, 2) end  -- sortie : E3 = CV/TRIG/GATE
    end
  end
  redraw()
end

function key(n, z)
  if boot_choose then                       -- ECRAN DE CHOIX : K2 = Recherche, K3 = Performance
    if z == 1 then
      if n == 2 then perf_mode = false ; boot_choose = false ; page = 27           -- RECHERCHE : menu, nav libre
      elseif n == 3 then perf_mode = true ; boot_choose = false ; page = 33         -- PERFORMANCE : demarre sur AGENT
        perf_last_count = count ; perf_had_diamonds = false ; perf_last_input = 0 end
    end
    redraw() ; return
  end
  if perf_mode and z == 1 then perf_last_input = util.time() end   -- toute touche = input manuel (grace anti-yank)
  if page == PERU_PAGE and n == 2 then      -- K2 : tap = react ; maintenu + E3 = threshold SAMT
    if z == 1 then peru_k2_down = true ; peru_k2_moved = false
    else peru_k2_down = false ; if not peru_k2_moved then peru_rmode = (peru_rmode % #peru_rmodes) + 1 end end
    redraw() ; return
  end
  if page == 37 and n == 1 then             -- CC : K1 tap = learn ; maintenu + E3 = mode CC/TRIG/GATE
    if z == 1 then cc_k1_down = true ; cc_k1_moved = false
    else cc_k1_down = false ; if not cc_k1_moved and cc_cursor >= 1 then cc_learn = not cc_learn end end
    redraw() ; return
  end
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
  if page == 28 then
    if n == 3 then os8_mod_on = not os8_mod_on end
    redraw() ; return
  end
  if page == 29 then
    if n == 3 then poto_mod_on = not poto_mod_on end
    redraw() ; return
  end
  if page == 30 then
    if n == 3 then
      local k = poto_src_keys[poto_src_cursor] ; poto_src[k] = not poto_src[k]
    elseif n == 2 then
      local all = poto_src.input and poto_src.metabo and poto_src.comp and poto_src.mgen
      for _, k in ipairs(poto_src_keys) do poto_src[k] = not all end
    end
    poto_rec_route()
    redraw() ; return
  end
  if page == 31 then
    if n == 3 then mind.on = not mind.on end
    redraw() ; return
  end
  if page == 32 then
    if n == 3 then style.on = not style.on end
    redraw() ; return
  end
  if page == 33 then
    if n == 3 then creature_auto = not creature_auto end   -- la creature AGIT (reve + decide)
    redraw() ; return
  end
  if page == 35 then
    if n == 3 then wifi_midi_on = not wifi_midi_on end
    redraw() ; return
  end
  if page == 36 then
    local net = wifi.nets[wifi_link_cur]
    if net then
      local L = wifi_links[net.ssid] or { dev = 1, ch = 1, on = false }
      if n == 2 then L.dev = (L.dev % 4) + 1
      elseif n == 3 then L.on = not L.on end
      wifi_links[net.ssid] = L
    end
    redraw() ; return
  end
  if page == 37 then
    if n == 1 then
      cc_learn = (not cc_learn) and cc_cursor >= 1                 -- arme l'apprentissage (lane seulement)
    elseif n == 2 then
      if cc_cursor == 0 then
        cc_dev = (cc_dev % 4) + 1                                  -- OUT : device global
      else
        local lane = cc_lanes[cc_cursor]
        lane.src = (lane.src % #CC_SRC) + 1                        -- lane : cycle la source
      end
    elseif n == 3 then
      if cc_cursor == 0 then
        local anyon = false ; for i = 1, 16 do if cc_lanes[i].on then anyon = true end end
        for i = 1, 16 do
          cc_lanes[i].on = not anyon
          if cc_lanes[i].on and (cc_lanes[i].src or 1) == 1 then cc_lanes[i].src = 9 end  -- defaut LFO
        end
        cc_on = not anyon            -- allumer toutes les lanes arme aussi le master
      else
        local lane = cc_lanes[cc_cursor]
        lane.on = not lane.on
        if lane.on and (lane.src or 1) == 1 then lane.src = 9 end                          -- defaut LFO
        if lane.on then cc_on = true end                                                   -- arme le master
      end
    end
    redraw() ; return
  end
  if page == PERU_PAGE then
    if n == 1 then peru_add(peru_sel)      -- lache le grain selectionne (K2 = react/threshold, gere plus haut)
    elseif n == 3 then peru_dia = {} ; peru_on = false end   -- vide la boite (clear + stop)
    redraw() ; return
  end
  if page == 27 then
    local c = NAV_CATS[home_cursor]
    if n == 3 then
      if c and c.arm then live_toggle(c.arm) end            -- K3 = armer / couper (si armable)
    elseif n == 2 then mgen_freeze = not mgen_freeze end     -- K2 = FREEZE des patterns MGEN ; K1 libre (entree = E3)
    redraw() ; return
  end
  if page == 26 then
    if n == 3 then mgen_taste(true)
    elseif n == 2 then mgen_taste(false) end
    redraw() ; return
  end
  if page == 19 then
    if n == 3 then midi_route[6][metabo_cur_dev] = not midi_route[6][metabo_cur_dev] end
    redraw() ; return
  end
  if page == 40 then
    if n == 3 then midi_route[8][peru_cur_dev] = not midi_route[8][peru_cur_dev] end
    redraw() ; return
  end
  if page == 41 then
    if n == 3 then samt_learn = (samt_learn == samt_cur) and 0 or samt_cur   -- arme/desarme LEARN
    elseif n == 2 then local sl = samt_slot[samt_cur] ; sl.dest = ((sl.dest or 1) % #SAMT_DEST) + 1   -- destination cc/X/Y
    elseif n == 1 then samt_slot[samt_cur].key = nil ; samt_slot[samt_cur].val = 0 end   -- efface le mapping
    redraw() ; return
  end
  if page == 42 then
    if n == 3 then samt_mind_on = not samt_mind_on       -- l'agent ecoute le mouvement
    elseif n == 2 then peru_spawn = not peru_spawn        -- le mouvement fait apparaitre des grains dans PERU
    elseif n == 1 then samt_move = 1.0 end                -- TEST : injecte une fausse impulsion de mouvement (sans capteur)
    redraw() ; return
  end
  if page == 45 then                                      -- OSC OUT : envoi vers un module externe (/cv/1..8)
    if osco_cursor == 0 then                              -- ligne destination
      if n == 3 then                                      -- K3 : editer l'hote (clavier a l'ecran)
        local te = require('textentry')
        te.enter(function(txt) if txt and txt ~= "" then osco_host = txt end ; redraw() end,
                 osco_host, "HOTE OSC (ip ou .local)")
        return
      elseif n == 2 then osco_on = not osco_on            -- K2 : arme/desarme l'envoi
      elseif n == 1 then                                  -- K1 : PANIC -> 0 sur toutes les sorties
        local dest = { osco_host, osco_port }
        for i = 1, OSCO_N do pcall(osc.send, dest, "/cv/" .. (i - 1), { 0.0 }) ; pcall(osc.send, dest, "/gate/" .. (i - 1), { 0.0 }) ; osco_lanes[i].val = 0 ; osco_lanes[i].ghi = false end
      end
    else                                                  -- une sortie CV
      local lane = osco_lanes[osco_cursor]
      if n == 3 then lane.src = (lane.src % #CC_SRC) + 1  -- K3 : cycle la source
      elseif n == 2 then lane.on = not lane.on ; if lane.on then osco_on = true end   -- K2 : on/off (arme le master)
      elseif n == 1 then                                  -- K1 : PANIC -> 0 sur toutes les sorties
        local dest = { osco_host, osco_port }
        for i = 1, OSCO_N do pcall(osc.send, dest, "/cv/" .. (i - 1), { 0.0 }) ; pcall(osc.send, dest, "/gate/" .. (i - 1), { 0.0 }) ; osco_lanes[i].val = 0 ; osco_lanes[i].ghi = false end
      end
    end
    redraw() ; return
  end
  if page == 44 then                                      -- SNOT : 4 instruments gestuels -> notes MIDI
    local sn = samt_notes[samt_note_cur]
    if n == 3 then                                        -- K3 : learn TRIG (champ 2) ou PITCH (champ 3) du SNOT courant
      if samt_note_fld == 2 then sn.learn = (sn.learn == 1) and 0 or 1
      elseif samt_note_fld == 3 then sn.learn = (sn.learn == 2) and 0 or 2 end
    elseif n == 2 then                                    -- K2 : arme/desarme CE SNOT
      sn.on = not sn.on
      if not sn.on and sn.playing then
        local out = midi_outs[sn.dev]
        if out then out:note_off(sn.playing, 0, sn.ch) end
        sn.playing = nil
      end
    elseif n == 1 then                                    -- K1 : TEST -> joue une note de CE SNOT (sans capteur)
      local pv = 0.5
      if sn.pitch and samt_mon[sn.pitch] then pv = samt_mon[sn.pitch].val or 0.5 end
      local lo, hi = sn.lo, sn.hi ; if hi < lo then lo, hi = hi, lo end
      local note = math.floor(lo + pv * (hi - lo) + 0.5)
      local out, ch = midi_outs[sn.dev], sn.ch
      if out then
        out:note_on(note, 110, ch)
        clock.run(function() clock.sleep(0.3) ; if out then out:note_off(note, 0, ch) end end)
      end
    end
    redraw() ; return
  end
  if n == 2 and page == 4 then
    p_rhythm_idx = (p_rhythm_idx % #RHYTHM_RATES) + 1
    p_rhythm     = RHYTHM_RATES[p_rhythm_idx]
  elseif n == 2 and page == 5 then
    p_poto_poly = (p_poto_poly % #POTO_POLY_NAMES) + 1
  elseif n == 2 and page == 6 then
    os8_sync = not os8_sync
  elseif n == 2 and page == 8 then
    -- K2 = tout activer / tout couper (sources)
    local all = os8_src.input and os8_src.metabo and os8_src.comp and os8_src.mgen
    for _, k in ipairs(os8_src_keys) do os8_src[k] = not all end
  elseif n == 2 and page == 14 then
    -- cycle : 0 / 5 / 12 / 22 / 40% (manuel) puis META (pilote par le stress METABO)
    mgen_mut_idx = (mgen_mut_idx % (#MGEN_MUT_RATES + 1)) + 1
    if mgen_mut_idx > #MGEN_MUT_RATES then
      mgen_evo_meta = true
    else
      mgen_evo_meta = false ; mgen_mut_rate = MGEN_MUT_RATES[mgen_mut_idx]
    end
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
      -- K3 = active/coupe l'element surligne (meme logique que les autres pages de routing)
      if os8_src_cursor <= #os8_src_keys then
        local k = os8_src_keys[os8_src_cursor] ; os8_src[k] = not os8_src[k]
      else
        os8_pitch = not os8_pitch
      end
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

  -- ECRAN D'ACCUEIL : doit passer AVANT le dispatch des pages (elles sortent toutes en early return)
  if splash_active then
    screen.font_size(16)
    screen.level(15) ; screen.move(2, 24) ; screen.text("TEAMMATE")
    screen.level(8)  ; screen.move(2, 44) ; screen.text(".POTO")
    screen.level(2)  ; screen.font_size(8) ; screen.move(2, 58) ; screen.text("norns / nsdos 2026")
    screen.level(3)  ; screen.move(0, 30) ; screen.line(128, 30) ; screen.stroke()
    screen.update() ; return
  end

  -- CHOIX DU MODE au demarrage (apres le splash) ; le dernier mode est memorise et pris par defaut
  if boot_choose then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 9) ; screen.text("TEAMMATE.POTO")
    screen.level(4)  ; screen.move(2, 19) ; screen.text("choisis le mode :")
    screen.level(15) ; screen.move(2, 33) ; screen.text("K2  RECHERCHE")
    if not perf_mode then screen.level(12) ; screen.move(96, 33) ; screen.text("<dernier") end
    screen.level(6)  ; screen.move(14, 41) ; screen.text("nav libre (normal)")
    screen.level(15) ; screen.move(2, 54) ; screen.text("K3  PERFORMANCE")
    if perf_mode then screen.level(12) ; screen.move(96, 54) ; screen.text("<dernier") end
    screen.level(6)  ; screen.move(14, 62) ; screen.text("auto : agent/peru/corpus")
    screen.update() ; return
  end

  if page == 26 then
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
  if page == 27 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("MENU")
    if mgen_freeze then screen.level(15) ; screen.move(40, 8) ; screen.text("FRZ") end   -- patterns figes
    screen.level(4)  ; screen.move(126, 8) ; screen.text_right("E3 in  K3 arm")
    local ons = { p_poto_on, os8_mode ~= "OFF", mgen_running, spat.on, metabolik.on,
                  niakaby.on, audio_midi_on, comp_on, wifi.on, cc_on, peru_on, samt_on }
    local ys  = { 16, 23, 30, 37, 44, 51, 58 }
    for i = 1, #NAV_CATS do
      local c    = NAV_CATS[i]
      local left = (i <= 7)
      local x    = left and 2 or 66
      local xr   = left and 62 or 126
      local y    = ys[left and i or (i - 7)]
      if y then                                    -- garde-fou : pas de slot d'affichage -> on saute (evite tout crash)
        local sel  = (i == home_cursor)
        local on   = c.arm and ons[c.arm]
        screen.level(sel and 15 or (on and 11 or 4))
        screen.move(x, y) ; screen.text((sel and ">" or " ") .. c.n)
        if c.arm then screen.level(on and 13 or 3) ; screen.move(xr, y) ; screen.text_right(on and "on" or "-") end
      end
    end
    screen.update() ; return
  end
  if page == 8 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("8OS")
    screen.level(os8_rec_n > 0 and 12 or 4) ; screen.move(126, 8) ; screen.text_right(os8_rec_n .. " gr")
    screen.level(4) ; screen.move(2, 18) ; screen.text("TRANS source")
    local pos    = { {2,26}, {66,26}, {2,34}, {66,34}, {2,42}, {66,42} }
    local labels = { os8_src_labels[1], os8_src_labels[2], os8_src_labels[3], os8_src_labels[4], os8_src_labels[5], "PITCH" }
    for i = 1, 6 do
      local on  = (i <= #os8_src_keys) and os8_src[os8_src_keys[i]] or os8_pitch
      local sel = (i == os8_src_cursor)
      local x, y = pos[i][1], pos[i][2]
      screen.level(sel and 15 or (on and 10 or 4))
      screen.move(x, y) ; screen.text((sel and ">" or " ") .. labels[i])
      screen.level(on and 15 or 3) ; screen.move(x + 44, y) ; screen.text(on and "[X]" or "[ ]")
    end
    screen.level(os8_spread > 0 and 10 or 4) ; screen.move(2, 52)
    screen.text(string.format("spr %d%%", math.floor(os8_spread * 100)))
    screen.level(os8_trans ~= 0 and 10 or 4) ; screen.move(66, 52)
    screen.text(string.format("tr %+d", os8_trans))
    screen.level(4) ; screen.move(2, 62) ; screen.text("E2sel K3tgl K2all")
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
  if page == PERU_PAGE then
    screen.clear() ; screen.font_size(8)
    screen.level(peru_on and 15 or 6) ; screen.move(2, 8) ; screen.text("PERU")
    -- grain selectionne | gravite | auto-secousse
    screen.level(corpus[peru_sel] and 9 or 3) ; screen.move(32, 8)
    screen.text("g" .. peru_sel .. (corpus[peru_sel] and "" or "-"))
    screen.level(4) ; screen.move(58, 8) ; screen.text(string.format("G%.2f", peru_grav))
    screen.level(peru_rmode > 1 and 12 or 4) ; screen.move(126, 8) ; screen.text_right(PERU_RLBL[peru_rmode])
    -- la boite
    screen.level(3) ; screen.rect(PERU_BX0, PERU_BY0, PERU_BX1 - PERU_BX0, PERU_BY1 - PERU_BY0) ; screen.stroke()
    -- les diamants
    for _, d in ipairs(peru_dia) do
      local g  = corpus[d.slot]
      local lv = d.flash > 0 and 15 or math.max(3, math.min(13, 4 + math.floor((g and g.rms or 0) * 200)))
      local r  = d.r or 2
      screen.level(lv)
      screen.move(d.x, d.y - r) ; screen.line(d.x + r, d.y) ; screen.line(d.x, d.y + r) ; screen.line(d.x - r, d.y) ; screen.line(d.x, d.y - r) ; screen.stroke()
    end
    -- aide + threshold SAMT (quand le capteur est arme)
    screen.level(4) ; screen.move(2, 63) ; screen.text("K1lch K2react K3vide")
    if samt_on then screen.level(8) ; screen.move(126, 63) ; screen.text_right("thr" .. math.floor(samt_thr * 100)) end
    screen.update() ; return
  end
  if page == 40 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("PERU MIDI")
    screen.level(4)  ; screen.move(126, 8) ; screen.text_right("str8")
    local ys = { 22, 33, 44, 55 }
    for d = 1, 4 do
      local sel    = (d == peru_cur_dev)
      local routed = midi_route[8][d]
      local dname  = (midi.vports[d] and midi.vports[d].name) or ("DEV " .. d)
      if #dname > 8 then dname = string.sub(dname, 1, 7) .. "~" end
      screen.level(sel and 15 or (routed and 9 or 4))
      screen.move(2, ys[d]) ; screen.text(string.format("%sd%d %s", sel and ">" or " ", d, dname))
      screen.level(routed and 15 or 3)
      screen.move(86, ys[d]) ; screen.text(routed and "[X]" or "[ ]")
      screen.level(sel and 12 or 5)
      screen.move(108, ys[d]) ; screen.text("c" .. midi_ch[8][d])
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text("E2 dev  E3 ch  K3 route")
    screen.update() ; return
  end
  if page == 41 then
    screen.clear() ; screen.font_size(8)
    screen.level(samt_on and 15 or 6) ; screen.move(2, 8) ; screen.text("SAMT")   -- brillant = arme (LIVE)
    screen.level(6) ; screen.move(40, 8) ; screen.text("thr" .. math.floor(samt_thr * 100))   -- deadzone (E3)
    local nax = 0 ; for _ in pairs(samt_mon) do nax = nax + 1 end   -- nb d'axes/capteurs distincts detectes
    local live = (util.time() - (samt_last.t or 0)) < 0.5
    screen.level(live and 12 or 4) ; screen.move(126, 8) ; screen.text_right(nax .. " ax")
    local ys = { 20, 30, 40, 50 }
    for s = 1, 4 do
      local sl  = samt_slot[s]
      local sel = (s == samt_cur)
      screen.level(sel and 15 or 6) ; screen.move(2, ys[s]) ; screen.text((sel and ">" or " ") .. "MO" .. s)
      local nm = (sl.key and sl.key:gsub("^/", ""):sub(1, 8)) or ((samt_learn == s) and "learn.." or "--")
      screen.level(sl.key and 9 or 4) ; screen.move(22, ys[s]) ; screen.text(nm)
      local dest = sl.dest or 1
      if dest > 1 then screen.level(11) ; screen.move(64, ys[s]) ; screen.text(SAMT_DEST[dest]) end   -- destination -> PERU
      if sl.key then
        screen.level(4)  ; screen.rect(96, ys[s] - 4, 28, 3) ; screen.stroke()
        screen.level(12) ; screen.rect(96, ys[s] - 4, 28 * math.max(0, math.min(1, sl.val or 0)), 3) ; screen.fill()
      end
    end
    if live then   -- dernier axe recu : bouge UN capteur pour voir SON chemin s'afficher (= reconnu)
      screen.level(9) ; screen.move(2, 58)
      local lk = (samt_last.key or ""):gsub("^/", ""):sub(1, 16)
      screen.text("rx " .. lk .. " " .. math.floor((samt_last.val or 0) * 100))
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text("E2sel E3thr K2dst K3lrn K1clr")
    screen.update() ; return
  end
  if page == 43 then
    -- MONITOR : TOUS les axes de TOUS les capteurs en direct (defilable, pas juste les 4 slots)
    screen.clear() ; screen.font_size(8)
    local keys = {}
    for k in pairs(samt_mon) do keys[#keys + 1] = k end
    table.sort(keys)
    local nax = #keys
    screen.level(15) ; screen.move(2, 8) ; screen.text("MON")
    screen.level(6)  ; screen.move(30, 8) ; screen.text(nax .. " ax")
    local live = (util.time() - (samt_last.t or 0)) < 0.5
    screen.level(samt_on and 15 or (live and 12 or 4)) ; screen.move(126, 8)
    screen.text_right(samt_on and "arme" or (live and "rx" or "no rx"))
    local rows = 6
    if samt_mon_off > math.max(0, nax - rows) then samt_mon_off = math.max(0, nax - rows) end
    if nax == 0 then
      screen.level(5) ; screen.move(2, 34) ; screen.text("aucun capteur.")
      screen.level(4) ; screen.move(2, 44) ; screen.text("envoie OSC -> norns.local:10111")
    else
      for r = 1, rows do
        local k = keys[samt_mon_off + r]
        if k then
          local a = samt_mon[k]
          local y = 8 + r * 8
          local fresh = a and (util.time() - (a.t or 0)) < 0.3
          local tag = "" ; for s = 1, 4 do if samt_slot[s].key == k then tag = "M" .. s end end
          if tag ~= "" then screen.level(15) ; screen.move(2, y) ; screen.text(tag)   -- axe deja mappe -> MOn
          else screen.level(3) ; screen.move(2, y) ; screen.text("-") end
          screen.level(fresh and 15 or 7) ; screen.move(20, y) ; screen.text(k:gsub("^/", ""):sub(1, 12))
          local v = a and a.val or 0
          screen.level(6) ; screen.move(92, y) ; screen.text_right(math.floor(v * 100))
          screen.level(4) ; screen.rect(96, y - 4, 28, 3) ; screen.stroke()
          screen.level(fresh and 12 or 8) ; screen.rect(96, y - 4, 28 * math.max(0, math.min(1, v)), 3) ; screen.fill()
        end
      end
      if nax > rows then   -- indicateur de position dans la liste
        screen.level(5) ; screen.move(126, 63)
        screen.text_right((samt_mon_off + 1) .. "-" .. math.min(nax, samt_mon_off + rows) .. "/" .. nax)
      end
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text("E2 defiler  Mn=mappe")
    screen.update() ; return
  end
  if page == 44 then
    -- SNOT x4 : un instrument gestuel par capteur/danseur (axe trigger + axe hauteur -> note MIDI)
    screen.clear() ; screen.font_size(8)
    local sn = samt_notes[samt_note_cur]
    local f = samt_note_fld
    local function fld(i) return (f == i) and 15 or 5 end
    -- en-tete : SNOT# (champ 1) + etat des 4 (pastille = arme, pleine = joue)
    screen.level(fld(1)) ; screen.move(2, 8) ; screen.text((f == 1 and ">" or " ") .. "SNOT" .. samt_note_cur)
    for i = 1, 4 do
      local s = samt_notes[i] ; local x = 44 + i * 9
      if s.playing then screen.level(15) ; screen.circle(x, 5, 3) ; screen.fill()
      elseif s.on then screen.level(10) ; screen.circle(x, 5, 3) ; screen.stroke()
      else screen.level(3) ; screen.circle(x, 5, 2) ; screen.stroke() end
    end
    screen.level(sn.on and 12 or 4) ; screen.move(126, 8) ; screen.text_right(sn.on and "ARME" or "off")
    -- TRIG (champ 2)
    screen.level(fld(2)) ; screen.move(2, 20) ; screen.text((f == 2 and ">" or " ") .. "TRIG")
    local tn = (sn.trig and sn.trig:gsub("^/", ""):sub(1, 12)) or ((sn.learn == 1) and "bouge l'axe.." or "--")
    screen.level(sn.trig and 12 or 4) ; screen.move(40, 20) ; screen.text(tn)
    -- PITCH (champ 3)
    screen.level(fld(3)) ; screen.move(2, 30) ; screen.text((f == 3 and ">" or " ") .. "PITCH")
    local pn = (sn.pitch and sn.pitch:gsub("^/", ""):sub(1, 12)) or ((sn.learn == 2) and "bouge l'axe.." or "--")
    screen.level(sn.pitch and 12 or 4) ; screen.move(40, 30) ; screen.text(pn)
    -- DEV / CH (champs 4,5)
    screen.level(fld(4)) ; screen.move(2, 42)  ; screen.text("DEV " .. sn.dev)
    screen.level(fld(5)) ; screen.move(46, 42) ; screen.text("CH " .. sn.ch)
    -- LO / HI / THR (champs 6,7,8)
    screen.level(fld(6)) ; screen.move(2, 52)  ; screen.text("LO " .. sn.lo)
    screen.level(fld(7)) ; screen.move(40, 52) ; screen.text("HI " .. sn.hi)
    screen.level(fld(8)) ; screen.move(80, 52) ; screen.text("THR " .. math.floor(sn.thr * 100))
    screen.level(4) ; screen.move(2, 63) ; screen.text("E2 champ E3 val K3 learn K2 arm K1 test")
    screen.update() ; return
  end
  if page == 45 then
    -- OSC OUT : 8 sorties /cv/N pilotees par leur source, envoyees vers un module externe
    screen.clear() ; screen.font_size(8)
    screen.level(osco_on and 15 or 6) ; screen.move(2, 8) ; screen.text("OSC OUT")
    do local _, nc = nav_cat_of(page) ; if nc then local p = 1 ; for k, pg in ipairs(nc.pg) do if pg == page then p = k end end
      screen.level(5) ; screen.move(58, 8) ; screen.text(p .. "/" .. #nc.pg) end end   -- position dans la categorie CC
    screen.level(osco_on and 12 or 4) ; screen.move(126, 8) ; screen.text_right(osco_on and "ARME" or "off")
    -- ligne destination (curseur 0)
    local dsel = (osco_cursor == 0)
    screen.level(dsel and 15 or 7) ; screen.move(2, 17)
    screen.text((dsel and ">" or " ") .. osco_host .. ":" .. osco_port)
    -- 8 sorties en 2 colonnes de 4
    local ys = { 28, 37, 46, 55 }
    for i = 1, OSCO_N do
      local lane = osco_lanes[i]
      local col  = (i <= 4) and 0 or 1
      local row  = ((i - 1) % 4) + 1
      local x    = 2 + col * 64
      local y    = ys[row]
      local sel  = (osco_cursor == i)
      screen.level(sel and 15 or (lane.on and 9 or 3)) ; screen.move(x, y)
      local tm = lane.tmode or 0
      local sep = lane.on and ":" or " " ; if tm == 1 then sep = "!" elseif tm == 2 then sep = "=" end  -- : CV, ! TRIG, = GATE
      screen.text((sel and ">" or " ") .. (i - 1) .. sep .. CC_SRC[lane.src or 1])   -- sortie 0-7 (= sortie physique du HAT)
      local bx = x + 44
      screen.level(3) ; screen.rect(bx, y - 4, 16, 3) ; screen.stroke()
      screen.level(lane.on and 12 or 5) ; screen.rect(bx, y - 4, 16 * math.max(0, math.min(1, lane.val or 0)), 3) ; screen.fill()
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text(dsel and "E3 port K3 hote K2 arm K1 0V" or "K3 src E3 cv/trg/gat K2 on")
    screen.update() ; return
  end
  if page == 42 then
    screen.clear() ; screen.font_size(8)
    screen.level(samt_mind_on and 15 or 6) ; screen.move(2, 8) ; screen.text("MOVE")
    screen.level(4) ; screen.move(126, 8) ; screen.text_right(samt_mind_on and "on" or "off")
    local function bar(y, lbl, v, lv)
      screen.level(6) ; screen.move(2, y) ; screen.text(lbl)
      screen.level(3) ; screen.rect(44, y - 4, 78, 3) ; screen.stroke()
      screen.level(lv) ; screen.rect(44, y - 4, 78 * math.max(0, math.min(1, v)), 3) ; screen.fill()
    end
    bar(20, "ENRG", samt_energy or 0,               13)   -- energie instantanee
    bar(30, "ARC",  samt_build or 0,                11)   -- arc / soutenu
    bar(40, "SHRP", math.min(1, (samt_jerk or 0) * 3), 12) -- brusquerie
    local q = "flowing"
    if     (samt_energy or 0) < 0.12  then q = "still"
    elseif (samt_jerk or 0)  > 0.35   then q = "sharp"
    elseif (samt_build or 0) > 0.45   then q = "building" end
    screen.level(10) ; screen.move(2, 52) ; screen.text("> " .. q)
    screen.level(4)  ; screen.move(78, 52) ; screen.text(string.format("%.1fs", samt_still or 0))
    screen.level(peru_spawn and 12 or 3) ; screen.move(126, 52) ; screen.text_right("spwn")   -- apparition de grains
    screen.level(4)  ; screen.move(2, 63) ; screen.text("K1 test  K2 spawn  K3 ecoute")
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
    screen.level(4)  ; screen.move(2, 64) ; screen.text("K3 new theme now")
    screen.update() ; return
  end

  if page == 28 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("8OS MOD")
    screen.move(126, 8) ; screen.text_right(os8_mod_on and "ON" or "off")
    screen.level(4)  ; screen.move(2, 20) ; screen.text("E3 SRC")
    screen.level(15) ; screen.move(74, 20) ; screen.text(os8_mod_src_names[os8_mod_src])
    screen.level(4)  ; screen.move(2, 32) ; screen.text("E2 DEPTH")
    screen.level(15) ; screen.move(74, 32) ; screen.text(string.format("%d%%", math.floor(os8_mod * 100)))
    screen.level(4)  ; screen.rect(2, 35, 120, 2) ; screen.stroke()
    screen.level(12) ; screen.rect(2, 35, 120 * os8_mod, 2) ; screen.fill()
    -- signaux live de la source (act = energie, tone = brillance/tension)
    local act, tone = os8_mod_sig()
    screen.level(os8_mod_on and 8 or 3) ; screen.move(2, 48) ; screen.text("act")
    screen.level(4) ; screen.rect(24, 44, 38, 4) ; screen.stroke()
    screen.level(os8_mod_on and 12 or 3) ; screen.rect(24, 44, 38 * act, 4) ; screen.fill()
    screen.level(os8_mod_on and 8 or 3) ; screen.move(70, 48) ; screen.text("ton")
    screen.level(4) ; screen.rect(92, 44, 30, 4) ; screen.stroke()
    screen.level(os8_mod_on and 12 or 3) ; screen.rect(92, 44, 30 * tone, 4) ; screen.fill()
    screen.level(4) ; screen.move(2, 58) ; screen.text("act>sz/spr  ton>pitch")
    screen.level(4) ; screen.move(2, 64) ; screen.text("K3 on/off")
    screen.update() ; return
  end

  if page == 29 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("POtO MOD")
    screen.move(126, 8) ; screen.text_right(poto_mod_on and "ON" or "off")
    screen.level(4)  ; screen.move(2, 20) ; screen.text("E3 SRC")
    screen.level(15) ; screen.move(74, 20) ; screen.text(MOD_SRC_NAMES[poto_mod_src])
    screen.level(4)  ; screen.move(2, 32) ; screen.text("E2 DEPTH")
    screen.level(15) ; screen.move(74, 32) ; screen.text(string.format("%d%%", math.floor(poto_mod * 100)))
    screen.level(4)  ; screen.rect(2, 35, 120, 2) ; screen.stroke()
    screen.level(12) ; screen.rect(2, 35, 120 * poto_mod, 2) ; screen.fill()
    local act, tone = poto_mod_sig()
    screen.level(poto_mod_on and 8 or 3) ; screen.move(2, 48) ; screen.text("act")
    screen.level(4) ; screen.rect(24, 44, 38, 4) ; screen.stroke()
    screen.level(poto_mod_on and 12 or 3) ; screen.rect(24, 44, 38 * act, 4) ; screen.fill()
    screen.level(poto_mod_on and 8 or 3) ; screen.move(70, 48) ; screen.text("ton")
    screen.level(4) ; screen.rect(92, 44, 30, 4) ; screen.stroke()
    screen.level(poto_mod_on and 12 or 3) ; screen.rect(92, 44, 30 * tone, 4) ; screen.fill()
    screen.level(4) ; screen.move(2, 58) ; screen.text("act>taille  ton>pitch")
    screen.level(4) ; screen.move(2, 64) ; screen.text("K3 on/off")
    screen.update() ; return
  end

  if page == 33 then face_redraw() ; return end
  if page == 31 then mind.redraw() ; return end
  if page == 32 then style.redraw() ; return end
  if page == 35 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("WIFI MIDI")
    screen.level(wifi_midi_on and 12 or 3) ; screen.move(126, 8) ; screen.text_right(wifi_midi_on and "ON" or "off")
    screen.level(4)  ; screen.move(2, 22) ; screen.text("E2 device")
    screen.level(15) ; screen.move(74, 22) ; screen.text("D" .. wifi_midi_dev)
    screen.level(4)  ; screen.move(2, 32) ; screen.text("E3 canal")
    screen.level(15) ; screen.move(74, 32) ; screen.text("ch " .. wifi_midi_ch)
    screen.level(6)  ; screen.move(2, 44) ; screen.text("reseaux -> notes (" .. (wifi.count or 0) .. ")")
    screen.level(4)  ; screen.move(2, 63) ; screen.text("K3 on/off")
    screen.update() ; return
  end
  if page == 36 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("WIFI")
    -- trafic : barre au milieu de l'entete (n'empiete pas sur le compteur)
    screen.level(3)  ; screen.move(34, 8) ; screen.text("t")
    screen.level(2)  ; screen.rect(42, 3, 44, 4) ; screen.stroke()
    screen.level(11) ; screen.rect(42, 3, 44 * (wifi.traffic or 0), 4) ; screen.fill()
    screen.level(8)  ; screen.move(126, 8) ; screen.text_right((wifi.count or 0) .. "r")
    local n = #wifi.nets
    if n == 0 then
      screen.level(4) ; screen.move(2, 34) ; screen.text("aucun reseau")
      screen.level(4) ; screen.move(2, 46) ; screen.text("(arme WIFI sur LIVE)")
      screen.update() ; return
    end
    wifi_link_cur = util.clamp(wifi_link_cur, 1, n)
    local start = util.clamp(wifi_link_cur - 1, 1, math.max(1, n - 3))
    local y = 20
    for i = start, math.min(start + 3, n) do
      local net  = wifi.nets[i]
      local link = wifi_links[net.ssid]
      local sel  = (i == wifi_link_cur)
      screen.level(sel and 15 or 6) ; screen.move(2, y)
      screen.text((sel and ">" or " ") .. (((net.ssid == "") and "<hid>") or net.ssid):sub(1, 7))
      screen.level(2)  ; screen.rect(54, y - 4, 20, 3) ; screen.stroke()                  -- signal
      screen.level(sel and 13 or 9) ; screen.rect(54, y - 4, 20 * ((net.sig or 0) / 100), 3) ; screen.fill()
      if link and link.on then
        screen.level(sel and 15 or 10) ; screen.move(80, y) ; screen.text("D" .. link.dev .. "c" .. link.ch)
      else
        screen.level(3) ; screen.move(80, y) ; screen.text("--")
      end
      y = y + 9
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text("K2 dev  K3 link")
    screen.update() ; return
  end
  if page == 37 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("CC GEN")
    do local _, nc = nav_cat_of(page) ; if nc then local p = 1 ; for k, pg in ipairs(nc.pg) do if pg == page then p = k end end
      screen.level(5) ; screen.move(56, 8) ; screen.text(p .. "/" .. #nc.pg) end end   -- position dans la categorie CC
    screen.level(cc_on and 12 or 3) ; screen.move(126, 8) ; screen.text_right(cc_on and "ARM" or "off")
    -- ligne OUT (device + canal global) : curseur 0
    local osel = (cc_cursor == 0)
    local dv   = midi_outs[cc_dev]
    local dnm  = (dv and dv.name and dv.name:sub(1, 8)) or "none"
    screen.level(osel and 15 or 5) ; screen.move(2, 17)
    screen.text((osel and ">" or " ") .. "D" .. cc_dev .. " " .. dnm .. " ch" .. cc_ch)
    -- liste des lanes autour du curseur (5 visibles)
    local cur   = math.max(1, cc_cursor)
    local start = util.clamp(cur - 1, 1, math.max(1, 16 - 2))
    local y = 27
    for i = start, math.min(start + 2, 16) do
      local lane = cc_lanes[i]
      local sel  = (i == cc_cursor)
      screen.level(sel and 15 or (lane.on and 8 or 4)) ; screen.move(2, y)
      screen.text((sel and ">" or " ") .. "CC" .. (lane.num or i))
      local tm = lane.tmode or 0                                   -- ! = TRIG, = : GATE (a cote du n)
      if tm > 0 then screen.level(lane.on and 12 or 4) ; screen.move(34, y) ; screen.text(tm == 1 and "!" or "=") end
      screen.level(lane.on and (sel and 15 or 10) or 3) ; screen.move(40, y)
      screen.text(CC_SRC[lane.src or 1])
      -- barre de valeur
      screen.level(2)  ; screen.rect(74, y - 4, 44, 3) ; screen.stroke()
      if lane.on and (lane.src or 1) > 1 then
        screen.level(sel and 13 or 9) ; screen.rect(74, y - 4, 44 * (lane.val or 0), 3) ; screen.fill()
      end
      y = y + 8
    end
    -- moniteur d'entree CC / apprentissage
    local recent = (util.time() - (cc_rx_t or 0)) < 4
    if cc_learn then
      screen.level(15) ; screen.move(2, 54) ; screen.text("LEARN: tourne un bouton OP-1")
    elseif recent and cc_rx_cc >= 0 then
      screen.level(8) ; screen.move(2, 54) ; screen.text("rx  cc" .. cc_rx_cc .. "  ch" .. cc_rx_ch)
    else
      screen.level(3) ; screen.move(2, 54) ; screen.text("K1 learn (tourne un bouton)")
    end
    screen.level(3) ; screen.move(2, 62)
    if cc_cursor == 0 then screen.text("E3 ch  K2 dev  K3 arm")
    else screen.text("E3cc# K2src K3on K1+E3=mode") end
    screen.update() ; return
  end
  if page == 30 then
    screen.clear() ; screen.font_size(8)
    screen.level(15) ; screen.move(2, 8) ; screen.text("POtO SRC")
    screen.level(4)  ; screen.move(2, 18) ; screen.text("REC: INPUT/COMP  pitch: tous")
    local ys = { 26, 33, 40, 47, 54 }
    for i = 1, #poto_src_keys do
      local k   = poto_src_keys[i]
      local sel = (i == poto_src_cursor)
      local aud = (k == "input" or k == "comp")   -- sources audio = enregistrees
      screen.level(sel and 15 or (poto_src[k] and 10 or 4))
      screen.move(sel and 2 or 10, ys[i])
      screen.text((sel and "> " or "") .. poto_src_labels[i])
      if aud and poto_src[k] then screen.level(8) ; screen.move(64, ys[i]) ; screen.text("rec") end
      screen.level(poto_src[k] and 15 or 3)
      screen.move(92, ys[i]) ; screen.text(poto_src[k] and "[X]" or "[ ]")
    end
    screen.level(4) ; screen.move(2, 63) ; screen.text("E2 sel  K3 on/off  K2 all")
    screen.update() ; return
  end

  screen.font_size(8)




  -- ligne 1 : etat | corpus | page | dot rec
  screen.level(15)
  screen.move(0, 8)
  screen.text(state)

  screen.level(5)
  screen.move(42, 8)
  screen.text(string.format("c:%d/%d", count, CORPUS_SLOTS))

  local _, nav_c = nav_cat_of(page)            -- MODE + position dedans (ex. "POtO 2/4")
  if nav_c then
    local ni = 1
    for k, pg in ipairs(nav_c.pg) do if pg == page then ni = k end end
    screen.level(8) ; screen.move(126, 8) ; screen.text_right(nav_c.n .. " " .. ni .. "/" .. #nav_c.pg)
  else
    screen.level(5) ; screen.move(100, 8) ; screen.text(page_pos(page) .. "/" .. #PAGE_ORDER)
  end

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
    if mgen_freeze then
      screen.level(15) ; screen.move(84, 37) ; screen.text("FRZ")
    else
      screen.level((mgen_evo_meta or mgen_mut_rate > 0) and 9 or 3)
      screen.move(84, 37)
      screen.text(mgen_evo_meta and "META K2" or string.format("~%d%% K2", math.floor(mgen_mut_rate * 100)))
    end
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
    if mclk_active then                                   -- device verrouille (verifie que c'est bien l'OP-XY)
      local nm = mclk_src_name or "?" ; if #nm > 12 then nm = string.sub(nm, 1, 11) .. "~" end
      screen.level(6) ; screen.move(128, 50) ; screen.text_right(nm)
    end
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
    if mgen_freeze then
      screen.level(15) ; screen.move(80, 44) ; screen.text("FRZ")
    else
      screen.level((mgen_evo_meta or mgen_mut_rate > 0) and 8 or 3)
      screen.move(80, 44)
      screen.text(mgen_evo_meta and "META" or string.format("~%d%%", math.floor(mgen_mut_rate * 100)))
    end

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
