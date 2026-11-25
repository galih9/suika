extends Control

## Main Game scene: manages responsive portrait layout, HUD, Evolution Bar, Pause, and Game Over overlays.

@onready var _board: GameBoard = %GameBoard

@onready var _score_card: PanelContainer = %ScoreCard
@onready var _score_title: Label = %ScoreTitle
@onready var _score_value: Label = %ScoreValue

@onready var _best_card: PanelContainer = %BestCard
@onready var _best_title: Label = %BestTitle
@onready var _best_value: Label = %BestValue

@onready var _next_card: PanelContainer = %NextCard
@onready var _next_title: Label = %NextTitle
@onready var _next_icon: TextureRect = %NextIcon
@onready var _next_name: Label = %NextName
@onready var _next_prop_label: Label = %NextPropLabel

@onready var _restart_button: Button = %RestartButton
@onready var _pause_button: Button = %PauseButton

@onready var _danger_banner: PanelContainer = %DangerBanner
@onready var _danger_label: Label = %DangerLabel

@onready var _evo_bar: PanelContainer = %EvoBar
@onready var _evo_strip: HBoxContainer = %EvoStrip

@onready var _pause_overlay: Control = %PauseOverlay
@onready var _pause_card: PanelContainer = %PauseCard
@onready var _pause_title: Label = %PauseTitle
@onready var _resume_button: Button = %ResumeButton
@onready var _pause_restart_button: Button = %PauseRestartButton
@onready var _pause_sound_button: Button = %PauseSoundButton
@onready var _pause_menu_button: Button = %PauseMenuButton

@onready var _game_over_overlay: Control = %GameOverOverlay
@onready var _game_over_card: PanelContainer = %GameOverCard
@onready var _game_over_title: Label = %GameOverTitle
@onready var _new_best_badge: PanelContainer = %NewBestBadge
@onready var _new_best_label: Label = %NewBestLabel
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _final_best_label: Label = %FinalBestLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _game_over_menu_button: Button = %GameOverMenuButton

var _top_hud_bottom: float = 164.0
var _bottom_bar_height: float = 104.0


func _ready() -> void:
	FruitRegistry.ensure_textures_ready()
	_apply_styles()
	_populate_evo_strip()

	_board.score_changed.connect(_on_board_score_changed)
	_board.next_fruit_changed.connect(_on_board_next_fruit_changed)
	_board.danger_changed.connect(_on_board_danger_changed)
	_board.game_over.connect(_on_board_game_over)

	_restart_button.pressed.connect(_on_restart_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_resume_button.pressed.connect(_on_resume_pressed)
	_pause_restart_button.pressed.connect(_on_restart_pressed)
	_pause_sound_button.pressed.connect(_on_sound_pressed)
	_pause_menu_button.pressed.connect(_on_menu_pressed)
	_play_again_button.pressed.connect(_on_restart_pressed)
	_game_over_menu_button.pressed.connect(_on_menu_pressed)

	get_viewport().size_changed.connect(_layout_board)
	_layout_board()
	_refresh_sound_button()
	_pause_overlay.visible = false
	_game_over_overlay.visible = false
	_danger_banner.visible = false

	_board.set_game_mode(SceneManager.selected_mode)
	_best_title.text = "FRENZY" if _board.game_mode == GameMode.Mode.FRENZY else "BEST"

	# Sync initial HUD values from board
	_on_board_score_changed(_board.score, _board.best_score, 0)
	_on_board_next_fruit_changed(_board.next_level, _board.next_property)


func _apply_styles() -> void:
	var card_style := UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_BORDER, 18, 2, 14, 10)
	_score_card.add_theme_stylebox_override("panel", card_style)
	_best_card.add_theme_stylebox_override("panel", card_style)
	_next_card.add_theme_stylebox_override("panel", card_style)
	_evo_bar.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_BORDER, 20, 2, 14, 10)
	)
	_danger_banner.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.DANGER_RED, Color("#B71C1C"), 16, 2, 18, 8)
	)
	_danger_label.add_theme_color_override("font_color", Color.WHITE)

	_score_title.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_score_value.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_best_title.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_best_value.add_theme_color_override("font_color", UITheme.ACCENT_CORAL)
	_next_title.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_next_name.add_theme_color_override("font_color", UITheme.TEXT_DARK)

	UITheme.style_secondary_button(_restart_button, 16, 18)
	UITheme.style_secondary_button(_pause_button, 16, 18)

	var modal_style := UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_BORDER, 26, 3, 28, 28)
	_pause_card.add_theme_stylebox_override("panel", modal_style)
	_game_over_card.add_theme_stylebox_override("panel", modal_style)
	_pause_title.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_game_over_title.add_theme_color_override("font_color", UITheme.DANGER_RED)

	_new_best_badge.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.ACCENT_CORAL, Color("#BF360C"), 14, 2, 16, 6)
	)
	_new_best_label.add_theme_color_override("font_color", Color.WHITE)
	_final_score_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_final_best_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)

	UITheme.style_primary_button(_resume_button, 18, 24)
	UITheme.style_secondary_button(_pause_restart_button, 18, 20)
	UITheme.style_secondary_button(_pause_sound_button, 18, 20)
	UITheme.style_secondary_button(_pause_menu_button, 18, 20)

	UITheme.style_primary_button(_play_again_button, 18, 24)
	UITheme.style_secondary_button(_game_over_menu_button, 18, 20)


func _populate_evo_strip() -> void:
	for child in _evo_strip.get_children():
		child.queue_free()

	var catalog := FruitRegistry.catalog
	var count := catalog.get_count()
	if count == 0:
		return
	var min_r := catalog.get_fruit(0).radius
	var max_r := catalog.get_fruit(count - 1).radius
	var span_r := maxf(max_r - min_r, 1.0)
	for i in range(count):
		var def := catalog.get_fruit(i)
		var tex := FruitRegistry.textures.get_texture(i)

		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)

		var icon_wrap := CenterContainer.new()
		var icon := TextureRect.new()
		var t := clampf((def.radius - min_r) / span_r, 0.0, 1.0)
		var sz := lerpf(20.0, 44.0, t)
		icon.custom_minimum_size = Vector2(sz, sz)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		icon_wrap.add_child(icon)
		box.add_child(icon_wrap)

		var lbl := Label.new()
		lbl.text = def.display_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		box.add_child(lbl)

		_evo_strip.add_child(box)


func _layout_board() -> void:
	var vp_size := get_viewport_rect().size
	var avail_h := maxf(vp_size.y - _top_hud_bottom - _bottom_bar_height - 32.0, 420.0)
	var board_h := 860.0

	# Keep RigidBody2D parent at unit scale so physics simulation remains rock-solid.
	_board.scale = Vector2.ONE
	var top_y := _top_hud_bottom + maxf((avail_h - board_h) * 0.5, 0.0)
	_board.position = Vector2(vp_size.x * 0.5, top_y)


func _on_board_score_changed(new_score: int, new_best: int, _delta_points: int) -> void:
	_score_value.text = str(new_score)
	_best_value.text = str(new_best)


func _on_board_next_fruit_changed(next_lvl: int, next_prop: int = FruitProperty.Type.NONE) -> void:
	var def := FruitRegistry.catalog.get_fruit(next_lvl)
	var tex := FruitRegistry.textures.get_texture(next_lvl)
	_next_icon.texture = tex
	_next_name.text = def.display_name if def != null else ""

	var prop := next_prop as FruitProperty.Type
	if prop != FruitProperty.Type.NONE:
		_next_prop_label.visible = true
		_next_prop_label.text = FruitProperty.get_short_label(prop)
		_next_prop_label.add_theme_color_override("font_color", FruitProperty.get_accent_color(prop))
	else:
		_next_prop_label.visible = false


func _on_board_danger_changed(is_triggered: bool, progress: float) -> void:
	_danger_banner.visible = is_triggered
	if is_triggered:
		var remaining := maxf((1.0 - progress) * _board.danger_detector.grace_duration, 0.0)
		_danger_label.text = "OVERFLOW! %.1fs" % remaining


func _on_board_game_over(final_score: int, is_new_best: bool) -> void:
	_danger_banner.visible = false
	_new_best_badge.visible = is_new_best
	_final_score_label.text = "Score: %d" % final_score
	_final_best_label.text = "Best: %d" % SaveManager.get_high_score(_board.game_mode)
	_game_over_overlay.visible = true


func _on_pause_pressed() -> void:
	if _board.is_game_over:
		return
	AudioManager.play_click()
	_board.dropper.cancel_drag()
	get_tree().paused = true
	_pause_overlay.visible = true


func _on_resume_pressed() -> void:
	AudioManager.play_click()
	_pause_overlay.visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	_pause_overlay.visible = false
	_game_over_overlay.visible = false
	_danger_banner.visible = false
	_board.reset_game()


func _on_sound_pressed() -> void:
	var next_state := not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(next_state)
	_refresh_sound_button()
	if next_state:
		AudioManager.play_click()


func _refresh_sound_button() -> void:
	_pause_sound_button.text = "Sound: ON" if SaveManager.is_sfx_enabled() else "Sound: OFF"


func _on_menu_pressed() -> void:
	AudioManager.play_click()
	SceneManager.goto_scene_with_loading(SceneManager.MENU_SCENE, "Returning to Menu...")
