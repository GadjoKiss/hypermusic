using Gst;

public static uint spect_bands = 32;
public static uint AUDIOFREQ = 44100;


public static int normalize_mag(float mag){
        // Normalize magnitude to 0-255
	double mag_min = -100.0;
	double mag_max = -40.0;
	//stdout.printf("yo %f\n\n",mag);
        if (mag < mag_min)
            return 0;
        if (mag > mag_max)
            return 255;

        return (int)(((mag-mag_min) / (mag_max - mag_min)) * 255);
}

public static bool createImage (GLib.Value magnitudes, GLib.Value phases, uint width, uint height){
		      double freq;
	      uint i;
	for (i = 0; i < spect_bands; ++i) {
		freq = (double) ((AUDIOFREQ / 2) * i + AUDIOFREQ / 4) / spect_bands;
		var mag = ValueList.get_value(magnitudes, i);
		var phase = ValueList.get_value(phases, i);

		if (mag != null && phase != null) {
//		normalize_mag(mag.get_float ());
		stdout.printf ("band %u (freq %g): magnitude %i dB phase %f\n", i, freq,
		    	normalize_mag(mag.get_float ()), phase.get_float ());
		}
	}
	return true;
}

public static bool
	message_handler (Gst.Bus bus, Gst.Message message)
	{
	  if (message.type != MessageType.ERROR) {
	    unowned Gst.Structure s = message.get_structure();
	    string name = s.get_name ();
	    Gst.ClockTime endtime;

	    if (name == "spectrum") {

	      if (!s.get_clock_time("endtime", out endtime))
		endtime = Gst.CLOCK_TIME_NONE;

	     // stdout.printf ("New spectrum message, endtime %s\n", endtime.to_string());

	      var magnitudes = s.get_value ("magnitude");
	      var phases = s.get_value ("phase");
	createImage(magnitudes,phases,16,9);
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
    		string dev = args[1];
    		if(dev == null) // set default value
    			dev = "alsa_output.pci-0000_00_1b.0.analog-stereo.monitor";
    			//"alsa_output.pci-0000_00_1b.0.hdmi-stereo-extra1.monitor"
    			//alsa_output.pci-0000_00_1b.0.analog-stereo.monitor
		src.set("device",dev);

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
