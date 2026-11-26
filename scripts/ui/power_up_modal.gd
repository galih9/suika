class_name PowerUpModal
extends Control

## Pop-up card explaining the Frenzy power-ups. Built in code so the Menu and the Game can both
## use it: `var modal := PowerUpModal.new(); add_child(modal); modal.open()`.

signal closed

const ENTRIES: Array[FruitProperty.Type] = [
	FruitProperty.Type.STICKY,
	FruitProperty.Type.BOMB,
	FruitProperty.Type.NUCLEAR,
	FruitProperty.Type.CONCRETE,
	FruitProperty.Type.CHARGED,
]

## Fruit used to preview the tint-style power-ups (Sticky / Concrete / Charged).
const PREVIEW_FRUIT_LEVEL := 6

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _ok_button: Button
var _row_entries: Array[Dictionary] = []
var _preview_icons: Array[TextureRect] = []
var _is_open: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.1, 0.16, 0.3, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(620, 0)
	_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 34, 26, 24, 9))
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_card.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	var bolt := PixelIcons.make_rect("bolt", 40.0, UITheme.PINK)
	header.add_child(bolt)

	_title_label = UITheme.make_label(Loc.t("pu.title"), 40, UITheme.TEXT_DARK, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := UITheme.make_icon_button("close", UITheme.CARD_WHITE, UITheme.CARD_SHADOW, UITheme.TEXT_MUTED, 60.0, 26.0)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	_subtitle_label = UITheme.make_label(Loc.t("pu.subtitle"), 20, UITheme.TEXT_MUTED)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(560, 0)
	col.add_child(_subtitle_label)

	_row_entries.clear()
	for prop in ENTRIES:
		col.add_child(_make_row(prop, Loc.t("pu.%s.desc" % Loc.prop_key(prop))))

	_ok_button = Button.new()
	_ok_button.text = Loc.t("pu.ok")
	_ok_button.custom_minimum_size = Vector2(0, 84)
	_ok_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_primary_button(_ok_button, 28, 32)
	_ok_button.pressed.connect(close)
	col.add_child(_ok_button)


func _make_row(prop: FruitProperty.Type, desc: String) -> Control:
	var accent := FruitProperty.get_color(prop)
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(accent.lerp(Color.WHITE, 0.82), accent.lerp(Color.WHITE, 0.4), 22, 0, 14, 10)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row_panel.add_child(row)

	var icon := make_power_up_icon(prop, 64.0)
	if FruitRegistry.textures.get_property_icon(prop) == null:
		_preview_icons.append(icon)
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var name_lbl := UITheme.make_label(FruitProperty.get_display_name(prop), 26, FruitProperty.get_accent_color(prop), true)
	text_col.add_child(name_lbl)

	var desc_lbl := UITheme.make_label(desc, 19, UITheme.TEXT_DARK)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(440, 0)
	text_col.add_child(desc_lbl)
	_row_entries.append({
		"prop": prop,
		"name_label": name_lbl,
		"desc_label": desc_lbl,
	})
	return row_panel


## Icon for a power-up: the bomb/nuke sprite, or a fruit wearing the power-up tint.
static func make_power_up_icon(prop: FruitProperty.Type, px: float = 56.0) -> TextureRect:
	var icon_tex := FruitRegistry.textures.get_property_icon(prop)
	var icon: TextureRect
	if icon_tex != null:
		icon = TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(px, px)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		icon = UITheme.make_fruit_icon(PREVIEW_FRUIT_LEVEL, px)
		icon.material = FruitRegistry.textures.get_property_material(prop)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func refresh_language() -> void:
	if _title_label != null:
		_title_label.text = Loc.t("pu.title")
	if _subtitle_label != null:
		_subtitle_label.text = Loc.t("pu.subtitle")
	if _ok_button != null:
		_ok_button.text = Loc.t("pu.ok")
	for entry in _row_entries:
		var prop: FruitProperty.Type = entry["prop"]
		var name_lbl: Label = entry["name_label"]
		var desc_lbl: Label = entry["desc_label"]
		name_lbl.text = FruitProperty.get_display_name(prop)
		desc_lbl.text = Loc.t("pu.%s.desc" % Loc.prop_key(prop))


func refresh_skin() -> void:
	var tex := FruitRegistry.textures.get_texture(PREVIEW_FRUIT_LEVEL)
	for icon in _preview_icons:
		if icon != null and is_instance_valid(icon):
			icon.texture = tex


func open() -> void:
	if _is_open:
		return
	_is_open = true
	refresh_language()
	refresh_skin()
	visible = true
	AudioManager.play_click()
	_dim.modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.18)
	tw.tween_property(_card, "modulate:a", 1.0, 0.14)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Card size is only known after layout; re-center the pivot next frame.
	await get_tree().process_frame
	_card.pivot_offset = _card.size * 0.5


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	AudioManager.play_click()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.14)
	tw.tween_property(_card, "modulate:a", 0.0, 0.12)
	tw.tween_property(_card, "scale", Vector2(0.9, 0.9), 0.12)
	tw.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)


func is_open() -> bool:
	return _is_open


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
