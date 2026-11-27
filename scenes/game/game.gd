extends Control

## Main Game scene: responsive portrait layout, casual HUD (score, best, next bubble), the fruit
## guide with unlock animations, toasts for fun moments, floating score pops, combos, screen
## shake, and the Pause / Game Over cards.

const COMBO_WINDOW := 1.1
const SCORE_MILESTONES := [1000, 2500, 5000, 10000, 20000, 50000]
const BIG_FRUIT_TOAST_LEVEL := 9
const BOARD_HEIGHT := 860.0

@onready var _board: GameBoard = %GameBoard
@onready var _board_layer: Node2D = $BoardLayer
@onready var _fx_layer: Control = %FxLayer

@onready var _top_margin: MarginContainer = %TopMargin
@onready var _pause_button: Button = %PauseButton
@onready var _mode_badge: PanelContainer = %ModeBadge
@onready var _mode_label: Label = %ModeLabel
@onready var _score_value: Label = %ScoreValue
@onready var _best_chip: PanelContainer = %BestChip
@onready var _best_row: HBoxContainer = %BestRow
@onready var _best_value: Label = %BestValue
@onready var _next_bubble: PanelContainer = %NextBubble
@onready var _next_title: Label = %NextTitle
@onready var _next_icon: TextureRect = %NextIcon
@onready var _next_prop_tag: PanelContainer = %NextPropTag
@onready var _next_prop_label: Label = %NextPropLabel

@onready var _danger_banner: PanelContainer = %DangerBanner
@onready var _danger_label: Label = %DangerLabel
@onready var _bottom_margin: MarginContainer = %BottomMargin
@onready var _fruit_guide: FruitGuideStrip = %FruitGuide
@onready var _toasts: ToastStack = %Toasts

@onready var _pause_overlay: Control = %PauseOverlay
@onready var _pause_card: PanelContainer = %PauseCard
@onready var _pause_title: Label = %PauseTitle
@onready var _resume_button: Button = %ResumeButton
@onready var _pause_restart_button: Button = %PauseRestartButton
@onready var _pause_sound_button: Button = %PauseSoundButton
@onready var _pause_power_ups_button: Button = %PausePowerUpsButton
@onready var _pause_skins_button: Button = %PauseSkinsButton
@onready var _pause_language_button: Button = %PauseLanguageButton
@onready var _pause_menu_button: Button = %PauseMenuButton

@onready var _game_over_overlay: Control = %GameOverOverlay
@onready var _game_over_dim: ColorRect = %GameOverDim
@onready var _game_over_card: PanelContainer = %GameOverCard
@onready var _game_over_title: Label = %GameOverTitle
@onready var _new_best_badge: PanelContainer = %NewBestBadge
@onready var _new_best_label: Label = %NewBestLabel
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _final_best_label: Label = %FinalBestLabel
@onready var _run_card: PanelContainer = %RunCard
@onready var _run_title: Label = %RunTitle
@onready var _run_fruits_row: HBoxContainer = %RunFruitsRow
@onready var _run_info_label: Label = %RunInfoLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _game_over_menu_button: Button = %GameOverMenuButton

var _top_hud_bottom: float = 170.0
var _bottom_bar_height: float = 124.0
var _power_up_modal: PowerUpModal
var _skin_modal: SkinModal
var _language_modal: LanguageModal
var _edge_splatter: EdgeSplatter
var _power_info_button: Button
var _modal_paused_game: bool = false

# Run state
var _displayed_score: float = 0.0
var _target_score: int = 0
var _best_at_start: int = 0
var _best_toast_done: bool = false
var _milestone_index: int = 0
var _combo: int = 0
var _last_merge_time: float = -10.0
var _combo_toast_done: bool = false
var _run_merges: int = 0
var _run_new_discoveries: Array[int] = []
var _run_max_level: int = 0
var _danger_peak: float = 0.0
var _last_phew_time: float = -100.0
var _danger_time: float = 0.0
var _clock: float = 0.0
var _shake: float = 0.0
var _next_prop_seen_this_run: Dictionary = {}
var _max_drop_level: int = 4


func _ready() -> void:
	FruitRegistry.ensure_textures_ready()
	UITheme.apply_to(self)
	_apply_styles()

	_board.score_changed.connect(_on_board_score_changed)
	_board.next_fruit_changed.connect(_on_board_next_fruit_changed)
	_board.danger_changed.connect(_on_board_danger_changed)
	_board.game_over.connect(_on_board_game_over)
	_board.fruit_merged.connect(_on_board_fruit_merged)
	_board.fruit_unlocked_at.connect(_on_board_fruit_unlocked_at)
	_board.explosion_triggered.connect(_on_board_explosion)
	_board.spawn_phase_changed.connect(_on_board_spawn_phase_changed)
	_board.spawn_floor_changed.connect(_on_board_spawn_floor_changed)

	_pause_button.pressed.connect(_on_pause_pressed)
	_resume_button.pressed.connect(_on_resume_pressed)
	_pause_restart_button.pressed.connect(_on_restart_pressed)
	_pause_sound_button.pressed.connect(_on_sound_pressed)
	_pause_power_ups_button.pressed.connect(_on_power_ups_pressed)
	_pause_skins_button.pressed.connect(_on_skins_pressed)
	_pause_language_button.pressed.connect(_on_language_pressed)
	_pause_menu_button.pressed.connect(_on_menu_pressed)
	_play_again_button.pressed.connect(_on_restart_pressed)
	_game_over_menu_button.pressed.connect(_on_menu_pressed)

	# Juice splats on the screen edges for combo splashes: above the HUD, below the modals.
	_edge_splatter = EdgeSplatter.new()
	add_child(_edge_splatter)
	move_child(_edge_splatter, _pause_overlay.get_index())

	_power_up_modal = PowerUpModal.new()
	add_child(_power_up_modal)
	_power_up_modal.closed.connect(_on_power_up_modal_closed)

	_skin_modal = SkinModal.new()
	add_child(_skin_modal)

	_language_modal = LanguageModal.new()
	add_child(_language_modal)

	FruitRegistry.skin_changed.connect(_on_skin_changed)
	Loc.language_changed.connect(_on_language_changed)
	AdManager.banner_height_changed.connect(_on_banner_height_changed)

	get_viewport().size_changed.connect(_layout_board)
	_pause_overlay.visible = false
	_game_over_overlay.visible = false
	_danger_banner.visible = false

	_board.set_game_mode(SceneManager.selected_mode)
	var is_frenzy := _board.game_mode == GameMode.Mode.FRENZY
	# In Frenzy the pink power-up button doubles as the mode indicator.
	_mode_badge.visible = false
	_pause_power_ups_button.visible = is_frenzy
	if is_frenzy:
		_build_power_info_button()

	_reset_run_state()
	_refresh_sound_button()
	# Sync initial HUD values from board.
	_on_board_score_changed(_board.score, _board.best_score, 0)
	_on_board_next_fruit_changed(_board.next_level, _board.next_property)
	AdManager.show_banner()
	await get_tree().process_frame
	_layout_board()


func _exit_tree() -> void:
	if Loc.language_changed.is_connected(_on_language_changed):
		Loc.language_changed.disconnect(_on_language_changed)
	if FruitRegistry.skin_changed.is_connected(_on_skin_changed):
		FruitRegistry.skin_changed.disconnect(_on_skin_changed)
	if AdManager.banner_height_changed.is_connected(_on_banner_height_changed):
		AdManager.banner_height_changed.disconnect(_on_banner_height_changed)
	# Never leave a screen-shake offset behind for the next scene.
	if is_inside_tree():
		get_viewport().canvas_transform = Transform2D.IDENTITY


func _process(delta: float) -> void:
	_clock += delta
	# Count the score up smoothly.
	if absf(_displayed_score - float(_target_score)) > 0.5:
		_displayed_score = lerpf(_displayed_score, float(_target_score), minf(delta * 12.0, 1.0))
		_score_value.text = UITheme.format_number(roundi(_displayed_score))
	elif _score_value.text != UITheme.format_number(_target_score):
		_displayed_score = float(_target_score)
		_score_value.text = UITheme.format_number(_target_score)

	# Screen shake (visual only: canvas transform, physics bodies never move).
	if _shake > 0.01:
		_shake = move_toward(_shake, 0.0, delta * 40.0)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		get_viewport().canvas_transform = Transform2D(0.0, off.round())
	elif get_viewport().canvas_transform != Transform2D.IDENTITY:
		get_viewport().canvas_transform = Transform2D.IDENTITY

	if _danger_banner.visible:
		var pulse := 1.0 + 0.05 * sin(_clock * 14.0)
		_danger_banner.pivot_offset = _danger_banner.size * 0.5
		_danger_banner.scale = Vector2(pulse, pulse)


# --- Styling ---------------------------------------------------------------------------------

func _apply_styles() -> void:
	_pause_button.text = ""
	UITheme.style_chunky_button(_pause_button, UITheme.CARD_WHITE, UITheme.CARD_SHADOW, UITheme.TEXT_DARK, 20, 30, false)
	UITheme.set_button_icon(_pause_button, "pause", 36.0, UITheme.TEXT_DARK)

	_mode_badge.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.PINK, UITheme.PINK_SHADOW, 14, 0, 12, 3))
	UITheme.style_label(_mode_label, 18, Color.WHITE, true)

	UITheme.style_label(_score_value, 72, Color.WHITE, true, 18, UITheme.OUTLINE_DARK)
	_score_value.add_theme_color_override("font_shadow_color", Color(0.18, 0.23, 0.36, 0.3))
	_score_value.add_theme_constant_override("shadow_offset_y", 7)
	_score_value.add_theme_constant_override("shadow_outline_size", 18)

	_best_chip.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 22, 14, 4, 4))
	var crown := PixelIcons.make_rect("crown", 24.0, UITheme.GOLD_SHADOW)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_best_row.add_child(crown)
	_best_row.move_child(crown, 0)
	UITheme.style_label(_best_value, 22, UITheme.TEXT_DARK, true)

	var bubble := UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 40, 8, 6, 7)
	_next_bubble.add_theme_stylebox_override("panel", bubble)
	UITheme.style_label(_next_title, 18, UITheme.TEXT_MUTED, true)

	_danger_banner.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.DANGER_RED, UITheme.DANGER_SHADOW, 24, 20, 6, 5))
	UITheme.style_label(_danger_label, 24, Color.WHITE, true, 6, UITheme.DANGER_SHADOW)

	var modal_style := UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 36, 30, 26, 9)
	_pause_card.add_theme_stylebox_override("panel", modal_style)
	_game_over_card.add_theme_stylebox_override("panel", modal_style)
	UITheme.style_label(_pause_title, 52, UITheme.TEXT_DARK, true)
	UITheme.style_label(_game_over_title, 54, Color.WHITE, true, 16, UITheme.PINK_SHADOW)

	UITheme.style_primary_button(_resume_button)
	UITheme.set_button_content(_resume_button, "play", Loc.t("game.resume"), 36, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 34.0)
	UITheme.style_orange_button(_pause_restart_button)
	UITheme.set_button_content(_pause_restart_button, "restart", Loc.t("game.restart"), 30, Color.WHITE, UITheme.ORANGE_SHADOW.darkened(0.2), 30.0)
	UITheme.style_secondary_button(_pause_sound_button)
	UITheme.style_secondary_button(_pause_power_ups_button)
	UITheme.set_button_content(_pause_power_ups_button, "bolt", Loc.t("menu.powerups"), 24, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 26.0)
	UITheme.style_blue_button(_pause_skins_button)
	UITheme.set_button_content(_pause_skins_button, "palette", Loc.t("menu.skins"), 26, Color.WHITE, UITheme.BLUE_SHADOW.darkened(0.2), 28.0)
	UITheme.style_secondary_button(_pause_language_button)
	UITheme.set_button_texture_content(_pause_language_button, FlagIcons.get_flag(Loc.language), Loc.t("menu.language"), 24, UITheme.TEXT_DARK, Color(0, 0, 0, 0), Vector2(36.0, 24.0))
	UITheme.style_secondary_button(_pause_menu_button)
	UITheme.set_button_content(_pause_menu_button, "home", Loc.t("game.home"), 28, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 30.0)

	_new_best_badge.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.GOLD, UITheme.GOLD_SHADOW, 18, 18, 4, 5))
	UITheme.style_label(_new_best_label, 24, Color.WHITE, true, 6, UITheme.GOLD_SHADOW)
	UITheme.style_label(_final_score_label, 80, UITheme.TEXT_DARK, true)
	UITheme.style_label(_final_best_label, 24, UITheme.TEXT_MUTED, true)
	_run_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color("#F2F9FC"), Color("#F2F9FC"), 24, 0, 16, 12))
	UITheme.style_label(_run_title, 20, UITheme.TEXT_MUTED, true)
	UITheme.style_label(_run_info_label, 20, UITheme.TEXT_DARK)
	_run_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UITheme.style_primary_button(_play_again_button)
	UITheme.set_button_content(_play_again_button, "restart", Loc.t("game.play_again"), 36, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 32.0)
	UITheme.style_secondary_button(_game_over_menu_button)
	UITheme.set_button_content(_game_over_menu_button, "home", Loc.t("game.home"), 28, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 30.0)

	_pause_title.text = Loc.t("game.paused")
	_next_title.text = Loc.t("game.next")
	_new_best_label.text = Loc.t("game.new_best_badge")


func _build_power_info_button() -> void:
	_power_info_button = UITheme.make_icon_button("bolt", UITheme.PINK, UITheme.PINK_SHADOW, Color.WHITE, 60.0, 28.0)
	_power_info_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_power_info_button.tooltip_text = Loc.t("menu.powerups")
	_power_info_button.pressed.connect(_on_power_ups_pressed)
	_mode_badge.get_parent().add_child(_power_info_button)


# --- Layout ----------------------------------------------------------------------------------

func _on_banner_height_changed(_height_pixels: int) -> void:
	_layout_board()


func _layout_board() -> void:
	var vp := get_viewport()
	var vp_size := get_viewport_rect().size
	var safe_top := UITheme.get_safe_top(vp)
	var safe_bottom := UITheme.get_safe_bottom(vp)
	var banner_top := AdManager.get_banner_height_in_viewport(vp)
	var top_pad := 12.0 if banner_top > 0.0 else 22.0
	_top_margin.add_theme_constant_override("margin_top", int(roundf(top_pad + safe_top + banner_top)))
	_bottom_margin.add_theme_constant_override("margin_bottom", int(18.0 + safe_bottom))

	_top_hud_bottom = maxf(_top_margin.get_combined_minimum_size().y, 150.0 + banner_top)
	_top_margin.offset_bottom = _top_hud_bottom
	_bottom_bar_height = maxf(_bottom_margin.get_combined_minimum_size().y, 110.0)
	var avail_h := maxf(vp_size.y - _top_hud_bottom - _bottom_bar_height, 420.0)

	# Keep the RigidBody2D parent at unit scale so physics stays rock-solid.
	_board.scale = Vector2.ONE
	# The held fruit floats ~20px above the board origin, so leave a little air above it.
	var top_y := _top_hud_bottom + maxf((avail_h - BOARD_HEIGHT) * 0.5, 0.0)
	_board.position = Vector2(roundf(vp_size.x * 0.5), roundf(top_y))

	_toasts.top_margin = _top_hud_bottom + 12.0
	_place_danger_banner()


func _place_danger_banner() -> void:
	var sz := _danger_banner.get_combined_minimum_size()
	_danger_banner.size = sz
	var anchor := _board.to_global(Vector2(0.0, JarContainer.JAR_TOP_Y + 22.0))
	_danger_banner.global_position = Vector2(anchor.x - sz.x * 0.5, anchor.y)


func _board_to_ui(local_pos: Vector2) -> Vector2:
	return _board.get_global_transform() * local_pos


# --- Run state -------------------------------------------------------------------------------

func _reset_run_state() -> void:
	_target_score = 0
	_displayed_score = 0.0
	_best_at_start = SaveManager.get_high_score(_board.game_mode)
	_best_toast_done = false
	_milestone_index = 0
	_combo = 0
	_last_merge_time = -10.0
	_combo_toast_done = false
	_run_merges = 0
	_run_new_discoveries.clear()
	_run_max_level = 0
	_danger_peak = 0.0
	_danger_time = 0.0
	_next_prop_seen_this_run.clear()
	_max_drop_level = 4
	_fruit_guide.reset_run()
	_toasts.clear()
	if _edge_splatter != null:
		_edge_splatter.clear()
	for child in _fx_layer.get_children():
		child.queue_free()


# --- Board signal handlers -------------------------------------------------------------------

func _on_board_score_changed(new_score: int, new_best: int, delta_points: int) -> void:
	_target_score = new_score
	if delta_points <= 0:
		_displayed_score = float(new_score)
		_score_value.text = UITheme.format_number(new_score)
	var best_key := "game.frenzy_best" if _board.game_mode == GameMode.Mode.FRENZY else "game.best"
	_best_value.text = Loc.t(best_key, [UITheme.format_number(new_best)])

	if delta_points > 0:
		_punch(_score_value, 1.15)
		if not _best_toast_done and _best_at_start > 0 and new_score > _best_at_start:
			_best_toast_done = true
			_toasts.show_toast(Loc.t("toast.best"), Loc.t("toast.best_sub", [UITheme.format_number(_best_at_start)]), PixelIcons.get_icon("crown"), UITheme.GOLD, ToastStack.HOLD_TIME, true)
			_punch(_best_chip, 1.2)
		while _milestone_index < SCORE_MILESTONES.size() and new_score >= int(SCORE_MILESTONES[_milestone_index]):
			var m := int(SCORE_MILESTONES[_milestone_index])
			_milestone_index += 1
			_toasts.show_toast(Loc.t("toast.points", [UITheme.format_number(m)]), _milestone_cheer(m), PixelIcons.get_icon("star"), UITheme.ORANGE)


func _milestone_cheer(m: int) -> String:
	if m >= 10000:
		return Loc.t("toast.cheer4")
	if m >= 5000:
		return Loc.t("toast.cheer3")
	if m >= 2500:
		return Loc.t("toast.cheer2")
	return Loc.t("toast.cheer1")


func _on_board_next_fruit_changed(next_lvl: int, next_prop: int = FruitProperty.Type.NONE) -> void:
	var tex := FruitRegistry.textures.get_texture(next_lvl)
	_next_icon.texture = tex
	var prop := next_prop as FruitProperty.Type
	# Same tint/outline look as in the jar for Sticky / Concrete / Charged.
	_next_icon.material = FruitRegistry.textures.get_property_material(prop)
	_punch(_next_icon, 1.25)

	if prop != FruitProperty.Type.NONE:
		_next_prop_tag.visible = true
		_next_prop_label.text = FruitProperty.get_short_label(prop)
		_next_prop_tag.add_theme_stylebox_override(
			"panel",
			UITheme.make_panel_style(FruitProperty.get_color(prop), FruitProperty.get_accent_color(prop), 14, 0, 12, 2)
		)
		UITheme.style_label(_next_prop_label, 18, Color.WHITE, true, 6, FruitProperty.get_accent_color(prop))
		_punch(_next_prop_tag, 1.3)
		_maybe_show_power_up_tip(prop)
	else:
		_next_prop_tag.visible = false


func _maybe_show_power_up_tip(prop: FruitProperty.Type) -> void:
	if SaveManager.has_seen_power_up(int(prop)):
		return
	SaveManager.mark_power_up_seen(int(prop))
	var desc := Loc.t("pu.%s.tip" % Loc.prop_key(prop))
	var icon: Texture2D = FruitRegistry.textures.get_property_icon(prop)
	if icon == null:
		icon = PixelIcons.get_icon("bolt")
	_toasts.show_toast(Loc.t("toast.powerup", [FruitProperty.get_display_name(prop)]), desc, icon, FruitProperty.get_color(prop))


func _on_board_fruit_merged(level: int, local_pos: Vector2, points: int, is_max_bonus: bool) -> void:
	_run_merges += 1
	_run_max_level = maxi(_run_max_level, level)

	# Combo: merges in quick succession.
	if _clock - _last_merge_time <= COMBO_WINDOW:
		_combo += 1
	else:
		_combo = 1
	_last_merge_time = _clock

	var ui_pos := _board_to_ui(local_pos)
	var col := FruitRegistry.textures.get_primary_color(level)
	var font_size := int(lerpf(30.0, 54.0, clampf(float(level) / 14.0, 0.0, 1.0)))
	_spawn_float_text("+%d" % points, ui_pos, font_size, Color.WHITE, col.darkened(0.35))

	# Combo splash plays only sometimes (chance grows with the combo), see AudioManager.
	var splashed := AudioManager.try_play_combo_splash(_combo)
	if splashed:
		# Splat the screen edges in this fruit's own sprite colours.
		_edge_splatter.splash(FruitRegistry.textures.get_palette(level), _combo)
		_add_shake(3.0)
	if _combo >= 3:
		_spawn_float_text(Loc.t("game.combo", [_combo]), ui_pos + Vector2(0.0, -48.0), 30, UITheme.GOLD, UITheme.GOLD_SHADOW.darkened(0.3), 0.08)
		if not splashed:
			AudioManager.play_pop(1.0 + 0.08 * float(mini(_combo, 8)))
	if _combo >= 5 and not _combo_toast_done:
		_combo_toast_done = true
		_toasts.show_toast(Loc.t("game.combo", [_combo]), Loc.t("toast.combo_sub"), PixelIcons.get_icon("sparkle"), UITheme.ORANGE)

	if is_max_bonus:
		_add_shake(14.0)
		_toasts.show_toast(Loc.t("toast.smash", [Loc.fruit_name(level)]), Loc.t("toast.smash_sub", [UITheme.format_number(points)]), FruitRegistry.textures.get_texture(level), UITheme.PINK, ToastStack.HOLD_TIME, true)
	elif level >= 11:
		_add_shake(8.0)
	elif level >= 8:
		_add_shake(4.0)


func _on_board_fruit_unlocked_at(level: int, local_pos: Vector2) -> void:
	var first_ever := SaveManager.discover(level)
	if first_ever:
		_run_new_discoveries.append(level)
	_fly_to_guide(level, _board_to_ui(local_pos), first_ever)

	var fruit_name := Loc.fruit_name(level)
	var total := FruitRegistry.catalog.get_count()
	if first_ever:
		if SaveManager.get_next_undiscovered(total) < 0:
			_toasts.show_toast(Loc.t("toast.complete"), Loc.t("toast.complete_sub", [total]), FruitRegistry.textures.get_texture(level), UITheme.PINK, 3.2, true)
		else:
			_toasts.show_toast(Loc.t("toast.new_fruit", [fruit_name]), Loc.t("toast.new_fruit_sub", [SaveManager.get_discovered_count(total), total]), FruitRegistry.textures.get_texture(level), UITheme.GOLD, 2.8, true)
	elif level >= BIG_FRUIT_TOAST_LEVEL:
		_toasts.show_toast(Loc.t("toast.wow", [fruit_name]), Loc.t("toast.tier", [level + 1, total]), FruitRegistry.textures.get_texture(level), UITheme.BLUE)


func _on_board_spawn_phase_changed(_phase: int, max_drop_level: int) -> void:
	var sub := Loc.t("toast.drops_sub")
	var icon: Texture2D = PixelIcons.get_icon("bolt")
	if max_drop_level > _max_drop_level:
		sub = Loc.t("toast.drops_new", [Loc.fruit_name(max_drop_level)])
		icon = FruitRegistry.textures.get_texture(max_drop_level)
	_max_drop_level = maxi(_max_drop_level, max_drop_level)
	_toasts.show_toast(Loc.t("toast.drops"), sub, icon, UITheme.GREEN)


func _on_board_spawn_floor_changed(floor_level: int) -> void:
	# The fruit right below the new floor just retired from (normal) drops.
	var retired := floor_level - 1
	_toasts.show_toast(
		Loc.t("toast.floor"),
		Loc.t("toast.floor_sub", [Loc.fruit_plural(retired)]),
		FruitRegistry.textures.get_texture(floor_level),
		UITheme.GREEN
	)


func _on_board_explosion(_local_pos: Vector2, _blast_radius: float, is_nuclear: bool) -> void:
	_add_shake(16.0 if is_nuclear else 9.0)


func _on_board_danger_changed(is_triggered: bool, progress: float) -> void:
	var was_visible := _danger_banner.visible
	_danger_banner.visible = is_triggered
	if is_triggered:
		_danger_peak = maxf(_danger_peak, progress)
		var remaining := maxf((1.0 - progress) * _board.danger_detector.grace_duration, 0.0)
		_danger_label.text = Loc.t("game.too_full", [remaining])
		if not was_visible:
			_place_danger_banner()
			_punch(_danger_banner, 1.25)
	elif was_visible and not _board.is_game_over:
		# Survived a close call.
		if _danger_peak >= 0.4 and _clock - _last_phew_time > 15.0:
			_last_phew_time = _clock
			_toasts.show_toast(Loc.t("toast.phew"), Loc.t("toast.phew_sub"), PixelIcons.get_icon("star"), UITheme.BLUE)
		_danger_peak = 0.0


func _on_board_game_over(final_score: int, is_new_best: bool) -> void:
	_danger_banner.visible = false
	SaveManager.record_run(_run_merges)
	_add_shake(10.0)
	AudioManager.play_pop(0.7)

	_target_score = final_score
	_new_best_badge.visible = is_new_best
	_final_score_label.text = UITheme.format_number(final_score)
	_final_best_label.text = Loc.t("game.final_best", [UITheme.format_number(SaveManager.get_high_score(_board.game_mode))])
	_game_over_title.text = Loc.t("game.record") if is_new_best else Loc.t("game.over")
	_build_run_summary()

	# Let the player see the overflow for a beat before the card slides in.
	await get_tree().create_timer(0.6).timeout
	if not _board.is_game_over:
		return
	_game_over_overlay.visible = true
	_game_over_dim.modulate.a = 0.0
	_game_over_card.pivot_offset = _game_over_card.size * 0.5
	_game_over_card.scale = Vector2(0.7, 0.7)
	_game_over_card.modulate.a = 0.0
	var tw := _game_over_card.create_tween().set_parallel(true)
	tw.tween_property(_game_over_dim, "modulate:a", 1.0, 0.25)
	tw.tween_property(_game_over_card, "modulate:a", 1.0, 0.18)
	tw.tween_property(_game_over_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_new_best:
		_new_best_badge.pivot_offset = _new_best_badge.size * 0.5
		var badge_tw := _new_best_badge.create_tween().set_loops(4)
		badge_tw.tween_property(_new_best_badge, "scale", Vector2(1.12, 1.12), 0.25)
		badge_tw.tween_property(_new_best_badge, "scale", Vector2.ONE, 0.25)


func _build_run_summary() -> void:
	for child in _run_fruits_row.get_children():
		child.queue_free()
	var total := FruitRegistry.catalog.get_count()
	var top := clampi(_run_max_level, 0, total - 1)
	for i in range(total):
		if _fruit_guide.is_made_this_run(i):
			top = maxi(top, i)
	# Show the climb up to the biggest fruit made this run.
	var first := maxi(top - 5, 0)
	for i in range(first, top + 1):
		var t := float(i - first) / float(maxi(top - first, 1))
		var icon := UITheme.make_fruit_icon(i, lerpf(30.0, 64.0, t))
		icon.size_flags_vertical = Control.SIZE_SHRINK_END
		_run_fruits_row.add_child(icon)
	_run_title.text = Loc.t("game.biggest", [Loc.fruit_name(top)])

	var lines: Array[String] = []
	if not _run_new_discoveries.is_empty():
		lines.append(Loc.t("game.discoveries", [_run_new_discoveries.size(), SaveManager.get_discovered_count(total), total]))
	else:
		var next_goal := SaveManager.get_next_undiscovered(total)
		if next_goal > 0:
			lines.append(Loc.t("game.next_discover", [Loc.fruit_plural(next_goal - 1)]))
		elif next_goal < 0:
			lines.append(Loc.t("game.complete"))
	lines.append(Loc.t("game.merges", [_run_merges]))
	_run_info_label.text = "\n".join(PackedStringArray(lines))


# --- FX helpers ------------------------------------------------------------------------------

func _spawn_float_text(text: String, ui_pos: Vector2, font_size: int, color: Color, outline: Color, delay: float = 0.0) -> void:
	var lbl := UITheme.make_label(text, font_size, color, true, 10, outline)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fx_layer.add_child(lbl)
	lbl.reset_size()
	var sz := lbl.get_combined_minimum_size()
	lbl.size = sz
	lbl.pivot_offset = sz * 0.5
	lbl.global_position = ui_pos - sz * 0.5
	lbl.scale = Vector2(0.3, 0.3)
	lbl.modulate.a = 0.0 if delay > 0.0 else 1.0
	var tw := lbl.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.01)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 70.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.25)
	tw.tween_callback(lbl.queue_free)


## A copy of the new fruit arcs from the merge spot into its slot in the fruit guide.
func _fly_to_guide(level: int, from_ui: Vector2, first_ever: bool) -> void:
	var def := FruitRegistry.catalog.get_fruit(level)
	var start_px := clampf((def.radius * 2.0) if def != null else 48.0, 32.0, 120.0)
	var icon := UITheme.make_fruit_icon(level, start_px)
	icon.size = Vector2(start_px, start_px)
	icon.pivot_offset = icon.size * 0.5
	_fx_layer.add_child(icon)
	icon.global_position = from_ui - icon.size * 0.5

	var end_center := _fruit_guide.get_slot_global_center(level)
	var end_scale := _fruit_guide.get_slot_icon_size(level) / start_px
	var start_center := from_ui
	var control_pt := Vector2(lerpf(start_center.x, end_center.x, 0.5), minf(start_center.y, end_center.y) - 140.0)
	var duration := 0.75 if first_ever else 0.55

	var tw := icon.create_tween()
	if first_ever:
		# Brief "look at me!" hold with a wobble before flying.
		tw.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(icon, "rotation", 0.2, 0.08)
		tw.tween_property(icon, "rotation", -0.2, 0.1)
		tw.tween_property(icon, "rotation", 0.0, 0.08)
	var start_scale := 1.35 if first_ever else 1.0
	var fly := func(t: float) -> void:
		# Quadratic bezier arc from the jar up and over into the guide slot.
		var a := start_center.lerp(control_pt, t)
		var b := control_pt.lerp(end_center, t)
		icon.global_position = a.lerp(b, t) - icon.size * 0.5
		var s := lerpf(start_scale, end_scale, t)
		icon.scale = Vector2(s, s)
		icon.rotation = t * TAU * 0.5
	tw.tween_method(fly, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		icon.queue_free()
		_fruit_guide.play_unlock(level, first_ever)
		AudioManager.play_pop(1.2 if first_ever else 1.0)
	)


func _punch(node: Control, amount: float = 1.15) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(amount, amount)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# --- Buttons ---------------------------------------------------------------------------------

func _on_pause_pressed() -> void:
	if _board.is_game_over or get_tree().paused:
		return
	AudioManager.play_click()
	_board.dropper.cancel_drag()
	get_tree().paused = true
	_pause_overlay.visible = true
	_pause_card.pivot_offset = _pause_card.size * 0.5
	_pause_card.scale = Vector2(0.8, 0.8)
	var tw := _pause_card.create_tween()
	tw.tween_property(_pause_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	_reset_run_state()
	_on_board_score_changed(_board.score, _board.best_score, 0)


func _on_power_ups_pressed() -> void:
	if _board.is_game_over:
		return
	if not get_tree().paused:
		_board.dropper.cancel_drag()
		get_tree().paused = true
		_modal_paused_game = true
	_power_up_modal.open()


func _on_power_up_modal_closed() -> void:
	if _modal_paused_game:
		_modal_paused_game = false
		if not _pause_overlay.visible:
			get_tree().paused = false


func _on_skins_pressed() -> void:
	_skin_modal.open()


func _on_language_pressed() -> void:
	_language_modal.open()


func _on_language_changed(_code: String) -> void:
	_pause_title.text = Loc.t("game.paused")
	UITheme.set_button_content(_resume_button, "play", Loc.t("game.resume"), 36, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 34.0)
	UITheme.set_button_content(_pause_restart_button, "restart", Loc.t("game.restart"), 30, Color.WHITE, UITheme.ORANGE_SHADOW.darkened(0.2), 30.0)
	_refresh_sound_button()
	UITheme.set_button_content(_pause_power_ups_button, "bolt", Loc.t("menu.powerups"), 24, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 26.0)
	UITheme.set_button_content(_pause_skins_button, "palette", Loc.t("menu.skins"), 26, Color.WHITE, UITheme.BLUE_SHADOW.darkened(0.2), 28.0)
	UITheme.set_button_texture_content(_pause_language_button, FlagIcons.get_flag(Loc.language), Loc.t("menu.language"), 24, UITheme.TEXT_DARK, Color(0, 0, 0, 0), Vector2(36.0, 24.0))
	UITheme.set_button_content(_pause_menu_button, "home", Loc.t("game.home"), 28, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 30.0)

	_next_title.text = Loc.t("game.next")
	_new_best_label.text = Loc.t("game.new_best_badge")
	UITheme.set_button_content(_play_again_button, "restart", Loc.t("game.play_again"), 36, Color.WHITE, UITheme.GREEN_SHADOW.darkened(0.2), 32.0)
	UITheme.set_button_content(_game_over_menu_button, "home", Loc.t("game.home"), 28, UITheme.TEXT_DARK, Color(0, 0, 0, 0), 30.0)

	var best_key := "game.frenzy_best" if _board.game_mode == GameMode.Mode.FRENZY else "game.best"
	_best_value.text = Loc.t(best_key, [UITheme.format_number(_board.best_score)])
	if _next_prop_tag.visible:
		_next_prop_label.text = FruitProperty.get_short_label(_board.next_property as FruitProperty.Type)
	if _power_info_button != null and is_instance_valid(_power_info_button):
		_power_info_button.tooltip_text = Loc.t("menu.powerups")

	_fruit_guide.refresh_language()
	_power_up_modal.refresh_language()
	_skin_modal.refresh_language()
	_language_modal.refresh_language()


func _on_skin_changed(_skin_id: String) -> void:
	_next_icon.texture = FruitRegistry.textures.get_texture(_board.next_level)
	_fruit_guide.refresh_skin()
	_power_up_modal.refresh_skin()


func _on_sound_pressed() -> void:
	var next_state := not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(next_state)
	_refresh_sound_button()
	if next_state:
		AudioManager.play_click()


func _refresh_sound_button() -> void:
	var on := SaveManager.is_sfx_enabled()
	UITheme.set_button_content(_pause_sound_button, "sound" if on else "mute", Loc.t("game.sound_on") if on else Loc.t("game.sound_off"), 24, UITheme.TEXT_DARK if on else UITheme.TEXT_MUTED, Color(0, 0, 0, 0), 28.0)


func _on_menu_pressed() -> void:
	AudioManager.play_click()
	SceneManager.goto_scene_with_loading(SceneManager.MENU_SCENE, Loc.t("load.home"))
