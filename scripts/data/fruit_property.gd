class_name FruitProperty
extends RefCounted

## Defines Frenzy mode fruit properties and visual/display helpers.

enum Type {
	NONE,
	STICKY,
	BOMB,
	NUCLEAR,
	CONCRETE,
	CHARGED,
	LOW_GRAVITY,
	SHADOW,
}

const FRENZY_TYPES: Array[Type] = [
	Type.STICKY,
	Type.BOMB,
	Type.NUCLEAR,
	Type.CONCRETE,
	Type.CHARGED,
	Type.LOW_GRAVITY,
	Type.SHADOW,
]
const BASE_FRENZY_TYPES: Array[Type] = [
	Type.STICKY,
	Type.CHARGED,
	Type.LOW_GRAVITY,
	Type.SHADOW,
]
const WAVE_UNLOCK_BOMB := 2
const WAVE_UNLOCK_CONCRETE := 4
const WAVE_UNLOCK_NUCLEAR := 6
const FRENZY_SPAWN_CHANCE := 0.20
const FRENZY_SPAWN_CHANCE_STEP := 0.05
const FRENZY_LATE_SPAWN_CHANCE_STEP := 0.08
const FRENZY_MAX_SPAWN_CHANCE := 0.85


static func pick_random(rng: RandomNumberGenerator) -> Type:
	if FRENZY_TYPES.is_empty():
		return Type.NONE
	var idx := rng.randi_range(0, FRENZY_TYPES.size() - 1)
	return FRENZY_TYPES[idx]


static func pick_for_frenzy(rng: RandomNumberGenerator, chance: float = FRENZY_SPAWN_CHANCE) -> Type:
	if rng != null and rng.randf() < chance:
		return pick_random(rng)
	return Type.NONE


static func get_available_types_for_wave(wave: int) -> Array[Type]:
	var available := BASE_FRENZY_TYPES.duplicate()
	if wave >= WAVE_UNLOCK_BOMB:
		available.append(Type.BOMB)
	if wave >= WAVE_UNLOCK_CONCRETE:
		available.append(Type.CONCRETE)
	if wave >= WAVE_UNLOCK_NUCLEAR:
		available.append(Type.NUCLEAR)
	return available


static func get_obstacle_unlocked_at_wave(wave: int) -> Type:
	match wave:
		WAVE_UNLOCK_BOMB:
			return Type.BOMB
		WAVE_UNLOCK_CONCRETE:
			return Type.CONCRETE
		WAVE_UNLOCK_NUCLEAR:
			return Type.NUCLEAR
		_:
			return Type.NONE


static func get_spawn_chance_for_wave(wave: int) -> float:
	var w := maxi(wave, 1)
	if w <= WAVE_UNLOCK_NUCLEAR:
		return FRENZY_SPAWN_CHANCE + FRENZY_SPAWN_CHANCE_STEP * float(w - 1)
	var late_base := FRENZY_SPAWN_CHANCE + FRENZY_SPAWN_CHANCE_STEP * float(WAVE_UNLOCK_NUCLEAR - 1)
	return minf(late_base + FRENZY_LATE_SPAWN_CHANCE_STEP * float(w - WAVE_UNLOCK_NUCLEAR), FRENZY_MAX_SPAWN_CHANCE)


static func pick_for_frenzy_wave(rng: RandomNumberGenerator, wave: int) -> Type:
	var chance := get_spawn_chance_for_wave(wave)
	if rng == null or rng.randf() >= chance:
		return Type.NONE
	var pool := get_available_types_for_wave(wave)
	if pool.is_empty():
		return Type.NONE
	return pool[rng.randi_range(0, pool.size() - 1)]


static func get_display_name(prop: Type) -> String:
	return Loc.prop_name(prop)


static func get_short_label(prop: Type) -> String:
	return Loc.prop_short(prop)


static func get_letter(prop: Type) -> String:
	match prop:
		Type.STICKY:
			return "S"
		Type.BOMB:
			return "B"
		Type.NUCLEAR:
			return "N"
		Type.CONCRETE:
			return "C"
		Type.CHARGED:
			return "CH"
		Type.LOW_GRAVITY:
			return "LG"
		Type.SHADOW:
			return "SH"
		_:
			return ""


static func get_color(prop: Type) -> Color:
	match prop:
		Type.STICKY:
			return Color("#FFD43B")
		Type.BOMB:
			return Color("#EF5350")
		Type.NUCLEAR:
			return Color("#AEEA00")
		Type.CONCRETE:
			return Color("#9AA3A8")
		Type.CHARGED:
			return Color("#4FA3FF")
		Type.LOW_GRAVITY:
			return Color("#2DD4BF")
		Type.SHADOW:
			return Color("#6D3FC7")
		_:
			return Color.WHITE


static func get_accent_color(prop: Type) -> Color:
	match prop:
		Type.STICKY:
			return Color("#B58900")
		Type.BOMB:
			return Color("#B71C1C")
		Type.NUCLEAR:
			return Color("#558B2F")
		Type.CONCRETE:
			return Color("#37474F")
		Type.CHARGED:
			return Color("#1E5FD6")
		Type.LOW_GRAVITY:
			return Color("#0F766E")
		Type.SHADOW:
			return Color("#311B6E")
		_:
			return Color("#6D4C41")


## Outline drawn around the fruit sprite by the property shader (Sticky, Concrete, Charged, Low Gravity, Shadow).
static func get_outline_color(prop: Type) -> Color:
	match prop:
		Type.STICKY:
			return Color("#FFC400")
		Type.CONCRETE:
			return Color("#5F6B73")
		Type.CHARGED:
			return Color("#2F80FF")
		Type.LOW_GRAVITY:
			return Color("#0D9488")
		Type.SHADOW:
			return Color("#240F4A")
		_:
			return Color(0.0, 0.0, 0.0, 0.0)


## How strongly the property colour filters the fruit sprite (0 = untouched).
static func get_tint_strength(prop: Type) -> float:
	match prop:
		Type.STICKY:
			return 0.7
		Type.CONCRETE:
			return 0.85
		Type.CHARGED:
			return 0.75
		Type.LOW_GRAVITY:
			return 0.72
		Type.SHADOW:
			return 0.86
		_:
			return 0.0
