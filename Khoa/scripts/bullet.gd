extends Area2D

var direction: Vector2 = Vector2.RIGHT
var bullet_speed: float = 500.0
var damage: int = 20
var insta_kill: bool = false
var source_actor: Node = null

var remaining_lifetime: float = 2.5
var has_hit: bool = false


func setup(
	shoot_direction: Vector2,
	speed: float,
	bullet_damage: int,
	bullet_insta_kill: bool,
	shooter: Node,
	lifetime: float
) -> void:
	direction = shoot_direction.normalized()
	bullet_speed = speed
	damage = maxi(0, bullet_damage)
	insta_kill = bullet_insta_kill
	source_actor = shooter
	remaining_lifetime = lifetime


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	global_position += direction * bullet_speed * delta

	remaining_lifetime -= delta

	if remaining_lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(5, 0),
		Vector2(0, 3),
		Vector2(-5, 0),
		Vector2(0, -3)
	])

	draw_colored_polygon(points, Color("#FFE082"))


func _on_body_entered(body: Node2D) -> void:
	_apply_damage(body)


func _on_area_entered(area: Area2D) -> void:
	_apply_damage(area)


func _apply_damage(hit_object: Node) -> void:
	if has_hit:
		return

	var target := _find_damageable(hit_object)

	if target == null:
		return

	has_hit = true

	target.call(
		"take_damage",
		damage,
		insta_kill,
		source_actor
	)

	print("Projectile hit: ", target.name)
	queue_free()


func _find_damageable(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if current.has_method("take_damage"):
			return current

		current = current.get_parent()

	return null
