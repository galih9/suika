extends Control

## Main Menu screen: displays high score, dynamic fruit hierarchy preview, play button, and audio toggle.

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _best_card: PanelContainer = %BestCard
@onready var _best_label: Label = %BestLabel
@onready var _evo_card: PanelContainer = %EvoCard
@onready var _evo_title: Label = %EvoTitle
@onready var _evo_flow: HFlowContainer = %EvoFlow
@onready var _play_button: Button = %PlayButton
@onready var _sound_button: Button = %SoundButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	FruitRegistry.ensure_textures_ready()
	_apply_styles()
	_populate_evolution_chart()
	_refresh_high_score()
	_refresh_sound_button()

	if OS.has_feature("mobile"):
		_quit_button.visible = false

	_play_button.pressed.connect(_on_play_pressed)
	_sound_button.pressed.connect(_on_sound_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _apply_styles() -> void:
	_title_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_subtitle_label.add_theme_color_override("font_color", UITheme.ACCENT_CORAL)

	_best_card.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.BG_APRICOT, UITheme.CARD_BORDER, 20, 2, 24, 12)
	)
	_best_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)

	_evo_card.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_BORDER, 24, 2, 22, 18)
	)
	_evo_title.add_theme_color_override("font_color", UITheme.TEXT_MUTED)

	UITheme.style_primary_button(_play_button, 22, 30)
	UITheme.style_secondary_button(_sound_button, 18, 22)
	UITheme.style_secondary_button(_quit_button, 18, 22)


func _populate_evolution_chart() -> void:
	for child in _evo_flow.get_children():
		child.queue_free()

	var catalog := FruitRegistry.catalog
	var count := catalog.get_count()
	for i in range(count):
		var def := catalog.get_fruit(i)
		var tex := FruitRegistry.textures.get_texture(i)

		var item := VBoxContainer.new()
		item.custom_minimum_size = Vector2(74, 0)
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		item.add_theme_constant_override("separation", 4)

		var icon_wrap := CenterContainer.new()
		var icon := TextureRect.new()
		var icon_sz := lerpf(36.0, 56.0, float(i) / float(maxi(count - 1, 1)))
		icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		icon_wrap.add_child(icon)
		item.add_child(icon_wrap)

		var name_lbl := Label.new()
		name_lbl.text = def.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		item.add_child(name_lbl)

		_evo_flow.add_child(item)

		if i < count - 1:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow.add_theme_font_size_override("font_size", 20)
			arrow.add_theme_color_override("font_color", UITheme.ACCENT_CORAL)
			_evo_flow.add_child(arrow)


func _refresh_high_score() -> void:
	_best_label.text = "BEST SCORE: %d" % SaveManager.get_high_score()


func _refresh_sound_button() -> void:
	var enabled := SaveManager.is_sfx_enabled()
	_sound_button.text = "Sound: ON" if enabled else "Sound: OFF"


func _on_play_pressed() -> void:
	AudioManager.play_click()
	SceneManager.goto_scene_with_loading(SceneManager.GAME_SCENE, "Preparing Jar...")


func _on_sound_pressed() -> void:
	var next_state := not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(next_state)
	_refresh_sound_button()
	if next_state:
		AudioManager.play_click()


func _on_quit_pressed() -> void:
	AudioManager.play_click()
	get_tree().quit()
