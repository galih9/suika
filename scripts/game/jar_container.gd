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
	var ci := get_canvas_item()
	var frame := 16.0
	var inner_rect := Rect2(-INNER_HALF_WIDTH, JAR_TOP_Y, INNER_HALF_WIDTH * 2.0, FLOOR_Y - JAR_TOP_Y)
	var outer_rect := inner_rect.grow_individual(frame, 4.0, frame, frame)

	# Soft drop shadow under the jar.
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.12, 0.32, 0.45, 0.18)
	shadow.set_corner_radius_all(34)
	shadow.draw(ci, Rect2(outer_rect.position + Vector2(0.0, 14.0), outer_rect.size))

	# Chunky white frame with a blue "lip" at the bottom (matches the UI cards).
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color("#FFFFFF")
	frame_sb.border_color = Color("#9ED3E8")
	frame_sb.border_width_bottom = 10
	frame_sb.corner_radius_top_left = 12
	frame_sb.corner_radius_top_right = 12
	frame_sb.corner_radius_bottom_left = 34
	frame_sb.corner_radius_bottom_right = 34
	frame_sb.draw(ci, outer_rect)

	# Cream interior.
	var inner_sb := StyleBoxFlat.new()
	inner_sb.bg_color = Color("#FFF8EC")
	inner_sb.border_color = Color("#F0E2CC")
	inner_sb.set_border_width_all(0)
	inner_sb.border_width_top = 0
	inner_sb.corner_radius_bottom_left = 22
	inner_sb.corner_radius_bottom_right = 22
	inner_sb.draw(ci, inner_rect)

	# Subtle checker "tablecloth" pattern on the floor area, pixel style.
	var tile := 16.0
	var floor_band := 48.0
	var y := FLOOR_Y - floor_band
	var row := 0
	while y < FLOOR_Y - 8.0:
		var x := -INNER_HALF_WIDTH + 12.0 + (tile if row % 2 == 1 else 0.0)
		while x < INNER_HALF_WIDTH - 12.0:
			draw_rect(Rect2(x, y, tile, tile), Color(1.0, 0.86, 0.72, 0.35))
			x += tile * 2.0
		y += tile
		row += 1

	# Glass highlights (pixel strips) on the walls.
	draw_rect(Rect2(-INNER_HALF_WIDTH + 8.0, JAR_TOP_Y + 12.0, 8.0, FLOOR_Y - JAR_TOP_Y - 80.0), Color(1.0, 1.0, 1.0, 0.75))
	draw_rect(Rect2(-INNER_HALF_WIDTH + 20.0, JAR_TOP_Y + 12.0, 4.0, 120.0), Color(1.0, 1.0, 1.0, 0.6))
	draw_rect(Rect2(INNER_HALF_WIDTH - 16.0, JAR_TOP_Y + 40.0, 8.0, FLOOR_Y - JAR_TOP_Y - 120.0), Color(0.85, 0.93, 0.97, 0.45))

	# Rounded lip caps on top of each wall.
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color("#FFFFFF")
	cap.border_color = Color("#9ED3E8")
	cap.border_width_bottom = 5
	cap.set_corner_radius_all(10)
	var cap_w := frame + 16.0
	cap.draw(ci, Rect2(-INNER_HALF_WIDTH - frame - 6.0, JAR_TOP_Y - 14.0, cap_w, 22.0))
	cap.draw(ci, Rect2(INNER_HALF_WIDTH - 10.0, JAR_TOP_Y - 14.0, cap_w, 22.0))
