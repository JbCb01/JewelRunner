extends Area2D

## Strefa Zagrożenia (Kolce / Przepaść / Hazard)
## Znajduje się na warstwie kolizji Hazards (Layer 5).

@export var damage: int = 100

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Events.player_hit.emit(damage)
