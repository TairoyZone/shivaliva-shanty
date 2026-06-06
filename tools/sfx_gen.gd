## PLACEHOLDER SFX GENERATOR — synthesises a small set of procedural .wav sound effects (no lifted audio,
## per the placeholder-first rule). Run headless:  godot --headless --script res://tools/sfx_gen.gd
## then re-import (godot --headless --editor --quit) so the engine picks the new .wav files up. Swap any
## of these for real clips later by overwriting the same res://audio/sfx/<name>.wav — the Audio autoload
## doesn't care. NOT part of the shipped game; just a regen tool.
extends SceneTree

const RATE : int = 44100


func _initialize() -> void:

	DirAccess.make_dir_recursive_absolute("res://audio/sfx")
	_save("coin",   _coin())
	_save("clack",  _clack())
	_save("pop",    _pop())
	_save("whoosh", _whoosh())
	_save("thunk",  _thunk())
	_save("chime",  _chime())
	_save("buzz",   _buzz())
	_save("click",  _click())
	_save("toss",   _toss())
	print("SFX generated to res://audio/sfx/")
	quit()


# Write a mono 16-bit WAV from float samples in [-1, 1].
func _save(snd_name: String, samples: PackedFloat32Array) -> void:

	var wav : AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes : PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	wav.save_to_wav("res://audio/sfx/%s.wav" % snd_name)


# --- synthesis helpers ---------------------------------------------------

func _len(dur: float) -> int:
	return int(dur * float(RATE))

# Attack/release envelope (fractions of the clip), with a little exponential decay in the body.
func _env(i: int, n: int, attack: float, release: float) -> float:
	var t : float = float(i) / float(n)
	var a : float = clampf(t / maxf(0.0001, attack), 0.0, 1.0)
	var r : float = clampf((1.0 - t) / maxf(0.0001, release), 0.0, 1.0)
	return a * r


# --- the sounds ----------------------------------------------------------

# Coin: two rising sine tones — a bright pickup blip.
func _coin() -> PackedFloat32Array:
	var n : int = _len(0.13)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var f : float = 880.0 if t < 0.045 else 1318.0
		out[i] = sin(TAU * f * t) * 0.4 * _env(i, n, 0.005, 0.55)
	return out

# Clack: a short woody click — a mid sine with a noisy transient + fast decay (match/clear tick).
func _clack() -> PackedFloat32Array:
	var n : int = _len(0.07)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var noise : float = (randf() * 2.0 - 1.0) * exp(-t * 220.0) * 0.35
		var body : float = sin(TAU * 320.0 * t) * exp(-t * 35.0) * 0.45
		out[i] = (noise + body) * _env(i, n, 0.002, 0.2)
	return out

# Pop: a quick upward pitch sweep — a satisfying clear/burst.
func _pop() -> PackedFloat32Array:
	var n : int = _len(0.11)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var f : float = lerpf(220.0, 720.0, clampf(t / 0.11, 0.0, 1.0))
		out[i] = sin(TAU * f * t) * 0.42 * _env(i, n, 0.004, 0.5)
	return out

# Whoosh: filtered noise with a bell envelope — panel slide / garbage drop.
func _whoosh() -> PackedFloat32Array:
	var n : int = _len(0.26)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	var smooth : float = 0.0
	for i in n:
		var t : float = float(i) / float(n)
		var raw : float = randf() * 2.0 - 1.0
		smooth = lerpf(smooth, raw, 0.18)             # crude low-pass = an airy swish
		var bell : float = sin(PI * t)                # fade in + out
		out[i] = smooth * bell * bell * 0.4
	return out

# Thunk: a low sine with a fast decay — a piece landing / hull patch.
func _thunk() -> PackedFloat32Array:
	var n : int = _len(0.16)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var f : float = lerpf(150.0, 90.0, clampf(t / 0.16, 0.0, 1.0))
		out[i] = sin(TAU * f * t) * exp(-t * 16.0) * 0.55
	return out

# Chime: a 3-note ascending arpeggio (C5 E5 G5) — win / results flourish.
func _chime() -> PackedFloat32Array:
	var n : int = _len(0.5)
	var freqs : Array = [523.25, 659.25, 783.99]
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var note : int = clampi(int(t / 0.13), 0, 2)
		var nt : float = t - float(note) * 0.13
		out[i] = sin(TAU * float(freqs[note]) * t) * exp(-nt * 6.0) * 0.36 * _env(i, n, 0.005, 0.18)
	return out

# Buzz: a low gritty tone — invalid / can't-do.
func _buzz() -> PackedFloat32Array:
	var n : int = _len(0.16)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var saw : float = fmod(150.0 * t, 1.0) * 2.0 - 1.0
		out[i] = saw * 0.32 * _env(i, n, 0.01, 0.4)
	return out

# Click: a tiny UI tick.
func _click() -> PackedFloat32Array:
	var n : int = _len(0.035)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		out[i] = sin(TAU * 1000.0 * t) * exp(-t * 120.0) * 0.4
	return out

# Toss: a soft downward blip — discard / wasted piece.
func _toss() -> PackedFloat32Array:
	var n : int = _len(0.12)
	var out : PackedFloat32Array = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t : float = float(i) / float(RATE)
		var f : float = lerpf(520.0, 200.0, clampf(t / 0.12, 0.0, 1.0))
		out[i] = sin(TAU * f * t) * 0.34 * _env(i, n, 0.004, 0.45)
	return out
