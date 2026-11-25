extends Control

## Boot screen: prepares the fruit sprites, plays a short splash, then goes Loading -> Menu.

@onready var _splash_card: VBoxContainer = %SplashCard
@onready var _badge_icon: TextureRect = %BadgeIcon
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel

var _time: float = 0.0


func _ready() -> void:
	UITheme.apply_to(self)
	_apply_styles()
	_title_label.text = Loc.t("app.title")
	_subtitle_label.text = Loc.t("boot.subtitle")
	_status_label.text = Loc.t("boot.washing")
	FruitRegistry.warm_up(self)

	# Show the biggest fruit the player has discovered so far.
	var count := FruitRegistry.catalog.get_count()
	var best := 0
	for i in range(count):
		if SaveManager.is_discovered(i):
			best = i
	_badge_icon.texture = FruitRegistry.textures.get_texture(best)

	_splash_card.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_splash_card, "modulate:a", 1.0, 0.25)

	_badge_icon.pivot_offset = _badge_icon.custom_minimum_size * 0.5
	_badge_icon.scale = Vector2(0.2, 0.2)
	var pop := create_tween()
	pop.tween_property(_badge_icon, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.55).timeout
	_status_label.text = Loc.t("boot.ready")
	await get_tree().create_timer(0.25).timeout
	SceneManager.goto_scene_with_loading(SceneManager.MENU_SCENE, Loc.t("load.opening"))


func _process(delta: float) -> void:
	_time += delta
	_badge_icon.rotation = sin(_time * 2.5) * 0.08


func _apply_styles() -> void:
	UITheme.style_label(_title_label, 80, Color.WHITE, true, 20, UITheme.OUTLINE_DARK)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.18, 0.23, 0.36, 0.35))
	_title_label.add_theme_constant_override("shadow_offset_y", 10)
	_title_label.add_theme_constant_override("shadow_outline_size", 20)
	UITheme.style_label(_subtitle_label, 26, Color.WHITE, true, 10, UITheme.OUTLINE_DARK)
	UITheme.style_label(_status_label, 24, UITheme.TEXT_DARK)
	UITheme.style_label(_version_label, 20, UITheme.TEXT_MUTED)
