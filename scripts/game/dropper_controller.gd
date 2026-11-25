class_name DropperController
extends Node2D

## Manages held-fruit preview, aim guide line, pointer drag/click input, and drop cooldown buffering.

signal drop_requested(spawn_x: float)

const DROP_COOLDOWN := 0.32

var drop_x: float = 0.0
var has_held_fruit: bool = false
var cooldown_timer: float = 0.0

var _is_pointer_down: bool = false
var _queued_drop: bool = false
var _queued_drop_x: float = 0.0
var _held_radius: float = 20.0
var _show_guide: bool = false
var _sprite: Sprite2D


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.visible = false
	add_child(_sprite)


func reset() -> void:
	drop_x = 0.0
	has_held_fruit = false
	cooldown_timer = 0.0
	_is_pointer_down = false
	_queued_drop = false
	_queued_drop_x = 0.0
	_held_radius = 20.0
	_show_guide = false
	_sprite.visible = false
	queue_redraw()


func show_held_fruit(level: int, jar: JarContainer = null) -> void:
	var def := FruitRegistry.catalog.get_fruit(level)
	var tex := FruitRegistry.textures.get_texture(level)
	_held_radius = def.radius if def != null else 20.0
	var s := FruitRegistry.textures.get_sprite_scale_for_radius(_held_radius)
	_sprite.texture = tex
	_sprite.scale = Vector2(s, s)

	if jar != null:
		drop_x = jar.clamp_drop_x(drop_x, _held_radius)
	else:
		var limit := JarContainer.INNER_HALF_WIDTH - _held_radius - 4.0
		drop_x = clampf(drop_x, -limit, limit)

	has_held_fruit = true
	_show_guide = true
	_sprite.visible = true
	_sprite.position = Vector2(drop_x, JarContainer.DROP_Y)
	queue_redraw()


func hide_guide() -> void:
	has_held_fruit = false
	_show_guide = false
	_sprite.visible = false
	queue_redraw()


func cancel_drag() -> void:
	_is_pointer_down = false
	_queued_drop = false


func start_cooldown() -> void:
	cooldown_timer = DROP_COOLDOWN
	hide_guide()


func tick(delta: float, next_held_level: int, jar: JarContainer) -> void:
	if cooldown_timer <= 0.0:
		return

	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if cooldown_timer > 0.0 or has_held_fruit:
		return

	if _queued_drop:
		_queued_drop = false
		var def := FruitRegistry.catalog.get_fruit(next_held_level)
		var next_radius := def.radius if def != null else 20.0
		_held_radius = next_radius
		drop_x = jar.clamp_drop_x(_queued_drop_x, next_radius)
		has_held_fruit = true
		drop_requested.emit(drop_x)
	else:
		show_held_fruit(next_held_level, jar)


func handle_input(event: InputEvent, board: Node2D, jar: JarContainer, can_interact: bool) -> void:
	if not can_interact or board == null or jar == null:
		return

	if event is InputEventMouseButton:
		var local_mb := board.make_input_local(event) as InputEventMouseButton
		if local_mb == null or local_mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var local_pos := local_mb.position
		if local_mb.pressed:
			if jar.is_in_play_zone(local_pos):
				_is_pointer_down = true
				_queued_drop = false
				_update_aim_x(local_pos.x, jar)
		elif _is_pointer_down:
			_is_pointer_down = false
			_update_aim_x(local_pos.x, jar)
			if has_held_fruit and cooldown_timer <= 0.0:
				drop_requested.emit(drop_x)
			elif cooldown_timer > 0.0:
				_queued_drop = true
				_queued_drop_x = drop_x
	elif event is InputEventMouseMotion:
		var local_mm := board.make_input_local(event) as InputEventMouseMotion
		if local_mm == null:
			return
		var local_pos := local_mm.position
		if _is_pointer_down:
			_update_aim_x(local_pos.x, jar)
		elif not _queued_drop and jar.is_in_play_zone(local_pos):
			_update_aim_x(local_pos.x, jar)


func _update_aim_x(local_x: float, jar: JarContainer) -> void:
	drop_x = jar.clamp_drop_x(local_x, _held_radius)
	if has_held_fruit and _show_guide:
		_sprite.position = Vector2(drop_x, JarContainer.DROP_Y)
		queue_redraw()


func _draw() -> void:
	if not _show_guide:
		return
	var y := JarContainer.DROP_Y + maxf(_held_radius, 20.0)
	var col := Color(0.45, 0.30, 0.18, 0.24)
	while y < JarContainer.FLOOR_Y - 12.0:
		var seg_end := minf(y + 10.0, JarContainer.FLOOR_Y - 12.0)
		draw_line(Vector2(drop_x, y), Vector2(drop_x, seg_end), col, 2.5, true)
		y += 22.0
