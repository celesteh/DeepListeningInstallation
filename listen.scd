(

var installation, fullscreen, rec_dot, text, init, colour, alpha, is_raspberry=false, lines, do_record, is_recording = false, semaphore, rec_dur = 20, buf, buffers, manage_text, instructions;

installation = KeepInstallationAlive.new;


semaphore = Semaphore(1);

{
	var next_buf, pb, watcher, recbuffer, srv_watcher, server_record;

	server_record = 		{
		try {
			installation.s.stopRecording;
		};
		try {
			installation.s.sync;
			installation.s.prepareForRecord(PathName("~/Desktop/Listen"++Date.getDate.rawSeconds++".aiff").absolutePath);
			installation.s.sync;
			installation.s.record;
		};
	};


	installation.boot(action:{
		buffers = Array(50);
		recbuffer = Buffer.alloc(s, ((rec_dur / 4) * installation.s.sampleRate).nextPowerOfTwo, 1);

		server_record.fork
	});

	srv_watcher = installation.setMonitorServer(true, 0);
	installation.preventPeaking(true);

	srv_watcher.addFirstFix({
		server_record.fork
	});

	//s.waitForBoot({

	//var next_buf, playgrp;

	//playgrp = Group(s);

	s.sync;

	installation.addGroup(\playgrp);

	installation.addSynthDef(
		SynthDef(\rec, {|in=0, db=0, bufnum=1, recbufnum=0, gate=1, dur=1|
			var input, env;

			env = EnvGen.kr(Env([0,1,1,0],[0.01, dur-0.11, 0.1]), gate, doneAction:2) *
			EnvGen.kr(Env.asr, gate);

			input = SoundIn.ar(in, env * db.dbamp);
			RecordBuf.ar(input, bufnum, preLevel:(1-env));
			DiskOut.ar(recbufnum, input);
	}));

	installation.addSynthDef(
		SynthDef(\player, {|out=0, amp=0.5, bufnum=0, gate=1, dur=1|
			var output, env;

			env = EnvGen.kr(Env([0,1,1,0],[0.01, dur, 0.1]), gate, doneAction:2) *
			EnvGen.kr(Env.asr, gate);

			output = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), loop:1);
			Out.ar(out, output * env * amp);
	}));

	next_buf = {
		// put the old buffer into the array
		buf.notNil.if({

			(buffers.size >= buffers.maxSize).if({
				buffers.removeAt(0);
			});
			buffers = buffers.add(buf)

		});

		// make a newbuffer
		buf = Buffer.alloc(s, s.sampleRate * rec_dur);

		// get recording buffer ready to write
		recbuffer.write(PathName("~/Desktop/sample"++Date.getDate.rawSeconds++".aiff").absolutePath, "aiff", "int16", 0, 0, true);
	};


	do_record = {
		//"do record".postln;
		{
			//"semaphore wait".postln;
			semaphore.wait;
			//"done waiting".postln;
			is_recording = true;
			colour = Color.red;
			AppClock.sched(0, {
				text.collect({|t| t.stringColor = Color.black; t.string = "";});
				text.last.string = "\t⬤  Recording...";
				text.last.stringColor = Color.red;
				nil
			});
			AppClock.sched(rec_dur, {
				//text.last.stringColor = Color.black;
				lines.reset;
				nil;
			});
			next_buf.();
			installation.groups[\playgrp].set(\gate, 0);
			s.sync;
			Synth(\rec, [\bufnum, buf.bufnum, \recbufnum, recbuffer.bufnum, \dur, rec_dur]);
			(rec_dur + 0.11).sleep;
			recbuffer.close;

			is_recording = false;
			semaphore.signal;
		}.fork;
	};

	s.sync;


	pb = Pbind(
		\instrument, \player,
		\group, Pfunc({var grp;
			grp = installation.groups[\playgrp];
			grp.notNil.if({ grp = grp.nodeID});
			grp
		}),
		\bufnum, Pfunc({ (buffers.size > 0).if({ buffers.choose.bufnum}, {Rest()}) }),
		\dur, rec_dur,
		\legato, 1.1,
		\db, Pwhite(-9.0, -6.0),
		\degree, Pfunc({|evt|
			(evt[\bufnum].isKindOf(Rest) || is_recording).if({
				\rest
			}, {
				buffers.size.linlin(0, 10, 0, 0.3).coin.if({
					1
				}, {
					\rest
				});
			});
		}),
		\out, 1,
		\isAlive, Pfunc({|evt| evt[\bufnum].postln; installation.checkIn(\pbind)})
	).play;

	watcher = installation.addWatchDog(\pbind, rec_dur);
	watcher.addFix({pb.resume});
	watcher.addFix({pb.start});
	watcher.addFix({pb.reset; pb.start});


}.fork;



init = {
	var pts, window, font, text_height;

	instructions = ["", "  Listen.", "  What do you hear?", "  Press the spacebar to record"];


	window = Window.new("Listen", Window.availableBounds, scroll:false); // was true
	window.view.decorator = FlowLayout( window.view.bounds, 10@10, 20@5 );

	text_height = window.view.bounds.height / instructions.size;

	pts = (text_height * 0.4).asInt;

	//"Font size is %".format(config[\font_size]).postln;
	//pts = //50; //(config[\font_size]).asInt(); //50;

	Font.availableFonts.collect({|name| name.asSymbol}).includes(\Bravura).if({
		font = Font("Bravura", pts);
	} , {
		Font.availableFonts.collect({|name| name.asSymbol}).includes(\Verdana).if({
			font = Font("Verdana", pts);
		} , {
			font = Font.sansSerif(pts);
		});
	});

	//(window.view.bounds.height/instructions.size).postln;

	text = instructions.collect ({
		StaticText(window.view, Rect(10, 0,  window.view.bounds.width, text_height));
	});//Rect(0, 100, window.bounds.width,

	window.view.background_(Color.black);
	window.front;
	window.fullScreen;
	fullscreen = true;

	text.collect({|t| t.background = Color.black;});
	colour = Color.white;
	text.collect({|t| t.stringColor = colour});
	alpha = 0;
	text.collect({|t| t.font = font;});
	text.collect({|t| t.align = \left;});
	//tweet.string = "#sc140";


	window.view.keyDownAction = {arg view, char, modifiers, unicode, keycode;

		//"key".postln;

		(char == $ ).if ({ //spacebar
			//"spacebar".postln;
			is_recording.not.if({
				//"not recording".postln;
				{do_record.()}.fork;
			});

		}, {

			//"char %, modifiers %, unicode %, keycode %\n".postf(char.asInt, modifiers.asInt, unicode.asInt, keycode.asInt)
			(char.asInt == 27 || is_raspberry ).if ({ //Esc key
				fullscreen.if({
					//window.endFullScreen;  //DISABLED
				}, {
					window.fullScreen;
				});
				fullscreen = fullscreen.not;
			});

		});
	};

	// if you close the window, you get 30 seconds befor eit re-opens itself
	window.onClose = { AppClock.sched(30, {{init}.value.value}, nil) };

};


AppClock.sched(0, {init.(); nil});

manage_text = {
	var alpha=0, fade, pause, steps, fade_index=0, watcher, appclock;

	watcher = installation.addWatchDog(\gui, rec_dur);

	lines = Routine ({
		var items, index, ret;
		items = instructions.pyramidg(1);
		items = items.collect({|i| i ++ Array.fill(text.size-i.size, {""}) }); // keep number of lines constant
		inf.do({
			ret = "";
			items.do({|item, count|
				//ret = item.join("\n");
				ret = item;
				//ret.postln;
				fade_index = count;
				ret.yield;
			});
		});
	});

	fade = 2;
	pause = 8.5;
	steps = 30;

	appclock = {
		var time;//, new_text;

		installation.checkIn(\gui);

		is_recording.not.if({


			(alpha == 0).if({
				lines.next.do({|line, i|
					(fade_index > 0).if({
						(i >= fade_index).if({
							text[i].stringColor = text[i].background;
						});

						text[i].string = line;
					});
				})
			});



			(alpha < 1).if({
				alpha = alpha + (1/steps);
				//alpha.postln;
				time = fade/steps;
				(fade_index > 0).if({
					text.do({|string, count|
						(count < fade_index).if({
							string.stringColor = Color.white;
						}, { (count == fade_index).if({
							string.stringColor = Color.white.alpha_(alpha.min(1));
							//string.string.postln;
						}, { (count > fade_index).if({
							string.stringColor = string.background;
						});
						});
						});
					});
				}, {
					text.do({|t| t.stringColor = t.stringColor.alpha_((1-alpha).min(1).max(0)); });
				});

			}, {
				alpha = 0;
				//new_text = lines.next;
				//new_text.spotln;
				//lines.next.do({|line, i|
				//	text[i].string = line;
				//	text[i].stringColor = Color.white;
				//});
				(fade_index > 0).if({
					text.do({|string| string.stringColor = Color.white });
				});
				time = pause - fade;
				//text.string.postln;
			});
			time;
		}, {
			alpha = 0;
			1
		});
	};


	AppClock.sched(1, appclock);

	watcher.addFix({AppClock.clear; AppClock.sched(1, appclock);});
	watcher.addFix({AppClock.clear; AppClock.sched(1, {{init}.value.value;}); AppClock.sched(5, appclock);});

};

manage_text.();

)


//AppClock.sched(0, { init.value; nil});

//)



