class_name MergeEffects
extends Node2D

## Single-draw-call batched shockwave rings and radial droplets for merges.

var _ring_positions := PackedVector2Array()
var _ring_start_radii := PackedFloat32Array()
var _ring_end_radii := PackedFloat32Array()
var _ring_ages := PackedFloat32Array()
var _ring_durations := PackedFloat32Array()
var _ring_colors := PackedColorArray()

var _drop_positions := PackedVector2Array()
var _drop_velocities := PackedVector2Array()
var _drop_radii := PackedFloat32Array()
var _drop_ages := PackedFloat32Array()
var _drop_durations := PackedFloat32Array()
var _drop_colors := PackedColorArray()


func _ready() -> void:
	set_process(false)


func spawn_merge_burst(pos: Vector2, radius: float, color: Color, is_max_bonus: bool = false) -> void:
	_ring_positions.append(pos)
	_ring_start_radii.append(radius * 0.55)
	_ring_end_radii.append(radius * (2.2 if is_max_bonus else 1.55))
	_ring_ages.append(0.0)
	_ring_durations.append(0.40 if is_max_bonus else 0.28)
	_ring_colors.append(color)

	var droplet_count := 12 if is_max_bonus else 7
	for i in range(droplet_count):
		var angle := (float(i) / float(droplet_count)) * TAU + randf_range(-0.18, 0.18)
		var speed := randf_range(radius * 2.2, radius * 4.2)
		_drop_positions.append(pos + Vector2(cos(angle), sin(angle)) * (radius * 0.3))
		_drop_velocities.append(Vector2(cos(angle), sin(angle)) * speed)
		_drop_radii.append(clampf(radius * 0.12, 4.0, 10.0))
		_drop_ages.append(0.0)
		_drop_durations.append(randf_range(0.24, 0.38))
		_drop_colors.append(color.lightened(0.25))

	set_process(true)
	queue_redraw()


func spawn_explosion_burst(pos: Vector2, blast_radius: float, is_nuclear: bool) -> void:
	var outer_color := FruitProperty.get_color(FruitProperty.Type.NUCLEAR) if is_nuclear else Color("#FF7043")
	var inner_color := Color("#FFF176") if is_nuclear else Color("#FFCA28")

	_ring_positions.append(pos)
	_ring_start_radii.append(blast_radius * 0.18)
	_ring_end_radii.append(blast_radius * 1.1)
	_ring_ages.append(0.0)
	_ring_durations.append(0.42 if is_nuclear else 0.30)
	_ring_colors.append(outer_color)

	_ring_positions.append(pos)
	_ring_start_radii.append(blast_radius * 0.08)
	_ring_end_radii.append(blast_radius * 0.72)
	_ring_ages.append(0.0)
	_ring_durations.append(0.28 if is_nuclear else 0.20)
	_ring_colors.append(inner_color)

	var droplet_count := 22 if is_nuclear else 14
	for i in range(droplet_count):
		var angle := (float(i) / float(droplet_count)) * TAU + randf_range(-0.15, 0.15)
		var speed := randf_range(blast_radius * 1.6, blast_radius * 3.1)
		_drop_positions.append(pos + Vector2(cos(angle), sin(angle)) * (blast_radius * 0.12))
		_drop_velocities.append(Vector2(cos(angle), sin(angle)) * speed)
		_drop_radii.append(clampf(blast_radius * 0.055, 4.5, 11.0))
		_drop_ages.append(0.0)
		_drop_durations.append(randf_range(0.26, 0.44))
		_drop_colors.append(outer_color if i % 2 == 0 else inner_color)

	set_process(true)
	queue_redraw()


func spawn_crush_burst(pos: Vector2, radius: float, color: Color) -> void:
	_ring_positions.append(pos)
	_ring_start_radii.append(radius * 0.4)
	_ring_end_radii.append(radius * 1.35)
	_ring_ages.append(0.0)
	_ring_durations.append(0.22)
	_ring_colors.append(Color("#90A4AE"))

	for i in range(8):
		var angle := (float(i) / 8.0) * TAU + randf_range(-0.2, 0.2)
		var speed := randf_range(radius * 2.0, radius * 4.0)
		_drop_positions.append(pos)
		_drop_velocities.append(Vector2(cos(angle), sin(angle)) * speed)
		_drop_radii.append(clampf(radius * 0.13, 3.5, 8.5))
		_drop_ages.append(0.0)
		_drop_durations.append(randf_range(0.20, 0.34))
		_drop_colors.append(color if i % 2 == 0 else Color("#B0BEC5"))

	set_process(true)
	queue_redraw()


func spawn_property_splash(pos: Vector2, radius: float, color: Color, droplet_count: int = 6) -> void:
	for i in range(droplet_count):
		var angle := (float(i) / float(maxi(droplet_count, 1))) * TAU + randf_range(-0.25, 0.25)
		var speed := randf_range(radius * 1.5, radius * 3.0)
		_drop_positions.append(pos + Vector2(cos(angle), sin(angle)) * (radius * 0.5))
		_drop_velocities.append(Vector2(cos(angle), sin(angle)) * speed)
		_drop_radii.append(clampf(radius * 0.11, 3.0, 7.0))
		_drop_ages.append(0.0)
		_drop_durations.append(randf_range(0.18, 0.30))
		_drop_colors.append(color)

	set_process(true)
	queue_redraw()


func clear_all() -> void:
	_ring_positions.clear()
	_ring_start_radii.clear()
	_ring_end_radii.clear()
	_ring_ages.clear()
	_ring_durations.clear()
	_ring_colors.clear()
	_drop_positions.clear()
	_drop_velocities.clear()
	_drop_radii.clear()
	_drop_ages.clear()
	_drop_durations.clear()
	_drop_colors.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var i := _ring_ages.size() - 1
	while i >= 0:
		var age := _ring_ages[i] + delta
		if age >= _ring_durations[i]:
			_remove_ring(i)
		else:
			_ring_ages[i] = age
		i -= 1

	var j := _drop_ages.size() - 1
	while j >= 0:
		var age := _drop_ages[j] + delta
		if age >= _drop_durations[j]:
			_remove_drop(j)
		else:
			_drop_ages[j] = age
			var vel := _drop_velocities[j] * (1.0 - minf(delta * 4.5, 0.9))
			_drop_velocities[j] = vel
			_drop_positions[j] = _drop_positions[j] + vel * delta
		j -= 1

	if _ring_ages.is_empty() and _drop_ages.is_empty():
		set_process(false)

	queue_redraw()


func _remove_ring(idx: int) -> void:
	var last := _ring_ages.size() - 1
	if idx != last:
		_ring_positions[idx] = _ring_positions[last]
		_ring_start_radii[idx] = _ring_start_radii[last]
		_ring_end_radii[idx] = _ring_end_radii[last]
		_ring_ages[idx] = _ring_ages[last]
		_ring_durations[idx] = _ring_durations[last]
		_ring_colors[idx] = _ring_colors[last]
	_ring_positions.resize(last)
	_ring_start_radii.resize(last)
	_ring_end_radii.resize(last)
	_ring_ages.resize(last)
	_ring_durations.resize(last)
	_ring_colors.resize(last)


func _remove_drop(idx: int) -> void:
	var last := _drop_ages.size() - 1
	if idx != last:
		_drop_positions[idx] = _drop_positions[last]
		_drop_velocities[idx] = _drop_velocities[last]
		_drop_radii[idx] = _drop_radii[last]
		_drop_ages[idx] = _drop_ages[last]
		_drop_durations[idx] = _drop_durations[last]
		_drop_colors[idx] = _drop_colors[last]
	_drop_positions.resize(last)
	_drop_velocities.resize(last)
	_drop_radii.resize(last)
	_drop_ages.resize(last)
	_drop_durations.resize(last)
	_drop_colors.resize(last)


func _draw() -> void:
	for i in range(_ring_ages.size()):
		var t := _ring_ages[i] / _ring_durations[i]
		var ease_t := 1.0 - pow(1.0 - t, 3.0)
		var r := lerpf(_ring_start_radii[i], _ring_end_radii[i], ease_t)
		var col := _ring_colors[i]
		col.a = (1.0 - t) * 0.78
		draw_arc(_ring_positions[i], r, 0.0, TAU, 36, col, lerpf(6.0, 1.5, t), true)

	for j in range(_drop_ages.size()):
		var t := _drop_ages[j] / _drop_durations[j]
		var col := _drop_colors[j]
		col.a = 1.0 - t
		var r := _drop_radii[j] * (1.0 - t * 0.65)
		draw_circle(_drop_positions[j], r, col)
