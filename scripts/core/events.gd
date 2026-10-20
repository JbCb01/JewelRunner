extends Node
## Szyna Zdarzeń (Event Bus) dla JewelRunner
## Centralny punkt wymiany sygnałów w grze. Wszystkie moduły (Gracz, UI, Drony, Klejnoty)
## komunikują się przez te sygnały bez konieczności bezpośrednich referencji między węzłami.

# --- Zdarzenia Gracza (Player Events) ---
signal player_spawned(player: Node2D)
signal player_state_changed(new_state_name: String)
signal player_dashed(direction: Vector2)
signal player_slid()
signal player_jumped(is_double_jump: bool)
signal player_hit(damage: int)
signal player_died()
signal player_stamina_changed(current: float, max_stamina: float)

# --- Zdarzenia Świata i Zbieractwa (Gameplay Events) ---
signal jewel_collected(value: int, position: Vector2)
signal score_updated(total_score: int)
signal multiplier_changed(multiplier: float)

# --- Zdarzenia Poziomu i Pętli Gry (Game Loop Events) ---
signal level_started()
signal level_completed()
signal run_restarted()

# --- Zdarzenia Adaptacyjnego AI (Metrics / Director Events) ---
signal playstyle_metric_recorded(metric_name: String, value: float)

func _enter_tree() -> void:
	_setup_default_inputs()

## Bezpieczna automatyczna rejestracja akcji w InputMap, aby zapobiec błędom
## jeśli akcje nie zostały jeszcze ręcznie dodane w Project Settings.
func _setup_default_inputs() -> void:
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_action("jump", [KEY_SPACE])
	_ensure_action("dash", [KEY_SHIFT])
	_ensure_action("crouch_slide", [KEY_S, KEY_DOWN, KEY_CTRL])

func _ensure_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for k in keys:
			var event := InputEventKey.new()
			event.physical_keycode = k
			InputMap.action_add_event(action_name, event)
