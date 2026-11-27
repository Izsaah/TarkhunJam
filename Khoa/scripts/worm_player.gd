extends CharacterBody2D

signal size_changed(new_size: int)
signal self_collided(segment_index: int)
signal died(reason: String)
signal color_changed(new_color: String)

@export var shoot_cooldown: float = 1.5
@export var cooldown_ui: Control

# Tự va chạm
@export var self_collision_enabled: bool = true
@export var safe_segments: int = 2
@export var self_collision_distance: float = 22.0

var is_dead: bool = false

@export var move_speed: float = 140.0
@export var min_turn_radius: float = 80.0
@export var mouse_dead_zone: float = 8.0

var move_direction: Vector2 = Vector2.RIGHT

# Biến thân giun
@export var segment_count: int = 5
@export var segment_spacing: float = 18.0
@export var history_step: float = 2.0

const BODY_SEGMENT_SCENE: PackedScene = preload("res://Khoa/scenes/worm_segment.tscn")

const COLOR_NAMES: Array[String] = [
	"red", "blue", "green", "yellow", "orange", "white", "black"
]

@export var current_color: String = "red"

@onready var head_pivot: Node2D = $HeadPivot
@onready var head_sprite: Sprite2D = $HeadPivot/HeadSprite
@onready var body_container: Node2D = $BodySegments
@onready var tail_pivot: Node2D = $TailPivot
@onready var tail_sprite: Sprite2D = $TailPivot/TailSprite
@onready var weapon_muzzle: Marker2D = $HeadPivot/WeaponMuzzle

var body_parts: Array[Node2D] = []
var path_history: Array[Vector2] = []
var _textures: Dictionary = {}


func _ready() -> void:
	_preload_all_textures()

	for i in range(segment_count):
		var segment := BODY_SEGMENT_SCENE.instantiate() as Node2D
		body_container.add_child(segment)
		body_parts.append(segment)

	path_history.clear()
	for i in range(250):
		var point := global_position - Vector2.RIGHT * float(i) * history_step
		path_history.append(point)

	_update_body_positions()
	set_color(current_color)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	_update_move_direction(delta)
	velocity = move_direction * move_speed
	head_pivot.global_rotation = move_direction.angle()

	move_and_slide()
	_record_path()
	_update_body_positions()
	_check_self_collision()


func _update_move_direction(delta: float) -> void:
	var mouse_vector := get_global_mouse_position() - global_position
	if mouse_vector.length_squared() <= mouse_dead_zone * mouse_dead_zone:
		return

	var target_angle := mouse_vector.angle()
	var current_angle := move_direction.angle()
	var target_angle_delta := wrapf(target_angle - current_angle, -PI, PI)

	var safe_radius := maxf(min_turn_radius, 1.0)
	var max_angle_change := (move_speed / safe_radius) * delta
	var angle_change := clampf(target_angle_delta, -max_angle_change, max_angle_change)

	move_direction = move_direction.rotated(angle_change).normalized()


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
		int(ceil(((body_parts.size() + 3) * segment_spacing + 64.0) / history_step))
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
		body_parts[i].global_position = _get_position_at_distance(distance)

	var tail_distance := segment_spacing * float(body_parts.size() + 1)
	tail_pivot.global_position = _get_position_at_distance(tail_distance)

	var tail_front := _get_position_at_distance(maxf(0.0, tail_distance - 4.0))
	var tail_back := _get_position_at_distance(tail_distance + 4.0)
	var tail_direction := tail_front - tail_back

	if not tail_direction.is_zero_approx():
		tail_pivot.global_rotation = tail_direction.angle()


func _preload_all_textures() -> void:
	for c in COLOR_NAMES:
		var base := "res://Khoa/assets/worms/%s/%s_worm_" % [c, c]
		_textures[c] = {
			"head": load(base + "head.png") as Texture2D,
			"body": load(base + "body.png") as Texture2D,
			"tail": load(base + "tail.png") as Texture2D
		}


func set_color(color_name: String) -> void:
	var key := color_name.to_lower()
	if not _textures.has(key):
		push_warning("WormPlayer: Unknown color '%s'" % color_name)
		return

	current_color = key
	var tex_set: Dictionary = _textures[key]

	if head_sprite:
		head_sprite.texture = tex_set["head"]
	if tail_sprite:
		tail_sprite.texture = tex_set["tail"]

	for segment in body_parts:
		_apply_body_texture(segment)

	color_changed.emit(current_color)


func cycle_next_color() -> void:
	var current_idx := COLOR_NAMES.find(current_color)
	var next_idx := (current_idx + 1) % COLOR_NAMES.size()
	set_color(COLOR_NAMES[next_idx])


func _apply_body_texture(segment: Node2D) -> void:
	if not _textures.has(current_color) or not is_instance_valid(segment):
		return

	var body_tex: Texture2D = _textures[current_color]["body"]
	if segment is Sprite2D:
		segment.texture = body_tex
	else:
		var spr := segment.find_child("*", true, false)
		if spr is Sprite2D:
			spr.texture = body_tex


func grow_worm(amount: int = 1) -> void:
	if amount <= 0:
		return

	for i in range(amount):
		var segment := BODY_SEGMENT_SCENE.instantiate() as Node2D
		if segment == null:
			push_error("Failed to instantiate WormSegment!")
			return

		_apply_body_texture(segment)
		body_container.add_child(segment)
		body_parts.append(segment)

	_update_body_positions()
	size_changed.emit(body_parts.size())


func _check_self_collision() -> void:
	if not self_collision_enabled or is_dead:
		return

	if body_parts.size() <= safe_segments:
		return

	var head_position: Vector2 = head_pivot.global_position

	for i in range(safe_segments, body_parts.size()):
		var segment: Node2D = body_parts[i]
		if not is_instance_valid(segment):
			continue

		var distance := head_position.distance_to(segment.global_position)
		if distance <= self_collision_distance:
			_handle_self_collision(i)
			return

	if is_instance_valid(tail_pivot):
		var tail_distance := head_position.distance_to(tail_pivot.global_position)
		if tail_distance <= self_collision_distance:
			_handle_self_collision(-1)


func _handle_self_collision(segment_index: int) -> void:
	if is_dead:
		return

	print("WORM SELF COLLISION!")
	print("Hit segment index: ", segment_index)
	self_collided.emit(segment_index)
	_die("self_collision")


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	# Mouse inputs
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if cooldown_ui and not cooldown_ui.is_ready():
				return

			weapon_muzzle.call("shoot_towards", get_global_mouse_position())

			if cooldown_ui:
				cooldown_ui.start_cooldown(shoot_cooldown)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cycle_next_color()

	# Phím 1 đến 7 để chọn trực tiếp màu
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_color("red")
			KEY_2: set_color("blue")
			KEY_3: set_color("green")
			KEY_4: set_color("yellow")
			KEY_5: set_color("orange")
			KEY_6: set_color("white")
			KEY_7: set_color("black")

func take_damage(
	amount: int = 0,
	instant_kill: bool = false,
	source: Node = null
) -> void:
	if is_dead:
		return

	# Ignore damage if the damage source is a bullet matching player color
	if is_instance_valid(source) and "bullet_color" in source:
		if source.bullet_color.to_lower() == current_color.to_lower():
			return

	if body_parts.is_empty():
		_die("bullet")
		return

	var segments_to_remove := body_parts.size() if instant_kill else mini(
		body_parts.size(),
		maxi(0, amount)
	)

	for i in range(segments_to_remove):
		var last_segment: Node2D = body_parts.pop_back()
		if is_instance_valid(last_segment):
			last_segment.queue_free()

	if segments_to_remove == 0:
		return

	_update_body_positions()
	size_changed.emit(body_parts.size())

	if body_parts.is_empty():
		_die("bullet")

func _die(reason: String) -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	print("WORM DIED: ", reason)
	died.emit(reason)