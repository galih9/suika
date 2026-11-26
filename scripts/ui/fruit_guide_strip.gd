class_name FruitGuideStrip
extends PanelContainer

## Bottom fruit guide: every tier as a small icon, with three states per fruit:
##  - never discovered (dark silhouette, the next one to find pulses with a "?"),
##  - discovered before but not made in this run (faded gray),
##  - made in this run (full colour).
## `play_unlock()` animates a fruit coming alive (pop, flash, pixel sparkles, "NEW!" tag).

const SLOT_W := 42.0
const SLOT_H := 50.0

var _slots: Array[Control] = []
var _icons: Array[TextureRect] = []
var _materials: Array[ShaderMaterial] = []
var _made_this_run: Dictionary = {}
var _count_label: Label
var _title_label: Label
var _row: HBoxContainer
var _goal_level: int = -1
var _goal_hint: TextureRect
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 28, 14, 8, 7))
	_build()
	reset_run()


func _build() -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	_title_label = UITheme.make_label(Loc.t("guide.title"), 18, UITheme.TEXT_MUTED, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_count_label = UITheme.make_label("1 / 15 found", 18, UITheme.ORANGE_SHADOW, true)
	header.add_child(_count_label)

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 0)
	col.add_child(_row)

	var catalog := FruitRegistry.catalog
	var count := catalog.get_count()
	for i in range(count):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(slot)

		var t := float(i) / float(maxi(count - 1, 1))
		var px := lerpf(22.0, 44.0, t)
		var icon := UITheme.make_fruit_icon(i, px)
		icon.size = Vector2(px, px)
		var mat := UITheme.make_icon_material()
		icon.material = mat
		slot.add_child(icon)
		slot.resized.connect(_center_icon.bind(slot, icon))

		_slots.append(slot)
		_icons.append(icon)
		_materials.append(mat)


func _center_icon(slot: Control, icon: TextureRect) -> void:
	icon.position = (slot.size - icon.size) * 0.5
	icon.pivot_offset = icon.size * 0.5


func _process(delta: float) -> void:
	_time += delta
	if _goal_level >= 0 and _goal_level < _icons.size():
		var icon := _icons[_goal_level]
		var s := 1.0 + 0.12 * absf(sin(_time * 3.0))
		if not icon.has_meta(&"animating"):
			icon.scale = Vector2(s, s)
		if _goal_hint != null:
			_goal_hint.modulate.a = 0.55 + 0.45 * absf(sin(_time * 3.0))
			_goal_hint.position = Vector2(_slots[_goal_level].size.x - 15.0, -4.0)


## Call at the start of every run.
func reset_run() -> void:
	_made_this_run.clear()
	_made_this_run[0] = true
	for i in range(_icons.size()):
		_icons[i].scale = Vector2.ONE
		_icons[i].rotation = 0.0
		_icons[i].remove_meta(&"animating")
		_apply_state(i)
	_refresh_goal()
	_refresh_count()


func is_made_this_run(level: int) -> bool:
	return _made_this_run.has(level)


func refresh_skin() -> void:
	for i in range(_icons.size()):
		_icons[i].texture = FruitRegistry.textures.get_texture(i)


func refresh_language() -> void:
	if _title_label != null:
		_title_label.text = Loc.t("guide.title")
	_refresh_count()


## Global-space centre of a slot (for fly-in animations).
func get_slot_global_center(level: int) -> Vector2:
	if level < 0 or level >= _slots.size():
		return global_position + size * 0.5
	var slot := _slots[level]
	return slot.global_position + slot.size * 0.5


func get_slot_icon_size(level: int) -> float:
	if level < 0 or level >= _icons.size():
		return 32.0
	return _icons[level].size.x


## Animate a fruit becoming "made this run". first_ever = brand new discovery (bigger party).
func play_unlock(level: int, first_ever: bool) -> void:
	if level < 0 or level >= _icons.size():
		return
	_made_this_run[level] = true
	var icon := _icons[level]
	var mat := _materials[level]
	icon.set_meta(&"animating", true)

	mat.set_shader_parameter("flash", 1.0)
	var set_silhouette := func(v: float) -> void:
		mat.set_shader_parameter("silhouette", v)
	var set_gray := func(v: float) -> void:
		mat.set_shader_parameter("gray", v)
	var set_flash := func(v: float) -> void:
		mat.set_shader_parameter("flash", v)
	icon.modulate = Color.WHITE
	var tw := icon.create_tween().set_parallel(true)
	tw.tween_method(set_silhouette, _get_param(mat, "silhouette"), 0.0, 0.3)
	tw.tween_method(set_gray, _get_param(mat, "gray"), 0.0, 0.3)
	tw.tween_method(set_flash, 1.0, 0.0, 0.45)
	icon.scale = Vector2(0.4, 0.4)
	var big := 2.0 if first_ever else 1.5
	var pop := icon.create_tween()
	pop.tween_property(icon, "scale", Vector2(big, big), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop.tween_callback(func() -> void: icon.remove_meta(&"animating"))
	var wiggle := icon.create_tween()
	wiggle.tween_property(icon, "rotation", 0.35, 0.08)
	wiggle.tween_property(icon, "rotation", -0.25, 0.1)
	wiggle.tween_property(icon, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_BACK)

	_spawn_sparkles(level, 14 if first_ever else 7)
	if first_ever:
		_spawn_new_tag(level)
	_refresh_goal()
	_refresh_count()
	# Little bump on the whole bar.
	pivot_offset = size * 0.5
	var bump := create_tween()
	bump.tween_property(self, "scale", Vector2(1.03, 1.03), 0.08)
	bump.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _get_param(mat: ShaderMaterial, param: String) -> float:
	var v: Variant = mat.get_shader_parameter(param)
	return float(v) if v != null else 0.0


func _apply_state(level: int) -> void:
	var mat := _materials[level]
	mat.set_shader_parameter("flash", 0.0)
	if _made_this_run.has(level):
		mat.set_shader_parameter("silhouette", 0.0)
		mat.set_shader_parameter("gray", 0.0)
		_icons[level].modulate = Color.WHITE
	elif SaveManager.is_discovered(level):
		mat.set_shader_parameter("silhouette", 0.0)
		mat.set_shader_parameter("gray", 1.0)
		_icons[level].modulate = Color(1.0, 1.0, 1.0, 0.45)
	else:
		mat.set_shader_parameter("silhouette", 1.0)
		mat.set_shader_parameter("gray", 0.0)
		_icons[level].modulate = Color.WHITE


func _refresh_goal() -> void:
	if _goal_hint != null:
		_goal_hint.queue_free()
		_goal_hint = null
	if _goal_level >= 0 and _goal_level < _icons.size() and not _icons[_goal_level].has_meta(&"animating"):
		_icons[_goal_level].scale = Vector2.ONE
	_goal_level = SaveManager.get_next_undiscovered(_icons.size())
	if _goal_level >= 0:
		var slot := _slots[_goal_level]
		_goal_hint = PixelIcons.make_rect("question", 16.0, UITheme.GOLD_SHADOW)
		_goal_hint.size = Vector2(16, 16)
		_goal_hint.position = Vector2(slot.size.x - 16.0, -2.0)
		slot.add_child(_goal_hint)
	# Re-apply visuals for any slot not mid-animation.
	for i in range(_icons.size()):
		if not _icons[i].has_meta(&"animating"):
			_apply_state(i)


func _refresh_count() -> void:
	var total := _icons.size()
	_count_label.text = Loc.t("guide.found", [SaveManager.get_discovered_count(total), total])


func _spawn_sparkles(level: int, count: int) -> void:
	var slot := _slots[level]
	var burst := PixelBurst.new()
	burst.position = slot.size * 0.5
	burst.count = count
	burst.color = UITheme.GOLD
	slot.add_child(burst)


func _spawn_new_tag(level: int) -> void:
	var slot := _slots[level]
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PINK, UITheme.PINK_SHADOW, 10, 0, 6, 1))
	var lbl := UITheme.make_label(Loc.t("guide.new"), 14, Color.WHITE, true)
	tag.add_child(lbl)
	slot.add_child(tag)
	tag.reset_size()
	var sz := tag.get_combined_minimum_size()
	tag.size = sz
	tag.position = Vector2((slot.size.x - sz.x) * 0.5, -sz.y - 2.0)
	tag.pivot_offset = sz * 0.5
	tag.scale = Vector2(0.2, 0.2)
	var tw := tag.create_tween()
	tw.tween_property(tag, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(tag, "modulate:a", 0.0, 0.4)
	tw.tween_callback(tag.queue_free)
