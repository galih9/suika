class_name MergeResolver
extends RefCounted

## Deduplicates fruit merge contacts, performs a continuous physics-tick sweep so
## crowded/sleeping pairs never miss merges, and spawns upgraded fruits safely.

const MERGE_CONTACT_EPSILON := 1.5
## Extra slack allowed for contacts reported by the physics engine (it reports contacts
## slightly before the circles overlap). Anything farther apart than this is a stale contact.
const MAX_CONTACT_GAP := 6.0
const WAKE_RADIUS_PADDING := 96.0

var _pending_merges: Array[Array] = []
var _queued_ids: Dictionary = {}
var _flush_scheduled: bool = false


func reset() -> void:
	_pending_merges.clear()
	_queued_ids.clear()
	_flush_scheduled = false


func is_flush_scheduled() -> bool:
	return _flush_scheduled


func mark_flush_scheduled(scheduled: bool) -> void:
	_flush_scheduled = scheduled


func has_pending() -> bool:
	return not _pending_merges.is_empty()


func enqueue_contact(a: Fruit, b: Fruit) -> bool:
	if a == null or b == null or a == b:
		return false
	if a.in_pool or b.in_pool or a.is_merging or b.is_merging:
		return false
	if not a.is_dropped or not b.is_dropped:
		return false
	if a.is_concrete_crushing() or b.is_concrete_crushing():
		return false
	if a.level != b.level:
		return false
	# Only merge fruits that are really touching. Guards against stale/old physics contacts,
	# which used to merge a freshly dropped fruit with one far away (the "teleport" bug).
	if not are_touching(a, b):
		return false

	var id_a := a.get_instance_id()
	var id_b := b.get_instance_id()
	if _queued_ids.has(id_a) or _queued_ids.has(id_b):
		return false

	a.is_merging = true
	b.is_merging = true
	_queued_ids[id_a] = true
	_queued_ids[id_b] = true
	_pending_merges.append([a, b])
	return true


static func are_touching(a: Fruit, b: Fruit) -> bool:
	var reach := a.radius + b.radius + MAX_CONTACT_GAP
	return a.position.distance_squared_to(b.position) <= reach * reach


func scan_active_contacts(active_fruits: Array[Fruit]) -> bool:
	var queued_any := false
	var count := active_fruits.size()
	if count < 2:
		return false

	# Pass 1: Catch any active physics contacts reported on the body itself.
	for i in range(count):
		var fruit := active_fruits[i]
		if not _is_merge_eligible(fruit):
			continue
		for body in fruit.get_colliding_bodies():
			if body is Fruit:
				var other := body as Fruit
				if enqueue_contact(fruit, other):
					queued_any = true
					break

	# Pass 2: Catch touching/overlapping same-level pairs missed by sleeping or contact limits.
	for i in range(count - 1):
		var a := active_fruits[i]
		if not _is_merge_eligible(a):
			continue
		for j in range(i + 1, count):
			var b := active_fruits[j]
			if not _is_merge_eligible(b) or a.level != b.level:
				continue
			var touch_dist := a.radius + b.radius + MERGE_CONTACT_EPSILON
			if a.position.distance_squared_to(b.position) <= touch_dist * touch_dist:
				if enqueue_contact(a, b):
					queued_any = true
					break

	return queued_any


func process_queue(pool: FruitPool, jar: JarContainer, effects: MergeEffects) -> Dictionary:
	_flush_scheduled = false
	if _pending_merges.is_empty():
		return {"gained_score": 0, "unlocked_levels": [], "nuclear_blasts": [], "merges": []}

	var batch := _pending_merges.duplicate()
	_pending_merges.clear()
	_queued_ids.clear()

	var catalog := FruitRegistry.catalog
	var gained_total := 0
	var unlocked_levels: Array[int] = []
	var nuclear_blasts: Array[Dictionary] = []
	# One entry per merge for UI/FX: {"level", "position", "points", "is_max_bonus"}.
	var merges: Array[Dictionary] = []

	for pair in batch:
		if pair.size() != 2:
			continue
		var a := pair[0] as Fruit
		var b := pair[1] as Fruit
		if a == null or b == null or a.in_pool or b.in_pool:
			continue

		var merged_level := a.level
		var midpoint := (a.position + b.position) * 0.5
		var avg_vel := (a.linear_velocity + b.linear_velocity) * 0.25
		var parent_was_below := a.has_been_below_danger_line or b.has_been_below_danger_line
		var trigger_nuclear := (
			a.fruit_property == FruitProperty.Type.NUCLEAR
			or b.fruit_property == FruitProperty.Type.NUCLEAR
		)

		pool.release(a)
		pool.release(b)

		var wake_radius := WAKE_RADIUS_PADDING
		var spawned_fruit: Fruit = null
		var blast_center := midpoint
		var blast_base_radius := 40.0
		if catalog.has_next_level(merged_level):
			var next_lvl := merged_level + 1
			var next_def := catalog.get_fruit(next_lvl)
			var clamped_pos := jar.clamp_merge_position(midpoint, next_def.radius)

			var merged_fruit := pool.acquire()
			merged_fruit.configure(
				next_def,
				catalog.get_shape(next_lvl),
				FruitRegistry.textures.get_texture(next_lvl),
				catalog.get_physics_material(),
				FruitRegistry.textures.get_sprite_scale(next_lvl),
				FruitProperty.Type.NONE
			)
			merged_fruit.activate(clamped_pos, avg_vel, true, JarContainer.DANGER_LINE_Y, parent_was_below)
			spawned_fruit = merged_fruit
			blast_center = clamped_pos
			blast_base_radius = next_def.radius

			gained_total += next_def.score
			unlocked_levels.append(next_lvl)
			wake_radius += next_def.radius
			merges.append({
				"level": next_lvl,
				"position": clamped_pos,
				"points": next_def.score,
				"is_max_bonus": false,
			})
			AudioManager.play_merge(next_lvl)
			if effects != null:
				effects.spawn_merge_burst(
					clamped_pos,
					next_def.radius,
					next_def.primary_color,
					false,
					next_lvl,
					FruitRegistry.textures.get_palette(next_lvl)
				)
		else:
			# Two max-level fruits (e.g. Watermelon + Watermelon) merge into a bonus burst.
			var max_def := catalog.get_fruit(merged_level)
			var bonus := catalog.get_max_merge_bonus(merged_level)
			var burst_radius := max_def.radius if max_def != null else 128.0
			blast_base_radius = burst_radius
			gained_total += bonus
			wake_radius += burst_radius
			merges.append({
				"level": merged_level,
				"position": midpoint,
				"points": bonus,
				"is_max_bonus": true,
			})
			AudioManager.play_merge(merged_level + 1)
			if effects != null:
				effects.spawn_merge_burst(
					midpoint,
					burst_radius,
					max_def.primary_color if max_def != null else Color.GOLD,
					true,
					merged_level,
					FruitRegistry.textures.get_palette(merged_level)
				)

		if trigger_nuclear:
			nuclear_blasts.append({
				"center": blast_center,
				"base_radius": blast_base_radius,
				"exempt": spawned_fruit,
			})

		_wake_nearby_fruits(pool.active_fruits, midpoint, wake_radius)

	return {
		"gained_score": gained_total,
		"unlocked_levels": unlocked_levels,
		"nuclear_blasts": nuclear_blasts,
		"merges": merges,
	}


func _is_merge_eligible(fruit: Fruit) -> bool:
	return (
		fruit != null
		and not fruit.in_pool
		and not fruit.is_merging
		and fruit.is_dropped
		and not fruit.is_concrete_crushing()
	)


func _wake_nearby_fruits(active_fruits: Array[Fruit], center: Vector2, radius: float) -> void:
	var radius_sq := radius * radius
	for fruit in active_fruits:
		if fruit == null or fruit.in_pool or fruit.is_merging:
			continue
		if fruit.position.distance_squared_to(center) <= radius_sq:
			fruit.sleeping = false
