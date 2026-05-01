Engine_Teammate : CroneEngine {

  var in_bus, rms_bus, freq_bus, centroid_bus, flatness_bus, gate_bus;
  var input_synth, analysis_synth;

  alloc {

    in_bus       = Bus.audio(Server.default,   1);
    rms_bus      = Bus.control(Server.default, 1);
    freq_bus     = Bus.control(Server.default, 1);
    centroid_bus = Bus.control(Server.default, 1);
    flatness_bus = Bus.control(Server.default, 1);
    gate_bus     = Bus.control(Server.default, 1);

    SynthDef('tm_input', {
      var sig = Mix.ar(SoundIn.ar([0,1]));
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
      Out.kr(rms_bus,      amp);
      Out.kr(freq_bus,     freq);
      Out.kr(centroid_bus, centroid);
      Out.kr(flatness_bus, flatness);
      Out.kr(gate_bus,     gate);
    }).add;

    Server.default.sync;

    input_synth    = Synth('tm_input',    [], Server.default);
    analysis_synth = Synth('tm_analysis', [], Server.default);

    this.addPoll('tm_rms',      { rms_bus.getSynchronous      });
    this.addPoll('tm_freq',     { freq_bus.getSynchronous     });
    this.addPoll('tm_centroid', { centroid_bus.getSynchronous });
    this.addPoll('tm_flatness', { flatness_bus.getSynchronous });
    this.addPoll('tm_gate',     { gate_bus.getSynchronous     });
  }

  free {
    [input_synth, analysis_synth].do { |s| if (s.notNil) { s.free } };
    [in_bus, rms_bus, freq_bus, centroid_bus, flatness_bus, gate_bus].do { |b| b.free };
  }
}
