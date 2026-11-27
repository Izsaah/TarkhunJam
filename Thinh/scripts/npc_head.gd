extends CharacterBody2D

const _bodyPartScene = preload("res://Thinh/scenes/body.tscn")
const _tailPartScene = preload("res://Thinh/scenes/tail.tscn")
const _bodyDistance: int = 5

# 7 Bullet types
const BULLET_SCENES = [
	preload("res://Thinh/scenes/bullet/black.tscn"),
	preload("res://Thinh/scenes/bullet/white.tscn"),
	preload("res://Thinh/scenes/bullet/blue.tscn"),
	preload("res://Thinh/scenes/bullet/green.tscn"),
	preload("res://Thinh/scenes/bullet/red.tscn"),
	preload("res://Thinh/scenes/bullet/yellow.tscn"),
	preload("res://Thinh/scenes/bullet/orange.tscn")
]

# Shooting Settings
@export var shoot_interval_min: float = 1.8
@export var shoot_interval_max: float = 3.5
@export var shoot_range: float = 600.0
@export var one_shot_chance: float = 0.01

# Body Settings
@export var min_body_parts: int = 6
@export var max_body_parts: int = 20

# AI Configuration
@export var player_head: CharacterBody2D = null
@export var base_speed: float = 170.0
@export var boost_speed: float = 260.0
@export var turn_speed: float = 5.0
@export var lead_distance: float = 130.0
@export var attack_range: float = 320.0
@export var avoid_distance: float = 90.0
@export_flags_2d_physics var danger_mask: int = 1

# Collision Radii
const HEAD_COLLISION_RADIUS: float = 23.0
const BODY_COLLISION_RADIUS: float = 18.0

var _bodyPartCount: int
var _scaleY: float = 0.8
var _bodyParts: Array = []
var _positionsHistory: Array = []
var _movementHistory: int

var _current_speed: float = base_speed
var _last_player_pos: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO
var _is_dead: bool = false
var _shoot_timer: float = 0.0

func _ready():
	_find_player()
	_setup_eat_area()

	_shoot_timer = randf_range(shoot_interval_min, shoot_interval_max)
	_bodyPartCount = randi_range(min_body_parts, max_body_parts)
	_movementHistory = (_bodyPartCount + 2) * _bodyDistance

	var back_dir = -Vector2.RIGHT.rotated(rotation)
	for i in range(_movementHistory + 10):
		var step_back = (_movementHistory + 10 - 1 - i)
		var trail_pos = global_position + back_dir * (step_back * _bodyDistance)
		_positionsHistory.push_back({pos = trail_pos, rot = rotation})

	CreateSnakeParts()
	UpdateBodyParts()

func _physics_process(delta):
	if _is_dead:
		return

	if not is_instance_valid(player_head):
		_find_player()
		if not is_instance_valid(player_head):
			return

	# 1. AI Movement
	_move_ai(delta)

	# 2. Shooting
	_process_shooting(delta)

	# 3. Record trail & update body parts
	_positionsHistory.push_back({pos = global_position, rot = rotation})
	if _positionsHistory.size() > _movementHistory:
		_positionsHistory.pop_front()
	UpdateBodyParts()

	_check_all_collisions()

# --- SHOOTING LOGIC ---

func _process_shooting(delta: float):
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = randf_range(shoot_interval_min, shoot_interval_max)
		if global_position.distance_to(player_head.global_position) <= shoot_range:
			_fire_bullet()

func _fire_bullet():
	# Pick 1 of 7 bullets randomly
	var bullet_scene: PackedScene = BULLET_SCENES.pick_random()
	var bullet = bullet_scene.instantiate()

	# 10% chance to one-shot
	var is_fatal: bool = randf() < one_shot_chance
	bullet.set("is_one_shot", is_fatal)

	# Spawn in front of the head and aim towards the player
	var shoot_dir = (player_head.global_position - global_position).normalized()
	bullet.global_position = global_position + shoot_dir * 28.0
	bullet.global_rotation = shoot_dir.angle()

	# Add to main scene root so bullet travels freely
	get_tree().current_scene.add_child(bullet)

# --- EATING & GROWING ---

func _setup_eat_area():
	var eat_area = Area2D.new()
	eat_area.name = "EatDetector"
	eat_area.collision_layer = 0
	eat_area.collision_mask = 2
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	eat_area.add_child(shape)
	
	add_child(eat_area)
	eat_area.area_entered.connect(_on_food_touched)

func _on_food_touched(area: Area2D):
	if area.collision_layer & 2 or "food" in area.name.to_lower():
		grow.call_deferred(1)
		if area.has_method("consume"):
			area.consume()
		elif area.has_method("collect"):
			area.collect()
		else:
			area.queue_free()

func grow(amount: int = 1):
	for a in range(amount):
		_bodyPartCount += 1
		_movementHistory = (_bodyPartCount + 2) * _bodyDistance

		var bodyPart = _bodyPartScene.instantiate()
		bodyPart.top_level = true
		bodyPart.visible = true
		add_child(bodyPart)

		if _bodyParts.size() > 0:
			_bodyParts.insert(1, bodyPart)
		else:
			_bodyParts.append(bodyPart)

		bodyPart.scale = Vector2(1, _scaleY)
		_scaleY = min(_scaleY + 0.01, 1.0)

func grow_worm(amount: int = 1):
	grow.call_deferred(amount)

# --- COLLISION LOGIC ---

func _check_all_collisions():
	if not is_instance_valid(player_head):
		return

	var dist_to_player_head = global_position.distance_to(player_head.global_position)

	# Head-to-Head: Both die
	if dist_to_player_head <= HEAD_COLLISION_RADIUS:
		_kill_player()
		die()
		return

	# NPC Head hits Player Body/Tail: NPC dies
	if "body_parts" in player_head:
		for part in player_head.body_parts:
			if is_instance_valid(part) and global_position.distance_to(part.global_position) <= BODY_COLLISION_RADIUS:
				die()
				return

	if "tail_pivot" in player_head:
		var tail = player_head.tail_pivot
		if is_instance_valid(tail) and global_position.distance_to(tail.global_position) <= BODY_COLLISION_RADIUS:
			die()
			return

	# Player Head hits NPC Body/Tail: Player dies
	for part in _bodyParts:
		if is_instance_valid(part) and player_head.global_position.distance_to(part.global_position) <= BODY_COLLISION_RADIUS:
			_kill_player()
			return

func _kill_player():
	if not is_instance_valid(player_head):
		return
	if player_head.has_method("die"):
		player_head.die()
	else:
		player_head.queue_free()

func die():
	if _is_dead:
		return
	_is_dead = true
	for part in _bodyParts:
		if is_instance_valid(part):
			part.queue_free()
	_bodyParts.clear()
	queue_free()

func _find_player():
	if is_instance_valid(player_head):
		_last_player_pos = player_head.global_position
		return

	var found = get_tree().root.find_child("WormPlayer", true, false)
	if found is CharacterBody2D:
		player_head = found
		_last_player_pos = player_head.global_position

# --- BODY CREATION & UPDATES ---

func CreateSnakeParts():
	AddTailParts()
	var adjustForTailParts = 2
	for i in range(_bodyPartCount - adjustForTailParts):
		AddBodyPart()

func AddTailParts():
	var tailPart = _tailPartScene.instantiate()
	tailPart.top_level = true
	tailPart.visible = true
	add_child(tailPart)
	_bodyParts.append(tailPart)
	tailPart.scale = Vector2(1, _scaleY)

func AddBodyPart():
	var bodyPart = _bodyPartScene.instantiate()
	bodyPart.top_level = true
	bodyPart.visible = true
	add_child(bodyPart)
	_bodyParts.append(bodyPart)
	bodyPart.scale = Vector2(1, _scaleY)
	_scaleY = min(_scaleY + 0.01, 1.0)

func UpdateBodyParts():
	var totalParts = _bodyParts.size()
	for i in range(totalParts):
		var offset = (totalParts - i) * _bodyDistance
		var historyIndex = _positionsHistory.size() - 1 - offset
		if historyIndex >= 0 and historyIndex < _positionsHistory.size():
			var historyPoint = _positionsHistory[historyIndex]
			var bodyPart = _bodyParts[i]
			bodyPart.global_position = historyPoint["pos"]
			bodyPart.global_rotation = historyPoint["rot"]
			bodyPart.visible = true
		elif _positionsHistory.size() > 0:
			var oldest = _positionsHistory[0]
			var bodyPart = _bodyParts[i]
			bodyPart.global_position = oldest["pos"]
			bodyPart.global_rotation = oldest["rot"]
			bodyPart.visible = true

# --- AI MOVEMENT ---

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
	velocity = Vector2.RIGHT.rotated(rotation) * _current_speed
	move_and_slide()

func _get_cutoff_position() -> Vector2:
	var player_dir = _player_velocity.normalized()
	if player_dir == Vector2.ZERO:
		var hp = player_head.get_node_or_null("HeadPivot")
		player_dir = Vector2.RIGHT.rotated(hp.global_rotation) if hp else Vector2.RIGHT.rotated(player_head.global_rotation)

	var intercept_point = player_head.global_position + (player_dir * lead_distance)
	var to_npc = (global_position - player_head.global_position).normalized()
	var side = sign(player_dir.cross(to_npc))
	if side == 0:
		side = 1.0

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
		query.exclude = [get_rid()]
		query.collide_with_areas = false

		var result = space_state.intersect_ray(query)
		if result:
			var weight = 1.0 - (global_position.distance_to(result.position) / avoid_distance)
			avoid_vector -= ray_dir * weight

	return avoid_vector.normalized()
