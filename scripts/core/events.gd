extends Node
## Szyna Zdarzeń (Event Bus) dla JewelRunner
## Centralny punkt wymiany sygnałów w grze. Wszystkie moduły (Gracz, UI, AI Director, PortalSync, Klejnoty)
## komunikują się przez te sygnały bez konieczności bezpośrednich referencji między węzłami.

const AIDirectorScript = preload("res://scripts/core/ai_director.gd")
const PortalSyncScript = preload("res://scripts/core/portal_sync.gd")

# --- Zdarzenia Gracza (Player Events) ---
signal player_spawned(player: Node2D)
signal player_state_changed(new_state_name: String)
signal player_dashed(direction: Vector2)
signal player_slid()
signal player_jumped(is_double_jump: bool)
signal player_hit(damage: int)
signal player_health_changed(current: int, max_health: int)
signal player_died()
signal player_stamina_changed(current: float, max_stamina: float)
signal stamina_action_rejected(move_name: String, required_stamina: float, current_stamina: float)

# --- Zdarzenia Świata i Zbieractwa (Gameplay Events) ---
signal jewel_collected(value: int, position: Vector2)
signal jewels_progress_updated(collected: int, total: int)
signal all_jewels_collected()
signal cursed_jewel_triggered(mechanic_name: String, duration: float)
signal score_added(amount: int)
signal score_updated(total_score: int)
signal trick_performed(points: int)
signal multiplier_changed(multiplier: float)

# --- Zdarzenia Poziomu i Pętli Gry (Game Loop Events) ---
signal level_started()
signal level_completed()
signal run_restarted()
signal session_started(session_id: String)

# --- Zdarzenia Adaptacyjnego AI (Metrics / Director Events) ---
signal playstyle_metric_recorded(metric_name: String, value: float)
signal stamina_multipliers_updated(multipliers: Dictionary)
signal mechanic_lockout_changed(move_name: String, is_locked: bool, duration: float)
signal level_analyzed(analysis: Dictionary)

# --- Zdarzenia Portalu Webowego (Web App Sync Events) ---
signal portal_webpage_opened(url: String)
signal portal_profile_synced(profile_state: Dictionary)
signal portal_challenges_synced(challenges: Array)
signal portal_sync_failed(code: String, message: String)

var session_id: String = ""
var completed_levels: Dictionary = {}
var level_best_times: Dictionary = {}

## Wybrany w menu głównym profil mechaniki poziomu (1 = Synergia, 2 = Ascent, 3 = Momentum, 4 = Aether / AI Szachownica)
var selected_level_profile: int = 1
var selected_level_seed: int = 0

## Instancja Adaptacyjnego Reżysera AI (zarządza mnożnikami staminy, kontraktami AI, blokadami i analizą poziomu)
var ai_director: AdaptiveAIDirector = null

## Instancja Serwisu Synchronizacji z Portalem Webowym (ustawienia, skórki, kolory, akcesoria, zadania)
var portal_sync: Node = null

func generate_session_id() -> String:
	var timestamp := int(Time.get_unix_time_from_system())
	var rand_part := randi() % 9000 + 1000
	session_id = "SES-%d-%04d" % [timestamp, rand_part]
	session_started.emit(session_id)
	return session_id

func complete_level(level_id: int, completion_time: float = -1.0) -> void:
	completed_levels[level_id] = true
	if completion_time >= 0.0:
		if not level_best_times.has(level_id) or completion_time < float(level_best_times[level_id]):
			level_best_times[level_id] = completion_time
	level_completed.emit()

func is_level_completed(level_id: int) -> bool:
	return completed_levels.get(level_id, false)

func get_level_best_time(level_id: int) -> float:
	return float(level_best_times.get(level_id, -1.0))

func _enter_tree() -> void:
	_setup_default_inputs()
	_ensure_services()

func _ensure_services() -> void:
	if not is_instance_valid(ai_director):
		ai_director = AIDirectorScript.new()
		ai_director.name = "AIDirector"
		add_child(ai_director)
	if not is_instance_valid(portal_sync):
		portal_sync = PortalSyncScript.new()
		portal_sync.name = "PortalSync"
		add_child(portal_sync)

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
	_ensure_action("trick", [KEY_C])

func _ensure_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for k in keys:
			var event := InputEventKey.new()
			event.physical_keycode = k
			InputMap.action_add_event(action_name, event)
