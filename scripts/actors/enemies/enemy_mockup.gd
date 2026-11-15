extends Area2D
class_name EnemyMockup

## Prototyp wroga

@export var contact_damage: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)
