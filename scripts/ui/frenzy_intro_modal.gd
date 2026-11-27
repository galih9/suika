class_name FrenzyIntroModal
extends Control

## Short pre-game popup explaining Frenzy waves, obstacles, and special fruits,
## with a persistent "Don't show this again" checkbox.

signal closed

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _rule_labels: Array[Label] = []
var _dont_show_button: Button
var _checkbox_box: PanelContainer
var _checkbox_check: TextureRect
var _dont_show_label: Label
var _start_button: Button
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
	_card.custom_minimum_size = Vector2(600, 0)
	_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 34, 28, 24, 9))
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_card.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	var fire := PixelIcons.make_rect("fire", 40.0, UITheme.PINK)
	header.add_child(fire)

	_title_label = UITheme.make_label(Loc.t("frenzy_intro.title"), 38, UITheme.TEXT_DARK, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_rule_labels.clear()
	col.add_child(_make_rule_row("star", UITheme.ORANGE, Loc.t("frenzy_intro.rule1")))
	col.add_child(_make_rule_row("fire", UITheme.DANGER_RED, Loc.t("frenzy_intro.rule2")))
	col.add_child(_make_rule_row("bolt", UITheme.PINK, Loc.t("frenzy_intro.rule3")))

	_dont_show_button = Button.new()
	_dont_show_button.toggle_mode = true
	_dont_show_button.flat = true
	_dont_show_button.focus_mode = Control.FOCUS_NONE
	_dont_show_button.custom_minimum_size = Vector2(0, 52)
	var empty_sb := StyleBoxEmpty.new()
	for state_name in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_dont_show_button.add_theme_stylebox_override(state_name, empty_sb)
	_dont_show_button.toggled.connect(_on_dont_show_toggled)
	col.add_child(_dont_show_button)

	var cb_row := HBoxContainer.new()
	cb_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	cb_row.add_theme_constant_override("separation", 12)
	cb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dont_show_button.add_child(cb_row)

	var cb_center := CenterContainer.new()
	cb_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb_row.add_child(cb_center)

	_checkbox_box = PanelContainer.new()
	_checkbox_box.custom_minimum_size = Vector2(36, 36)
	_checkbox_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb_center.add_child(_checkbox_box)

	var check_wrap := CenterContainer.new()
	check_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checkbox_box.add_child(check_wrap)

	_checkbox_check = PixelIcons.make_rect("check", 22.0, Color.WHITE)
	check_wrap.add_child(_checkbox_check)

	_dont_show_label = UITheme.make_label(Loc.t("frenzy_intro.dont_show"), 22, UITheme.TEXT_DARK, true)
	_dont_show_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dont_show_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_child(_dont_show_label)

	_refresh_checkbox_visual()

	_start_button = Button.new()
	_start_button.custom_minimum_size = Vector2(0, 88)
	_start_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_primary_button(_start_button, 28, 34)
	UITheme.set_button_content(_start_button, "play", Loc.t("frenzy_intro.start"), 34, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 30.0)
	_start_button.pressed.connect(close)
	col.add_child(_start_button)


func _make_rule_row(icon_name: String, accent: Color, text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(accent.lerp(Color.WHITE, 0.84), accent.lerp(Color.WHITE, 0.45), 20, 0, 14, 12)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon := PixelIcons.make_rect(icon_name, 36.0, accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var lbl := UITheme.make_label(text, 20, UITheme.TEXT_DARK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(460, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	_rule_labels.append(lbl)
	return panel


func _on_dont_show_toggled(_pressed: bool) -> void:
	if _is_open and visible:
		AudioManager.play_click()
	_refresh_checkbox_visual()


func _refresh_checkbox_visual() -> void:
	if _checkbox_box == null or _checkbox_check == null or _dont_show_button == null:
		return
	var checked := _dont_show_button.button_pressed
	_checkbox_check.visible = checked
	if checked:
		_checkbox_box.add_theme_stylebox_override(
			"panel",
			UITheme.make_panel_style(UITheme.GREEN, UITheme.GREEN_SHADOW, 10, 3, 0, 0)
		)
	else:
		_checkbox_box.add_theme_stylebox_override(
			"panel",
			UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 10, 3, 0, 0)
		)


func is_open() -> bool:
	return _is_open


func is_dont_show_checked() -> bool:
	return _dont_show_button != null and _dont_show_button.button_pressed


func set_dont_show_checked(checked: bool) -> void:
	if _dont_show_button == null:
		return
	_dont_show_button.set_pressed_no_signal(checked)
	_refresh_checkbox_visual()


func refresh_language() -> void:
	if _title_label != null:
		_title_label.text = Loc.t("frenzy_intro.title")
	if _rule_labels.size() >= 3:
		_rule_labels[0].text = Loc.t("frenzy_intro.rule1")
		_rule_labels[1].text = Loc.t("frenzy_intro.rule2")
		_rule_labels[2].text = Loc.t("frenzy_intro.rule3")
	if _dont_show_label != null:
		_dont_show_label.text = Loc.t("frenzy_intro.dont_show")
	if _start_button != null:
		UITheme.set_button_content(_start_button, "play", Loc.t("frenzy_intro.start"), 34, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 30.0)


func open() -> void:
	if _is_open:
		return
	_is_open = true
	refresh_language()
	set_dont_show_checked(SaveManager.is_frenzy_intro_hidden())
	visible = true
	_dim.modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.18)
	tw.tween_property(_card, "modulate:a", 1.0, 0.14)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	if is_instance_valid(_card):
		_card.pivot_offset = _card.size * 0.5


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if is_dont_show_checked():
		SaveManager.set_frenzy_intro_hidden(true)
	AudioManager.play_click()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.14)
	tw.tween_property(_card, "modulate:a", 0.0, 0.12)
	tw.tween_property(_card, "scale", Vector2(0.9, 0.9), 0.12)
	tw.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
