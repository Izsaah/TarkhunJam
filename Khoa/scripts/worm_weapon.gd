extends Marker2D

signal ammo_changed(current_ammo: int)

@export var bullet_scene: PackedScene

@export var bullet_damage: int = 1
@export var bullet_count: int = 20
@export var bullet_speed: float = 500.0

@export var bullet_instakill: bool = false

@export var fire_interval: float = 0.25
@export var projectile_lifetime: float = 2.5

@export var actor_path: NodePath = NodePath("../..")

var actor: Node = null
var cooldown_remaining: float = 0.0


func _ready() -> void:
	actor = get_node_or_null(actor_path)

	if bullet_scene == null:
		push_error("WormWeapon: Bullet Scene is missing!")

	if actor == null:
		push_error("WormWeapon: Actor reference is missing!")


func _process(delta: float) -> void:
	cooldown_remaining = maxf(
		0.0,
		cooldown_remaining - delta
	)


func shoot_towards(target_position: Vector2) -> bool:

	if bullet_scene == null:
		return false

	if not is_instance_valid(actor):
		return false

	if bullet_count <= 0:
		print("Out of ammunition!")
		return false

	if cooldown_remaining > 0.0:
		return false

	var direction := global_position.direction_to(
		target_position
	)

	if direction.is_zero_approx():
		return false

	var projectile := bullet_scene.instantiate() as Area2D

	if projectile == null:
		push_error("WormWeapon: Invalid Bullet Scene!")
		return false

	projectile.call(
		"setup",
		direction,
		bullet_speed,
		bullet_damage,
		bullet_instakill,
		actor,
		projectile_lifetime
	)

	var scene_root := get_tree().current_scene

	if scene_root == null:
		projectile.free()
		return false

	scene_root.add_child(projectile)

	projectile.global_position = global_position

	bullet_count -= 1
	ammo_changed.emit(bullet_count)

	cooldown_remaining = fire_interval

	print("Ammo remaining: ", bullet_count)

	return true


func set_insta_kill_enabled(enabled: bool) -> void:
	bullet_instakill = enabled

	print("Insta Kill: ", bullet_instakill)


func add_ammo(amount: int) -> void:
	if amount <= 0:
		return

	bullet_count += amount
	ammo_changed.emit(bullet_count)
