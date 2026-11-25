class_name JarContainer
extends Node2D

## Static physics jar boundaries, coordinate clamping helpers, and retained jar drawing.

const INNER_HALF_WIDTH := 284.0
const WALL_THICKNESS := 64.0
const FLOOR_Y := 840.0
const JAR_TOP_Y := 118.0
const DROP_Y := 56.0
const DANGER_LINE_Y := 160.0

var _walls_built: bool = false


func _ready() -> void:
	ensure_walls_built()
	queue_redraw()


func ensure_walls_built() -> void:
	if _walls_built:
		return
	_walls_built = true

	var walls := StaticBody2D.new()
	walls.name = "JarWalls"
	walls.add_to_group(&"jar_wall")
	walls.collision_layer = 2
	walls.collision_mask = 5

	var wall_mat := PhysicsMaterial.new()
	wall_mat.friction = 0.4
	wall_mat.bounce = 0.1
	walls.physics_material_override = wall_mat

	var wall_height := FLOOR_Y - JAR_TOP_Y + 260.0
	var wall_center_y := FLOOR_Y + WALL_THICKNESS * 0.5 - wall_height * 0.5

	# Left wall
	var left_col := CollisionShape2D.new()
	var left_shape := RectangleShape2D.new()
	left_shape.size = Vector2(WALL_THICKNESS, wall_height)
	left_col.shape = left_shape
	left_col.position = Vector2(-INNER_HALF_WIDTH - WALL_THICKNESS * 0.5, wall_center_y)
	walls.add_child(left_col)

	# Right wall
	var right_col := CollisionShape2D.new()
	var right_shape := RectangleShape2D.new()
	right_shape.size = Vector2(WALL_THICKNESS, wall_height)
	right_col.shape = right_shape
	right_col.position = Vector2(INNER_HALF_WIDTH + WALL_THICKNESS * 0.5, wall_center_y)
	walls.add_child(right_col)

	add_child(walls)

	# Separate floor body so Sticky & Concrete can distinguish JarFloor from JarWalls
	var floor_body := StaticBody2D.new()
	floor_body.name = "JarFloor"
	floor_body.add_to_group(&"jar_floor")
	floor_body.collision_layer = 2
	floor_body.collision_mask = 5
	floor_body.physics_material_override = wall_mat

	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(INNER_HALF_WIDTH * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	floor_col.shape = floor_shape
	floor_col.position = Vector2(0.0, FLOOR_Y + WALL_THICKNESS * 0.5)
	floor_body.add_child(floor_col)

	add_child(floor_body)


func clamp_drop_x(x: float, radius: float) -> float:
	var limit := INNER_HALF_WIDTH - radius - 4.0
	return clampf(x, -limit, limit)


func clamp_merge_position(pos: Vector2, radius: float) -> Vector2:
	var limit := INNER_HALF_WIDTH - radius - 2.0
	return Vector2(
		clampf(pos.x, -limit, limit),
		minf(pos.y, FLOOR_Y - radius - 2.0)
	)


func is_in_play_zone(local_pos: Vector2) -> bool:
	return (
		absf(local_pos.x) <= INNER_HALF_WIDTH + 160.0
		and local_pos.y >= -60.0
		and local_pos.y <= FLOOR_Y + 80.0
	)


func _draw() -> void:
	var outer_pad := 14.0
	var inner_rect := Rect2(-INNER_HALF_WIDTH, JAR_TOP_Y, INNER_HALF_WIDTH * 2.0, FLOOR_Y - JAR_TOP_Y)
	var outer_rect := Rect2(
		-INNER_HALF_WIDTH - outer_pad,
		JAR_TOP_Y - 6.0,
		INNER_HALF_WIDTH * 2.0 + outer_pad * 2.0,
		FLOOR_Y - JAR_TOP_Y + outer_pad + 6.0
	)

	# Warm wooden outer frame
	draw_rect(outer_rect, Color("#D7B892"), true)
	draw_rect(outer_rect, Color("#A4794E"), false, 4.0)

	# Inner translucent cream glass interior
	draw_rect(inner_rect, Color("#FFFDF8"), true)

	# Subtle side highlight strips inside jar
	draw_rect(
		Rect2(-INNER_HALF_WIDTH + 6.0, JAR_TOP_Y + 8.0, 10.0, FLOOR_Y - JAR_TOP_Y - 16.0),
		Color(1.0, 0.96, 0.88, 0.85),
		true
	)
	draw_rect(
		Rect2(INNER_HALF_WIDTH - 16.0, JAR_TOP_Y + 8.0, 10.0, FLOOR_Y - JAR_TOP_Y - 16.0),
		Color(0.95, 0.89, 0.80, 0.55),
		true
	)

	# Lip accents at top opening
	draw_rect(
		Rect2(-INNER_HALF_WIDTH - outer_pad - 6.0, JAR_TOP_Y - 12.0, outer_pad + 12.0, 18.0),
		Color("#C49A6C"),
		true
	)
	draw_rect(
		Rect2(INNER_HALF_WIDTH - 6.0, JAR_TOP_Y - 12.0, outer_pad + 12.0, 18.0),
		Color("#C49A6C"),
		true
	)
