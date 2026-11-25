extends Node2D

@export var npc_head_scene: PackedScene # Drag your npc_head.tscn here
@export var player_head: Node2D         # Drag your Player's Head node here
@export var npc_count: int = 20

@export var spawn_area_size: Vector2 = Vector2(2000, 2000)
@export var min_dist_from_player: float = 350.0

func _ready():
	if not npc_head_scene or not player_head:
		push_error("NPCSpawner: Assign npc_head_scene and player_head in the Inspector!")
		return

	for i in range(npc_count):
		spawn_npc()

func spawn_npc():
	var npc_head = npc_head_scene.instantiate()
	npc_head.global_position = _get_safe_spawn_position()
	npc_head.rotation = randf_range(0, TAU)
	
	# Grab the actual moving Head inside Player
	var actual_head = player_head.get_node_or_null("%Head")
	npc_head.player_head = actual_head if actual_head else player_head
	
	add_child(npc_head)

func _get_safe_spawn_position() -> Vector2:
	var half_size = spawn_area_size / 2.0
	var pos = Vector2.ZERO
	
	for attempt in range(20):
		pos = Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		if pos.distance_to(player_head.global_position) >= min_dist_from_player:
			return pos
			
	return pos