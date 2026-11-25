class_name EdgeSplatter
extends Control

## Pixel-art juice splats that burst in from the screen edges (used with the combo splash
## sound). Each splat is a blocky blob that sits partly off-screen, with flying droplets and
## drips that run down, then it dithers away. Drawn with plain rects on an 8px grid so it
## matches the pixel-art fruit. Never blocks input.

const BLOCK := 8.0
const LIFE := 1.5
## Time for a splat to pop to full size.
const POP_TIME := 0.12
const PEAK_ALPHA := 0.85
const MAX_SPLATS := 8

enum Edge { LEFT, RIGHT, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }


class Splat:
	var center: Vector2
	var radius: float = 80.0
	var color: Color = Color.WHITE
	var shade: Color = Color.WHITE
	var highlight: Color = Color.WHITE
	var inward: Vector2 = Vector2.RIGHT
	## Droplets: x, y = offset from centre, z = radius.
	var drops: Array[Vector3] = []
	## Drips: x = x offset, y = max length, z = speed factor.
	var drips: Array[Vector3] = []
	## Lobes that make the blob splat-shaped: x, y = offset (x radius), z = radius (x radius).
	var lobes: Array[Vector3] = []
	var age: float = 0.0
	var delay: float = 0.0


var _splats: Array[Splat] = []
var _rng := RandomNumberGenerator.new()
var _last_edges: Array[int] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	set_process(false)


## Burst `count` splats (scaled by combo) in the given fruit colours.
func splash(colors: PackedColorArray, combo: int = 2) -> void:
	var palette := colors
	if palette.is_empty():
		palette = PackedColorArray([Color("#FF6FA0")])
	var count := clampi(combo, 2, 4)
	var size_boost := clampf(1.0 + 0.12 * float(combo - 2), 1.0, 1.5)
	var edges := _pick_edges(count)
	for i in range(edges.size()):
		var base := palette[i % palette.size()]
		_spawn_splat(edges[i], base, size_boost, float(i) * 0.06)
	while _splats.size() > MAX_SPLATS:
		_splats.pop_front()
	set_process(true)
	queue_redraw()


func clear() -> void:
	_splats.clear()
	set_process(false)
	queue_redraw()


func _pick_edges(count: int) -> Array[int]:
	var all: Array[int] = [Edge.LEFT, Edge.RIGHT, Edge.TOP_LEFT, Edge.TOP_RIGHT, Edge.BOTTOM_LEFT, Edge.BOTTOM_RIGHT]
	# Prefer edges that weren't used last time so consecutive splashes look different.
	var fresh: Array[int] = []
	var used: Array[int] = []
	for e in all:
		if _last_edges.has(e):
			used.append(e)
		else:
			fresh.append(e)
	fresh.shuffle()
	used.shuffle()
	var picked: Array[int] = []
	for e in fresh + used:
		if picked.size() >= count:
			break
		picked.append(e)
	_last_edges = picked.duplicate()
	return picked


func _spawn_splat(edge: int, base: Color, size_boost: float, delay: float) -> void:
	var w := size.x
	var h := size.y
	var s := Splat.new()
	s.radius = _rng.randf_range(70.0, 110.0) * size_boost
	s.delay = delay
	# Juicier colours: a touch more saturated, plus darker shade and a light highlight.
	s.color = Color.from_hsv(base.h, clampf(base.s * 1.15, 0.0, 1.0), clampf(base.v * 1.02, 0.0, 1.0))
	s.shade = s.color.darkened(0.25)
	s.highlight = s.color.lightened(0.45)

	var off := s.radius * 0.35
	match edge:
		Edge.LEFT:
			s.center = Vector2(-off, h * _rng.randf_range(0.3, 0.7))
			s.inward = Vector2.RIGHT
		Edge.RIGHT:
			s.center = Vector2(w + off, h * _rng.randf_range(0.3, 0.7))
			s.inward = Vector2.LEFT
		Edge.TOP_LEFT:
			s.center = Vector2(-off * 0.5, h * _rng.randf_range(0.12, 0.22))
			s.inward = Vector2(1.0, 0.4).normalized()
		Edge.TOP_RIGHT:
			s.center = Vector2(w + off * 0.5, h * _rng.randf_range(0.12, 0.22))
			s.inward = Vector2(-1.0, 0.4).normalized()
		Edge.BOTTOM_LEFT:
			s.center = Vector2(-off * 0.5, h * _rng.randf_range(0.74, 0.84))
			s.inward = Vector2(1.0, -0.3).normalized()
		_:
			s.center = Vector2(w + off * 0.5, h * _rng.randf_range(0.74, 0.84))
			s.inward = Vector2(-1.0, -0.3).normalized()

	# Irregular lobes around the rim (biased toward the screen) so it reads as a splat.
	var lobe_count := _rng.randi_range(6, 9)
	for i in range(lobe_count):
		var ang := TAU * float(i) / float(lobe_count) + _rng.randf_range(-0.3, 0.3)
		var dir := Vector2(cos(ang), sin(ang))
		var toward := clampf(dir.dot(s.inward), 0.0, 1.0)
		var dist := _rng.randf_range(0.7, 0.95) + 0.25 * toward
		s.lobes.append(Vector3(dir.x * dist, dir.y * dist, _rng.randf_range(0.22, 0.42) + 0.12 * toward))

	# Droplets flung inward in a cone.
	var drop_count := _rng.randi_range(6, 10)
	for i in range(drop_count):
		var ang := s.inward.angle() + _rng.randf_range(-0.9, 0.9)
		var dist := s.radius * _rng.randf_range(1.15, 2.2)
		var r := _rng.randf_range(6.0, 20.0) * (1.4 - dist / (s.radius * 2.6))
		s.drops.append(Vector3(cos(ang) * dist, sin(ang) * dist, maxf(r, 5.0)))

	# Drips running down from the blob.
	var drip_count := _rng.randi_range(2, 4)
	for i in range(drip_count):
		var x := _rng.randf_range(-0.55, 0.55) * s.radius + s.inward.x * s.radius * 0.25
		s.drips.append(Vector3(x, s.radius * _rng.randf_range(1.1, 2.3), _rng.randf_range(0.7, 1.3)))

	_splats.append(s)


func _process(delta: float) -> void:
	var i := _splats.size() - 1
	while i >= 0:
		var s := _splats[i]
		s.age += delta
		if s.age >= s.delay + LIFE:
			_splats.remove_at(i)
		i -= 1
	if _splats.is_empty():
		set_process(false)
	queue_redraw()


static func _snap(v: float) -> float:
	return floorf(v / BLOCK) * BLOCK


func _draw() -> void:
	for s: Splat in _splats:
		var local_age := s.age - s.delay
		if local_age < 0.0:
			continue
		var t := local_age / LIFE
		# Pop in with a little overshoot, then hold.
		var pop := clampf(local_age / POP_TIME, 0.0, 1.0)
		var grow := 1.0 + 0.18 * sin(pop * PI) if pop < 1.0 else 1.0
		grow *= lerpf(0.35, 1.0, pop)
		var alpha := PEAK_ALPHA if t < 0.55 else lerpf(PEAK_ALPHA, 0.0, (t - 0.55) / 0.45)
		# Second half: checkerboard dither for a pixel-art fade.
		var dither := 0
		if t > 0.7:
			dither = 2
		elif t > 0.55:
			dither = 1

		var col := Color(s.color.r, s.color.g, s.color.b, alpha)
		var shade := Color(s.shade.r, s.shade.g, s.shade.b, alpha)
		var hi := Color(s.highlight.r, s.highlight.g, s.highlight.b, alpha)

		# Drips (behind the blob), growing downward over time.
		var drip_t := clampf((local_age - POP_TIME) / 0.9, 0.0, 1.0)
		for d: Vector3 in s.drips:
			var length := d.y * drip_t * d.z
			if length <= BLOCK:
				continue
			var x := _snap(s.center.x + d.x)
			var top := _snap(s.center.y + s.radius * 0.6)
			_block_rect(Rect2(x, top, BLOCK * 2.0, _snap(length)), shade, dither)
			# Round drop at the end of the drip.
			_pixel_disc(Vector2(x + BLOCK, top + length), BLOCK * 1.6, col, dither)

		# Main blob: dark rim, body, then a highlight toward the screen centre.
		var r := s.radius * grow
		# Dark rim pass, then body pass (core + lobes), then a small highlight.
		_pixel_disc(s.center, r * 0.85 + BLOCK, shade, dither)
		for l: Vector3 in s.lobes:
			_pixel_disc(s.center + Vector2(l.x, l.y) * r, l.z * r + BLOCK, shade, dither)
		_pixel_disc(s.center, r * 0.85, col, dither)
		for l: Vector3 in s.lobes:
			_pixel_disc(s.center + Vector2(l.x, l.y) * r, l.z * r, col, dither)
		_pixel_disc(s.center + s.inward * r * 0.3 + Vector2(0.0, -r * 0.3), r * 0.16, hi, dither)

		# Droplets fly out a little during the pop.
		var fly := lerpf(0.55, 1.0, pop)
		for p: Vector3 in s.drops:
			var c := s.center + Vector2(p.x, p.y) * fly
			_pixel_disc(c, p.z * grow, col, dither)
			if p.z > 10.0:
				_pixel_disc(c + Vector2(-p.z * 0.3, -p.z * 0.3), p.z * 0.35, hi, dither)


## Filled circle on the block grid. dither 0 = solid, 1 = few holes, 2 = checkerboard.
func _pixel_disc(center: Vector2, radius: float, col: Color, dither: int) -> void:
	if radius < BLOCK * 0.5:
		return
	var rows := int(ceilf(radius / BLOCK))
	var cy := _snap(center.y)
	for iy in range(-rows, rows):
		var yc := (float(iy) + 0.5) * BLOCK
		var half_sq := radius * radius - yc * yc
		if half_sq <= 0.0:
			continue
		var half := _snap(sqrt(half_sq) + BLOCK * 0.5)
		if half <= 0.0:
			continue
		var y := cy + float(iy) * BLOCK
		var x0 := _snap(center.x - half)
		var width := half * 2.0
		if dither == 0:
			draw_rect(Rect2(x0, y, width, BLOCK), col)
		else:
			_block_rect(Rect2(x0, y, width, BLOCK), col, dither)


## Rect drawn block by block so it can be dithered.
func _block_rect(rect: Rect2, col: Color, dither: int) -> void:
	if dither == 0:
		draw_rect(rect, col)
		return
	var nx := int(rect.size.x / BLOCK)
	var ny := maxi(int(rect.size.y / BLOCK), 1)
	for by in range(ny):
		for bx in range(nx):
			var gx := int(rect.position.x / BLOCK) + bx
			var gy := int(rect.position.y / BLOCK) + by
			var parity := posmod(gx + gy, 2)
			if dither == 2 and parity == 0:
				continue
			if dither == 1 and posmod(gx * 3 + gy * 5, 4) == 0:
				continue
			draw_rect(Rect2(rect.position.x + float(bx) * BLOCK, rect.position.y + float(by) * BLOCK, BLOCK, BLOCK), col)
