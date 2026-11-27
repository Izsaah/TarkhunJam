extends CharacterBody2D

@export var speed: float = 300.0
@export var max_lifetime: float = 3.0
@export var hit_radius: float = 18.0
@export var bullet_color: String = ""

var is_one_shot: bool = false
var _time_alive: float = 0.0
var _player: Node = null

func _ready():
	_player = get_tree().root.find_child("WormPlayer", true, false)
	
	# Automatically detect color from scene filename (e.g. red.tscn -> "red")
	if bullet_color.is_empty():
		bullet_color = scene_file_path.get_file().get_basename().to_lower()

func _physics_process(delta: float):
	_time_alive += delta
	if _time_alive >= max_lifetime:
		queue_free()
		return

	var move_vector = Vector2.RIGHT.rotated(global_rotation) * speed * delta
	var collision = move_and_collide(move_vector)

	if collision:
		var target = collision.get_collider()
		
		# Ignore NPC shooters and their body parts
		if target and (target.is_in_group("npc_head") or target.is_in_group("npc_body") or "Npc" in target.name):
			return

		_handle_hit(target)
		queue_free()
		return

	# Check hit against player body segments and tail
	if _check_player_body():
		queue_free()

func _check_player_body() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().root.find_child("WormPlayer", true, false)
		if not is_instance_valid(_player):
			return false

	if "body_parts" in _player:
		for part in _player.body_parts:
			if is_instance_valid(part) and global_position.distance_to(part.global_position) <= hit_radius:
				_handle_hit(_player)
				return true

	return false

func _handle_hit(target: Node):
	var player = _find_worm_player(target)
	if not player:
		return

	# Immune if player color matches bullet color
	if "current_color" in player and player.current_color.to_lower() == bullet_color.to_lower():
		return

	# 1% Chance: Instant kill
	if is_one_shot:
		_kill_player(player)
		return

	# 99% Chance: Remove 1 segment from player
	if "body_parts" in player:
		if player.body_parts.size() > 0:
			var segment = player.body_parts.pop_back()
			if is_instance_valid(segment):
				segment.queue_free()
			if player.has_signal("size_changed"):
				player.size_changed.emit(player.body_parts.size())

		# Die immediately if no body parts remain
		if player.body_parts.size() <= 0:
			_kill_player(player)
	else:
		_kill_player(player)

func _kill_player(player: Node):
	if player.has_method("take_damage"):
		player.take_damage(0, true, self)
	elif player.has_method("die"):
		player.die()
	else:
		player.queue_free()

func _find_worm_player(node: Node) -> Node:
	var current = node
	while current:
		if "body_parts" in current or current.name == "WormPlayer":
			return current
		current = current.get_parent()
	return null