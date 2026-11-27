extends Node

## Central autoload providing the fruit catalog, skin catalog, and sprite-based fruit/power-up visuals.

signal skin_changed(skin_id: String)

var catalog: FruitCatalog
var skins: SkinCatalog
var textures: FruitTextureCache
var active_skin_id: String = SkinCatalog.DEFAULT_SKIN_ID


func _ready() -> void:
	catalog = FruitCatalog.new()
	skins = SkinCatalog.new()
	textures = FruitTextureCache.new()
	var saved_skin := skins.get_skin_or_default(SaveManager.get_skin_id())
	if saved_skin != null and is_skin_unlocked(saved_skin.id):
		active_skin_id = saved_skin.id
	else:
		active_skin_id = SkinCatalog.DEFAULT_SKIN_ID


func warm_up(_host: Node = null) -> void:
	ensure_textures_ready()


func ensure_textures_ready() -> void:
	if not textures.is_baked() or textures.get_skin_id() != active_skin_id:
		textures.build(catalog, get_active_skin())


func get_active_skin() -> SkinDefinition:
	return skins.get_skin_or_default(active_skin_id)


func is_skin_unlocked(skin_id: String) -> bool:
	var skin := skins.get_skin(skin_id)
	if skin == null:
		return false
	return skin.unlocked_by_default or SaveManager.is_skin_unlocked(skin_id)


func unlock_skin(skin_id: String) -> bool:
	if not skins.has_skin(skin_id):
		return false
	return SaveManager.unlock_skin(skin_id)


func set_skin(skin_id: String, persist: bool = true) -> bool:
	if not skins.has_skin(skin_id) or not is_skin_unlocked(skin_id):
		return false
	if active_skin_id == skin_id:
		ensure_textures_ready()
		return false
	active_skin_id = skin_id
	if persist:
		SaveManager.set_skin_id(skin_id)
	textures.build(catalog, get_active_skin())
	skin_changed.emit(active_skin_id)
	return true
