extends Booster
func _ready() -> void:
	body_entered.connect(_on_body_entered)
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not body.is_in_group("Body"):
		apply_effect(body)
		queue_free()
