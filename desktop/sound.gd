extends Node

var ambient=AudioStreamPlayer.new()
var cue=AudioStreamPlayer.new()
var rain=AudioStreamPlayer.new()
var enabled=true
var sounds={}

func setup():
	add_child(ambient); add_child(cue); add_child(rain)
	if DisplayServer.get_name()=="headless": return
	var rng=RandomNumberGenerator.new()
	rng.seed=46429
	for kind in ["water","rain","click","alert","finish"]:
		var wave=AudioStreamWAV.new()
		wave.format=AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate=16000
		var loop=kind in ["water","rain"]
		var length=4.0 if loop else (0.14 if kind=="click" else 0.86)
		var frames=roundi(length*wave.mix_rate)
		var bytes=PackedByteArray()
		bytes.resize(frames*2)
		var filtered=0.0
		for i in frames:
			var t=float(i)/wave.mix_rate
			var v=0.0
			if loop:
				var sample_noise=rng.randf_range(-1.0,1.0)
				filtered=lerpf(filtered,sample_noise,0.045 if kind=="water" else 0.24)
				v=filtered*(0.55+0.11*sin(TAU*t/length))
				if kind=="water":
					var bird=maxf(0.0,1.0-absf(t-2.67)/0.13)
					v+=0.019*bird*sin(TAU*(1900*t+38*sin(t*43.0)))
			else:
				var tone=510.0 if kind=="click" else (252.0 if kind=="alert" else 405.0)
				v=(sin(TAU*t*tone)+0.33*sin(TAU*t*tone*1.5))*exp(-t*(32.0 if kind=="click" else 4.8))*minf(1.0,t*100)*0.34
			bytes.encode_s16(i*2,roundi(clampf(v,-1,1)*32767))
		wave.data=bytes
		if loop:
			wave.loop_mode=AudioStreamWAV.LOOP_FORWARD
			wave.loop_end=frames
		sounds[kind]=wave
	ambient.stream=sounds.water; ambient.volume_db=-14; ambient.play()
	rain.stream=sounds.rain; rain.volume_db=-70; rain.play()
	cue.volume_db=-15

func effect(kind: String):
	if not enabled or not sounds.has(kind): return
	cue.stream=sounds[kind]
	cue.play()

func update_weather(value: bool):
	ambient.volume_db=-14 if enabled else -75
	rain.volume_db=-13 if enabled and value else -75

func silence():
	for player in [ambient,cue,rain]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null
	sounds.clear()
