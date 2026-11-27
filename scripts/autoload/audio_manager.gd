extends Node

## Synthesizes lightweight in-memory PCM SFX and plays them via a fixed player pool.

const SAMPLE_RATE := 22050
const POOL_SIZE := 6

## Combo splash: an mp3 asset, played with a chance so it stays special.
const SPLASH_COMBO_PATH := "res://assets/audio/splash_combo.mp3"
## Smallest combo (merges in quick succession) that can splash.
const SPLASH_MIN_COMBO := 2
## Never splash again within this many seconds (the clip is ~1.7s long).
const SPLASH_COOLDOWN := 1.2
const SPLASH_VOLUME_DB := -2.0

## Landing thuds: one of these plays (at random) when a dropped fruit first hits something.
const LAND_SOUND_PATHS: Array[String] = ["res://assets/audio/fall_1.mp3", "res://assets/audio/fall_2.mp3"]
## Seconds of near-silence to skip at the start of each landing clip, so the thud is on time.
const LAND_SOUND_OFFSETS: Array[float] = [0.0, 0.12]
const LAND_VOLUME_DB := -5.0
## Don't start a new landing sound if one started this recently (avoids a wall of thuds).
const LAND_MIN_INTERVAL := 0.07
const LAND_PLAYER_COUNT := 3

const TOAST_SOUND_PATH := "res://assets/audio/toast.mp3"
const IMPORTANT_TOAST_SOUND_PATH := "res://assets/audio/important_toast.mp3"
const TOAST_VOLUME_DB := -3.0
## Several normal toasts appearing together only chime once.
const TOAST_MIN_INTERVAL := 0.35

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
var _stream_shadow_split: AudioStreamWAV
var _stream_wave_clear: AudioStreamWAV
var _stream_unlock: AudioStreamWAV
var _stream_pop: AudioStreamWAV
var _stream_splash_combo: AudioStream
var _splash_player: AudioStreamPlayer
var _last_splash_ms: int = -100000
var _rng := RandomNumberGenerator.new()
var _land_streams: Array[AudioStream] = []
var _land_offsets: Array[float] = []
var _land_players: Array[AudioStreamPlayer] = []
var _next_land_player: int = 0
var _last_land_ms: int = -100000
var _stream_toast: AudioStream
var _stream_important_toast: AudioStream
var _toast_player: AudioStreamPlayer
var _important_toast_player: AudioStreamPlayer
var _last_toast_ms: int = -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_streams()
	_build_player_pool()
	_stream_splash_combo = _load_audio(SPLASH_COMBO_PATH)
	# Own player so the long splash never gets cut off by the round-robin SFX pool.
	_splash_player = AudioStreamPlayer.new()
	_splash_player.bus = &"Master"
	_splash_player.volume_db = SPLASH_VOLUME_DB
	add_child(_splash_player)
	_build_asset_sounds()


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
	_stream_shadow_split = null
	_stream_wave_clear = null
	_stream_unlock = null
	_stream_pop = null
	_stream_splash_combo = null
	_land_streams.clear()
	_stream_toast = null
	_stream_important_toast = null


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
	_stream_shadow_split = _synth_chime([440.0, 587.33, 880.0], 0.14, 0.30)
	_stream_wave_clear = _synth_chime([523.25, 659.25, 783.99, 1046.5], 0.24, 0.34)
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


func _play_stream(stream: AudioStream, pitch: float = 1.0) -> void:
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


func play_shadow_split() -> void:
	_play_stream(_stream_shadow_split, randf_range(0.95, 1.06))


func play_wave_clear() -> void:
	_play_stream(_stream_wave_clear, 1.0)


## Sparkly arpeggio for discovering a brand-new fruit.
func play_unlock() -> void:
	_play_stream(_stream_unlock)


## Short bubbly pop for UI moments (toasts, fruit guide pop).
func play_pop(pitch: float = 1.0) -> void:
	_play_stream(_stream_pop, pitch)


# --- Asset-based sounds -----------------------------------------------------------------------

## Loads an imported audio asset; falls back to reading a raw .mp3 so it still works before
## the editor has imported the file.
func _load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			return stream
	if path.get_extension().to_lower() == "mp3" and FileAccess.file_exists(path):
		var mp3 := AudioStreamMP3.new()
		mp3.data = FileAccess.get_file_as_bytes(path)
		return mp3
	push_warning("AudioManager: could not load " + path)
	return null


## Chance that a merge at this combo count splashes: x2 30%, x3 45%, x4 60%, x5 75%, x6+ 85%.
static func get_splash_chance(combo: int) -> float:
	if combo < SPLASH_MIN_COMBO:
		return 0.0
	return clampf(0.3 + 0.15 * float(combo - SPLASH_MIN_COMBO), 0.0, 0.85)


## Call on every merge with the current combo count. Plays the splash only sometimes
## (chance grows with the combo, plus a cooldown). Returns true if it played.
func try_play_combo_splash(combo: int) -> bool:
	if _stream_splash_combo == null or not SaveManager.is_sfx_enabled():
		return false
	var chance := get_splash_chance(combo)
	if chance <= 0.0:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_splash_ms < int(SPLASH_COOLDOWN * 1000.0):
		return false
	if _rng.randf() >= chance:
		return false
	_last_splash_ms = now
	_splash_player.stream = _stream_splash_combo
	# Slight random pitch so repeated splashes don't sound identical.
	_splash_player.pitch_scale = _rng.randf_range(0.94, 1.08)
	_splash_player.play()
	return true


func _build_asset_sounds() -> void:
	for i in range(LAND_SOUND_PATHS.size()):
		var stream := _load_audio(LAND_SOUND_PATHS[i])
		if stream != null:
			_land_streams.append(stream)
			_land_offsets.append(LAND_SOUND_OFFSETS[i] if i < LAND_SOUND_OFFSETS.size() else 0.0)
	for i in range(LAND_PLAYER_COUNT):
		_land_players.append(_make_player(LAND_VOLUME_DB))

	_stream_toast = _load_audio(TOAST_SOUND_PATH)
	_stream_important_toast = _load_audio(IMPORTANT_TOAST_SOUND_PATH)
	_toast_player = _make_player(TOAST_VOLUME_DB)
	_important_toast_player = _make_player(TOAST_VOLUME_DB)


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	player.volume_db = volume_db
	add_child(player)
	return player


## Thud when a dropped fruit first lands. Bigger fruits sound deeper and a bit louder.
func play_fruit_land(level: int) -> void:
	if _land_streams.is_empty() or not SaveManager.is_sfx_enabled():
		return
	var now := Time.get_ticks_msec()
	if now - _last_land_ms < int(LAND_MIN_INTERVAL * 1000.0):
		return
	_last_land_ms = now
	var idx := _rng.randi_range(0, _land_streams.size() - 1)
	var t := clampf(float(level) / 14.0, 0.0, 1.0)
	var player := _land_players[_next_land_player]
	_next_land_player = (_next_land_player + 1) % _land_players.size()
	player.stream = _land_streams[idx]
	player.volume_db = LAND_VOLUME_DB + lerpf(-4.0, 2.0, t)
	player.pitch_scale = lerpf(1.15, 0.85, t) * _rng.randf_range(0.95, 1.05)
	player.play(_land_offsets[idx])


## Chime for a toast. Important ones (new fruit, new best...) use the bigger jingle.
func play_toast(important: bool = false) -> void:
	if not SaveManager.is_sfx_enabled():
		return
	if important:
		if _stream_important_toast != null:
			_important_toast_player.stream = _stream_important_toast
			_important_toast_player.play()
		return
	var now := Time.get_ticks_msec()
	if _stream_toast == null or now - _last_toast_ms < int(TOAST_MIN_INTERVAL * 1000.0):
		return
	# Don't talk over the important jingle.
	if _important_toast_player.playing:
		return
	_last_toast_ms = now
	_toast_player.stream = _stream_toast
	_toast_player.play()
