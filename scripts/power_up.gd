extends Area2D
class_name PowerUp

## Obiekt wzmocnienia (Power-up) do zebrania na poziomie
## Obsługuje logikę działania power-upów, timery i reguły nadpisywania (S23KC2S1P1-279)

@export var powerup_type: String = "SPEED_BOOST" # SPEED_BOOST, INVINCIBILITY, SHIELD, SCORE_MULTIPLIER, JUMP_BOOST, INSTANT_HEAL
@export var duration: float = 6.0
@export var value: float = 1.4
@export var tier: int = 1
@export var bob_speed: float = 4.0
@export var bob_height: float = 3.0

@onready var sprite_node: Node2D = get_node_or_null("Sprite2D")
var start_y: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	if sprite_node:
		start_y = sprite_node.position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if sprite_node:
		time_passed += delta * bob_speed
		sprite_node.position.y = start_y + sin(time_passed) * bob_height

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_powerup"):
			body.apply_powerup(powerup_type, duration, value, tier)
		else:
			Events.powerup_collected.emit(powerup_type, duration, value)
		queue_free()
