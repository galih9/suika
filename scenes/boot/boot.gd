extends Control

## Boot screen: warms up the single-atlas procedural fruit textures then transitions through Loading to Menu.

@onready var _splash_card: PanelContainer = %SplashCard
@onready var _badge_panel: PanelContainer = %BadgePanel
@onready var _badge_icon: TextureRect = %BadgeIcon
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_apply_styles()
	_splash_card.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_splash_card, "modulate:a", 1.0, 0.3)

	_status_label.text = "Preparing orchard..."
	await FruitRegistry.warm_up(self)

	var preview_tex := FruitRegistry.textures.get_texture(FruitRegistry.catalog.get_count() - 1)
	if preview_tex != null:
		_badge_icon.texture = preview_tex
	_status_label.text = "Ready!"

	await get_tree().create_timer(0.35).timeout
	SceneManager.goto_scene_with_loading(SceneManager.MENU_SCENE, "Entering Menu...")


func _apply_styles() -> void:
	_splash_card.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.CARD_WHITE, UITheme.CARD_BORDER, 28, 3, 36, 36)
	)
	_badge_panel.add_theme_stylebox_override(
		"panel",
		UITheme.make_panel_style(UITheme.BG_APRICOT, UITheme.CARD_BORDER, 64, 2, 16, 16)
	)
	_title_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_subtitle_label.add_theme_color_override("font_color", UITheme.ACCENT_CORAL)
	_status_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_version_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
