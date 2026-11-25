extends Node

## Coordinates scene transitions through the Loading screen, with a soft fade between scenes.

const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const LOADING_SCENE := "res://scenes/loading/loading.tscn"
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"

const FADE_OUT_TIME := 0.16
const FADE_IN_TIME := 0.24
const FADE_COLOR := Color("#BFEFFF")

var next_scene_path: String = MENU_SCENE
var loading_hint: String = "Loading..."
var selected_mode: GameMode.Mode = GameMode.Mode.NORMAL

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_tween: Tween
var _is_transitioning: bool = false
var _pending_swap: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 120
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


func goto_scene_with_loading(target_path: String, hint: String = "Loading...") -> void:
	next_scene_path = target_path
	loading_hint = hint
	_transition(func() -> void: get_tree().change_scene_to_file(LOADING_SCENE))


func goto_scene_direct(target_path: String) -> void:
	_transition(func() -> void: get_tree().change_scene_to_file(target_path))


## Used by the Loading screen once the threaded load finished.
func change_to_packed(packed: PackedScene, fallback_path: String = "") -> void:
	_transition(func() -> void:
		if packed != null:
			get_tree().change_scene_to_packed(packed)
		elif not fallback_path.is_empty():
			get_tree().change_scene_to_file(fallback_path)
	)


func is_transitioning() -> bool:
	return _is_transitioning


func _transition(swap: Callable) -> void:
	if _is_transitioning:
		# Another transition is mid-way: run this one as soon as it finishes.
		_pending_swap = swap
		return
	_is_transitioning = true
	get_tree().paused = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_TIME)
	_fade_tween.tween_callback(swap)
	# Give the new scene a frame to build its first layout before revealing it.
	_fade_tween.tween_interval(0.05)
	_fade_tween.tween_callback(_on_swap_done)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_TIME)
	_fade_tween.tween_callback(func() -> void: _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _on_swap_done() -> void:
	_is_transitioning = false
	if _pending_swap.is_valid():
		var next := _pending_swap
		_pending_swap = Callable()
		_transition(next)
