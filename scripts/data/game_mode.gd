class_name GameMode
extends RefCounted

## Defines available game modes and display labels.

enum Mode {
	NORMAL,
	FRENZY,
}


static func get_display_name(mode: Mode) -> String:
	match mode:
		Mode.FRENZY:
			return "Frenzy"
		_:
			return "Normal"


static func get_badge_text(mode: Mode) -> String:
	match mode:
		Mode.FRENZY:
			return "FRENZY"
		_:
			return "NORMAL"
