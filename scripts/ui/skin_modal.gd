class_name SkinModal
extends Control

## Pop-up card letting the player choose and preview fruit skins from the Menu or Pause screen.

signal closed
signal skin_selected(skin_id: String)

const PREVIEW_SIZES := [32.0, 38.0, 44.0, 50.0, 56.0]

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _done_button: Button
var _cards_box: VBoxContainer
var _card_entries: Array[Dictionary] = []
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

	var palette_icon := PixelIcons.make_rect("palette", 40.0, UITheme.BLUE)
	header.add_child(palette_icon)

	_title_label = UITheme.make_label(Loc.t("skin.title"), 40, UITheme.TEXT_DARK, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := UITheme.make_icon_button("close", UITheme.CARD_WHITE, UITheme.CARD_SHADOW, UITheme.TEXT_MUTED, 60.0, 26.0)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	_subtitle_label = UITheme.make_label(Loc.t("skin.subtitle"), 20, UITheme.TEXT_MUTED)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(560, 0)
	col.add_child(_subtitle_label)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 12)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var all_skins := FruitRegistry.skins.get_skins()
	if all_skins.size() > 4:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 620)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		scroll.add_child(_cards_box)
	else:
		col.add_child(_cards_box)

	_card_entries.clear()
	for skin in all_skins:
		var entry := _make_skin_card(skin)
		_cards_box.add_child(entry["button"])
		_card_entries.append(entry)

	_done_button = Button.new()
	_done_button.text = Loc.t("skin.done")
	_done_button.custom_minimum_size = Vector2(0, 80)
	_done_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_primary_button(_done_button, 28, 32)
	_done_button.pressed.connect(close)
	col.add_child(_done_button)

	_refresh_cards()


func _make_skin_card(skin: SkinDefinition) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 158)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.add_press_juice(btn)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 20)
	btn.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 0)
	top.add_child(text_col)

	var name_lbl := UITheme.make_label(Loc.t(skin.name_key), 26, UITheme.TEXT_DARK, true)
	text_col.add_child(name_lbl)

	var desc_lbl := UITheme.make_label(Loc.t(skin.desc_key), 18, UITheme.TEXT_MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(desc_lbl)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(skin.accent_color, skin.accent_shadow, 14, 0, 12, 4)
	)
	var badge_row := HBoxContainer.new()
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_theme_constant_override("separation", 6)
	badge.add_child(badge_row)
	var check_icon := PixelIcons.make_rect("check", 18.0, Color.WHITE)
	check_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_row.add_child(check_icon)
	var badge_lbl := UITheme.make_label(Loc.t("skin.equipped"), 18, Color.WHITE, true)
	badge_row.add_child(badge_lbl)
	top.add_child(badge)

	var preview_row := HBoxContainer.new()
	preview_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 14)
	preview_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_row)

	var count := mini(skin.preview_levels.size(), PREVIEW_SIZES.size())
	for i in range(count):
		var lvl := int(skin.preview_levels[i])
		var px := float(PREVIEW_SIZES[i])
		var icon := TextureRect.new()
		icon.texture = FruitRegistry.textures.get_skin_texture(skin, lvl)
		icon.custom_minimum_size = Vector2(px, px)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_END
		preview_row.add_child(icon)

	btn.pressed.connect(_on_card_pressed.bind(skin.id, btn))
	return {
		"skin": skin,
		"button": btn,
		"badge": badge,
		"name_label": name_lbl,
		"desc_label": desc_lbl,
		"badge_label": badge_lbl,
	}


func _refresh_cards() -> void:
	var active_id := FruitRegistry.active_skin_id
	for entry in _card_entries:
		var skin: SkinDefinition = entry["skin"]
		var btn: Button = entry["button"]
		var badge: PanelContainer = entry["badge"]
		var selected := (skin.id == active_id)
		badge.visible = selected

		if selected:
			var face := skin.accent_color.lerp(Color.WHITE, 0.80)
			var normal := _make_card_button_style(face, skin.accent_color, false, true)
			var hover := _make_card_button_style(face.lightened(0.04), skin.accent_color, false, true)
			var pressed := _make_card_button_style(face.darkened(0.04), skin.accent_color, true, true)
			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", pressed)
		else:
			var face := Color("#F4FAFD")
			var shadow := Color("#D3E6EE")
			btn.add_theme_stylebox_override("normal", _make_card_button_style(face, shadow, false, false))
			btn.add_theme_stylebox_override("hover", _make_card_button_style(face.lightened(0.04), shadow, false, false))
			btn.add_theme_stylebox_override("pressed", _make_card_button_style(face.darkened(0.04), shadow, true, false))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_card_button_style(face: Color, shadow: Color, pressed: bool, highlighted: bool) -> StyleBoxFlat:
	var sb := UITheme.make_chunky_style(face, shadow, 24, pressed, 0, 0)
	if highlighted:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
	return sb


func _on_card_pressed(skin_id: String, btn: Button) -> void:
	var changed := FruitRegistry.set_skin(skin_id)
	if changed:
		AudioManager.play_pop(1.15)
	else:
		AudioManager.play_click()
	_refresh_cards()
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.04, 1.04)
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	skin_selected.emit(skin_id)


func refresh_language() -> void:
	if _title_label != null:
		_title_label.text = Loc.t("skin.title")
	if _subtitle_label != null:
		_subtitle_label.text = Loc.t("skin.subtitle")
	if _done_button != null:
		_done_button.text = Loc.t("skin.done")
	for entry in _card_entries:
		var skin: SkinDefinition = entry["skin"]
		var name_lbl: Label = entry["name_label"]
		var desc_lbl: Label = entry["desc_label"]
		var badge_lbl: Label = entry["badge_label"]
		name_lbl.text = Loc.t(skin.name_key)
		desc_lbl.text = Loc.t(skin.desc_key)
		badge_lbl.text = Loc.t("skin.equipped")


func get_card_count() -> int:
	return _card_entries.size()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	refresh_language()
	_refresh_cards()
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
