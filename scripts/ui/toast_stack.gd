class_name ToastStack
extends Control

## Little pop-down notifications ("New fruit discovered!", "New best!", ...).
## Toasts slide in from the top with a bounce, stack (max 3), and slide away on their own.
## Never blocks input.

const MAX_VISIBLE := 3
const HOLD_TIME := 2.4
const GAP := 12.0

@export var top_margin: float = 150.0

var _toasts: Array[Dictionary] = []   # {node, target_y, age, hold, leaving}
var _queue: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


## icon: any Texture2D (fruit sprite or pixel icon). accent tints the side stripe + title.
func show_toast(
	title: String,
	subtitle: String = "",
	icon: Texture2D = null,
	accent: Color = UITheme.GOLD,
	hold: float = HOLD_TIME,
	important: bool = false
) -> void:
	_queue.append({"title": title, "subtitle": subtitle, "icon": icon, "accent": accent, "hold": hold, "important": important})
	_try_show_next()


func clear() -> void:
	for t in _toasts:
		var raw: Variant = t["node"]
		if is_instance_valid(raw):
			(raw as Control).queue_free()
	_toasts.clear()
	_queue.clear()


func _try_show_next() -> void:
	while not _queue.is_empty() and _active_count() < MAX_VISIBLE:
		var data: Dictionary = _queue.pop_front()
		_spawn(data)


func _active_count() -> int:
	var n := 0
	for t in _toasts:
		if not bool(t["leaving"]):
			n += 1
	return n


func _spawn(data: Dictionary) -> void:
	var accent: Color = data["accent"]
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.make_card_style(UITheme.CARD_WHITE, accent.darkened(0.1), 28, 18, 10, 6)
	sb.border_width_left = 10
	sb.content_margin_left = 26
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon_tex: Texture2D = data["icon"]
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if icon_tex is ImageTexture:
			# Pixel icons are white: tint them with the accent colour.
			icon.modulate = accent.darkened(0.05)
		row.add_child(icon)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", -2)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	col.add_child(UITheme.make_label(String(data["title"]), 28, UITheme.TEXT_DARK, true))
	var sub := String(data["subtitle"])
	if not sub.is_empty():
		col.add_child(UITheme.make_label(sub, 20, UITheme.TEXT_MUTED))

	add_child(panel)
	# Size is known after one layout pass; start fully hidden above the screen.
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	panel.pivot_offset = sz * 0.5
	panel.position = Vector2((size.x - sz.x) * 0.5, -sz.y - 20.0)
	panel.scale = Vector2(0.8, 0.8)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_toasts.append({"node": panel, "age": 0.0, "hold": float(data["hold"]), "leaving": false})
	# Sound plays when the toast actually appears (not when it was queued).
	AudioManager.play_toast(bool(data.get("important", false)))


func _process(delta: float) -> void:
	if _toasts.is_empty():
		return
	var y := top_margin
	var i := 0
	while i < _toasts.size():
		var t := _toasts[i]
		# Check validity on the raw value first: assigning a freed object to a typed
		# variable is itself an error in Godot.
		var raw: Variant = t["node"]
		if not is_instance_valid(raw):
			_toasts.remove_at(i)
			continue
		var node := raw as Control
		t["age"] = float(t["age"]) + delta
		if not bool(t["leaving"]) and float(t["age"]) >= float(t["hold"]):
			t["leaving"] = true
			var tw := node.create_tween().set_parallel(true)
			tw.tween_property(node, "modulate:a", 0.0, 0.25)
			tw.tween_property(node, "scale", Vector2(0.9, 0.9), 0.25)
			tw.chain().tween_callback(node.queue_free)

		var target_x := (size.x - node.size.x) * 0.5
		var target_y := y if not bool(t["leaving"]) else node.position.y - 30.0
		node.position = Vector2(target_x, lerpf(node.position.y, target_y, minf(delta * 14.0, 1.0)))
		if not bool(t["leaving"]):
			y += node.size.y + GAP
		i += 1
	_try_show_next()
