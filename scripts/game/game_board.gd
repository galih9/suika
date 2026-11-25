class_name GameBoard
extends Node2D

## Main Suika playfield coordinator wiring the jar, dropper, fruit pool, merge resolver, and danger detector.

signal score_changed(score: int, best_score: int, delta_points: int)
signal next_fruit_changed(next_level: int)
signal fruit_unlocked(level: int)
signal danger_changed(is_triggered: bool, progress: float)
signal game_over(final_score: int, is_new_best: bool)

const INNER_HALF_WIDTH := JarContainer.INNER_HALF_WIDTH
const WALL_THICKNESS := JarContainer.WALL_THICKNESS
const FLOOR_Y := JarContainer.FLOOR_Y
const JAR_TOP_Y := JarContainer.JAR_TOP_Y
const DROP_Y := JarContainer.DROP_Y
const DANGER_LINE_Y := JarContainer.DANGER_LINE_Y
const DROP_COOLDOWN := DropperController.DROP_COOLDOWN

var score: int = 0
var best_score: int = 0
var is_game_over: bool = false
var current_level: int = 0
var next_level: int = 0
var drop_x: float = 0.0

var jar: JarContainer
var dropper: DropperController
var fruit_pool: FruitPool
var danger_detector: DangerDetector
var merge_effects: MergeEffects
var merge_resolver := MergeResolver.new()
var spawn_progression := SpawnProgression.new()

var _fruits_container: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	FruitRegistry.ensure_textures_ready()
	_build_layers()
	reset_game()


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
	fruit_pool.initialize(_fruits_container, _on_fruit_merge_contact)

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


func reset_game() -> void:
	merge_resolver.reset()
	is_game_over = false
	score = 0
	best_score = SaveManager.get_high_score()

	fruit_pool.release_all()
	merge_effects.clear_all()
	danger_detector.reset()
	dropper.reset()

	spawn_progression.reset(FruitRegistry.catalog)
	current_level = spawn_progression.current_level
	next_level = spawn_progression.next_level

	dropper.show_held_fruit(current_level, jar)
	drop_x = dropper.drop_x

	score_changed.emit(score, best_score, 0)
	next_fruit_changed.emit(next_level)
	danger_changed.emit(false, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var can_interact := not is_game_over and not get_tree().paused
	dropper.handle_input(event, self, jar, can_interact)
	drop_x = dropper.drop_x


func _physics_process(delta: float) -> void:
	if is_game_over:
		return

	fruit_pool.flush_quarantine()
	dropper.tick(delta, spawn_progression.current_level, jar)
	drop_x = dropper.drop_x

	if merge_resolver.scan_active_contacts(fruit_pool.active_fruits):
		_schedule_merge_flush()

	danger_detector.evaluate(fruit_pool.active_fruits, delta)


func _on_drop_requested(spawn_x: float) -> void:
	if is_game_over or not dropper.has_held_fruit:
		return

	var catalog := FruitRegistry.catalog
	var dropped_level := spawn_progression.current_level
	var def := catalog.get_fruit(dropped_level)
	if def == null:
		return

	spawn_progression.consume_and_advance(catalog, _rng)
	current_level = spawn_progression.current_level
	next_level = spawn_progression.next_level

	dropper.start_cooldown()

	var clamped_x := jar.clamp_drop_x(spawn_x, def.radius)
	drop_x = clamped_x
	dropper.drop_x = clamped_x

	var fruit := fruit_pool.acquire()
	fruit.configure(
		def,
		catalog.get_shape(dropped_level),
		FruitRegistry.textures.get_texture(dropped_level),
		catalog.get_physics_material(),
		FruitRegistry.textures.get_sprite_scale_for_radius(def.radius)
	)
	fruit.activate(Vector2(clamped_x, JarContainer.DROP_Y), Vector2(0.0, 40.0), false, JarContainer.DANGER_LINE_Y, false)
	AudioManager.play_drop()
	next_fruit_changed.emit(next_level)


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
	var unlocked: Array = result.get("unlocked_levels", [])
	for lvl in unlocked:
		if spawn_progression.unlock_level(int(lvl)):
			fruit_unlocked.emit(int(lvl))

	var gained := int(result.get("gained_score", 0))
	if gained > 0:
		score += gained
		if score > best_score:
			best_score = score
		score_changed.emit(score, best_score, gained)


func _on_danger_state_changed(triggered: bool, progress: float) -> void:
	danger_changed.emit(triggered, progress)


func _on_danger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	dropper.cancel_drag()
	dropper.hide_guide()

	var is_new_best := SaveManager.try_update_high_score(score)
	best_score = SaveManager.get_high_score()
	AudioManager.play_game_over()
	game_over.emit(score, is_new_best)
