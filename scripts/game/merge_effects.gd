class_name MergeEffects
extends Node2D

## Pixel-art merge / explosion effects, all drawn in one _draw() with plain rects snapped to the
## 4px grid the fruit sprites use (every sprite pixel is 4x4 on screen), so effects look like
## they belong to the sprites:
## - a white pixel flash disc,
## - expanding pixel rings that dither out,
## - chunky square debris in the fruit's own sprite colours (with gravity),
## - twinkling "+" sparkles.

const PX := 4.0
const MAX_CHUNKS := 420
const MAX_SPARKLES := 120


class Chunk:
	var pos: Vector2
	var vel: Vector2
	var size: float = 8.0
	var color: Color = Color.WHITE
	var age: float = 0.0
	var life: float = 0.5
	var gravity: float = 1300.0
	var drag: float = 2.2


class Sparkle:
	var pos: Vector2
	var color: Color = Color.WHITE
	var age: float = 0.0
	var life: float = 0.45
	var delay: float = 0.0
	var arm: int = 2


class Ring:
	var center: Vector2
	var r0: float = 10.0
	var r1: float = 40.0
	var color: Color = Color.WHITE
	var age: float = 0.0
	var life: float = 0.3
	var delay: float = 0.0
	var thickness: int = 2


class Flash:
	var center: Vector2
	var radius: float = 20.0
	var color: Color = Color.WHITE
	var age: float = 0.0
	var life: float = 0.12


var _chunks: Array[Chunk] = []
var _sparkles: Array[Sparkle] = []
var _rings: Array[Ring] = []
var _flashes: Array[Flash] = []


func _ready() -> void:
	set_process(false)


# --- Public API --------------------------------------------------------------------------------

func spawn_merge_burst(
	pos: Vector2,
	radius: float,
	color: Color,
	is_max_bonus: bool = false,
	level: int = -1,
	palette: PackedColorArray = PackedColorArray()
) -> void:
	var colors := palette
	if colors.is_empty():
		colors = PackedColorArray([color, color.lightened(0.3), color.darkened(0.15)])
	var tier := clampf(float(maxi(level, 0)) / 14.0, 0.0, 1.0)
	var light := colors[0].lightened(0.45)

	_add_flash(pos, radius * (1.15 if is_max_bonus else 0.95), Color.WHITE, 0.1 + tier * 0.05)
	_add_ring(pos, radius * 0.7, radius * (1.55 + tier * 0.35), light, 0.3 + tier * 0.1, 0.0, 2)
	_add_ring(pos, radius * 0.5, radius * (1.25 + tier * 0.25), Color.WHITE, 0.24, 0.05, 1)

	var chunk_count := int(lerpf(9.0, 26.0, tier))
	var sparkle_count := int(lerpf(3.0, 9.0, tier))
	if is_max_bonus:
		chunk_count = 46
		sparkle_count = 16
		_add_ring(pos, radius * 0.9, radius * 2.6, Color("#FFE066"), 0.55, 0.08, 3)
		_add_ring(pos, radius * 0.6, radius * 2.1, Color("#FF8FB1"), 0.48, 0.16, 2)

	for i in range(chunk_count):
		var angle := (float(i) / float(chunk_count)) * TAU + randf_range(-0.25, 0.25)
		var dir := Vector2(cos(angle), sin(angle))
		var speed := randf_range(radius * 3.0, radius * 6.0) + 90.0
		var c := Chunk.new()
		c.pos = pos + dir * radius * randf_range(0.2, 0.7)
		c.vel = dir * speed + Vector2(0.0, -radius * 2.2)
		c.size = PX * (2.0 if randf() < 0.35 + tier * 0.4 else 1.0)
		c.color = colors[i % colors.size()]
		c.life = randf_range(0.4, 0.7) + tier * 0.15
		c.gravity = 1500.0
		_push_chunk(c)

	for i in range(sparkle_count):
		var s := Sparkle.new()
		var a := randf() * TAU
		s.pos = pos + Vector2(cos(a), sin(a)) * radius * randf_range(0.6, 1.5)
		s.color = Color.WHITE if i % 2 == 0 else light
		s.delay = randf_range(0.0, 0.18)
		s.life = randf_range(0.3, 0.5)
		s.arm = 2 if randf() < 0.6 else 3
		_push_sparkle(s)

	_wake()


func spawn_explosion_burst(pos: Vector2, blast_radius: float, is_nuclear: bool) -> void:
	var outer_color := FruitProperty.get_color(FruitProperty.Type.NUCLEAR) if is_nuclear else Color("#FF7043")
	var inner_color := Color("#FFF176") if is_nuclear else Color("#FFCA28")

	_add_flash(pos, blast_radius * 0.55, Color("#FFFDE7"), 0.12)
	_add_ring(pos, blast_radius * 0.2, blast_radius * 1.1, outer_color, 0.42 if is_nuclear else 0.32, 0.0, 3)
	_add_ring(pos, blast_radius * 0.1, blast_radius * 0.75, inner_color, 0.3, 0.04, 2)
	if is_nuclear:
		_add_ring(pos, blast_radius * 0.3, blast_radius * 1.35, Color.WHITE, 0.5, 0.1, 1)

	var count := 34 if is_nuclear else 22
	var smoke := Color("#B0BEC5")
	for i in range(count):
		var angle := (float(i) / float(count)) * TAU + randf_range(-0.2, 0.2)
		var dir := Vector2(cos(angle), sin(angle))
		var c := Chunk.new()
		c.pos = pos + dir * blast_radius * 0.12
		c.vel = dir * randf_range(blast_radius * 1.8, blast_radius * 3.4) + Vector2(0.0, -120.0)
		c.size = PX * (2.0 if i % 3 == 0 else 1.0)
		c.color = outer_color if i % 3 == 0 else (inner_color if i % 3 == 1 else smoke)
		c.life = randf_range(0.35, 0.65)
		c.gravity = 700.0
		_push_chunk(c)

	for i in range(8 if is_nuclear else 5):
		var s := Sparkle.new()
		var a := randf() * TAU
		s.pos = pos + Vector2(cos(a), sin(a)) * blast_radius * randf_range(0.3, 0.9)
		s.color = inner_color
		s.delay = randf_range(0.0, 0.15)
		s.arm = 3
		_push_sparkle(s)
	_wake()


func spawn_crush_burst(pos: Vector2, radius: float, color: Color) -> void:
	_add_ring(pos, radius * 0.4, radius * 1.35, Color("#90A4AE"), 0.22, 0.0, 2)
	for i in range(10):
		var angle := (float(i) / 10.0) * TAU + randf_range(-0.2, 0.2)
		var c := Chunk.new()
		c.pos = pos
		c.vel = Vector2(cos(angle), sin(angle)) * randf_range(radius * 2.0, radius * 4.0)
		c.size = PX * (2.0 if i % 2 == 0 else 1.0)
		c.color = color if i % 2 == 0 else Color("#B0BEC5")
		c.life = randf_range(0.25, 0.45)
		_push_chunk(c)
	_wake()


func spawn_property_splash(pos: Vector2, radius: float, color: Color, droplet_count: int = 6) -> void:
	for i in range(droplet_count):
		var angle := (float(i) / float(maxi(droplet_count, 1))) * TAU + randf_range(-0.25, 0.25)
		var c := Chunk.new()
		c.pos = pos + Vector2(cos(angle), sin(angle)) * (radius * 0.5)
		c.vel = Vector2(cos(angle), sin(angle)) * randf_range(radius * 1.5, radius * 3.0)
		c.size = PX
		c.color = color
		c.life = randf_range(0.2, 0.34)
		c.gravity = 600.0
		_push_chunk(c)
	var s := Sparkle.new()
	s.pos = pos
	s.color = color.lightened(0.4)
	s.arm = 2
	_push_sparkle(s)
	_wake()


func clear_all() -> void:
	_chunks.clear()
	_sparkles.clear()
	_rings.clear()
	_flashes.clear()
	set_process(false)
	queue_redraw()


func has_active_effects() -> bool:
	return not (_chunks.is_empty() and _sparkles.is_empty() and _rings.is_empty() and _flashes.is_empty())


# --- Internals ---------------------------------------------------------------------------------

func _add_flash(center: Vector2, radius: float, color: Color, life: float) -> void:
	var f := Flash.new()
	f.center = center
	f.radius = radius
	f.color = color
	f.life = life
	_flashes.append(f)


func _add_ring(center: Vector2, r0: float, r1: float, color: Color, life: float, delay: float, thickness: int) -> void:
	var r := Ring.new()
	r.center = center
	r.r0 = r0
	r.r1 = r1
	r.color = color
	r.life = life
	r.delay = delay
	r.thickness = thickness
	_rings.append(r)


func _push_chunk(c: Chunk) -> void:
	if _chunks.size() >= MAX_CHUNKS:
		_chunks.pop_front()
	_chunks.append(c)


func _push_sparkle(s: Sparkle) -> void:
	if _sparkles.size() >= MAX_SPARKLES:
		_sparkles.pop_front()
	_sparkles.append(s)


func _wake() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var i := _chunks.size() - 1
	while i >= 0:
		var c := _chunks[i]
		c.age += delta
		if c.age >= c.life:
			_chunks.remove_at(i)
		else:
			c.vel *= maxf(1.0 - c.drag * delta, 0.0)
			c.vel.y += c.gravity * delta
			c.pos += c.vel * delta
		i -= 1

	i = _sparkles.size() - 1
	while i >= 0:
		var s := _sparkles[i]
		s.age += delta
		if s.age >= s.delay + s.life:
			_sparkles.remove_at(i)
		i -= 1

	i = _rings.size() - 1
	while i >= 0:
		var r := _rings[i]
		r.age += delta
		if r.age >= r.delay + r.life:
			_rings.remove_at(i)
		i -= 1

	i = _flashes.size() - 1
	while i >= 0:
		var f := _flashes[i]
		f.age += delta
		if f.age >= f.life:
			_flashes.remove_at(i)
		i -= 1

	if not has_active_effects():
		set_process(false)
	queue_redraw()


static func _snap(v: float) -> float:
	return floorf(v / PX) * PX


func _draw() -> void:
	for f: Flash in _flashes:
		var t := f.age / f.life
		var col := f.color
		col.a = 1.0 - t
		_draw_pixel_disc(f.center, f.radius * (1.0 + t * 0.25), col)

	for r: Ring in _rings:
		if r.age < r.delay:
			continue
		var t := clampf((r.age - r.delay) / r.life, 0.0, 1.0)
		var ease_t := 1.0 - pow(1.0 - t, 3.0)
		var radius := lerpf(r.r0, r.r1, ease_t)
		_draw_pixel_ring(r.center, radius, r.color, r.thickness, t)

	for c: Chunk in _chunks:
		var t := c.age / c.life
		# Shrink in steps (8px -> 4px) instead of fading, like a sprite animation.
		var sz := c.size if t < 0.6 else maxf(c.size - PX, PX)
		var col := c.color
		if t > 0.85:
			col.a = 0.5
		draw_rect(Rect2(_snap(c.pos.x) - sz * 0.5, _snap(c.pos.y) - sz * 0.5, sz, sz), col)

	for s: Sparkle in _sparkles:
		if s.age < s.delay:
			continue
		var t := (s.age - s.delay) / s.life
		# Arm length grows then shrinks: 0 -> arm -> 0 blocks.
		var arm := roundi(sin(t * PI) * float(s.arm))
		var x := _snap(s.pos.x)
		var y := _snap(s.pos.y)
		draw_rect(Rect2(x, y, PX, PX), Color.WHITE)
		for k in range(1, arm + 1):
			var off := float(k) * PX
			var col := s.color
			col.a = 1.0 - float(k - 1) * 0.3
			draw_rect(Rect2(x - off, y, PX, PX), col)
			draw_rect(Rect2(x + off, y, PX, PX), col)
			draw_rect(Rect2(x, y - off, PX, PX), col)
			draw_rect(Rect2(x, y + off, PX, PX), col)


## Filled pixel circle: one rect per 4px row.
func _draw_pixel_disc(center: Vector2, radius: float, col: Color) -> void:
	var rows := int(ceilf(radius / PX))
	var cy := _snap(center.y)
	for iy in range(-rows, rows):
		var yc := (float(iy) + 0.5) * PX
		var half_sq := radius * radius - yc * yc
		if half_sq <= 0.0:
			continue
		var half := _snap(sqrt(half_sq))
		if half <= 0.0:
			continue
		draw_rect(Rect2(_snap(center.x - half), cy + float(iy) * PX, half * 2.0, PX), col)


## Ring made of 4px blocks; dithers out (checkerboard holes) in its second half.
func _draw_pixel_ring(center: Vector2, radius: float, col: Color, thickness: int, t: float) -> void:
	var c := col
	c.a = 1.0 if t < 0.5 else lerpf(1.0, 0.35, (t - 0.5) * 2.0)
	var dither := t > 0.55
	var dither_phase := int(t * 12.0) % 2
	for k in range(maxi(thickness, 1)):
		var rr := radius - float(k) * PX
		if rr <= PX:
			continue
		var steps := maxi(16, int(TAU * rr / PX))
		var last := Vector2(INF, INF)
		for i in range(steps):
			var a := TAU * float(i) / float(steps)
			var p := Vector2(_snap(center.x + cos(a) * rr), _snap(center.y + sin(a) * rr))
			if p == last:
				continue
			last = p
			if dither and (int(p.x / PX) + int(p.y / PX) + dither_phase) % 2 == 0:
				continue
			draw_rect(Rect2(p, Vector2(PX, PX)), c)
