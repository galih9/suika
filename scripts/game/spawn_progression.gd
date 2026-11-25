class_name SpawnProgression
extends RefCounted

## Tracks per-run unlocked fruit levels so new runs start strictly with Kersen (level 0)
## and higher droppable tiers unlock only after being created by a merge.

var current_level: int = 0
var next_level: int = 0
var highest_unlocked_level: int = 0
var _unlocked_levels: Dictionary = {0: true}


func reset(_catalog: FruitCatalog) -> void:
	_unlocked_levels.clear()
	_unlocked_levels[0] = true
	highest_unlocked_level = 0
	current_level = 0
	next_level = 0


func unlock_level(level: int) -> bool:
	if level < 0:
		return false
	if _unlocked_levels.get(level, false):
		return false
	_unlocked_levels[level] = true
	highest_unlocked_level = maxi(highest_unlocked_level, level)
	return true


func is_level_unlocked(level: int) -> bool:
	return bool(_unlocked_levels.get(level, false))


func get_unlocked_levels_copy() -> Dictionary:
	return _unlocked_levels.duplicate()


func consume_and_advance(catalog: FruitCatalog, rng: RandomNumberGenerator) -> int:
	var dropped := current_level
	current_level = next_level
	if catalog != null:
		next_level = catalog.pick_spawn_level_for_unlocked(rng, _unlocked_levels)
	else:
		next_level = 0
	return dropped
