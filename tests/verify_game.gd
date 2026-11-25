extends Node

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_all")


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		push_error("ASSERT FAILED: " + msg)


func _run_all() -> void:
	await get_tree().process_frame

	_test_scenes_load_and_instantiate()
	_test_fruit_catalog_and_extension()
	_test_fruit_pool_reuse()
	await _test_game_board_merge_logic()
	await _test_spawn_progression_unlocks()
	await _test_continuous_merge_sweep_and_clusters()
	await _test_dropper_input_and_no_teleport()
	_test_danger_detector_rules()
	await _test_modes_and_save_manager()
	await _test_frenzy_sticky_property()
	await _test_frenzy_bomb_property()
	await _test_frenzy_nuclear_property()
	await _test_frenzy_concrete_property()
	await _test_frenzy_charged_property()

	await get_tree().process_frame
	await get_tree().process_frame

	if _failures.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("FAILED CHECKS (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)


func _test_scenes_load_and_instantiate() -> void:
	var paths := [
		"res://scenes/boot/boot.tscn",
		"res://scenes/loading/loading.tscn",
		"res://scenes/menu/menu.tscn",
		"res://scenes/game/game.tscn",
	]
	for path in paths:
		var packed := ResourceLoader.load(path) as PackedScene
		_assert(packed != null, "Failed to load scene: " + path)
		if packed != null:
			var inst := packed.instantiate()
			_assert(inst != null, "Failed to instantiate scene: " + path)
			if inst != null:
				inst.free()


func _test_fruit_catalog_and_extension() -> void:
	var catalog := FruitCatalog.new()
	var expected_names := [
		"Kersen",
		"Dukuh",
		"Rambutan",
		"Salak",
		"Jambu Biji",
		"Manggis",
		"Kelapa",
	]
	_assert(catalog.get_count() == 7, "Expected 7 default fruits, got %d" % catalog.get_count())

	var prev_radius := 0.0
	for i in range(expected_names.size()):
		var def := catalog.get_fruit(i)
		_assert(def != null, "Missing fruit at level %d" % i)
		if def != null:
			_assert(def.display_name == expected_names[i], "Expected %s at %d, got %s" % [expected_names[i], i, def.display_name])
			_assert(def.radius > prev_radius, "Radius did not strictly increase at level %d" % i)
			prev_radius = def.radius

	_assert(is_equal_approx(catalog.get_fruit(6).radius, 126.0), "Expected Kelapa radius 126.0")
	_assert(not catalog.has_next_level(6), "Kelapa (6) should be max level before extension")

	# Verify unlock-filtered spawn selection never returns locked levels
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(25):
		_assert(catalog.pick_spawn_level_for_unlocked(rng, {0: true}) == 0, "Only level 0 unlocked must always pick 0")
	var picked_set := {}
	for _i in range(60):
		var lvl := catalog.pick_spawn_level_for_unlocked(rng, {0: true, 1: true, 4: true, 5: true, 6: true})
		_assert(lvl == 0 or lvl == 1, "Unlocked filter must never pick non-droppable levels (4..6) or locked (2..3), got %d" % lvl)
		picked_set[lvl] = true
	_assert(picked_set.has(1), "Unlocked droppable level 1 should appear in spawn pool")

	# Test extending catalog with an 8th fruit (level 7)
	var durian := FruitDefinition.new()
	durian.id = &"durian"
	durian.display_name = "Durian"
	durian.level = 7
	durian.radius = 152.0
	durian.score = 36
	durian.mass = 16.0
	durian.primary_color = Color("#9CCC65")
	durian.secondary_color = Color("#DCE775")
	durian.accent_color = Color("#558B2F")
	durian.outline_color = Color("#33691E")
	catalog.register_fruit(durian)

	_assert(catalog.get_count() == 8, "Expected 8 fruits after register_fruit")
	_assert(catalog.has_next_level(6), "Expected has_next_level(6) == true after extending to 8 fruits")
	_assert(catalog.get_fruit(7).display_name == "Durian", "Expected Durian at level 7")


func _test_fruit_pool_reuse() -> void:
	var container := Node2D.new()
	add_child(container)
	var pool := FruitPool.new()
	container.add_child(pool)
	pool.initialize(container, Callable())

	var initial_total := pool.get_total_allocated()
	_assert(initial_total == FruitPool.INITIAL_POOL_SIZE, "Expected pre-warmed pool size %d" % FruitPool.INITIAL_POOL_SIZE)

	var f1 := pool.acquire()
	var f2 := pool.acquire()
	_assert(pool.active_fruits.size() == 2, "Expected 2 active fruits")
	var id1 := f1.get_instance_id()

	# Same-frame release must enter quarantine instead of being immediately reused
	pool.release(f1)
	_assert(pool.active_fruits.size() == 1, "Expected 1 active fruit after release")
	_assert(f1.in_pool, "Released fruit should be marked in_pool")
	var f_immediate := pool.acquire()
	_assert(f_immediate.get_instance_id() != id1, "Quarantined fruit must NOT be reused on the same physics frame")

	# After flushing quarantine on the next physics tick, f1 returns to free list and is reused
	pool.flush_quarantine()
	var free_before := pool.get_total_allocated()
	var reused := false
	for _i in range(FruitPool.INITIAL_POOL_SIZE):
		var fn := pool.acquire()
		if fn.get_instance_id() == id1:
			reused = true
			break
	_assert(reused, "Flushed quarantine fruit should be reused without extra allocations")
	_assert(pool.get_total_allocated() == free_before, "Pool should reuse flushed instances without growing")

	pool.release_all()
	_assert(pool.active_fruits.is_empty(), "Expected 0 active fruits after release_all")
	container.queue_free()


func _test_game_board_merge_logic() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame

	var catalog := FruitRegistry.catalog
	var def0 := catalog.get_fruit(0)
	var def1 := catalog.get_fruit(1)

	var a := board.fruit_pool.acquire()
	a.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	a.activate(Vector2(-15.0, 600.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)

	var b := board.fruit_pool.acquire()
	b.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	b.activate(Vector2(15.0, 600.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)

	# Simulate duplicate contact reporting from both bodies
	board._on_fruit_merge_contact(a, b)
	board._on_fruit_merge_contact(b, a)
	await get_tree().process_frame

	_assert(board.fruit_pool.active_fruits.size() == 1, "Duplicate contact must produce exactly 1 merged fruit, got %d" % board.fruit_pool.active_fruits.size())
	_assert(board.score == def1.score, "Expected score %d after Kersen merge, got %d" % [def1.score, board.score])
	if board.fruit_pool.active_fruits.size() == 1:
		var merged := board.fruit_pool.active_fruits[0]
		_assert(merged.level == 1, "Merged fruit should be level 1 (Dukuh)")
		_assert(a.in_pool and b.in_pool and merged != a and merged != b, "Quarantined source fruits must stay in pool and not be reused on same frame")

	# Test max-level merge bonus (2 Kelapas)
	board.reset_game()
	var max_lvl := catalog.get_count() - 1
	var max_def := catalog.get_fruit(max_lvl)
	var k1 := board.fruit_pool.acquire()
	k1.configure(max_def, catalog.get_shape(max_lvl), FruitRegistry.textures.get_texture(max_lvl), catalog.get_physics_material(), 1.0)
	k1.activate(Vector2(-50.0, 600.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	var k2 := board.fruit_pool.acquire()
	k2.configure(max_def, catalog.get_shape(max_lvl), FruitRegistry.textures.get_texture(max_lvl), catalog.get_physics_material(), 1.0)
	k2.activate(Vector2(50.0, 600.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)

	board._on_fruit_merge_contact(k1, k2)
	await get_tree().process_frame

	_assert(board.fruit_pool.active_fruits.is_empty(), "Two max-level fruits should merge cleanly with 0 remaining fruits")
	_assert(board.score == catalog.get_max_merge_bonus(max_lvl), "Expected max-level bonus %d, got %d" % [catalog.get_max_merge_bonus(max_lvl), board.score])

	board.queue_free()


func _test_spawn_progression_unlocks() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame

	# Empty box: strictly level 0 (Kersen) for both current and next
	_assert(board.current_level == 0, "Empty box must start with current_level 0 (Kersen), got %d" % board.current_level)
	_assert(board.next_level == 0, "Empty box must start with next_level 0 (Kersen), got %d" % board.next_level)
	_assert(board.spawn_progression.is_level_unlocked(0), "Level 0 should be unlocked initially")
	_assert(not board.spawn_progression.is_level_unlocked(1), "Level 1 (Dukuh) must start locked")

	# Dropping fruits without merging must only produce level 0
	for i in range(6):
		board._on_drop_requested(float(i * 40 - 100))
		board.dropper.cooldown_timer = 0.0
		board.dropper.has_held_fruit = true
		_assert(board.current_level == 0 and board.next_level == 0, "Before any merge, only Kersen (0) can be queued")
	for f in board.fruit_pool.active_fruits:
		_assert(f.level == 0, "Dropped fruit before any merge must be level 0, got %d" % f.level)

	# Merging two level-0 fruits unlocks level 1 (Dukuh), while level 2 remains locked
	board.reset_game()
	var catalog := FruitRegistry.catalog
	var def0 := catalog.get_fruit(0)
	var a := board.fruit_pool.acquire()
	a.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	a.activate(Vector2(-10.0, 700.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	var b := board.fruit_pool.acquire()
	b.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	b.activate(Vector2(10.0, 700.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	board._on_fruit_merge_contact(a, b)
	await get_tree().process_frame

	_assert(board.spawn_progression.is_level_unlocked(1), "Merging two Kersens must unlock level 1 (Dukuh)")
	_assert(not board.spawn_progression.is_level_unlocked(2), "Level 2 (Rambutan) must stay locked until merged")

	# Even if higher non-droppable levels (4..6) are unlocked, they must never drop
	board.spawn_progression.unlock_level(4)
	board.spawn_progression.unlock_level(5)
	board.spawn_progression.unlock_level(6)
	for _i in range(30):
		board._on_drop_requested(0.0)
		board.dropper.cooldown_timer = 0.0
		board.dropper.has_held_fruit = true
		_assert(board.next_level <= 1, "Only unlocked droppable levels (0, 1) may spawn, got %d" % board.next_level)

	board.queue_free()


func _test_continuous_merge_sweep_and_clusters() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame

	var catalog := FruitRegistry.catalog
	var def0 := catalog.get_fruit(0)

	# 1. Resting / sleeping touching fruits missed by body_entered must still merge via sweep
	var s1 := board.fruit_pool.acquire()
	s1.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	s1.activate(Vector2(0.0, 780.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	s1.sleeping = true

	var s2 := board.fruit_pool.acquire()
	s2.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	s2.activate(Vector2(def0.radius * 2.0 + 0.5, 780.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	s2.sleeping = true

	await get_tree().physics_frame
	await get_tree().process_frame
	_assert(board.fruit_pool.active_fruits.size() == 1, "Sweep must merge sleeping touching pair, got %d fruits" % board.fruit_pool.active_fruits.size())
	if board.fruit_pool.active_fruits.size() == 1:
		_assert(board.fruit_pool.active_fruits[0].level == 1, "Merged sleeping pair should produce level 1")

	# 2. 3-way simultaneous cluster must merge exactly one pair, leaving 1 upgraded + 1 original
	board.reset_game()
	var c1 := board.fruit_pool.acquire()
	c1.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	c1.activate(Vector2(-15.0, 780.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	var c2 := board.fruit_pool.acquire()
	c2.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	c2.activate(Vector2(15.0, 780.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)
	var c3 := board.fruit_pool.acquire()
	c3.configure(def0, catalog.get_shape(0), FruitRegistry.textures.get_texture(0), catalog.get_physics_material(), 1.0)
	c3.activate(Vector2(0.0, 780.0 - 28.0), Vector2.ZERO, false, GameBoard.DANGER_LINE_Y, false)

	board.merge_resolver.scan_active_contacts(board.fruit_pool.active_fruits)
	board._process_merge_queue()
	_assert(board.fruit_pool.active_fruits.size() == 2, "3-way cluster must produce 2 fruits (1 merged + 1 leftover), got %d" % board.fruit_pool.active_fruits.size())

	# 3. Live physics drop of two Kersens at identical X must fall, collide, and merge
	board.reset_game()
	board._on_drop_requested(0.0)
	for _i in range(45):
		await get_tree().physics_frame
	board.dropper.cooldown_timer = 0.0
	board.dropper.has_held_fruit = true
	board._on_drop_requested(0.0)
	var merged_live := false
	for _i in range(120):
		await get_tree().physics_frame
		if board.fruit_pool.active_fruits.size() == 1 and board.fruit_pool.active_fruits[0].level == 1:
			merged_live = true
			break
	_assert(merged_live, "Two dropped Kersens at same X must collide and merge into Dukuh in live physics")

	board.queue_free()


func _test_dropper_input_and_no_teleport() -> void:
	var board := GameBoard.new()
	board.position = Vector2(360.0, 200.0)
	add_child(board)
	await get_tree().process_frame

	# Click deep inside the jar (global y = 780 -> local y = 580, local x = 120)
	var click_pos := Vector2(360.0 + 120.0, 200.0 + 580.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_pos
	board._unhandled_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_pos
	board._unhandled_input(release)

	_assert(board.fruit_pool.active_fruits.size() == 1, "Click-release should spawn 1 fruit")
	if board.fruit_pool.active_fruits.size() == 1:
		var dropped := board.fruit_pool.active_fruits[0]
		_assert(is_equal_approx(dropped.position.y, GameBoard.DROP_Y), "Fruit must spawn at DROP_Y (%f), not teleport to click Y (%f)" % [GameBoard.DROP_Y, dropped.position.y])
		_assert(is_equal_approx(dropped.position.x, 120.0), "Fruit must align with click X (120.0), got %f" % dropped.position.x)
		_assert(not dropped.freeze, "Dropped fruit must not be frozen")
		var start_y := dropped.position.y
		for _i in range(10):
			await get_tree().physics_frame
		_assert(dropped.position.y > start_y + 10.0, "Dropped fruit must fall downward under gravity")

	# Rapid click during cooldown must buffer and drop smoothly at DROP_Y once cooldown ends
	var rapid_pos := Vector2(360.0 - 110.0, 200.0 + 500.0)
	var p2 := InputEventMouseButton.new()
	p2.button_index = MOUSE_BUTTON_LEFT
	p2.pressed = true
	p2.position = rapid_pos
	board._unhandled_input(p2)

	var r2 := InputEventMouseButton.new()
	r2.button_index = MOUSE_BUTTON_LEFT
	r2.pressed = false
	r2.position = rapid_pos
	board._unhandled_input(r2)

	for _i in range(30):
		await get_tree().physics_frame
	_assert(board.fruit_pool.active_fruits.size() == 2, "Buffered click during cooldown must drop once cooldown expires, got %d" % board.fruit_pool.active_fruits.size())
	if board.fruit_pool.active_fruits.size() == 2:
		var second := board.fruit_pool.active_fruits[1]
		_assert(second.position.y < 300.0, "Buffered fruit must drop from DROP_Y and fall, not teleport to click Y=500 (pos.y=%f)" % second.position.y)

	# Drag cancellation (e.g. focus loss) must prevent stray drop on release
	var count_before := board.fruit_pool.active_fruits.size()
	var p3 := InputEventMouseButton.new()
	p3.button_index = MOUSE_BUTTON_LEFT
	p3.pressed = true
	p3.position = Vector2(360.0, 400.0)
	board._unhandled_input(p3)
	board.dropper.cancel_drag()
	var r3 := InputEventMouseButton.new()
	r3.button_index = MOUSE_BUTTON_LEFT
	r3.pressed = false
	r3.position = Vector2(360.0, 400.0)
	board._unhandled_input(r3)
	_assert(board.fruit_pool.active_fruits.size() == count_before, "Cancelled drag must not drop on release")

	board.queue_free()


func _test_danger_detector_rules() -> void:
	var detector := DangerDetector.new()
	detector.line_y = 160.0
	detector.grace_duration = 2.0
	detector.settled_overflow_delay = 0.6
	add_child(detector)

	var game_over_count := [0]
	detector.game_over_triggered.connect(func(): game_over_count[0] += 1)

	# 1. Proximity test: fruit sitting 1px below line_y -> must NOT trigger
	var f_prox := Fruit.new()
	f_prox.radius = 30.0
	f_prox.in_pool = false
	f_prox.is_dropped = true
	f_prox.position = Vector2(0.0, detector.line_y + 1.0 + f_prox.radius)
	detector.evaluate([f_prox], 0.1)
	_assert(not detector.is_triggered, "Proximity 1px below danger line must NOT trigger")

	# 2. Top-to-bottom drop test: newly dropped fruit falling fast downward through line_y -> must NOT trigger
	detector.reset()
	var f_drop := Fruit.new()
	f_drop.radius = 30.0
	f_drop.in_pool = false
	f_drop.is_dropped = true
	f_drop.has_been_below_danger_line = false
	f_drop.linear_velocity = Vector2(0.0, 300.0)
	f_drop.position = Vector2(0.0, detector.line_y - 10.0 + f_drop.radius)
	detector.evaluate([f_drop], 0.1)
	_assert(not detector.is_triggered, "Top-to-bottom falling fruit must NOT trigger danger glow")

	# 3. Bottom-to-top rise test: fruit goes below line_y, then rises across line_y -> triggers & fires game_over
	detector.reset()
	game_over_count[0] = 0
	var f_rise := Fruit.new()
	f_rise.radius = 30.0
	f_rise.in_pool = false
	f_rise.is_dropped = true
	f_rise.position = Vector2(0.0, detector.line_y + 5.0 + f_rise.radius)
	detector.evaluate([f_rise], 0.1)
	_assert(not detector.is_triggered, "Fruit below line_y should not trigger")
	_assert(f_rise.has_been_below_danger_line, "Fruit below line_y should record has_been_below_danger_line")

	f_rise.position = Vector2(0.0, detector.line_y - 8.0 + f_rise.radius)
	for _i in range(20):
		detector.evaluate([f_rise], 0.1)
	_assert(detector.is_triggered, "Bottom-to-top crossing must trigger danger detector")
	_assert(game_over_count[0] == 1, "Game over should fire after grace_duration, fired %d times" % game_over_count[0])

	# 4. Recovery test: briefly breaches bottom -> top for 0.5s, then falls back below line_y -> resets
	detector.reset()
	game_over_count[0] = 0
	var f_rec := Fruit.new()
	f_rec.radius = 30.0
	f_rec.in_pool = false
	f_rec.is_dropped = true
	f_rec.position = Vector2(0.0, detector.line_y + 6.0 + f_rec.radius)
	detector.evaluate([f_rec], 0.1)
	f_rec.position = Vector2(0.0, detector.line_y - 8.0 + f_rec.radius)
	detector.evaluate([f_rec], 0.5)
	_assert(detector.is_triggered, "Expected trigger during brief upward breach")
	f_rec.position = Vector2(0.0, detector.line_y + 12.0 + f_rec.radius)
	detector.evaluate([f_rec], 0.1)
	_assert(not detector.is_triggered, "Expected recovery when fruit drops back below line_y")
	_assert(not detector.game_over_emitted and game_over_count[0] == 0, "Game over must not emit after recovery")

	# 5. Resting overflow soft-lock guard
	detector.reset()
	var f_rest := Fruit.new()
	f_rest.radius = 30.0
	f_rest.in_pool = false
	f_rest.is_dropped = true
	f_rest.has_been_below_danger_line = false
	f_rest.has_collided = true
	f_rest.linear_velocity = Vector2.ZERO
	f_rest.position = Vector2(0.0, detector.line_y - 12.0 + f_rest.radius)
	detector.evaluate([f_rest], 0.2)
	_assert(not detector.is_triggered, "Stationary perched fruit should not trigger before settled_overflow_delay")
	detector.evaluate([f_rest], 0.5)
	_assert(detector.is_triggered, "Stationary perched fruit must trigger after settled_overflow_delay to prevent soft-lock")

	f_prox.free()
	f_drop.free()
	f_rise.free()
	f_rec.free()
	f_rest.free()
	detector.queue_free()


func _spawn_test_fruit(
	board: GameBoard,
	lvl: int,
	pos: Vector2,
	prop: FruitProperty.Type = FruitProperty.Type.NONE,
	lin_vel: Vector2 = Vector2.ZERO
) -> Fruit:
	var catalog := FruitRegistry.catalog
	var def := catalog.get_fruit(lvl)
	var f := board.fruit_pool.acquire()
	f.configure(
		def,
		catalog.get_shape(lvl),
		FruitRegistry.textures.get_texture(lvl),
		catalog.get_physics_material_for_property(prop),
		FruitRegistry.textures.get_sprite_scale_for_radius(def.radius),
		prop
	)
	f.activate(pos, lin_vel, false, GameBoard.DANGER_LINE_Y, false)
	return f


func _test_modes_and_save_manager() -> void:
	var prev_normal := SaveManager.get_high_score(GameMode.Mode.NORMAL)
	var prev_frenzy := SaveManager.get_high_score(GameMode.Mode.FRENZY)

	# Verify Normal vs Frenzy high scores are independent
	SaveManager.try_update_high_score(prev_normal + 10, GameMode.Mode.NORMAL)
	_assert(SaveManager.get_high_score(GameMode.Mode.NORMAL) == prev_normal + 10, "Normal high score should update independently")
	_assert(SaveManager.get_high_score(GameMode.Mode.FRENZY) == prev_frenzy, "Updating Normal high score must not overwrite Frenzy high score")

	SaveManager.try_update_high_score(prev_frenzy + 25, GameMode.Mode.FRENZY)
	_assert(SaveManager.get_high_score(GameMode.Mode.FRENZY) == prev_frenzy + 25, "Frenzy high score should update independently")

	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame

	_assert(board.game_mode == GameMode.Mode.NORMAL, "Default GameBoard mode should be NORMAL")
	_assert(board.current_property == FruitProperty.Type.NONE, "Normal mode must spawn NONE property")
	_assert(board.next_property == FruitProperty.Type.NONE, "Normal mode next_property must be NONE")

	board.set_game_mode(GameMode.Mode.FRENZY)
	_assert(board.game_mode == GameMode.Mode.FRENZY, "set_game_mode should switch to FRENZY")

	# Verify 20% randomized Frenzy property distribution
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var special_count := 0
	var none_count := 0
	var seen_types := {}
	for _i in range(500):
		var p := FruitProperty.pick_for_frenzy(rng)
		if p == FruitProperty.Type.NONE:
			none_count += 1
		else:
			special_count += 1
			seen_types[p] = true
	_assert(none_count > 0 and special_count > 0, "Frenzy property roll must produce both NONE and special properties")
	_assert(special_count >= 60 and special_count <= 140, "Expected ~20%% (60..140/500) special properties, got %d" % special_count)
	_assert(seen_types.size() == FruitProperty.FRENZY_TYPES.size(), "All 5 Frenzy property types should appear in randomized rolls")

	# Verify GameBoard in Frenzy mode drops both NONE and special-property fruits
	board._rng.seed = 2026
	board.reset_game()
	var board_none := 0
	var board_special := 0
	for i in range(40):
		board.dropper.cooldown_timer = 0.0
		board.dropper.has_held_fruit = true
		board._on_drop_requested(float((i % 5) * 40 - 80))
	for f in board.fruit_pool.active_fruits:
		if f.fruit_property == FruitProperty.Type.NONE:
			board_none += 1
		else:
			board_special += 1
	_assert(board_none > 0 and board_special > 0, "Frenzy GameBoard drops must include both normal (%d) and special (%d) fruits" % [board_none, board_special])

	board.queue_free()


func _test_frenzy_sticky_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	# 1. Stick to jar wall
	var def0 := FruitRegistry.catalog.get_fruit(0)
	var wall_sticky := _spawn_test_fruit(
		board,
		0,
		Vector2(-JarContainer.INNER_HALF_WIDTH + def0.radius - 1.0, 420.0),
		FruitProperty.Type.STICKY,
		Vector2(-80.0, 20.0)
	)
	for _i in range(8):
		await get_tree().physics_frame
		if wall_sticky.is_stuck:
			break
	_assert(wall_sticky.is_stuck, "Sticky fruit touching jar wall must become stuck")
	_assert(wall_sticky.freeze, "Sticky fruit stuck to jar wall must freeze in place")

	# 2. Stick to jar floor
	board.reset_game()
	var floor_sticky := _spawn_test_fruit(
		board,
		0,
		Vector2(0.0, JarContainer.FLOOR_Y - def0.radius - 6.0),
		FruitProperty.Type.STICKY,
		Vector2(0.0, 120.0)
	)
	for _i in range(15):
		await get_tree().physics_frame
		if floor_sticky.is_stuck:
			break
	_assert(floor_sticky.is_stuck and floor_sticky.freeze, "Sticky fruit touching jar floor must stick to floor")

	# 3. Stick magnetically to a different-level fruit without orbiting or clipping, then detach cleanly when target merges
	board.reset_game()
	var base_a := _spawn_test_fruit(board, 1, Vector2(0.0, JarContainer.FLOOR_Y - 28.0), FruitProperty.Type.NONE)
	var sticky_top := _spawn_test_fruit(board, 0, Vector2(14.0, JarContainer.FLOOR_Y - 28.0 - 48.0), FruitProperty.Type.STICKY, Vector2(0.0, 90.0))
	for _i in range(25):
		await get_tree().physics_frame
		if sticky_top.is_stuck:
			break
	_assert(sticky_top.is_stuck and sticky_top.stuck_target == base_a, "Sticky fruit must stick to different-level fruit")

	# Push base_a laterally and run live physics to verify sticky_top follows like a magnet without orbiting or clipping
	base_a.apply_central_impulse(Vector2(180.0, 0.0))
	for _i in range(35):
		await get_tree().physics_frame
	var surface_dist := sticky_top.position.distance_to(base_a.position)
	var expected_dist := sticky_top.radius + base_a.radius
	_assert(absf(surface_dist - expected_dist) < 6.0, "Sticky fruit must stay magnetically on target surface (dist=%f, expected=%f)" % [surface_dist, expected_dist])
	var rel_angle := (sticky_top.position - base_a.position).angle() - base_a.rotation
	var angle_drift := absf(wrapf(rel_angle - sticky_top.stuck_local_angle, -PI, PI))
	_assert(angle_drift < 0.25, "Sticky fruit must not orbit around contact point (angle_drift=%f)" % angle_drift)

	# Merge base_a with another level-1 fruit -> sticky_top must detach cleanly without crashing
	var base_b := _spawn_test_fruit(board, 1, base_a.position + Vector2(54.0, 0.0), FruitProperty.Type.NONE)
	board._on_fruit_merge_contact(base_a, base_b)
	await get_tree().process_frame
	_assert(not sticky_top.is_stuck and sticky_top.stuck_target == null, "Sticky fruit must detach cleanly when its target fruit merges")

	# 4. Same-level sticky fruit merges instead of only sticking, and awards merge score
	board.reset_game()
	var s1 := _spawn_test_fruit(board, 0, Vector2(-18.0, 680.0), FruitProperty.Type.STICKY)
	var s2 := _spawn_test_fruit(board, 0, Vector2(18.0, 680.0), FruitProperty.Type.NONE)
	board._on_fruit_merge_contact(s1, s2)
	await get_tree().process_frame
	_assert(board.fruit_pool.active_fruits.size() == 1, "Same-level sticky + normal pair must merge")
	_assert(board.score == FruitRegistry.catalog.get_fruit(1).score, "Merging sticky fruit must award merge score")

	board.queue_free()


func _test_frenzy_bomb_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	# 1. Merging a bomb before timer expires disarms it and awards merge score without destroying nearby fruits
	var bystander := _spawn_test_fruit(board, 2, Vector2(90.0, 720.0), FruitProperty.Type.NONE)
	var b1 := _spawn_test_fruit(board, 0, Vector2(-15.0, 720.0), FruitProperty.Type.BOMB)
	_assert(is_equal_approx(b1.bomb_timer, 10.0), "Bomb fruit must start with 10.0s timer")
	var b2 := _spawn_test_fruit(board, 0, Vector2(15.0, 720.0), FruitProperty.Type.NONE)
	board._on_fruit_merge_contact(b1, b2)
	await get_tree().process_frame
	_assert(board.fruit_pool.active_fruits.size() == 2, "Merging bomb must leave merged fruit + bystander intact")
	_assert(not bystander.in_pool, "Bystander must not be destroyed when bomb merges")
	_assert(board.score == FruitRegistry.catalog.get_fruit(1).score, "Merged bomb must award merge score")

	# 2. Expired bomb explodes, destroys itself & nearby fruits, spares distant fruit, and awards 0 score
	board.reset_game()
	var bomb := _spawn_test_fruit(board, 0, Vector2(0.0, 760.0), FruitProperty.Type.BOMB)
	var nearby := _spawn_test_fruit(board, 1, Vector2(60.0, 760.0), FruitProperty.Type.NONE)
	var distant := _spawn_test_fruit(board, 1, Vector2(230.0, 760.0), FruitProperty.Type.NONE)
	bomb.bomb_timer = 0.05
	for _i in range(10):
		await get_tree().physics_frame
		if bomb.in_pool:
			break
	_assert(bomb.in_pool, "Expired bomb must be destroyed")
	_assert(nearby.in_pool, "Nearby fruit within bomb blast radius must be destroyed")
	_assert(not distant.in_pool, "Distant fruit outside bomb blast radius must survive")
	_assert(board.score == 0, "Bomb explosion destruction must award 0 score, got %d" % board.score)

	board.queue_free()


func _test_frenzy_nuclear_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	var n1 := _spawn_test_fruit(board, 0, Vector2(-15.0, 720.0), FruitProperty.Type.NUCLEAR)
	var n2 := _spawn_test_fruit(board, 0, Vector2(15.0, 720.0), FruitProperty.Type.NONE)
	var nearby1 := _spawn_test_fruit(board, 1, Vector2(95.0, 720.0), FruitProperty.Type.NONE)
	var nearby2 := _spawn_test_fruit(board, 2, Vector2(-110.0, 720.0), FruitProperty.Type.NONE)
	var far_fruit := _spawn_test_fruit(board, 1, Vector2(0.0, 320.0), FruitProperty.Type.NONE)

	board._on_fruit_merge_contact(n1, n2)
	await get_tree().process_frame

	_assert(nearby1.in_pool and nearby2.in_pool, "Nuclear merge must destroy nearby fruits")
	_assert(not far_fruit.in_pool, "Distant fruit outside nuclear blast radius must survive")
	_assert(board.fruit_pool.active_fruits.size() == 2, "Only leveled-up fruit and far fruit should remain, got %d" % board.fruit_pool.active_fruits.size())

	var expected_merge_score := FruitRegistry.catalog.get_fruit(1).score
	_assert(board.score == expected_merge_score, "Nuclear merge must award ONLY merge score (%d), not points for destroyed fruits, got %d" % [expected_merge_score, board.score])

	var leveled_up: Fruit = null
	for f in board.fruit_pool.active_fruits:
		if f.level == 1 and f != far_fruit:
			leveled_up = f
	_assert(leveled_up != null and leveled_up.fruit_property == FruitProperty.Type.NONE, "Leveled-up fruit from nuclear merge must survive with NONE property")

	board.queue_free()


func _test_frenzy_concrete_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	var def0 := FruitRegistry.catalog.get_fruit(0)
	var def1 := FruitRegistry.catalog.get_fruit(1)

	# Place both a different-level fruit AND a same-level fruit in concrete's drop path
	var victim_same := _spawn_test_fruit(board, 0, Vector2(0.0, 520.0), FruitProperty.Type.NONE)
	var victim_diff := _spawn_test_fruit(board, 1, Vector2(0.0, JarContainer.FLOOR_Y - def1.radius), FruitProperty.Type.NONE)
	victim_same.freeze = true
	victim_diff.freeze = true

	var concrete := _spawn_test_fruit(board, 0, Vector2(0.0, GameBoard.DROP_Y), FruitProperty.Type.CONCRETE, Vector2(0.0, 200.0))
	_assert(concrete.is_concrete_crushing(), "Dropped concrete fruit must start in crushing state")

	for _i in range(120):
		await get_tree().physics_frame
		if concrete.concrete_landed:
			break

	_assert(concrete.concrete_landed, "Concrete fruit must land on the jar floor")
	_assert(victim_same.in_pool, "Falling concrete must destroy same-level fruit in path without merging")
	_assert(victim_diff.in_pool, "Falling concrete must destroy different-level fruit on floor")
	_assert(board.score == 0, "Concrete crush destruction must award 0 score, got %d" % board.score)
	_assert(concrete.collision_layer == Fruit.LAYER_FRUIT, "Landed concrete must restore normal fruit collision layer")

	# After landing on floor, concrete stops destroying and can merge normally for score
	var partner := _spawn_test_fruit(board, 0, Vector2(def0.radius * 2.0 + 0.5, concrete.position.y), FruitProperty.Type.NONE)
	for _i in range(15):
		await get_tree().physics_frame
		await get_tree().process_frame
		if board.score > 0:
			break
	_assert(not partner.in_pool or board.score == def1.score, "Landed concrete should merge instead of crushing")
	_assert(board.score == def1.score, "Merging landed concrete must award merge score %d, got %d" % [def1.score, board.score])

	board.queue_free()


func _test_frenzy_charged_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	var def0 := FruitRegistry.catalog.get_fruit(0)
	var charged := _spawn_test_fruit(
		board,
		0,
		Vector2(0.0, JarContainer.FLOOR_Y - def0.radius - 120.0),
		FruitProperty.Type.CHARGED,
		Vector2(0.0, 420.0)
	)
	_assert(charged.physics_material_override.bounce > 0.8, "Charged fruit must have high-bounce physics material")

	var bounced_up := false
	for _i in range(40):
		await get_tree().physics_frame
		if charged.has_collided and charged.linear_velocity.y < -150.0:
			bounced_up = true
			break
	_assert(bounced_up, "Charged fruit must bounce strongly upward after hitting floor")

	# Merging charged fruit clears charged property and restores normal physics material
	var other := _spawn_test_fruit(board, 0, charged.position + Vector2(def0.radius * 1.6, 0.0), FruitProperty.Type.NONE)
	board._on_fruit_merge_contact(charged, other)
	await get_tree().process_frame
	_assert(board.fruit_pool.active_fruits.size() == 1, "Charged + normal same-level pair must merge")
	if board.fruit_pool.active_fruits.size() == 1:
		var merged := board.fruit_pool.active_fruits[0]
		_assert(merged.fruit_property == FruitProperty.Type.NONE, "Merged fruit must clear CHARGED property")
		_assert(merged.physics_material_override == FruitRegistry.catalog.get_physics_material(), "Merged fruit must restore normal physics material")
	_assert(board.score == FruitRegistry.catalog.get_fruit(1).score, "Merging charged fruit must award merge score")

	board.queue_free()
