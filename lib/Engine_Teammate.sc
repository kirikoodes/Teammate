Engine_Teammate : CroneEngine {

  var in_bus, rms_bus, freq_bus, centroid_bus, flatness_bus, gate_bus;
  var chroma_bus;
  var input_synth, analysis_synth;

  alloc {

    in_bus       = Bus.audio(Server.default,   1);
    rms_bus      = Bus.control(Server.default, 1);
    freq_bus     = Bus.control(Server.default, 1);
    centroid_bus = Bus.control(Server.default, 1);
    flatness_bus = Bus.control(Server.default, 1);
    gate_bus     = Bus.control(Server.default, 1);
    // chroma : 12 classes de hauteur (analyse multi-notes / accords)
    chroma_bus   = Array.fill(12, { Bus.control(Server.default, 1) });

    SynthDef('tm_input', {
      var sig = Mix.ar(SoundIn.ar([0,1])) * 0.5;
      Out.ar(in_bus, sig);
    }).add;

    SynthDef('tm_analysis', {
      var sig      = In.ar(in_bus);
      var amp      = Amplitude.kr(sig, 0.005, 0.12);
      var gate     = (amp > 0.008).lag(0.01);
      var chain    = FFT(LocalBuf(2048), sig);
      var freq     = Pitch.kr(sig, initFreq: 440, minFreq: 60, maxFreq: 4000)[0];
      var centroid = SpecCentroid.kr(chain);
      var flatness = SpecFlatness.kr(chain);
      // CHROMA : banc de resonateurs (12 classes x 3 octaves, UGens de base, sans plugin)
      // -> energie presente par classe de hauteur, pour capter les accords
      var chroma   = Array.fill(12, { |pc|
        ([48, 60, 72].collect { |b| Amplitude.kr(BPF.ar(sig, (b + pc).midicps, 0.04), 0.01, 0.1) }).sum;
      });
      Out.kr(rms_bus,      amp);
      Out.kr(freq_bus,     freq);
      Out.kr(centroid_bus, centroid);
      Out.kr(flatness_bus, flatness);
      Out.kr(gate_bus,     gate);
      chroma.do { |e, pc| Out.kr(chroma_bus[pc], e) };
    }).add;

    Server.default.sync;

    input_synth    = Synth('tm_input',    [], Server.default);
    // l'analyse doit tourner APRES l'entree (sinon elle lit le bus avant qu'il soit rempli = silence :
    // centroide 0, flatness ~0,8 en permanence)
    analysis_synth = Synth.after(input_synth, 'tm_analysis');

    this.addPoll('tm_rms',      { rms_bus.getSynchronous      });
    this.addPoll('tm_freq',     { freq_bus.getSynchronous     });
    this.addPoll('tm_centroid', { centroid_bus.getSynchronous });
    this.addPoll('tm_flatness', { flatness_bus.getSynchronous });
    this.addPoll('tm_gate',     { gate_bus.getSynchronous     });
    12.do { |pc| this.addPoll(("tm_chr" ++ pc).asSymbol, { chroma_bus[pc].getSynchronous }) };
  }

  free {
    [input_synth, analysis_synth].do { |s| if (s.notNil) { s.free } };
    [in_bus, rms_bus, freq_bus, centroid_bus, flatness_bus, gate_bus].do { |b| b.free };
    chroma_bus.do { |b| b.free };
  }
}
