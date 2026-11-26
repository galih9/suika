class_name LanguageModal
extends Control

## Pop-up card letting the player choose the game language with flag badges.

signal closed
signal language_selected(code: String)

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _done_button: Button
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
	_card.custom_minimum_size = Vector2(640, 0)
	_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 34, 24, 24, 9))
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_card.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	var globe_icon := PixelIcons.make_rect("globe", 40.0, UITheme.BLUE)
	header.add_child(globe_icon)

	_title_label = UITheme.make_label(Loc.t("lang.title"), 40, UITheme.TEXT_DARK, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := UITheme.make_icon_button("close", UITheme.CARD_WHITE, UITheme.CARD_SHADOW, UITheme.TEXT_MUTED, 60.0, 26.0)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	_subtitle_label = UITheme.make_label(Loc.t("lang.subtitle"), 20, UITheme.TEXT_MUTED)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(580, 0)
	col.add_child(_subtitle_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if Loc.LANGUAGES.size() > 8:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 440)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		scroll.add_child(grid)
	else:
		col.add_child(grid)

	_card_entries.clear()
	for code in Loc.LANGUAGES:
		var entry := _make_language_card(code)
		grid.add_child(entry["button"])
		_card_entries.append(entry)

	_done_button = Button.new()
	_done_button.text = Loc.t("lang.done")
	_done_button.custom_minimum_size = Vector2(0, 80)
	_done_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_primary_button(_done_button, 28, 32)
	_done_button.pressed.connect(close)
	col.add_child(_done_button)

	_refresh_cards()


func _make_language_card(code: String) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 96)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.add_press_juice(btn)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 16)
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var flag := FlagIcons.make_rect(code, 54.0, 36.0)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 0)
	row.add_child(text_col)

	var name_lbl := UITheme.make_label(Loc.get_language_name(code), 20, UITheme.TEXT_DARK, true)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_col.add_child(name_lbl)

	var sub_lbl := UITheme.make_label(Loc.get_language_subtitle(code), 15, UITheme.TEXT_MUTED)
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_col.add_child(sub_lbl)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -30.0
	badge.offset_top = 6.0
	badge.offset_right = -6.0
	badge.offset_bottom = 30.0
	badge.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.BLUE, UITheme.BLUE_SHADOW, 12, 0, 5, 5)
	)
	var check_icon := PixelIcons.make_rect("check", 14.0, Color.WHITE)
	check_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	check_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(check_icon)
	btn.add_child(badge)

	btn.pressed.connect(_on_card_pressed.bind(code, btn))
	return {
		"code": code,
		"button": btn,
		"badge": badge,
	}


func _refresh_cards() -> void:
	var active_code := Loc.language
	for entry in _card_entries:
		var code: String = entry["code"]
		var btn: Button = entry["button"]
		var badge: PanelContainer = entry["badge"]
		var selected := (code == active_code)
		badge.visible = selected

		if selected:
			var face := UITheme.BLUE.lerp(Color.WHITE, 0.84)
			btn.add_theme_stylebox_override("normal", _make_card_button_style(face, UITheme.BLUE, false, true))
			btn.add_theme_stylebox_override("hover", _make_card_button_style(face.lightened(0.04), UITheme.BLUE, false, true))
			btn.add_theme_stylebox_override("pressed", _make_card_button_style(face.darkened(0.04), UITheme.BLUE, true, true))
		else:
			var face := Color("#F4FAFD")
			var shadow := Color("#D3E6EE")
			btn.add_theme_stylebox_override("normal", _make_card_button_style(face, shadow, false, false))
			btn.add_theme_stylebox_override("hover", _make_card_button_style(face.lightened(0.04), shadow, false, false))
			btn.add_theme_stylebox_override("pressed", _make_card_button_style(face.darkened(0.04), shadow, true, false))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_card_button_style(face: Color, shadow: Color, pressed: bool, highlighted: bool) -> StyleBoxFlat:
	var sb := UITheme.make_chunky_style(face, shadow, 22, pressed, 0, 0)
	if highlighted:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
	return sb


func _on_card_pressed(code: String, btn: Button) -> void:
	var changed := Loc.set_language(code)
	if changed:
		AudioManager.play_pop(1.15)
	else:
		AudioManager.play_click()
	refresh_language()
	_refresh_cards()
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.04, 1.04)
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	language_selected.emit(code)


func refresh_language() -> void:
	if _title_label != null:
		_title_label.text = Loc.t("lang.title")
	if _subtitle_label != null:
		_subtitle_label.text = Loc.t("lang.subtitle")
	if _done_button != null:
		_done_button.text = Loc.t("lang.done")


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
