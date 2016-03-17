using Gst;

public static uint spect_bands = 20;
public static uint AUDIOFREQ = 44100;

public static bool
	message_handler (Gst.Bus bus, Gst.Message message)
	{
	  if (message.type != MessageType.ERROR) {
	    unowned Gst.Structure s = message.get_structure();
	    string name = s.get_name ();
	    Gst.ClockTime endtime;

	    if (name == "spectrum") {
	      double freq;
	      uint i;
	      if (!s.get_clock_time("endtime", out endtime))
		endtime = Gst.CLOCK_TIME_NONE;

	      stdout.printf ("New spectrum message, endtime %", endtime);

	      var magnitudes = s.get_value ("magnitude");
	      var phases = s.get_value ("phase");

	      for (i = 0; i < spect_bands; ++i) {
		freq = (double) ((AUDIOFREQ / 2) * i + AUDIOFREQ / 4) / spect_bands;
		var mag = ValueList.get_value (magnitudes, i);
		var phase = ValueList.get_value (phases, i);

		if (mag != null && phase != null) {
		  stdout.printf ("band %u (freq %g): magnitude %f dB phase %f\n", i, freq,
		      mag.get_float (), phase.get_float ());
		}
	      }
	      stdout.printf ("\n");
	    }
	  }
	  return true;
}

	public static int main (string[] args) {
		Gst.Bus bus;
		MainLoop loop;

		Gst.init (ref args);


 		var bin = new Pipeline ("test");
    		var src = ElementFactory.make ("pulsesrc", "src");
		src.set("device","alsa_output.pci-0000_00_1b.0.hdmi-stereo-extra1.monitor");
		//src.set("wave", 0);
		//src.set("freq", 6000.0);

		var audioconvert = ElementFactory.make ("audioconvert",null);
		//assert(audioconvert);

		var spectrum = ElementFactory.make  ("spectrum", "spectrum");

		spectrum.set("bands", spect_bands);
		spectrum.set("threshold", -100);
		spectrum.set("post-messages", true);
		spectrum.set("message-phase", true);

		var sink = ElementFactory.make ("fakesink", "sink");
		sink.set("sync", true);
		bin.add_many(src, audioconvert, spectrum, sink);

		var caps = new Caps.simple("audio/x-raw", "rate", typeof(int), AUDIOFREQ);//.simple("audio/x-raw",
	       //                 "rate", typeof(int), AUDIOFREQ);

		if (!src.link (audioconvert) ||
		      !audioconvert.link_filtered (spectrum, caps) ||
		      !spectrum.link (sink)) {
		    stdout.printf ("can't link elements\n");
		    return (1);
		  }
		  //unref (caps);//gst_caps_unref (caps);

		  bus = bin.get_bus ();
		  bus.add_watch (GLib.Priority.DEFAULT, message_handler);
		  //unref (bus);

		  bin.set_state (State.PLAYING);

		  /* we need to run a GLib main loop to get the messages */
		  loop = new MainLoop ();
		  loop.run();

		  bin.set_state(State.NULL);

		  //unref bin;

		  return 0;
	}
