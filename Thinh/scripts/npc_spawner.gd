extends Node2D

@export var npc_head_scene: PackedScene
@export var player_head: Node2D
@export var match_timer_ui: Control

@export var total_npcs: int = 30
@export var spawn_area_size: Vector2 = Vector2(2000, 2000)
@export var min_dist_from_player: float = 350.0

var _spawned_so_far: int = 0
var _alive_npcs: int = 0

func _ready() -> void:
	if not npc_head_scene or not player_head:
		push_error("NPCSpawner: Assign npc_head_scene and player_head in the Inspector!")
		return

	if not is_instance_valid(match_timer_ui):
		match_timer_ui = get_tree().root.find_child("MatchTimerUI", true, false)

	if is_instance_valid(match_timer_ui) and match_timer_ui.has_signal("wave_triggered"):
		match_timer_ui.wave_triggered.connect(_on_wave_triggered)
	else:
		push_error("NPCSpawner: Could not find MatchTimerUI!")

func _on_wave_triggered(wave_index: int, total_waves: int, ai_tier: int) -> void:
	var count := _calculate_wave_count(wave_index, total_waves)
	for i in range(count):
		spawn_npc(ai_tier)
		_spawned_so_far += 1

	if _alive_npcs == 0 and _spawned_so_far >= total_npcs:
		if is_instance_valid(match_timer_ui) and match_timer_ui.has_method("win_game"):
			match_timer_ui.win_game("ENEMIES CLEARED!")

func _calculate_wave_count(wave_index: int, total_waves: int) -> int:
	if _spawned_so_far >= total_npcs:
		return 0

	if wave_index >= total_waves - 1:
		return total_npcs - _spawned_so_far

	var weight_sum := float(total_waves * (total_waves + 1)) / 2.0
	var wave_weight := float(wave_index + 1)
	var count := int(round(float(total_npcs) * (wave_weight / weight_sum)))
	return clampi(count, 0, total_npcs - _spawned_so_far)

func spawn_npc(ai_tier: int = 0) -> void:
	var npc_head = npc_head_scene.instantiate()
	npc_head.global_position = _get_safe_spawn_position()
	npc_head.rotation = randf_range(0, TAU)

	var actual_head = player_head.get_node_or_null("%Head")
	npc_head.player_head = actual_head if actual_head else player_head

	if npc_head.has_method("set_ai_tier"):
		npc_head.set_ai_tier(ai_tier)

	_alive_npcs += 1
	npc_head.tree_exited.connect(_on_npc_removed)
	add_child(npc_head)

func _on_npc_removed() -> void:
	if not is_inside_tree():
		return

	_alive_npcs = maxi(0, _alive_npcs - 1)

	if _alive_npcs == 0 and is_instance_valid(match_timer_ui) and not get_tree().paused:
		if _spawned_so_far >= total_npcs:
			# No more NPCs left to spawn: player wins
			match_timer_ui.win_game("ENEMIES CLEARED!")
		else:
			# Still have waves left: spawn next wave early
			match_timer_ui.trigger_next_wave()

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