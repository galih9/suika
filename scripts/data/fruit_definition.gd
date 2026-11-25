class_name FruitDefinition
extends Resource

## Data resource describing one fruit tier in the merge hierarchy.

## Legacy: only used by the old procedural FruitPainter (scripts/data/fruit_painter.gd).
## Safe to delete together with that script.
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
## Sprite for this tier (an AtlasTexture region of the fruit spritesheet). The sprite is
## expected to be a circle filling its region; it is scaled so its width equals 2 * radius.
@export var texture: Texture2D
@export var spawn_weight: float = 0.0
