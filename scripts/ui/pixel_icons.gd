class_name PixelIcons
extends RefCounted

## Tiny 12x12 pixel-art UI icons generated at runtime (no image import needed).
## They are white, so tint them with `modulate`. Draw them with nearest filtering to keep
## them crisp — `make_rect()` sets that up for you.

const SIZE := 12

const MAPS := {
	"pause": [
		"............",
		"............",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"............",
		"............",
	],
	"play": [
		"............",
		"...XX.......",
		"...XXXX.....",
		"...XXXXXX...",
		"...XXXXXXXX.",
		"...XXXXXXXXX",
		"...XXXXXXXXX",
		"...XXXXXXXX.",
		"...XXXXXX...",
		"...XXXX.....",
		"...XX.......",
		"............",
	],
	"restart": [
		"............",
		"....XXXX.XX.",
		"..XXXXXXXXX.",
		"..XXX...XXX.",
		".XXX...XXXX.",
		".XX.........",
		".XX.........",
		".XXX.....XX.",
		"..XXX...XXX.",
		"..XXXXXXXX..",
		"....XXXXX...",
		"............",
	],
	"home": [
		"............",
		".....XX.....",
		"....XXXX....",
		"...XXXXXX...",
		"..XXXXXXXX..",
		".XXXXXXXXXX.",
		"..XXXXXXXX..",
		"..XXXXXXXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"............",
	],
	"sound": [
		"............",
		".....X......",
		"....XX...X..",
		"...XXX....X.",
		"XXXXXX..X..X",
		"XXXXXX...X.X",
		"XXXXXX...X.X",
		"XXXXXX..X..X",
		"...XXX....X.",
		"....XX...X..",
		".....X......",
		"............",
	],
	"mute": [
		"............",
		".....X......",
		"....XX......",
		"...XXX......",
		"XXXXXX.X...X",
		"XXXXXX..X.X.",
		"XXXXXX...X..",
		"XXXXXX..X.X.",
		"...XXX.X...X",
		"....XX......",
		".....X......",
		"............",
	],
	"bolt": [
		"............",
		"......XXXX..",
		".....XXXX...",
		"....XXXX....",
		"...XXXX.....",
		"..XXXXXXXX..",
		"..XXXXXXX...",
		".....XXX....",
		"....XXX.....",
		"...XXX......",
		"..XX........",
		"..X.........",
	],
	"star": [
		"............",
		".....XX.....",
		".....XX.....",
		"....XXXX....",
		"XXXXXXXXXXXX",
		".XXXXXXXXXX.",
		"..XXXXXXXX..",
		"...XXXXXX...",
		"..XXXXXXXX..",
		"..XXX..XXX..",
		".XX......XX.",
		"............",
	],
	"crown": [
		"............",
		"............",
		"X....XX....X",
		"XX..XXXX..XX",
		"XXX.XXXX.XXX",
		"XXXXXXXXXXXX",
		"XXXXXXXXXXXX",
		"XXXXXXXXXXXX",
		".XXXXXXXXXX.",
		"............",
		".XXXXXXXXXX.",
		"............",
	],
	"lock": [
		"............",
		"....XXXX....",
		"...XX..XX...",
		"...X....X...",
		"...X....X...",
		"..XXXXXXXX..",
		"..XXXXXXXX..",
		"..XXX..XXX..",
		"..XXX..XXX..",
		"..XXXXXXXX..",
		"..XXXXXXXX..",
		"............",
	],
	"question": [
		"............",
		"...XXXXXX...",
		"..XXXXXXXX..",
		"..XXX..XXX..",
		".......XXX..",
		"......XXX...",
		".....XXX....",
		".....XXX....",
		"............",
		".....XXX....",
		".....XXX....",
		"............",
	],
	"close": [
		"............",
		".XX......XX.",
		".XXX....XXX.",
		"..XXX..XXX..",
		"...XXXXXX...",
		"....XXXX....",
		"....XXXX....",
		"...XXXXXX...",
		"..XXX..XXX..",
		".XXX....XXX.",
		".XX......XX.",
		"............",
	],
	"sparkle": [
		"............",
		".....XX.....",
		".....XX.....",
		".....XX.....",
		"....XXXX....",
		"XXXXXXXXXXXX",
		"XXXXXXXXXXXX",
		"....XXXX....",
		".....XX.....",
		".....XX.....",
		".....XX.....",
		"............",
	],
	"fire": [
		"............",
		".....X......",
		".....XX.....",
		"....XXX..X..",
		"...XXXXX.X..",
		"..XXXXXXXX..",
		"..XXXX.XXXX.",
		".XXXX...XXX.",
		".XXX.....XX.",
		".XXX.....XX.",
		"..XXX...XX..",
		"...XXXXXX...",
	],
	"globe": [
		"....XXXX....",
		"..XX.XX.XX..",
		".X..X..X..X.",
		".X..X..X..X.",
		"XXXXXXXXXXXX",
		"X...X..X...X",
		"X...X..X...X",
		"XXXXXXXXXXXX",
		".X..X..X..X.",
		".X..X..X..X.",
		"..XX.XX.XX..",
		"....XXXX....",
	],
}

static var _cache: Dictionary = {}


static func has_icon(icon_name: String) -> bool:
	return MAPS.has(icon_name)


static func get_icon(icon_name: String) -> Texture2D:
	if _cache.has(icon_name):
		return _cache[icon_name]
	if not MAPS.has(icon_name):
		return null
	var rows: Array = MAPS[icon_name]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(mini(rows.size(), SIZE)):
		var row := String(rows[y])
		for x in range(mini(row.length(), SIZE)):
			if row[x] == "X":
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_cache[icon_name] = tex
	return tex


## A crisp TextureRect showing the icon at `px` x `px`, tinted with `tint`.
static func make_rect(icon_name: String, px: float = 36.0, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = get_icon(icon_name)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = tint
	return rect
