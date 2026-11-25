extends Control

## Loading screen: smoothly loads the target scene via ResourceLoader.load_threaded_request.

const MIN_DISPLAY_TIME := 0.35

@onready var _card: PanelContainer = %LoadingCard
@onready var _fruit_icon: TextureRect = %FruitIcon
@onready var _hint_label: Label = %HintLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _percent_label: Label = %PercentLabel
@onready var _tip_label: Label = %TipLabel

var _target_path: String = ""
var _elapsed: float = 0.0
var _visual_progress: float = 0.0
var _icon_timer: float = 0.0
var _icon_index: int = 0
var _is_done: bool = false


func _ready() -> void:
	FruitRegistry.ensure_textures_ready()
	_apply_styles()

	_target_path = SceneManager.next_scene_path
	if _target_path.is_empty():
		_target_path = SceneManager.MENU_SCENE

	_hint_label.text = SceneManager.loading_hint if not SceneManager.loading_hint.is_empty() else "Loading..."
	_tip_label.text = "Tip: Merge identical fruits from Kersen all the way to Kelapa!"
	_update_fruit_icon()

	var err := ResourceLoader.load_threaded_request(_target_path)
	if err != OK:
		_is_done = true
		get_tree().change_scene_to_file(_target_path)


func _apply_styles() -> void:
	_card.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_BORDER, 26, 3, 32, 32)
	)
	_hint_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_percent_label.add_theme_color_override("font_color", UITheme.PRIMARY_GREEN)
	_tip_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	UITheme.style_progress_bar(_progress_bar)


func _update_fruit_icon() -> void:
	var count := FruitRegistry.catalog.get_count()
	if count > 0:
		_fruit_icon.texture = FruitRegistry.textures.get_texture(_icon_index % count)


func _process(delta: float) -> void:
	if _is_done:
		return

	_elapsed += delta
	_icon_timer += delta
	if _icon_timer >= 0.22:
		_icon_timer = 0.0
		_icon_index += 1
		_update_fruit_icon()

	# Gentle bounce animation on the icon
	_fruit_icon.pivot_offset = _fruit_icon.size * 0.5
	var bounce := 1.0 + 0.08 * sin(_elapsed * 9.0)
	_fruit_icon.scale = Vector2(bounce, bounce)

	var progress_arr: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_path, progress_arr)
	var real_progress := 0.0
	if not progress_arr.is_empty():
		real_progress = float(progress_arr[0])

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		real_progress = 1.0
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_is_done = true
		get_tree().change_scene_to_file(_target_path)
		return

	var target_visual := minf(real_progress, _elapsed / MIN_DISPLAY_TIME)
	_visual_progress = move_toward(_visual_progress, clampf(target_visual, 0.0, 1.0), delta * 3.0)
	_progress_bar.value = _visual_progress * 100.0
	_percent_label.text = "%d%%" % int(round(_visual_progress * 100.0))

	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MIN_DISPLAY_TIME and _visual_progress >= 0.99:
		_is_done = true
		var packed := ResourceLoader.load_threaded_get(_target_path) as PackedScene
		if packed != null:
			get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(_target_path)
