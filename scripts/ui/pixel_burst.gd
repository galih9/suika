class_name PixelBurst
extends Control

## One-shot UI sparkle burst: chunky pixel squares + "+" twinkles flying out from the origin.
## Add it as a child at the burst centre; it frees itself when done.

const PX := 4.0

@export var count: int = 10
@export var color: Color = UITheme.GOLD
@export var speed: float = 160.0
@export var life: float = 0.6

var _parts: Array[Dictionary] = []
var _age: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var palette := [color, Color.WHITE, color.lightened(0.4)]
	for i in range(count):
		var a := TAU * float(i) / float(maxi(count, 1)) + randf_range(-0.3, 0.3)
		_parts.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.6, 1.3),
			"col": palette[i % palette.size()],
			"size": PX * (2.0 if i % 3 == 0 else 1.0),
			"star": i % 4 == 0,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	for p in _parts:
		var v: Vector2 = p["vel"]
		v *= maxf(1.0 - 3.0 * delta, 0.0)
		v.y += 220.0 * delta
		p["vel"] = v
		p["pos"] = Vector2(p["pos"]) + v * delta
	queue_redraw()


func _draw() -> void:
	var t := _age / life
	for p in _parts:
		var pos: Vector2 = p["pos"]
		var x := floorf(pos.x / PX) * PX
		var y := floorf(pos.y / PX) * PX
		var col: Color = p["col"]
		col.a = 1.0 - t * t
		var sz := float(p["size"]) if t < 0.5 else PX
		if bool(p["star"]) and t < 0.7:
			draw_rect(Rect2(x - PX, y, PX * 3.0, PX), col)
			draw_rect(Rect2(x, y - PX, PX, PX * 3.0), col)
		else:
			draw_rect(Rect2(x, y, sz, sz), col)
