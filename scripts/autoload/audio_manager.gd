extends Node

## Synthesizes lightweight in-memory PCM SFX and plays them via a fixed player pool.

const SAMPLE_RATE := 22050
const POOL_SIZE := 6

var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0

var _stream_drop: AudioStreamWAV
var _stream_merge: AudioStreamWAV
var _stream_click: AudioStreamWAV
var _stream_game_over: AudioStreamWAV
var _stream_bomb_explode: AudioStreamWAV
var _stream_nuclear_explode: AudioStreamWAV
var _stream_concrete_crush: AudioStreamWAV
var _stream_sticky: AudioStreamWAV
var _stream_charged_bounce: AudioStreamWAV
var _stream_unlock: AudioStreamWAV
var _stream_pop: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_streams()
	_build_player_pool()


func _exit_tree() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_players.clear()
	_stream_drop = null
	_stream_merge = null
	_stream_click = null
	_stream_game_over = null
	_stream_bomb_explode = null
	_stream_nuclear_explode = null
	_stream_concrete_crush = null
	_stream_sticky = null
	_stream_charged_bounce = null
	_stream_unlock = null
	_stream_pop = null


func _build_player_pool() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func _build_streams() -> void:
	_stream_drop = _synth_tone(420.0, 210.0, 0.11, 0.35)
	_stream_merge = _synth_chime([523.25, 659.25], 0.16, 0.40)
	_stream_click = _synth_tone(780.0, 620.0, 0.06, 0.25)
	_stream_game_over = _synth_chime([392.0, 329.63, 261.63], 0.36, 0.35)
	_stream_bomb_explode = _synth_explosion(180.0, 42.0, 0.34, 0.48, 0.55)
	_stream_nuclear_explode = _synth_explosion(240.0, 32.0, 0.52, 0.54, 0.65)
	_stream_concrete_crush = _synth_explosion(140.0, 55.0, 0.16, 0.42, 0.45)
	_stream_sticky = _synth_tone(260.0, 480.0, 0.09, 0.28)
	_stream_charged_bounce = _synth_chime([740.0, 1046.5], 0.10, 0.30)
	_stream_unlock = _synth_chime([659.25, 783.99, 1046.5, 1318.5], 0.11, 0.34)
	_stream_pop = _synth_tone(520.0, 900.0, 0.07, 0.26)


func _synth_tone(start_hz: float, end_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(duration * float(SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var freq := lerpf(start_hz, end_hz, t)
		var env := (1.0 - t) * (1.0 - t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var sample := sin(phase) * env * volume
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		pcm.encode_s16(i * 2, val)
	return _wrap_wav(pcm)


func _synth_chime(notes: Array[float], duration: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(duration * float(SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var note_count := maxi(notes.size(), 1)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var note_idx := mini(int(t * float(note_count)), note_count - 1)
		var local_t := fmod(t * float(note_count), 1.0)
		var freq := notes[note_idx]
		var env := sin(minf(local_t * 6.0, 1.0) * PI * 0.5) * (1.0 - local_t * 0.75)
		phase += TAU * freq / float(SAMPLE_RATE)
		var sample := (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * env * volume
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		pcm.encode_s16(i * 2, val)
	return _wrap_wav(pcm)


func _synth_explosion(start_hz: float, end_hz: float, duration: float, volume: float, noise_mix: float) -> AudioStreamWAV:
	var sample_count := int(duration * float(SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var freq := lerpf(start_hz, end_hz, minf(t * 1.4, 1.0))
		var env := (1.0 - t) * (1.0 - t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var boom := sin(phase)
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := lerpf(boom, noise, noise_mix) * env * volume
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		pcm.encode_s16(i * 2, val)
	return _wrap_wav(pcm)


func _wrap_wav(pcm: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _play_stream(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if not SaveManager.is_sfx_enabled() or stream == null or _players.is_empty():
		return
	var player := _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func play_drop() -> void:
	_play_stream(_stream_drop, randf_range(0.96, 1.04))


func play_merge(level: int) -> void:
	_play_stream(_stream_merge, 0.85 + float(level) * 0.08)


func play_click() -> void:
	_play_stream(_stream_click, 1.0)


func play_game_over() -> void:
	_play_stream(_stream_game_over, 1.0)


func play_bomb_explode() -> void:
	_play_stream(_stream_bomb_explode, randf_range(0.95, 1.05))


func play_nuclear_explode() -> void:
	_play_stream(_stream_nuclear_explode, randf_range(0.96, 1.04))


func play_concrete_crush() -> void:
	_play_stream(_stream_concrete_crush, randf_range(0.92, 1.08))


func play_sticky() -> void:
	_play_stream(_stream_sticky, randf_range(0.94, 1.08))


func play_charged_bounce() -> void:
	_play_stream(_stream_charged_bounce, randf_range(0.95, 1.12))


## Sparkly arpeggio for discovering a brand-new fruit.
func play_unlock() -> void:
	_play_stream(_stream_unlock)


## Short bubbly pop for UI moments (toasts, fruit guide pop).
func play_pop(pitch: float = 1.0) -> void:
	_play_stream(_stream_pop, pitch)
