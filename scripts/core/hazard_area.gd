extends Area2D

## Strefa Zagrożenia (Kolce / Przepaść / Hazard)
## Znajduje się na warstwie kolizji Hazards (Layer 5).

@export var damage: int = 1
@export var is_abyss: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_abyss and body.has_method("handle_abyss_fall"):
			body.handle_abyss_fall(damage)
		elif body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		else:
			Events.player_hit.emit(damage)
