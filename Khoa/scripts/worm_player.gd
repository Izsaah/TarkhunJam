extends CharacterBody2D
signal size_changed(new_size: int)

# biến di chuyển
@export var move_speed: float = 140.0
@export var turn_smoothing: float = 14.0

# biến thân giun
@export var segment_count: int = 5
@export var segment_spacing: float = 18.0
@export var history_step: float = 2.0

# xài thân giun bên scene worm_segment.tscn
const BODY_SEGMENT_SCENE: PackedScene = preload(
    "res://Khoa/scenes/worm_segment.tscn"
)

@onready var head_pivot: Node2D = $HeadPivot
@onready var body_container: Node2D = $BodySegments
@onready var tail_pivot: Node2D = $TailPivot

var body_parts: Array[Node2D] = []
var path_history: Array[Vector2] = []


func _ready() -> void:
	# tạo thân giun
	for i in range(segment_count):
		var segment := BODY_SEGMENT_SCENE.instantiate() as Node2D

		body_container.add_child(segment)
		body_parts.append(segment)

	# thiết lập lưu di chuyển của giun, ban đầu hướng về bên phải
	path_history.clear()

	for i in range(250):
		var point := global_position - Vector2.RIGHT * float(i) * history_step
		path_history.append(point)

	_update_body_positions()


func _physics_process(delta: float) -> void:
	var direction := _get_input_direction()

	# di chuyển đầu giun
	velocity = direction * move_speed
	move_and_slide()

	# xoay đầu
	if direction != Vector2.ZERO:
		var target_angle := direction.angle()

		head_pivot.rotation = lerp_angle(
			head_pivot.rotation,
			target_angle,
			1.0 - exp(-turn_smoothing * delta)
		)

	# lưu lại di chuyển của đầu
	_record_path()

	# cập nhật vị trí thân giun và đuôi
	_update_body_positions()


func _get_input_direction() -> Vector2:
	var direction := Vector2.ZERO

	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0

	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0

	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	return direction.normalized()


func _record_path() -> void:
	if path_history.is_empty():
		return

	var last_point: Vector2 = path_history[0]
	var distance := last_point.distance_to(global_position)

	if distance < history_step:
		return

	var direction := (global_position - last_point).normalized()
	var steps := int(distance / history_step)

	for i in range(1, steps + 1):
		var new_point := last_point + direction * history_step * float(i)
		path_history.push_front(new_point)

	var max_history_points := maxi(
		200,
		int(ceil(
			((body_parts.size() + 3) * segment_spacing + 64.0)
			/ history_step
		))
	)

	while path_history.size() > max_history_points:
		path_history.pop_back()


func _get_position_at_distance(target_distance: float) -> Vector2:
	var remaining := target_distance

	for i in range(path_history.size() - 1):
		var newer: Vector2 = path_history[i]
		var older: Vector2 = path_history[i + 1]

		var segment_length := newer.distance_to(older)

		if segment_length <= 0.001:
			continue

		if remaining <= segment_length:
			var t := remaining / segment_length
			return newer.lerp(older, t)

		remaining -= segment_length

	return path_history.back()


func _update_body_positions() -> void:
	for i in range(body_parts.size()):
		var distance := segment_spacing * float(i + 1)

		body_parts[i].global_position = (
			_get_position_at_distance(distance)
		)

	var tail_distance := segment_spacing * float(body_parts.size() + 1)

	tail_pivot.global_position = (
		_get_position_at_distance(tail_distance)
	)

	var tail_front := _get_position_at_distance(
		maxf(0.0, tail_distance - 4.0)
	)

	var tail_back := _get_position_at_distance(
		tail_distance + 4.0
	)

	var tail_direction := tail_front - tail_back

	if not tail_direction.is_zero_approx():
		tail_pivot.global_rotation = tail_direction.angle()

func grow_worm(amount: int = 1) -> void:
	if amount <= 0:
		return

	for i in range(amount):
		var segment := BODY_SEGMENT_SCENE.instantiate() as Node2D

		if segment == null:
			push_error("Failed to instantiate WormSegment!")
			return

		body_container.add_child(segment)
		body_parts.append(segment)

	_update_body_positions()

	size_changed.emit(body_parts.size())

# hàm test chức năng tăng chiều dài
# func _input(event: InputEvent) -> void:
# 	if event is InputEventKey:
# 		if event.pressed and not event.echo:
# 			if event.physical_keycode == KEY_E:
# 				grow_worm()
# 				print("Worm Size: ", body_parts.size())
