class_name FruitTextureCache
extends RefCounted

## Single-atlas procedural fruit texture baker for batched 2D rendering.

const CELL_SIZE := 320
const DRAW_RADIUS := 128.0
const COLS := 4
const HEADLESS_CELL_SIZE := 32

var _atlas_texture: ImageTexture
var _textures: Dictionary = {}
var _is_baked: bool = false
var _baked_draw_radius: float = DRAW_RADIUS


func is_baked() -> bool:
	return _is_baked


func get_sprite_scale_for_radius(radius: float) -> float:
	if _baked_draw_radius <= 0.0:
		return 1.0
	return radius / _baked_draw_radius


func get_texture(level: int) -> Texture2D:
	return _textures.get(level, null)


func bake_async(host: Node, catalog: FruitCatalog) -> void:
	if _is_baked or catalog == null:
		return

	var count := catalog.get_count()
	if count == 0:
		return

	# Headless environments have no GPU surface; build a lightweight CPU atlas immediately.
	if DisplayServer.get_name() == "headless":
		_bake_cpu_fallback(catalog)
		return

	var rows := ceili(float(count) / float(COLS))
	var atlas_size := Vector2i(COLS * CELL_SIZE, rows * CELL_SIZE)

	var viewport := SubViewport.new()
	viewport.size = atlas_size
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	var painter := FruitPainter.new()
	painter.catalog = catalog
	painter.cell_size = CELL_SIZE
	painter.cols = COLS
	painter.draw_radius = DRAW_RADIUS
	viewport.add_child(painter)
	host.add_child(viewport)
	painter.queue_redraw()

	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = null
	var vp_tex := viewport.get_texture()
	if vp_tex != null:
		img = vp_tex.get_image()

	viewport.queue_free()

	if img == null or img.is_empty():
		_bake_cpu_fallback(catalog)
		return

	_finalize_atlas_from_image(img, catalog, CELL_SIZE, DRAW_RADIUS)


func bake_sync_fallback(catalog: FruitCatalog) -> void:
	if _is_baked or catalog == null:
		return
	_bake_cpu_fallback(catalog)


func _bake_cpu_fallback(catalog: FruitCatalog) -> void:
	var count := catalog.get_count()
	if count == 0:
		return
	var rows := ceili(float(count) / float(COLS))
	var cell := HEADLESS_CELL_SIZE
	var img := Image.create(COLS * cell, rows * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var r := float(cell) * 0.42
	var r_sq := r * r
	for i in range(count):
		var def := catalog.get_fruit(i)
		if def == null:
			continue
		var col := i % COLS
		@warning_ignore("integer_division")
		var row := i / COLS
		var cx := (float(col) + 0.5) * float(cell)
		var cy := (float(row) + 0.5) * float(cell)
		for y in range(row * cell, (row + 1) * cell):
			for x in range(col * cell, (col + 1) * cell):
				var dx := float(x) + 0.5 - cx
				var dy := float(y) + 0.5 - cy
				var dist_sq := dx * dx + dy * dy
				if dist_sq <= r_sq:
					var pixel_color := def.outline_color if dist_sq >= (r - 2.0) * (r - 2.0) else def.primary_color
					img.set_pixel(x, y, pixel_color)

	_finalize_atlas_from_image(img, catalog, cell, r)


func _finalize_atlas_from_image(img: Image, catalog: FruitCatalog, cell: int, draw_r: float) -> void:
	_baked_draw_radius = draw_r
	_atlas_texture = ImageTexture.create_from_image(img)
	_textures.clear()
	for i in range(catalog.get_count()):
		var col := i % COLS
		@warning_ignore("integer_division")
		var row := i / COLS
		var atlas := AtlasTexture.new()
		atlas.atlas = _atlas_texture
		atlas.region = Rect2(col * cell, row * cell, cell, cell)
		_textures[i] = atlas
	_is_baked = true
