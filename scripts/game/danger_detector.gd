class_name DangerDetector
extends Node2D

## Detects game-over ONLY when a fruit crosses from bottom to top across the danger line
## (or settles stationary on top of an overflowing pile) — never on mere proximity or downward drops.

signal danger_state_changed(is_triggered: bool, progress: float)
signal game_over_triggered()

@export var line_y: float = 160.0
@export var half_width: float = 280.0
@export var grace_duration: float = 2.0
@export var settled_overflow_delay: float = 0.6

var is_triggered: bool = false
var danger_timer: float = 0.0
var game_over_emitted: bool = false

var _glow_alpha: float = 0.0
var _pulse_time: float = 0.0
var _last_emitted_progress: float = -1.0


func reset() -> void:
	is_triggered = false
	danger_timer = 0.0
	game_over_emitted = false
	_glow_alpha = 0.0
	_pulse_time = 0.0
	_last_emitted_progress = -1.0
	queue_redraw()


func get_progress() -> float:
	if grace_duration <= 0.0:
		return 0.0
	return clampf(danger_timer / grace_duration, 0.0, 1.0)


func evaluate(active_fruits: Array[Fruit], delta: float) -> void:
	var any_breaching := false

	for fruit in active_fruits:
		if fruit.in_pool or fruit.is_merging or not fruit.is_dropped:
			continue

		var top_y := fruit.position.y - fruit.radius
		var center_y := fruit.position.y

		if top_y >= line_y:
			# Strictly below the danger line: safe regardless of proximity.
			fruit.has_been_below_danger_line = true
			fruit.is_breaching_from_below = false
			fruit.settled_above_line_time = 0.0
		else:
			if fruit.has_been_below_danger_line:
				# Crossed from bottom to top!
				fruit.is_breaching_from_below = true
			else:
				# Newly dropped fruit descending top -> bottom.
				if center_y >= line_y and fruit.linear_velocity.y < -15.0:
					# Entered partway and bounced back upward.
					fruit.has_been_below_danger_line = true
					fruit.is_breaching_from_below = true
				elif fruit.has_collided and fruit.linear_velocity.length_squared() < 400.0:
					# Soft-lock guard: fruit came to rest perched above the line on an overflowing stack.
					fruit.settled_above_line_time += delta
					if fruit.settled_above_line_time >= settled_overflow_delay:
						fruit.is_breaching_from_below = true
				else:
					# Falling downward top -> bottom: do NOT glow or trigger.
					fruit.is_breaching_from_below = false

			if fruit.is_breaching_from_below:
				any_breaching = true

		fruit.prev_top_y = top_y

	var prev_triggered := is_triggered
	if any_breaching:
		is_triggered = true
		danger_timer = minf(danger_timer + delta, grace_duration)
		if danger_timer >= grace_duration and not game_over_emitted:
			game_over_emitted = true
			game_over_triggered.emit()
	else:
		is_triggered = false
		danger_timer = maxf(danger_timer - delta * 2.5, 0.0)

	var target_glow := 1.0 if is_triggered else 0.0
	_glow_alpha = move_toward(_glow_alpha, target_glow, delta * 6.0)
	if _glow_alpha > 0.001:
		_pulse_time += delta

	if is_triggered or _glow_alpha > 0.001 or prev_triggered != is_triggered:
		queue_redraw()

	var progress := get_progress()
	if prev_triggered != is_triggered or absf(progress - _last_emitted_progress) >= 0.015:
		_last_emitted_progress = progress
		danger_state_changed.emit(is_triggered, progress)


func _draw() -> void:
	var left := -half_width
	var right := half_width

	# Calm dashed reference line
	var dash_len := 16.0
	var gap_len := 12.0
	var base_color := Color(1.0, 0.42, 0.55, 0.45)
	var x := left
	while x < right:
		# Pixel-style dashes (4px tall blocks) to match the fruit sprites.
		var seg_end := minf(x + dash_len, right)
		draw_rect(Rect2(x, line_y - 2.0, seg_end - x, 4.0), base_color)
		x += dash_len + gap_len

	# Glow + countdown bar appear ONLY when breaching from bottom to top
	if _glow_alpha > 0.01:
		var pulse := 0.72 + 0.28 * sin(_pulse_time * 10.0)
		var alpha := _glow_alpha * pulse
		draw_line(
			Vector2(left, line_y),
			Vector2(right, line_y),
			Color(1.0, 0.28, 0.15, 0.18 * alpha),
			24.0,
			true
		)
		draw_line(
			Vector2(left, line_y),
			Vector2(right, line_y),
			Color(1.0, 0.22, 0.12, 0.36 * alpha),
			11.0,
			true
		)
		draw_line(
			Vector2(left, line_y),
			Vector2(right, line_y),
			Color(1.0, 0.15, 0.10, 0.92 * alpha),
			3.5,
			true
		)

		var prog := get_progress()
		if prog > 0.005:
			var fill_right := lerpf(left, right, prog)
			draw_line(
				Vector2(left, line_y + 5.0),
				Vector2(fill_right, line_y + 5.0),
				Color(0.95, 0.14, 0.14, 0.95 * _glow_alpha),
				4.5,
				true
			)
