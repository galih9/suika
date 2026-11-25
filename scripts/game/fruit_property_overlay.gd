class_name FruitPropertyOverlay
extends Node2D

## Lightweight upright letter badge overlay indicating a fruit's Frenzy property.

var fruit_property: FruitProperty.Type = FruitProperty.Type.NONE
var radius: float = 20.0
var is_preview: bool = false

var bomb_timer: float = 0.0:
	set(value):
		bomb_timer = value
		if fruit_property == FruitProperty.Type.BOMB and visible:
			_refresh_label()

var is_stuck: bool = false:
	set(value):
		if is_stuck == value:
			return
		is_stuck = value
		if fruit_property == FruitProperty.Type.STICKY and visible:
			_refresh_label()

var concrete_landed: bool = false:
	set(value):
		if concrete_landed == value:
			return
		concrete_landed = value
		if fruit_property == FruitProperty.Type.CONCRETE and visible:
			_refresh_appearance()

var _label: Label
var _badge_style: StyleBoxFlat
var _last_text: String = ""


func _init() -> void:
	visible = false
	set_process(false)

	_badge_style = StyleBoxFlat.new()
	_badge_style.set_corner_radius_all(8)
	_badge_style.set_border_width_all(2)
	_badge_style.border_color = Color(1.0, 1.0, 1.0, 0.85)
	_badge_style.content_margin_left = 6
	_badge_style.content_margin_right = 6
	_badge_style.content_margin_top = 2
	_badge_style.content_margin_bottom = 2

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_stylebox_override("normal", _badge_style)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)


func reset() -> void:
	fruit_property = FruitProperty.Type.NONE
	radius = 20.0
	bomb_timer = 0.0
	is_stuck = false
	concrete_landed = false
	is_preview = false
	_last_text = ""
	rotation = 0.0
	modulate = Color.WHITE
	visible = false
	set_process(false)


func configure(prop: FruitProperty.Type, r: float, preview: bool = false) -> void:
	fruit_property = prop
	radius = r
	is_preview = preview
	rotation = 0.0
	visible = (prop != FruitProperty.Type.NONE)
	set_process(visible and not preview)

	if not visible:
		_last_text = ""
		return

	var font_sz := int(clampf(radius * 0.52, 11.0, 24.0))
	_label.add_theme_font_size_override("font_size", font_sz)
	_badge_style.bg_color = FruitProperty.get_accent_color(prop)
	_last_text = ""
	_refresh_appearance()
	_refresh_label()


func _process(_delta: float) -> void:
	if not visible or is_preview:
		return
	var p := get_parent()
	if p is Node2D:
		var target_rot := -(p as Node2D).rotation
		if not is_equal_approx(rotation, target_rot):
			rotation = target_rot


func _refresh_appearance() -> void:
	if fruit_property == FruitProperty.Type.CONCRETE and concrete_landed:
		modulate = Color(1.0, 1.0, 1.0, 0.45)
	else:
		modulate = Color.WHITE


func _refresh_label() -> void:
	var next_text := FruitProperty.get_letter(fruit_property)
	if fruit_property == FruitProperty.Type.BOMB and not is_preview:
		var t_str := "%.1f" % maxf(bomb_timer, 0.0) if bomb_timer < 2.0 else str(ceili(bomb_timer))
		next_text = "B %s" % t_str

	if _last_text == next_text:
		return
	_last_text = next_text
	_label.text = next_text
	_label.reset_size()
	_label.position = -_label.size * 0.5
