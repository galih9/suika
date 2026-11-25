class_name FruitTextureCache
extends RefCounted

## Serves the pixel-art fruit sprites (from the spritesheet AtlasTextures) plus the shared
## power-up icons and tint/outline materials. Everything comes from one atlas and a handful
## of shared resources, so fruits batch well and nothing is drawn procedurally.

## Transparent texels added around each sprite region so the outline shader has room to draw.
## The spritesheet keeps a 2px gap between fruits, so 1px never bleeds into a neighbour.
const SPRITE_MARGIN := 1.0
const EFFECT_SHADER_PATH := "res://shaders/fruit_property_effect.gdshader"
const BOMB_ICON_PATH := "res://assets/powerup_bomb.png"
const NUCLEAR_ICON_PATH := "res://assets/powerup_nuclear.png"

var _textures: Dictionary = {}       # level -> Texture2D (region with margin)
var _sprite_scales: Dictionary = {}  # level -> float, makes sprite width == 2 * radius
var _icons: Dictionary = {}          # FruitProperty.Type -> Texture2D
var _materials: Dictionary = {}      # FruitProperty.Type -> ShaderMaterial
var _palettes: Dictionary = {}       # level -> PackedColorArray (dominant sprite colours)
var _catalog: FruitCatalog
var _is_baked: bool = false


func is_baked() -> bool:
	return _is_baked


func get_texture(level: int) -> Texture2D:
	return _textures.get(level, null)


func get_sprite_scale(level: int) -> float:
	return float(_sprite_scales.get(level, 1.0))


func get_property_icon(prop: FruitProperty.Type) -> Texture2D:
	return _icons.get(prop, null)


## Shared material for Sticky / Concrete / Charged, or null for properties without a tint.
func get_property_material(prop: FruitProperty.Type) -> ShaderMaterial:
	return _materials.get(prop, null)


## Up to 4 dominant colours of a fruit sprite (used for pixel merge debris). Sampled lazily
## from the spritesheet once per level; falls back to the catalog colours.
func get_palette(level: int) -> PackedColorArray:
	if _palettes.has(level):
		return _palettes[level]
	var palette := _sample_palette(level)
	_palettes[level] = palette
	return palette


func _sample_palette(level: int) -> PackedColorArray:
	var out := PackedColorArray()
	var def: FruitDefinition = _catalog.get_fruit(level) if _catalog != null else null
	if def != null and def.texture is AtlasTexture:
		var src := def.texture as AtlasTexture
		var img: Image = null
		if src.atlas != null:
			img = src.atlas.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var region := Rect2i(src.region)
			var counts: Dictionary = {}
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
						continue
					var c := img.get_pixel(x, y)
					# Skip transparent pixels, dark outlines and eye/mouth pixels.
					if c.a < 0.6 or c.get_luminance() < 0.18:
						continue
					var key := c.to_html(false)
					counts[key] = int(counts.get(key, 0)) + 1
			var keys: Array = counts.keys()
			keys.sort_custom(func(a, b) -> bool: return int(counts[a]) > int(counts[b]))
			for i in range(mini(keys.size(), 4)):
				out.append(Color.html(String(keys[i])))
	if out.is_empty():
		if def != null:
			out.append(def.primary_color)
			out.append(def.secondary_color)
			out.append(def.accent_color)
		else:
			out.append(Color.WHITE)
	return out


func build(catalog: FruitCatalog) -> void:
	if _is_baked or catalog == null:
		return
	_catalog = catalog

	_textures.clear()
	_sprite_scales.clear()
	for i in range(catalog.get_count()):
		var def := catalog.get_fruit(i)
		if def == null or def.texture == null:
			continue
		var content_px := 0.0
		if def.texture is AtlasTexture:
			var src := def.texture as AtlasTexture
			content_px = src.region.size.x
			_textures[i] = _make_padded_region(src)
		else:
			content_px = float(def.texture.get_width())
			_textures[i] = def.texture
		if content_px > 0.0:
			_sprite_scales[i] = (def.radius * 2.0) / content_px

	_build_power_up_visuals()
	_is_baked = true


func _make_padded_region(src: AtlasTexture) -> AtlasTexture:
	var padded := AtlasTexture.new()
	padded.atlas = src.atlas
	padded.filter_clip = false
	var region := src.region.grow(SPRITE_MARGIN)
	if src.atlas != null:
		var bounds := Rect2(Vector2.ZERO, Vector2(src.atlas.get_size()))
		region = region.intersection(bounds)
	padded.region = region
	return padded


func _build_power_up_visuals() -> void:
	_icons.clear()
	_materials.clear()

	var bomb_icon := load(BOMB_ICON_PATH) as Texture2D
	if bomb_icon != null:
		_icons[FruitProperty.Type.BOMB] = bomb_icon
	var nuclear_icon := load(NUCLEAR_ICON_PATH) as Texture2D
	if nuclear_icon != null:
		_icons[FruitProperty.Type.NUCLEAR] = nuclear_icon

	var shader := load(EFFECT_SHADER_PATH) as Shader
	if shader == null:
		return
	for prop in [FruitProperty.Type.STICKY, FruitProperty.Type.CONCRETE, FruitProperty.Type.CHARGED]:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("outline_color", FruitProperty.get_outline_color(prop))
		mat.set_shader_parameter("tint_color", FruitProperty.get_color(prop))
		mat.set_shader_parameter("tint_strength", FruitProperty.get_tint_strength(prop))
		_materials[prop] = mat
