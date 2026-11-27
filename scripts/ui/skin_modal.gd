class_name SkinModal
extends Control

## Pop-up card letting the player choose, preview, and unlock fruit skins via rewarded ads.

signal closed
signal skin_selected(skin_id: String)

const PREVIEW_SIZES := [32.0, 38.0, 44.0, 50.0, 56.0]

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _done_button: Button
var _cards_box: VBoxContainer
var _card_entries: Array[Dictionary] = []
var _is_open: bool = false
var _pending_unlock_skin_id: String = ""


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

	AdManager.rewarded_ad_earned.connect(_on_rewarded_ad_earned)
	AdManager.rewarded_ad_closed.connect(_on_rewarded_ad_closed)
	AdManager.rewarded_ad_failed.connect(_on_rewarded_ad_failed)


func _exit_tree() -> void:
	if AdManager.rewarded_ad_earned.is_connected(_on_rewarded_ad_earned):
		AdManager.rewarded_ad_earned.disconnect(_on_rewarded_ad_earned)
	if AdManager.rewarded_ad_closed.is_connected(_on_rewarded_ad_closed):
		AdManager.rewarded_ad_closed.disconnect(_on_rewarded_ad_closed)
	if AdManager.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		AdManager.rewarded_ad_failed.disconnect(_on_rewarded_ad_failed)


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

	_status_label = UITheme.make_label("", 20, UITheme.TEXT_MUTED, true)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(560, 0)
	_status_label.visible = false
	col.add_child(_status_label)

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
	var badge_icon := PixelIcons.make_rect("check", 18.0, Color.WHITE)
	badge_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_row.add_child(badge_icon)
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
		"badge_icon": badge_icon,
		"name_label": name_lbl,
		"desc_label": desc_lbl,
		"badge_label": badge_lbl,
		"preview_row": preview_row,
	}


func _refresh_cards() -> void:
	var active_id := FruitRegistry.active_skin_id
	var ad_busy := not _pending_unlock_skin_id.is_empty()
	for entry in _card_entries:
		var skin: SkinDefinition = entry["skin"]
		var btn: Button = entry["button"]
		var badge: PanelContainer = entry["badge"]
		var badge_icon: TextureRect = entry["badge_icon"]
		var badge_lbl: Label = entry["badge_label"]
		var preview_row: HBoxContainer = entry["preview_row"]

		var unlocked := FruitRegistry.is_skin_unlocked(skin.id)
		var selected := unlocked and (skin.id == active_id)
		var is_loading := (_pending_unlock_skin_id == skin.id)

		btn.disabled = ad_busy

		if selected:
			badge.visible = true
			badge.add_theme_stylebox_override(
				"panel",
				UITheme.make_panel_style(skin.accent_color, skin.accent_shadow, 14, 0, 12, 4)
			)
			badge_icon.texture = PixelIcons.get_icon("check")
			badge_lbl.text = Loc.t("skin.equipped")
			preview_row.modulate = Color.WHITE

			var face := skin.accent_color.lerp(Color.WHITE, 0.80)
			var normal := _make_card_button_style(face, skin.accent_color, false, true)
			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_stylebox_override("hover", _make_card_button_style(face.lightened(0.04), skin.accent_color, false, true))
			btn.add_theme_stylebox_override("pressed", _make_card_button_style(face.darkened(0.04), skin.accent_color, true, true))
			btn.add_theme_stylebox_override("disabled", normal)
		elif unlocked:
			badge.visible = false
			preview_row.modulate = Color.WHITE

			var face := Color("#F4FAFD")
			var shadow := Color("#D3E6EE")
			var normal := _make_card_button_style(face, shadow, false, false)
			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_stylebox_override("hover", _make_card_button_style(face.lightened(0.04), shadow, false, false))
			btn.add_theme_stylebox_override("pressed", _make_card_button_style(face.darkened(0.04), shadow, true, false))
			btn.add_theme_stylebox_override("disabled", normal)
		else:
			badge.visible = true
			badge.add_theme_stylebox_override(
				"panel",
				UITheme.make_panel_style(UITheme.ORANGE, UITheme.ORANGE_SHADOW, 14, 0, 12, 4)
			)
			badge_icon.texture = PixelIcons.get_icon("lock")
			badge_lbl.text = Loc.t("skin.loading_ad") if is_loading else Loc.t("skin.watch_ad")
			preview_row.modulate = Color(0.82, 0.86, 0.90, 0.72)

			var face := Color("#EDF2F6")
			var shadow := Color("#C8D6E0")
			var normal := _make_card_button_style(face, shadow, false, false)
			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_stylebox_override("hover", _make_card_button_style(face.lightened(0.04), shadow, false, false))
			btn.add_theme_stylebox_override("pressed", _make_card_button_style(face.darkened(0.04), shadow, true, false))
			btn.add_theme_stylebox_override("disabled", normal)

		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_card_button_style(face: Color, shadow: Color, pressed: bool, highlighted: bool) -> StyleBoxFlat:
	var sb := UITheme.make_chunky_style(face, shadow, 24, pressed, 0, 0)
	if highlighted:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
	return sb


func _set_status(text: String, color: Color = UITheme.TEXT_MUTED) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	_status_label.visible = not text.is_empty()


func _find_card_entry(skin_id: String) -> Dictionary:
	for entry in _card_entries:
		var skin: SkinDefinition = entry["skin"]
		if skin.id == skin_id:
			return entry
	return {}


func _bounce_button(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.04, 1.04)
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_pressed(skin_id: String, btn: Button) -> void:
	if not _pending_unlock_skin_id.is_empty():
		return

	if FruitRegistry.is_skin_unlocked(skin_id):
		_set_status("")
		var changed := FruitRegistry.set_skin(skin_id)
		if changed:
			AudioManager.play_pop(1.15)
		else:
			AudioManager.play_click()
		_refresh_cards()
		_bounce_button(btn)
		skin_selected.emit(skin_id)
		return

	AudioManager.play_click()
	_pending_unlock_skin_id = skin_id
	_set_status(Loc.t("skin.loading_ad"), UITheme.TEXT_MUTED)
	_refresh_cards()
	AdManager.show_rewarded_ad(skin_id)


func _on_rewarded_ad_earned(context_id: String) -> void:
	if context_id.is_empty() or context_id != _pending_unlock_skin_id:
		return
	FruitRegistry.unlock_skin(context_id)
	FruitRegistry.set_skin(context_id, true)
	AudioManager.play_unlock()

	var skin := FruitRegistry.skins.get_skin(context_id)
	var skin_name := Loc.t(skin.name_key) if skin != null else context_id
	_set_status(Loc.t("skin.unlocked", [skin_name]), UITheme.GREEN_SHADOW)
	_refresh_cards()

	var entry := _find_card_entry(context_id)
	if not entry.is_empty():
		_bounce_button(entry["button"] as Button)
	skin_selected.emit(context_id)


func _on_rewarded_ad_closed(context_id: String, earned: bool) -> void:
	if context_id != _pending_unlock_skin_id:
		return
	_pending_unlock_skin_id = ""
	if not earned:
		_set_status(Loc.t("skin.ad_skipped"), UITheme.ORANGE_SHADOW)
	_refresh_cards()


func _on_rewarded_ad_failed(context_id: String, _reason: String) -> void:
	if context_id != _pending_unlock_skin_id:
		return
	_pending_unlock_skin_id = ""
	_set_status(Loc.t("skin.ad_unavailable"), UITheme.DANGER_RED)
	_refresh_cards()


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
		name_lbl.text = Loc.t(skin.name_key)
		desc_lbl.text = Loc.t(skin.desc_key)
	_refresh_cards()


func get_card_count() -> int:
	return _card_entries.size()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_pending_unlock_skin_id = ""
	_set_status("")
	refresh_language()
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
	if not _pending_unlock_skin_id.is_empty():
		AdManager.cancel_pending_rewarded_ad()
		_pending_unlock_skin_id = ""
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
