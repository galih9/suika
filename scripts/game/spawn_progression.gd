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
##  - after the opening, three tiny fruits in a row get one reroll,
##  - score raises a "floor": from SCORE_FLOOR_START points the smallest tier stops dropping,
##    and every SCORE_FLOOR_STEP points after that the next one does too (Blueberry at 500,
##    Cherry at 800, Strawberry at 1100, ...). Fruits under the floor keep a small
##    BELOW_FLOOR_CHANCE so a tiny one still sneaks in now and then.

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

## Score floor: at SCORE_FLOOR_START the floor becomes level 1 (no more Blueberry), then +1
## level every SCORE_FLOOR_STEP points, up to MAX_FLOOR_LEVEL.
const SCORE_FLOOR_START := 500
const SCORE_FLOOR_STEP := 300
const MAX_FLOOR_LEVEL := 6
## Total chance (0..1) that a drop is still a fruit below the floor.
const BELOW_FLOOR_CHANCE := 0.04
## Once the floor rises, at least this many tiers above it can drop too...
const FLOOR_WINDOW_EXTRA := 2
## ...but never bigger than this level (8 = Apple).
const MAX_DROP_LEVEL_CAP := 8
## Tiers above the end of the current phase table taper off from its last weight:
## last * FALLOFF, last * FALLOFF^2, ... (so bigger fruits are always rarer).
const ABOVE_TABLE_FALLOFF := 0.6

## Set by the board whenever the score changes.
var current_score: int = 0

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
	current_score = 0
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


## Floor from score alone (0 = no floor).
func get_score_floor() -> int:
	if current_score < SCORE_FLOOR_START:
		return 0
	@warning_ignore("integer_division")
	var steps := (current_score - SCORE_FLOOR_START) / SCORE_FLOOR_STEP
	return mini(1 + steps, MAX_FLOOR_LEVEL)


## Lowest level that normally drops right now (never above what was made this run).
func get_floor_level() -> int:
	return mini(get_score_floor(), get_chain_level())


## Biggest level that can currently drop.
func get_max_drop_level() -> int:
	var weights: Array = PHASES[get_phase()]["weights"]
	var top := weights.size() - 1
	var floor_lvl := get_floor_level()
	if floor_lvl > 0:
		top = maxi(top, floor_lvl + FLOOR_WINDOW_EXTRA)
	return mini(mini(top, MAX_DROP_LEVEL_CAP), get_chain_level())


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
	var top := get_max_drop_level()
	if catalog != null:
		top = mini(top, catalog.get_count() - 1)
	var floor_lvl := mini(get_floor_level(), top)
	var out := PackedFloat32Array()
	out.resize(top + 1)

	# Normal pool: floor..top.
	var main_total := 0.0
	for i in range(floor_lvl, top + 1):
		var w := 0.0
		if i < base.size():
			w = float(base[i])
		else:
			w = float(base[base.size() - 1]) * pow(ABOVE_TABLE_FALLOFF, float(i - base.size() + 1))
		out[i] = w
		main_total += w

	# Below the floor: a small shared chance so a tiny fruit still shows up once in a while.
	if floor_lvl > 0 and main_total > 0.0 and BELOW_FLOOR_CHANCE > 0.0:
		var below_total := main_total * BELOW_FLOOR_CHANCE / (1.0 - BELOW_FLOOR_CHANCE)
		for i in range(floor_lvl):
			out[i] = below_total / float(floor_lvl)
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
