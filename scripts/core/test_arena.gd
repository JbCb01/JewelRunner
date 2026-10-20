extends Node2D

## Główny skrypt Areny Testowej (Etap 0 / Setup Poziomu)
## Obsługuje szybki restart areny pod klawiszem 'R' oraz reakcję na wypadnięcie/śmierć gracza.

@onready var respawn_point: Marker2D = $RespawnPoint
@onready var hud_stamina_bar: ProgressBar = $HUD/StaminaPanel/HBox/HudStaminaBar

func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.player_hit.connect(_on_player_hit)
	Events.player_stamina_changed.connect(_on_player_stamina_changed)

func _on_player_stamina_changed(current: float, max_stamina: float) -> void:
	if hud_stamina_bar:
		hud_stamina_bar.max_value = max_stamina
		hud_stamina_bar.value = current

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	# Krótka pauza i restart sceny testowej
	await get_tree().create_timer(0.4).timeout
	get_tree().reload_current_scene()

func _on_player_hit(_damage: int) -> void:
	Events.player_died.emit()
