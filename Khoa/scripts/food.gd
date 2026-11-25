extends Area2D

signal eaten(food: Area2D)

@export var growth_amount: int = 1

var consumed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if consumed:
		return

	if not body.has_method("grow_worm"):
		return

	consumed = true

	body.call("grow_worm", growth_amount)

	eaten.emit(self)
	print("Food consumed!")

	queue_free()
