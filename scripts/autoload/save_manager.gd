extends Node

## Persists high scores, audio preference, the fruit collection (fruits ever discovered),
## seen power-up tips and a few lifetime stats in user://save_data.cfg.

signal fruit_discovered(level: int)

const SAVE_PATH := "user://save_data.cfg"
## The game used to be called "Fruity-zer" and before that "Buah Merge". On desktop Godot keeps
## user data in a folder named after the project, so old saves live next to the new folder.
## The newest one found is copied over once.
const LEGACY_APP_DIR_NAMES: Array[String] = ["Fruity-zer", "Buah Merge"]
const SECTION_STATS := "stats"
const KEY_HIGH_SCORE := "high_score"
const KEY_FRENZY_HIGH_SCORE := "frenzy_high_score"
const KEY_TOTAL_MERGES := "total_merges"
const KEY_GAMES_PLAYED := "games_played"
const SECTION_AUDIO := "audio"
const KEY_SFX_ENABLED := "sfx_enabled"
const SECTION_SETTINGS := "settings"
const KEY_LANGUAGE := "language"
const KEY_SKIN := "skin"
const SECTION_COLLECTION := "collection"
const KEY_DISCOVERED := "discovered_mask"
const KEY_SEEN_POWERUPS := "seen_powerups_mask"

var _config := ConfigFile.new()
var _high_score: int = 0
var _frenzy_high_score: int = 0
var _sfx_enabled: bool = true
var _discovered_mask: int = 1
var _seen_powerups_mask: int = 0
var _total_merges: int = 0
var _games_played: int = 0
var _language: String = ""
var _skin_id: String = SkinCatalog.DEFAULT_SKIN_ID


func _ready() -> void:
	_load()


func _load() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		err = _try_load_legacy_save()
	if err == OK:
		_high_score = int(_config.get_value(SECTION_STATS, KEY_HIGH_SCORE, 0))
		_frenzy_high_score = int(_config.get_value(SECTION_STATS, KEY_FRENZY_HIGH_SCORE, 0))
		_total_merges = int(_config.get_value(SECTION_STATS, KEY_TOTAL_MERGES, 0))
		_games_played = int(_config.get_value(SECTION_STATS, KEY_GAMES_PLAYED, 0))
		_sfx_enabled = bool(_config.get_value(SECTION_AUDIO, KEY_SFX_ENABLED, true))
		_discovered_mask = int(_config.get_value(SECTION_COLLECTION, KEY_DISCOVERED, 1))
		_seen_powerups_mask = int(_config.get_value(SECTION_COLLECTION, KEY_SEEN_POWERUPS, 0))
		_language = String(_config.get_value(SECTION_SETTINGS, KEY_LANGUAGE, ""))
		_skin_id = String(_config.get_value(SECTION_SETTINGS, KEY_SKIN, SkinCatalog.DEFAULT_SKIN_ID))
	else:
		_high_score = 0
		_frenzy_high_score = 0
		_total_merges = 0
		_games_played = 0
		_sfx_enabled = true
		_discovered_mask = 1
		_seen_powerups_mask = 0
		_skin_id = SkinCatalog.DEFAULT_SKIN_ID
	# The first fruit (Blueberry) is always known.
	_discovered_mask |= 1


func _save() -> void:
	_config.set_value(SECTION_STATS, KEY_HIGH_SCORE, _high_score)
	_config.set_value(SECTION_STATS, KEY_FRENZY_HIGH_SCORE, _frenzy_high_score)
	_config.set_value(SECTION_STATS, KEY_TOTAL_MERGES, _total_merges)
	_config.set_value(SECTION_STATS, KEY_GAMES_PLAYED, _games_played)
	_config.set_value(SECTION_AUDIO, KEY_SFX_ENABLED, _sfx_enabled)
	_config.set_value(SECTION_COLLECTION, KEY_DISCOVERED, _discovered_mask)
	_config.set_value(SECTION_COLLECTION, KEY_SEEN_POWERUPS, _seen_powerups_mask)
	_config.set_value(SECTION_SETTINGS, KEY_LANGUAGE, _language)
	_config.set_value(SECTION_SETTINGS, KEY_SKIN, _skin_id)
	_config.save(SAVE_PATH)


## Loads a save from an old-name user folder (desktop only) and copies it over.
func _try_load_legacy_save() -> Error:
	var base := OS.get_user_data_dir().get_base_dir()
	for dir_name in LEGACY_APP_DIR_NAMES:
		var legacy_path := base.path_join(dir_name).path_join("save_data.cfg")
		if not FileAccess.file_exists(legacy_path):
			continue
		var err := _config.load(legacy_path)
		if err == OK:
			_config.save(SAVE_PATH)
			return OK
	return ERR_FILE_NOT_FOUND


# --- Settings -------------------------------------------------------------------------------

## Saved language code from Loc.LANGUAGES, or "" if the player never picked one.
func get_language() -> String:
	return _language


func set_language(code: String) -> void:
	if _language == code:
		return
	_language = code
	_save()


func get_skin_id() -> String:
	return _skin_id


func set_skin_id(skin_id: String) -> void:
	if _skin_id == skin_id:
		return
	_skin_id = skin_id
	_save()


# --- High scores ----------------------------------------------------------------------------

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


# --- Audio ----------------------------------------------------------------------------------

func is_sfx_enabled() -> bool:
	return _sfx_enabled


func set_sfx_enabled(enabled: bool) -> void:
	if _sfx_enabled == enabled:
		return
	_sfx_enabled = enabled
	_save()


# --- Fruit collection -----------------------------------------------------------------------

func is_discovered(level: int) -> bool:
	if level < 0 or level > 62:
		return false
	return (_discovered_mask & (1 << level)) != 0


## Marks a fruit as discovered. Returns true only the very first time (ever) it happens.
func discover(level: int) -> bool:
	if level < 0 or level > 62 or is_discovered(level):
		return false
	_discovered_mask |= (1 << level)
	_save()
	fruit_discovered.emit(level)
	return true


func get_discovered_count(total: int = 15) -> int:
	var count := 0
	for i in range(total):
		if is_discovered(i):
			count += 1
	return count


## Lowest-tier fruit that has never been made, or -1 when the collection is complete.
func get_next_undiscovered(total: int = 15) -> int:
	for i in range(total):
		if not is_discovered(i):
			return i
	return -1


# --- Power-up tips --------------------------------------------------------------------------

func has_seen_power_up(prop: int) -> bool:
	return (_seen_powerups_mask & (1 << prop)) != 0


func mark_power_up_seen(prop: int) -> void:
	if has_seen_power_up(prop):
		return
	_seen_powerups_mask |= (1 << prop)
	_save()


# --- Lifetime stats -------------------------------------------------------------------------

func get_total_merges() -> int:
	return _total_merges


func get_games_played() -> int:
	return _games_played


## Called once at the end of every run.
func record_run(merges: int) -> void:
	_total_merges += maxi(merges, 0)
	_games_played += 1
	_save()
