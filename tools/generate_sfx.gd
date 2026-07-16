extends SceneTree
## Procedural SFX generator for Crystal Slash — synthesizes all sound
## effects from math and writes them to assets/sounds/ as 16-bit mono WAVs.
## Deterministic (fixed seed), so re-running produces identical files.
##
## Run:  Godot_console.exe --headless --path <project> -s res://tools/generate_sfx.gd

const SAMPLE_RATE := 44100


func _init() -> void:
	seed(20260716)
	_save("slice", _gen_slice())
	_save("crystal_break", _gen_crystal_break())
	_save("explosion", _gen_explosion())
	_save("button", _gen_button())
	_save("powerup", _gen_powerup())
	_save("game_over", _gen_game_over())
	print("[SFX] all sounds generated")
	quit()


## Sword slash: bright metallic "shing" attack + air-cutting swish tail.
func _gen_slice() -> PackedFloat32Array:
	var n := int(0.22 * SAMPLE_RATE)
	var noise := _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var ring_freqs: Array[float] = [3200.0, 4700.0, 6350.0]
	for i in n:
		var t := float(i) / n
		var ts := float(i) / SAMPLE_RATE
		# Swish: noise starts bright (blade edge) and darkens as it passes.
		var window := int(lerpf(3.0, 30.0, pow(t, 1.3)))
		var s := 0.0
		for j in window:
			s += noise[maxi(i - j, 0)]
		s /= window
		var swish := s * minf(ts * 120.0, 1.0) * exp(-ts * 13.0) * 2.4
		# Metallic ring — the "shing" of steel.
		var shing := 0.0
		for k in ring_freqs.size():
			shing += sin(TAU * ring_freqs[k] * ts * (1.0 + 0.002 * k) + k)
		shing *= 0.14 * minf(ts * 300.0, 1.0) * exp(-ts * 20.0)
		out[i] = clampf(swish + shing, -1.0, 1.0) * 0.85
	return out


## Glassy shatter: high inharmonic partials with sharp decay + initial click.
func _gen_crystal_break() -> PackedFloat32Array:
	var n := int(0.4 * SAMPLE_RATE)
	var freqs: Array[float] = [2093.0, 3136.0, 4186.0, 5274.0, 6272.0]
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var s := 0.0
		for k in freqs.size():
			var f := freqs[k] * (1.0 + 0.01 * sin(t * 30.0 + k))
			s += sin(TAU * f * t + k) * exp(-t * (14.0 + 2.0 * k)) / freqs.size()
		s += (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.35
		out[i] = clampf(s * 0.9, -1.0, 1.0)
	return out


## Deep boom: heavy lowpassed noise + a sinking bass thump.
func _gen_explosion() -> PackedFloat32Array:
	var n := int(0.7 * SAMPLE_RATE)
	var noise := _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var s := 0.0
		for j in 45:
			s += noise[maxi(i - j, 0)]
		s /= 45.0
		phase += TAU * (110.0 * exp(-t * 2.0)) / SAMPLE_RATE
		var thump := sin(phase) * exp(-t * 7.0) * 0.8
		out[i] = clampf((s * 3.0 * exp(-t * 5.5)) + thump, -1.0, 1.0) * 0.9
	return out


## Short soft blip for UI.
func _gen_button() -> PackedFloat32Array:
	var n := int(0.09 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		out[i] = sin(TAU * 950.0 * t) * exp(-t * 40.0) * 0.5 \
			+ sin(TAU * 1900.0 * t) * exp(-t * 55.0) * 0.15
	return out


## Rising major arpeggio — classic "good thing happened".
func _gen_powerup() -> PackedFloat32Array:
	return _melody([523.25, 659.25, 783.99, 1046.5], [0.1, 0.1, 0.1, 0.18], 9.0, 0.45)


## Three descending somber notes.
func _gen_game_over() -> PackedFloat32Array:
	return _melody([392.0, 311.13, 261.63], [0.2, 0.2, 0.35], 6.0, 0.4)


func _melody(freqs: Array, durations: Array, decay: float, amp: float) -> PackedFloat32Array:
	var total := 0.0
	for d: float in durations:
		total += d
	var n := int(total * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var note_start := 0.0
	for k in freqs.size():
		var f: float = freqs[k]
		var start := int(note_start * SAMPLE_RATE)
		var count := int(durations[k] * SAMPLE_RATE)
		for i in count:
			if start + i >= n:
				break
			var t := float(i) / SAMPLE_RATE
			var attack := minf(t * 80.0, 1.0)
			var s := (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) \
				+ 0.2 * sin(TAU * f * 1.005 * t)) * attack * exp(-t * decay) * amp
			out[start + i] += s
		note_start += durations[k]
	return out


func _noise(count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = randf() * 2.0 - 1.0
	return out


func _save(sound_name: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	var err := wav.save_to_wav("res://assets/sounds/%s.wav" % sound_name)
	print("[SFX] %s.wav (%.2fs) -> %s" % [sound_name, samples.size() / float(SAMPLE_RATE), error_string(err)])
