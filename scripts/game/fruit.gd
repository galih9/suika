class_name Fruit
extends RigidBody2D

## Pooled circular 2D physics body representing one dropped/merged fruit.

signal merge_contact(fruit_a: Fruit, fruit_b: Fruit)
signal sticky_contact(fruit: Fruit, target: Node)
signal charged_bounced(fruit: Fruit, other: Node)

const POOL_PARKING_POS := Vector2(-5000.0, -5000.0)
const BOMB_DURATION := 10.0
const CONCRETE_FALL_GRAVITY_SCALE := 1.35
const LAYER_FRUIT := 1
const LAYER_JAR := 2
const LAYER_CONCRETE_FALLING := 4

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

var fruit_property: FruitProperty.Type = FruitProperty.Type.NONE
var is_stuck: bool = false
var has_used_sticky: bool = false
var stuck_target: Fruit = null
var stuck_local_angle: float = 0.0
var stuck_rel_rotation: float = 0.0
var bomb_timer: float = 0.0
var concrete_landed: bool = false
var concrete_hit_floor: bool = false
var prev_pos: Vector2 = Vector2.ZERO
var charged_bounce_cooldown: float = 0.0

var _sprite: Sprite2D
var _overlay: FruitPropertyOverlay
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

	_overlay = FruitPropertyOverlay.new()
	_overlay.bind_target(_sprite)
	add_child(_overlay)

	_collision_shape = CollisionShape2D.new()
	add_child(_collision_shape)

	body_entered.connect(_on_body_entered)


func is_concrete_crushing() -> bool:
	return (
		fruit_property == FruitProperty.Type.CONCRETE
		and not concrete_landed
		and is_dropped
		and not in_pool
	)


func configure(
	def: FruitDefinition,
	shape: CircleShape2D,
	tex: Texture2D,
	phys_mat: PhysicsMaterial,
	sprite_scale: float,
	prop: FruitProperty.Type = FruitProperty.Type.NONE
) -> void:
	level = def.level
	radius = def.radius
	mass = def.mass
	fruit_property = prop
	physics_material_override = phys_mat
	_collision_shape.shape = shape
	_sprite.texture = tex
	_base_sprite_scale = sprite_scale
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_overlay.configure(prop, def.radius, false)


func refresh_texture(tex: Texture2D, sprite_scale: float) -> void:
	_sprite.texture = tex
	_base_sprite_scale = sprite_scale
	if _scale_tween == null or not _scale_tween.is_valid():
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

	# Pooled fruits sit frozen, and frozen bodies never get contact updates from the physics
	# server, so the contact list still holds the neighbours from this fruit's previous life
	# (somewhere deep in the jar). Without this reset, a freshly dropped fruit could "touch" a
	# far-away fruit of the same level on its first tick and merge/stick with it instantly,
	# which looked like the fruit teleporting instead of falling. Re-arming the monitor clears it.
	contact_monitor = false
	contact_monitor = true

	is_stuck = false
	has_used_sticky = false
	stuck_target = null
	stuck_local_angle = 0.0
	stuck_rel_rotation = 0.0
	bomb_timer = 0.0
	concrete_landed = false
	concrete_hit_floor = false
	prev_pos = pos
	charged_bounce_cooldown = 0.0

	var target_layer := LAYER_FRUIT
	var target_mask := LAYER_FRUIT | LAYER_JAR
	var target_gravity := 1.0
	var target_lin_damp := 0.15
	var target_ang_damp := 0.25
	var target_can_sleep := true

	if fruit_property == FruitProperty.Type.BOMB:
		bomb_timer = BOMB_DURATION
	elif fruit_property == FruitProperty.Type.CONCRETE:
		if from_merge:
			concrete_landed = true
		else:
			target_layer = LAYER_CONCRETE_FALLING
			target_mask = LAYER_JAR
			target_gravity = CONCRETE_FALL_GRAVITY_SCALE
	elif fruit_property == FruitProperty.Type.CHARGED:
		target_lin_damp = 0.01
		target_ang_damp = 0.05
		target_can_sleep = false

	position = pos
	rotation = 0.0
	linear_velocity = lin_vel
	angular_velocity = 0.0
	collision_layer = target_layer
	collision_mask = target_mask
	gravity_scale = target_gravity
	linear_damp = target_lin_damp
	angular_damp = target_ang_damp
	can_sleep = target_can_sleep
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
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

	_overlay.bomb_timer = bomb_timer
	_overlay.concrete_landed = concrete_landed
	_overlay.is_stuck = false

	if from_merge:
		has_been_below_danger_line = parent_was_below or (pos.y >= danger_line_y - radius)
		prev_top_y = maxf(danger_line_y, pos.y - radius)
		_sprite.scale = Vector2(_base_sprite_scale * 0.55, _base_sprite_scale * 0.55)
		if is_inside_tree():
			# Pop in with a quick white flash so every merge feels punchy.
			_sprite.self_modulate = Color(2.4, 2.4, 2.4, 1.0)
			_scale_tween = create_tween().set_parallel(true)
			_scale_tween.tween_property(
				_sprite,
				"scale",
				Vector2(_base_sprite_scale, _base_sprite_scale),
				0.22
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_scale_tween.tween_property(_sprite, "self_modulate", Color.WHITE, 0.2)
		else:
			_sprite.scale = Vector2(_base_sprite_scale, _base_sprite_scale)
			_sprite.self_modulate = Color.WHITE
	else:
		has_been_below_danger_line = false
		prev_top_y = pos.y - radius
		_sprite.scale = Vector2(_base_sprite_scale, _base_sprite_scale)
		_sprite.self_modulate = Color.WHITE


func finish_concrete_landing(normal_phys_mat: PhysicsMaterial) -> void:
	concrete_landed = true
	concrete_hit_floor = true
	collision_layer = LAYER_FRUIT
	collision_mask = LAYER_FRUIT | LAYER_JAR
	gravity_scale = 1.0
	physics_material_override = normal_phys_mat
	_overlay.concrete_landed = true


func set_stuck_visual(stuck: bool) -> void:
	_overlay.is_stuck = stuck


func sync_bomb_overlay() -> void:
	_overlay.bomb_timer = bomb_timer


func deactivate_to_pool() -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
		_scale_tween = null
	_sprite.self_modulate = Color.WHITE

	in_pool = true
	is_dropped = false
	is_merging = false
	has_collided = false
	has_been_below_danger_line = false
	is_breaching_from_below = false
	settled_above_line_time = 0.0

	fruit_property = FruitProperty.Type.NONE
	is_stuck = false
	has_used_sticky = false
	stuck_target = null
	stuck_local_angle = 0.0
	stuck_rel_rotation = 0.0
	bomb_timer = 0.0
	concrete_landed = false
	concrete_hit_floor = false
	prev_pos = Vector2.ZERO
	charged_bounce_cooldown = 0.0

	gravity_scale = 1.0
	linear_damp = 0.15
	angular_damp = 0.25
	can_sleep = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	position = POOL_PARKING_POS
	rotation = 0.0
	_overlay.reset()

	if is_inside_tree():
		var rid := get_rid()
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		reset_physics_interpolation()


func _on_body_entered(body: Node) -> void:
	if in_pool or is_merging or not is_dropped:
		return
	if not has_collided:
		# First touch after a drop (merged fruits start with has_collided = true).
		AudioManager.play_fruit_land(level)
	has_collided = true

	if is_concrete_crushing():
		if body.is_in_group(&"jar_floor"):
			concrete_hit_floor = true
		return

	if body is Fruit:
		var other := body as Fruit
		if other == self or other.in_pool or other.is_merging or not other.is_dropped or other.is_concrete_crushing():
			return
		if other.level == level:
			merge_contact.emit(self, other)
			return
		if fruit_property == FruitProperty.Type.STICKY and not has_used_sticky:
			has_used_sticky = true
			sticky_contact.emit(self, other)
		elif fruit_property == FruitProperty.Type.CHARGED:
			charged_bounced.emit(self, other)
	else:
		if fruit_property == FruitProperty.Type.STICKY and not has_used_sticky:
			if body.is_in_group(&"jar_wall") or body.is_in_group(&"jar_floor"):
				has_used_sticky = true
				sticky_contact.emit(self, body)
		elif fruit_property == FruitProperty.Type.CHARGED:
			charged_bounced.emit(self, body)
