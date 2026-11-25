extends Node

## Persists high score and audio preference in user://save_data.cfg.

const SAVE_PATH := "user://save_data.cfg"
const SECTION_STATS := "stats"
const KEY_HIGH_SCORE := "high_score"
const KEY_FRENZY_HIGH_SCORE := "frenzy_high_score"
const SECTION_AUDIO := "audio"
const KEY_SFX_ENABLED := "sfx_enabled"

var _config := ConfigFile.new()
var _high_score: int = 0
var _frenzy_high_score: int = 0
var _sfx_enabled: bool = true


func _ready() -> void:
	_load()


func _load() -> void:
	var err := _config.load(SAVE_PATH)
	if err == OK:
		_high_score = int(_config.get_value(SECTION_STATS, KEY_HIGH_SCORE, 0))
		_frenzy_high_score = int(_config.get_value(SECTION_STATS, KEY_FRENZY_HIGH_SCORE, 0))
		_sfx_enabled = bool(_config.get_value(SECTION_AUDIO, KEY_SFX_ENABLED, true))
	else:
		_high_score = 0
		_frenzy_high_score = 0
		_sfx_enabled = true


func _save() -> void:
	_config.set_value(SECTION_STATS, KEY_HIGH_SCORE, _high_score)
	_config.set_value(SECTION_STATS, KEY_FRENZY_HIGH_SCORE, _frenzy_high_score)
	_config.set_value(SECTION_AUDIO, KEY_SFX_ENABLED, _sfx_enabled)
	_config.save(SAVE_PATH)


func get_high_score(mode: GameMode.Mode = GameMode.Mode.NORMAL) -> int:
	if mode == GameMode.Mode.FRENZY:
		return _frenzy_high_score
	return _high_score


func try_update_high_score(score: int, mode: GameMode.Mode = GameMode.Mode.NORMAL) -> bool:
	if mode == GameMode.Mode.FRENZY:
		if score > _frenzy_high_score:
			_frenzy_high_score = score
			_save()
			return true
		return false
	if score > _high_score:
		_high_score = score
		_save()
		return true
	return false


func is_sfx_enabled() -> bool:
	return _sfx_enabled


func set_sfx_enabled(enabled: bool) -> void:
	if _sfx_enabled == enabled:
		return
	_sfx_enabled = enabled
	_save()
