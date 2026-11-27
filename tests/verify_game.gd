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
	_test_sprite_assets_and_power_up_visuals()
	_test_fruit_pool_reuse()
	await _test_game_board_merge_logic()
	await _test_spawn_progression_unlocks()
	_test_spawn_phases_scale_with_progress()
	await _test_continuous_merge_sweep_and_clusters()
	await _test_dropper_input_and_no_teleport()
	await _test_no_stale_contact_teleport()
	_test_danger_detector_rules()
	_test_combo_splash_chance()
	await _test_edge_splatter_layout_and_edges()
	await _test_modes_and_save_manager()
	await _test_frenzy_sticky_property()
	await _test_frenzy_bomb_property()
	await _test_frenzy_nuclear_property()
	await _test_frenzy_concrete_property()
	await _test_frenzy_charged_property()
	await _test_frenzy_waves_and_obstacle_progression()
	await _test_frenzy_intro_modal()
	await _test_frenzy_low_gravity_property()
	await _test_frenzy_shadow_property()
	await _test_skin_system()
	await _test_ad_manager_and_banner_layout()
	await _test_localization_and_language_modal()
	_test_splash_and_loading_config()
	await _test_versioning()

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
		"Blueberry", "Cherry", "Strawberry", "Grape", "Kiwi",
		"Lime", "Orange", "Persimmon", "Apple", "Pear",
		"Peach", "Dragonfruit", "Pineapple", "Melon", "Watermelon",
	]
	var expected_px := [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 44, 48, 56, 64]
	_assert(catalog.get_count() == 15, "Expected 15 default fruits, got %d" % catalog.get_count())

	var prev_radius := 0.0
	for i in range(expected_names.size()):
		var def := catalog.get_fruit(i)
		_assert(def != null, "Missing fruit at level %d" % i)
		if def != null:
			_assert(def.display_name == expected_names[i], "Expected %s at %d, got %s" % [expected_names[i], i, def.display_name])
			_assert(def.radius > prev_radius, "Radius did not strictly increase at level %d" % i)
			_assert(is_equal_approx(def.radius, float(expected_px[i]) * 2.0), "Radius at level %d should be 2x its %dpx sprite" % [i, expected_px[i]])
			_assert(def.texture is AtlasTexture, "Fruit %s must use its spritesheet AtlasTexture" % def.display_name)
			if def.texture is AtlasTexture:
				_assert(int((def.texture as AtlasTexture).region.size.x) == expected_px[i], "Sprite region for %s should be %dpx wide" % [def.display_name, expected_px[i]])
			prev_radius = def.radius

	_assert(is_equal_approx(catalog.get_fruit(14).radius, 128.0), "Expected Watermelon radius 128.0")
	_assert(not catalog.has_next_level(14), "Watermelon (14) should be max level before extension")

	# Verify unlock-filtered spawn selection never returns locked levels
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(25):
		_assert(catalog.pick_spawn_level_for_unlocked(rng, {0: true}) == 0, "Only level 0 unlocked must always pick 0")
	var picked_set := {}
	for _i in range(60):
		var lvl := catalog.pick_spawn_level_for_unlocked(rng, {0: true, 1: true, 5: true, 6: true, 14: true})
		_assert(lvl == 0 or lvl == 1, "Unlocked filter must never pick non-droppable levels (5+) or locked (2..4), got %d" % lvl)
		picked_set[lvl] = true
	_assert(picked_set.has(1), "Unlocked droppable level 1 should appear in spawn pool")

	# Test extending catalog with a 16th fruit (level 15)
	var durian := FruitDefinition.new()
	durian.id = &"durian"
	durian.display_name = "Durian"
	durian.level = 15
	durian.radius = 152.0
	durian.score = 36
	durian.mass = 16.0
	durian.primary_color = Color("#9CCC65")
	durian.secondary_color = Color("#DCE775")
	durian.accent_color = Color("#558B2F")
	durian.outline_color = Color("#33691E")
	catalog.register_fruit(durian)

	_assert(catalog.get_count() == 16, "Expected 16 fruits after register_fruit")
	_assert(catalog.has_next_level(14), "Expected has_next_level(14) == true after extending to 16 fruits")
	_assert(catalog.get_fruit(15).display_name == "Durian", "Expected Durian at level 15")


func _test_sprite_assets_and_power_up_visuals() -> void:
	FruitRegistry.ensure_textures_ready()
	var textures := FruitRegistry.textures
	var catalog := FruitRegistry.catalog
	for i in range(catalog.get_count()):
		_assert(textures.get_texture(i) != null, "Missing sprite texture for level %d" % i)
		_assert(is_equal_approx(textures.get_sprite_scale(i), 4.0), "Level %d sprite should render at 4x pixel scale, got %f" % [i, textures.get_sprite_scale(i)])

	_assert(textures.get_property_icon(FruitProperty.Type.BOMB) != null, "Bomb must use its icon asset")
	_assert(textures.get_property_icon(FruitProperty.Type.NUCLEAR) != null, "Nuclear must use its icon asset")
	for prop in [
		FruitProperty.Type.STICKY,
		FruitProperty.Type.CONCRETE,
		FruitProperty.Type.CHARGED,
		FruitProperty.Type.LOW_GRAVITY,
		FruitProperty.Type.SHADOW,
	]:
		_assert(textures.get_property_icon(prop) == null, "%s should not use an icon" % FruitProperty.get_display_name(prop))
		_assert(textures.get_property_material(prop) != null, "%s must use the tint/outline material" % FruitProperty.get_display_name(prop))
	_assert(textures.get_property_material(FruitProperty.Type.NONE) == null, "Plain fruits must not get a material")
	_assert(
		textures.get_property_material(FruitProperty.Type.STICKY) != textures.get_property_material(FruitProperty.Type.CHARGED),
		"Each tinted property needs its own shared material"
	)

	# A pooled fruit picks up / drops the visuals when configured and returned to the pool.
	var fruit := Fruit.new()
	add_child(fruit)
	var def0 := catalog.get_fruit(0)
	fruit.configure(def0, catalog.get_shape(0), textures.get_texture(0), catalog.get_physics_material(), textures.get_sprite_scale(0), FruitProperty.Type.CHARGED)
	_assert(fruit._sprite.material == textures.get_property_material(FruitProperty.Type.CHARGED), "Charged fruit sprite must use the blue material")
	_assert(not fruit._overlay.visible, "Charged fruit must not show an icon")
	fruit.configure(def0, catalog.get_shape(0), textures.get_texture(0), catalog.get_physics_material(), textures.get_sprite_scale(0), FruitProperty.Type.BOMB)
	_assert(fruit._sprite.material == null, "Bomb fruit sprite must not keep a tint material")
	_assert(fruit._overlay.visible and fruit._overlay.texture == textures.get_property_icon(FruitProperty.Type.BOMB), "Bomb fruit must show the bomb icon")
	fruit.deactivate_to_pool()
	_assert(not fruit._overlay.visible and fruit._sprite.material == null, "Pooled fruit must clear property visuals")
	fruit.free()


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
	_assert(board.score == def1.score, "Expected score %d after Blueberry merge, got %d" % [def1.score, board.score])
	if board.fruit_pool.active_fruits.size() == 1:
		var merged := board.fruit_pool.active_fruits[0]
		_assert(merged.level == 1, "Merged fruit should be level 1 (Cherry)")
		_assert(a.in_pool and b.in_pool and merged != a and merged != b, "Quarantined source fruits must stay in pool and not be reused on same frame")

	# Test max-level merge bonus (2 Watermelons)
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

	# Empty box: strictly level 0 (Blueberry) for both current and next
	_assert(board.current_level == 0, "Empty box must start with current_level 0 (Blueberry), got %d" % board.current_level)
	_assert(board.next_level == 0, "Empty box must start with next_level 0 (Blueberry), got %d" % board.next_level)
	_assert(board.spawn_progression.is_level_unlocked(0), "Level 0 should be unlocked initially")
	_assert(not board.spawn_progression.is_level_unlocked(1), "Level 1 (Cherry) must start locked")

	# Dropping fruits without merging must only produce level 0
	for i in range(6):
		board._on_drop_requested(float(i * 40 - 100))
		board.dropper.cooldown_timer = 0.0
		board.dropper.has_held_fruit = true
		_assert(board.current_level == 0 and board.next_level == 0, "Before any merge, only Blueberry (0) can be queued")
	for f in board.fruit_pool.active_fruits:
		_assert(f.level == 0, "Dropped fruit before any merge must be level 0, got %d" % f.level)

	# Merging two level-0 fruits unlocks level 1 (Cherry), while level 2 remains locked
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

	_assert(board.spawn_progression.is_level_unlocked(1), "Merging two Blueberries must unlock level 1 (Cherry)")
	_assert(not board.spawn_progression.is_level_unlocked(2), "Level 2 (Strawberry) must stay locked until merged")

	# Even if higher non-droppable levels (5+) are unlocked, they must never drop
	board.spawn_progression.unlock_level(5)
	board.spawn_progression.unlock_level(6)
	board.spawn_progression.unlock_level(7)
	for _i in range(30):
		board._on_drop_requested(0.0)
		board.dropper.cooldown_timer = 0.0
		board.dropper.has_held_fruit = true
		_assert(board.next_level <= 1, "Only unlocked droppable levels (0, 1) may spawn, got %d" % board.next_level)

	board.queue_free()


func _test_spawn_phases_scale_with_progress() -> void:
	var catalog := FruitRegistry.catalog
	var sp := SpawnProgression.new()
	sp.reset(catalog)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	_assert(sp.get_phase() == 0 and sp.get_max_drop_level() == 0, "Fresh run: phase 0, only Blueberry drops")

	# Make Cherry..Persimmon (levels 1-5): still the opening phase, drops up to Kiwi (4).
	for lvl in range(1, 6):
		sp.unlock_level(lvl)
	_assert(sp.get_phase() == 0 and sp.get_max_drop_level() == 4, "Before Orange, drops stay within the first 5 tiers")
	var early_blue := float(sp.get_drop_chances(catalog).get(0, 0.0))

	# Make Orange (6): near-even odds like Suika.
	sp.unlock_level(6)
	_assert(sp.get_phase() == 1, "Making Orange must enter phase 1")
	var mid_blue := float(sp.get_drop_chances(catalog).get(0, 0.0))
	_assert(mid_blue < early_blue, "Blueberry must get rarer as the run grows (%f -> %f)" % [early_blue, mid_blue])

	# Make up to Dragonfruit (11): Lime and Orange join the drop pool, Blueberry is rare.
	for lvl in range(7, 12):
		sp.unlock_level(lvl)
	_assert(sp.get_max_drop_level() == 6, "Late game must allow drops up to Orange (6), got %d" % sp.get_max_drop_level())
	var late := sp.get_drop_chances(catalog)
	_assert(float(late.get(0, 0.0)) < 0.08, "Late game Blueberry chance must be small, got %f" % float(late.get(0, 0.0)))

	var small_count := 0
	for _i in range(400):
		sp.consume_and_advance(catalog, rng)
		_assert(sp.next_level >= 0 and sp.next_level <= 6, "Late drops must stay within 0..6, got %d" % sp.next_level)
		if sp.next_level <= 1:
			small_count += 1
	_assert(small_count < 100, "Late game must not be flooded with tiny fruits (%d/400 were tier 1-2)" % small_count)

	# Score floor: 500 retires Blueberry, 800 retires Cherry, ... every 300 points.
	sp.current_score = 499
	_assert(sp.get_floor_level() == 0, "No floor below 500 points")
	sp.current_score = 500
	_assert(sp.get_floor_level() == 1, "500 points must retire Blueberry (floor 1)")
	sp.current_score = 800
	_assert(sp.get_floor_level() == 2, "800 points must retire Cherry (floor 2)")
	sp.current_score = 2000
	_assert(sp.get_floor_level() == 6, "2000 points must put the floor at Orange (6), got %d" % sp.get_floor_level())
	var chances := sp.get_drop_chances(catalog)
	var below := 0.0
	for lvl in range(0, 6):
		below += float(chances.get(lvl, 0.0))
	_assert(absf(below - SpawnProgression.BELOW_FLOOR_CHANCE) < 0.005, "Below-floor fruits must keep a small total chance, got %f" % below)
	_assert(float(chances.get(0, 0.0)) > 0.0, "A Blueberry must still be possible (rarely) at 2000 points")
	_assert(sp.get_max_drop_level() == SpawnProgression.MAX_DROP_LEVEL_CAP, "High floor must widen drops up to the cap")
	var under_floor := 0
	for _i in range(1000):
		sp.consume_and_advance(catalog, rng)
		if sp.next_level < 6:
			under_floor += 1
	_assert(under_floor > 0 and under_floor < 120, "Under-floor drops at 2000 points must be rare but possible (%d/1000)" % under_floor)


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

	# 3. Live physics drop of two Blueberries at identical X must fall, collide, and merge
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
	_assert(merged_live, "Two dropped Blueberries at same X must collide and merge into Cherry in live physics")

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


func _test_no_stale_contact_teleport() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame

	# 1. A contact between far-apart same-level fruits (e.g. stale data on a recycled body)
	#    must never merge them.
	var far_a := _spawn_test_fruit(board, 0, Vector2(-200.0, 780.0))
	var far_b := _spawn_test_fruit(board, 0, Vector2(200.0, 780.0))
	board._on_fruit_merge_contact(far_a, far_b)
	await get_tree().process_frame
	_assert(not far_a.in_pool and not far_b.in_pool, "Far-apart fruits must not merge from a stale contact")
	_assert(board.fruit_pool.active_fruits.size() == 2, "Stale contact must not spawn a merged fruit")

	# 2. A recycled pool body must start with an empty contact list.
	board.reset_game()
	var settled := _spawn_test_fruit(board, 0, Vector2(0.0, JarContainer.FLOOR_Y - 20.0))
	var neighbour := _spawn_test_fruit(board, 1, Vector2(0.0, JarContainer.FLOOR_Y - 20.0 - 44.0))
	for _i in range(20):
		await get_tree().physics_frame
	board.fruit_pool.release(settled)
	for _i in range(3):
		await get_tree().physics_frame
	var recycled := _spawn_test_fruit(board, 0, Vector2(120.0, GameBoard.DROP_Y))
	_assert(recycled.get_colliding_bodies().is_empty(), "Re-activated fruit must not keep contacts from its previous life")
	await get_tree().physics_frame
	_assert(not recycled.in_pool and recycled.position.y < 200.0, "Freshly dropped fruit must fall from the top, not teleport (y=%f)" % recycled.position.y)
	_assert(not neighbour.in_pool, "Untouched neighbour must stay in place")

	board.queue_free()


func _test_combo_splash_chance() -> void:
	_assert(AudioManager.get_splash_chance(0) == 0.0, "No splash without a combo")
	_assert(AudioManager.get_splash_chance(1) == 0.0, "A single merge must never splash")
	var prev := 0.0
	for combo in range(2, 12):
		var c := AudioManager.get_splash_chance(combo)
		_assert(c > 0.0 and c < 1.0, "Combo x%d splash chance must be a real chance, got %f" % [combo, c])
		_assert(c >= prev, "Splash chance must not drop as the combo grows")
		prev = c


func _test_edge_splatter_layout_and_edges() -> void:
	var game := (ResourceLoader.load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var splatter: EdgeSplatter = game._edge_splatter
	var vp_size: Vector2 = game.get_viewport_rect().size
	_assert(splatter != null, "Game scene must create _edge_splatter")
	_assert(vp_size.x > 0.0 and vp_size.y > 0.0, "Viewport size must be positive")
	_assert(splatter.size == vp_size, "EdgeSplatter must match full viewport size %s, got %s" % [str(vp_size), str(splatter.size)])
	_assert(
		is_zero_approx(splatter.offset_left) and is_zero_approx(splatter.offset_top)
		and is_zero_approx(splatter.offset_right) and is_zero_approx(splatter.offset_bottom),
		"EdgeSplatter full-rect offsets must all be 0.0"
	)

	var w := vp_size.x
	var h := vp_size.y
	var edges: Array[int] = [
		EdgeSplatter.Edge.LEFT,
		EdgeSplatter.Edge.RIGHT,
		EdgeSplatter.Edge.TOP_LEFT,
		EdgeSplatter.Edge.TOP_RIGHT,
		EdgeSplatter.Edge.BOTTOM_LEFT,
		EdgeSplatter.Edge.BOTTOM_RIGHT,
	]
	for edge in edges:
		splatter.clear()
		splatter._spawn_splat(edge, Color.RED, 1.0, 0.0)
		_assert(splatter._splats.size() == 1, "Expected 1 splat for edge %d" % edge)
		var c := splatter._splats[0].center
		match edge:
			EdgeSplatter.Edge.LEFT:
				_assert(c.x < w * 0.25, "LEFT splat x (%f) must stay on left edge" % c.x)
				_assert(c.y >= h * 0.28 and c.y <= h * 0.72, "LEFT splat y (%f) must be in middle band" % c.y)
			EdgeSplatter.Edge.RIGHT:
				_assert(c.x > w * 0.75, "RIGHT splat x (%f) must stay on right edge" % c.x)
				_assert(c.y >= h * 0.28 and c.y <= h * 0.72, "RIGHT splat y (%f) must be in middle band" % c.y)
			EdgeSplatter.Edge.TOP_LEFT:
				_assert(c.x < w * 0.25, "TOP_LEFT splat x (%f) must stay on left edge" % c.x)
				_assert(c.y >= h * 0.10 and c.y <= h * 0.25, "TOP_LEFT splat y (%f) must be in top band" % c.y)
			EdgeSplatter.Edge.TOP_RIGHT:
				_assert(c.x > w * 0.75, "TOP_RIGHT splat x (%f) must stay on right edge" % c.x)
				_assert(c.y >= h * 0.10 and c.y <= h * 0.25, "TOP_RIGHT splat y (%f) must be in top band" % c.y)
			EdgeSplatter.Edge.BOTTOM_LEFT:
				_assert(c.x < w * 0.25, "BOTTOM_LEFT splat x (%f) must stay on left edge" % c.x)
				_assert(c.y >= h * 0.72 and c.y <= h * 0.86, "BOTTOM_LEFT splat y (%f) must be in bottom band" % c.y)
			EdgeSplatter.Edge.BOTTOM_RIGHT:
				_assert(c.x > w * 0.75, "BOTTOM_RIGHT splat x (%f) must stay on right edge" % c.x)
				_assert(c.y >= h * 0.72 and c.y <= h * 0.86, "BOTTOM_RIGHT splat y (%f) must be in bottom band" % c.y)

	splatter.clear()
	var saw_left := false
	var saw_right := false
	var saw_top := false
	var saw_middle := false
	var saw_bottom := false
	for _i in range(6):
		splatter.splash(PackedColorArray([Color.RED, Color.YELLOW]), 4)
		for s in splatter._splats:
			if s.center.x < w * 0.5:
				saw_left = true
			else:
				saw_right = true
			if s.center.y < h * 0.3:
				saw_top = true
			elif s.center.y <= h * 0.7:
				saw_middle = true
			else:
				saw_bottom = true
	_assert(saw_left and saw_right, "Splashes must span both left and right edges")
	_assert(saw_top and saw_middle and saw_bottom, "Splashes must span top, middle, and bottom regions")

	game.queue_free()


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
		FruitRegistry.textures.get_sprite_scale(lvl),
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
	_assert(seen_types.size() == FruitProperty.FRENZY_TYPES.size(), "All %d Frenzy property types should appear in randomized rolls" % FruitProperty.FRENZY_TYPES.size())

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
	var base_b := _spawn_test_fruit(board, 1, base_a.position + Vector2(base_a.radius * 2.0 - 2.0, 0.0), FruitProperty.Type.NONE)
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


func _test_frenzy_waves_and_obstacle_progression() -> void:
	# 1. Obstacle unlock progression & escalating spawn probability
	var w1 := FruitProperty.get_available_types_for_wave(1)
	_assert(not w1.has(FruitProperty.Type.BOMB) and not w1.has(FruitProperty.Type.CONCRETE) and not w1.has(FruitProperty.Type.NUCLEAR), "Wave 1 must not spawn Bomb, Concrete, or Nuclear obstacles")
	_assert(w1.has(FruitProperty.Type.STICKY) and w1.has(FruitProperty.Type.CHARGED) and w1.has(FruitProperty.Type.LOW_GRAVITY) and w1.has(FruitProperty.Type.SHADOW), "Wave 1 must include Sticky, Charged, Low Gravity, and Shadow")

	var w2 := FruitProperty.get_available_types_for_wave(2)
	_assert(w2.has(FruitProperty.Type.BOMB) and not w2.has(FruitProperty.Type.CONCRETE) and not w2.has(FruitProperty.Type.NUCLEAR), "Wave 2 must unlock Bomb only")
	_assert(FruitProperty.get_obstacle_unlocked_at_wave(2) == FruitProperty.Type.BOMB, "Wave 2 unlock helper must return BOMB")

	var w4 := FruitProperty.get_available_types_for_wave(4)
	_assert(w4.has(FruitProperty.Type.BOMB) and w4.has(FruitProperty.Type.CONCRETE) and not w4.has(FruitProperty.Type.NUCLEAR), "Wave 4 must unlock Concrete")
	_assert(FruitProperty.get_obstacle_unlocked_at_wave(4) == FruitProperty.Type.CONCRETE, "Wave 4 unlock helper must return CONCRETE")

	var w6 := FruitProperty.get_available_types_for_wave(6)
	_assert(w6.size() == FruitProperty.FRENZY_TYPES.size() and w6.has(FruitProperty.Type.NUCLEAR), "Wave 6 must unlock Nuclear alongside all properties")
	_assert(FruitProperty.get_obstacle_unlocked_at_wave(6) == FruitProperty.Type.NUCLEAR, "Wave 6 unlock helper must return NUCLEAR")

	var c1 := FruitProperty.get_spawn_chance_for_wave(1)
	var c2 := FruitProperty.get_spawn_chance_for_wave(2)
	var c4 := FruitProperty.get_spawn_chance_for_wave(4)
	var c6 := FruitProperty.get_spawn_chance_for_wave(6)
	var c7 := FruitProperty.get_spawn_chance_for_wave(7)
	var c9 := FruitProperty.get_spawn_chance_for_wave(9)
	var c20 := FruitProperty.get_spawn_chance_for_wave(20)
	_assert(c1 < c2 and c2 < c4 and c4 < c6 and c6 < c7 and c7 < c9, "Property spawn chance must strictly increase across waves")
	_assert(c20 <= FruitProperty.FRENZY_MAX_SPAWN_CHANCE + 0.0001, "Property spawn chance must cap at FRENZY_MAX_SPAWN_CHANCE")

	# 2. Target score progression (+300 each wave)
	_assert(GameBoard.get_frenzy_wave_target(1) == 300, "Wave 1 target must be 300")
	_assert(GameBoard.get_frenzy_wave_target(2) == 600, "Wave 2 target must be 600")
	_assert(GameBoard.get_frenzy_wave_target(3) == 900, "Wave 3 target must be 900")
	_assert(GameBoard.get_frenzy_wave_target(6) == 1800, "Wave 6 target must be 1800")

	# 3. Board wave state, advance on sufficient score, and game over on timeout
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	_assert(board.frenzy_wave == 1, "Frenzy must start at Wave 1")
	_assert(is_equal_approx(board.frenzy_wave_timer, GameBoard.FRENZY_WAVE_DURATION), "Wave timer must start at 20.0s")
	_assert(board.frenzy_wave_score == 0 and board.frenzy_wave_target == 300, "Wave 1 must start at 0 / 300")

	var advanced_events: Array[Array] = []
	board.frenzy_wave_advanced.connect(func(nw: int, nt: int, uo: int) -> void:
		advanced_events.append([nw, nt, uo])
	)

	board.frenzy_wave_score = 300
	board.frenzy_wave_timer = 0.01
	board._tick_frenzy_wave(0.05)
	_assert(not board.is_game_over, "Meeting wave score before timer expiry must not end game")
	_assert(board.frenzy_wave == 2, "Meeting Wave 1 score must advance to Wave 2")
	_assert(board.frenzy_wave_score == 0 and board.frenzy_wave_target == 600, "Wave 2 must reset wave_score to 0 and set target to 600")
	_assert(is_equal_approx(board.frenzy_wave_timer, GameBoard.FRENZY_WAVE_DURATION), "Advancing wave must reset timer to 20.0s")
	_assert(advanced_events.size() == 1 and advanced_events[0] == [2, 600, FruitProperty.Type.BOMB], "Advancing to Wave 2 must emit BOMB obstacle unlock")

	# Failing wave 2 (score < 600) must end the run with WAVE_TIMEOUT
	var game_over_count := [0]
	board.game_over.connect(func(_s: int, _nb: bool) -> void: game_over_count[0] += 1)
	board.frenzy_wave_score = 599
	board.frenzy_wave_timer = 0.01
	board._tick_frenzy_wave(0.05)
	_assert(board.is_game_over, "Expiring wave timer below target score must trigger game over")
	_assert(board.game_over_reason == GameBoard.GameOverReason.WAVE_TIMEOUT, "Game over reason must be WAVE_TIMEOUT")
	_assert(game_over_count[0] == 1, "game_over signal must emit once on wave timeout")

	# Normal mode must never time out
	board.set_game_mode(GameMode.Mode.NORMAL)
	board.frenzy_wave_timer = 0.01
	for _i in range(5):
		await get_tree().physics_frame
	_assert(not board.is_game_over, "Normal mode must never trigger Frenzy wave timeout")

	board.queue_free()

	# 4. Game HUD WaveBar visibility & PowerUpModal completeness
	var prev_selected := SceneManager.selected_mode
	SceneManager.selected_mode = GameMode.Mode.FRENZY
	var frenzy_scene := (ResourceLoader.load(SceneManager.GAME_SCENE) as PackedScene).instantiate()
	add_child(frenzy_scene)
	await get_tree().process_frame
	_assert(frenzy_scene._wave_bar.visible, "WaveBar must be visible in Frenzy mode")

	SceneManager.selected_mode = GameMode.Mode.NORMAL
	var normal_scene := (ResourceLoader.load(SceneManager.GAME_SCENE) as PackedScene).instantiate()
	add_child(normal_scene)
	await get_tree().process_frame
	_assert(not normal_scene._wave_bar.visible, "WaveBar must be hidden in Normal mode")
	_assert(PowerUpModal.ENTRIES.size() == 7, "PowerUpModal must list all 7 Frenzy properties")

	frenzy_scene.queue_free()
	normal_scene.queue_free()
	SceneManager.selected_mode = prev_selected


func _test_frenzy_intro_modal() -> void:
	var prev_hidden := SaveManager.is_frenzy_intro_hidden()
	var prev_selected := SceneManager.selected_mode

	SaveManager.set_frenzy_intro_hidden(false)

	# 1. Normal mode must NOT show the Frenzy intro popup
	SceneManager.selected_mode = GameMode.Mode.NORMAL
	var normal_scene := (ResourceLoader.load(SceneManager.GAME_SCENE) as PackedScene).instantiate()
	add_child(normal_scene)
	await get_tree().process_frame
	_assert(not normal_scene._frenzy_intro_modal.is_open(), "Frenzy intro modal must stay closed in Normal mode")
	_assert(not get_tree().paused, "Normal mode must not start paused")
	normal_scene.queue_free()
	await get_tree().process_frame

	# 2. Frenzy mode MUST show the popup, pause the wave timer, and unpause on Start
	SceneManager.selected_mode = GameMode.Mode.FRENZY
	var frenzy_scene := (ResourceLoader.load(SceneManager.GAME_SCENE) as PackedScene).instantiate()
	add_child(frenzy_scene)
	await get_tree().process_frame
	var modal: FrenzyIntroModal = frenzy_scene._frenzy_intro_modal
	_assert(modal.is_open() and modal.visible, "Frenzy intro modal must open before Frenzy starts")
	_assert(get_tree().paused, "Game tree must pause while Frenzy intro modal is open")
	_assert(not modal.is_dont_show_checked(), "Don't show again checkbox must start unchecked")

	for _i in range(5):
		await get_tree().physics_frame
	_assert(is_equal_approx(frenzy_scene._board.frenzy_wave_timer, GameBoard.FRENZY_WAVE_DURATION), "Wave timer must stay paused at 20.0s while intro modal is open")

	# Dismiss without checking "Don't show again" -> unpauses and keeps preference false
	modal._start_button.pressed.emit()
	await modal.closed
	_assert(not modal.is_open() and not modal.visible, "Frenzy intro modal must close after Start pressed")
	_assert(not get_tree().paused, "Game tree must unpause after Frenzy intro modal closes")
	_assert(not SaveManager.is_frenzy_intro_hidden(), "Unchecked checkbox must keep frenzy intro enabled")

	# Restarting opens the intro again; checking the checkbox and pressing Start persists opt-out
	frenzy_scene._on_restart_pressed()
	await get_tree().process_frame
	_assert(modal.is_open() and get_tree().paused, "Restarting Frenzy while not hidden must re-open intro and pause")
	modal.set_dont_show_checked(true)
	_assert(modal.is_dont_show_checked(), "Checkbox helper must reflect checked state")
	modal._start_button.pressed.emit()
	await modal.closed
	_assert(not get_tree().paused, "Closing intro modal after checking opt-out must unpause")
	_assert(SaveManager.is_frenzy_intro_hidden(), "Checking 'Don't show this again' must persist in SaveManager")

	frenzy_scene.queue_free()
	await get_tree().process_frame

	# 3. Subsequent Frenzy session skips the popup when hidden
	var frenzy_skip := (ResourceLoader.load(SceneManager.GAME_SCENE) as PackedScene).instantiate()
	add_child(frenzy_skip)
	await get_tree().process_frame
	_assert(not frenzy_skip._frenzy_intro_modal.is_open(), "Frenzy intro modal must not open when 'Don't show this again' is saved")
	_assert(not get_tree().paused, "Frenzy must start unpaused when intro is hidden")
	frenzy_skip.queue_free()
	await get_tree().process_frame

	SaveManager.set_frenzy_intro_hidden(prev_hidden)
	SceneManager.selected_mode = prev_selected


func _test_frenzy_low_gravity_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	var normal_fruit := _spawn_test_fruit(board, 1, Vector2(-80.0, GameBoard.DROP_Y), FruitProperty.Type.NONE, Vector2(0.0, 40.0))
	var low_grav := _spawn_test_fruit(board, 1, Vector2(80.0, GameBoard.DROP_Y), FruitProperty.Type.LOW_GRAVITY, Vector2(0.0, GameBoard.LOW_GRAVITY_DROP_VY))
	_assert(is_equal_approx(low_grav.gravity_scale, Fruit.LOW_GRAVITY_SCALE), "Low Gravity fruit must activate with reduced gravity_scale")

	for _i in range(30):
		await get_tree().physics_frame

	_assert(low_grav.position.y > GameBoard.DROP_Y + 5.0, "Low Gravity fruit must still fall downward")
	_assert(low_grav.position.y < normal_fruit.position.y - 80.0, "Low Gravity fruit must fall much slower than normal fruit (low_grav=%f, normal=%f)" % [low_grav.position.y, normal_fruit.position.y])

	# Merging clears LOW_GRAVITY and restores normal gravity_scale
	var partner := _spawn_test_fruit(board, 1, low_grav.position + Vector2(low_grav.radius * 1.8, 0.0), FruitProperty.Type.NONE)
	board._on_fruit_merge_contact(low_grav, partner)
	await get_tree().process_frame
	var merged_found: Fruit = null
	for f in board.fruit_pool.active_fruits:
		if f.level == 2:
			merged_found = f
			break
	_assert(merged_found != null and merged_found.fruit_property == FruitProperty.Type.NONE, "Merged Low Gravity fruit must become NONE property")
	if merged_found != null:
		_assert(is_equal_approx(merged_found.gravity_scale, 1.0), "Merged fruit must restore gravity_scale == 1.0")

	board.queue_free()


func _test_frenzy_shadow_property() -> void:
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.set_game_mode(GameMode.Mode.FRENZY)

	# Level 2 (Strawberry) Shadow + Level 2 Normal -> Level 3 (Grape) + 2x Level 2 (Strawberry) shot to each side
	var s1 := _spawn_test_fruit(board, 2, Vector2(-20.0, 680.0), FruitProperty.Type.SHADOW)
	var s2 := _spawn_test_fruit(board, 2, Vector2(20.0, 680.0), FruitProperty.Type.NONE)
	board._on_fruit_merge_contact(s1, s2)
	await get_tree().process_frame

	_assert(board.fruit_pool.active_fruits.size() == 3, "Shadow merge must leave 1 upgraded fruit + 2 side-shot fruits, got %d" % board.fruit_pool.active_fruits.size())
	var level3_count := 0
	var level2_shots: Array[Fruit] = []
	for f in board.fruit_pool.active_fruits:
		_assert(f.fruit_property == FruitProperty.Type.NONE, "Upgraded and shadow-shot fruits must have NONE property")
		if f.level == 3:
			level3_count += 1
		elif f.level == 2:
			level2_shots.append(f)

	_assert(level3_count == 1, "Shadow merge of level 2 must produce one level 3 fruit")
	_assert(level2_shots.size() == 2, "Shadow merge of level 2 must shoot two level 2 fruits")
	if level2_shots.size() == 2:
		var vxs := [level2_shots[0].linear_velocity.x, level2_shots[1].linear_velocity.x]
		vxs.sort()
		_assert(vxs[0] < -100.0 and vxs[1] > 100.0, "Shadow-shot fruits must launch toward opposite left/right sides, got %s" % str(vxs))

	var expected_score := FruitRegistry.catalog.get_fruit(3).score
	_assert(board.score == expected_score, "Shadow merge must award level 3 merge score (%d), got %d" % [expected_score, board.score])

	board.queue_free()


func _test_skin_system() -> void:
	var prev_skin := FruitRegistry.active_skin_id
	var prev_unlocked := SaveManager.get_unlocked_skins()
	var catalog := FruitRegistry.catalog
	var skins := FruitRegistry.skins

	SaveManager.set_unlocked_skins(PackedStringArray(["classic"]))
	FruitRegistry.set_skin("classic", false)

	_assert(skins.get_count() == 3, "Expected 3 skins, got %d" % skins.get_count())
	for sid in ["classic", "rotten", "livestock"]:
		_assert(skins.has_skin(sid), "Missing skin '%s' in SkinCatalog" % sid)

	_assert(FruitRegistry.is_skin_unlocked("classic"), "Classic skin must be unlocked by default")
	_assert(not FruitRegistry.is_skin_unlocked("rotten"), "Rotten skin must start locked")
	_assert(not FruitRegistry.is_skin_unlocked("livestock"), "Livestock skin must start locked")
	_assert(not FruitRegistry.set_skin("rotten", true), "Equipping locked skin 'rotten' must fail")
	_assert(FruitRegistry.active_skin_id == "classic", "Locked skin rejection must keep active_skin_id == 'classic'")

	# SkinModal rewarded-ad unlock flow (skipped, failed, earned)
	var modal := SkinModal.new()
	add_child(modal)
	await get_tree().process_frame
	_assert(modal.get_card_count() == skins.get_count(), "SkinModal card count must match SkinCatalog count")
	modal.open()
	_assert(modal.is_open(), "SkinModal must report is_open() == true after open()")
	await get_tree().process_frame

	var rotten_entry := modal._find_card_entry("rotten")
	var rotten_btn: Button = rotten_entry["button"]
	var rotten_badge_lbl: Label = rotten_entry["badge_label"]
	_assert(rotten_badge_lbl.text == Loc.t("skin.watch_ad"), "Locked skin card must show 'Watch Ad' badge")

	AdManager.set_test_rewarded_handler(func(ctx: String) -> void:
		AdManager.rewarded_ad_closed.emit(ctx, false)
	)
	rotten_btn.pressed.emit()
	await get_tree().process_frame
	_assert(not FruitRegistry.is_skin_unlocked("rotten"), "Skipped rewarded ad must keep 'rotten' locked")
	_assert(modal._status_label.visible and modal._status_label.text == Loc.t("skin.ad_skipped"), "Skipped ad must show skip message")

	AdManager.set_test_rewarded_handler(func(ctx: String) -> void:
		AdManager.rewarded_ad_failed.emit(ctx, "no fill")
	)
	rotten_btn.pressed.emit()
	await get_tree().process_frame
	_assert(not FruitRegistry.is_skin_unlocked("rotten"), "Failed rewarded ad must keep 'rotten' locked")
	_assert(modal._status_label.visible and modal._status_label.text == Loc.t("skin.ad_unavailable"), "Failed ad must show unavailable message")

	AdManager.set_test_rewarded_handler(func(ctx: String) -> void:
		AdManager.rewarded_ad_earned.emit(ctx)
		AdManager.rewarded_ad_closed.emit(ctx, true)
	)
	rotten_btn.pressed.emit()
	await get_tree().process_frame
	_assert(FruitRegistry.is_skin_unlocked("rotten") and SaveManager.is_skin_unlocked("rotten"), "Completed rewarded ad must unlock 'rotten' in SaveManager")
	_assert(FruitRegistry.active_skin_id == "rotten", "Unlocking via rewarded ad must equip 'rotten'")
	_assert(rotten_badge_lbl.text == Loc.t("skin.equipped"), "Unlocked & equipped card must show 'Equipped' badge")
	AdManager.set_test_rewarded_handler(Callable())

	modal.close()
	_assert(not modal.is_open(), "SkinModal must report is_open() == false after close()")
	modal.queue_free()

	# Unlock livestock for asset & live-refresh verification
	FruitRegistry.unlock_skin("livestock")
	_assert(FruitRegistry.is_skin_unlocked("livestock"), "unlock_skin('livestock') must unlock it")

	# Verify every skin has all 15 AtlasTextures matching classic dimensions, 4x scale, and non-empty palettes
	var classic_def := skins.get_skin("classic")
	for sid in ["classic", "rotten", "livestock"]:
		var skin := skins.get_skin(sid)
		FruitRegistry.set_skin(sid, false)
		for i in range(catalog.get_count()):
			var raw := skin.load_texture(i)
			_assert(raw is AtlasTexture, "Skin '%s' level %d must load an AtlasTexture" % [sid, i])
			var classic_raw := classic_def.load_texture(i)
			if raw is AtlasTexture and classic_raw is AtlasTexture:
				var sz := (raw as AtlasTexture).region.size
				var c_sz := (classic_raw as AtlasTexture).region.size
				_assert(sz == c_sz, "Skin '%s' level %d region size %s must match classic %s" % [sid, i, sz, c_sz])
			_assert(FruitRegistry.textures.get_texture(i) != null, "Skin '%s' baked texture missing for level %d" % [sid, i])
			_assert(is_equal_approx(FruitRegistry.textures.get_sprite_scale(i), 4.0), "Skin '%s' level %d scale must be 4.0" % [sid, i])
			_assert(not FruitRegistry.textures.get_palette(i).is_empty(), "Skin '%s' level %d palette must not be empty" % [sid, i])

	# Invalid skin id must be rejected without changing active skin
	FruitRegistry.set_skin("classic", false)
	var invalid_ok := FruitRegistry.set_skin("nonexistent", false)
	_assert(not invalid_ok, "set_skin('nonexistent') must return false")
	_assert(FruitRegistry.active_skin_id == "classic", "Invalid set_skin must not change active_skin_id")

	# Signal emission and persistence
	var signal_ids: Array[String] = []
	var on_changed := func(new_id: String) -> void: signal_ids.append(new_id)
	FruitRegistry.skin_changed.connect(on_changed)

	var switched := FruitRegistry.set_skin("rotten", true)
	_assert(switched, "Switching from classic to rotten should return true")
	_assert(signal_ids == ["rotten"], "skin_changed must emit ['rotten'], got %s" % str(signal_ids))
	_assert(SaveManager.get_skin_id() == "rotten", "SaveManager.get_skin_id() must persist 'rotten'")

	FruitRegistry.skin_changed.disconnect(on_changed)

	# Live refresh on GameBoard (active fruit + dropper)
	FruitRegistry.set_skin("classic", false)
	var board := GameBoard.new()
	add_child(board)
	await get_tree().process_frame

	var live_fruit := _spawn_test_fruit(board, 0, Vector2(0.0, 720.0))
	FruitRegistry.set_skin("livestock", false)
	var fruit_tex := live_fruit._sprite.texture as AtlasTexture
	var dropper_tex := board.dropper._sprite.texture as AtlasTexture
	_assert(fruit_tex != null and fruit_tex.atlas != null and fruit_tex.atlas.resource_path == "res://assets/skins/livestock/suika_livestock_spritesheet.png", "Active fruit sprite must live-update to livestock spritesheet")
	_assert(dropper_tex != null and dropper_tex.atlas != null and dropper_tex.atlas.resource_path == "res://assets/skins/livestock/suika_livestock_spritesheet.png", "Dropper sprite must live-update to livestock spritesheet")
	board.queue_free()

	# Restore original unlocked skins and skin preference
	SaveManager.set_unlocked_skins(prev_unlocked)
	if FruitRegistry.is_skin_unlocked(prev_skin):
		FruitRegistry.set_skin(prev_skin, true)
	else:
		FruitRegistry.set_skin(SkinCatalog.DEFAULT_SKIN_ID, true)
	if SaveManager.get_skin_id() != prev_skin:
		SaveManager.set_skin_id(prev_skin)


func _test_ad_manager_and_banner_layout() -> void:
	_assert(AdManager != null, "AdManager autoload must exist")
	_assert(AdManager.process_mode == Node.PROCESS_MODE_ALWAYS, "AdManager must stay active while paused")
	_assert(not AdManager.get_banner_ad_unit_id().is_empty(), "Banner ad unit ID must not be empty")
	_assert(not AdManager.get_rewarded_ad_unit_id().is_empty(), "Rewarded ad unit ID must not be empty")

	AdManager.set_simulated_banner_height_pixels(0)
	var menu_scene := (ResourceLoader.load(SceneManager.MENU_SCENE) as PackedScene).instantiate()
	var game_scene := (ResourceLoader.load(SceneManager.GAME_SCENE) as PackedScene).instantiate()
	add_child(menu_scene)
	add_child(game_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var menu_top_0: int = menu_scene._safe_margin.get_theme_constant("margin_top")
	var game_top_0: int = game_scene._top_margin.get_theme_constant("margin_top")
	var hud_bottom_0: float = game_scene._top_hud_bottom
	var board_y_0: float = game_scene._board.position.y

	AdManager.set_simulated_banner_height_pixels(100)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(menu_scene._safe_margin.get_theme_constant("margin_top") > menu_top_0, "Menu top margin must shift down when top banner is active")
	_assert(game_scene._top_margin.get_theme_constant("margin_top") > game_top_0, "Game HUD top margin must shift down when top banner is active")
	_assert(game_scene._top_hud_bottom > hud_bottom_0, "Game HUD bottom bound must expand for top banner")
	_assert(game_scene._board.position.y > board_y_0, "GameBoard Y must shift down when top banner is active")

	AdManager.set_simulated_banner_height_pixels(-1)
	menu_scene.queue_free()
	game_scene.queue_free()
	await get_tree().process_frame


func _test_localization_and_language_modal() -> void:
	var prev_lang := Loc.language
	var prev_saved := SaveManager.get_language()

	var expected_langs: Array[String] = ["en", "id", "ru", "ja", "sk", "cs", "pl", "ms"]
	_assert(Loc.LANGUAGES.size() == expected_langs.size(), "Expected %d languages, got %d" % [expected_langs.size(), Loc.LANGUAGES.size()])
	for code in expected_langs:
		_assert(Loc.LANGUAGES.has(code), "Missing language code '%s' in Loc.LANGUAGES" % code)
		_assert(not Loc.get_language_name(code).is_empty(), "Missing display name for '%s'" % code)
		_assert(not Loc.get_language_subtitle(code).is_empty(), "Missing subtitle for '%s'" % code)

	# Key parity & printf placeholder parity against English
	var en_table := Loc.get_strings("en")
	var placeholder_re := RegEx.new()
	placeholder_re.compile("%(?:\\.\\d+)?[sdf]")
	for code in expected_langs:
		var table := Loc.get_strings(code)
		for key in en_table.keys():
			_assert(table.has(key), "Language '%s' missing translation key '%s'" % [code, key])
			if table.has(key):
				var val := String(table[key])
				_assert(not val.is_empty(), "Language '%s' has empty string for key '%s'" % [code, key])
				var en_ph: Array[String] = []
				for m in placeholder_re.search_all(String(en_table[key])):
					en_ph.append(m.get_string())
				var tr_ph: Array[String] = []
				for m in placeholder_re.search_all(val):
					tr_ph.append(m.get_string())
				_assert(tr_ph == en_ph, "Placeholder mismatch in '%s' key '%s': expected %s, got %s" % [code, key, str(en_ph), str(tr_ph)])

	# Device locale resolution + aliases
	_assert(Loc.resolve_device_language("en") == "en", "Expected 'en' -> 'en'")
	_assert(Loc.resolve_device_language("id") == "id", "Expected 'id' -> 'id'")
	_assert(Loc.resolve_device_language("in") == "id", "Expected legacy 'in' -> 'id'")
	_assert(Loc.resolve_device_language("ru_RU") == "ru", "Expected 'ru_RU' -> 'ru'")
	_assert(Loc.resolve_device_language("ja-JP") == "ja", "Expected 'ja-JP' -> 'ja'")
	_assert(Loc.resolve_device_language("jp") == "ja", "Expected 'jp' -> 'ja'")
	_assert(Loc.resolve_device_language("sk") == "sk", "Expected 'sk' -> 'sk'")
	_assert(Loc.resolve_device_language("cs_CZ") == "cs", "Expected 'cs_CZ' -> 'cs'")
	_assert(Loc.resolve_device_language("cz") == "cs", "Expected 'cz' -> 'cs'")
	_assert(Loc.resolve_device_language("pl") == "pl", "Expected 'pl' -> 'pl'")
	_assert(Loc.resolve_device_language("ms") == "ms", "Expected 'ms' -> 'ms'")
	_assert(Loc.resolve_device_language("zsm") == "ms", "Expected 'zsm' -> 'ms'")
	_assert(Loc.resolve_device_language("xx") == "en", "Expected unknown locale -> 'en'")
	_assert(Loc.resolve_device_language("") == "en", "Expected empty locale -> 'en'")

	# set_language switching, signal emission, persistence, and invalid rejection
	Loc.set_language("en")
	var emitted: Array[String] = []
	var on_lang_changed := func(c: String) -> void: emitted.append(c)
	Loc.language_changed.connect(on_lang_changed)
	_assert(not Loc.set_language("xx"), "Invalid language 'xx' must return false")
	_assert(Loc.language == "en", "Invalid set_language must not alter Loc.language")
	_assert(Loc.set_language("ja"), "Switching en -> ja must return true")
	_assert(emitted == ["ja"], "language_changed must emit ['ja'], got %s" % str(emitted))
	_assert(SaveManager.get_language() == "ja", "SaveManager must persist 'ja'")
	_assert(not Loc.set_language("ja"), "Setting already active language must return false")
	Loc.language_changed.disconnect(on_lang_changed)

	# FlagIcons procedural patterns
	for code in expected_langs:
		_assert(FlagIcons.has_flag(code), "FlagIcons missing support for '%s'" % code)
		var tex := FlagIcons.get_flag(code)
		_assert(tex != null, "FlagIcons returned null texture for '%s'" % code)
		if tex != null:
			var img := tex.get_image()
			_assert(img.get_width() == FlagIcons.FLAG_W and img.get_height() == FlagIcons.FLAG_H, "Flag '%s' size must be %dx%d" % [code, FlagIcons.FLAG_W, FlagIcons.FLAG_H])
			var center_px := img.get_pixel(FlagIcons.FLAG_W / 2, FlagIcons.FLAG_H / 2)
			_assert(center_px.a > 0.9, "Flag '%s' center pixel must be opaque" % code)
	var ru_img := FlagIcons.get_flag("ru").get_image()
	var sk_img := FlagIcons.get_flag("sk").get_image()
	_assert(ru_img.get_pixel(27, 30) != sk_img.get_pixel(27, 30), "Slovakia shield must make its flag visually distinct from Russia")

	# Font fallback coverage across Latin, Polish, Czech/Slovak, Russian, Japanese
	for bold_flag in [false, true]:
		var font := UITheme.get_font(bold_flag)
		for sample_cp in [ord("A"), ord("ł"), ord("č"), ord("П"), ord("あ"), ord("果")]:
			_assert(font.has_char(sample_cp), "Font (bold=%s) missing glyph for U+%04X" % [str(bold_flag), sample_cp])

	# LanguageModal instantiation, card count, open/close, and selection
	Loc.set_language("en")
	var modal := LanguageModal.new()
	add_child(modal)
	await get_tree().process_frame
	_assert(modal.get_card_count() == expected_langs.size(), "LanguageModal card count must match Loc.LANGUAGES")
	modal.open()
	_assert(modal.is_open(), "LanguageModal must report is_open() == true after open()")
	await get_tree().process_frame
	var selected_emits: Array[String] = []
	modal.language_selected.connect(func(c: String) -> void: selected_emits.append(c))
	var ru_entry_btn: Button = modal._card_entries[2]["button"]
	ru_entry_btn.pressed.emit()
	_assert(Loc.language == "ru", "Clicking Russian card must set Loc.language to 'ru'")
	_assert(selected_emits == ["ru"], "LanguageModal must emit language_selected('ru')")
	modal.close()
	_assert(not modal.is_open(), "LanguageModal must report is_open() == false after close()")
	modal.queue_free()

	# Live language switching on Menu scene
	Loc.set_language("en")
	var menu_scene := (ResourceLoader.load(SceneManager.MENU_SCENE) as PackedScene).instantiate()
	add_child(menu_scene)
	await get_tree().process_frame
	Loc.set_language("pl")
	await get_tree().process_frame
	_assert(menu_scene._collection_title.text == Loc.t("menu.collection"), "Menu collection title must live-update to Polish")
	menu_scene.queue_free()

	# Restore original language preference
	Loc._apply(prev_lang)
	if SaveManager.get_language() != prev_saved:
		SaveManager.set_language(prev_saved)


func _test_splash_and_loading_config() -> void:
	var boot_packed := ResourceLoader.load(SceneManager.BOOT_SCENE) as PackedScene
	_assert(boot_packed != null, "Boot scene must load")
	if boot_packed != null:
		var boot := boot_packed.instantiate()
		_assert(boot != null, "Boot scene must instantiate")
		if boot != null:
			_assert(is_equal_approx(boot.SPLASH_DURATION, 3.0), "Boot splash duration must be 3.0s")
			_assert(boot.get_node("%TitleLabel").text == "Galih9", "Boot title must be Galih9")
			_assert(boot.get_node("%GodotLogo").texture != null, "Boot GodotLogo must have a texture")
			_assert(boot.get_node("%IntroPlayer").stream != null, "Boot IntroPlayer must have intro.mp3 stream")
			_assert(boot.get_node("Background").texture is GradientTexture2D, "Boot Background must use GradientTexture2D")
			boot.free()

	var loading_packed := ResourceLoader.load(SceneManager.LOADING_SCENE) as PackedScene
	_assert(loading_packed != null, "Loading scene must load")
	if loading_packed != null:
		var loading := loading_packed.instantiate()
		_assert(loading != null, "Loading scene must instantiate")
		if loading != null:
			_assert(is_equal_approx(loading.FAKE_LOAD_DURATION, 3.0), "Loading fake load duration must be 3.0s")
			_assert(is_equal_approx(loading.compute_post_load_progress(0.0, 0.0), 0.0), "Post-load progress at t=0 must equal start_progress")
			_assert(is_equal_approx(loading.compute_post_load_progress(0.0, 1.5), 0.5), "Post-load progress at t=1.5s must be 0.5")
			_assert(loading.compute_post_load_progress(0.25, 2.5) < 1.0, "Post-load progress before 3.0s must be < 1.0")
			_assert(is_equal_approx(loading.compute_post_load_progress(0.25, 3.0), 1.0), "Post-load progress at t=3.0s must reach 1.0")
			loading.free()


func _test_versioning() -> void:
	# 1. SemVer parsing
	var p1 := AppVersion.parse_semver("1.0.0")
	_assert(p1.valid and p1.major == 1 and p1.minor == 0 and p1.patch == 0, "parse_semver('1.0.0') failed")
	var p2 := AppVersion.parse_semver("2.14.9")
	_assert(p2.valid and p2.major == 2 and p2.minor == 14 and p2.patch == 9, "parse_semver('2.14.9') failed")
	var p3 := AppVersion.parse_semver("v1.2.3")
	_assert(p3.valid and p3.major == 1 and p3.minor == 2 and p3.patch == 3, "parse_semver('v1.2.3') failed")
	var p4 := AppVersion.parse_semver("1.0")
	_assert(p4.valid and p4.major == 1 and p4.minor == 0 and p4.patch == 0, "parse_semver('1.0') failed")
	var p5 := AppVersion.parse_semver("3")
	_assert(p5.valid and p5.major == 3 and p5.minor == 0 and p5.patch == 0, "parse_semver('3') failed")
	var p6 := AppVersion.parse_semver("1.2.3-beta+7")
	_assert(p6.valid and p6.major == 1 and p6.minor == 2 and p6.patch == 3, "parse_semver('1.2.3-beta+7') failed")
	var p_empty := AppVersion.parse_semver("")
	_assert(not p_empty.valid and p_empty.major == 1 and p_empty.minor == 0 and p_empty.patch == 0, "parse_semver('') must fall back to invalid 1.0.0")
	var p_bad := AppVersion.parse_semver("abc")
	_assert(not p_bad.valid and p_bad.major == 1 and p_bad.minor == 0 and p_bad.patch == 0, "parse_semver('abc') must fall back to invalid 1.0.0")

	# 2. Patch bumping
	_assert(AppVersion.bump_patch("1.0.0") == "1.0.1", "bump_patch('1.0.0') must be '1.0.1'")
	_assert(AppVersion.bump_patch("1.0.9") == "1.0.10", "bump_patch('1.0.9') must be '1.0.10'")
	_assert(AppVersion.bump_patch("2.3") == "2.3.1", "bump_patch('2.3') must be '2.3.1'")
	_assert(AppVersion.bump_patch("") == "1.0.1", "bump_patch('') must be '1.0.1'")

	# 3. Runtime ProjectSettings version helpers
	_assert(AppVersion.get_version_string() == "1.0.0", "Expected AppVersion.get_version_string() == '1.0.0', got '%s'" % AppVersion.get_version_string())
	_assert(AppVersion.get_display_version() == "v1.0.0", "Expected AppVersion.get_display_version() == 'v1.0.0', got '%s'" % AppVersion.get_display_version())

	# 4. ConfigFile version/code bumping helper
	var export_plugin_script := load("res://addons/auto_version/auto_version_export_plugin.gd")
	_assert(export_plugin_script != null, "AutoVersionExportPlugin script must load")
	if export_plugin_script != null:
		var cfg_empty_name := ConfigFile.new()
		cfg_empty_name.set_value("preset.0", "name", "Android")
		cfg_empty_name.set_value("preset.0.options", "version/code", 2)
		cfg_empty_name.set_value("preset.0.options", "version/name", "")
		cfg_empty_name.set_value("preset.1", "name", "iOS")
		cfg_empty_name.set_value("preset.1.options", "version/code", 10)
		var bumped_code: int = export_plugin_script.bump_config_file_version_code(cfg_empty_name, "Android", "1.0.1")
		_assert(bumped_code == 3, "Expected bumped code 3, got %d" % bumped_code)
		_assert(cfg_empty_name.get_value("preset.0.options", "version/code") == 3, "Android version/code must bump 2 -> 3")
		_assert(cfg_empty_name.get_value("preset.0.options", "version/name") == "", "Empty version/name must remain empty")
		_assert(cfg_empty_name.get_value("preset.1.options", "version/code") == 10, "Non-matching preset iOS must stay untouched")

		var cfg_with_name := ConfigFile.new()
		cfg_with_name.set_value("preset.0", "name", "Android")
		cfg_with_name.set_value("preset.0.options", "version/code", 4)
		cfg_with_name.set_value("preset.0.options", "version/name", "1.0.0")
		var bumped_code2: int = export_plugin_script.bump_config_file_version_code(cfg_with_name, "Android", "1.0.1")
		_assert(bumped_code2 == 5, "Expected bumped code 5, got %d" % bumped_code2)
		_assert(cfg_with_name.get_value("preset.0.options", "version/code") == 5, "Android version/code must bump 4 -> 5")
		_assert(cfg_with_name.get_value("preset.0.options", "version/name") == "1.0.1", "Non-empty version/name must update to '1.0.1'")

	# 5. Project configuration checks
	var project_cfg := ConfigFile.new()
	_assert(project_cfg.load("res://project.godot") == OK, "project.godot must load as ConfigFile")
	var enabled_plugins: PackedStringArray = project_cfg.get_value("editor_plugins", "enabled", PackedStringArray())
	_assert(enabled_plugins.has("res://addons/auto_version/plugin.cfg"), "res://addons/auto_version/plugin.cfg must be enabled in project.godot")

	var export_cfg := ConfigFile.new()
	_assert(export_cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg must load as ConfigFile")
	var preset_code: Variant = export_cfg.get_value("preset.0.options", "version/code", 0)
	_assert(preset_code is int and int(preset_code) > 0, "export_presets.cfg preset.0.options version/code must be a positive int")

	# 6. Main Menu VersionLabel rendering
	var menu := (ResourceLoader.load(SceneManager.MENU_SCENE) as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	_assert(menu._version_label != null, "Menu must have _version_label")
	if menu._version_label != null:
		_assert(menu._version_label.text == AppVersion.get_display_version(), "Menu version label must match AppVersion.get_display_version()")
		_assert(menu._version_label.visible, "Menu version label must be visible")
	menu.queue_free()
