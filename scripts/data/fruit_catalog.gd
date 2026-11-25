class_name FruitCatalog
extends RefCounted

## Ordered, extensible catalog of fruit tiers, shared physics shapes, and physics material.

var fruits: Array[FruitDefinition] = []
var _shape_cache: Dictionary = {}
var _physics_material: PhysicsMaterial
var _sticky_physics_material: PhysicsMaterial
var _concrete_physics_material: PhysicsMaterial
var _charged_physics_material: PhysicsMaterial


func _init() -> void:
	_physics_material = PhysicsMaterial.new()
	_physics_material.friction = 0.35
	_physics_material.bounce = 0.14

	_sticky_physics_material = PhysicsMaterial.new()
	_sticky_physics_material.friction = 1.0
	_sticky_physics_material.bounce = 0.0

	_concrete_physics_material = PhysicsMaterial.new()
	_concrete_physics_material.friction = 0.8
	_concrete_physics_material.bounce = 0.0

	_charged_physics_material = PhysicsMaterial.new()
	_charged_physics_material.friction = 0.05
	_charged_physics_material.bounce = 0.92

	_populate_defaults()


func _populate_defaults() -> void:
	fruits.clear()
	_shape_cache.clear()

	# 0: Kersen
	_add_default(
		&"kersen", "Kersen", 0, 20.0, 1, 0.6, 40.0,
		Color("#E53935"), Color("#FF6F60"), Color("#43A047"), Color("#8E0000"),
		FruitDefinition.PatternType.KERSEN
	)
	# 1: Dukuh
	_add_default(
		&"dukuh", "Dukuh", 1, 28.0, 3, 1.1, 30.0,
		Color("#E6C280"), Color("#C99E55"), Color("#6D7B3B"), Color("#7D5A2A"),
		FruitDefinition.PatternType.DUKUH
	)
	# 2: Rambutan
	_add_default(
		&"rambutan", "Rambutan", 2, 39.0, 6, 1.9, 18.0,
		Color("#D81B60"), Color("#F06292"), Color("#8BC34A"), Color("#880E4F"),
		FruitDefinition.PatternType.RAMBUTAN
	)
	# 3: Salak
	_add_default(
		&"salak", "Salak", 3, 53.0, 10, 3.2, 12.0,
		Color("#794225"), Color("#A15E38"), Color("#C68B59"), Color("#3E1F10"),
		FruitDefinition.PatternType.SALAK
	)
	# 4: Jambu Biji
	_add_default(
		&"jambu_biji", "Jambu Biji", 4, 72.0, 15, 5.2, 0.0,
		Color("#7CB342"), Color("#AED581"), Color("#F48FB1"), Color("#33691E"),
		FruitDefinition.PatternType.JAMBU_BIJI
	)
	# 5: Manggis
	_add_default(
		&"manggis", "Manggis", 5, 96.0, 21, 8.2, 0.0,
		Color("#5E2375"), Color("#8E44AD"), Color("#7CB342"), Color("#2E0E3B"),
		FruitDefinition.PatternType.MANGGIS
	)
	# 6: Kelapa
	_add_default(
		&"kelapa", "Kelapa", 6, 126.0, 28, 12.5, 0.0,
		Color("#6D4C41"), Color("#8D6E63"), Color("#3E2723"), Color("#3E2723"),
		FruitDefinition.PatternType.KELAPA
	)


func _add_default(
	id: StringName,
	display_name: String,
	level: int,
	radius: float,
	score: int,
	mass: float,
	spawn_weight: float,
	primary: Color,
	secondary: Color,
	accent: Color,
	outline: Color,
	pattern: FruitDefinition.PatternType
) -> void:
	var def := FruitDefinition.new()
	def.id = id
	def.display_name = display_name
	def.level = level
	def.radius = radius
	def.score = score
	def.mass = mass
	def.spawn_weight = spawn_weight
	def.primary_color = primary
	def.secondary_color = secondary
	def.accent_color = accent
	def.outline_color = outline
	def.pattern_type = pattern
	fruits.append(def)


func get_count() -> int:
	return fruits.size()


func get_fruit(level: int) -> FruitDefinition:
	if level < 0 or level >= fruits.size():
		return null
	return fruits[level]


func get_shape(level: int) -> CircleShape2D:
	if _shape_cache.has(level):
		return _shape_cache[level]
	var def := get_fruit(level)
	var shape := CircleShape2D.new()
	shape.radius = def.radius if def != null else 22.0
	_shape_cache[level] = shape
	return shape


func get_physics_material() -> PhysicsMaterial:
	return _physics_material


func get_physics_material_for_property(prop: FruitProperty.Type) -> PhysicsMaterial:
	match prop:
		FruitProperty.Type.STICKY:
			return _sticky_physics_material
		FruitProperty.Type.CONCRETE:
			return _concrete_physics_material
		FruitProperty.Type.CHARGED:
			return _charged_physics_material
		_:
			return _physics_material


func has_next_level(level: int) -> bool:
	return level >= 0 and level + 1 < fruits.size()


func is_max_level(level: int) -> bool:
	return level == fruits.size() - 1


func get_max_merge_bonus(level: int) -> int:
	var def := get_fruit(level)
	if def == null:
		return 0
	return def.score * 2


func pick_random_spawn_level(rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	for def in fruits:
		if def.spawn_weight > 0.0:
			total_weight += def.spawn_weight
	if total_weight <= 0.0:
		return 0
	var roll := rng.randf_range(0.0, total_weight)
	var accum := 0.0
	for def in fruits:
		if def.spawn_weight <= 0.0:
			continue
		accum += def.spawn_weight
		if roll <= accum:
			return def.level
	return 0


func pick_spawn_level_for_unlocked(rng: RandomNumberGenerator, unlocked_levels: Dictionary) -> int:
	var total_weight := 0.0
	for def in fruits:
		if def.spawn_weight > 0.0 and unlocked_levels.get(def.level, false):
			total_weight += def.spawn_weight
	if total_weight <= 0.0:
		return 0
	var roll := rng.randf_range(0.0, total_weight)
	var accum := 0.0
	for def in fruits:
		if def.spawn_weight <= 0.0 or not unlocked_levels.get(def.level, false):
			continue
		accum += def.spawn_weight
		if roll <= accum:
			return def.level
	return 0


func register_fruit(def: FruitDefinition) -> void:
	if def == null:
		return
	var target_level := def.level
	if target_level < 0 or target_level >= fruits.size():
		def.level = fruits.size()
		fruits.append(def)
		_shape_cache.erase(def.level)
	else:
		fruits[target_level] = def
		_shape_cache.erase(target_level)
