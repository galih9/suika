class_name Fruit
extends RigidBody2D

## Pooled circular 2D physics body representing one dropped/merged fruit.

signal merge_contact(fruit_a: Fruit, fruit_b: Fruit)

const POOL_PARKING_POS := Vector2(-5000.0, -5000.0)

var level: int = 0
var radius: float = 20.0
var is_merging: bool = false
var in_pool: bool = true
var is_dropped: bool = false
var has_collided: bool = false
var has_been_below_danger_line: bool = false
var is_breaching_from_below: bool = false
var prev_top_y: float = 0.0
var settled_above_line_time: float = 0.0
var pool_index: int = -1

var _sprite: Sprite2D
var _collision_shape: CollisionShape2D
var _base_sprite_scale: float = 1.0
var _scale_tween: Tween


func _init() -> void:
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 16
	continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	linear_damp = 0.15
	angular_damp = 0.25
	collision_layer = 0
	collision_mask = 0
	freeze = true
	visible = false

	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)

	_collision_shape = CollisionShape2D.new()
	add_child(_collision_shape)

	body_entered.connect(_on_body_entered)


func configure(
	def: FruitDefinition,
	shape: CircleShape2D,
	tex: Texture2D,
	phys_mat: PhysicsMaterial,
	sprite_scale: float
) -> void:
	level = def.level
	radius = def.radius
	mass = def.mass
	physics_material_override = phys_mat
	_collision_shape.shape = shape
	_sprite.texture = tex
	_base_sprite_scale = sprite_scale
	_sprite.scale = Vector2(sprite_scale, sprite_scale)


func activate(
	pos: Vector2,
	lin_vel: Vector2,
	from_merge: bool,
	danger_line_y: float,
	parent_was_below: bool = false
) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

	position = pos
	rotation = 0.0
	linear_velocity = lin_vel
	angular_velocity = 0.0
	collision_layer = 1
	collision_mask = 3
	freeze = false
	sleeping = false
	visible = true

	if is_inside_tree():
		var rid := get_rid()
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, lin_vel)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
		reset_physics_interpolation()

	in_pool = false
	is_merging = false
	is_dropped = true
	has_collided = from_merge
	is_breaching_from_below = false
	settled_above_line_time = 0.0

	if from_merge:
		has_been_below_danger_line = parent_was_below or (pos.y >= danger_line_y - radius)
		prev_top_y = maxf(danger_line_y, pos.y - radius)
		_sprite.scale = Vector2(_base_sprite_scale * 0.55, _base_sprite_scale * 0.55)
		if is_inside_tree():
			_scale_tween = create_tween()
			_scale_tween.tween_property(
				_sprite,
				"scale",
				Vector2(_base_sprite_scale, _base_sprite_scale),
				0.14
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_sprite.scale = Vector2(_base_sprite_scale, _base_sprite_scale)
	else:
		has_been_below_danger_line = false
		prev_top_y = pos.y - radius
		_sprite.scale = Vector2(_base_sprite_scale, _base_sprite_scale)


func deactivate_to_pool() -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
		_scale_tween = null

	in_pool = true
	is_dropped = false
	is_merging = false
	has_collided = false
	has_been_below_danger_line = false
	is_breaching_from_below = false
	settled_above_line_time = 0.0

	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	position = POOL_PARKING_POS
	rotation = 0.0

	if is_inside_tree():
		var rid := get_rid()
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		reset_physics_interpolation()


func _on_body_entered(body: Node) -> void:
	if in_pool or is_merging or not is_dropped:
		return
	has_collided = true
	if body is Fruit:
		var other := body as Fruit
		if other == self or other.in_pool or other.is_merging or not other.is_dropped:
			return
		if other.level == level:
			merge_contact.emit(self, other)
