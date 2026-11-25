extends CharacterBody2D

@export var speed: float = 900.0
@export var max_lifetime: float = 3.0

var is_one_shot: bool = false
var _time_alive: float = 0.0

func _physics_process(delta: float):
	_time_alive += delta
	if _time_alive >= max_lifetime:
		queue_free()
		return

	# Move forward in the direction it was rotated
	var move_vector = Vector2.RIGHT.rotated(global_rotation) * speed * delta
	var collision = move_and_collide(move_vector)

	if collision:
		var target = collision.get_collider()
		
		# Ignore NPC shooters and their body parts
		if target and (target.is_in_group("npc_head") or target.is_in_group("npc_body") or "Npc" in target.name):
			return

		_handle_hit(target)
		queue_free()

func _handle_hit(target: Node):
	var player = _find_worm_player(target)
	if not player:
		return

	# 10% Chance: Instant kill
	if is_one_shot:
		_kill_player(player)
		return

	# 90% Chance: Remove 1 segment from player
	if "body_parts" in player:
		if player.body_parts.size() > 0:
			var segment = player.body_parts.pop_back()
			if is_instance_valid(segment):
				segment.queue_free()
			if player.has_signal("size_changed"):
				player.size_changed.emit(player.body_parts.size())
		else:
			_kill_player(player)
	else:
		_kill_player(player)

func _kill_player(player: Node):
	if player.has_method("die"):
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
