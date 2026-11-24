class_name ProceduralAudioManager
extends Node

const SAMPLE_RATE := 22050.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

# Continuous synth state
var _engine_phase := 0.0
var _sub_phase := 0.0
var _lpf_state := 0.0
var _noise_lpf := 0.0

var rpm_norm: float = 0.0
var throttle_amount: float = 0.0
var is_boosting: bool = false
var is_airborne: bool = false
var is_muted: bool = false

# Active one-shot procedural voices (chimes, thuds, fanfare, pops)
var _voices: Array[Dictionary] = []

# Pentatonic scale frequencies (C5 -> E6) for escalating combo shards
const PENTATONIC := [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51]


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.08
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null or is_muted:
		return
	_fill_buffer()


func _fill_buffer() -> void:
	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	var base_freq := lerpf(58.0, 215.0, clampf(rpm_norm, 0.0, 1.35))
	var engine_vol := lerpf(0.08, 0.22, clampf(throttle_amount * 0.7 + rpm_norm * 0.3, 0.0, 1.0))
	if is_airborne:
		engine_vol *= 0.72
	var cutoff := lerpf(0.08, 0.38, clampf(rpm_norm * 0.7 + throttle_amount * 0.4, 0.0, 1.0))

	for _i in range(frames_available):
		# 1. Rover motor + warm saw/triangle harmonic hum
		_engine_phase = fmod(_engine_phase + base_freq / SAMPLE_RATE, 1.0)
		_sub_phase = fmod(_sub_phase + (base_freq * 0.5) / SAMPLE_RATE, 1.0)

		var saw := (_engine_phase * 2.0 - 1.0) * 0.55
		var tri := (absf(_engine_phase * 4.0 - 2.0) - 1.0) * 0.45
		var sub := sin(_sub_phase * TAU) * 0.55
		var raw_engine := (saw + tri + sub) * engine_vol
		_lpf_state += cutoff * (raw_engine - _lpf_state)
		var sample := _lpf_state

		# 2. Ion Thruster plasma roar (filtered noise + high whine)
		if is_boosting:
			var white := randf_range(-1.0, 1.0)
			_noise_lpf += 0.24 * (white - _noise_lpf)
			sample += _noise_lpf * 0.28 + sin(_engine_phase * TAU * 3.0) * 0.06

		# 3. Mix active one-shot SFX voices
		var v_idx := _voices.size() - 1
		while v_idx >= 0:
			var v := _voices[v_idx]
			var t: float = v["t"]
			var dur: float = v["dur"]
			if t < 0.0:
				v["t"] = t + 1.0 / SAMPLE_RATE
				v_idx -= 1
				continue
			if t >= dur:
				_voices.remove_at(v_idx)
				v_idx -= 1
				continue

			var progress := t / dur
			var env := (1.0 - progress) * (1.0 - progress)
			var freq: float = lerpf(v["f_start"], v["f_end"], progress)
			var phase: float = v["phase"] + freq / SAMPLE_RATE
			v["phase"] = phase
			v["t"] = t + 1.0 / SAMPLE_RATE

			var vtype: String = v["type"]
			var vsample := 0.0
			if vtype == "chime":
				vsample = (sin(phase * TAU) + 0.35 * sin(phase * TAU * 2.0)) * env * v["vol"]
			elif vtype == "thud":
				var thud_noise := randf_range(-1.0, 1.0) * (1.0 - minf(progress * 3.5, 1.0)) * 0.35
				vsample = (sin(phase * TAU) + thud_noise) * env * v["vol"]
			elif vtype == "pop":
				vsample = sin(phase * TAU) * env * v["vol"]

			sample += vsample
			v_idx -= 1

		sample = clampf(sample, -0.92, 0.92)
		_playback.push_frame(Vector2(sample, sample))


func play_shard_chime(combo_index: int) -> void:
	var idx := clampi(combo_index, 0, PENTATONIC.size() - 1)
	var freq: float = PENTATONIC[idx]
	_voices.append({
		"type": "chime",
		"f_start": freq,
		"f_end": freq * 1.02,
		"dur": 0.24,
		"vol": 0.34,
		"t": 0.0,
		"phase": 0.0,
	})


func play_landing_thud(impact_strength: float) -> void:
	var strength := clampf(impact_strength, 0.2, 1.0)
	_voices.append({
		"type": "thud",
		"f_start": lerpf(110.0, 165.0, strength),
		"f_end": 34.0,
		"dur": lerpf(0.14, 0.28, strength),
		"vol": lerpf(0.22, 0.48, strength),
		"t": 0.0,
		"phase": 0.0,
	})


func play_fanfare() -> void:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in range(notes.size()):
		_voices.append({
			"type": "chime",
			"f_start": notes[i],
			"f_end": notes[i] * 1.015,
			"dur": 0.32 + i * 0.06,
			"vol": 0.22,
			"t": -float(i) * 0.045,
			"phase": 0.0,
		})


func play_ui_pop() -> void:
	_voices.append({
		"type": "pop",
		"f_start": 380.0,
		"f_end": 740.0,
		"dur": 0.075,
		"vol": 0.22,
		"t": 0.0,
		"phase": 0.0,
	})
