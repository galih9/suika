class_name FruitCatalog
extends RefCounted

## Ordered, extensible catalog of the 15 sprite-based fruit tiers, shared physics shapes, and physics material.

const SPRITE_PATH_FORMAT := "res://assets/fruit_%d.tres"

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

	# Radius = sprite pixel size * 2 so every fruit renders at a crisp 4x pixel scale
	# (e.g. Blueberry 10px -> 20 radius, Watermelon 64px -> 128 radius).
	# Only the first five tiers are droppable (spawn_weight > 0), like classic Suika.
	_add_default(&"blueberry", "Blueberry", 0, 10, 1, 40.0, Color("#4060D0"))
	_add_default(&"cherry", "Cherry", 1, 12, 3, 30.0, Color("#E02030"))
	_add_default(&"strawberry", "Strawberry", 2, 14, 6, 20.0, Color("#F03050"))
	_add_default(&"grape", "Grape", 3, 16, 10, 12.0, Color("#8040C0"))
	_add_default(&"kiwi", "Kiwi", 4, 18, 15, 8.0, Color("#907030"))
	_add_default(&"lime", "Lime", 5, 20, 21, 0.0, Color("#70C030"))
	_add_default(&"orange", "Orange", 6, 24, 28, 0.0, Color("#F0A020"))
	_add_default(&"persimmon", "Persimmon", 7, 28, 36, 0.0, Color("#F05010"))
	_add_default(&"apple", "Apple", 8, 32, 45, 0.0, Color("#D02030"))
	_add_default(&"pear", "Pear", 9, 36, 55, 0.0, Color("#E0D040"))
	_add_default(&"peach", "Peach", 10, 40, 66, 0.0, Color("#F0A0A0"))
	_add_default(&"dragonfruit", "Dragonfruit", 11, 44, 78, 0.0, Color("#E03080"))
	_add_default(&"pineapple", "Pineapple", 12, 48, 91, 0.0, Color("#F0C020"))
	_add_default(&"melon", "Melon", 13, 56, 105, 0.0, Color("#90D070"))
	_add_default(&"watermelon", "Watermelon", 14, 64, 120, 0.0, Color("#30A040"))


func _add_default(
	id: StringName,
	display_name: String,
	level: int,
	sprite_px: int,
	score: int,
	spawn_weight: float,
	primary: Color
) -> void:
	var def := FruitDefinition.new()
	def.id = id
	def.display_name = display_name
	def.level = level
	def.radius = float(sprite_px) * 2.0
	def.score = score
	# Mass grows a bit slower than area so big fruits stay pushable.
	def.mass = 0.6 * pow(def.radius / 20.0, 1.65)
	def.spawn_weight = spawn_weight
	def.primary_color = primary
	def.secondary_color = primary.lightened(0.25)
	def.accent_color = primary.darkened(0.2)
	def.outline_color = primary.darkened(0.5)
	def.texture = load(SPRITE_PATH_FORMAT % (level + 1)) as Texture2D
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
