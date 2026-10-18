extends SceneTree
## Synthesises every sound effect and the music loop as WAV files in res://assets/audio.
## Nothing is sampled or licensed: rerun this script to rebuild the audio from scratch.
##   godot --headless --path . --script res://tools/make_sounds.gd

const RATE := 22050
const OUT_DIR := "res://assets/audio"
const MUSIC_BPM := 88.0
const MUSIC_BARS := 48
## Two bars each, in F minor: [sub-bass root in Hz, pad notes in Hz] for Fm7, D♭maj7, A♭ and B♭m7.
const MUSIC_CHORDS := [
	[43.65, [174.61, 207.65, 261.63, 311.13]],
	[34.65, [174.61, 207.65, 261.63, 277.18]],
	[51.91, [207.65, 261.63, 311.13, 415.30]],
	[58.27, [174.61, 207.65, 233.08, 277.18]],
]
## The lead's eight-bar phrase: [start beat, length in beats, Hz].
const MUSIC_LEAD := [
	[0.0, 2.0, 523.25], [2.0, 1.0, 415.30], [3.0, 1.0, 466.16], [4.0, 3.0, 523.25],
	[8.0, 2.0, 622.25], [10.0, 1.0, 554.37], [11.0, 1.0, 523.25], [12.0, 4.0, 415.30],
	[16.0, 2.0, 466.16], [18.0, 1.0, 523.25], [19.0, 1.0, 554.37], [20.0, 2.0, 523.25], [22.0, 2.0, 415.30],
	[24.0, 2.0, 392.0], [26.0, 1.0, 415.30], [27.0, 1.0, 466.16], [28.0, 4.0, 523.25],
]
const SAW_TABLE_SIZE := 2048


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

## A dark, slow synth piece in F minor at 88 BPM, 48 bars (about 2 minutes 11 seconds), built to loop:
## a filtered intro that opens up (bars 1-8), a build (9-16), the full piece with a lead (17-32), a
## breakdown (33-40) and a return (41-48). Most of its weight is in the bass, with little above 2 kHz.
## Notes that run past the end wrap round to the start, so the loop has no seam.
func _music() -> PackedFloat32Array:
	var beat := 60.0 / MUSIC_BPM
	var bar_seconds := beat * 4.0
	var out := _buffer(MUSIC_BARS * bar_seconds)
	var saw := _saw_table(24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for bar: int in MUSIC_BARS:
		var part := _section(bar)
		var start := bar * bar_seconds
		var chord: Array = MUSIC_CHORDS[floori(bar / 2.0) % MUSIC_CHORDS.size()]
		var root: float = chord[0]
		var notes: Array = chord[1]
		# Pads and sub-bass change every two bars, so they're laid down once per chord.
		if bar % 2 == 0:
			var after := _section((bar + 2) % MUSIC_BARS)
			_add_pad(out, saw, notes, start, bar_seconds * 2.0, part["pad_cutoff"], after["pad_cutoff"])
			_add_sub(out, root, start, bar_seconds * 2.0, part["sub"])
		# Bass line in eighths: on 1, the "and" of 2, 3 and 4.
		if part["bass"] > 0.0:
			for hit: Array in [[0, 2], [3, 1], [4, 2], [6, 2]]:
				_add_bass(out, saw, root * 2.0, start + hit[0] * beat / 2.0, hit[1] * beat / 2.0, part["bass"])
		# Arpeggio in eighths over the chord an octave up, with two echoes.
		if part["arp"] > 0.0:
			for step: int in 8:
				var freq: float = notes[[0, 2, 1, 3, 2, 0, 3, 1][step]] * (4.0 if step == 7 else 2.0)
				var at := start + step * beat / 2.0
				for echo: Array in [[0.0, 1.0], [0.75, 0.35], [1.5, 0.12]]:
					_add_arp(out, saw, freq, at + echo[0] * beat, part["arp"] * echo[1], part["arp_cutoff"])
		# Half-time drums: kick on 1 (and the "and" of 3 in the full parts), snare on 3, soft hats on the eighths.
		if part["kick"] > 0.0:
			_add_kick(out, start, part["kick"])
			if part["snare"] > 0.0:
				_add_kick(out, start + 2.5 * beat, part["kick"] * 0.7)
		if part["snare"] > 0.0:
			_add_snare(out, rng, start + 2.0 * beat, part["snare"])
		if part["hat"] > 0.0:
			for eighth: int in [1, 3, 5, 7]:
				_add_hat(out, rng, start + eighth * beat / 2.0, part["hat"])
	# The lead plays its eight-bar phrase twice in the full part and once in the return.
	for phrase_bar: int in [16, 24, 40]:
		for note: Array in MUSIC_LEAD:
			var note_bar := phrase_bar + floori(float(note[0]) / 4.0)
			if note_bar < MUSIC_BARS and _section(note_bar)["lead"]:
				var at: float = (phrase_bar * 4.0 + float(note[0])) * beat
				_add_lead(out, note[2], at, float(note[1]) * beat, 1.0)
				_add_lead(out, note[2], at + 0.75 * beat, float(note[1]) * beat, 0.3)
	# A noise riser through the last bar of the breakdown.
	_add_riser(out, rng, 39 * bar_seconds, bar_seconds)
	# Gentle saturation, then a peak of 0.72.
	var peak := 0.0
	for i: int in out.size():
		out[i] = tanh(out[i] * 1.1)
		peak = maxf(peak, absf(out[i]))
	for i: int in out.size():
		out[i] *= 0.72 / peak
	return out


## How much of each part plays in a bar, and how open the filters are.
func _section(bar: int) -> Dictionary:
	if bar < 8:
		return {"pad_cutoff": lerpf(600.0, 1300.0, bar / 7.0), "sub": 0.6, "bass": 0.0, "arp": 0.0, "arp_cutoff": 600.0,
			"kick": 0.0, "snare": 0.0, "hat": 0.0, "lead": false}
	if bar < 16:
		var t := (bar - 8) / 7.0
		return {"pad_cutoff": lerpf(1300.0, 2400.0, t), "sub": 0.8, "bass": lerpf(0.4, 0.8, t), "arp": lerpf(0.3, 0.7, t),
			"arp_cutoff": lerpf(1000.0, 3000.0, t), "kick": 0.8 if bar >= 12 else 0.0, "snare": 0.0,
			"hat": 0.3 if bar >= 14 else 0.0, "lead": false}
	if bar >= 32 and bar < 40:
		var t := (bar - 32) / 7.0
		return {"pad_cutoff": lerpf(1800.0, 1000.0, t), "sub": 0.7, "bass": 0.0, "arp": 0.6, "arp_cutoff": lerpf(1800.0, 1200.0, t),
			"kick": 0.0, "snare": 0.0, "hat": 0.0, "lead": false}
	if bar == MUSIC_BARS - 1:
		# The last bar winds down towards the intro the loop returns to.
		return {"pad_cutoff": 900.0, "sub": 0.6, "bass": 0.3, "arp": 0.3, "arp_cutoff": 1200.0,
			"kick": 0.6, "snare": 0.0, "hat": 0.0, "lead": false}
	return {"pad_cutoff": 2600.0, "sub": 1.0, "bass": 1.0, "arp": 0.8, "arp_cutoff": 3400.0,
		"kick": 1.0, "snare": 1.0, "hat": 0.5, "lead": true}


## One cycle of a band-limited sawtooth, for oscillators that read it at any pitch.
func _saw_table(harmonics: int) -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(SAW_TABLE_SIZE)
	for i: int in SAW_TABLE_SIZE:
		var x := TAU * i / SAW_TABLE_SIZE
		var value := 0.0
		for h: int in range(1, harmonics + 1):
			value += sin(h * x) / h
		table[i] = value * 0.53
	return table


## Detuned saws through a low-pass filter that moves from one cutoff to the next across the chord.
func _add_pad(out: PackedFloat32Array, saw: PackedFloat32Array, notes: Array, start: float, length: float, cutoff_from: float, cutoff_to: float) -> void:
	var total := length + 0.6
	var count := int(total * RATE)
	var first := int(start * RATE)
	var phases := PackedFloat32Array()
	phases.resize(notes.size() * 2)
	var low := 0.0
	var lower := 0.0
	var a := 0.0
	for i: int in count:
		var t := float(i) / RATE
		if i % 64 == 0:
			a = 1.0 - exp(-TAU * lerpf(cutoff_from, cutoff_to, clampf(t / length, 0.0, 1.0)) / RATE)
		var sample := 0.0
		for n: int in notes.size():
			var freq: float = notes[n]
			for side: int in 2:
				var index := n * 2 + side
				phases[index] = fmod(phases[index] + freq * (0.998 if side == 0 else 1.002) / RATE, 1.0)
				sample += saw[int(phases[index] * SAW_TABLE_SIZE)]
		low += a * (sample - low)
		lower += a * (low - lower)
		var envelope := minf(t / 0.6, 1.0) * minf((total - t) / 1.2, 1.0)
		_mix(out, first + i, lower * envelope * 0.05)


## A sine two octaves below the pads, with a strong octave above so small speakers still carry it.
func _add_sub(out: PackedFloat32Array, root: float, start: float, length: float, level: float) -> void:
	var total := length + 0.3
	var count := int(total * RATE)
	var first := int(start * RATE)
	for i: int in count:
		var t := float(i) / RATE
		var envelope := minf(t / 0.08, 1.0) * minf((total - t) / 0.6, 1.0)
		var sample := tanh(1.6 * (sin(TAU * root * t) + 0.8 * sin(TAU * root * 2.0 * t))) / tanh(1.6)
		_mix(out, first + i, sample * envelope * level * 0.12)


## A plucked saw bass whose filter closes as the note sounds.
func _add_bass(out: PackedFloat32Array, saw: PackedFloat32Array, freq: float, start: float, length: float, level: float) -> void:
	var total := length + 0.06
	var count := int(total * RATE)
	var first := int(start * RATE)
	var phase := 0.0
	var low := 0.0
	for i: int in count:
		var t := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		var cutoff := 250.0 + 650.0 * exp(-t * 12.0)
		low += (1.0 - exp(-TAU * cutoff / RATE)) * (saw[int(phase * SAW_TABLE_SIZE)] - low)
		var envelope := minf(t / 0.005, 1.0) * (0.6 + 0.4 * exp(-t * 8.0)) * clampf((total - t) / 0.06, 0.0, 1.0)
		_mix(out, first + i, low * envelope * level * 0.22)


func _add_arp(out: PackedFloat32Array, saw: PackedFloat32Array, freq: float, start: float, level: float, cutoff: float) -> void:
	var count := int(0.25 * RATE)
	var first := int(start * RATE)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var phase := 0.0
	var low := 0.0
	for i: int in count:
		var t := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		low += a * (saw[int(phase * SAW_TABLE_SIZE)] - low)
		_mix(out, first + i, low * minf(t / 0.004, 1.0) * exp(-t * 10.0) * level * 0.05)


## A soft, rounded lead with a little vibrato.
func _add_lead(out: PackedFloat32Array, freq: float, start: float, length: float, level: float) -> void:
	var total := length + 0.3
	var count := int(total * RATE)
	var first := int(start * RATE)
	var phase := 0.0
	for i: int in count:
		var t := float(i) / RATE
		phase += TAU * freq * (1.0 + 0.0035 * sin(TAU * 5.0 * t) * minf(t / 0.4, 1.0)) / RATE
		var envelope := minf(t / 0.06, 1.0) * clampf((total - t) / 0.3, 0.0, 1.0)
		_mix(out, first + i, (sin(phase) + 0.25 * sin(3.0 * phase)) * envelope * level * 0.075)


func _add_kick(out: PackedFloat32Array, start: float, level: float) -> void:
	var first := int(start * RATE)
	var phase := 0.0
	for i: int in int(0.5 * RATE):
		var t := float(i) / RATE
		phase += TAU * (45.0 + 65.0 * exp(-t * 25.0)) / RATE
		_mix(out, first + i, sin(phase) * exp(-t * 7.0) * level * 0.5)


## A dark snare: noise with its top end rolled off, over a short low body.
func _add_snare(out: PackedFloat32Array, rng: RandomNumberGenerator, start: float, level: float) -> void:
	var first := int(start * RATE)
	var low := 0.0
	for i: int in int(0.3 * RATE):
		var t := float(i) / RATE
		low += 0.45 * (rng.randf_range(-1.0, 1.0) - low)
		var body := sin(TAU * 180.0 * t) * exp(-t * 22.0)
		_mix(out, first + i, (low * exp(-t * 14.0) * 0.6 + body * 0.5) * level * 0.2)


func _add_hat(out: PackedFloat32Array, rng: RandomNumberGenerator, start: float, level: float) -> void:
	var first := int(start * RATE)
	var low := 0.0
	for i: int in int(0.05 * RATE):
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.3 * (noise - low)
		_mix(out, first + i, (noise - low) * exp(-t * 45.0) * level * 0.05)


## Noise rising through a filter that opens across one bar.
func _add_riser(out: PackedFloat32Array, rng: RandomNumberGenerator, start: float, length: float) -> void:
	var first := int(start * RATE)
	var low := 0.0
	for i: int in int(length * RATE):
		var t := float(i) / RATE / length
		low += (1.0 - exp(-TAU * lerpf(200.0, 3000.0, t * t) / RATE)) * (rng.randf_range(-1.0, 1.0) - low)
		_mix(out, first + i, low * t * t * 0.06)


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
