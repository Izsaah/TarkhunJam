extends Node2D

@export var food_scene: PackedScene
@export var worm: Node2D

@export var max_food_count: int = 8
@export var respawn_delay: float = 1.0

# vùng spawn
@export var spawn_min: Vector2 = Vector2(64, 64)
@export var spawn_max: Vector2 = Vector2(736, 536)

# khoảng cách tối thiểu
@export var min_distance_from_worm: float = 96.0
@export var min_distance_between_foods: float = 40.0

@export var max_spawn_attempts: int = 30

var rng := RandomNumberGenerator.new()
var active_foods: Array[Area2D] = []


func _ready() -> void:
	rng.randomize()

	if food_scene == null:
		push_error("FoodSpawner: Food Scene is not assigned!")
		return

	if worm == null:
		push_error("FoodSpawner: Worm reference is missing!")
		return

	if spawn_min.x >= spawn_max.x or spawn_min.y >= spawn_max.y:
		push_error("FoodSpawner: Invalid spawn boundaries!")
		return

	for i in range(max_food_count):
		if not _spawn_food():
			push_warning("FoodSpawner: Could not spawn all initial foods.")
			break


func _spawn_food() -> bool:
	# tìm spawn random
	for attempt in range(max_spawn_attempts):

		var local_position := Vector2(
			rng.randf_range(spawn_min.x, spawn_max.x),
			rng.randf_range(spawn_min.y, spawn_max.y)
		)

		var spawn_position := to_global(local_position)

		if not _is_valid_spawn_position(spawn_position):
			continue

		var food := food_scene.instantiate() as Area2D

		if food == null:
			push_error("FoodSpawner: Food scene root must be Area2D!")
			return false

		food.connect("eaten", _on_food_eaten)

		add_child(food)

		food.global_position = spawn_position

		active_foods.append(food)

		return true

	return false


func _is_valid_spawn_position(candidate_position: Vector2) -> bool:

	# food không được spawn gần đầu giun
	if is_instance_valid(worm):
		if candidate_position.distance_to(worm.global_position) < min_distance_from_worm:
			return false

	# các food không được spawn gần nhau
	for food in active_foods:
		if not is_instance_valid(food):
			continue

		if candidate_position.distance_to(food.global_position) < min_distance_between_foods:
			return false

	return true


func _on_food_eaten(food: Area2D) -> void:

	active_foods.erase(food)

	print("Food consumed. Remaining: ", active_foods.size())

	_respawn_food()


func _respawn_food() -> void:

	await get_tree().create_timer(respawn_delay).timeout

	if not is_inside_tree():
		return

	# lượng food spawn không được vượt quá max_food_count
	if active_foods.size() < max_food_count:
		if not _spawn_food():
			push_warning("FoodSpawner: Failed to respawn Food.")
