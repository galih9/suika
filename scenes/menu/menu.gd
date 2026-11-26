extends Control

## Main Menu: minimal casual layout — title, best scores, the fruit tier list (as a collection
## you complete by discovering fruits), Play / Frenzy, and a Power-ups info modal.

const SLOT_SIZE := 100.0

@onready var _column: VBoxContainer = %Column
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _hero: VBoxContainer = %Hero
@onready var _fruit_trio: HBoxContainer = %FruitTrio
@onready var _title_label: Label = %TitleLabel
@onready var _best_row: HBoxContainer = %BestRow
@onready var _collection_card: PanelContainer = %CollectionCard
@onready var _collection_title: Label = %CollectionTitle
@onready var _collection_count: Label = %CollectionCount
@onready var _fruit_grid: GridContainer = %FruitGrid
@onready var _info_label: Label = %InfoLabel
@onready var _play_button: Button = %PlayButton
@onready var _frenzy_button: Button = %FrenzyButton
@onready var _power_ups_button: Button = %PowerUpsButton

var _quit_button: Button
var _sound_button: Button
var _skins_button: Button
var _lang_button: Button
var _power_up_modal: PowerUpModal
var _skin_modal: SkinModal
var _language_modal: LanguageModal
var _trio_icons: Array[TextureRect] = []
var _goal_slot: Control
var _time: float = 0.0
var _selected_slot: Control
var _selected_level: int = -1


func _ready() -> void:
	FruitRegistry.ensure_textures_ready()
	UITheme.apply_to(self)
	_build_top_bar()
	_style_static()
	_build_fruit_trio()
	_build_best_row()
	_build_collection()

	_play_button.pressed.connect(_on_play_pressed)
	_frenzy_button.pressed.connect(_on_frenzy_pressed)
	_power_ups_button.pressed.connect(_on_power_ups_pressed)

	_power_up_modal = PowerUpModal.new()
	add_child(_power_up_modal)

	_skin_modal = SkinModal.new()
	add_child(_skin_modal)

	_language_modal = LanguageModal.new()
	add_child(_language_modal)

	FruitRegistry.skin_changed.connect(_on_skin_changed)
	Loc.language_changed.connect(_on_language_changed)

	_play_intro()


func _exit_tree() -> void:
	if Loc.language_changed.is_connected(_on_language_changed):
		Loc.language_changed.disconnect(_on_language_changed)
	if FruitRegistry.skin_changed.is_connected(_on_skin_changed):
		FruitRegistry.skin_changed.disconnect(_on_skin_changed)


func _process(delta: float) -> void:
	_time += delta
	# Bobbing hero fruits.
	for i in range(_trio_icons.size()):
		var icon := _trio_icons[i]
		var bob := sin(_time * 3.0 + float(i) * 1.3) * 6.0
		icon.position.y = (96.0 - icon.size.y) + bob
		icon.rotation = sin(_time * 2.0 + float(i)) * 0.06
	# The next fruit to discover gently pulses to invite the player.
	if _goal_slot != null:
		var s := 1.0 + 0.06 * sin(_time * 5.0)
		_goal_slot.scale = Vector2(s, s)


# --- Building ----------------------------------------------------------------------------------

func _build_top_bar() -> void:
	_top_bar.add_theme_constant_override("separation", 10)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_quit_button = UITheme.make_icon_button("close", UITheme.CARD_WHITE, UITheme.CARD_SHADOW, UITheme.TEXT_MUTED, 72.0, 28.0)
		_quit_button.tooltip_text = Loc.t("menu.quit")
		_quit_button.pressed.connect(_on_quit_pressed)
		_top_bar.add_child(_quit_button)

	_skins_button = Button.new()
	_skins_button.custom_minimum_size = Vector2(156, 72)
	_skins_button.focus_mode = Control.FOCUS_NONE
	_skins_button.tooltip_text = Loc.t("menu.skins")
	UITheme.style_blue_button(_skins_button, 26, 26)
	UITheme.set_button_content(_skins_button, "palette", Loc.t("menu.skins"), 24, Color.WHITE, UITheme.BLUE_SHADOW.darkened(0.2), 26.0)
	_skins_button.pressed.connect(_on_skins_pressed)
	_top_bar.add_child(_skins_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(spacer)

	# Language picker: shows current flag + code, tap to open the language modal.
	_lang_button = Button.new()
	_lang_button.custom_minimum_size = Vector2(124, 72)
	_lang_button.focus_mode = Control.FOCUS_NONE
	_lang_button.tooltip_text = Loc.t("menu.language")
	UITheme.style_secondary_button(_lang_button, 28, 24)
	UITheme.set_button_texture_content(_lang_button, FlagIcons.get_flag(Loc.language), Loc.language.to_upper(), 24, UITheme.TEXT_DARK, Color(0, 0, 0, 0), Vector2(36.0, 24.0))
	_lang_button.pressed.connect(_on_language_pressed)
	_top_bar.add_child(_lang_button)

	_sound_button = UITheme.make_icon_button("sound", UITheme.CARD_WHITE, UITheme.CARD_SHADOW, UITheme.TEXT_DARK, 72.0, 34.0)
	_sound_button.pressed.connect(_on_sound_pressed)
	_top_bar.add_child(_sound_button)
	_refresh_sound_button()


func _style_static() -> void:
	_title_label.text = Loc.t("app.title")
	_collection_title.text = Loc.t("menu.collection")
	UITheme.style_label(_title_label, 86, Color.WHITE, true, 22, UITheme.OUTLINE_DARK)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.18, 0.23, 0.36, 0.35))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 10)
	_title_label.add_theme_constant_override("shadow_outline_size", 22)

	_collection_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 34, 22, 18, 8))
	UITheme.style_label(_collection_title, 28, UITheme.TEXT_DARK, true)
	UITheme.style_label(_collection_count, 26, UITheme.ORANGE_SHADOW, true)
	UITheme.style_label(_info_label, 22, UITheme.TEXT_MUTED)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UITheme.style_primary_button(_play_button, 34, 44)
	UITheme.set_button_content(_play_button, "play", Loc.t("menu.play"), 48, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 40.0)

	UITheme.style_accent_button(_frenzy_button, 30, 36)
	UITheme.set_button_content(_frenzy_button, "fire", Loc.t("menu.frenzy"), 38, Color.WHITE, UITheme.PINK_SHADOW.darkened(0.2), 34.0)

	UITheme.style_secondary_button(_power_ups_button, 30, 26)
	UITheme.set_button_content(_power_ups_button, "bolt", Loc.t("menu.powerups"), 26, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 30.0)


func _build_fruit_trio() -> void:
	for child in _fruit_trio.get_children():
		_fruit_trio.remove_child(child)
		child.queue_free()
	_trio_icons.clear()

	# Show off the biggest fruits the player has discovered (never spoil undiscovered ones).
	var count := FruitRegistry.catalog.get_count()
	var found: Array[int] = []
	for i in range(count - 1, -1, -1):
		if SaveManager.is_discovered(i):
			found.append(i)
		if found.size() >= 3:
			break
	while found.size() < 3:
		found.append(0)
	var order := [found[1], found[0], found[2]]
	var sizes := [76.0, 96.0, 64.0]
	for k in range(3):
		var holder := Control.new()
		var px := float(sizes[k])
		holder.custom_minimum_size = Vector2(px, 96.0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := UITheme.make_fruit_icon(int(order[k]), px)
		icon.position = Vector2(0.0, 96.0 - px)
		icon.size = Vector2(px, px)
		icon.pivot_offset = icon.size * 0.5
		holder.add_child(icon)
		_fruit_trio.add_child(holder)
		_trio_icons.append(icon)


func _build_best_row() -> void:
	for child in _best_row.get_children():
		_best_row.remove_child(child)
		child.queue_free()
	_best_row.add_child(_make_chip("crown", UITheme.GOLD, Loc.t("menu.best", [UITheme.format_number(SaveManager.get_high_score(GameMode.Mode.NORMAL))])))
	_best_row.add_child(_make_chip("fire", UITheme.PINK, Loc.t("menu.frenzy_best", [UITheme.format_number(SaveManager.get_high_score(GameMode.Mode.FRENZY))])))


func _make_chip(icon_name: String, icon_color: Color, text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 26, 18, 8, 5))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(box)
	var icon := PixelIcons.make_rect(icon_name, 28.0, icon_color)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(UITheme.make_label(text, 24, UITheme.TEXT_DARK, true))
	return chip


func _build_collection() -> void:
	for child in _fruit_grid.get_children():
		_fruit_grid.remove_child(child)
		child.queue_free()
	_goal_slot = null

	var catalog := FruitRegistry.catalog
	var count := catalog.get_count()
	var discovered := SaveManager.get_discovered_count(count)
	var next_goal := SaveManager.get_next_undiscovered(count)
	_collection_count.text = "%d / %d" % [discovered, count]

	for i in range(count):
		var slot := _make_slot(i, SaveManager.is_discovered(i), i == next_goal)
		_fruit_grid.add_child(slot)
		if i == next_goal:
			_goal_slot = slot

	if next_goal < 0:
		_info_label.text = Loc.t("menu.complete")
	else:
		_info_label.text = Loc.t("menu.tap_hint")


func _make_slot(level: int, discovered: bool, is_goal: bool) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.focus_mode = Control.FOCUS_NONE
	var face := Color("#F4FAFD") if discovered else Color("#E9EEF2")
	var shadow := Color("#D3E6EE") if discovered else Color("#CDD6DC")
	if is_goal:
		face = Color("#FFF4D6")
		shadow = UITheme.GOLD
	slot.add_theme_stylebox_override("normal", UITheme.make_chunky_style(face, shadow, 24, false, 4, 4))
	slot.add_theme_stylebox_override("hover", UITheme.make_chunky_style(face.lightened(0.05), shadow, 24, false, 4, 4))
	slot.add_theme_stylebox_override("pressed", UITheme.make_chunky_style(face.darkened(0.04), shadow, 24, true, 4, 4))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UITheme.add_press_juice(slot)

	var def := FruitRegistry.catalog.get_fruit(level)
	# Bigger tiers get slightly bigger icons so the list still reads as a size ladder.
	var t := float(level) / float(maxi(FruitRegistry.catalog.get_count() - 1, 1))
	var px := lerpf(40.0, 74.0, t)
	var icon := UITheme.make_fruit_icon(level, px)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -px * 0.5
	icon.offset_right = px * 0.5
	icon.offset_top = -px * 0.5 - 4.0
	icon.offset_bottom = px * 0.5 - 4.0
	if not discovered:
		var mat := UITheme.make_icon_material()
		mat.set_shader_parameter("silhouette", 1.0)
		icon.material = mat
	slot.add_child(icon)

	if not discovered:
		var q := PixelIcons.make_rect("question", 28.0, UITheme.GOLD_SHADOW if is_goal else UITheme.TEXT_MUTED)
		q.set_anchors_preset(Control.PRESET_CENTER)
		q.offset_left = -14.0
		q.offset_right = 14.0
		q.offset_top = -18.0
		q.offset_bottom = 10.0
		slot.add_child(q)

	var tier := UITheme.make_label(str(level + 1), 16, UITheme.TEXT_MUTED, true)
	tier.position = Vector2(10.0, 4.0)
	slot.add_child(tier)

	slot.pressed.connect(func() -> void: _on_slot_pressed(slot, level, discovered, def))
	return slot


func _on_slot_pressed(slot: Control, level: int, discovered: bool, def: FruitDefinition) -> void:
	AudioManager.play_click()
	_selected_slot = slot
	_selected_level = level
	if discovered and def != null:
		_info_label.text = Loc.t("menu.tier_name", [level + 1, Loc.fruit_name(level)])
		_info_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	else:
		var prev := FruitRegistry.catalog.get_fruit(level - 1)
		if prev != null and SaveManager.is_discovered(level - 1):
			_info_label.text = Loc.t("menu.tier_hint_prev", [level + 1, Loc.fruit_plural(level - 1)])
		else:
			_info_label.text = Loc.t("menu.tier_hint", [level + 1])
		_info_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_info_label.pivot_offset = _info_label.size * 0.5
	_info_label.scale = Vector2(1.08, 1.08)
	var tw := create_tween()
	tw.tween_property(_info_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_info_label() -> void:
	if _selected_level >= 0:
		var def := FruitRegistry.catalog.get_fruit(_selected_level)
		var discovered := SaveManager.is_discovered(_selected_level)
		if discovered and def != null:
			_info_label.text = Loc.t("menu.tier_name", [_selected_level + 1, Loc.fruit_name(_selected_level)])
			_info_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		else:
			var prev := FruitRegistry.catalog.get_fruit(_selected_level - 1)
			if prev != null and SaveManager.is_discovered(_selected_level - 1):
				_info_label.text = Loc.t("menu.tier_hint_prev", [_selected_level + 1, Loc.fruit_plural(_selected_level - 1)])
			else:
				_info_label.text = Loc.t("menu.tier_hint", [_selected_level + 1])
			_info_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		return
	var next_goal := SaveManager.get_next_undiscovered(FruitRegistry.catalog.get_count())
	_info_label.text = Loc.t("menu.complete") if next_goal < 0 else Loc.t("menu.tap_hint")


# --- Intro animation -------------------------------------------------------------------------

func _play_intro() -> void:
	var items: Array[Control] = [_hero, _best_row, _collection_card, _play_button, _frenzy_button.get_parent() as Control]
	var delay := 0.0
	for item in items:
		item.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(item, "modulate:a", 1.0, 0.25)
		delay += 0.06
	# Title pop.
	_title_label.pivot_offset = Vector2(_title_label.size.x * 0.5, _title_label.size.y * 0.5)
	_title_label.scale = Vector2(0.7, 0.7)
	var pop := create_tween()
	pop.tween_property(_title_label, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	_title_label.pivot_offset = _title_label.size * 0.5


# --- Actions ---------------------------------------------------------------------------------

func _refresh_sound_button() -> void:
	var enabled := SaveManager.is_sfx_enabled()
	UITheme.set_button_icon(_sound_button, "sound" if enabled else "mute", 34.0, UITheme.TEXT_DARK if enabled else UITheme.TEXT_MUTED)


func _on_play_pressed() -> void:
	AudioManager.play_click()
	SceneManager.selected_mode = GameMode.Mode.NORMAL
	SceneManager.goto_scene_with_loading(SceneManager.GAME_SCENE, Loc.t("load.filling"))


func _on_frenzy_pressed() -> void:
	AudioManager.play_click()
	SceneManager.selected_mode = GameMode.Mode.FRENZY
	SceneManager.goto_scene_with_loading(SceneManager.GAME_SCENE, Loc.t("load.charging"))


func _on_power_ups_pressed() -> void:
	_power_up_modal.open()


func _on_skins_pressed() -> void:
	_skin_modal.open()


func _on_skin_changed(_skin_id: String) -> void:
	_build_fruit_trio()
	_build_collection()
	_power_up_modal.refresh_skin()


func _on_sound_pressed() -> void:
	var next_state := not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(next_state)
	_refresh_sound_button()
	if next_state:
		AudioManager.play_click()


func _on_language_pressed() -> void:
	_language_modal.open()


func _on_language_changed(_code: String) -> void:
	if _quit_button != null:
		_quit_button.tooltip_text = Loc.t("menu.quit")
	if _skins_button != null:
		_skins_button.tooltip_text = Loc.t("menu.skins")
		UITheme.set_button_content(_skins_button, "palette", Loc.t("menu.skins"), 24, Color.WHITE, UITheme.BLUE_SHADOW.darkened(0.2), 26.0)
	if _lang_button != null:
		_lang_button.tooltip_text = Loc.t("menu.language")
		UITheme.set_button_texture_content(_lang_button, FlagIcons.get_flag(Loc.language), Loc.language.to_upper(), 24, UITheme.TEXT_DARK, Color(0, 0, 0, 0), Vector2(36.0, 24.0))

	_title_label.text = Loc.t("app.title")
	_collection_title.text = Loc.t("menu.collection")
	UITheme.set_button_content(_play_button, "play", Loc.t("menu.play"), 48, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 40.0)
	UITheme.set_button_content(_frenzy_button, "fire", Loc.t("menu.frenzy"), 38, Color.WHITE, UITheme.PINK_SHADOW.darkened(0.2), 34.0)
	UITheme.set_button_content(_power_ups_button, "bolt", Loc.t("menu.powerups"), 26, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 30.0)

	_build_best_row()
	_update_info_label()
	_power_up_modal.refresh_language()
	_skin_modal.refresh_language()
	_language_modal.refresh_language()


func _on_quit_pressed() -> void:
	AudioManager.play_click()
	get_tree().quit()
