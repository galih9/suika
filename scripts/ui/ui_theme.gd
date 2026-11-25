class_name UITheme
extends RefCounted

## Shared tropical palette and StyleBoxFlat builders for consistent mobile-first UI.

const BG_CREAM := Color("#FFF8EE")
const BG_APRICOT := Color("#FDEBD0")
const CARD_WHITE := Color("#FFFFFF")
const CARD_BORDER := Color("#E8D5BC")
const PRIMARY_GREEN := Color("#2E7D32")
const PRIMARY_GREEN_HOVER := Color("#388E3C")
const PRIMARY_GREEN_PRESSED := Color("#1B5E20")
const SECONDARY_BEIGE := Color("#F5E6D3")
const SECONDARY_BEIGE_HOVER := Color("#ECD5BA")
const SECONDARY_BEIGE_PRESSED := Color("#DFC09E")
const ACCENT_CORAL := Color("#E65100")
const DANGER_RED := Color("#D32F2F")
const TEXT_DARK := Color("#3E2723")
const TEXT_MUTED := Color("#6D4C41")


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
	return sb


static func style_primary_button(btn: Button, radius: int = 18, font_size: int = 26) -> void:
	var normal := make_panel_style(PRIMARY_GREEN, PRIMARY_GREEN_PRESSED, radius, 2, 20, 14)
	var hover := make_panel_style(PRIMARY_GREEN_HOVER, PRIMARY_GREEN_PRESSED, radius, 2, 20, 14)
	var pressed := make_panel_style(PRIMARY_GREEN_PRESSED, PRIMARY_GREEN_PRESSED, radius, 2, 20, 14)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color("#E8F5E9"))
	btn.add_theme_font_size_override("font_size", font_size)


static func style_secondary_button(btn: Button, radius: int = 16, font_size: int = 20) -> void:
	var normal := make_panel_style(SECONDARY_BEIGE, CARD_BORDER, radius, 2, 16, 10)
	var hover := make_panel_style(SECONDARY_BEIGE_HOVER, CARD_BORDER, radius, 2, 16, 10)
	var pressed := make_panel_style(SECONDARY_BEIGE_PRESSED, CARD_BORDER, radius, 2, 16, 10)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", TEXT_DARK)
	btn.add_theme_font_size_override("font_size", font_size)


static func style_progress_bar(bar: ProgressBar) -> void:
	var bg := make_panel_style(SECONDARY_BEIGE, CARD_BORDER, 14, 2, 0, 0)
	var fill := make_panel_style(PRIMARY_GREEN, PRIMARY_GREEN, 12, 0, 0, 0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
