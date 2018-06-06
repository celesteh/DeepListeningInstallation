(

var fullscreen, rec_dot, text, init, colour, alpha, is_raspberry=false, lines, do_record, is_recording = false, semaphore, rec_dur = 20, buf, buffers = [], manage_text, instructions;

semaphore = Semaphore(1);


s.waitForBoot({

	var next_buf, playgrp;

	playgrp = Group(s);

	SynthDef(\rec, {|in=0, db=0, bufnum=0, gate=1, dur=1|
		var input, env;

		env = EnvGen.kr(Env([0,1,1,0],[0.01, dur, 0.1]), gate, doneAction:2) *
		EnvGen.kr(Env.asr, gate);

		input = SoundIn.ar(in, env * db.dbamp);
		RecordBuf.ar(input, bufnum, preLevel:(1-env));
	}).add;

	SynthDef(\player, {|out=0, amp=0.5, bufnum=0, gate=1, dur=1|
		var output, env;

		env = EnvGen.kr(Env([0,1,1,0],[0.01, dur, 0.1]), gate, doneAction:2) *
		EnvGen.kr(Env.asr, gate);

		output = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), loop:1);
		Out.ar(out, output * env * amp);
	}).add;

	next_buf = {
		buf.notNil.if({ buffers = buffers.add(buf)});
		buf = Buffer.alloc(s, s.sampleRate * rec_dur);
	};


	do_record = {
		{
			semaphore.wait;
			is_recording = true;
			colour = Color.red;
			AppClock.sched(0, {
				text.stringColor = Color.black;
				text.string = "\n\n\n\n\n\t\t⬤  Recording...";
				text.stringColor = Color.red;
				nil
			});
			AppClock.sched(rec_dur, {
				text.stringColor = Color.black;
				lines.reset;
				nil;
			});
			next_buf.();
			playgrp.set(\gate, 0);
			s.sync;
			Synth(\rec, [\bufnum, buf.bufnum, \dur, rec_dur]);
			rec_dur.sleep;
			is_recording = false;
			semaphore.signal;
		}.fork;
	};

	s.sync;

	Pbind(
		\instrument, \player,
		\group, playgrp.nodeID,
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
		})
	).play;


});



init = {
	var pts, window, font;

	instructions = ["", "\tListen.", "\tWhat do you hear?", "\tPress the spacebar to record"];


	//"Font size is %".format(config[\font_size]).postln;
	pts = 50; //(config[\font_size]).asInt(); //50;

	Font.availableFonts.collect({|name| name.asSymbol}).includes(\Bravura).if({
		font = Font("Bravura", pts);
	} , {
		Font.availableFonts.collect({|name| name.asSymbol}).includes(\Verdana).if({
			font = Font("Verdana", pts);
		} , {
			font = Font.sansSerif(pts);
		});
	});

	window = Window.new("Listen", Window.availableBounds, scroll:false); // was true
	window.view.decorator = FlowLayout( window.view.bounds, 10@10, 20@5 );

	text = instructions.collect ({
		StaticText(window.view, Rect(10, 0,  window.view.bounds.width, window.view.bounds.height/instructions.size));
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

		(char == $ ).if ({ //spacebar
			is_recording.not.if({
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
	var alpha=0, fade, pause, steps, fade_index=0;

	lines = Routine ({
		var items, index, ret;
		items = instructions.pyramidg(1);
		items = items.collect({|i| i ++ Array.fill(text.size-i.size, {""}) }); // keep number of lines constant
		inf.do({
			ret = "";
			items.do({|item, count|
				//ret = item.join("\n");
				ret = item;
				ret.postln;
				fade_index = count;
				ret.yield;
			});
		});
	});

	fade = 2;
	pause = 8.5;
	steps = 30;

	AppClock.sched(1, {
		var time;//, new_text;
		is_recording.not.if({
			(alpha == 0).if({
				lines.next.do({|line, i|
					(i >= fade_index).if({
						text[i].stringColor = text[i].background;
					});

					text[i].string = line;
				});
			});

			(alpha < 1).if({
				alpha = alpha + (1/steps);
				alpha.postln;
				time = fade/steps;
				text.do({|string, count|
					(count < fade_index).if({
						string.stringColor = Color.white;
					}, { (count == fade_index).if({
						string.stringColor = Color.white.alpha_(alpha.min(1));
						string.string.postln;
					}, { (count > fade_index).if({
						string.stringColor = string.background;
					});
					});
					});
				});

			}, {
				alpha = 0;
				//new_text = lines.next;
				//new_text.spotln;
				//lines.next.do({|line, i|
				//	text[i].string = line;
				//	text[i].stringColor = Color.white;
				//});
				text.do({|string| string.stringColor = Color.white });
				time = pause - fade;
				//text.string.postln;
			});
			time;
		}, { 1 });
	});

};

manage_text.();

)


//AppClock.sched(0, { init.value; nil});

//)



