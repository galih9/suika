class_name SkinDefinition
extends RefCounted

## Metadata and asset path pattern for one visual skin set.

var id: String = ""
var name_key: String = ""
var desc_key: String = ""
var sprite_path_format: String = ""
var accent_color: Color = Color.WHITE
var accent_shadow: Color = Color.GRAY
var preview_levels: Array[int] = [0, 3, 6, 11, 14]
var unlocked_by_default: bool = false
var ads_required: int = 1


func get_texture_path(level: int) -> String:
	return sprite_path_format % (level + 1)


func load_texture(level: int) -> Texture2D:
	var path := get_texture_path(level)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
