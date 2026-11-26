class_name FlagIcons
extends RefCounted

## Simple procedural 90x60 rounded flag icons generated at runtime (no image import needed).
## Cached as ImageTextures, mirroring PixelIcons.

const FLAG_W := 90
const FLAG_H := 60
const CORNER_RADIUS := 8.0

const SUPPORTED_FLAGS: Array[String] = ["en", "id", "ru", "ja", "sk", "cs", "pl", "ms"]

const RED_BRIGHT := Color("#E53935")
const RED_CRIMSON := Color("#DC2626")
const BLUE_ROYAL := Color("#1D4ED8")
const BLUE_MID := Color("#2563EB")
const BLUE_NAVY := Color("#1E3A8A")
const GOLD := Color("#FACC15")
const BORDER_COLOR := Color(0.18, 0.23, 0.36, 0.18)

static var _cache: Dictionary = {}


static func has_flag(code: String) -> bool:
	return SUPPORTED_FLAGS.has(code)


static func get_flag(code: String) -> Texture2D:
	if _cache.has(code):
		return _cache[code]
	var img := Image.create(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	_paint_flag(img, code)
	_apply_rounded_border(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[code] = tex
	return tex


static func make_rect(code: String, width: float = 54.0, height: float = 36.0) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = get_flag(code)
	rect.custom_minimum_size = Vector2(width, height)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _paint_flag(img: Image, code: String) -> void:
	var w := float(FLAG_W)
	var h := float(FLAG_H)
	var half_h := h * 0.5
	var third_h := h / 3.0
	var two_third_h := h * 2.0 / 3.0

	match code:
		"id":
			for y in range(FLAG_H):
				var col := RED_BRIGHT if float(y) < half_h else Color.WHITE
				for x in range(FLAG_W):
					img.set_pixel(x, y, col)
		"pl":
			for y in range(FLAG_H):
				var col := Color.WHITE if float(y) < half_h else RED_CRIMSON
				for x in range(FLAG_W):
					img.set_pixel(x, y, col)
		"ru":
			for y in range(FLAG_H):
				var col := Color.WHITE
				if float(y) >= two_third_h:
					col = RED_BRIGHT
				elif float(y) >= third_h:
					col = BLUE_MID
				for x in range(FLAG_W):
					img.set_pixel(x, y, col)
		"ja":
			var cx := (w - 1.0) * 0.5
			var cy := (h - 1.0) * 0.5
			var r := 0.30 * h
			for y in range(FLAG_H):
				for x in range(FLAG_W):
					var d := Vector2(float(x) - cx, float(y) - cy).length()
					var t := clampf(r + 0.6 - d, 0.0, 1.0)
					img.set_pixel(x, y, Color.WHITE.lerp(RED_CRIMSON, t))
		"cs":
			var cy := (h - 1.0) * 0.5
			for y in range(FLAG_H):
				var tri_x := (w * 0.5) * (1.0 - absf(float(y) - cy) / cy)
				var base := Color.WHITE if float(y) < half_h else RED_CRIMSON
				for x in range(FLAG_W):
					var col := BLUE_ROYAL if float(x) <= tri_x else base
					img.set_pixel(x, y, col)
		"en":
			var cx := (w - 1.0) * 0.5
			var cy := (h - 1.0) * 0.5
			var diag_norm := sqrt(w * w + h * h)
			for y in range(FLAG_H):
				for x in range(FLAG_W):
					var fx := float(x)
					var fy := float(y)
					var col := BLUE_NAVY
					var d1 := absf(fy * w - fx * h) / diag_norm
					var d2 := absf((h - 1.0 - fy) * w - fx * h) / diag_norm
					var diag_d := minf(d1, d2)
					if diag_d <= 2.5:
						col = RED_CRIMSON
					elif diag_d <= 5.5:
						col = Color.WHITE
					var dx := absf(fx - cx)
					var dy := absf(fy - cy)
					if dx <= 5.0 or dy <= 5.0:
						col = RED_CRIMSON
					elif dx <= 8.0 or dy <= 8.0:
						col = Color.WHITE
					img.set_pixel(x, y, col)
		"sk":
			var sx := 0.30 * w
			var top_y := 15.0
			var shield_h := 30.0
			var split_y := 16.0
			var max_hw := 11.0
			for y in range(FLAG_H):
				var fy := float(y)
				var bg := Color.WHITE
				if fy >= two_third_h:
					bg = RED_BRIGHT
				elif fy >= third_h:
					bg = BLUE_MID
				for x in range(FLAG_W):
					var fx := float(x)
					var col := bg
					var sdy := fy - top_y
					if sdy >= 0.0 and sdy <= shield_h:
						var outer_hw := max_hw
						if sdy > split_y:
							var tt := (sdy - split_y) / (shield_h - split_y)
							outer_hw = max_hw * sqrt(maxf(0.0, 1.0 - tt * tt))
						if absf(fx - sx) <= outer_hw:
							col = Color.WHITE
							var inner_hw := outer_hw - 2.0
							if sdy >= 2.0 and sdy <= shield_h - 2.0 and absf(fx - sx) <= inner_hw:
								col = RED_BRIGHT
								var mound_y := 22.8 - 2.2 * maxf(0.0, 1.0 - absf(fx - sx) * 0.22)
								if sdy >= mound_y:
									col = BLUE_MID
								var on_stem := absf(fx - sx) <= 1.2 and sdy >= 5.0 and sdy <= 23.0
								var on_top_bar := absf(sdy - 9.0) <= 1.1 and absf(fx - sx) <= 3.8
								var on_bot_bar := absf(sdy - 14.5) <= 1.1 and absf(fx - sx) <= 5.2
								if on_stem or on_top_bar or on_bot_bar:
									col = Color.WHITE
					img.set_pixel(x, y, col)
		"ms":
			var canton_w := 0.52 * w
			var canton_h := 0.55 * h
			var c_outer := Vector2(0.20 * w, 0.275 * h)
			var c_inner := Vector2(0.238 * w, 0.275 * h)
			var r_outer := 0.175 * h
			var r_inner := 0.142 * h
			var star_c := Vector2(0.37 * w, 0.275 * h)
			for y in range(FLAG_H):
				var fy := float(y)
				var stripe_idx := int(floorf(fy * 10.0 / h))
				var stripe_col := RED_CRIMSON if (stripe_idx % 2 == 0) else Color.WHITE
				for x in range(FLAG_W):
					var fx := float(x)
					var col := stripe_col
					if fx < canton_w and fy < canton_h:
						col = BLUE_NAVY
						var p := Vector2(fx, fy)
						var in_crescent := p.distance_to(c_outer) <= r_outer and p.distance_to(c_inner) > r_inner
						var sd := p - star_c
						var s_dist := sd.length()
						var s_angle := atan2(sd.y, sd.x)
						var star_r := lerpf(0.045 * h, 0.11 * h, 0.5 + 0.5 * cos(s_angle * 7.0))
						var in_star := s_dist <= star_r
						if in_crescent or in_star:
							col = GOLD
					img.set_pixel(x, y, col)
		_:
			img.fill(Color("#CFD8DC"))


static func _apply_rounded_border(img: Image) -> void:
	var half_w := float(FLAG_W) * 0.5
	var half_h := float(FLAG_H) * 0.5
	var r := CORNER_RADIUS
	var inner_box := Vector2(half_w - r, half_h - r)

	for y in range(FLAG_H):
		for x in range(FLAG_W):
			var p := Vector2(float(x) + 0.5 - half_w, float(y) + 0.5 - half_h)
			var q := Vector2(absf(p.x), absf(p.y)) - inner_box
			var dist := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
			if dist > 0.5:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var col := img.get_pixel(x, y)
			if dist > -2.0:
				col = col.lerp(Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 1.0), BORDER_COLOR.a)
			var alpha := clampf(0.5 - dist, 0.0, 1.0)
			col.a *= alpha
			img.set_pixel(x, y, col)
