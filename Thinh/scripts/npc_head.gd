extends CharacterBody2D

@export var player_head: Node2D # Drag the Player's %Head node here in the Inspector
@export var base_speed: float = 200.0
@export var boost_speed: float = 320.0
@export var turn_speed: float = 4.5 # Radians per second

# AI Tuning
@export var lead_distance: float = 140.0 # How far ahead of the player to aim
@export var attack_range: float = 350.0  # Distance to trigger boost for a cut-off
@export var avoid_distance: float = 120.0 # How far ahead to check for obstacles
@export_flags_2d_physics var danger_mask: int = 1 # Set to the collision layer of Player body & walls

var _current_speed: float = base_speed
var _last_player_pos: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO

func _ready():
	if player_head:
		_last_player_pos = player_head.global_position

func _physics_process(delta):
	if not is_instance_valid(player_head):
		return

	# 1. Estimate player's movement direction/velocity
	_player_velocity = (player_head.global_position - _last_player_pos) / delta
	_last_player_pos = player_head.global_position

	# 2. Decide target direction: Avoid danger first, otherwise intercept player
	var avoid_dir = _get_avoidance_direction()
	var desired_angle: float

	if avoid_dir != Vector2.ZERO:
		# Danger ahead! Steer away immediately
		desired_angle = avoid_dir.angle()
		_current_speed = base_speed
	else:
		# No immediate danger: calculate cut-off point ahead of the player
		var target_pos = _get_cutoff_position()
		desired_angle = (target_pos - global_position).angle()

		# Boost if we are close enough to swoop in front of them
		var dist_to_target = global_position.distance_to(target_pos)
		if dist_to_target < attack_range and dist_to_target > 40.0:
			_current_speed = boost_speed
		else:
			_current_speed = base_speed

	# 3. Smoothly rotate and move forward
	rotation = rotate_toward(rotation, desired_angle, turn_speed * delta)
	position += Vector2.RIGHT.rotated(rotation) * _current_speed * delta


func _get_cutoff_position() -> Vector2:
	# Predict where the player will be in a moment
	var player_dir = _player_velocity.normalized()
	
	# Fallback if player isn't moving
	if player_dir == Vector2.ZERO:
		player_dir = Vector2.RIGHT.rotated(player_head.rotation)

	# Aim ahead of the player's nose
	var intercept_point = player_head.global_position + (player_dir * lead_distance)

	# Add a slight perpendicular offset so the NPC sweeps ACROSS the player's path
	# instead of driving straight into their face
	var to_npc = (global_position - player_head.global_position).normalized()
	var side = sign(player_dir.cross(to_npc)) # -1 for left, 1 for right
	if side == 0:
		side = 1
		
	var sweep_offset = player_dir.orthogonal() * (-side * 50.0)
	return intercept_point + sweep_offset


func _get_avoidance_direction() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	# Cast 5 rays in a fan in front of the NPC (-60°, -30°, 0°, 30°, 60°)
	var ray_angles = [-1.05, -0.52, 0.0, 0.52, 1.05]
	var avoid_vector = Vector2.ZERO

	for angle_offset in ray_angles:
		var ray_dir = Vector2.RIGHT.rotated(rotation + angle_offset)
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + ray_dir * avoid_distance,
			danger_mask
		)
		# Ignore the NPC's own body parts if they are on the same layer
		query.exclude = [get_parent()] 
		
		var result = space_state.intersect_ray(query)
		if result:
			# Push away from the hit point; closer hits push harder
			var dist = global_position.distance_to(result.position)
			var weight = 1.0 - (dist / avoid_distance)
			avoid_vector -= ray_dir * weight

	return avoid_vector.normalized()