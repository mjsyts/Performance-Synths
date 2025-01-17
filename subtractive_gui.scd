(
var win;
var mixGUI, mixFlow;
var winX=150, winY=300, winWidth=1120, winHeight=680;
var sliderWidth=20, sliderHeight=140;
var gateButton;
var mixGUIx=20, mixGUIy=350, mixGUIwidth=220, mixGUIheight=310;
var mixSlider1, mixSlider2, mixSlider3, mixSlider4, mixMuteButton;
var mixMuteButtonX=160, mixMuteButtonY=200, mixMuteButtonHeight=30, mixMuteButtonWidth=40;
var masterKnob, masterLabel, masterKnobWidget, masterValBox;
var masterKnobSize=90, masterValBoxHeight=18, masterValBoxWidth=50, masterKnobY=175;
var sliderValHeight=13, sliderValWidth=30;
var envGUI, envWidget;
var envGUIx=240, envGUIy=350, envGUIwidth=200, envGUIheight=310;
var atk, dec, sus, rel, curve;
var aSlidVal, dSlidVal, sSlidVal, rSlidVal;
var greyness=0.7;
var osc1Node, osc2Node, osc3Node, noiseNode, mixNode, filtNode;
var osc1GUI, osc2GUI, osc3GUI;
var osc1GUIx=10, osc1GUIy=20;
var oscGUIwidth=200, oscGUIheight=310;
var freqDispSize=60;
var oscSliderSize=150;
var freqDispX=12, freqDispY=20;
var oscGUIMargin=4, guiXs;
var osc1SliderFlow, osc2SliderFlow, osc3SliderFlow;
var oscPitchSliderSize=20@130;
var oscSliderFlowY=90, oscSliderFlowHeight=150, oscSliderMargin=29, oscSliderGap=40;
var osc1freqDisp, osc2freqDisp, osc3freqDisp;
var shapeSliderY=251, shapeSliderHeight=10;
var shapeLabelY=260, oscSliderLabelHeight=15;
var osc1ShapeLabel, osc2ShapeLabel, osc3ShapeLabel;
var osc1WidthLabel, osc2WidthLabel, osc3WidthLabel;
var widthSliderY=281, widthLabelY=290;
var oscMargin = 20;
var oct1Slider, oct2Slider, oct3Slider, semi1Slider, semi2Slider, semi3Slider, fine1Slider, fine2Slider, fine3Slider;
var osc1OctWidget, osc2OctWidget, osc3octWidget;
var oscSlider1, oscSlider2, oscSlider3;
var oscOctWidgetX=20, oscOctWidgetY=225, oscOctWidgetW=10, oscOctWidgetH=70;
var octSlideMap, semiMap, fineMap, octNumMap;
var filtGUI;
var filtGUIx=460, filtGUIy=350, filtGUIwidth=220, filtGUIheight=310;
var cutoffKnobY=20, cutoffKnobSize=150;
var resKnobY=195, resKnobSize=60;
var filtSelectY=280;
var filtSelectWidget, resKnob;
var filtEnvGUI, filtEnvWidget;
var filtEnvGUIx=680, filtEnvGUIy=350, filtEnvGUIwidth=420, filtEnvGUIheight=310;
var filtEnvASlider, filtEnvDSlider, filtEnvSSlider, filtEnvRSlider;
var mulKnobSize=180;


/////test vars/////
var testSynth;
var buttonGUI;
///////////////////





/////////////////////////CLEANUP, BOOT//////////////////////////





s = Server.local;
s.newBusAllocators;
s.options.numInputBusChannels_(0);
Window.closeAll;
MIDIClient.init;
MIDIIn.connectAll;
s.waitForBoot({


	/////allocate scope buffer


	~scopeBuf = Buffer.alloc(s,1024,1);

	s.sync;




	/////////////???/////CONTROL SPEC MAP/////////////////////////

	~filterMap = ControlSpec(20,20000,\exp);
	~resMap = ControlSpec(1.0,0.01,\lin);
	~curveMap = ControlSpec(-4.0,4.0,\lin);
	~envMap = ControlSpec(0.001,10.0,\exp);
	~filtCVMap = ControlSpec(-10.0,10.0,\lin);
	~octaveMap = ControlSpec(-4, 4, \lin);




	///////////////////NODE/GROUP ALLOCATION//////////////////////






	~osc1Bus = Bus.audio(s);
	~osc2Bus = Bus.audio(s);
	~osc3Bus = Bus.audio(s);
	~noiseBus = Bus.audio(s);
	~mixBus = Bus.audio(s);
	~ampEnvBus = Bus.audio(s);
	~filtBus = Bus.audio(s);
	~sigGrp = Group(s);
	~oscGrp = Group(~sigGrp);

	s.sync;




	/////////////////////////SYNTHDEFS///////////////////////////







	SynthDef(\osc, {
		arg shape=0, freq=60.midicps, amp=1, out, oct=0, semi=0, fine=0, width=0.5, lag=0.0;
		var wave, sig, pitch;
		pitch = ((12*oct)+semi+fine).midiratio*freq;
		pitch = Lag.kr(pitch, lag);
		wave = [
			SinOsc.ar(pitch),
			VarSaw.ar(pitch),
			Saw.ar(pitch),
			Pulse.ar(pitch, width)
		];
		sig = SelectX.ar(shape, wave);
		sig = (sig*amp)/4;
		Out.ar(out, sig);
	}).add;

	SynthDef(\noise, {
		arg noiseSel=0, amp=0, out;
		var noiseArray, sig;
		noiseArray = [
			WhiteNoise.ar,
			PinkNoise.ar,
		];
		sig = Select.ar(noiseSel, noiseArray);
		sig = (sig*amp)/4;
		Out.ar(out, sig);
	}).add;

	SynthDef(\envMix, {
		arg in1, in2, in3, in4, amp=0.5, out, atk=0.01, dec=0.3, sus=0.5, rel=1.0, gate=0, curve=0, aud=1, chans=1;
		var sig, env, osc1, osc2, osc3, noise;
		osc1 = In.ar(~osc1Bus.index);
		osc2 = In.ar(~osc2Bus.index);
		osc3 = In.ar(~osc3Bus.index);
		noise = In.ar(~noiseBus.index);
		sig = Mix.ar([osc1, osc2, osc3, noise]);
		env = EnvGen.ar(Env.adsr(atk, dec, sus, rel, curve: curve), gate);
		sig = sig*env*aud*amp;
		Out.ar(out, sig);
	}).add;

	SynthDef(\filter, {
		arg in, freq=1000, rq=1.0, filtSel=0, gate=0, scale=1.0, atk=0.01, dec=0.3, sus=0.5, rel=1.0, peak=0, out;
		var sig, env, filtArray, pitch;
		sig = In.ar(~mixBus.index);
		env = EnvGen.ar(Env.adsr(atk, dec, sus, rel, peak*12, curve), gate);
		pitch = (freq*(env.midiratio)).clip(20, 20000);
		filtArray = [
			RLPF.ar(sig, pitch, rq),
			RHPF.ar(sig, pitch, rq),
			BPF.ar(sig, pitch, rq)
		];
		sig = Select.ar(filtSel, filtArray);
		sig = LeakDC.ar(sig);
		sig = Pan2.ar(sig, 0.0);
		Out.ar(out, sig);
	}).add;

	s.sync;

	//////////CREATE SYNTHS/////////

	osc1Node = Synth(\osc, [\out, ~osc1Bus], ~oscGrp);
	osc2Node = Synth(\osc, [\out, ~osc2Bus], ~oscGrp);
	osc3Node = Synth(\osc, [\out, ~osc3Bus], ~oscGrp);
	noiseNode = Synth(\noise, [\out, ~noiseBus], ~sigGrp);
	mixNode = Synth(\envMix, [\out, ~mixBus], ~sigGrp, \addToTail);
	filtNode = Synth(\filter, [\out, 0, \in, ~mixBus.index], s, \addToTail);


	s.sync;


	/////////////////////////GUI WINDOW/////////////////////////





	win = Window("Subtractive Synth", Rect(winX,winY,winWidth,winHeight)).front
	.background_(Color.white)
	.onClose_({s.freeAll;
		MIDIdef.freeAll;
		s.freeAllBuffers;
	});


Knob.defaultMode_(\vert);


	/////////////////////////MIXER//////////////////////////////






	mixGUI = View(win, Rect(mixGUIx,mixGUIy,mixGUIwidth,mixGUIheight))
	.background_(Color.grey(greyness));

	masterKnob = Knob(mixGUI, Rect(mixGUIwidth-masterKnobSize/2,masterKnobY,masterKnobSize,masterKnobSize))
	.value_(0.5)
	.action_({
		masterValBox.value = masterKnob.value.ampdb;
		mixNode.set(\amp, masterKnob.value)
	});

	mixMuteButton = Button(mixGUI, Rect(mixMuteButtonX, mixMuteButtonY, mixMuteButtonWidth, mixMuteButtonHeight))
	.states_([
		["MUTE", Color.white, Color.red(0.8)],
		["UN
MUTE", Color.white, Color.green(0.8)]
	])
	.font_(Font(size:12))
	.action_({mixNode.set(\aud, [1,0]@mixMuteButton.value)});

	StaticText(mixGUI, Rect(0,260,mixGUIwidth,20))
	.string_("Mix Level")
	.align_(\center);

	masterValBox = NumberBox(mixGUI, Rect(mixGUIwidth-masterValBoxWidth/2,277,masterValBoxWidth,masterValBoxHeight))
	.value_(0.5.ampdb)
	.align_(\center)
	.maxDecimals_(2)
	.action_({
		var val = masterValBox.value.dbamp;
		masterKnob.value = val;
		mixNode.set(\amp, val)
	})
	.clipHi_(0);

	mixGUI.decorator_(FlowLayout(mixGUI.bounds, 10@0, 20@2));

	StaticText(mixGUI, 30@20)
	.string_("OSC1")
	.align_(\center)
	.font_(Font(size:10, bold:true));

	StaticText(mixGUI, 30@20)
	.string_("OSC2")
	.align_(\center)
	.font_(Font(size:10, bold:true));

	StaticText(mixGUI, 30@20)
	.string_("OSC3")
	.align_(\center)
	.font_(Font(size:10, bold:true));

	StaticText(mixGUI, 30@20)
	.string_("Noise")
	.align_(\center)
	.font_(Font(size:10, bold:true));

	mixGUI.decorator_(FlowLayout(mixGUI.bounds, 10@16, 20@9));

	~mixVal1 = NumberBox(mixGUI, sliderValWidth@sliderValHeight)
	.value_(1)
	.align_(\center)
	.font_(Font(size:10))
	.action_({
		mixSlider1.value_(~mixVal1.value);
		osc1Node.set(\amp, ~mixVal1.value);
	})
	.clipLo_(0)
	.clipHi_(1)
	.scroll_step_(0.1)
	.shift_scale_(100)
	.ctrl_scale_(10);

	~mixVal2 = NumberBox(mixGUI, sliderValWidth@sliderValHeight)
	.value_(1)
	.align_(\center)
	.font_(Font(size:10))
	.action_({
		mixSlider2.value_(~mixVal2.value);
		osc2Node.set(\amp, ~mixVal2.value);
	})
	.clipLo_(0)
	.clipHi_(1)
	.scroll_step_(0.1)
	.shift_scale_(100)
	.ctrl_scale_(10);

	~mixVal3 = NumberBox(mixGUI, sliderValWidth@sliderValHeight)
	.value_(1)
	.align_(\center)
	.font_(Font(size:10))
	.action_({
		mixSlider3.value_(~mixVal3.value);
		osc3Node.set(\amp, ~mixVal3.value);
	})
	.clipLo_(0)
	.clipHi_(1)
	.scroll_step_(0.1)
	.shift_scale_(100)
	.ctrl_scale_(10);

	~mixVal4 = NumberBox(mixGUI, sliderValWidth@sliderValHeight)
	.value_(0)
	.align_(\center)
	.font_(Font(size:10))
	.action_({
		mixSlider4.value_(~mixVal4.value);
		noiseNode.set(\amp, ~mixVal4.value);
	})
	.clipLo_(0)
	.clipHi_(1)
	.scroll_step_(0.1)
	.shift_scale_(100)
	.ctrl_scale_(10);

	mixGUI.decorator_(FlowLayout(mixGUI.bounds, 15@30, 30@20));

	mixSlider1 = Slider(mixGUI, sliderWidth@sliderHeight)
	.value_(~mixVal1.value)
	.step_(0.01)
	.shift_scale_(100)
	.ctrl_scale_(10)
	.action_({
		~mixVal1.value_(mixSlider1.value);
		osc1Node.set(\amp, ~mixVal1.value);
	});

	mixSlider2 = Slider(mixGUI, sliderWidth@sliderHeight)
	.value_(~mixVal2.value)
	.step_(0.01)
	.shift_scale_(100)
	.ctrl_scale_(10)
	.action_({
		~mixVal2.value_(mixSlider2.value);
		osc2Node.set(\amp, ~mixVal2.value);
	});

	mixSlider3 = Slider(mixGUI, sliderWidth@sliderHeight)
	.value_(~mixVal3.value)
	.step_(0.01)
	.shift_scale_(100)
	.ctrl_scale_(10)
	.action_({
		~mixVal3.value_(mixSlider3.value);
		osc3Node.set(\amp, ~mixVal3.value);
	});

	mixSlider4 = Slider(mixGUI, sliderWidth@sliderHeight)
	.value_(~mixVal4.value)
	.step_(0.01)
	.shift_scale_(100)
	.ctrl_scale_(10)
	.action_({
		~mixVal4.value_(mixSlider4.value);
		noiseNode.set(\amp, ~mixVal4.value);
	});






	/////////////////////////ENV GEN//////////////////////////////






	envGUI = View(win, Rect(envGUIx,envGUIy,envGUIwidth,envGUIheight))
	.background_(Color.grey(greyness));
	envGUI.decorator_(FlowLayout(envGUI.bounds));
	envWidget=EnvelopeView(envGUI,Rect(4,4,192,100));
	envWidget.setEnv(Env.adsr(curve:0))
	.keepHorizontalOrder_(true)
	.editable_(false)
	.drawRects_(false);

	~ampEnvCurveSlider=Slider(envGUI, 192@15)
	.value_(0.5)
	.action_({
		var val;
		val = ~ampEnvCurveSlider.value.linlin(0.0,1.0,-4.0,4.0);
		envWidget.curves_(val);
		mixNode.set(\curve, val);
	});

	envGUI.decorator_(FlowLayout(envGUI.bounds, 15@128, 30@20));

	atk=0.01;
	dec=0.3;
	sus=0.5;
	rel=1.0;
	curve=0.0;

	aSlidVal=atk.explin(0.001,10.0,0.0,1.0);
	dSlidVal=dec.explin(0.001,10.0,0.0,1.0);
	rSlidVal=rel.explin(0.001,10.0,0.0,1.0);

	~ampEnvASlider = Slider(envGUI, 20@130)
	.value_(aSlidVal)
	.action_({
		var val;
		val = ~ampEnvASlider.value.linexp(0.0,1.0,0.001,10.0);
		envWidget
		.setEnv(Env.adsr(~envMap.map(~ampEnvASlider.value), ~envMap.map(~ampEnvDSlider.value), ~ampEnvSSlider.value, ~envMap.map(~ampEnvRSlider.value), curve:~curveMap.map(~ampEnvCurveSlider.value)));
		~ampEnvAVal.value_(val.round(0.001));
		mixNode.set(\atk, val);
	});

	~ampEnvDSlider = Slider(envGUI, 20@130)
	.value_(dSlidVal)
	.action_({
		var val;
		val = ~ampEnvDSlider.value.linexp(0.0,1.0,0.001,10.0);
		envWidget
		.setEnv(Env.adsr(~envMap.map(~ampEnvASlider.value), ~envMap.map(~ampEnvDSlider.value), ~ampEnvSSlider.value, ~envMap.map(~ampEnvRSlider.value), curve:~curveMap.map(~ampEnvCurveSlider.value)));
		~ampEnvDVal.value_(val.round(0.001));
		mixNode.set(\dec, val);
	});

	~ampEnvSSlider = Slider(envGUI, 20@130)
	.value_(sus)
	.action_({
		var val;
		val = ~ampEnvSSlider.value;
		envWidget
		.setEnv(Env.adsr(~envMap.map(~ampEnvASlider.value), ~envMap.map(~ampEnvDSlider.value), ~ampEnvSSlider.value, ~envMap.map(~ampEnvRSlider.value), curve:~curveMap.map(~ampEnvCurveSlider.value)));
		~ampEnvSVal.value_(~ampEnvSSlider.value.round(0.01));
		mixNode.set(\sus, val);
	});

	~ampEnvRSlider = Slider(envGUI, 20@130)
	.value_(rSlidVal.explin(0.001,10.0,0.0,1.0))
	.action_({
		var val;
		val = ~ampEnvRSlider.value.linexp(0.0,1.0,0.001,10.0);
		envWidget
		.setEnv(Env.adsr(~envMap.map(~ampEnvASlider.value), ~envMap.map(~ampEnvDSlider.value), ~ampEnvSSlider.value, ~envMap.map(~ampEnvRSlider.value), curve:~curveMap.map(~ampEnvCurveSlider.value)));
		~ampEnvRVal.value_(val.round(0.001));
		mixNode.set(\rel, val);
	});

	envGUI.decorator_(FlowLayout(envGUI.bounds, 7@262, 15@20));

	~ampEnvAVal=NumberBox(envGUI, 35@15)
	.string_(atk)
	.font_(Font(size:10))
	.align_(\center)
	.maxDecimals_(3).action_({
		var val, slidVal;
		val=~ampEnvAVal.value;
		slidVal=val.explin(0.001,10.0,0.0,1.0);
		~ampEnvASlider.valueAction_(slidVal);
		mixNode.set(\atk, val);
	})
	.clipLo_(0.001)
	.clipHi_(10.0);

	~ampEnvDVal=NumberBox(envGUI, 35@15)
	.value_(dec)
	.font_(Font(size:10))
	.align_(\center).maxDecimals_(3).action_({
		var val, slidVal;
		val=~ampEnvDVal.value;
		slidVal=val.explin(0.001,10.0,0.0,1.0);
		~ampEnvDSlider.valueAction_(slidVal);
		mixNode.set(\dec, val);
	})
	.clipLo_(0.001)
	.clipHi_(10.0);

	~ampEnvSVal=NumberBox(envGUI, 35@15)
	.value_(sus)
	.font_(Font(size:10))
	.align_(\center)
	.maxDecimals_(2).action_({
		var val;
		val=~ampEnvSVal.value;
		~ampEnvSSlider.valueAction_(val);
		mixNode.set(\sus, val);
	})
	.clipLo_(0.0)
	.clipHi_(1.0);

	~ampEnvRVal=NumberBox(envGUI, 35@15).value_(rel)
	.font_(Font(size:10))
	.align_(\center)
	.maxDecimals_(3)
	.action_({
		var val, slidVal;
		val=~ampEnvRVal.value;
		slidVal=val.explin(0.001,10.0,0.0,1.0);
		~ampEnvRSlider.valueAction_(slidVal);
		mixNode.set(\rel, val);
	})
	.clipLo_(0.001)
	.clipHi_(10.0);

	envGUI.decorator_(FlowLayout(envGUI.bounds, 12@285, 30@20));

	StaticText(envGUI, 21@10).string_("Atk").font_(Font(size:11, bold:true)).align_(\center);
	StaticText(envGUI, 21@10).string_("Dec").font_(Font(size:11, bold:true)).align_(\center);
	StaticText(envGUI, 21@10).string_("Sus").font_(Font(size:11, bold:true)).align_(\center);
	StaticText(envGUI, 21@10).string_("Rel").font_(Font(size:11, bold:true)).align_(\center);

	// buttonGUI = View(win, Rect(830, 20, 50, 50))
	// .background_(Color.white);
	// gateButton = Button(buttonGUI, Rect(2,2,46,46))
	// .states_([["Gate", Color.black, Color.green], ["Gate", Color.black, Color.red]])
	// .value_(0)
	// .action_({
	// 	mixNode.set(\gate, gateButton.value);
	// 	filtNode.set(\gate, gateButton.value)
	// });





	//////////////////////OSCILLATORS////////////////////////////




	guiXs = Array.fill(3, {
		arg i;
		oscMargin+(oscGUIwidth+oscMargin*i)
	});


	osc1GUI = View(win, Rect(oscMargin,osc1GUIy,oscGUIwidth,oscGUIheight))
	.background_(Color.grey(greyness));

	osc2GUI = View(win, Rect(guiXs.at(1),osc1GUIy,oscGUIwidth,oscGUIheight))
	.background_(Color.grey(greyness));

	osc3GUI = View(win, Rect(guiXs.at(2),osc1GUIy,oscGUIwidth,oscGUIheight))
	.background_(Color.grey(greyness));

	//Control Spec Map

	octSlideMap = ControlSpec(1, 108, \lin, 12);
	octNumMap = ControlSpec(0, 8, \lin, 1);
	semiMap = ControlSpec(-11, 11, \lin);
	fineMap = ControlSpec(-0.99, 0.99, \lin, 0.01);

	//Freq Display

	osc1freqDisp = StaticText(osc1GUI, Rect(freqDispX, freqDispY, oscGUIwidth-(freqDispX*2), freqDispSize))
	.string_(60.midicps.round(0.01))
	.background_(Color.grey(0.9))
	.align_(\center)
	.font_(Font(size:48));

	osc2freqDisp = StaticText(osc2GUI, Rect(freqDispX, freqDispY, oscGUIwidth-(freqDispX*2), freqDispSize))
	.string_(60.midicps.round(0.01))
	.background_(Color.grey(0.9))
	.align_(\center)
	.font_(Font(size:48));

	osc3freqDisp = StaticText(osc3GUI, Rect(freqDispX, freqDispY, oscGUIwidth-(freqDispX*2), freqDispSize))
	.string_(60.midicps.round(0.01))
	.background_(Color.grey(0.9))
	.align_(\center)
	.font_(Font(size:48));

	//Pitch Sliders

	View(osc1GUI, Rect(48, 155, 120, 1))
	.background_(Color.black);
	View(osc2GUI, Rect(48, 155, 120, 1))
	.background_(Color.black);
	View(osc3GUI, Rect(48, 155, 120, 1))
	.background_(Color.black);

	///OSC1

	osc1SliderFlow = FlowView(osc1GUI, Rect(0, oscSliderFlowY, oscGUIwidth, oscSliderFlowHeight+10), oscSliderMargin@0, oscSliderGap@0);

	oct1Slider=Slider(osc1SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.step_(1/8)
	.action_({
		osc1freqDisp.string = ((octNumMap.map(oct1Slider.value).octcps) * (semiMap.map(semi1Slider.value).midiratio) * (fineMap.map(fine1Slider.value).midiratio)).round(0.01);
		~osc1OctVal.value = octNumMap.map(oct1Slider.value).round(0.01);
		osc1Node.set(\oct, ~octaveMap.map(oct1Slider.value), \semi, semiMap.map(semi1Slider.value), \fine, fineMap.map(fine1Slider.value));
	});

	semi1Slider=Slider(osc1SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.step_(1/22)
	.action_({
		osc1freqDisp.string = ((octNumMap.map(oct1Slider.value).octcps) * (semiMap.map(semi1Slider.value).midiratio) * (fineMap.map(fine1Slider.value).midiratio)).round(0.01);
		~osc1SemiVal.value = semiMap.map(semi1Slider.value);
		osc1Node.set(\oct, ~octaveMap.map(oct1Slider.value), \semi, semiMap.map(semi1Slider.value), \fine, fineMap.map(fine1Slider.value));
	});

	fine1Slider=Slider(osc1SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.action_({
		osc1freqDisp.string = ((octNumMap.map(oct1Slider.value).octcps) * (semiMap.map(semi1Slider.value).midiratio) * (fineMap.map(fine1Slider.value).midiratio)).round(0.01);
		~osc1FineVal.value = fineMap.map(fine1Slider.value);
		osc1Node.set(\oct, ~octaveMap.map(oct1Slider.value), \semi, semiMap.map(semi1Slider.value), \fine, fineMap.map(fine1Slider.value));
	});

	~osc1NumFlow = FlowView(osc1GUI, Rect(0, 219, oscGUIwidth, oscSliderFlowHeight+10), 23@0, 27@0);

	~osc1OctVal=NumberBox(~osc1NumFlow, 32@15)
	.value_(4)
	.font_(Font(size:10))
	.align_(\center)
	.clipHi_(8)
	.clipLo_(0)
	.action_({
		oct1Slider.valueAction = ~osc1OctVal.value/8;
	});

	~osc1SemiVal=NumberBox(~osc1NumFlow, 32@15)
	.value_(0)
	.font_(Font(size:10))
	.align_(\center)
	.action_({
		semi1Slider.valueAction = semiMap.unmap(~osc1SemiVal.value);
	});

	~osc1FineVal=NumberBox(~osc1NumFlow, 32@15)
	.value_(0)
	.font_(Font(size:10))
	.step_(0.01)
	.align_(\center)
	.action_({
		fine1Slider.valueAction = fineMap.unmap(~osc1FineVal.value);
	});

	~osc1NumFlow.startRow;

	StaticText(~osc1NumFlow, 32@15)
	.string_("OCT")
	.font_(Font(size:10))
	.align_(\center);

	StaticText(~osc1NumFlow, 32@15)
	.string_("SEMI")
	.font_(Font(size:10))
	.align_(\center);

	StaticText(~osc1NumFlow, 32@15)
	.string_("FINE")
	.font_(Font(size:10))
	.align_(\center);


	///OSC2


	osc2SliderFlow = FlowView(osc2GUI, Rect(0, oscSliderFlowY, oscGUIwidth, oscSliderFlowHeight+10), oscSliderMargin@0, oscSliderGap@0);

	oct2Slider=Slider(osc2SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.step_(1/8)
	.action_({
		osc2freqDisp.string = ((octNumMap.map(oct2Slider.value).octcps) * (semiMap.map(semi2Slider.value).midiratio) * (fineMap.map(fine2Slider.value).midiratio)).round(0.01);
		~osc2OctVal.value = octNumMap.map(oct2Slider.value);
		osc2Node.set(\oct, ~octaveMap.map(oct2Slider.value), \semi, semiMap.map(semi2Slider.value), \fine, fineMap.map(fine2Slider.value));
	});

	semi2Slider=Slider(osc2SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.step_(1/22)
	.action_({
		osc2freqDisp.string = ((octNumMap.map(oct2Slider.value).octcps) * (semiMap.map(semi2Slider.value).midiratio) * (fineMap.map(fine2Slider.value).midiratio)).round(0.01);
		~osc2SemiVal.value = semiMap.map(semi2Slider.value);
		osc2Node.set(\oct, ~octaveMap.map(oct2Slider.value), \semi, semiMap.map(semi2Slider.value), \fine, fineMap.map(fine2Slider.value));
	});

	fine2Slider=Slider(osc2SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.action_({
		osc2freqDisp.string = ((octNumMap.map(oct2Slider.value).octcps) * (semiMap.map(semi2Slider.value).midiratio) * (fineMap.map(fine2Slider.value).midiratio)).round(0.01);
		~osc2FineVal.value = fineMap.map(fine2Slider.value);
		osc2Node.set(\oct, ~octaveMap.map(oct2Slider.value), \semi, semiMap.map(semi2Slider.value), \fine, fineMap.map(fine2Slider.value));
	});

	~osc2NumFlow = FlowView(osc2GUI, Rect(0, 219, oscGUIwidth, oscSliderFlowHeight+10), 23@0, 27@0);

	~osc2OctVal=NumberBox(~osc2NumFlow, 32@15)
	.string_(4)
	.font_(Font(size:10))
	.align_(\center)
	.clipHi_(8)
	.clipLo_(0)
	.action_({
		oct2Slider.valueAction = ~osc2OctVal.value/8;
	});

	~osc2SemiVal=NumberBox(~osc2NumFlow, 32@15)
	.value_(0)
	.font_(Font(size:10))
	.align_(\center)
	.action_({
		semi2Slider.valueAction = semiMap.unmap(~osc2SemiVal.value);
	});

	~osc2FineVal=NumberBox(~osc2NumFlow, 32@15)
	.value_(0)
	.font_(Font(size:10))
	.step_(0.01)
	.align_(\center)
	.action_({
		fine2Slider.valueAction = fineMap.unmap(~osc2FineVal.value);
	});

	~osc2NumFlow.startRow;

	StaticText(~osc2NumFlow, 32@15)
	.string_("OCT")
	.font_(Font(size:10))
	.align_(\center);

	StaticText(~osc2NumFlow, 32@15)
	.string_("SEMI")
	.font_(Font(size:10))
	.align_(\center);

	StaticText(~osc2NumFlow, 32@15)
	.string_("FINE")
	.font_(Font(size:10))
	.align_(\center);

	///OSC3

	osc3SliderFlow = FlowView(osc3GUI, Rect(0, oscSliderFlowY, oscGUIwidth, oscSliderFlowHeight+10), oscSliderMargin@0, oscSliderGap@0);

	oct3Slider=Slider(osc3SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.step_(1/8)
	.action_({
		osc3freqDisp.string = ((octNumMap.map(oct3Slider.value).octcps) * (semiMap.map(semi3Slider.value).midiratio) * (fineMap.map(fine3Slider.value).midiratio)).round(0.01);
		~osc3OctVal.value = octNumMap.map(oct3Slider.value);
		osc3Node.set(\oct, ~octaveMap.map(oct3Slider.value), \semi, semiMap.map(semi3Slider.value), \fine, fineMap.map(fine3Slider.value));
	});

	semi3Slider=Slider(osc3SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.step_(1/22)
	.action_({
		osc3freqDisp.string = ((octNumMap.map(oct3Slider.value).octcps) * (semiMap.map(semi3Slider.value).midiratio) * (fineMap.map(fine3Slider.value).midiratio)).round(0.01);
		~osc3SemiVal.value = semiMap.map(semi3Slider.value);
		osc3Node.set(\oct, ~octaveMap.map(oct3Slider.value), \semi, semiMap.map(semi3Slider.value), \fine, fineMap.map(fine3Slider.value));
	});

	fine3Slider=Slider(osc3SliderFlow, oscPitchSliderSize)
	.value_(0.5)
	.action_({
		osc3freqDisp.string = ((octNumMap.map(oct3Slider.value).octcps) * (semiMap.map(semi3Slider.value).midiratio) * (fineMap.map(fine3Slider.value).midiratio)).round(0.01);
		~osc3FineVal.value = fineMap.map(fine3Slider.value);
		osc3Node.set(\oct, ~octaveMap.map(oct3Slider.value), \semi, semiMap.map(semi3Slider.value), \fine, fineMap.map(fine3Slider.value));
	});

	~osc3NumFlow = FlowView(osc3GUI, Rect(0, 219, oscGUIwidth, oscSliderFlowHeight+10), 23@0, 27@0);

	~osc3OctVal=NumberBox(~osc3NumFlow, 32@15)
	.value_(4)
	.font_(Font(size:10))
	.align_(\center)
	.clipHi_(8)
	.clipLo_(0)
	.action_({
		oct3Slider.valueAction = ~osc3OctVal.value/8;
	});

	~osc3SemiVal=NumberBox(~osc3NumFlow, 32@15)
	.value_(0)
	.font_(Font(size:10))
	.align_(\center)
	.action_({
		semi3Slider.valueAction = semiMap.unmap(~osc3SemiVal.value);
	});

	~osc3FineVal=NumberBox(~osc3NumFlow, 32@15)
	.value_(0)
	.font_(Font(size:10))
	.step_(0.01)
	.align_(\center)
	.action_({
		fine3Slider.valueAction = fineMap.unmap(~osc3FineVal.value);
	});

	~osc3NumFlow.startRow;

	StaticText(~osc3NumFlow, 32@15)
	.string_("OCT")
	.font_(Font(size:10))
	.align_(\center);

	StaticText(~osc3NumFlow, 32@15)
	.string_("SEMI")
	.font_(Font(size:10))
	.align_(\center);

	StaticText(~osc3NumFlow, 32@15)
	.string_("FINE")
	.font_(Font(size:10))
	.align_(\center);

	//Shape Slider

	~osc1ShapeSlider = Slider(osc1GUI, Rect(oscGUIwidth-oscSliderSize/2, shapeSliderY, oscSliderSize, shapeSliderHeight))
	.step_(0.01)
	.shift_scale_(100/3)
	.value_(0)
	.action_({
		osc1Node.set(\shape, ~osc1ShapeSlider.value*3)
	});

	~osc2ShapeSlider = Slider(osc2GUI, Rect(oscGUIwidth-oscSliderSize/2, shapeSliderY, oscSliderSize, shapeSliderHeight))
	.step_(0.01)
	.shift_scale_(100/3)
	.value_(0)
	.action_({
		osc2Node.set(\shape, ~osc2ShapeSlider.value*3
	)});

	~osc3ShapeSlider = Slider(osc3GUI, Rect(oscGUIwidth-oscSliderSize/2, shapeSliderY, oscSliderSize, shapeSliderHeight))
	.step_(0.01)
	.shift_scale_(100/3)
	.value_(0)
	.action_({
		osc3Node.set(\shape, ~osc3ShapeSlider.value*3)
	});

	//Shape Label

	osc1ShapeLabel = StaticText(osc1GUI, Rect(0, shapeLabelY, oscGUIwidth, oscSliderLabelHeight))
	.string_("Shape")
	.font_(Font(size:12))
	.align_(\center);

	osc2ShapeLabel = StaticText(osc2GUI, Rect(0, shapeLabelY, oscGUIwidth, oscSliderLabelHeight))
	.string_("Shape")
	.font_(Font(size:12))
	.align_(\center);

	osc1ShapeLabel = StaticText(osc3GUI, Rect(0, shapeLabelY, oscGUIwidth, oscSliderLabelHeight))
	.string_("Shape")
	.font_(Font(size:12))
	.align_(\center);

	//PW Slider

	~osc1WidthSlider = Slider(osc1GUI, Rect(oscGUIwidth-oscSliderSize/2, widthSliderY, oscSliderSize, shapeSliderHeight))
	.value_(0.5)
	.action_({
		osc1Node.set(\width, ~osc1WidthSlider.value.linlin(0.0,1.0,0.01,0.99);
	)});

	~osc2WidthSlider = Slider(osc2GUI, Rect(oscGUIwidth-oscSliderSize/2, widthSliderY, oscSliderSize, shapeSliderHeight))
	.value_(0.5)
	.action_({
		osc2Node.set(\width, ~osc2WidthSlider.value.linlin(0.0,1.0,0.01,0.99);
	)});

	~osc3WidthSlider = Slider(osc3GUI, Rect(oscGUIwidth-oscSliderSize/2, widthSliderY, oscSliderSize, shapeSliderHeight))
	.value_(0.5)
	.action_({
		osc3Node.set(\width, ~osc3WidthSlider.value.linlin(0.0,1.0,0.01,0.99);
	)});

	//PW Label

	osc1WidthLabel = StaticText(osc1GUI, Rect(0, widthLabelY, oscGUIwidth, oscSliderLabelHeight))
	.string_("Pulse Width")
	.font_(Font(size:12))
	.align_(\center);

	osc2WidthLabel = StaticText(osc2GUI, Rect(0, widthLabelY, oscGUIwidth, oscSliderLabelHeight))
	.string_("Pulse Width")
	.font_(Font(size:12))
	.align_(\center);

	osc1WidthLabel = StaticText(osc3GUI, Rect(0, widthLabelY, oscGUIwidth, oscSliderLabelHeight))
	.string_("Pulse Width")
	.font_(Font(size:12))
	.align_(\center);







	////////////////////////FILTER/////////////////////////////









	filtGUI = View(win, Rect(filtGUIx,filtGUIy,filtGUIwidth,filtGUIheight))
	.background_(Color.grey(greyness));

	~cutoffKnob=Knob(filtGUI, Rect(filtGUIwidth-cutoffKnobSize/2, cutoffKnobY, cutoffKnobSize, cutoffKnobSize))
	.value_(~filterMap.unmap(1000))
	.action_({
		~cutoffVal.value = ~filterMap.map(~cutoffKnob.value);
		filtNode.set(\freq, ~filterMap.map(~cutoffKnob.value))
	});

	~cutoffVal = NumberBox(filtGUI, Rect(filtGUIwidth-108/2, 170, 108, 20))
	.value_(1000)
	.clipHi_(20000)
	.clipLo_(20)
	.decimals_(2)
	.align_(\center)
	.action_({
		~cutoffKnob.value = ~filterMap.unmap(~cutoffVal.value);
		filtNode.set(\freq, ~filterMap.map(~cutoffKnob.value))
	});

	resKnob=Knob(filtGUI, Rect(filtGUIwidth-resKnobSize/2, resKnobY, resKnobSize, resKnobSize))
	.value_(0)
	.action_({
		~resVal.value = resKnob.value;
		filtNode.set(\rq, ~resMap.unmap(resKnob.value))
	});

	~resVal = NumberBox(filtGUI, Rect(filtGUIwidth-40/2, 256, 40, 20))
	.value_(0.0)
	.decimals_(2)
	.clipHi_(1.0)
	.clipLo_(0.01)
	.align_(\center)
	.action_({
		resKnob.value = ~resVal.value;
		filtNode.set(\rq, ~resMap.unmap(~resVal.value));
	});

	filtSelectWidget = PopUpMenu(filtGUI, Rect(filtGUIwidth-90/2, filtSelectY, 90, 20))
	.items_(["Lowpass", "Highpass", "Bandpass"])
	.action_({
		filtNode.set(\filtSel, filtSelectWidget.value)
	});




	///////////////////////////////FILTER ENV////////////////////////////////////




	filtEnvGUI = View(win, Rect(filtEnvGUIx,filtEnvGUIy,filtEnvGUIwidth,filtEnvGUIheight))
	.background_(Color.grey(greyness));

	~filtEnvCurveSlider=Slider(filtEnvGUI, Rect(4, 108, 192, 15))
	.value_(0.5)
	.action_({
		filtEnvWidget.curves_(~curveMap.map(~filtEnvCurveSlider.value));
		filtNode.set(\curve, ~curveMap.map(~filtEnvCurveSlider.value));
	});

	~filtEnvKnob = Knob(filtEnvGUI, Rect(200+(220-mulKnobSize/2), 310-mulKnobSize/2, mulKnobSize, mulKnobSize))
	.value_(0.5)
	.step_(0.01)
	.shift_scale_(50)
	.alt_scale_(0.05)
	.action_({
		filtNode.set(\peak, ~filtCVMap.map(~filtEnvKnob.value));
		~filtCVVal.value_(~filtCVMap.map(~filtEnvKnob.value));
	});

	~filtCVVal = NumberBox(filtEnvGUI, Rect(200+(220-60/2), 240, 60, 20))
	.value_(0.5)
	.align_(\center)
	.decimals_(2)
	.action_({
		~filtEnvKnob.valueAction_(~filtCVMap.unmap(~filtCVVal.value));
	});

	filtEnvGUI.decorator_(FlowLayout(Rect(filtEnvGUIx, filtEnvGUIy, 200, 310)));


	filtEnvWidget=EnvelopeView(filtEnvGUI,Rect(4,4,192,100))
	.setEnv(Env.adsr(curve:0))
	.keepHorizontalOrder_(true)
	.editable_(false)
	.drawRects_(false);


	filtEnvGUI.decorator_(FlowLayout(filtEnvGUI.bounds, 15@128, 30@20));


	filtEnvASlider = Slider(filtEnvGUI, 20@130)
	.value_(~envMap.unmap(0.01))
	.action_({
		var val;
		val = ~envMap.map(filtEnvASlider.value);
		filtEnvWidget
		.setEnv(Env.adsr(~envMap.map(filtEnvASlider.value), ~envMap.map(filtEnvDSlider.value), filtEnvSSlider.value, ~envMap.map(filtEnvRSlider.value), curve:~curveMap.map(~filtEnvCurveSlider.value)));
		~filtEnvAVal.value = val;
		filtNode.set(\atk, val);
	});

	filtEnvDSlider = Slider(filtEnvGUI, 20@130)
	.value_(~envMap.unmap(0.3))
	.action_({
		var val;
		val = ~envMap.map(filtEnvDSlider.value);
		filtEnvWidget.setEnv(Env.adsr(~envMap.map(filtEnvASlider.value), ~envMap.map(filtEnvDSlider.value), filtEnvSSlider.value, ~envMap.map(filtEnvRSlider.value), curve:~curveMap.map(~filtEnvCurveSlider.value)));
		~filtEnvDVal.value_(val);
		filtNode.set(\dec, val);
	});

	filtEnvSSlider = Slider(filtEnvGUI, 20@130)
	.value_(0.5)
	.action_({
		var val;
		val = filtEnvSSlider.value;
		filtEnvWidget.setEnv(Env.adsr(~envMap.map(filtEnvASlider.value), ~envMap.map(filtEnvDSlider.value), filtEnvSSlider.value, ~envMap.map(filtEnvRSlider.value), curve:~curveMap.map(~filtEnvCurveSlider.value)));
		~filtEnvSVal.value_(filtEnvSSlider.value);
		filtNode.set(\sus, val);
	});

	filtEnvRSlider = Slider(filtEnvGUI, 20@130)
	.value_(~envMap.unmap(1.0))
	.action_({
		var val;
		val = ~envMap.map(filtEnvRSlider.value);
		filtEnvWidget.setEnv(Env.adsr(~envMap.map(filtEnvASlider.value), ~envMap.map(filtEnvDSlider.value), filtEnvSSlider.value, ~envMap.map(filtEnvRSlider.value), curve:~curveMap.map(~filtEnvCurveSlider.value)));
		~filtEnvRVal.value_(val);
		filtNode.set(\rel, val);
	});

	filtEnvGUI.decorator_(FlowLayout(filtEnvGUI.bounds, 7@262, 15@20));

	~filtEnvAVal=NumberBox(filtEnvGUI, 35@15)
	.value_(0.01)
	.font_(Font(size:10))
	.align_(\center)
	.maxDecimals_(3)
	.clipLo_(0.001)
	.clipHi_(10.0)
	.action_({
		var val, slidVal;
		val=~filtEnvAVal.value;
		slidVal=~envMap.unmap(val);
		filtEnvASlider.valueAction_(slidVal);
	});

	~filtEnvDVal=NumberBox(filtEnvGUI, 35@15)
	.value_(0.3)
	.font_(Font(size:10))
	.align_(\center)
	.maxDecimals_(3)
	.clipLo_(0.001)
	.clipHi_(10.0)
	.action_({
		var val, slidVal;
		val=~filtEnvDVal.value;
		slidVal=~envMap.unmap(val);
		filtEnvDSlider.valueAction_(slidVal);
	});

	~filtEnvSVal=NumberBox(filtEnvGUI, 35@15)
	.value_(0.5)
	.font_(Font(size:10))
	.align_(\center)
	.clipLo_(0.0)
	.clipHi_(1.0)
	.maxDecimals_(2).action_({
		var val;
		val=~filtEnvSVal.value;
		filtEnvSSlider.valueAction_(val);
	});

	~filtEnvRVal=NumberBox(filtEnvGUI, 35@15)
	.value_(1.0)
	.font_(Font(size:10))
	.align_(\center)
	.maxDecimals_(3)
	.clipLo_(0.001)
	.clipHi_(10.0)
	.action_({
		var val, slidVal;
		val=~filtEnvRVal.value;
		slidVal=~envMap.unmap(val);
		filtEnvRSlider.valueAction_(slidVal);
	});

	filtEnvGUI.decorator_(FlowLayout(filtEnvGUI.bounds, 12@285, 30@20));

	StaticText(filtEnvGUI, 21@10).string_("Atk").font_(Font(size:11, bold:true)).align_(\center);
	StaticText(filtEnvGUI, 21@10).string_("Dec").font_(Font(size:11, bold:true)).align_(\center);
	StaticText(filtEnvGUI, 21@10).string_("Sus").font_(Font(size:11, bold:true)).align_(\center);
	StaticText(filtEnvGUI, 21@10).string_("Rel").font_(Font(size:11, bold:true)).align_(\center);



	////////////////////////////SLEW LIMITER///////////////////////////////


	~slewMap = ControlSpec(0.0, 5.0, 4);


	~slewLimiterGUI = View(win, Rect(680, 90, 100, 240)).background_(Color.grey(greyness));
	~slewLimiter = Slider(~slewLimiterGUI, Rect(100-20/2, 15, 20, 160))
	.value_(0)
	.step_(0.001)
	.action_({
		~slewVal.value = ~slewMap.map(~slewLimiter.value);
		~sigGrp.set(\lag, ~slewMap.map(~slewLimiter.value));
	});
	~slewVal = NumberBox(~slewLimiterGUI, Rect(100-50/2, 185, 50, 20))
	.decimals_(3)
	.align_(\center)
	.action_({
		~slewLimiter.valueAction_(~slewMap.unmap(~slewVal.value));
	});

	StaticText(~slewLimiterGUI, Rect(100-80/2, 210, 80, 20))
	.string_("Slew Limiter")
	.align_(\center);



		////////////////////////////SLEW LIMITER///////////////////////////////

	~noiseGUI = View(win, Rect(680, 20, 100, 60)).background_(Color.grey(greyness));

	~noiseWidget = MultiSliderView(~noiseGUI, Rect(20, 20, 60, 30))
	.thumbSize_(27)
	.step_(1)
	.size_(1)
	.elasticMode_(0)
	.gap_(0)
	.indexIsHorizontal_(false)
	.background_(Color.grey(0.5))
	.colors_(Color.white,Color.white)
	.currentvalue_(0)
	.action_({
		var val, colors;
		val = ~noiseWidget.currentvalue;
		colors = [Color.white, Color.fromHexString("#ffcccc")];
		~noiseWidget.colors_(colors@val, colors@val);
		noiseNode.set(\noiseSel, val);
	});

	StaticText(~noiseGUI, Rect(0, 0, 100, 20))
	.string_("Noise")
	.align_(\center);

	StaticText(~noiseGUI, Rect(5, 25, 20, 20))
	.string_("W")
	.align_(\left);

	StaticText(~noiseGUI, Rect(72, 25, 20, 20))
	.string_("P")
	.align_(\right);




	s.sync;





	////////////////////////MIDI/////////////////////////





~ewi = -1951946844;
~touchbar = -607326372;

	MIDIdef.noteOn(\ewiNoteOn, {
					arg vel, num;
					osc1Node.set(\freq, num.midicps);
					osc2Node.set(\freq, num.midicps);
					osc3Node.set(\freq, num.midicps);
				});

	MIDIdef.cc(\breath, {
					arg val;
					mixNode.set(\gate, val);
					filtNode.set(\gate, val);
				});



	////////////////////////////Settings GUI///////////////////////////////




	~settingsGUI = View(win, Rect(800, 20, 300, 310)).background_(Color.grey(greyness));

	View(win, Rect(800, 60, 300, 10)).background_(Color.white);


	///MIDI select


	// ~midiSelect = PopUpMenu(~settingsGUI, Rect(10, 10, 100, 20))
	// .items_(["MIDI Source", "Keyboard", "EWI"]);


			////////////////////////////Presets///////////////////////////////



	~presets = PopUpMenu(~settingsGUI, Rect(70, 10, 220, 20))
	.items_(["Flashlight", "Stevie Bass", "Funkenstein", "Shine On"])
	.action_({
		var val;
		val = ~presets.value;
		[
			{
				~ampEnvCurveSlider.valueAction = 0;
				
				~ampEnvAVal.valueAction = 0.005;
				~ampEnvDVal.valueAction = 0.2;
				~ampEnvSSlider.valueAction = 0.6;
				~ampEnvRVal.valueAction = 0.1;
				
				~filtEnvCurveSlider.valueAction = 0;
				
				~filtEnvAVal.valueAction = 0.005;
				~filtEnvDVal.valueAction = 0.01;
				~filtEnvSVal.valueAction = 1;
				~filtEnvRVal.valueAction = 0.01;
				
				~filtCVVal.valueAction = 4.0;
				~cutoffVal.valueAction = 126;
				~resVal.valueAction = 0.8;
				
				~osc1ShapeSlider.valueAction=2/3;
				~osc2ShapeSlider.valueAction=2/3;
				~osc3ShapeSlider.valueAction=0;
				
				~osc1WidthSlider.valueAction=0.5;
				~osc2WidthSlider.valueAction=0.5;
				~osc3WidthSlider.valueAction=0.5;
				
				~mixVal1.valueAction = 1.0;
				~mixVal2.valueAction = 1.0;
				~mixVal3.valueAction = 0;
				~mixVal4.valueAction = 0;
				
				~slewVal.valueAction = 0.1;
				
				~osc1FineVal.valueAction = 0.15;
				~osc1SemiVal.valueAction = 0;
				~osc1OctVal.valueAction = 4;
				
				~osc2FineVal.valueAction = 0;
				~osc2SemiVal.valueAction = 0;
				~osc2OctVal.valueAction = 3;
				
				~osc3FineVal.valueAction = 0;
				~osc3SemiVal.valueAction = 0;
				~osc3OctVal.valueAction = 4;
				
			},
			{
				~ampEnvCurveSlider.valueAction = 0;
				
				~ampEnvAVal.valueAction = 0.05;
				~ampEnvDVal.valueAction = 0.058;
				~ampEnvSSlider.valueAction = 0.81;
				~ampEnvRVal.valueAction = 0.058;
				
				~filtEnvCurveSlider.valueAction = 0;
				
				~filtEnvAVal.valueAction = 0.6;
				~filtEnvDVal.valueAction = 0.6;
				~filtEnvSVal.valueAction = 0.9;
				~filtEnvRVal.valueAction = 0.6;
				
				~filtCVVal.valueAction = 6.0;
				~cutoffVal.valueAction = 261.63;
				~resVal.valueAction = 0.25;
				
				~osc1ShapeSlider.valueAction=2/3;
				~osc2ShapeSlider.valueAction=1/3;
				~osc3ShapeSlider.valueAction=0;
				
				~osc1WidthSlider.valueAction=0.5;
				~osc2WidthSlider.valueAction=0.5;
				~osc3WidthSlider.valueAction=0.5;
				
				~mixVal1.valueAction = 0.6;
				~mixVal2.valueAction = 0.4;
				~mixVal3.valueAction = 0;
				~mixVal4.valueAction = 0;
				
				~slewVal.valueAction = 0.1;
				
				~osc1FineVal.valueAction = 0;
				~osc1SemiVal.valueAction = 0;
				~osc1OctVal.valueAction = 4;
				
				~osc2FineVal.valueAction = 0;
				~osc2SemiVal.valueAction = 0;
				~osc2OctVal.valueAction = 3;
				
				~osc3FineVal.valueAction = 0;
				~osc3SemiVal.valueAction = 0;
				~osc3OctVal.valueAction = 4;
			},
			{
				~ampEnvCurveSlider.valueAction = 0;
				
				~ampEnvAVal.valueAction = 0.001;
				~ampEnvDVal.valueAction = 0.05;
				~ampEnvSSlider.valueAction = 0.6;
				~ampEnvRVal.valueAction = 0.05;
				
				~filtEnvCurveSlider.valueAction = 0;
				
				~filtEnvAVal.valueAction = 0.1;
				~filtEnvDVal.valueAction = 0.4;
				~filtEnvSVal.valueAction = 0.6;
				~filtEnvRVal.valueAction = 0.4;
				
				~filtCVVal.valueAction = 4.5;
				~cutoffVal.valueAction = 1353.75;
				~resVal.valueAction = 0.5;
				
				~osc1ShapeSlider.valueAction=1;
				~osc2ShapeSlider.valueAction=0;
				~osc3ShapeSlider.valueAction=0;
				
				~osc1WidthSlider.valueAction=0.15;
				~osc2WidthSlider.valueAction=0.5;
				~osc3WidthSlider.valueAction=0.5;
				
				~mixVal1.valueAction = 1;
				~mixVal2.valueAction = 0;
				~mixVal3.valueAction = 0;
				~mixVal4.valueAction = 0;
				
				~slewVal.valueAction = 0.3;
				
				~osc1FineVal.valueAction = 0;
				~osc1SemiVal.valueAction = 0;
				~osc1OctVal.valueAction = 4;
				
				~osc2FineVal.valueAction = 0;
				~osc2SemiVal.valueAction = 0;
				~osc2OctVal.valueAction = 4;
				
				~osc3FineVal.valueAction = 0;
				~osc3SemiVal.valueAction = 0;
				~osc3OctVal.valueAction = 4;
			},
			{
				~ampEnvCurveSlider.valueAction = 0;
				
				~ampEnvAVal.valueAction = 0.3;
				~ampEnvDVal.valueAction = 0.6;
				~ampEnvSSlider.valueAction = 0.7;
				~ampEnvRVal.valueAction = 0.6;
				
				~filtEnvCurveSlider.valueAction = 0;
				
				~filtEnvAVal.valueAction = 0.6;
				~filtEnvDVal.valueAction = 0.6;
				~filtEnvSVal.valueAction = 0.9;
				~filtEnvRVal.valueAction = 0.6;
				
				~filtCVVal.valueAction = 3;
				~cutoffVal.valueAction = 112.6;
				~resVal.valueAction = 0;
				
				~osc1ShapeSlider.valueAction=2/3;
				~osc2ShapeSlider.valueAction=2/3;
				~osc3ShapeSlider.valueAction=0;
				
				~osc1WidthSlider.valueAction=0.5;
				~osc2WidthSlider.valueAction=0.5;
				~osc3WidthSlider.valueAction=0.5;
				
				~mixVal1.valueAction = 1;
				~mixVal2.valueAction = 1;
				~mixVal3.valueAction = 0;
				~mixVal4.valueAction = 0;
				
				~slewVal.valueAction = 0.3;
				
				~osc1FineVal.valueAction = 0.1;
				~osc1SemiVal.valueAction = 0;
				~osc1OctVal.valueAction = 4;
				
				~osc2FineVal.valueAction = 0;
				~osc2SemiVal.valueAction = 0;
				~osc2OctVal.valueAction = 4;
				
				~osc3FineVal.valueAction = 0;
				~osc3SemiVal.valueAction = 0;
				~osc3OctVal.valueAction = 4;
			}
		].at(val).choose
	});	


	~presets.valueAction_(0);

	StaticText(~settingsGUI, Rect(10, 10, 60, 20))
	.string_("Presets:")
	.font_(Font(bold:true));
	
	osc1Node.set(\freq, 60.midicps);
	osc2Node.set(\freq, 60.midicps);
	osc3Node.set(\freq, 60.midicps);


s.sync;

////Scope

	~scopeBuf = Buffer.alloc(s,1024,1);
	//

	~scope = ScopeView(~settingsGUI, Rect(10, 160, 280, 140))
	.server_(s)
	.bufnum_(~scopeBuf)
	.start;

	~scopeMenu = PopUpMenu(~settingsGUI, Rect(120, 130, 170, 20))
	.items_(["Oscillator 1", "Oscillator 2", "Oscillator 3", "Noise", "Pre-Filter Mix", "Post-Filter"])
	.value_(5)
	.action_({
		~scopeSynth.set(\bus, [~osc1Bus, ~osc2Bus, ~osc3Bus, ~noiseBus, ~mixBus, ~filtBus].at(~scopeMenu.value).index)
	});

	~scopeButton = Button(~settingsGUI, Rect(10, 130, 100, 20))
	.states_([
		["Scope On", Color.black, Color.fromHexString("#00dd33")],
		["Scope Off", Color.black, Color.fromHexString("#ff3333")]
	])
	.action_({
		(~scopeButton.value==1).if
		{
			~scopeSynth = SynthDef(\scope, { arg bus, bufnum;
				var sig;
				sig = In.ar(bus,1);
				ScopeOut2.ar(sig, bufnum);
			}).play(s,
				[\bus, [~osc1Bus, ~osc2Bus, ~osc3Bus, ~noiseBus, ~mixBus, ~filtBus].at(~scopeMenu.value).index, \bufnum, ~scopeBuf.bufnum],
			\addToTail);
		}

		{
			~scopeSynth.free;
		};
	});

});


)
