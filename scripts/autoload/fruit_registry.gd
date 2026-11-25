extends Node

## Central autoload providing the fruit catalog and single-atlas baked textures.

var catalog: FruitCatalog
var textures: FruitTextureCache


func _ready() -> void:
	catalog = FruitCatalog.new()
	textures = FruitTextureCache.new()


func warm_up(host: Node) -> void:
	if textures.is_baked():
		return
	await textures.bake_async(host, catalog)


func ensure_textures_ready() -> void:
	if not textures.is_baked():
		textures.bake_sync_fallback(catalog)
