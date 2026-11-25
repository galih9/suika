extends Node

## Coordinates scene transitions through the Loading screen cleanly.

const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const LOADING_SCENE := "res://scenes/loading/loading.tscn"
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"

var next_scene_path: String = MENU_SCENE
var loading_hint: String = "Loading..."
var selected_mode: GameMode.Mode = GameMode.Mode.NORMAL


func goto_scene_with_loading(target_path: String, hint: String = "Loading...") -> void:
	get_tree().paused = false
	next_scene_path = target_path
	loading_hint = hint
	get_tree().change_scene_to_file(LOADING_SCENE)


func goto_scene_direct(target_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(target_path)
