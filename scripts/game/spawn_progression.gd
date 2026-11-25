class_name SpawnProgression
extends RefCounted

## Decides which fruit drops next.
##
## Like the original Suika Game, only small fruits ever drop and they are picked at random —
## but because Fruityzer's chain is longer (15 tiers vs Suika's 11), the drop pool grows with
## the run so late games don't drag on with endless Blueberries:
##  - a run starts with only Blueberry; a tier can drop once it has been made this run,
##  - the odds shift toward bigger fruit as the biggest fruit made this run grows (PHASES),
##  - late phases also unlock Lime (tier 6) and Orange (tier 7) as drops,
##  - after the opening, three tiny fruits in a row get one reroll.

## Each phase starts once a fruit of at least `min_level` (0-based) has been made this run.
## `weights[i]` is the relative chance of level i; levels past the end of the array never drop.
const PHASES: Array[Dictionary] = [
	{"min_level": 0, "weights": [30.0, 25.0, 20.0, 15.0, 10.0]},           # Start: small-biased
	{"min_level": 6, "weights": [18.0, 22.0, 22.0, 20.0, 18.0]},           # Made Orange: ~even, like Suika
	{"min_level": 9, "weights": [10.0, 16.0, 22.0, 22.0, 18.0, 12.0]},     # Made Pear: Lime can drop
	{"min_level": 11, "weights": [5.0, 11.0, 18.0, 22.0, 21.0, 15.0, 8.0]},# Made Dragonfruit: Orange can drop
]
## Levels counted as "tiny" for the anti-streak reroll (Blueberry, Cherry).
const TINY_MAX_LEVEL := 1
const STREAK_LIMIT := 3

var current_level: int = 0
var next_level: int = 0
var highest_unlocked_level: int = 0
var _unlocked_levels: Dictionary = {0: true}
var _history: Array[int] = []


func reset(_catalog: FruitCatalog) -> void:
	_unlocked_levels.clear()
	_unlocked_levels[0] = true
	highest_unlocked_level = 0
	current_level = 0
	next_level = 0
	_history.clear()


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


## Highest level L such that every level 0..L has been made this run.
func get_chain_level() -> int:
	var lvl := 0
	while is_level_unlocked(lvl + 1):
		lvl += 1
	return lvl


## Index into PHASES for the current run progress.
func get_phase() -> int:
	var chain := get_chain_level()
	var phase := 0
	for i in range(PHASES.size()):
		if chain >= int(PHASES[i]["min_level"]):
			phase = i
	return phase


## Biggest level that can currently drop.
func get_max_drop_level() -> int:
	var weights: Array = PHASES[get_phase()]["weights"]
	return mini(weights.size() - 1, get_chain_level())


## Current drop chances as {level: probability 0..1} (for tests / debugging / UI).
func get_drop_chances(catalog: FruitCatalog = null) -> Dictionary:
	var weights := _current_weights(catalog)
	var total := 0.0
	for w in weights:
		total += w
	var out := {}
	for i in range(weights.size()):
		if weights[i] > 0.0 and total > 0.0:
			out[i] = weights[i] / total
	return out


func consume_and_advance(catalog: FruitCatalog, rng: RandomNumberGenerator) -> int:
	var dropped := current_level
	_history.append(dropped)
	if _history.size() > 8:
		_history.pop_front()
	current_level = next_level
	next_level = _pick_next(catalog, rng)
	return dropped


func _pick_next(catalog: FruitCatalog, rng: RandomNumberGenerator) -> int:
	var weights := _current_weights(catalog)
	var pick := _roll(weights, rng)
	# Anti-streak: after the opening, don't serve a third tiny fruit in a row (one reroll).
	if get_phase() >= 1 and pick <= TINY_MAX_LEVEL and _tiny_streak() >= STREAK_LIMIT - 1:
		pick = _roll(weights, rng)
	return pick


## Count of tiny fruits at the end of the queue (already dropped + the one now held).
func _tiny_streak() -> int:
	var seq: Array[int] = _history.duplicate()
	seq.append(current_level)
	var n := 0
	for i in range(seq.size() - 1, -1, -1):
		if seq[i] <= TINY_MAX_LEVEL:
			n += 1
		else:
			break
	return n


func _current_weights(catalog: FruitCatalog) -> PackedFloat32Array:
	var base: Array = PHASES[get_phase()]["weights"]
	var chain := get_chain_level()
	var count := catalog.get_count() if catalog != null else base.size()
	var out := PackedFloat32Array()
	out.resize(mini(base.size(), count))
	for i in range(out.size()):
		# Only tiers made this run (as an unbroken chain from Blueberry) can drop.
		out[i] = float(base[i]) if i <= chain else 0.0
	return out


func _roll(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var roll := rng.randf_range(0.0, total) if rng != null else randf() * total
	var accum := 0.0
	for i in range(weights.size()):
		if weights[i] <= 0.0:
			continue
		accum += weights[i]
		if roll <= accum:
			return i
	return 0
