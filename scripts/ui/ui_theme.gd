class_name UITheme
extends RefCounted

## Shared casual "sunny sky" palette, chunky button styles, fonts and small UI helpers.
## Every screen calls `UITheme.apply_to(root)` once, then uses the style_* helpers.

# --- Palette -----------------------------------------------------------------------------
const SKY_TOP := Color("#7FD3FF")
const SKY_BOTTOM := Color("#CFF6E4")
const CARD_WHITE := Color("#FFFFFF")
const CARD_SHADOW := Color("#A9D4E6")
const CARD_BORDER := Color("#E3EEF3")
const CREAM := Color("#FFF8EC")

const TEXT_DARK := Color("#2F3B5C")
const TEXT_MUTED := Color("#7483A6")
const OUTLINE_DARK := Color("#2F3B5C")

const GREEN := Color("#69D25A")
const GREEN_SHADOW := Color("#3E9F35")
const PINK := Color("#FF6FA0")
const PINK_SHADOW := Color("#D4467A")
const ORANGE := Color("#FFA43A")
const ORANGE_SHADOW := Color("#DC7A12")
const BLUE := Color("#53B6F5")
const BLUE_SHADOW := Color("#2E86C8")
const GOLD := Color("#FFCC33")
const GOLD_SHADOW := Color("#E09A10")
const DANGER_RED := Color("#FF5468")
const DANGER_SHADOW := Color("#C92F45")

# Legacy names (kept so older scripts still compile).
const BG_CREAM := CREAM
const BG_APRICOT := Color("#FFE9C7")
const PRIMARY_GREEN := GREEN
const PRIMARY_GREEN_HOVER := Color("#7BDC6C")
const PRIMARY_GREEN_PRESSED := GREEN_SHADOW
const SECONDARY_BEIGE := CARD_WHITE
const SECONDARY_BEIGE_HOVER := Color("#F3FAFD")
const SECONDARY_BEIGE_PRESSED := Color("#E6F3F8")
const ACCENT_CORAL := PINK
const ACCENT_CORAL_HOVER := Color("#FF86B0")
const ACCENT_CORAL_PRESSED := PINK_SHADOW

const FONT_MEDIUM_PATH := "res://assets/fonts/Fredoka-Medium.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/Fredoka-Bold.ttf"

const ICON_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 silhouette_color : source_color = vec4(0.18, 0.23, 0.36, 0.28);
uniform float silhouette : hint_range(0.0, 1.0) = 0.0;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(c.rgb, vec3(l), gray);
	col = mix(col, silhouette_color.rgb, silhouette);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, c.a * mix(1.0, silhouette_color.a, silhouette)) * COLOR;
}
"""

static var _font_medium: Font
static var _font_bold: Font
static var _theme: Theme
static var _icon_shader: Shader


# --- Fonts & theme -------------------------------------------------------------------------

static func get_font(bold: bool = false) -> Font:
	if bold:
		if _font_bold == null:
			_font_bold = _load_font(FONT_BOLD_PATH, true)
		return _font_bold
	if _font_medium == null:
		_font_medium = _load_font(FONT_MEDIUM_PATH, false)
	return _font_medium


static func _load_font(path: String, bold: bool = false) -> Font:
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path) as Font
	if font == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			font = ff
	if font == null:
		font = ThemeDB.fallback_font
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray([
		"Hiragino Maru Gothic ProN",
		"Rounded Mplus 1c",
		"Hiragino Sans",
		"Yu Gothic UI",
		"Meiryo",
		"Noto Sans CJK JP",
		"Noto Sans JP",
		"Noto Sans",
		"Segoe UI",
		"Roboto",
		"DejaVu Sans",
		"Arial",
		"sans-serif",
	])
	fallback.font_weight = 700 if bold else 500
	var fv := FontVariation.new()
	fv.base_font = font
	fv.fallbacks = [fallback]
	return fv


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = get_font(false)
	t.default_font_size = 24

	t.set_color("font_color", "Label", TEXT_DARK)
	t.set_color("font_outline_color", "Label", OUTLINE_DARK)

	var normal := make_chunky_style(CARD_WHITE, CARD_SHADOW, 24, false)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", make_chunky_style(Color("#F5FBFE"), CARD_SHADOW, 24, false))
	t.set_stylebox("pressed", "Button", make_chunky_style(Color("#EAF5FA"), CARD_SHADOW, 24, true))
	t.set_stylebox("disabled", "Button", make_chunky_style(Color("#EEF2F5"), Color("#CBD5DC"), 24, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT_DARK)
	t.set_color("font_hover_color", "Button", TEXT_DARK)
	t.set_color("font_pressed_color", "Button", TEXT_DARK)
	t.set_color("font_focus_color", "Button", TEXT_DARK)
	t.set_font("font", "Button", get_font(true))
	t.set_font_size("font_size", "Button", 26)

	t.set_stylebox("panel", "PanelContainer", make_card_style())
	_theme = t
	return t


## Applies the shared theme and smooth text filtering to a scene root.
## Fruit sprites/icons explicitly opt back into nearest filtering so pixel art stays crisp.
static func apply_to(root: Control) -> void:
	root.theme = get_theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


# --- StyleBoxes ----------------------------------------------------------------------------

static func make_panel_style(
	bg_color: Color = CARD_WHITE,
	border_color: Color = CARD_BORDER,
	radius: int = 20,
	border_width: int = 2,
	pad_x: int = 18,
	pad_y: int = 14
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.anti_aliasing = true
	return sb


## Soft white card with a coloured "lip" at the bottom — the main casual panel look.
static func make_card_style(
	bg_color: Color = CARD_WHITE,
	shadow_color: Color = CARD_SHADOW,
	radius: int = 30,
	pad_x: int = 22,
	pad_y: int = 18,
	lip: int = 7
) -> StyleBoxFlat:
	var sb := make_panel_style(bg_color, shadow_color, radius, 0, pad_x, pad_y)
	sb.border_width_bottom = lip
	sb.content_margin_bottom = pad_y + lip
	return sb


## Chunky "3D" button face: a thick darker bottom border that shrinks when pressed.
static func make_chunky_style(face: Color, shadow: Color, radius: int = 24, pressed: bool = false, pad_x: int = 22, pad_y: int = 12) -> StyleBoxFlat:
	var lip := 3 if pressed else 9
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = shadow
	sb.border_width_bottom = lip
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	# Keep the label in the same spot relative to the face so it "sinks" with the press.
	sb.content_margin_top = pad_y + (9 - lip)
	sb.content_margin_bottom = pad_y + lip
	sb.anti_aliasing = true
	return sb


static func style_chunky_button(
	btn: Button,
	face: Color,
	shadow: Color,
	text_color: Color = Color.WHITE,
	font_size: int = 30,
	radius: int = 26,
	text_outline: bool = true
) -> void:
	btn.add_theme_stylebox_override("normal", make_chunky_style(face, shadow, radius, false))
	btn.add_theme_stylebox_override("hover", make_chunky_style(face.lightened(0.08), shadow, radius, false))
	btn.add_theme_stylebox_override("pressed", make_chunky_style(face.darkened(0.06), shadow, radius, true))
	btn.add_theme_stylebox_override("disabled", make_chunky_style(face.lerp(Color("#C9D2D8"), 0.6), shadow.lerp(Color("#9AA6AE"), 0.6), radius, false))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(key, text_color)
	btn.add_theme_font_override("font", get_font(true))
	btn.add_theme_font_size_override("font_size", font_size)
	if text_outline and text_color.get_luminance() > 0.6:
		btn.add_theme_color_override("font_outline_color", shadow.darkened(0.15))
		btn.add_theme_constant_override("outline_size", 8)
	add_press_juice(btn)


static func style_primary_button(btn: Button, radius: int = 26, font_size: int = 30) -> void:
	style_chunky_button(btn, GREEN, GREEN_SHADOW, Color.WHITE, font_size, radius)


static func style_accent_button(btn: Button, radius: int = 26, font_size: int = 30) -> void:
	style_chunky_button(btn, PINK, PINK_SHADOW, Color.WHITE, font_size, radius)


static func style_orange_button(btn: Button, radius: int = 26, font_size: int = 30) -> void:
	style_chunky_button(btn, ORANGE, ORANGE_SHADOW, Color.WHITE, font_size, radius)


static func style_blue_button(btn: Button, radius: int = 26, font_size: int = 30) -> void:
	style_chunky_button(btn, BLUE, BLUE_SHADOW, Color.WHITE, font_size, radius)


static func style_secondary_button(btn: Button, radius: int = 24, font_size: int = 26) -> void:
	style_chunky_button(btn, CARD_WHITE, CARD_SHADOW, TEXT_DARK, font_size, radius, false)


## Squishy press feedback for any button (scale down on press, springy release).
static func add_press_juice(btn: Button) -> void:
	if btn.has_meta(&"press_juice"):
		return
	btn.set_meta(&"press_juice", true)
	var center_pivot := func() -> void:
		btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(center_pivot)
	center_pivot.call()
	btn.button_down.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	)


## Puts a pixel icon in the middle of a (usually text-less) button.
static func set_button_icon(btn: Button, icon_name: String, px: float = 36.0, tint: Color = Color.WHITE) -> TextureRect:
	for child in btn.get_children():
		if child.has_meta(&"pixel_icon"):
			child.queue_free()
	var rect := PixelIcons.make_rect(icon_name, px, tint)
	rect.set_meta(&"pixel_icon", true)
	rect.set_anchors_preset(Control.PRESET_CENTER)
	rect.offset_left = -px * 0.5
	rect.offset_right = px * 0.5
	# Nudge up a bit to sit on the button face, not the bottom lip.
	rect.offset_top = -px * 0.5 - 4.0
	rect.offset_bottom = px * 0.5 - 4.0
	btn.add_child(rect)
	return rect


## Icon + text centred on a button (keeps text smooth and the pixel icon crisp).
static func set_button_content(
	btn: Button,
	icon_name: String,
	text: String,
	font_size: int = 30,
	color: Color = Color.WHITE,
	outline_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	icon_px: float = 34.0
) -> Label:
	btn.text = ""
	for child in btn.get_children():
		if child.has_meta(&"button_content") or child.has_meta(&"pixel_icon"):
			child.queue_free()
	var box := HBoxContainer.new()
	box.set_meta(&"button_content", true)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -8.0
	if not icon_name.is_empty():
		var icon := PixelIcons.make_rect(icon_name, icon_px, color)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
	var lbl := make_label(text, font_size, color, true, 8 if outline_color.a > 0.0 else 0, outline_color)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(lbl)
	btn.add_child(box)
	return lbl


## Texture + text centred on a button (for flag icons or custom textures).
static func set_button_texture_content(
	btn: Button,
	tex: Texture2D,
	text: String,
	font_size: int = 26,
	color: Color = TEXT_DARK,
	outline_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	icon_size: Vector2 = Vector2(36.0, 24.0),
	nearest: bool = false
) -> Label:
	btn.text = ""
	for child in btn.get_children():
		if child.has_meta(&"button_content") or child.has_meta(&"pixel_icon"):
			child.queue_free()
	var box := HBoxContainer.new()
	box.set_meta(&"button_content", true)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -8.0
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
	var lbl := make_label(text, font_size, color, true, 8 if outline_color.a > 0.0 else 0, outline_color)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(lbl)
	btn.add_child(box)
	return lbl


static func make_icon_button(icon_name: String, face: Color = CARD_WHITE, shadow: Color = CARD_SHADOW, tint: Color = TEXT_DARK, side: float = 76.0, icon_px: float = 36.0) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(side, side)
	btn.focus_mode = Control.FOCUS_NONE
	style_chunky_button(btn, face, shadow, tint, 20, int(side * 0.38), false)
	set_button_icon(btn, icon_name, icon_px, tint)
	return btn


# --- Labels ----------------------------------------------------------------------------------

static func style_label(
	lbl: Label,
	font_size: int = 24,
	color: Color = TEXT_DARK,
	bold: bool = false,
	outline_size: int = 0,
	outline_color: Color = OUTLINE_DARK
) -> void:
	lbl.add_theme_font_override("font", get_font(bold))
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if outline_size > 0:
		lbl.add_theme_constant_override("outline_size", outline_size)
		lbl.add_theme_color_override("font_outline_color", outline_color)


static func make_label(text: String, font_size: int = 24, color: Color = TEXT_DARK, bold: bool = false, outline_size: int = 0, outline_color: Color = OUTLINE_DARK) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(lbl, font_size, color, bold, outline_size, outline_color)
	return lbl


# --- Fruit icons -----------------------------------------------------------------------------

static func get_icon_shader() -> Shader:
	if _icon_shader == null:
		_icon_shader = Shader.new()
		_icon_shader.code = ICON_SHADER_CODE
	return _icon_shader


## Per-icon material supporting silhouette (undiscovered), gray (not made this run) and flash.
static func make_icon_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = get_icon_shader()
	return mat


static func make_fruit_icon(level: int, px: float = 48.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = FruitRegistry.textures.get_texture(level)
	icon.custom_minimum_size = Vector2(px, px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


# --- Misc ------------------------------------------------------------------------------------

static func format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if negative else out


## "Cherry" -> "Cherries", "Peach" -> "Peaches", "Kiwi" -> "Kiwis".
static func pluralize(word: String) -> String:
	if word.is_empty():
		return word
	var lower := word.to_lower()
	if lower.ends_with("ch") or lower.ends_with("sh") or lower.ends_with("s") or lower.ends_with("x"):
		return word + "es"
	if lower.ends_with("y") and lower.length() > 1 and not "aeiou".contains(lower[lower.length() - 2]):
		return word.substr(0, word.length() - 1) + "ies"
	return word + "s"


## Top safe-area inset (notches / status bars) in viewport units. 0 on desktop.
static func get_safe_top(vp: Viewport) -> float:
	if vp == null or not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return 0.0
	var scale := vp.get_visible_rect().size.y / float(screen.y)
	return maxf(float(safe.position.y) * scale, 0.0)


static func get_safe_bottom(vp: Viewport) -> float:
	if vp == null or not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return 0.0
	var scale := vp.get_visible_rect().size.y / float(screen.y)
	var bottom_gap := float(screen.y - (safe.position.y + safe.size.y))
	return maxf(bottom_gap * scale, 0.0)
