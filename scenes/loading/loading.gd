extends Control

## Loading screen: threaded scene load with a row of hopping fruits, a chunky progress bar with
## a fruit riding along it, and a random gameplay tip.

const FAKE_LOAD_DURATION := 3.0
const REAL_LOAD_WEIGHT := 0.25
const HOP_FRUIT_COUNT := 5
const HOP_SIZE := 72.0

@onready var _column: VBoxContainer = %Column
@onready var _fruit_row: Control = %FruitRow
@onready var _hint_label: Label = %HintLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _bar_rider: TextureRect = %BarRider
@onready var _percent_label: Label = %PercentLabel
@onready var _tip_card: PanelContainer = %TipCard
@onready var _tip_row: HBoxContainer = %TipRow
@onready var _tip_label: Label = %TipLabel

var _target_path: String = ""
var _elapsed: float = 0.0
var _visual_progress: float = 0.0
var _is_loaded: bool = false
var _post_load_elapsed: float = 0.0
var _progress_at_loaded: float = 0.0
var _loaded_scene: PackedScene = null
var _is_done: bool = false
var _hop_icons: Array[TextureRect] = []


func _ready() -> void:
	AdManager.hide_banner()
	FruitRegistry.ensure_textures_ready()
	UITheme.apply_to(self)
	_apply_styles()
	_build_hop_row()

	_target_path = SceneManager.next_scene_path
	if _target_path.is_empty():
		_target_path = SceneManager.MENU_SCENE

	_hint_label.text = SceneManager.loading_hint if not SceneManager.loading_hint.is_empty() else Loc.t("load.default")
	_tip_label.text = Loc.random_tip()

	var err := ResourceLoader.load_threaded_request(_target_path)
	if err != OK:
		_is_done = true
		SceneManager.change_to_packed(null, _target_path)


func _apply_styles() -> void:
	UITheme.style_label(_hint_label, 40, Color.WHITE, true, 14, UITheme.OUTLINE_DARK)
	UITheme.style_label(_percent_label, 26, UITheme.TEXT_DARK, true)
	UITheme.style_label(_tip_label, 22, UITheme.TEXT_DARK)

	var bar_bg := UITheme.make_panel_style(Color("#FFFFFF"), UITheme.CARD_SHADOW, 24, 0, 0, 0)
	bar_bg.border_width_bottom = 6
	var bar_fill := UITheme.make_panel_style(UITheme.GREEN, UITheme.GREEN_SHADOW, 24, 0, 0, 0)
	bar_fill.border_width_bottom = 6
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	_tip_card.add_theme_stylebox_override("panel", UITheme.make_card_style(UITheme.CARD_WHITE, UITheme.CARD_SHADOW, 26, 20, 14, 6))
	var bulb := PixelIcons.make_rect("star", 32.0, UITheme.GOLD)
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_row.add_child(bulb)
	_tip_row.move_child(bulb, 0)

	_bar_rider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bar_rider.texture = FruitRegistry.textures.get_texture(0)


func _build_hop_row() -> void:
	# Hop the first few fruits the player has discovered (or Blueberries for a new player).
	var levels: Array[int] = []
	var count := FruitRegistry.catalog.get_count()
	for i in range(count):
		if SaveManager.is_discovered(i):
			levels.append(i)
	levels.shuffle()
	while levels.size() < HOP_FRUIT_COUNT:
		levels.append(0)
	levels.resize(HOP_FRUIT_COUNT)
	levels.sort()
	for lvl in levels:
		var icon := UITheme.make_fruit_icon(lvl, HOP_SIZE)
		icon.size = Vector2(HOP_SIZE, HOP_SIZE)
		icon.pivot_offset = Vector2(HOP_SIZE * 0.5, HOP_SIZE)
		_fruit_row.add_child(icon)
		_hop_icons.append(icon)


static func compute_post_load_progress(start_progress: float, post_load_elapsed: float) -> float:
	var fake_t := clampf(post_load_elapsed / FAKE_LOAD_DURATION, 0.0, 1.0)
	return lerpf(clampf(start_progress, 0.0, 1.0), 1.0, fake_t)


func _process(delta: float) -> void:
	_elapsed += delta
	_animate_hops()

	if _is_done:
		return

	if not _is_loaded:
		var progress_arr: Array = []
		var status := ResourceLoader.load_threaded_get_status(_target_path, progress_arr)
		var real_progress := 0.0
		if not progress_arr.is_empty():
			real_progress = float(progress_arr[0])

		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_done = true
			SceneManager.change_to_packed(null, _target_path)
			return
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			_is_loaded = true
			_loaded_scene = ResourceLoader.load_threaded_get(_target_path) as PackedScene
			_progress_at_loaded = _visual_progress
			_post_load_elapsed = 0.0
		else:
			_visual_progress = move_toward(_visual_progress, clampf(real_progress, 0.0, 1.0) * REAL_LOAD_WEIGHT, delta * 2.0)

	if _is_loaded:
		_post_load_elapsed += delta
		var target_visual := compute_post_load_progress(_progress_at_loaded, _post_load_elapsed)
		_visual_progress = move_toward(_visual_progress, target_visual, delta * 2.5)

	_progress_bar.value = _visual_progress * 100.0
	_percent_label.text = "%d%%" % roundi(_visual_progress * 100.0)
	_update_rider()

	if _is_loaded and _post_load_elapsed >= FAKE_LOAD_DURATION and _visual_progress >= 0.99:
		_progress_bar.value = 100.0
		_percent_label.text = "100%"
		_is_done = true
		SceneManager.change_to_packed(_loaded_scene, _target_path)


func _animate_hops() -> void:
	var n := _hop_icons.size()
	if n == 0:
		return
	var row_w := _fruit_row.size.x
	var spacing := minf(110.0, row_w / float(n))
	var start_x := (row_w - spacing * float(n)) * 0.5 + (spacing - HOP_SIZE) * 0.5
	var ground := _fruit_row.size.y - HOP_SIZE
	for i in range(n):
		var icon := _hop_icons[i]
		# Each fruit hops in a wave; squash on landing, stretch in the air.
		var phase := fmod(_elapsed * 2.2 - float(i) * 0.18, 1.0)
		var height := sin(phase * PI)
		icon.position = Vector2(start_x + spacing * float(i), ground - height * 64.0)
		if phase < 0.08 or phase > 0.92:
			icon.scale = Vector2(1.15, 0.85)
		else:
			icon.scale = Vector2(1.0 - 0.08 * height, 1.0 + 0.1 * height)


func _update_rider() -> void:
	var bar_w := _progress_bar.size.x
	var rider_size := 56.0
	_bar_rider.size = Vector2(rider_size, rider_size)
	var x := clampf(bar_w * _visual_progress - rider_size * 0.5, -rider_size * 0.25, bar_w - rider_size * 0.75)
	var bob := absf(sin(_elapsed * 10.0)) * 6.0
	_bar_rider.position = Vector2(x, -rider_size * 0.55 - bob)
	_bar_rider.pivot_offset = Vector2(rider_size * 0.5, rider_size * 0.5)
	_bar_rider.rotation = _elapsed * 6.0
	# The rider grows into a bigger fruit as loading progresses.
	var count := FruitRegistry.catalog.get_count()
	var lvl := clampi(int(_visual_progress * 4.99), 0, count - 1)
	if SaveManager.is_discovered(lvl):
		_bar_rider.texture = FruitRegistry.textures.get_texture(lvl)
