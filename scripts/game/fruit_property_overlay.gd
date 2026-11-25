class_name FruitPropertyOverlay
extends Sprite2D

## Shows a fruit's Frenzy property using shared assets only:
## - Bomb / Nuclear: the pixel-art power-up icon on top of the fruit.
## - Sticky / Concrete / Charged: a shared tint + outline ShaderMaterial on the fruit sprite.
## No per-frame _process, no Labels or StyleBoxes, so property fruits stay cheap.

## The bomb icon starts blinking red during the last seconds of its fuse.
const BOMB_BLINK_START := 3.0
const BOMB_BLINK_COLOR := Color(1.0, 0.35, 0.35)

var fruit_property: FruitProperty.Type = FruitProperty.Type.NONE
var radius: float = 20.0
var is_preview: bool = false
var is_stuck: bool = false
var concrete_landed: bool = false

var bomb_timer: float = 0.0:
	set(value):
		bomb_timer = value
		if fruit_property == FruitProperty.Type.BOMB and visible and not is_preview:
			_update_bomb_blink()

var _target_sprite: CanvasItem


func _init() -> void:
	centered = true
	visible = false
	set_process(false)


## The fruit sprite that receives the tint/outline material.
func bind_target(sprite: CanvasItem) -> void:
	_target_sprite = sprite


func reset() -> void:
	fruit_property = FruitProperty.Type.NONE
	radius = 20.0
	bomb_timer = 0.0
	is_stuck = false
	concrete_landed = false
	is_preview = false
	texture = null
	rotation = 0.0
	scale = Vector2.ONE
	self_modulate = Color.WHITE
	visible = false
	if _target_sprite != null:
		_target_sprite.material = null


func configure(prop: FruitProperty.Type, r: float, preview: bool = false) -> void:
	fruit_property = prop
	radius = r
	is_preview = preview
	rotation = 0.0
	self_modulate = Color.WHITE

	if _target_sprite != null:
		_target_sprite.material = FruitRegistry.textures.get_property_material(prop)

	var icon := FruitRegistry.textures.get_property_icon(prop)
	texture = icon
	visible = icon != null
	if icon != null:
		# Integer pixel scale (2x..4x) keeps the 16px icon crisp on every fruit size.
		var s := float(clampi(roundi(r / 16.0), 2, 4))
		scale = Vector2(s, s)


func _update_bomb_blink() -> void:
	if bomb_timer > BOMB_BLINK_START or bomb_timer <= 0.0:
		self_modulate = Color.WHITE
		return
	var period := lerpf(0.12, 0.5, bomb_timer / BOMB_BLINK_START)
	var on := fmod(bomb_timer, period) < period * 0.5
	self_modulate = BOMB_BLINK_COLOR if on else Color.WHITE
