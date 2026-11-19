extends Area2D
class_name CheckpointArea

## Punkt Kontrolny (Checkpoint) na poziomie
## Po wejściu gracza zapisuje jego pozycję odrodzenia na wypadek wpadnięcia w przepaść.

@export var checkpoint_id: String = "CP-1"
var is_activated: bool = false

func _ready() -> void:
	add_to_group("checkpoints")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_activated = true
		if body.has_method("set_checkpoint"):
			body.set_checkpoint(global_position, checkpoint_id)
		_update_visuals_activated()
		if is_instance_valid(Events):
			Events.checkpoint_reached.emit(checkpoint_id, global_position)

func _update_visuals_activated() -> void:
	for child in get_children():
		if child is ColorRect:
			(child as ColorRect).color = Color(0.25, 0.95, 0.45, 0.9)
		elif child is Sprite2D:
			(child as Sprite2D).modulate = Color(0.25, 0.95, 0.45, 1.0)
		elif child is Label:
			(child as Label).modulate = Color(0.35, 1.0, 0.55, 1.0)
