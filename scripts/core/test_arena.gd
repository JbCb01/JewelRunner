extends Node2D

## Główny skrypt Areny Testowej (Etap 0 / Setup Poziomu)
## Obsługuje szybki restart areny pod klawiszem 'R' oraz reakcję na wypadnięcie/śmierć gracza.

@onready var respawn_point: Marker2D = $RespawnPoint

func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.player_hit.connect(_on_player_hit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	# Krótka pauza i restart sceny testowej
	await get_tree().create_timer(0.4).timeout
	get_tree().reload_current_scene()

func _on_player_hit(_damage: int) -> void:
	Events.player_died.emit()

