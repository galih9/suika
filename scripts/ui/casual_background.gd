class_name CasualBackground
extends Control

## Sunny sky gradient with slowly drifting pixel clouds and twinkling pixel sparkles.
## Cheap: a handful of rects per frame, no textures.

const BLOCK := 8.0

@export var top_color: Color = UITheme.SKY_TOP
@export var bottom_color: Color = UITheme.SKY_BOTTOM
@export var cloud_count: int = 6
@export var sparkle_count: int = 14
@export var animate: bool = true

var _clouds: Array[Dictionary] = []
var _sparkles: Array[Dictionary] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7331
	resized.connect(_rebuild)
	_rebuild()
	set_process(animate)


func _rebuild() -> void:
	_clouds.clear()
	_sparkles.clear()
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	for i in range(cloud_count):
		_clouds.append({
			"x": _rng.randf_range(-120.0, w),
			"y": _rng.randf_range(h * 0.04, h * 0.92),
			"scale": _rng.randf_range(0.7, 1.5),
			"speed": _rng.randf_range(6.0, 16.0),
			"alpha": _rng.randf_range(0.35, 0.7),
		})
	for i in range(sparkle_count):
		_sparkles.append({
			"x": _rng.randf_range(0.0, w),
			"y": _rng.randf_range(0.0, h),
			"phase": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(1.2, 2.6),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var w := size.x
	for c in _clouds:
		c["x"] = float(c["x"]) + float(c["speed"]) * delta
		if float(c["x"]) > w + 40.0:
			c["x"] = -220.0 * float(c["scale"])
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Banded gradient (8 steps) reads as pixel-art dithering rather than a smooth blend.
	var bands := 10
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var y0 := floorf(h * float(i) / float(bands))
		var y1 := floorf(h * float(i + 1) / float(bands)) + 1.0
		draw_rect(Rect2(0.0, y0, w, y1 - y0), top_color.lerp(bottom_color, t))

	for c in _clouds:
		_draw_cloud(float(c["x"]), float(c["y"]), float(c["scale"]), float(c["alpha"]))

	for s in _sparkles:
		var tw := 0.5 + 0.5 * sin(_time * float(s["speed"]) + float(s["phase"]))
		if tw < 0.35:
			continue
		var px := floorf(float(s["x"]) / 4.0) * 4.0
		var py := floorf(float(s["y"]) / 4.0) * 4.0
		var col := Color(1.0, 1.0, 1.0, 0.25 + 0.55 * tw)
		var arm := 4.0 if tw > 0.8 else 0.0
		draw_rect(Rect2(px, py, 4.0, 4.0), col)
		if arm > 0.0:
			draw_rect(Rect2(px - arm, py, 4.0, 4.0), col)
			draw_rect(Rect2(px + arm, py, 4.0, 4.0), col)
			draw_rect(Rect2(px, py - arm, 4.0, 4.0), col)
			draw_rect(Rect2(px, py + arm, 4.0, 4.0), col)


## A blocky cloud: three overlapping pixel circles on a flat base.
func _draw_cloud(x: float, y: float, s: float, alpha: float) -> void:
	# Opaque colour (sky blended toward white) so overlapping blobs don't double up.
	var t := clampf(y / maxf(size.y, 1.0), 0.0, 1.0)
	var col := top_color.lerp(bottom_color, t).lerp(Color.WHITE, alpha)
	var base_y := floorf(y / BLOCK) * BLOCK
	var bx := floorf(x / BLOCK) * BLOCK
	_pixel_disc(bx + 40.0 * s, base_y - 4.0 * s, 26.0 * s, col)
	_pixel_disc(bx + 88.0 * s, base_y - 18.0 * s, 36.0 * s, col)
	_pixel_disc(bx + 140.0 * s, base_y - 2.0 * s, 24.0 * s, col)
	draw_rect(Rect2(bx + 16.0 * s, base_y, 150.0 * s, BLOCK * 2.0), col)


## Filled circle made of BLOCK-sized rows (one rect per row, so it stays cheap).
func _pixel_disc(cx: float, cy: float, r: float, col: Color) -> void:
	var rows := int(ceilf(r / BLOCK))
	for iy in range(-rows, rows):
		var yc := (float(iy) + 0.5) * BLOCK
		var half_sq := r * r - yc * yc
		if half_sq <= 0.0:
			continue
		var half := floorf(sqrt(half_sq) / BLOCK) * BLOCK
		if half <= 0.0:
			continue
		var top := floorf((cy + float(iy) * BLOCK) / BLOCK) * BLOCK
		draw_rect(Rect2(floorf((cx - half) / BLOCK) * BLOCK, top, half * 2.0, BLOCK), col)
