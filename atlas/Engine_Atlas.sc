// ============================================================================
// Engine_Atlas  —  PHASE A (brouillon, moteur SEPARE pour tester)
// ----------------------------------------------------------------------------
// Objectif : héberger le CORPUS dans un Buffer SuperCollider et le rejouer en
// NUAGE granulaire concaténatif (CataRT poly), sans toucher au moteur live.
//
// Disposition du corpus = identique à softcut : 48 slots de 2 s, slot s (0-based)
// commence au temps s*2.0 s dans le buffer. On enregistre l'entrée EN PARALLELE
// de softcut, via les mêmes hooks rec_start/rec_stop (côté Lua).
//
// Test standalone possible : charger un mini-script qui declenche
//   engine.corpus_rec(0)  ... (jouer un son) ... engine.corpus_rec_stop
//   engine.cloud(0, 0.4, 40, 0.12, 1, <8 positions sec>, <8 gains>)
// ============================================================================

Engine_Atlas : CroneEngine {

  classvar <slots = 48;
  classvar <slotDur = 2.0;        // secondes par slot (= CORPUS_DUR cote Lua)
  classvar <nSrc = 8;             // nb de sources de grain par nuage (grains proches du curseur)

  var in_bus;
  var input_synth;
  var corpus_buf;                 // Buffer SC du corpus (mono)
  var rec_synth;                  // synth d'enregistrement en cours (ou nil)
  var clouds;                     // IdentityDictionary : id -> Synth de nuage

  alloc {
    in_bus = Bus.audio(Server.default, 1);
    clouds = IdentityDictionary.new;

    // corpus : 48 * 2 s mono (~96 s ; ~18 Mo @48k)
    corpus_buf = Buffer.alloc(Server.default, (slots * slotDur * Server.default.sampleRate).asInteger, 1);

    // entree audio -> bus mono (comme le moteur live)
    SynthDef('atlas_input', {
      Out.ar(in_bus, Mix.ar(SoundIn.ar([0, 1])));
    }).add;

    // ENREGISTREMENT d'un slot : ecrit l'entree dans le buffer a l'offset du slot.
    // Phasor a la vitesse 1 = 1 frame/sample. Lua le cree (rec) et le free (rec_stop).
    SynthDef('atlas_corpus_rec', { |slot = 0|
      var sig   = In.ar(in_bus);
      var sr    = SampleRate.ir;
      var start = slot * slotDur * sr;
      var phase = Phasor.ar(0, 1, start, start + (slotDur * sr));  // reste dans les 2 s du slot
      BufWr.ar(sig, corpus_buf, phase);
    }).add;

    // NUAGE granulaire concatenatif :
    //  - nSrc sources = les grains proches du curseur (position en SECONDES dans le buffer)
    //  - gains = poids (distance au curseur) ; tirage pondere par grain (TWindex)
    //  - Dust declenche les grains a `density` grains/s ; GrainBuf lit une fenetre
    SynthDef('atlas_cloud', { |amp = 0.3, density = 40, grainDur = 0.12, rate = 1,
                            jitter = 0.01, gate = 1, out = 0,
                            positions = #[0,0,0,0,0,0,0,0],
                            gains     = #[0.001,0,0,0,0,0,0,0]|
      var totalSec = BufDur.kr(corpus_buf);
      var trig     = Dust.kr(density.max(1));            // trigger control-rate (~700 Hz >> densite)
      var idx      = TWindex.kr(trig, gains, 1);            // choisit une source (pondere par le gain)
      var posSec   = Select.kr(idx, positions);          // sa position en secondes
      var jit      = TRand.kr(jitter.neg, jitter, trig); // micro-dispersion
      var posN     = ((posSec + jit) / totalSec).clip(0, 1);
      var g        = GrainBuf.ar(2, trig, grainDur, corpus_buf, rate, posN, 2, 0, -1);
      var env      = EnvGen.kr(Env.asr(0.3, 1, 0.4), gate, doneAction: 2);
      Out.ar(out, g * amp * env);
    }).add;

    Server.default.sync;
    input_synth = Synth('atlas_input', [], Server.default);

    // ---- Commandes ----------------------------------------------------------

    // enregistre le slot donne (0..47) : cree le synth d'enreg (parallele a softcut)
    this.addCommand("corpus_rec", "i", { |msg|
      if (rec_synth.notNil) { rec_synth.free };
      rec_synth = Synth('atlas_corpus_rec', [\slot, msg[1].asInteger], input_synth, \addAfter);
    });

    // stoppe l'enregistrement en cours
    this.addCommand("corpus_rec_stop", "", { |msg|
      if (rec_synth.notNil) { rec_synth.free; rec_synth = nil };
    });

    // vide tout le corpus
    this.addCommand("corpus_clear", "", { |msg| corpus_buf.zero });

    // met a jour / cree un NUAGE (curseur) :
    //   id, amp, density, grainDur, rate, puis 8 positions(sec), puis 8 gains
    this.addCommand("cloud", "iffff" ++ String.fill(nSrc, $f) ++ String.fill(nSrc, $f), { |msg|
      var id   = msg[1].asInteger;
      var amp  = msg[2]; var dens = msg[3]; var gd = msg[4]; var rate = msg[5];
      var pos  = msg[(6)..(6 + nSrc - 1)];
      var gns  = msg[(6 + nSrc)..(6 + (2 * nSrc) - 1)];
      var s    = clouds[id];
      if (s.isNil) {
        s = Synth('atlas_cloud',
          [\amp, amp, \density, dens, \grainDur, gd, \rate, rate], input_synth, \addAfter);
        clouds[id] = s;
      } {
        s.set(\amp, amp, \density, dens, \grainDur, gd, \rate, rate);
      };
      s.setn(\positions, pos);   // array-control -> setn
      s.setn(\gains, gns);
    });

    // eteint un nuage (fade via gate)
    this.addCommand("cloud_free", "i", { |msg|
      var s = clouds[msg[1].asInteger];
      if (s.notNil) { s.set(\gate, 0); clouds[msg[1].asInteger] = nil };
    });
  }

  free {
    clouds.do { |s| if (s.notNil) { s.free } };
    if (rec_synth.notNil) { rec_synth.free };
    if (input_synth.notNil) { input_synth.free };
    if (corpus_buf.notNil) { corpus_buf.free };
    if (in_bus.notNil) { in_bus.free };
  }
}
