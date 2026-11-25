extends Node

## Central autoload providing the fruit catalog and the sprite-based fruit/power-up visuals.

var catalog: FruitCatalog
var textures: FruitTextureCache


func _ready() -> void:
	catalog = FruitCatalog.new()
	textures = FruitTextureCache.new()


func warm_up(_host: Node = null) -> void:
	ensure_textures_ready()


func ensure_textures_ready() -> void:
	if not textures.is_baked():
		textures.build(catalog)
