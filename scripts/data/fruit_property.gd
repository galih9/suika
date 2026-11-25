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
	match prop:
		Type.STICKY:
			return "Sticky"
		Type.BOMB:
			return "Bomb"
		Type.NUCLEAR:
			return "Nuclear"
		Type.CONCRETE:
			return "Concrete"
		Type.CHARGED:
			return "Charged"
		_:
			return ""


static func get_short_label(prop: Type) -> String:
	match prop:
		Type.STICKY:
			return "STICKY"
		Type.BOMB:
			return "BOMB"
		Type.NUCLEAR:
			return "NUKE"
		Type.CONCRETE:
			return "CONCRETE"
		Type.CHARGED:
			return "CHARGED"
		_:
			return ""


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
			return Color("#66BB6A")
		Type.BOMB:
			return Color("#EF5350")
		Type.NUCLEAR:
			return Color("#AEEA00")
		Type.CONCRETE:
			return Color("#78909C")
		Type.CHARGED:
			return Color("#00E5FF")
		_:
			return Color.WHITE


static func get_accent_color(prop: Type) -> Color:
	match prop:
		Type.STICKY:
			return Color("#2E7D32")
		Type.BOMB:
			return Color("#B71C1C")
		Type.NUCLEAR:
			return Color("#558B2F")
		Type.CONCRETE:
			return Color("#37474F")
		Type.CHARGED:
			return Color("#00838F")
		_:
			return Color("#6D4C41")
