class_name FruitPainter
extends Node2D

## Procedural 2D drawer used to bake all fruit tiers into a single texture atlas.

var catalog: FruitCatalog
var cell_size: int = 320
var cols: int = 4
var draw_radius: float = 128.0


func _draw() -> void:
	if catalog == null:
		return
	for i in range(catalog.get_count()):
		var def := catalog.get_fruit(i)
		if def == null:
			continue
		var col := i % cols
		@warning_ignore("integer_division")
		var row := i / cols
		var center := Vector2(
			(float(col) + 0.5) * float(cell_size),
			(float(row) + 0.5) * float(cell_size)
		)
		_draw_fruit(center, def)


func _draw_fruit(center: Vector2, def: FruitDefinition) -> void:
	var r := draw_radius

	# Rambutan hairs sit just outside the body rim before filling the core circle.
	if def.pattern_type == FruitDefinition.PatternType.RAMBUTAN:
		_draw_rambutan_hairs(center, r, def)

	# Base circle
	draw_circle(center, r, def.primary_color)

	# Lower-right subtle shading crescent
	_draw_shadow_crescent(center, r, def.outline_color)

	# Per-fruit surface pattern
	match def.pattern_type:
		FruitDefinition.PatternType.KERSEN:
			_draw_kersen(center, r, def)
		FruitDefinition.PatternType.DUKUH:
			_draw_dukuh(center, r, def)
		FruitDefinition.PatternType.RAMBUTAN:
			_draw_rambutan_inner(center, r, def)
		FruitDefinition.PatternType.SALAK:
			_draw_salak(center, r, def)
		FruitDefinition.PatternType.JAMBU_BIJI:
			_draw_jambu_biji(center, r, def)
		FruitDefinition.PatternType.MANGGIS:
			_draw_manggis(center, r, def)
		FruitDefinition.PatternType.KELAPA:
			_draw_kelapa(center, r, def)
		FruitDefinition.PatternType.GENERIC_STRIPED:
			_draw_generic_striped(center, r, def)
		FruitDefinition.PatternType.GENERIC_DOTTED:
			_draw_generic_dotted(center, r, def)

	# Crisp outer rim
	var rim_w := maxf(4.5 * (r / 104.0), 3.0)
	draw_arc(center, r - rim_w * 0.45, 0.0, TAU, 72, def.outline_color, rim_w, true)

	# Upper-left glossy specular highlight
	var spec_pos := center + Vector2(-r * 0.34, -r * 0.36)
	draw_set_transform(spec_pos, -0.55, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r * 0.22, Color(1.0, 1.0, 1.0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(center + Vector2(-r * 0.18, -r * 0.52), r * 0.07, Color(1.0, 1.0, 1.0, 0.42))


func _draw_shadow_crescent(center: Vector2, r: float, shade_color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 28
	for i in range(steps + 1):
		var angle := lerpf(-0.15, PI * 0.65, float(i) / float(steps))
		pts.append(center + Vector2(cos(angle), sin(angle)) * (r - 2.5))
	for i in range(steps, -1, -1):
		var angle := lerpf(-0.15, PI * 0.65, float(i) / float(steps))
		var inner_r := r * 0.80
		var offset := Vector2(-r * 0.08, -r * 0.08)
		pts.append(center + offset + Vector2(cos(angle), sin(angle)) * inner_r)
	var col := Color(shade_color.r, shade_color.g, shade_color.b, 0.22)
	draw_colored_polygon(pts, col)


func _draw_kersen(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	draw_circle(center + Vector2(-r * 0.1, -r * 0.1), r * 0.62, Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.45))
	var stem_start := center + Vector2(0.0, -r * 0.72)
	var stem_mid := center + Vector2(r * 0.08, -r * 0.96)
	var stem_end := center + Vector2(r * 0.22, -r * 1.12)
	draw_line(stem_start, stem_mid, def.accent_color, 5.5 * k, true)
	draw_line(stem_mid, stem_end, def.accent_color, 4.5 * k, true)
	draw_circle(stem_start, 6.0 * k, def.outline_color)
	draw_set_transform(center + Vector2(-r * 0.15, -r * 0.96), -0.45, Vector2(1.4, 0.7))
	draw_circle(Vector2.ZERO, r * 0.12, def.accent_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dukuh(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	draw_circle(center + Vector2(-r * 0.12, -r * 0.12), r * 0.68, Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.32))
	var line_col := Color(def.outline_color.r, def.outline_color.g, def.outline_color.b, 0.20)
	for i in range(5):
		var a := float(i) * (TAU / 5.0) - PI * 0.5
		var p1 := center + Vector2(cos(a), sin(a)) * (r * 0.14)
		var p2 := center + Vector2(cos(a), sin(a)) * (r * 0.86)
		draw_line(p1, p2, line_col, 2.5 * k, true)
	var speck_col := Color(def.outline_color.r, def.outline_color.g, def.outline_color.b, 0.28)
	var offsets := [
		Vector2(-0.42, 0.15), Vector2(0.36, -0.22), Vector2(0.18, 0.48),
		Vector2(-0.22, -0.45), Vector2(0.45, 0.24), Vector2(-0.52, -0.15),
	]
	for off in offsets:
		draw_circle(center + off * r, 3.2 * k, speck_col)
	draw_circle(center + Vector2(0.0, -r * 0.78), 7.5 * k, def.accent_color)


func _draw_rambutan_hairs(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	var max_reach := float(cell_size) * 0.48 - r
	var hair_mid := minf(9.0 * k, max_reach * 0.55)
	var hair_tip := minf(16.0 * k, max_reach)
	var count := 20
	for i in range(count):
		var angle := float(i) * (TAU / float(count))
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var base := center + dir * (r - 6.0 * k)
		var bend := tangent * ((8.0 if i % 2 == 0 else -8.0) * k)
		var mid := center + dir * (r + hair_mid) + bend * 0.45
		var tip := center + dir * (r + hair_tip) + bend
		draw_line(base, mid, def.primary_color, 6.0 * k, true)
		draw_line(mid, tip, def.accent_color, 4.0 * k, true)


func _draw_rambutan_inner(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	draw_circle(center + Vector2(-r * 0.10, -r * 0.10), r * 0.68, Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.38))
	var dimple_col := Color(def.outline_color.r, def.outline_color.g, def.outline_color.b, 0.26)
	var pts := [
		Vector2(-0.35, -0.10), Vector2(0.30, -0.28), Vector2(0.05, 0.25),
		Vector2(-0.25, 0.42), Vector2(0.42, 0.18), Vector2(0.0, -0.45),
	]
	for p in pts:
		draw_circle(center + p * r, 4.0 * k, dimple_col)


func _draw_salak(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	var step_x := 28.0 * k
	var step_y := 24.0 * k
	var max_dist := r - 15.0 * k
	var half_w := 12.0 * k
	var half_h := 11.0 * k
	for row in range(-4, 5):
		for col in range(-4, 5):
			var shift := step_x * 0.5 if abs(row) % 2 == 1 else 0.0
			var p := center + Vector2(float(col) * step_x + shift, float(row) * step_y)
			if p.distance_to(center) > max_dist:
				continue
			var scale_pts := PackedVector2Array([
				p + Vector2(0.0, -half_h),
				p + Vector2(half_w, 0.0),
				p + Vector2(0.0, half_h),
				p + Vector2(-half_w, 0.0),
			])
			var fill := def.secondary_color if (row + col) % 2 == 0 else def.accent_color
			fill.a = 0.55
			draw_colored_polygon(scale_pts, fill)
			draw_polyline(scale_pts + PackedVector2Array([scale_pts[0]]), Color(def.outline_color.r, def.outline_color.g, def.outline_color.b, 0.55), 2.0 * k, true)


func _draw_jambu_biji(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	draw_circle(center, r * 0.78, Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.35))
	draw_circle(center + Vector2(r * 0.06, r * 0.10), r * 0.46, Color(def.accent_color.r, def.accent_color.g, def.accent_color.b, 0.42))
	var stipple := Color(1.0, 1.0, 1.0, 0.24)
	for p in [Vector2(-0.45, 0.20), Vector2(0.42, -0.18), Vector2(0.24, 0.48), Vector2(-0.18, -0.52)]:
		draw_circle(center + p * r, 3.5 * k, stipple)
	draw_line(center + Vector2(0.0, -r * 0.82), center + Vector2(0.0, -r * 1.04), def.outline_color, 5.0 * k, true)
	draw_set_transform(center + Vector2(r * 0.16, -r * 0.94), 0.35, Vector2(1.4, 0.65))
	draw_circle(Vector2.ZERO, r * 0.14, def.secondary_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_manggis(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	draw_circle(center + Vector2(-r * 0.10, -r * 0.08), r * 0.68, Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.35))
	var calyx_center := center + Vector2(0.0, -r * 0.42)
	for i in range(4):
		var angle := float(i) * (PI * 0.5) + PI * 0.25
		draw_set_transform(calyx_center + Vector2(cos(angle), sin(angle)) * (18.0 * k), angle, Vector2(1.35, 0.78))
		draw_circle(Vector2.ZERO, 16.0 * k, def.accent_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(calyx_center, 11.0 * k, Color("#558B2F"))
	draw_line(calyx_center, calyx_center + Vector2(2.0 * k, -24.0 * k), Color("#4E342E"), 6.0 * k, true)


func _draw_kelapa(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	draw_circle(center + Vector2(-r * 0.08, -r * 0.08), r * 0.72, Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.36))
	var grain := Color(def.outline_color.r, def.outline_color.g, def.outline_color.b, 0.40)
	draw_arc(center + Vector2(-r * 0.55, 0.0), r * 0.95, -0.65, 0.65, 24, grain, 3.0 * k, true)
	draw_arc(center + Vector2(r * 0.58, 0.0), r * 0.95, PI - 0.65, PI + 0.65, 24, grain, 3.0 * k, true)
	draw_arc(center + Vector2(0.0, r * 0.58), r * 0.85, -PI * 0.78, -PI * 0.22, 20, grain, 2.5 * k, true)
	var eyes := [
		Vector2(-r * 0.19, -r * 0.26),
		Vector2(r * 0.19, -r * 0.26),
		Vector2(0.0, -r * 0.04),
	]
	for eye in eyes:
		draw_circle(center + eye, r * 0.11, def.accent_color)
		draw_arc(center + eye, r * 0.11, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.35), 2.5 * k, true)


func _draw_generic_striped(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	var stripe_col := Color(def.secondary_color.r, def.secondary_color.g, def.secondary_color.b, 0.5)
	for idx in range(-2, 3):
		var x_off := float(idx) * r * 0.28
		var half_h := sqrt(maxf(0.0, (r - 10.0 * k) * (r - 10.0 * k) - x_off * x_off))
		draw_line(center + Vector2(x_off, -half_h), center + Vector2(x_off, half_h), stripe_col, 7.0 * k, true)


func _draw_generic_dotted(center: Vector2, r: float, def: FruitDefinition) -> void:
	var k := r / 104.0
	var dot_col := Color(def.accent_color.r, def.accent_color.g, def.accent_color.b, 0.55)
	for i in range(6):
		var a := float(i) * (TAU / 6.0)
		draw_circle(center + Vector2(cos(a), sin(a)) * (r * 0.48), 7.0 * k, dot_col)
