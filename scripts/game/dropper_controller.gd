class_name DropperController
extends Node2D

## Manages held-fruit preview, aim guide, pointer drag/click input, and drop cooldown buffering.
##
## The next fruit is shown as soon as the previous one drops (dimmed while the cooldown runs),
## so the player can keep aiming. A tap during the cooldown is queued and released from the
## preview's spot once the cooldown ends — the fruit never pops into existence out of nowhere.

signal drop_requested(spawn_x: float)

const DROP_COOLDOWN := 0.32
const COOLDOWN_ALPHA := 0.45
const GUIDE_PIXEL := 4.0

var drop_x: float = 0.0
var has_held_fruit: bool = false
var cooldown_timer: float = 0.0

var _is_pointer_down: bool = false
var _queued_drop: bool = false
var _queued_drop_x: float = 0.0
var _held_radius: float = 20.0
var _held_property: FruitProperty.Type = FruitProperty.Type.NONE
var _show_guide: bool = false
var _sprite: Sprite2D
var _overlay: FruitPropertyOverlay
var _pop_tween: Tween
var _sprite_scale: float = 1.0
var _bob_time: float = 0.0


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.visible = false
	add_child(_sprite)

	_overlay = FruitPropertyOverlay.new()
	_overlay.bind_target(_sprite)
	add_child(_overlay)


func _process(delta: float) -> void:
	if not has_held_fruit:
		return
	# Gentle idle bob so the held fruit feels alive.
	_bob_time += delta
	var bob := sin(_bob_time * 4.0) * 2.0
	_sprite.position = Vector2(drop_x, JarContainer.DROP_Y + bob)
	_overlay.position = _sprite.position


func reset() -> void:
	drop_x = 0.0
	has_held_fruit = false
	cooldown_timer = 0.0
	_is_pointer_down = false
	_queued_drop = false
	_queued_drop_x = 0.0
	_held_radius = 20.0
	_held_property = FruitProperty.Type.NONE
	_show_guide = false
	_kill_pop()
	_sprite.visible = false
	_sprite.modulate = Color.WHITE
	_overlay.reset()
	queue_redraw()


func show_held_fruit(
	level: int,
	jar: JarContainer = null,
	prop: FruitProperty.Type = FruitProperty.Type.NONE
) -> void:
	var def := FruitRegistry.catalog.get_fruit(level)
	var tex := FruitRegistry.textures.get_texture(level)
	_held_radius = def.radius if def != null else 20.0
	_held_property = prop
	_sprite_scale = FruitRegistry.textures.get_sprite_scale(level)
	_sprite.texture = tex

	if jar != null:
		drop_x = jar.clamp_drop_x(drop_x, _held_radius)
	else:
		var limit := JarContainer.INNER_HALF_WIDTH - _held_radius - 4.0
		drop_x = clampf(drop_x, -limit, limit)

	has_held_fruit = true
	_show_guide = true
	_sprite.visible = true
	_sprite.position = Vector2(drop_x, JarContainer.DROP_Y)
	_sprite.modulate = Color(1.0, 1.0, 1.0, COOLDOWN_ALPHA if cooldown_timer > 0.0 else 1.0)
	_overlay.configure(prop, _held_radius, true)
	_overlay.position = _sprite.position

	# Little pop-in so the new fruit is noticed.
	_kill_pop()
	if is_inside_tree():
		_sprite.scale = Vector2(_sprite_scale, _sprite_scale) * 0.4
		_pop_tween = create_tween()
		_pop_tween.tween_property(_sprite, "scale", Vector2(_sprite_scale, _sprite_scale), 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	queue_redraw()


func hide_guide() -> void:
	has_held_fruit = false
	_show_guide = false
	_queued_drop = false
	_kill_pop()
	_sprite.visible = false
	_overlay.reset()
	queue_redraw()


func cancel_drag() -> void:
	_is_pointer_down = false
	_queued_drop = false


func start_cooldown() -> void:
	cooldown_timer = DROP_COOLDOWN
	has_held_fruit = false
	_queued_drop = false
	_sprite.visible = false
	_overlay.reset()
	queue_redraw()


func is_ready_to_drop() -> bool:
	return has_held_fruit and cooldown_timer <= 0.0


func tick(
	delta: float,
	next_held_level: int,
	jar: JarContainer,
	next_held_prop: FruitProperty.Type = FruitProperty.Type.NONE
) -> void:
	if cooldown_timer <= 0.0:
		return

	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if cooldown_timer > 0.0:
		return

	# Cooldown just finished.
	if not has_held_fruit:
		show_held_fruit(next_held_level, jar, next_held_prop)
	_sprite.modulate = Color.WHITE
	queue_redraw()

	if _queued_drop:
		_queued_drop = false
		drop_x = jar.clamp_drop_x(_queued_drop_x, _held_radius)
		drop_requested.emit(drop_x)


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
		_overlay.position = _sprite.position
		queue_redraw()


func _kill_pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = null
	_sprite.scale = Vector2(_sprite_scale, _sprite_scale)


func _draw() -> void:
	if not _show_guide or not has_held_fruit:
		return
	# Pixel-style dotted aim guide: small squares snapped to the 4px fruit pixel grid.
	var col := Color(0.18, 0.23, 0.36, 0.22)
	if _held_property != FruitProperty.Type.NONE:
		var prop_col := FruitProperty.get_color(_held_property)
		col = Color(prop_col.r, prop_col.g, prop_col.b, 0.5)
	if cooldown_timer > 0.0:
		col.a *= 0.5
	var x := floorf(drop_x / GUIDE_PIXEL) * GUIDE_PIXEL - GUIDE_PIXEL * 0.5
	var y := JarContainer.DROP_Y + maxf(_held_radius, 20.0) + 8.0
	var bottom := JarContainer.FLOOR_Y - 12.0
	while y < bottom:
		draw_rect(Rect2(x, floorf(y / GUIDE_PIXEL) * GUIDE_PIXEL, GUIDE_PIXEL, GUIDE_PIXEL), col)
		y += GUIDE_PIXEL * 5.0
