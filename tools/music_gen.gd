## PLACEHOLDER MUSIC GENERATOR — synthesises a seamless looping ambient pad (no lifted audio, per the
## placeholder-first rule). A gentle Am - F - C - G wander of crossfading sine-chord voices + a sub bass +
## a slow tremolo shimmer. Every periodic part is PHASE-ALIGNED to a whole number of cycles over the loop,
## so it repeats click-free. Run:  godot --headless --script res://tools/music_gen.gd  then re-import.
## Swap for a real track by overwriting res://audio/music/overworld.wav. NOT shipped; a regen tool.
extends SceneTree

const RATE : int = 44100
const LOOP_SECS : float = 16.0


func _initialize() -> void:

	DirAccess.make_dir_recursive_absolute("res://audio/music")
	_save_loop("overworld", _ambient_pad())
	print("Music generated to res://audio/music/")
	quit()


func _save_loop(snd_name: String, samples: PackedFloat32Array) -> void:

	var wav : AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	var bytes : PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	wav.save_to_wav("res://audio/music/%s.wav" % snd_name)


# Snap a frequency to a whole number of cycles over the loop, so it wraps without a click.
func _align(freq: float) -> float:
	return roundf(freq * LOOP_SECS) / LOOP_SECS


func _ambient_pad() -> PackedFloat32Array:

	# Am - F - C - G — a gentle minor-key wander (vi-IV-I-V in C). Each chord = 3 notes; a sub on the root.
	var chords : Array = [
		[220.0, 261.63, 329.63],   # Am  (A3 C4 E4)
		[174.61, 220.0, 261.63],   # F   (F3 A3 C4)
		[261.63, 329.63, 392.0],   # C   (C4 E4 G4)
		[196.0, 246.94, 293.66],   # G   (G3 B3 D4)
	]
	for c in chords:
		for j in c.size():
			c[j] = _align(c[j])
	var subs : Array = []
	for c in chords:
		subs.append(_align(float(c[0]) * 0.5))   # root, an octave down
	var trem_f : float = _align(0.12)             # slow tremolo (aligned so it wraps too)

	var n : int = int(LOOP_SECS * float(RATE))
	var per_chord : float = LOOP_SECS / float(chords.size())
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var pos : float = t / per_chord                 # 0..4 along the progression
		var ci : int = int(floorf(pos)) % chords.size()
		var ni : int = (ci + 1) % chords.size()
		var f : float = pos - floorf(pos)               # 0..1 crossfade weight
		var wa : float = cos(f * PI * 0.5)              # equal-power crossfade out
		var wb : float = sin(f * PI * 0.5)              # ...and in
		var s : float = 0.0
		for note in chords[ci]:
			s += sin(TAU * float(note) * t + float(note) * 0.017) * wa   # phase offset = no all-zero seam
		for note in chords[ni]:
			s += sin(TAU * float(note) * t + float(note) * 0.017) * wb
		s += sin(TAU * float(subs[ci]) * t) * wa * 1.2
		s += sin(TAU * float(subs[ni]) * t) * wb * 1.2
		var trem : float = 0.85 + 0.15 * sin(TAU * trem_f * t)
		out[i] = s * 0.07 * trem
	return out
