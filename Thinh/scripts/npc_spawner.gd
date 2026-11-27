extends Node2D

signal time_updated(seconds_left: int)
signal game_ended(is_win: bool, message: String)

@export var npc_head_scene: PackedScene
@export var player_head: Node2D
@export var player: Node = null

@export_group("Spawning")
@export var total_npcs: int = 30
@export var spawn_area_size: Vector2 = Vector2(2000, 2000)
@export var min_dist_from_player: float = 350.0

@export_group("Match & Waves")
@export_range(0.0, 1.0) var normal_tier_start: float = 0.4 # Normal starts at 40% of waves
@export_range(0.0, 1.0) var smart_tier_start: float = 0.8  # Smart starts at 80% of waves
@export var match_duration_seconds: float = 300.0
@export var wave_interval_seconds: float = 60.0

@onready var match_timer: Timer = get_node_or_null("MatchTimer")

var _spawned_so_far: int = 0
var _alive_npcs: int = 0
var _game_over: bool = false
var _last_wave_index: int = -1
var _total_waves: int = 1
var _wave_elapsed: float = 0.0
var _last_displayed_second: int = -1

func _ready() -> void:
	if not npc_head_scene or not player_head:
		push_error("NPCSpawner: Assign npc_head_scene and player_head in the Inspector!")
		return

	if not is_instance_valid(player):
		player = get_tree().root.find_child("WormPlayer", true, false)

	if is_instance_valid(player) and player.has_signal("died"):
		player.died.connect(_on_player_died)

	if not is_instance_valid(match_timer):
		match_timer = Timer.new()
		match_timer.name = "MatchTimer"
		add_child(match_timer)

	_total_waves = maxi(1, int(ceil(match_duration_seconds / maxf(1.0, wave_interval_seconds))))

	match_timer.one_shot = true
	match_timer.timeout.connect(_on_match_timer_timeout)
	match_timer.start(match_duration_seconds)

	# Trigger Wave 0 after all nodes finish _ready()
	trigger_next_wave.call_deferred()

func _process(delta: float) -> void:
	if _game_over:
		return

	var seconds_left := ceili(match_timer.time_left)
	if seconds_left != _last_displayed_second:
		_last_displayed_second = seconds_left
		time_updated.emit(seconds_left)

	# Trigger next wave when interval (e.g. 60s) is reached
	if _last_wave_index + 1 < _total_waves:
		_wave_elapsed += delta
		if _wave_elapsed >= wave_interval_seconds:
			trigger_next_wave()

func trigger_next_wave() -> void:
	if _game_over or _last_wave_index + 1 >= _total_waves:
		return

	_last_wave_index += 1
	_wave_elapsed = 0.0

	var progress := float(_last_wave_index) / float(_total_waves)
	var ai_tier: int = 0 # Dumb
	if progress >= smart_tier_start:
		ai_tier = 2 # Smart
	elif progress >= normal_tier_start:
		ai_tier = 1 # Normal

	_spawn_wave(_last_wave_index, _total_waves, ai_tier)

func _spawn_wave(wave_index: int, total_waves: int, ai_tier: int) -> void:
	var count := _calculate_wave_count(wave_index, total_waves)
	for i in range(count):
		spawn_npc(ai_tier)
		_spawned_so_far += 1

	if _alive_npcs == 0 and _spawned_so_far >= total_npcs:
		win_game("ENEMIES CLEARED!")

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
	if not is_inside_tree() or _game_over:
		return

	_alive_npcs = maxi(0, _alive_npcs - 1)

	if _alive_npcs == 0 and not get_tree().paused:
		if _spawned_so_far >= total_npcs:
			win_game("ENEMIES CLEARED!")
		else:
			trigger_next_wave()

func _on_match_timer_timeout() -> void:
	if _game_over:
		return
	_end_game(true, "YOU SURVIVED!")

func win_game(message: String = "YOU WIN!") -> void:
	if _game_over:
		return
	_end_game(true, message)

func _on_player_died(_reason: String) -> void:
	if _game_over:
		return
	_end_game(false, "GAME OVER")

func _end_game(is_win: bool, message: String) -> void:
	_game_over = true
	match_timer.stop()
	game_ended.emit(is_win, message)
	get_tree().paused = true

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