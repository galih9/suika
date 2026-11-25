class_name FruitDefinition
extends Resource

## Data resource describing one fruit tier in the merge hierarchy.

enum PatternType {
	KERSEN,
	DUKUH,
	RAMBUTAN,
	SALAK,
	JAMBU_BIJI,
	MANGGIS,
	KELAPA,
	GENERIC_STRIPED,
	GENERIC_DOTTED,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var level: int = 0
@export var radius: float = 24.0
@export var score: int = 1
@export var mass: float = 1.0
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.GRAY
@export var accent_color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK
@export var pattern_type: PatternType = PatternType.GENERIC_DOTTED
@export var spawn_weight: float = 0.0
