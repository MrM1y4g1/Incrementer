extends SceneTree
## Synthesises every sound effect and the music loop as WAV files in res://assets/audio.
## Nothing is sampled or licensed: rerun this script to rebuild the audio from scratch.
##   godot --headless --path . --script res://tools/make_sounds.gd

const RATE := 22050
const OUT_DIR := "res://assets/audio"
const MUSIC_SECONDS := 32.0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("click", _click())
	_save("buy", _buy())
	_save("upgrade", _arpeggio([523.25, 659.25, 783.99], 0.07, 0.35))
	_save("overclock", _arpeggio([880.0, 1046.5, 1318.5], 0.045, 0.3))
	_save("widen", _widen())
	_save("achievement", _bell())
	_save("overflow", _overflow())
	_save("fault", _fault())
	_save("music", _music())
	print("Wrote sounds to %s" % OUT_DIR)
	quit()


# --- Effects --------------------------------------------------------------------

func _click() -> PackedFloat32Array:
	var out := _buffer(0.06)
	var phase := 0.0
	for i: int in out.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(1500.0, 950.0, t / 0.06) / RATE
		out[i] = (sin(phase) + 0.25 * sin(phase * 2.0)) * exp(-t * 70.0) * 0.4
	return out


func _buy() -> PackedFloat32Array:
	var out := _buffer(0.12)
	for i: int in out.size():
		var t := float(i) / RATE
		var freq := 660.0 if t < 0.045 else 990.0
		var local := t if t < 0.045 else t - 0.045
		out[i] = (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 3.0 * t)) * exp(-local * 45.0) * 0.32
	return out


func _arpeggio(notes: Array, step: float, volume: float) -> PackedFloat32Array:
	var out := _buffer(step * notes.size() + 0.25)
	for n: int in notes.size():
		var freq: float = notes[n]
		var start := int(step * n * RATE)
		for i: int in range(start, out.size()):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * freq * t) + 0.2 * sin(TAU * freq * 2.0 * t)) * exp(-t * 14.0) * volume
	return out


func _widen() -> PackedFloat32Array:
	var length := 0.55
	var out := _buffer(length)
	var phase := 0.0
	for i: int in out.size():
		var t := float(i) / RATE
		var progress := t / length
		phase += TAU * (220.0 * pow(6.0, progress) + 6.0 * sin(TAU * 7.0 * t)) / RATE
		var envelope := sin(PI * progress) * (1.0 - progress * 0.4)
		out[i] = (sin(phase) + 0.15 * signf(sin(phase))) * envelope * 0.28
	return out


func _bell() -> PackedFloat32Array:
	var out := _buffer(1.1)
	var partials := [[1.0, 1.0], [2.76, 0.45], [5.4, 0.2], [8.93, 0.08]]
	for i: int in out.size():
		var t := float(i) / RATE
		var sample := 0.0
		for partial: Array in partials:
			var ratio: float = partial[0]
			var gain: float = partial[1]
			sample += sin(TAU * 880.0 * ratio * t) * gain * exp(-t * (3.0 + ratio))
		out[i] = sample * 0.3
	return out


func _overflow() -> PackedFloat32Array:
	var length := 1.6
	var out := _buffer(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var phase := 0.0
	var smoothed := 0.0
	for i: int in out.size():
		var t := float(i) / RATE
		# A noise burst, a sweep falling from 1600 Hz to 70 Hz, and a low boom underneath.
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.35)
		phase += TAU * (1600.0 * pow(70.0 / 1600.0, minf(t / 1.1, 1.0))) / RATE
		var burst := smoothed * exp(-t * 6.0) * 0.5
		var sweep := sin(phase) * exp(-t * 2.2) * 0.35
		var boom := sin(TAU * 55.0 * t) * exp(-t * 2.5) * 0.5
		out[i] = (burst + sweep + boom) * 0.7
	return out


# --- Music ----------------------------------------------------------------------

## A slow, quiet loop: A minor, F, C and G pads with a soft arpeggio over them.
## Notes that run past the end wrap round to the start, so the loop has no seam.
func _music() -> PackedFloat32Array:
	var total := int(MUSIC_SECONDS * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var chords := [
		[220.0, 261.63, 329.63],
		[174.61, 220.0, 261.63],
		[130.81, 196.0, 261.63],
		[196.0, 246.94, 293.66],
	]
	var chord_seconds := MUSIC_SECONDS / chords.size()
	for c: int in chords.size():
		var notes: Array = chords[c]
		var chord_start := c * chord_seconds
		# Pad: detuned sines with a slow swell, overlapping the next chord by a second.
		_add_pad(out, notes, chord_start - 1.0, chord_seconds + 2.0)
		# Arpeggio: one note every half second, an octave up.
		for beat: int in int(chord_seconds * 2.0):
			var freq: float = notes[beat % notes.size()] * 2.0
			_add_pluck(out, freq, chord_start + beat * 0.5)
	return out


func _add_pad(out: PackedFloat32Array, notes: Array, start: float, length: float) -> void:
	var count := int(length * RATE)
	var first := int(start * RATE)
	for i: int in count:
		var t := float(i) / RATE
		var envelope := sin(PI * clampf(t / length, 0.0, 1.0))
		var sample := 0.0
		for note: float in notes:
			sample += sin(TAU * note * t) + 0.5 * sin(TAU * note * 1.003 * t + 1.0)
		_mix(out, first + i, sample * envelope * 0.035)


func _add_pluck(out: PackedFloat32Array, freq: float, start: float) -> void:
	var count := int(0.9 * RATE)
	var first := int(start * RATE)
	for i: int in count:
		var t := float(i) / RATE
		var sample := (sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)) * exp(-t * 5.0)
		_mix(out, first + i, sample * 0.05)


func _mix(out: PackedFloat32Array, index: int, value: float) -> void:
	var size := out.size()
	out[((index % size) + size) % size] += value


## A bad bit: two short, low, slightly square pulses, like a memory check failing.
func _fault() -> PackedFloat32Array:
	var out := _buffer(0.34)
	for pulse: int in 2:
		var freq := 330.0 if pulse == 0 else 247.0
		var start := int(pulse * 0.17 * RATE)
		for i: int in range(start, mini(out.size(), start + int(0.15 * RATE))):
			var t := float(i - start) / RATE
			var wave := clampf(sin(TAU * freq * t) * 2.5, -1.0, 1.0)
			out[i] += wave * exp(-t * 16.0) * 0.2
	return out


# --- Output ---------------------------------------------------------------------

func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


func _save(sound_name: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var path := ProjectSettings.globalize_path("%s/%s.wav" % [OUT_DIR, sound_name])
	var err := wav.save_to_wav(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
