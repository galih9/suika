extends Control

## Boot splash screen: shows the Galih9 title over a yellow-to-orange gradient with the Godot logo
## at bottom middle, plays the intro audio, warms up fruit textures, and transitions to Loading.

const SPLASH_DURATION := 3.0
const INTRO_AUDIO_PATH := "res://assets/intro.mp3"
const GODOT_LOGO_PATH := "res://assets/godot_logo.png"
const LOGO_BOTTOM_MARGIN := 48.0
const LOGO_HEIGHT := 84.0

@onready var _title_label: Label = %TitleLabel
@onready var _godot_logo: TextureRect = %GodotLogo
@onready var _intro_player: AudioStreamPlayer = %IntroPlayer


func _ready() -> void:
	UITheme.apply_to(self)
	_apply_styles()
	FruitRegistry.warm_up(self)

	if _godot_logo.texture == null:
		_godot_logo.texture = load(GODOT_LOGO_PATH) as Texture2D

	var safe_bottom := UITheme.get_safe_bottom(get_viewport())
	_godot_logo.offset_bottom = -(LOGO_BOTTOM_MARGIN + safe_bottom)
	_godot_logo.offset_top = _godot_logo.offset_bottom - LOGO_HEIGHT

	if _intro_player.stream == null:
		_intro_player.stream = load(INTRO_AUDIO_PATH) as AudioStream
	if _intro_player.stream != null and SaveManager.is_sfx_enabled():
		_intro_player.play()

	_title_label.modulate.a = 0.0
	_godot_logo.modulate.a = 0.0
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_title_label, "modulate:a", 1.0, 0.45)
	fade.tween_property(_godot_logo, "modulate:a", 1.0, 0.45)

	await get_tree().create_timer(SPLASH_DURATION).timeout
	if not is_inside_tree():
		return
	SceneManager.goto_scene_with_loading(SceneManager.MENU_SCENE, Loc.t("load.opening"))


func _apply_styles() -> void:
	_title_label.text = "Galih9"
	UITheme.style_label(_title_label, 104, Color.WHITE, true, 18, Color("#5A2308"))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.35, 0.14, 0.03, 0.35))
	_title_label.add_theme_constant_override("shadow_offset_y", 10)
	_title_label.add_theme_constant_override("shadow_outline_size", 18)
	_godot_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
