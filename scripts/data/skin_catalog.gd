class_name SkinCatalog
extends RefCounted

## Ordered registry of available fruit skins.

const DEFAULT_SKIN_ID := "classic"

var skins: Array[SkinDefinition] = []
var _by_id: Dictionary = {}


func _init() -> void:
	_register_defaults()


func _register_defaults() -> void:
	skins.clear()
	_by_id.clear()

	var classic := SkinDefinition.new()
	classic.id = "classic"
	classic.name_key = "skin.classic"
	classic.desc_key = "skin.classic.desc"
	classic.sprite_path_format = "res://assets/fruit_%d.tres"
	classic.accent_color = UITheme.GREEN
	classic.accent_shadow = UITheme.GREEN_SHADOW
	classic.preview_levels = [0, 3, 6, 11, 14]
	classic.unlocked_by_default = true
	classic.ads_required = 0
	register_skin(classic)

	var rotten := SkinDefinition.new()
	rotten.id = "rotten"
	rotten.name_key = "skin.rotten"
	rotten.desc_key = "skin.rotten.desc"
	rotten.sprite_path_format = "res://assets/skins/rotten/rotten_fruit_%d.tres"
	rotten.accent_color = Color("#8CA852")
	rotten.accent_shadow = Color("#5D7430")
	rotten.preview_levels = [0, 3, 6, 11, 14]
	rotten.unlocked_by_default = false
	rotten.ads_required = 1
	register_skin(rotten)

	var livestock := SkinDefinition.new()
	livestock.id = "livestock"
	livestock.name_key = "skin.livestock"
	livestock.desc_key = "skin.livestock.desc"
	livestock.sprite_path_format = "res://assets/skins/livestock/livestock_%d.tres"
	livestock.accent_color = UITheme.ORANGE
	livestock.accent_shadow = UITheme.ORANGE_SHADOW
	livestock.preview_levels = [0, 3, 6, 11, 14]
	livestock.unlocked_by_default = false
	livestock.ads_required = 1
	register_skin(livestock)


func register_skin(def: SkinDefinition) -> void:
	if def == null or def.id.is_empty():
		return
	if _by_id.has(def.id):
		var idx := skins.find(_by_id[def.id])
		if idx >= 0:
			skins[idx] = def
		else:
			skins.append(def)
	else:
		skins.append(def)
	_by_id[def.id] = def


func get_skins() -> Array[SkinDefinition]:
	return skins


func get_count() -> int:
	return skins.size()


func has_skin(skin_id: String) -> bool:
	return _by_id.has(skin_id)


func get_skin(skin_id: String) -> SkinDefinition:
	return _by_id.get(skin_id, null) as SkinDefinition


func get_skin_or_default(skin_id: String) -> SkinDefinition:
	var found := get_skin(skin_id)
	if found != null:
		return found
	var fallback := get_skin(DEFAULT_SKIN_ID)
	if fallback != null:
		return fallback
	return skins[0] if not skins.is_empty() else null
