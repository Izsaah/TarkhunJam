extends Node2D

const _bodyPartScene = preload("res://Thinh/scenes/body.tscn")
const _tailPartScene = preload("res://Thinh/scenes/tail.tscn")
const _bodyDistance = 4

# Body Randomization
@export var min_body_parts: int = 6
@export var max_body_parts: int = 200

# AI Settings
@export var player_head: Node2D
@export var base_speed: float = 200.0
@export var boost_speed: float = 320.0
@export var turn_speed: float = 4.5
@export var lead_distance: float = 140.0
@export var attack_range: float = 350.0
@export var avoid_distance: float = 120.0
@export_flags_2d_physics var danger_mask: int = 1 # Set to Player body & walls layer

var _bodyPartCount: int
var _scaleY: float = 0.8
var _bodyParts: Array = []
var _positionsHistory: Array = []
var _movementHistory: int

var _current_speed: float = base_speed
var _last_player_pos: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO

func _ready():
	# 1. Setup randomized body
	_bodyPartCount = randi_range(min_body_parts, max_body_parts)
	_movementHistory = (_bodyPartCount + 2) * _bodyDistance
	CreateSnakeParts()

	# 2. Setup AI tracking
	if player_head:
		_last_player_pos = player_head.global_position

func _physics_process(delta):
	# 1. AI Movement
	if is_instance_valid(player_head):
		_move_ai(delta)

	# 2. Record trail & update body parts
	_positionsHistory.push_back({pos = global_position, rot = global_rotation})
	if _positionsHistory.size() > _movementHistory:
		_positionsHistory.pop_front()

	UpdateBodyParts()

# --- BODY LOGIC ---

func CreateSnakeParts():
	AddTailParts()
	var adjustForTailParts = 2
	for i in range(_bodyPartCount - adjustForTailParts):
		AddBodyPart()

func AddTailParts():
	var tailPart = _tailPartScene.instantiate()
	tailPart.top_level = true # Prevents it from moving rigidly with the head
	add_child(tailPart)
	_bodyParts.append(tailPart)
	tailPart.scale = Vector2(1, _scaleY)

func AddBodyPart():
	var bodyPart = _bodyPartScene.instantiate()
	bodyPart.top_level = true # Prevents it from moving rigidly with the head
	add_child(bodyPart)
	_bodyParts.append(bodyPart)
	bodyPart.scale = Vector2(1, _scaleY)
	_scaleY = min(_scaleY + 0.01, 1.0)

func UpdateBodyParts():
	var totalParts = _bodyParts.size()
	for i in range(totalParts):
		var offset = (totalParts - i) * _bodyDistance
		var historyIndex = _positionsHistory.size() - 1 - offset
		if historyIndex >= 0:
			var historyPoint = _positionsHistory[historyIndex]
			var bodyPart = _bodyParts[i]
			bodyPart.global_position = historyPoint["pos"]
			bodyPart.global_rotation = historyPoint["rot"]
			bodyPart.visible = true

# --- AI LOGIC ---

func _move_ai(delta):
	_player_velocity = (player_head.global_position - _last_player_pos) / delta
	_last_player_pos = player_head.global_position

	var avoid_dir = _get_avoidance_direction()
	var desired_angle: float

	if avoid_dir != Vector2.ZERO:
		desired_angle = avoid_dir.angle()
		_current_speed = base_speed
	else:
		var target_pos = _get_cutoff_position()
		desired_angle = (target_pos - global_position).angle()
		var dist = global_position.distance_to(target_pos)
		_current_speed = boost_speed if (dist < attack_range and dist > 40.0) else base_speed

	rotation = rotate_toward(rotation, desired_angle, turn_speed * delta)
	position += Vector2.RIGHT.rotated(rotation) * _current_speed * delta

func _get_cutoff_position() -> Vector2:
	var player_dir = _player_velocity.normalized()
	if player_dir == Vector2.ZERO:
		player_dir = Vector2.RIGHT.rotated(player_head.global_rotation)

	var intercept_point = player_head.global_position + (player_dir * lead_distance)
	var to_npc = (global_position - player_head.global_position).normalized()
	var side = sign(player_dir.cross(to_npc))
	if side == 0:
		side = 1
		
	return intercept_point + player_dir.orthogonal() * (-side * 50.0)

func _get_avoidance_direction() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var ray_angles = [-1.05, -0.52, 0.0, 0.52, 1.05]
	var avoid_vector = Vector2.ZERO

	for angle_offset in ray_angles:
		var ray_dir = Vector2.RIGHT.rotated(rotation + angle_offset)
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + ray_dir * avoid_distance,
			danger_mask
		)
		var result = space_state.intersect_ray(query)
		if result:
			var weight = 1.0 - (global_position.distance_to(result.position) / avoid_distance)
			avoid_vector -= ray_dir * weight

	return avoid_vector.normalized()