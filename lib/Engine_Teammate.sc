Engine_Teammate : CroneEngine {

  var in_bus, centroid_bus, flatness_bus;
  var input_synth, analysis_synth;

  alloc {

    in_bus       = Bus.audio(Server.default,   1);
    centroid_bus = Bus.control(Server.default, 1);
    flatness_bus = Bus.control(Server.default, 1);

    SynthDef('tm_input', {
      var sig = Mix.ar(SoundIn.ar([0,1]));
      Out.ar(in_bus, sig);
    }).add;

    SynthDef('tm_analysis', {
      var sig      = In.ar(in_bus);
      var chain    = FFT(LocalBuf(2048), sig);
      var centroid = SpecCentroid.kr(chain);
      var flatness = SpecFlatness.kr(chain);
      Out.kr(centroid_bus, centroid);
      Out.kr(flatness_bus, flatness);
    }).add;

    Server.default.sync;

    input_synth    = Synth('tm_input',    [], Server.default);
    analysis_synth = Synth('tm_analysis', [], Server.default);

    this.addPoll('tm_centroid', { centroid_bus.getSynchronous });
    this.addPoll('tm_flatness', { flatness_bus.getSynchronous });
  }

  free {
    [input_synth, analysis_synth].do { |s| if (s.notNil) { s.free } };
    [in_bus, centroid_bus, flatness_bus].do { |b| b.free };
  }
}
