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
}

const FRENZY_TYPES: Array[Type] = [
	Type.STICKY,
	Type.BOMB,
	Type.NUCLEAR,
	Type.CONCRETE,
	Type.CHARGED,
]
const FRENZY_SPAWN_CHANCE := 0.20


static func pick_random(rng: RandomNumberGenerator) -> Type:
	if FRENZY_TYPES.is_empty():
		return Type.NONE
	var idx := rng.randi_range(0, FRENZY_TYPES.size() - 1)
	return FRENZY_TYPES[idx]


static func pick_for_frenzy(rng: RandomNumberGenerator, chance: float = FRENZY_SPAWN_CHANCE) -> Type:
	if rng != null and rng.randf() < chance:
		return pick_random(rng)
	return Type.NONE


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
		_:
			return Color("#6D4C41")


## Outline drawn around the fruit sprite by the property shader (Sticky, Concrete, Charged).
static func get_outline_color(prop: Type) -> Color:
	match prop:
		Type.STICKY:
			return Color("#FFC400")
		Type.CONCRETE:
			return Color("#5F6B73")
		Type.CHARGED:
			return Color("#2F80FF")
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
		_:
			return 0.0
