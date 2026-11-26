class_name GameBoard
extends Node2D

## Main Suika playfield coordinator wiring the jar, dropper, fruit pool, merge resolver, and danger detector.

signal score_changed(score: int, best_score: int, delta_points: int)
signal next_fruit_changed(next_level: int, next_property: int)
signal fruit_unlocked(level: int)
## Same as fruit_unlocked, plus where (board-local) the new fruit appeared. Used for UI fly-ins.
signal fruit_unlocked_at(level: int, local_pos: Vector2)
## Emitted for every merge. level = the new fruit's level (or the max level for a bonus merge).
signal fruit_merged(level: int, local_pos: Vector2, points: int, is_max_bonus: bool)
signal explosion_triggered(local_pos: Vector2, blast_radius: float, is_nuclear: bool)
## The drop pool grew (bigger fruits drop more often / a new tier can drop). See SpawnProgression.
signal spawn_phase_changed(phase: int, max_drop_level: int)
## The score floor rose: fruits below floor_level (mostly) stop dropping.
signal spawn_floor_changed(floor_level: int)
signal danger_changed(is_triggered: bool, progress: float)
signal game_over(final_score: int, is_new_best: bool)

const INNER_HALF_WIDTH := JarContainer.INNER_HALF_WIDTH
const WALL_THICKNESS := JarContainer.WALL_THICKNESS
const FLOOR_Y := JarContainer.FLOOR_Y
const JAR_TOP_Y := JarContainer.JAR_TOP_Y
const DROP_Y := JarContainer.DROP_Y
const DANGER_LINE_Y := JarContainer.DANGER_LINE_Y
const DROP_COOLDOWN := DropperController.DROP_COOLDOWN

const BOMB_BLAST_EXTRA_RADIUS := 85.0
const NUCLEAR_BLAST_EXTRA_RADIUS := 165.0
const CHARGED_MIN_REBOUND_SPEED := 340.0
const CHARGED_MAX_UPWARD_SPEED := 780.0
const CHARGED_MAX_SPEED := 920.0
const CHARGED_BOUNCE_COOLDOWN := 0.16
const STICKY_BAUMGARTE := 0.25
const STICKY_STIFFNESS := 0.85
const STICKY_MAX_BIAS_SPEED := 480.0

var game_mode: GameMode.Mode = GameMode.Mode.NORMAL
var score: int = 0
var best_score: int = 0
var is_game_over: bool = false
var current_level: int = 0
var next_level: int = 0
var current_property: FruitProperty.Type = FruitProperty.Type.NONE
var next_property: FruitProperty.Type = FruitProperty.Type.NONE
var drop_x: float = 0.0

var jar: JarContainer
var dropper: DropperController
var fruit_pool: FruitPool
var danger_detector: DangerDetector
var merge_effects: MergeEffects
var merge_resolver := MergeResolver.new()
var spawn_progression := SpawnProgression.new()

var _fruits_container: Node2D
var _pending_sticky_contacts: Array[Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	FruitRegistry.ensure_textures_ready()
	if not FruitRegistry.skin_changed.is_connected(_on_skin_changed):
		FruitRegistry.skin_changed.connect(_on_skin_changed)
	_build_layers()
	reset_game()


func _on_skin_changed(_skin_id: String) -> void:
	refresh_skin_visuals()


func refresh_skin_visuals() -> void:
	if fruit_pool != null:
		for fruit in fruit_pool.active_fruits:
			if fruit == null or fruit.in_pool:
				continue
			fruit.refresh_texture(
				FruitRegistry.textures.get_texture(fruit.level),
				FruitRegistry.textures.get_sprite_scale(fruit.level)
			)
	if dropper != null:
		dropper.refresh_held_texture(current_level)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if dropper != null:
			dropper.cancel_drag()


func _build_layers() -> void:
	jar = JarContainer.new()
	jar.name = "JarContainer"
	add_child(jar)

	_fruits_container = Node2D.new()
	_fruits_container.name = "FruitsContainer"
	add_child(_fruits_container)

	fruit_pool = FruitPool.new()
	fruit_pool.name = "FruitPool"
	add_child(fruit_pool)
	fruit_pool.initialize(
		_fruits_container,
		_on_fruit_merge_contact,
		_on_fruit_sticky_contact,
		_on_fruit_charged_bounced,
		_on_fruit_pre_release
	)

	danger_detector = DangerDetector.new()
	danger_detector.name = "DangerDetector"
	danger_detector.line_y = JarContainer.DANGER_LINE_Y
	danger_detector.half_width = JarContainer.INNER_HALF_WIDTH
	danger_detector.danger_state_changed.connect(_on_danger_state_changed)
	danger_detector.game_over_triggered.connect(_on_danger_game_over)
	add_child(danger_detector)

	merge_effects = MergeEffects.new()
	merge_effects.name = "MergeEffects"
	add_child(merge_effects)

	dropper = DropperController.new()
	dropper.name = "DropperController"
	dropper.drop_requested.connect(_on_drop_requested)
	add_child(dropper)


func set_game_mode(mode: GameMode.Mode) -> void:
	game_mode = mode
	if is_inside_tree() and fruit_pool != null:
		reset_game()


func _pick_property_for_mode() -> FruitProperty.Type:
	if game_mode == GameMode.Mode.FRENZY:
		return FruitProperty.pick_for_frenzy(_rng)
	return FruitProperty.Type.NONE


func reset_game() -> void:
	merge_resolver.reset()
	_pending_sticky_contacts.clear()

	is_game_over = false
	score = 0
	best_score = SaveManager.get_high_score(game_mode)

	fruit_pool.release_all()
	merge_effects.clear_all()
	danger_detector.reset()
	dropper.reset()

	spawn_progression.reset(FruitRegistry.catalog)
	current_level = spawn_progression.current_level
	next_level = spawn_progression.next_level
	current_property = _pick_property_for_mode()
	next_property = _pick_property_for_mode()

	dropper.show_held_fruit(current_level, jar, current_property)
	drop_x = dropper.drop_x

	score_changed.emit(score, best_score, 0)
	next_fruit_changed.emit(next_level, next_property)
	danger_changed.emit(false, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var can_interact := not is_game_over and not get_tree().paused
	dropper.handle_input(event, self, jar, can_interact)
	drop_x = dropper.drop_x


func _physics_process(delta: float) -> void:
	if is_game_over:
		return

	fruit_pool.flush_quarantine()
	dropper.tick(delta, spawn_progression.current_level, jar, current_property)
	drop_x = dropper.drop_x

	_process_pending_sticky()
	_update_sticky_magnets(delta)
	_process_concrete_crushing()

	if merge_resolver.scan_active_contacts(fruit_pool.active_fruits):
		_schedule_merge_flush()

	_tick_frenzy_fruits(delta)
	danger_detector.evaluate(fruit_pool.active_fruits, delta)


func _on_drop_requested(spawn_x: float) -> void:
	if is_game_over or not dropper.has_held_fruit:
		return

	var catalog := FruitRegistry.catalog
	var dropped_level := spawn_progression.current_level
	var dropped_property := current_property
	var def := catalog.get_fruit(dropped_level)
	if def == null:
		return

	spawn_progression.consume_and_advance(catalog, _rng)
	current_level = spawn_progression.current_level
	next_level = spawn_progression.next_level
	current_property = next_property
	next_property = _pick_property_for_mode()

	var clamped_x := jar.clamp_drop_x(spawn_x, def.radius)
	drop_x = clamped_x
	dropper.drop_x = clamped_x

	# Show the next fruit right away (dimmed until the cooldown ends) so the player always sees
	# what they are aiming; a tap during the cooldown is queued and drops from the preview spot.
	dropper.start_cooldown()
	dropper.show_held_fruit(current_level, jar, current_property)

	var fruit := fruit_pool.acquire()
	fruit.configure(
		def,
		catalog.get_shape(dropped_level),
		FruitRegistry.textures.get_texture(dropped_level),
		catalog.get_physics_material_for_property(dropped_property),
		FruitRegistry.textures.get_sprite_scale(dropped_level),
		dropped_property
	)
	fruit.activate(Vector2(clamped_x, JarContainer.DROP_Y), Vector2(0.0, 40.0), false, JarContainer.DANGER_LINE_Y, false)
	AudioManager.play_drop()
	next_fruit_changed.emit(next_level, next_property)


func _on_fruit_merge_contact(a: Fruit, b: Fruit) -> void:
	if is_game_over:
		return
	if merge_resolver.enqueue_contact(a, b):
		_schedule_merge_flush()


func _schedule_merge_flush() -> void:
	if not merge_resolver.is_flush_scheduled():
		merge_resolver.mark_flush_scheduled(true)
		call_deferred("_process_merge_queue")


func _process_merge_queue() -> void:
	var result := merge_resolver.process_queue(fruit_pool, jar, merge_effects)
	var phase_before := spawn_progression.get_phase()
	var merges: Array = result.get("merges", [])
	for m in merges:
		var info: Dictionary = m
		var lvl := int(info.get("level", 0))
		var pos: Vector2 = info.get("position", Vector2.ZERO)
		var is_bonus := bool(info.get("is_max_bonus", false))
		fruit_merged.emit(lvl, pos, int(info.get("points", 0)), is_bonus)
		if not is_bonus and spawn_progression.unlock_level(lvl):
			fruit_unlocked.emit(lvl)
			fruit_unlocked_at.emit(lvl, pos)
	var phase_after := spawn_progression.get_phase()
	if phase_after > phase_before:
		spawn_phase_changed.emit(phase_after, spawn_progression.get_max_drop_level())

	var gained := int(result.get("gained_score", 0))
	if gained > 0:
		score += gained
		if score > best_score:
			best_score = score
		score_changed.emit(score, best_score, gained)
	_sync_spawn_floor()

	var nuclear_blasts: Array = result.get("nuclear_blasts", [])
	for blast in nuclear_blasts:
		var center: Vector2 = blast.get("center", Vector2.ZERO)
		var base_r := float(blast.get("base_radius", 40.0))
		var exempt: Fruit = blast.get("exempt", null)
		_trigger_explosion(center, base_r + NUCLEAR_BLAST_EXTRA_RADIUS, true, exempt)


## Feeds the score to the spawn picker and announces when the drop floor rises.
func _sync_spawn_floor() -> void:
	var floor_before := spawn_progression.get_floor_level()
	spawn_progression.current_score = score
	var floor_after := spawn_progression.get_floor_level()
	if floor_after > floor_before:
		spawn_floor_changed.emit(floor_after)


func _process_concrete_crushing() -> void:
	var concrete_fruits: Array[Fruit] = []
	for fruit in fruit_pool.active_fruits:
		if fruit != null and fruit.is_concrete_crushing():
			concrete_fruits.append(fruit)

	if concrete_fruits.is_empty():
		return

	var normal_mat := FruitRegistry.catalog.get_physics_material()
	for concrete in concrete_fruits:
		if concrete == null or concrete.in_pool or not concrete.is_concrete_crushing():
			continue

		var seg_start := concrete.prev_pos
		var seg_end := concrete.position
		var victims: Array[Fruit] = []

		for other in fruit_pool.active_fruits:
			if other == null or other == concrete or other.in_pool or other.is_merging:
				continue
			if other.is_concrete_crushing():
				continue
			var combined_r := concrete.radius + other.radius
			var closest := Geometry2D.get_closest_point_to_segment(other.position, seg_start, seg_end)
			if closest.distance_squared_to(other.position) <= combined_r * combined_r:
				victims.append(other)

		if not victims.is_empty():
			for victim in victims:
				_destroy_fruit(victim, true)
			AudioManager.play_concrete_crush()

		concrete.prev_pos = seg_end

		if concrete.concrete_hit_floor or concrete.position.y + concrete.radius >= JarContainer.FLOOR_Y - 2.5:
			concrete.finish_concrete_landing(normal_mat)
			merge_effects.spawn_property_splash(
				Vector2(concrete.position.x, JarContainer.FLOOR_Y - 4.0),
				concrete.radius,
				FruitProperty.get_color(FruitProperty.Type.CONCRETE),
				8
			)


func _tick_frenzy_fruits(delta: float) -> void:
	var expired_bombs: Array[Fruit] = []

	for fruit in fruit_pool.active_fruits:
		if fruit == null or fruit.in_pool or fruit.is_merging or not fruit.is_dropped:
			continue

		if fruit.fruit_property == FruitProperty.Type.BOMB:
			fruit.bomb_timer -= delta
			fruit.sync_bomb_overlay()
			if fruit.bomb_timer <= 0.0:
				expired_bombs.append(fruit)
		elif fruit.fruit_property == FruitProperty.Type.CHARGED:
			if fruit.charged_bounce_cooldown > 0.0:
				fruit.charged_bounce_cooldown = maxf(0.0, fruit.charged_bounce_cooldown - delta)
			var vel := fruit.linear_velocity
			var clamped := false
			if vel.y < -CHARGED_MAX_UPWARD_SPEED:
				vel.y = -CHARGED_MAX_UPWARD_SPEED
				clamped = true
			if vel.length() > CHARGED_MAX_SPEED:
				vel = vel.normalized() * CHARGED_MAX_SPEED
				clamped = true
			if clamped:
				fruit.linear_velocity = vel

	for bomb in expired_bombs:
		if bomb == null or bomb.in_pool or bomb.is_merging:
			continue
		_trigger_explosion(bomb.position, bomb.radius + BOMB_BLAST_EXTRA_RADIUS, false, null)


func _trigger_explosion(center: Vector2, blast_radius: float, is_nuclear: bool, exempt_fruit: Fruit) -> void:
	var victims: Array[Fruit] = []
	for fruit in fruit_pool.active_fruits:
		if fruit == null or fruit == exempt_fruit or fruit.in_pool:
			continue
		var reach := blast_radius + fruit.radius
		if fruit.position.distance_squared_to(center) <= reach * reach:
			victims.append(fruit)

	for victim in victims:
		_destroy_fruit(victim, false)

	var impulse_reach := blast_radius + 140.0
	for fruit in fruit_pool.active_fruits:
		if fruit == null or fruit.in_pool or fruit.is_merging:
			continue
		var offset := fruit.position - center
		var dist := offset.length()
		if dist <= impulse_reach:
			fruit.sleeping = false
			if not fruit.freeze:
				var dir := offset.normalized() if dist > 1.0 else Vector2.UP
				var strength := lerpf(260.0, 70.0, clampf(dist / impulse_reach, 0.0, 1.0))
				fruit.apply_central_impulse(dir * strength * fruit.mass)

	merge_effects.spawn_explosion_burst(center, blast_radius, is_nuclear)
	explosion_triggered.emit(center, blast_radius, is_nuclear)
	if is_nuclear:
		AudioManager.play_nuclear_explode()
	else:
		AudioManager.play_bomb_explode()


func _destroy_fruit(fruit: Fruit, spawn_crush_fx: bool) -> void:
	if fruit == null or fruit.in_pool:
		return
	# Destroyed fruits never award score.
	if spawn_crush_fx:
		var col := FruitRegistry.textures.get_primary_color(fruit.level)
		merge_effects.spawn_crush_burst(fruit.position, fruit.radius, col)
	fruit_pool.release(fruit)


func _would_create_sticky_cycle(fruit: Fruit, candidate: Fruit) -> bool:
	var cur := candidate
	var steps := 0
	while cur != null and steps < 64:
		if cur == fruit:
			return true
		cur = cur.stuck_target
		steps += 1
	return false


func _detach_sticky_fruit(fruit: Fruit) -> void:
	if fruit == null:
		return
	fruit.stuck_target = null
	fruit.is_stuck = false
	fruit.stuck_local_angle = 0.0
	fruit.stuck_rel_rotation = 0.0
	fruit.can_sleep = (fruit.fruit_property != FruitProperty.Type.CHARGED)
	fruit.set_stuck_visual(false)
	fruit.sleeping = false


func _on_fruit_pre_release(fruit: Fruit) -> void:
	if fruit == null:
		return
	fruit.stuck_target = null
	fruit.is_stuck = false
	fruit.stuck_local_angle = 0.0
	fruit.stuck_rel_rotation = 0.0

	for other in fruit_pool.active_fruits:
		if other == null or other == fruit or other.in_pool:
			continue
		if other.stuck_target == fruit:
			_detach_sticky_fruit(other)


func _on_fruit_sticky_contact(fruit: Fruit, target: Node) -> void:
	if is_game_over or fruit == null or fruit.in_pool or fruit.is_merging:
		return
	_pending_sticky_contacts.append([fruit, target])
	if _pending_sticky_contacts.size() == 1:
		call_deferred("_process_pending_sticky")


func _process_pending_sticky() -> void:
	if _pending_sticky_contacts.is_empty():
		return
	var batch := _pending_sticky_contacts.duplicate()
	_pending_sticky_contacts.clear()

	for pair in batch:
		if pair.size() != 2:
			continue
		var fruit := pair[0] as Fruit
		var target := pair[1] as Node
		if fruit == null or fruit.in_pool or fruit.is_merging or not fruit.is_dropped:
			continue
		if fruit.is_stuck:
			continue
		if target == null or not is_instance_valid(target):
			fruit.has_used_sticky = false
			continue

		if target.is_in_group(&"jar_wall") or target.is_in_group(&"jar_floor"):
			# Ignore stale wall/floor contacts: the fruit must really be against a wall or the floor.
			var near_wall := absf(fruit.position.x) + fruit.radius >= JarContainer.INNER_HALF_WIDTH - 8.0
			var near_floor := fruit.position.y + fruit.radius >= JarContainer.FLOOR_Y - 8.0
			if not near_wall and not near_floor:
				fruit.has_used_sticky = false
				continue
			fruit.linear_velocity = Vector2.ZERO
			fruit.angular_velocity = 0.0
			fruit.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			fruit.freeze = true
			fruit.is_stuck = true
			fruit.set_stuck_visual(true)
			if fruit.is_inside_tree():
				var rid := fruit.get_rid()
				PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
				PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
			merge_effects.spawn_property_splash(
				fruit.position,
				fruit.radius,
				FruitProperty.get_color(FruitProperty.Type.STICKY),
				6
			)
			AudioManager.play_sticky()
		elif target is Fruit:
			var other := target as Fruit
			if other.in_pool or other.is_merging or not other.is_dropped or other.is_concrete_crushing():
				fruit.has_used_sticky = false
				continue
			if _would_create_sticky_cycle(fruit, other):
				fruit.is_stuck = true
				fruit.set_stuck_visual(true)
				continue

			var delta_pos := fruit.position - other.position
			var normal := delta_pos.normalized() if delta_pos.length_squared() > 0.001 else Vector2.UP
			var contact_dist := fruit.radius + other.radius
			if delta_pos.length() > contact_dist + 12.0:
				# Not actually touching (stale contact): never snap a fruit across the jar.
				fruit.has_used_sticky = false
				continue
			if delta_pos.length() > contact_dist + 1.5:
				fruit.position = jar.clamp_merge_position(other.position + normal * contact_dist, fruit.radius)
				if fruit.is_inside_tree():
					PhysicsServer2D.body_set_state(fruit.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, fruit.global_transform)

			fruit.stuck_local_angle = normal.angle() - other.rotation
			fruit.stuck_rel_rotation = fruit.rotation - other.rotation
			fruit.linear_velocity = other.linear_velocity
			fruit.angular_velocity = other.angular_velocity
			if fruit.is_inside_tree():
				var rid := fruit.get_rid()
				PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, other.linear_velocity)
				PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, other.angular_velocity)

			fruit.stuck_target = other
			fruit.is_stuck = true
			fruit.can_sleep = false
			fruit.sleeping = false
			fruit.set_stuck_visual(true)
			var contact_point := other.position + normal * other.radius
			merge_effects.spawn_property_splash(
				contact_point,
				fruit.radius * 0.8,
				FruitProperty.get_color(FruitProperty.Type.STICKY),
				6
			)
			AudioManager.play_sticky()


func _update_sticky_magnets(delta: float) -> void:
	var inv_dt := 1.0 / maxf(delta, 0.001)
	for fruit in fruit_pool.active_fruits:
		if fruit == null or fruit.in_pool or fruit.is_merging or not fruit.is_dropped:
			continue
		if not fruit.is_stuck or fruit.stuck_target == null or fruit.freeze:
			continue

		var other := fruit.stuck_target
		if other.in_pool or other.is_merging or not other.is_dropped or other.is_concrete_crushing():
			_detach_sticky_fruit(fruit)
			continue

		var world_angle := other.rotation + fruit.stuck_local_angle
		var target_dir := Vector2(cos(world_angle), sin(world_angle))
		var contact_dist := fruit.radius + other.radius
		var target_pos := other.position + target_dir * contact_dist
		var pos_err := target_pos - fruit.position

		fruit.sleeping = false
		if not other.freeze and pos_err.length_squared() > 1.0:
			other.sleeping = false

		var r_anchor := target_dir * contact_dist
		var v_anchor := other.linear_velocity + Vector2(-r_anchor.y, r_anchor.x) * other.angular_velocity

		var bias_vel := pos_err * (STICKY_BAUMGARTE * inv_dt)
		if bias_vel.length() > STICKY_MAX_BIAS_SPEED:
			bias_vel = bias_vel.normalized() * STICKY_MAX_BIAS_SPEED

		var dv := bias_vel - (fruit.linear_velocity - v_anchor)
		var m_eff := fruit.mass if other.freeze else (fruit.mass * other.mass) / (fruit.mass + other.mass)
		var impulse := dv * (m_eff * STICKY_STIFFNESS)
		fruit.apply_central_impulse(impulse)

		if not other.freeze:
			other.apply_central_impulse(-impulse)
			var r_contact := target_dir * other.radius
			var torque_impulse := r_contact.cross(-impulse)
			var inertia := maxf(0.5 * other.mass * other.radius * other.radius, 1.0)
			other.angular_velocity += clampf(torque_impulse / inertia, -2.5, 2.5) * 0.35

		var ang_err := wrapf((other.rotation + fruit.stuck_rel_rotation) - fruit.rotation, -PI, PI)
		fruit.angular_velocity = lerpf(fruit.angular_velocity, other.angular_velocity + ang_err * 10.0, 0.45)


func _on_fruit_charged_bounced(fruit: Fruit, other: Node) -> void:
	if is_game_over or fruit == null or fruit.in_pool or fruit.is_merging:
		return
	if fruit.charged_bounce_cooldown > 0.0:
		return
	fruit.charged_bounce_cooldown = CHARGED_BOUNCE_COOLDOWN
	call_deferred("_apply_charged_rebound", fruit, other)


func _apply_charged_rebound(fruit: Fruit, other: Node) -> void:
	if is_game_over or fruit == null or fruit.in_pool or fruit.is_merging or not fruit.is_dropped:
		return
	if fruit.fruit_property != FruitProperty.Type.CHARGED or fruit.freeze:
		return

	var vel := fruit.linear_velocity
	var away_dir := Vector2.UP
	if other != null and is_instance_valid(other):
		if other is Fruit:
			var other_fruit := other as Fruit
			var diff := fruit.position - other_fruit.position
			if diff.length_squared() > 0.001:
				away_dir = (diff.normalized() + Vector2(0.0, -0.45)).normalized()
		elif other.is_in_group(&"jar_wall"):
			var x_dir := -1.0 if fruit.position.x > 0.0 else 1.0
			away_dir = Vector2(x_dir * 0.72, -0.68).normalized()

	var speed := vel.length()
	if speed < CHARGED_MIN_REBOUND_SPEED:
		vel = away_dir * CHARGED_MIN_REBOUND_SPEED
	elif vel.y > -120.0:
		vel = vel.normalized() * maxf(speed, CHARGED_MIN_REBOUND_SPEED)
		vel.y = minf(vel.y, -CHARGED_MIN_REBOUND_SPEED * 0.65)

	vel.y = maxf(vel.y, -CHARGED_MAX_UPWARD_SPEED)
	if vel.length() > CHARGED_MAX_SPEED:
		vel = vel.normalized() * CHARGED_MAX_SPEED
	fruit.linear_velocity = vel
	if fruit.is_inside_tree():
		PhysicsServer2D.body_set_state(fruit.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, vel)

	merge_effects.spawn_property_splash(
		fruit.position,
		fruit.radius * 0.85,
		FruitProperty.get_color(FruitProperty.Type.CHARGED),
		5
	)
	AudioManager.play_charged_bounce()


func _on_danger_state_changed(triggered: bool, progress: float) -> void:
	danger_changed.emit(triggered, progress)


func _on_danger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	dropper.cancel_drag()
	dropper.hide_guide()

	var is_new_best := SaveManager.try_update_high_score(score, game_mode)
	best_score = SaveManager.get_high_score(game_mode)
	AudioManager.play_game_over()
	game_over.emit(score, is_new_best)
