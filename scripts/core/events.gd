extends Node
## Szyna Zdarzeń (Event Bus) dla JewelRunner
## Centralny punkt wymiany sygnałów w grze. Wszystkie moduły (Gracz, UI, AI Director, PortalSync, Klejnoty)
## komunikują się przez te sygnały bez konieczności bezpośrednich referencji między węzłami.

const AIDirectorScript = preload("res://scripts/core/ai_director.gd")
const PortalSyncScript = preload("res://scripts/core/portal_sync.gd")
const WalletSyncScript = preload("res://scripts/core/wallet_sync.gd")
const KeybindManagerScript = preload("res://scripts/core/keybind_manager.gd")
const PlayStyleProfilerScript = preload("res://scripts/core/playstyle_profiler.gd")

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
## Combo tricków zmieniło się: lista tricków, aktualna wypłata staminy, czy zakończone Finałem.
signal trick_combo_updated(tricks: Array, payout: float, finished: bool)
## Combo zakończone: liczba tricków, faktycznie dodana stamina, Finał?, wpadka (bail)?
signal trick_combo_ended(count: int, stamina_gained: float, finished: bool, bailed: bool)
signal multiplier_changed(multiplier: float)
signal enemy_defeated()
signal powerup_collected(powerup_type: String, duration: float, value: float)
signal powerup_expired(powerup_type: String)
signal checkpoint_reached(checkpoint_id: String, position: Vector2)
signal player_fell_in_abyss(respawn_position: Vector2)
signal special_jewel_collected(special_id: String, jewel_name: String, rarity: String, already_owned: bool)

# --- Zdarzenia Poziomu i Pętli Gry (Game Loop Events) ---
signal loading_screen_finished()
signal player_appear_finished()
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
signal portal_run_synced(run_result: Dictionary)
signal portal_daily_reward_updated(daily_state: Dictionary)
signal portal_cloud_save_loaded(save_data: Dictionary)
signal portal_save_conflict(local_save: Dictionary, server_save: Dictionary)

var session_id: String = ""
var completed_levels: Dictionary = {}
var level_best_times: Dictionary = {}
var level_contracts_completed: Dictionary = {}

## Płynna, konfigurowalna w Settings prędkość biernej regeneracji staminy
signal stamina_regen_changed(new_rate: float)
signal keybinds_changed()
var stamina_regen_rate: float = 0.10

## Wybrany w menu głównym profil mechaniki poziomu (1 = Synergia, 2 = Ascent, 3 = Momentum, 4 = Aether / AI Szachownica)
var selected_level_profile: int = 1
var selected_level_seed: int = 0
var return_to_level_select: bool = false
var last_szachownica_music_path: String = ""

## Instancja Adaptacyjnego Reżysera AI - Patryk (Prywatny Asystent Technologiczny, Reagujący i Kreatywny)
## (zarządza mnożnikami staminy, kontraktami AI, blokadami i analizą poziomu)
var patryk: AdaptiveAIDirector = null
var ai_director: AdaptiveAIDirector:
	get:
		return patryk
	set(value):
		patryk = value

## Instancja Serwisu Synchronizacji z Portalem Webowym (ustawienia, skórki, kolory, akcesoria, zadania)
var portal_sync: Node = null

## Bufor salda klejnotów: kolejka offline i synchronizacja z serwerem (/api/me/wallet/sync)
var wallet_sync: Node = null

## Menedżer skrótów klawiszowych (zmiana w ustawieniach oraz zapis lokalny)
var keybind_manager: KeybindManagerScript = null

## Trwały profil stylu gry (analiza dla generatora poziomu AI)
var playstyle_profiler: PlayStyleProfilerScript = null

## Trwała kolekcja specjalnych (sekretnych) klejnotów
const SPECIAL_JEWELS_SAVE_PATH: String = "user://special_jewels.json"
var special_jewels_save_path: String = SPECIAL_JEWELS_SAVE_PATH
var collected_special_jewels: Dictionary = {}

func is_special_jewel_owned(special_id: String) -> bool:
	if special_id.is_empty():
		return false
	return collected_special_jewels.has(special_id)

func register_special_jewel(special_id: String, jewel_name: String = "Sekretny Klejnot", rarity: String = "Legendarny") -> bool:
	if special_id.is_empty() or collected_special_jewels.has(special_id):
		return false
	collected_special_jewels[special_id] = {
		"id": special_id,
		"name": jewel_name,
		"rarity": rarity,
		"collected_at": int(Time.get_unix_time_from_system())
	}
	save_special_jewels()
	if is_instance_valid(portal_sync):
		portal_sync.player_profile["special_gems"] = int(portal_sync.player_profile.get("special_gems", 0)) + 1
	return true

func save_special_jewels() -> void:
	var file := FileAccess.open(special_jewels_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(collected_special_jewels))

func load_special_jewels() -> void:
	collected_special_jewels.clear()
	if not FileAccess.file_exists(special_jewels_save_path):
		return
	var text := FileAccess.get_file_as_string(special_jewels_save_path)
	if text.strip_edges().is_empty():
		return
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		collected_special_jewels = (json.data as Dictionary).duplicate(true)

func generate_session_id() -> String:
	var timestamp := int(Time.get_unix_time_from_system())
	var rand_part := randi() % 9000 + 1000
	session_id = "SES-%d-%04d" % [timestamp, rand_part]
	session_started.emit(session_id)
	return session_id

func complete_level(level_id: int, completion_time: float = -1.0, contract_mode: int = -1) -> void:
	completed_levels[level_id] = true
	var c_mode = contract_mode
	if c_mode < 0:
		c_mode = int(patryk.active_contract) if is_instance_valid(patryk) else 0

	if not level_contracts_completed.has(level_id):
		level_contracts_completed[level_id] = {}
	level_contracts_completed[level_id][c_mode] = true

	if completion_time >= 0.0:
		if not level_best_times.has(level_id) or completion_time < float(level_best_times[level_id]):
			level_best_times[level_id] = completion_time
	level_completed.emit()

func is_level_completed(level_id: int) -> bool:
	return completed_levels.get(level_id, false)

func get_level_stars(level_id: int) -> int:
	var contracts: Dictionary = level_contracts_completed.get(level_id, {})
	var count: int = 0
	for m in [0, 1, 2]:
		if contracts.get(m, false) == true:
			count += 1
	if count == 0 and is_level_completed(level_id):
		count = 1
	return count

func is_level_contract_completed(level_id: int, contract_id: int) -> bool:
	var contracts: Dictionary = level_contracts_completed.get(level_id, {})
	if contracts.get(contract_id, false) == true:
		return true
	if contract_id == 0 and is_level_completed(level_id) and contracts.is_empty():
		return true
	return false

func get_level_best_time(level_id: int) -> float:
	return float(level_best_times.get(level_id, -1.0))

func _enter_tree() -> void:
	load_special_jewels()
	_setup_default_inputs()
	_ensure_services()

func _ensure_services() -> void:
	if not is_instance_valid(patryk):
		patryk = AIDirectorScript.new()
		patryk.name = "Patryk" # AI Director - Patryk (Prywatny Asystent Technologiczny, Reagujący i Kreatywny)
		add_child(patryk)
	if not is_instance_valid(portal_sync):
		portal_sync = PortalSyncScript.new()
		portal_sync.name = "PortalSync"
		add_child(portal_sync)
	if not is_instance_valid(wallet_sync):
		wallet_sync = WalletSyncScript.new()
		wallet_sync.name = "WalletSync"
		add_child(wallet_sync)
	if not is_instance_valid(keybind_manager):
		keybind_manager = KeybindManagerScript.new()
		keybind_manager.name = "KeybindManager"
		add_child(keybind_manager)
		keybind_manager.load_keybinds()
	if not is_instance_valid(playstyle_profiler):
		playstyle_profiler = PlayStyleProfilerScript.new()
		playstyle_profiler.name = "PlayStyleProfiler"
		add_child(playstyle_profiler)

## Bezpieczna automatyczna rejestracja akcji w InputMap, aby zapobiec błędom
## jeśli akcje nie zostały jeszcze ręcznie dodane w Project Settings.
func _setup_default_inputs() -> void:
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_action("jump", [KEY_SPACE])
	_ensure_action("dash", [KEY_SHIFT])
	_ensure_action("crouch_slide", [KEY_S, KEY_DOWN])
	_ensure_action("trick_flip", [KEY_Z])
	_ensure_action("trick_star", [KEY_X])
	_ensure_action("trick_finish", [KEY_C])

func get_action_key_label(action_name: String, lang: String = "pl") -> String:
	if is_instance_valid(keybind_manager):
		return keybind_manager.get_primary_key_label(action_name, lang)
	return action_name

func normalize_legacy_keybind_template(text: String) -> String:
	var out := text
	out = out.replace("[W]", "[{move_up}]")
	out = out.replace("[S]", "[{crouch_slide}]")
	out = out.replace("[A]", "[{move_left}]")
	out = out.replace("[D]", "[{move_right}]")
	out = out.replace("[Shift]", "[{dash}]")
	out = out.replace("[Ctrl]", "[{trick}]")
	# {trick} = wszystkie trzy klawisze tricków (np. "Z/X/C")
	out = out.replace("[Space]", "[{jump}]")
	out = out.replace("[Spacja]", "[{jump}]")
	return out

func format_keybind_text(text: String, lang: String = "pl") -> String:
	var out := normalize_legacy_keybind_template(text)
	var actions: Array[String] = [
		"move_left",
		"move_right",
		"move_up",
		"move_down",
		"jump",
		"dash",
		"crouch_slide",
		"trick_flip",
		"trick_star",
		"trick_finish"
	]
	for action_name in actions:
		var token := "{%s}" % action_name
		if out.contains(token):
			out = out.replace(token, get_action_key_label(action_name, lang))
	if out.contains("{trick}"):
		out = out.replace("{trick}", get_trick_keys_label(lang))
	return out

## Etykieta trzech klawiszy tricków, np. "Z/X/C".
func get_trick_keys_label(lang: String = "pl") -> String:
	return "%s/%s/%s" % [get_action_key_label("trick_flip", lang), get_action_key_label("trick_star", lang), get_action_key_label("trick_finish", lang)]

func update_controls_grid_labels(ctrl_grid: Node, lang: String = "pl") -> void:
	if not ctrl_grid:
		return
	var km := keybind_manager
	var is_en: bool = (lang == "en")
	var a1 := ctrl_grid.get_node_or_null("Action1") as Label
	if a1: a1.text = "Horizontal Movement (Left / Right):" if is_en else "Ruch poziomy (Lewo / Prawo):"
	var k1 := ctrl_grid.get_node_or_null("Key1") as Label
	if k1:
		var left_k := km.get_action_key_label("move_left", lang) if km else "A / ←"
		var right_k := km.get_action_key_label("move_right", lang) if km else "D / →"
		k1.text = "%s  |  %s" % [left_k, right_k]
	var a2 := ctrl_grid.get_node_or_null("Action2") as Label
	if a2: a2.text = "Jump / Double Jump:" if is_en else "Skok / Podwójny skok:"
	var k2 := ctrl_grid.get_node_or_null("Key2") as Label
	if k2: k2.text = km.get_action_key_label("jump", lang) if km else ("Space" if is_en else "Spacja")
	var a3 := ctrl_grid.get_node_or_null("Action3") as Label
	if a3: a3.text = "Dash:" if is_en else "Zryw (Dash):"
	var k3 := ctrl_grid.get_node_or_null("Key3") as Label
	if k3: k3.text = km.get_action_key_label("dash", lang) if km else "Shift"
	var a4 := ctrl_grid.get_node_or_null("Action4") as Label
	if a4: a4.text = "Crouch / Slide:" if is_en else "Kucanie / Wślizg:"
	var k4 := ctrl_grid.get_node_or_null("Key4") as Label
	if k4: k4.text = km.get_action_key_label("crouch_slide", lang) if km else "S / ↓"
	var a5 := ctrl_grid.get_node_or_null("Action5") as Label
	if a5: a5.text = "Wall Climb:" if is_en else "Wspinaczka (przy ścianie):"
	var k5 := ctrl_grid.get_node_or_null("Key5") as Label
	if k5: k5.text = km.get_action_key_label("move_up", lang) if km else "W / ↑"
	var a6 := ctrl_grid.get_node_or_null("Action6") as Label
	if a6: a6.text = "Trick Combo (mid-air, charges stamina):" if is_en else "Combo tricków (w locie - ładuje staminę):"
	var k6 := ctrl_grid.get_node_or_null("Key6") as Label
	if k6:
		var keys: Array[String] = []
		for a in ["trick_flip", "trick_star", "trick_finish"]:
			keys.append(km.get_action_key_label(a, lang) if km else a)
		k6.text = ("%s Flip  %s Star  %s Finale" if is_en else "%s Salto  %s Gwiazda  %s Finał") % keys
	var a7 := ctrl_grid.get_node_or_null("Action7") as Label
	if a7: a7.text = "Pause:" if is_en else "Pauza:"

func apply_audio_slider_tooltips(master_slider: Slider, music_slider: Slider, level_music_slider: Slider, sfx_slider: Slider, lang: String = "pl") -> void:
	var is_en: bool = (lang == "en")
	if master_slider:
		master_slider.tooltip_text = "Controls overall game volume across all audio channels (Master bus)." if is_en else "Reguluje ogólną głośność wszystkich dźwięków i muzyki w grze (szyna Master)."
	if music_slider:
		music_slider.tooltip_text = "Controls background music volume in menus only (MusicMenu bus)." if is_en else "Reguluje głośność muzyki w menu głównym (szyna MusicMenu)."
	if level_music_slider:
		level_music_slider.tooltip_text = "Controls background music volume during gameplay levels (MusicLevel bus)." if is_en else "Reguluje głośność muzyki odtwarzanej podczas gry na poziomach (szyna MusicLevel)."
	if sfx_slider:
		sfx_slider.tooltip_text = "Controls sound effects volume: jumps, dashes, pickups and UI sounds (SFX bus)." if is_en else "Reguluje głośność efektów dźwiękowych: skoków, dashy, klejnotów i kliknięć menu (szyna SFX)."

func _ensure_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		for k in keys:
			var event := InputEventKey.new()
			event.physical_keycode = k
			InputMap.action_add_event(action_name, event)
