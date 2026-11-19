extends Node
class_name PortalSyncService

## Serwis integracji i synchronizacji gry JewelRunner z aplikacją webową (Portalem Gracza).
## Odpowiada za:
## 1. Otwieranie strony profilu w przeglądarce (przycisk profilu na górze w menu głównym).
## 2. Parowanie gry z kontem webowym za pomocą 6-znakowego kodu (/api/auth/pair).
## 3. Pobieranie aktualnych ustawień profilu gracza, skórek, kolorów, akcesoriów, wzmocnień oraz aktywnych zadań (/api/me/game-state, /api/me, /api/me/challenges, /api/challenges).
## 4. Aplikowanie pobranych ustawień (Audio, Grafika, Sterowanie) oraz wyglądu i wzmocnień na postaci gracza.
## 5. Przekazywanie warunków aktywnych zadań ze strony do Generatora Map AI.

const SESSION_SAVE_PATH: String = "user://portal_session.cfg"
const RUNS_QUEUE_PATH: String = "user://pending_runs.json"
const BOOSTERS_QUEUE_PATH: String = "user://pending_boosters.json"
const DEFAULT_PORTAL_WEB_URL: String = "https://jewelrunner-app.azurewebsites.net"
const DEFAULT_API_BASE_URL: String = "https://jewelrunner-app.azurewebsites.net/api"
const HTTP_TIMEOUT_S: float = 30.0
const RUNS_RETRY_INTERVAL_S: float = 30.0
const SETTINGS_DEBOUNCE_S: float = 0.7
const GAME_VERSION: String = "0.3.0"

@export var portal_web_url: String = DEFAULT_PORTAL_WEB_URL
@export var api_base_url: String = DEFAULT_API_BASE_URL

var session_token: String = ""
var is_linked: bool = false
var last_sync_timestamp: String = ""
var last_opened_url: String = ""
var runs_queue_path: String = RUNS_QUEUE_PATH
var boosters_queue_path: String = BOOSTERS_QUEUE_PATH
var pending_runs: Array[Dictionary] = []
var pending_booster_uses: Array[Dictionary] = []
var _sending_run_id: String = ""
var _sending_booster_op_id: String = ""
var _pending_settings_patch: Dictionary = {}
var _inflight_settings_patch: Dictionary = {}
var _is_applying_remote_payload: bool = false
var daily_reward_state: Dictionary = {}
var _daily_req_kind: String = ""
var cloud_save: Dictionary = {}
var save_conflict_server: Dictionary = {}
var _last_local_save_payload: Dictionary = {}
var _save_req_kind: String = ""

# --- Dane profilu pobrane ze strony ---
var player_profile: Dictionary = {
	"id": "",
	"username": "Gość",
	"email": "",
	"gems": 250,
	"special_gems": 0
}

# --- Ustawienia pobrane ze strony (tabela ustawienia_gracza + przypisanie_klawisza) ---
var profile_settings: Dictionary = {
	"music_volume": 80,
	"level_music_volume": 70,
	"sfx_volume": 100,
	"resolution": "1280x720",
	"graphics_profile": "Wysoki",
	"language": "pl",
	"keybindings": {}
}

# --- Skórki, kolory, akcesoria i wzmocnienia (tabele wyglad_postaci, posiadany_element, posiadane_wzmocnienie) ---
var cosmetics_state: Dictionary = {
	"active_skin": "Skórka podstawowa",
	"active_color_name": "Fioletowy",
	"active_color_hex": "#6A3FB5",
	"equipped_accessories": {}, # np. {"głowa": "Czapka"}
	"owned_items": [
		{"type": "skórka", "name": "Skórka podstawowa"},
		{"type": "kolor", "name": "Fioletowy", "color_hex": "#6A3FB5"}
	],
	"boosters": {
		"tarcza": 0,
		"podwójne punkty": 0,
		"dodatkowe życie": 0,
		"magnes": 0
	}
}

# --- Aktywne zadania (wyzwania) pobrane ze strony ---
var active_challenges: Array[Dictionary] = []

# Wewnętrzne węzły HTTP i timery do komunikacji z backendem FastAPI
var _http_pair: HTTPRequest = null
var _http_sync: HTTPRequest = null
var _http_logout: HTTPRequest = null
var _http_runs: HTTPRequest = null
var _http_settings: HTTPRequest = null
var _http_appearance: HTTPRequest = null
var _http_booster: HTTPRequest = null
var _http_daily: HTTPRequest = null
var _http_save: HTTPRequest = null
var _runs_retry_timer: Timer = null
var _settings_debounce_timer: Timer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_env_url_overrides()
	_setup_http_nodes()
	_load_saved_session()
	load_pending_runs()
	load_pending_booster_uses()
	# Domyślne przykładowe wyzwania zgodne z bazą (001_dane_startowe.sql / 002_dane_przykladowe.sql),
	# które są aktualizowane natychmiast po połączeniu z API
	if not is_linked and active_challenges.is_empty():
		_init_default_portal_challenges()
	if is_linked and not session_token.is_empty() and DisplayServer.get_name() != "headless":
		request_sync_from_web.call_deferred()
		flush_pending_runs.call_deferred()
		flush_pending_booster_uses.call_deferred()

func _apply_env_url_overrides() -> void:
	var env_portal: String = OS.get_environment("JEWELRUNNER_PORTAL_URL").strip_edges()
	if not env_portal.is_empty():
		portal_web_url = env_portal.trim_suffix("/")
		api_base_url = portal_web_url + "/api"
	var env_api: String = OS.get_environment("JEWELRUNNER_API_URL").strip_edges()
	if not env_api.is_empty():
		api_base_url = env_api.trim_suffix("/")

func _make_http_node(node_name: String, callback: Callable) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.name = node_name
	req.timeout = HTTP_TIMEOUT_S
	add_child(req)
	req.request_completed.connect(callback)
	return req

func _setup_http_nodes() -> void:
	if not _http_pair:
		_http_pair = _make_http_node("HttpPair", _on_pair_request_completed)
	if not _http_sync:
		_http_sync = _make_http_node("HttpSync", _on_sync_request_completed)
	if not _http_logout:
		_http_logout = _make_http_node("HttpLogout", _on_logout_request_completed)
	if not _http_runs:
		_http_runs = _make_http_node("HttpRuns", _on_run_request_completed)
	if not _http_settings:
		_http_settings = _make_http_node("HttpSettings", _on_settings_request_completed)
	if not _http_appearance:
		_http_appearance = _make_http_node("HttpAppearance", _on_appearance_request_completed)
	if not _http_booster:
		_http_booster = _make_http_node("HttpBooster", _on_booster_request_completed)
	if not _http_daily:
		_http_daily = _make_http_node("HttpDaily", _on_daily_request_completed)
	if not _http_save:
		_http_save = _make_http_node("HttpSave", _on_save_request_completed)
	if not _runs_retry_timer:
		_runs_retry_timer = Timer.new()
		_runs_retry_timer.name = "RunsRetryTimer"
		_runs_retry_timer.wait_time = RUNS_RETRY_INTERVAL_S
		_runs_retry_timer.autostart = true
		add_child(_runs_retry_timer)
		_runs_retry_timer.timeout.connect(_on_retry_timer_timeout)
	if not _settings_debounce_timer:
		_settings_debounce_timer = Timer.new()
		_settings_debounce_timer.name = "SettingsDebounceTimer"
		_settings_debounce_timer.wait_time = SETTINGS_DEBOUNCE_S
		_settings_debounce_timer.one_shot = true
		add_child(_settings_debounce_timer)
		_settings_debounce_timer.timeout.connect(_flush_settings_patch)

func _on_retry_timer_timeout() -> void:
	flush_pending_runs()
	flush_pending_booster_uses()

func _init_default_portal_challenges() -> void:
	active_challenges = [
		{
			"challenge_id": 1,
			"name": "Pierwsze kroki",
			"description": "Ukończ pierwszy poziom.",
			"difficulty": "łatwy",
			"status": "Aktywne",
			"progress_percent": 40,
			"completion_conditions": {"ukoncz_poziom": true},
			"reward": {"type": "klejnoty", "gems": 50, "element_name": null, "booster_type": null}
		},
		{
			"challenge_id": 2,
			"name": "Łowca klejnotów",
			"description": "Zbierz wszystkie klejnoty w jednym przejściu.",
			"difficulty": "średni",
			"status": "Aktywne",
			"progress_percent": 0,
			"completion_conditions": {"min_klejnotow": 5},
			"reward": {"type": "klejnoty", "gems": 200, "element_name": null, "booster_type": null}
		},
		{
			"challenge_id": 3,
			"name": "Mistrz czasu",
			"description": "Ukończ poziom poniżej 60 sekund.",
			"difficulty": "trudny",
			"status": "Aktywne",
			"progress_percent": 0,
			"completion_conditions": {"max_czas_s": 60},
			"reward": {"type": "skórka", "gems": null, "element_name": "Bursztynowa Stelly", "booster_type": null}
		}
	]

## Otwiera stronę profilu w aplikacji webowej (wywoływane przez przycisk profilu na górze w menu).
## W trybie headless (testy automatyczne) zapisuje adres w `last_opened_url` bez otwierania okna przeglądarki.
func open_profile_webpage(path: String = "/profil") -> String:
	var clean_base: String = portal_web_url.trim_suffix("/")
	var clean_path: String = path if path.begins_with("/") else ("/" + path)
	var target_url: String = clean_base + clean_path
	last_opened_url = target_url
	
	if is_instance_valid(Events):
		Events.portal_webpage_opened.emit(target_url)
		
	if DisplayServer.get_name() != "headless":
		OS.shell_open(target_url)
	return target_url

## Paruje grę z kontem ze strony internetowej za pomocą 6-znakowego kodu z portalu (/api/auth/pair).
func pair_with_code(raw_code: String) -> bool:
	var normalized: String = ""
	for ch in raw_code.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			normalized += ch
	if normalized.length() != 6:
		if is_instance_valid(Events):
			Events.portal_sync_failed.emit("invalid_pairing_code", "Kod parowania musi składać się z 6 znaków.")
		return false
		
	if DisplayServer.get_name() == "headless":
		simulate_successful_pairing(normalized)
		return true

	if _http_pair and is_inside_tree():
		if _http_pair.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_http_pair.cancel_request()
		var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
		var body: String = JSON.stringify({"code": normalized})
		var err: Error = _http_pair.request(api_base_url.trim_suffix("/") + "/auth/pair", headers, HTTPClient.METHOD_POST, body)
		if err == OK:
			return true

	if is_instance_valid(Events):
		Events.portal_sync_failed.emit("request_error", "Nie udało się wysłać żądania parowania do serwera Azure.")
	return false

## Symuluje poprawne sparowanie i pobranie danych ze strony (wyłącznie dla trybu testowego headless).
func simulate_successful_pairing(code: String) -> void:
	session_token = "tok_" + code.to_lower() + "_demo"
	is_linked = true
	if DisplayServer.get_name() != "headless":
		_save_session()
	var demo_payload: Dictionary = {
		"player": {
			"id": "00000000-0000-0000-0000-000000000001",
			"username": "Demo",
			"email": "demo@example.com"
		},
		"wallet": {
			"gems": 450,
			"special_gems": 2
		},
		"settings": {
			"music_volume": 75,
			"sfx_volume": 90,
			"resolution": "1280x720",
			"graphics_profile": "Wysoki",
			"language": "pl",
			"keybindings": {}
		},
		"appearance": {
			"active_skin": "Bursztynowa Stelly",
			"active_color_name": "Fioletowy",
			"active_color_hex": "#6A3FB5",
			"equipped_accessories": {"głowa": "Czapka"},
			"owned_items": [
				{"type": "skórka", "name": "Skórka podstawowa"},
				{"type": "skórka", "name": "Bursztynowa Stelly"},
				{"type": "kolor", "name": "Fioletowy", "color_hex": "#6A3FB5"},
				{"type": "akcesorium", "name": "Czapka", "mount_point": "głowa"}
			]
		},
		"boosters": {
			"tarcza": 1,
			"podwójne punkty": 0,
			"dodatkowe życie": 1,
			"magnes": 1
		},
		"challenges": active_challenges.duplicate(true)
	}
	apply_synced_payload(demo_payload)

## Wysyła żądanie pobrania aktualnego stanu profilu, skórek, ustawień i wyzwań ze strony (/api/me/game-state).
func request_sync_from_web() -> bool:
	if session_token.is_empty():
		if is_instance_valid(Events):
			Events.portal_sync_failed.emit("unauthorized", "Gra nie jest jeszcze sparowana z kontem portalu.")
		return false
		
	if DisplayServer.get_name() == "headless":
		apply_synced_payload(build_current_state_payload())
		return true

	if _http_sync and is_inside_tree():
		if _http_sync.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_http_sync.cancel_request()
		var headers: PackedStringArray = PackedStringArray([
			"Authorization: Bearer " + session_token,
			"Accept: application/json"
		])
		var err: Error = _http_sync.request(api_base_url.trim_suffix("/") + "/me/game-state", headers, HTTPClient.METHOD_GET)
		if err == OK:
			return true

	if is_instance_valid(Events):
		Events.portal_sync_failed.emit("request_error", "Nie udało się wysłać żądania synchronizacji.")
	return false

func _on_pair_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		var data := parsed as Dictionary
		session_token = String(data.get("token", ""))
		is_linked = not session_token.is_empty()
		if data.has("player") and data["player"] is Dictionary:
			var p := data["player"] as Dictionary
			player_profile["id"] = String(p.get("id", ""))
			player_profile["username"] = String(p.get("username", "Gracz"))
			player_profile["email"] = String(p.get("email", ""))
		player_profile["gems"] = 0
		player_profile["special_gems"] = 0
		_save_session()
		if is_instance_valid(Events):
			Events.portal_profile_synced.emit(build_current_state_payload())
		request_sync_from_web()
		flush_pending_runs()
		flush_pending_booster_uses()
		if is_instance_valid(Events) and is_instance_valid(Events.wallet_sync):
			Events.wallet_sync.flush()
		return

	if not is_instance_valid(Events):
		return
	if response_code == 0:
		Events.portal_sync_failed.emit("network_error", "Brak połączenia z serwerem Azure lub przekroczono czas oczekiwania. Spróbuj ponownie.")
	else:
		var err_info := _extract_api_error(parsed, "pair_error", "Nieprawidłowy lub wygasły kod parowania.")
		Events.portal_sync_failed.emit(err_info["code"], err_info["message"])

func _on_sync_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		apply_synced_payload(parsed as Dictionary)
		fetch_daily_reward()
		fetch_cloud_save()
		flush_pending_booster_uses()
	elif response_code == 401:
		handle_unauthorized()
	elif is_instance_valid(Events):
		if response_code == 0:
			Events.portal_sync_failed.emit("network_error", "Nie udało się połączyć z serwerem Azure (timeout lub brak sieci).")
		else:
			var err_info := _extract_api_error(parsed, "sync_error", "Nie udało się pobrać danych profilu ze strony (HTTP %d)." % response_code)
			Events.portal_sync_failed.emit(err_info["code"], err_info["message"])

## Aplikuje kompletny słownik danych pobranych ze strony internetowej:
## ustawienia audio/grafiki/klawiszy, skórki, kolory, akcesoria, wzmocnienia i zadania!
func apply_synced_payload(payload: Dictionary) -> void:
	_is_applying_remote_payload = true
	if payload.has("player") and payload["player"] is Dictionary:
		var p := payload["player"] as Dictionary
		player_profile["id"] = String(p.get("id", player_profile["id"]))
		player_profile["username"] = String(p.get("username", player_profile["username"]))
		player_profile["email"] = String(p.get("email", player_profile["email"]))
		is_linked = true
		
	if payload.has("wallet") and payload["wallet"] is Dictionary:
		var w := payload["wallet"] as Dictionary
		player_profile["gems"] = int(w.get("gems", player_profile["gems"]))
		player_profile["special_gems"] = int(w.get("special_gems", player_profile.get("special_gems", 0)))
		if is_instance_valid(Events) and is_instance_valid(Events.wallet_sync) and Events.wallet_sync.has_method("sync_server_balance"):
			Events.wallet_sync.sync_server_balance(int(player_profile["gems"]))
		
	if payload.has("settings") and payload["settings"] is Dictionary:
		var s := payload["settings"] as Dictionary
		if s.get("music_volume") != null:
			profile_settings["music_volume"] = clampi(int(s["music_volume"]), 0, 100)
		if s.get("level_music_volume") != null:
			profile_settings["level_music_volume"] = clampi(int(s["level_music_volume"]), 0, 100)
		if s.get("sfx_volume") != null:
			profile_settings["sfx_volume"] = clampi(int(s["sfx_volume"]), 0, 100)
		if s.get("resolution") != null:
			profile_settings["resolution"] = String(s["resolution"])
		if s.get("graphics_profile") != null:
			profile_settings["graphics_profile"] = String(s["graphics_profile"])
		if s.get("language") != null:
			profile_settings["language"] = String(s["language"])
			cosmetics_state["language"] = profile_settings["language"]
		if s.has("keybindings") and s["keybindings"] is Dictionary:
			profile_settings["keybindings"] = (s["keybindings"] as Dictionary).duplicate()
		_apply_settings_to_engine()
		
	if payload.has("appearance") and payload["appearance"] is Dictionary:
		var app := payload["appearance"] as Dictionary
		cosmetics_state["active_skin"] = String(app.get("active_skin", cosmetics_state["active_skin"]))
		if app.has("active_skin_id") and app["active_skin_id"] != null:
			cosmetics_state["active_skin_id"] = int(app["active_skin_id"])
		cosmetics_state["active_color_name"] = String(app.get("active_color_name", cosmetics_state["active_color_name"]))
		cosmetics_state["active_color_hex"] = String(app.get("active_color_hex", cosmetics_state["active_color_hex"]))
		if app.has("active_color_id") and app["active_color_id"] != null:
			cosmetics_state["active_color_id"] = int(app["active_color_id"])
		if app.has("equipped_accessories") and app["equipped_accessories"] is Dictionary:
			cosmetics_state["equipped_accessories"] = (app["equipped_accessories"] as Dictionary).duplicate()
		if app.has("equipped_accessories_detail") and app["equipped_accessories_detail"] is Array:
			cosmetics_state["equipped_accessories_detail"] = (app["equipped_accessories_detail"] as Array).duplicate(true)
		if app.has("owned_items") and app["owned_items"] is Array:
			cosmetics_state["owned_items"] = (app["owned_items"] as Array).duplicate(true)
			
	if payload.has("boosters") and payload["boosters"] is Dictionary:
		var b := payload["boosters"] as Dictionary
		cosmetics_state["boosters"] = {
			"tarcza": 0,
			"podwójne punkty": 0,
			"dodatkowe życie": 0,
			"magnes": 0
		}
		for b_key in b.keys():
			cosmetics_state["boosters"][String(b_key)] = int(b[b_key])
			
	if payload.has("challenges") and payload["challenges"] is Array:
		var ch_list: Array[Dictionary] = []
		for item in payload["challenges"]:
			if item is Dictionary:
				ch_list.append((item as Dictionary).duplicate(true))
		active_challenges = ch_list
		
	last_sync_timestamp = Time.get_datetime_string_from_system(true)
	
	if is_instance_valid(Events):
		Events.portal_profile_synced.emit(build_current_state_payload())
		Events.portal_challenges_synced.emit(get_active_challenges())
	_is_applying_remote_payload = false

## Aplikuje pobrane ustawienia audio i przypisania klawiszy bezpośrednio do silnika Godot.
func _apply_settings_to_engine() -> void:
	var music_vol: float = float(profile_settings.get("music_volume", 80)) / 100.0
	var level_music_vol: float = float(profile_settings.get("level_music_volume", 70)) / 100.0
	var sfx_vol: float = float(profile_settings.get("sfx_volume", 100)) / 100.0
	
	var mus_menu_bus: int = AudioServer.get_bus_index("MusicMenu")
	if mus_menu_bus != -1:
		AudioServer.set_bus_mute(mus_menu_bus, music_vol <= 0.001)
		if music_vol > 0.001:
			AudioServer.set_bus_volume_db(mus_menu_bus, linear_to_db(music_vol))
			
	var mus_lvl_bus: int = AudioServer.get_bus_index("MusicLevel")
	if mus_lvl_bus != -1:
		AudioServer.set_bus_mute(mus_lvl_bus, level_music_vol <= 0.001)
		if level_music_vol > 0.001:
			AudioServer.set_bus_volume_db(mus_lvl_bus, linear_to_db(level_music_vol))

	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_mute(music_bus, music_vol <= 0.001)
		if music_vol > 0.001:
			AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_vol))
			
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_mute(sfx_bus, sfx_vol <= 0.001)
		if sfx_vol > 0.001:
			AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_vol))
			
	var kb: Dictionary = profile_settings.get("keybindings", {})
	for action_name in kb.keys():
		var key_str: String = String(kb[action_name])
		var keycode: Key = OS.find_keycode_from_string(key_str)
		if keycode != KEY_NONE and InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)

## Zwraca listę aktywnych wyzwań gracza (status == "Aktywne").
func get_active_challenges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ch in active_challenges:
		if String(ch.get("status", "Aktywne")) == "Aktywne":
			result.append(ch)
	return result

## Zwraca połączone wymagania ze wszystkich aktywnych zadań na stronie dla Generatora Map AI!
func get_aggregated_challenge_requirements() -> Dictionary:
	var min_jewels: int = 0
	var max_time_s: float = -1.0
	var require_completion: bool = false
	var focus_mechanics: Array[String] = []
	var has_acrobat_goal: bool = false
	var challenge_names: Array[String] = []
	
	for ch in get_active_challenges():
		challenge_names.append(String(ch.get("name", "Wyzwanie")))
		var conds: Dictionary = ch.get("completion_conditions", {}) if ch.get("completion_conditions") is Dictionary else {}
		if conds.has("min_klejnotow"):
			min_jewels = max(min_jewels, int(conds["min_klejnotow"]))
		if conds.has("max_czas_s"):
			var t: float = float(conds["max_czas_s"])
			if max_time_s < 0.0 or t < max_time_s:
				max_time_s = t
		if conds.has("ukoncz_poziom") and bool(conds["ukoncz_poziom"]):
			require_completion = true
		if conds.has("min_wynik") or String(ch.get("name", "")).to_lower().contains("akrobata"):
			has_acrobat_goal = true
		if conds.has("wymagana_mechanika"):
			var mech: String = String(conds["wymagana_mechanika"])
			if not focus_mechanics.has(mech):
				focus_mechanics.append(mech)
				
	return {
		"min_jewels": min_jewels,
		"max_time_s": max_time_s,
		"require_completion": require_completion,
		"has_acrobat_goal": has_acrobat_goal,
		"focus_mechanics": focus_mechanics,
		"active_challenge_names": challenge_names,
		"active_count": challenge_names.size()
	}

## Aktualizuje postęp wyzwań po ukończeniu poziomu w grze.
func evaluate_run_against_challenges(collected_jewels: int, elapsed_time: float, level_completed: bool, tricks_count: int = 0) -> Array[Dictionary]:
	var completed_now: Array[Dictionary] = []
	for ch in active_challenges:
		if String(ch.get("status", "")) != "Aktywne":
			continue
		var conds: Dictionary = ch.get("completion_conditions", {}) if ch.get("completion_conditions") is Dictionary else {}
		var passed: bool = true
		var progress: int = int(ch.get("progress_percent", 0))
		
		if conds.has("ukoncz_poziom"):
			if not level_completed:
				passed = false
			else:
				progress = 100
		if conds.has("min_klejnotow"):
			var req_j: int = max(1, int(conds["min_klejnotow"]))
			progress = max(progress, clampi(int(round((float(collected_jewels) / float(req_j)) * 100.0)), 0, 100))
			if collected_jewels < req_j or not level_completed:
				passed = false
		if conds.has("max_czas_s"):
			var max_t: float = float(conds["max_czas_s"])
			if not level_completed or elapsed_time > max_t:
				passed = false
			else:
				progress = 100
		if conds.has("min_wynik"):
			var req_s: int = max(1, int(conds["min_wynik"]))
			var equiv_pts: int = collected_jewels * 150 + tricks_count * 50
			progress = max(progress, clampi(int(round((float(equiv_pts) / float(req_s)) * 100.0)), 0, 100))
			if equiv_pts < req_s or not level_completed:
				passed = false
				
		ch["progress_percent"] = 100 if passed else progress
		if passed:
			ch["status"] = "Ukończone"
			completed_now.append(ch.duplicate(true))
			# Odblokowanie nagrody ze strony w lokalnym profilu gracza
			if ch.has("reward") and ch["reward"] is Dictionary:
				_grant_challenge_reward(ch["reward"] as Dictionary)
				
	if not completed_now.is_empty() and is_instance_valid(Events):
		Events.portal_challenges_synced.emit(get_active_challenges())
	return completed_now

func _grant_challenge_reward(reward: Dictionary) -> void:
	var r_type: String = String(reward.get("type", ""))
	match r_type:
		"klejnoty":
			player_profile["gems"] = int(player_profile.get("gems", 0)) + int(reward.get("gems", 0))
		"skórka":
			var s_name: String = String(reward.get("element_name", ""))
			if not s_name.is_empty():
				cosmetics_state["owned_items"].append({"type": "skórka", "name": s_name})
		"akcesorium":
			var a_name: String = String(reward.get("element_name", ""))
			if not a_name.is_empty():
				cosmetics_state["owned_items"].append({"type": "akcesorium", "name": a_name, "mount_point": "głowa"})
		"wzmocnienie":
			var b_type: String = String(reward.get("booster_type", ""))
			if not b_type.is_empty():
				cosmetics_state["boosters"][b_type] = int(cosmetics_state["boosters"].get(b_type, 0)) + 1

## Aplikuje pobrane ze strony skórki, kolory, akcesoria i wzmocnienia bezpośrednio na węzeł gracza (PlayerController).
func apply_cosmetics_and_boosters_to_player(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	var visuals: Node2D = player.get_node_or_null("Visuals")
	var anim_sprite: AnimatedSprite2D = player.get_node_or_null("Visuals/AnimatedSprite2D")
	
	# 1. Faktyczna podmiana assetów SpriteFrames w AnimatedSprite2D dla wybranej skórki
	var skin_name: String = String(cosmetics_state.get("active_skin", "Klasyczna Stelly"))
	SkinManager.apply_skin_to_player(player, skin_name)
	player.set_meta("portal_skin_tint", Color.WHITE)
	player.set_meta("portal_active_skin", skin_name)
	
	var color_hex: String = String(cosmetics_state.get("active_color_hex", "#6A3FB5"))
	var base_tint: Color = Color.from_string(color_hex, Color(0.42, 0.25, 0.71, 1.0))
		
	# 2. Akcesoria (np. "Czapka" na punkcie mocowania "głowa")
	if visuals:
		var existing_hat: Node2D = visuals.get_node_or_null("PortalAccessoryHat")
		var equipped: Dictionary = cosmetics_state.get("equipped_accessories", {})
		var head_item: String = String(equipped.get("głowa", ""))
		if not head_item.is_empty():
			if not existing_hat:
				existing_hat = Node2D.new()
				existing_hat.name = "PortalAccessoryHat"
				var brim := ColorRect.new()
				brim.name = "Brim"
				brim.position = Vector2(-7, -18)
				brim.size = Vector2(15, 3)
				brim.color = Color(0.95, 0.78, 0.15, 1.0) if (skin_name == "Bursztynowa Stelly" or skin_name == "Złoty biegacz") else base_tint.lightened(0.2)
				var crown := ColorRect.new()
				crown.name = "Crown"
				crown.position = Vector2(-5, -23)
				crown.size = Vector2(10, 5)
				crown.color = brim.color.darkened(0.15)
				existing_hat.add_child(brim)
				existing_hat.add_child(crown)
				visuals.add_child(existing_hat)
			existing_hat.visible = true
		elif existing_hat:
			existing_hat.visible = false
			
	# 3. Wzmocnienia (Boosters) z profilu webowego:
	# - "dodatkowe życie": zwiększa max_health o +1
	# - "tarcza": daje tarczę ochronną pochłaniającą 1 obrażenie
	# - "magnes": zwiększa zasięg przyciągania klejnotów
	# - "podwójne punkty": podwaja zdobywane punkty na poziomie
	var boosters: Dictionary = cosmetics_state.get("boosters", {})
	if int(boosters.get("dodatkowe życie", 0)) > 0 and player.has_method("set_max_health"):
		player.call("set_max_health", 4, true)
		player.set_meta("has_portal_extra_life", true)
	if int(boosters.get("tarcza", 0)) > 0:
		player.set_meta("has_portal_shield", true)
	if int(boosters.get("magnes", 0)) > 0:
		player.set_meta("has_portal_magnet", true)
	if int(boosters.get("podwójne punkty", 0)) > 0:
		player.set_meta("has_portal_double_points", true)

func build_current_state_payload() -> Dictionary:
	var mus_idx = AudioServer.get_bus_index("MusicMenu")
	if mus_idx == -1:
		mus_idx = AudioServer.get_bus_index("Music")
	if mus_idx != -1:
		profile_settings["music_volume"] = 0.0 if AudioServer.is_bus_mute(mus_idx) else clampf(db_to_linear(AudioServer.get_bus_volume_db(mus_idx)) * 100.0, 0.0, 100.0)
	var mus_lvl_idx = AudioServer.get_bus_index("MusicLevel")
	if mus_lvl_idx != -1:
		profile_settings["level_music_volume"] = 0.0 if AudioServer.is_bus_mute(mus_lvl_idx) else clampf(db_to_linear(AudioServer.get_bus_volume_db(mus_lvl_idx)) * 100.0, 0.0, 100.0)
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		profile_settings["sfx_volume"] = 0.0 if AudioServer.is_bus_mute(sfx_idx) else clampf(db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)) * 100.0, 0.0, 100.0)
	return {
		"player": player_profile.duplicate(true),
		"wallet": {
			"gems": player_profile.get("gems", 0),
			"special_gems": player_profile.get("special_gems", 0)
		},
		"settings": profile_settings.duplicate(true),
		"appearance": cosmetics_state.duplicate(true),
		"boosters": (cosmetics_state.get("boosters", {}) as Dictionary).duplicate(true),
		"challenges": active_challenges.duplicate(true)
	}

## Odłącza grę od konta w portalu (unieważnia sesję na serwerze i czyści lokalny stan).
func disconnect_account() -> void:
	var tok := session_token
	if not tok.is_empty() and _http_logout and is_inside_tree() and DisplayServer.get_name() != "headless":
		if _http_logout.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_http_logout.cancel_request()
		var headers := PackedStringArray(["Authorization: Bearer " + tok])
		_http_logout.request(api_base_url.trim_suffix("/") + "/auth/logout", headers, HTTPClient.METHOD_POST, "")
	_clear_local_session()
	if is_instance_valid(Events):
		Events.portal_profile_synced.emit(build_current_state_payload())
		Events.portal_challenges_synced.emit(get_active_challenges())
		Events.portal_daily_reward_updated.emit({})
		Events.portal_cloud_save_loaded.emit({})

## Obsługa wygasłej lub unieważnionej sesji gry (HTTP 401).
func handle_unauthorized() -> void:
	if not is_linked and session_token.is_empty():
		return
	_clear_local_session()
	if is_instance_valid(Events):
		Events.portal_profile_synced.emit(build_current_state_payload())
		Events.portal_challenges_synced.emit(get_active_challenges())
		Events.portal_daily_reward_updated.emit({})
		Events.portal_cloud_save_loaded.emit({})
		Events.portal_sync_failed.emit("unauthorized", "Sesja gry wygasła lub została odłączona w portalu. Wygeneruj nowy kod na /profil.")

func _on_logout_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	pass

func _clear_local_session() -> void:
	session_token = ""
	is_linked = false
	last_sync_timestamp = ""
	daily_reward_state = {}
	cloud_save = {}
	save_conflict_server = {}
	_last_local_save_payload = {}
	_pending_settings_patch = {}
	_inflight_settings_patch = {}
	player_profile = {
		"id": "",
		"username": "Gość",
		"email": "",
		"gems": 0,
		"special_gems": 0
	}
	cosmetics_state = {
		"active_skin": "Skórka podstawowa",
		"active_color_name": "Fioletowy",
		"active_color_hex": "#6A3FB5",
		"equipped_accessories": {},
		"owned_items": [
			{"type": "skórka", "name": "Skórka podstawowa"},
			{"type": "kolor", "name": "Fioletowy", "color_hex": "#6A3FB5"}
		],
		"boosters": {
			"tarcza": 0,
			"podwójne punkty": 0,
			"dodatkowe życie": 0,
			"magnes": 0
		}
	}
	_init_default_portal_challenges()
	if is_instance_valid(Events) and is_instance_valid(Events.wallet_sync) and Events.wallet_sync.has_method("sync_server_balance"):
		Events.wallet_sync.sync_server_balance(0)
	_save_session()

# ---------------------------------------------------------------- Faza 2: Ustawienia, Wygląd, Boostery, Cloud Save, Nagroda Dzienna

## Kolejkuje częściową aktualizację ustawień do wysłania na PATCH /api/me/settings (z debounce).
func queue_settings_sync(patch: Dictionary) -> void:
	if _is_applying_remote_payload or not is_linked or session_token.is_empty() or DisplayServer.get_name() == "headless":
		return
	var changed := false
	for k in ["music_volume", "level_music_volume", "sfx_volume"]:
		if patch.has(k) and patch[k] != null:
			_pending_settings_patch[k] = clampi(int(round(float(patch[k]))), 0, 100)
			changed = true
	if patch.has("resolution") and patch["resolution"] != null:
		var res_str := String(patch["resolution"]).strip_edges()
		if res_str.contains("x") and not res_str.contains(" ") and res_str.length() >= 7 and res_str.length() <= 9:
			_pending_settings_patch["resolution"] = res_str
			changed = true
	if patch.has("language") and patch["language"] != null:
		var lang := String(patch["language"]).strip_edges()
		if lang == "pl" or lang == "en":
			_pending_settings_patch["language"] = lang
			changed = true
	if changed:
		_pending_settings_patch["changed_at"] = int(Time.get_unix_time_from_system())
		if _settings_debounce_timer and is_inside_tree():
			_settings_debounce_timer.start()

func _flush_settings_patch() -> void:
	if _pending_settings_patch.is_empty() or not _inflight_settings_patch.is_empty():
		return
	if session_token.is_empty() or _http_settings == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	_inflight_settings_patch = _pending_settings_patch.duplicate(true)
	_pending_settings_patch.clear()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + session_token
	])
	var body: String = JSON.stringify(_inflight_settings_patch)
	var err: Error = _http_settings.request(api_base_url.trim_suffix("/") + "/me/settings", headers, HTTPClient.METHOD_PATCH, body)
	if err != OK:
		for k in _inflight_settings_patch.keys():
			if not _pending_settings_patch.has(k):
				_pending_settings_patch[k] = _inflight_settings_patch[k]
		_inflight_settings_patch.clear()

func _on_settings_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sent := _inflight_settings_patch.duplicate(true)
	_inflight_settings_patch.clear()
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		var s := parsed as Dictionary
		for k in ["music_volume", "level_music_volume", "sfx_volume", "resolution", "graphics_profile", "language"]:
			if s.get(k) != null:
				profile_settings[k] = s[k]
		if not _pending_settings_patch.is_empty() and _settings_debounce_timer and is_inside_tree():
			_settings_debounce_timer.start()
	elif response_code == 409 and parsed is Dictionary:
		var err_dict: Variant = (parsed as Dictionary).get("error")
		if err_dict is Dictionary and (err_dict as Dictionary).get("details") is Dictionary:
			var details := (err_dict as Dictionary)["details"] as Dictionary
			if details.get("server_settings") is Dictionary:
				apply_synced_payload({"settings": details["server_settings"]})
	elif response_code == 401:
		handle_unauthorized()
	elif response_code == 0 or response_code == 429 or response_code >= 500:
		for k in sent.keys():
			if not _pending_settings_patch.has(k):
				_pending_settings_patch[k] = sent[k]

## Sprawdza, czy skórka jest odblokowana na koncie gracza w portalu (w trybie Gościa / headless zawsze true).
func is_skin_owned(skin_identifier: Variant) -> bool:
	if not is_linked or DisplayServer.get_name() == "headless":
		return true
	var target_key := SkinManager.get_skin_key(skin_identifier)
	if target_key == "base":
		return true
	for item in cosmetics_state.get("owned_items", []):
		if item is Dictionary and String((item as Dictionary).get("type", "")) == "skórka":
			if SkinManager.get_skin_key((item as Dictionary).get("name", "")) == target_key:
				return true
	return false

func find_owned_element_id(kind: String, identifier: Variant) -> int:
	var target_key := SkinManager.get_skin_key(identifier) if kind == "skórka" else ""
	var target_name := String(identifier).strip_edges().to_lower()
	for item in cosmetics_state.get("owned_items", []):
		if not (item is Dictionary):
			continue
		var d := item as Dictionary
		if String(d.get("type", "")) != kind:
			continue
		var item_name := String(d.get("name", ""))
		if kind == "skórka":
			if SkinManager.get_skin_key(item_name) == target_key:
				return int(d.get("id", 0))
		elif item_name.strip_edges().to_lower() == target_name:
			return int(d.get("id", 0))
	return 0

## Wysyła wybraną skórkę i obecne akcesoria do PUT /api/me/appearance.
func save_appearance_to_web(skin_identifier: Variant) -> bool:
	if _is_applying_remote_payload or not is_linked or session_token.is_empty():
		return false
	if _http_appearance == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	var skin_id := find_owned_element_id("skórka", skin_identifier)
	if skin_id <= 0:
		return false
	var color_id := int(cosmetics_state.get("active_color_id", 0))
	if color_id <= 0:
		color_id = find_owned_element_id("kolor", cosmetics_state.get("active_color_name", "Fioletowy"))
	if color_id <= 0:
		for item in cosmetics_state.get("owned_items", []):
			if item is Dictionary and String((item as Dictionary).get("type", "")) == "kolor" and int((item as Dictionary).get("id", 0)) > 0:
				color_id = int((item as Dictionary)["id"])
				break
	if color_id <= 0:
		return false

	var accessories: Array = []
	for acc in cosmetics_state.get("equipped_accessories_detail", []):
		if acc is Dictionary and int((acc as Dictionary).get("accessory_id", 0)) > 0:
			var entry: Dictionary = {"accessory_id": int((acc as Dictionary)["accessory_id"])}
			if (acc as Dictionary).get("color_id") != null:
				entry["color_id"] = int((acc as Dictionary)["color_id"])
			accessories.append(entry)

	if _http_appearance.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_appearance.cancel_request()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + session_token
	])
	var payload: Dictionary = {
		"skin_id": skin_id,
		"color_id": color_id,
		"accessories": accessories,
		"changed_at": int(Time.get_unix_time_from_system())
	}
	return _http_appearance.request(api_base_url.trim_suffix("/") + "/me/appearance", headers, HTTPClient.METHOD_PUT, JSON.stringify(payload)) == OK

func _on_appearance_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		var data := parsed as Dictionary
		if data.get("skin") is Dictionary:
			var sk := data["skin"] as Dictionary
			cosmetics_state["active_skin"] = String(sk.get("name", cosmetics_state["active_skin"]))
			if sk.get("id") != null:
				cosmetics_state["active_skin_id"] = int(sk["id"])
		if data.get("color") is Dictionary:
			var col := data["color"] as Dictionary
			cosmetics_state["active_color_name"] = String(col.get("name", cosmetics_state["active_color_name"]))
			cosmetics_state["active_color_hex"] = String(col.get("hex", cosmetics_state["active_color_hex"]))
			if col.get("id") != null:
				cosmetics_state["active_color_id"] = int(col["id"])
		if data.get("accessories") is Array:
			var eq: Dictionary = {}
			var eq_detail: Array = []
			for acc in data["accessories"]:
				if acc is Dictionary and (acc as Dictionary).get("accessory") is Dictionary:
					var ad := acc as Dictionary
					var acc_info := ad["accessory"] as Dictionary
					var col_info: Variant = ad.get("color")
					eq[String(ad.get("slot", ""))] = String(acc_info.get("name", ""))
					eq_detail.append({
						"slot": String(ad.get("slot", "")),
						"accessory_id": int(acc_info.get("id", 0)),
						"name": String(acc_info.get("name", "")),
						"color_id": int((col_info as Dictionary)["id"]) if col_info is Dictionary and (col_info as Dictionary).get("id") != null else null
					})
			cosmetics_state["equipped_accessories"] = eq
			cosmetics_state["equipped_accessories_detail"] = eq_detail
	elif response_code == 409 or response_code == 422:
		request_sync_from_web()
	elif response_code == 401:
		handle_unauthorized()

## Kolejkuje i wysyła zużycie wzmocnienia na POST /api/me/boosters/use (idempotentne po operation_id).
func report_booster_used(booster_type: String, operation_id: String = "") -> bool:
	if not is_linked or session_token.is_empty():
		return false
	var boosters: Dictionary = cosmetics_state.get("boosters", {})
	boosters[booster_type] = maxi(0, int(boosters.get(booster_type, 0)) - 1)
	var op_id := _normalize_operation_id(operation_id)
	for item in pending_booster_uses:
		if String(item.get("operation_id", "")) == op_id:
			return false
	pending_booster_uses.append({"operation_id": op_id, "booster_type": booster_type})
	if boosters_queue_path != BOOSTERS_QUEUE_PATH or DisplayServer.get_name() != "headless":
		save_pending_booster_uses()
	flush_pending_booster_uses()
	return true

func _normalize_operation_id(raw_id: String) -> String:
	var clean := ""
	for ch in raw_id:
		if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch in ["_", ".", ":", "-"]:
			clean += ch
	if clean.length() < 8:
		clean = "BST-%d-%04d" % [int(Time.get_unix_time_from_system()), randi() % 9000 + 1000]
	return clean.substr(0, 64)

func flush_pending_booster_uses() -> bool:
	if pending_booster_uses.is_empty() or not _sending_booster_op_id.is_empty():
		return false
	if session_token.is_empty() or _http_booster == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	var op: Dictionary = pending_booster_uses[0]
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + session_token
	])
	var err: Error = _http_booster.request(api_base_url.trim_suffix("/") + "/me/boosters/use", headers, HTTPClient.METHOD_POST, JSON.stringify(op))
	if err != OK:
		return false
	_sending_booster_op_id = String(op.get("operation_id", ""))
	return true

func _on_booster_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sent_id := _sending_booster_op_id
	_sending_booster_op_id = ""
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		var data := parsed as Dictionary
		var b_type := String(data.get("booster_type", ""))
		if not b_type.is_empty() and data.has("remaining"):
			(cosmetics_state.get("boosters", {}) as Dictionary)[b_type] = int(data["remaining"])
		pending_booster_uses = _remove_by_key(pending_booster_uses, "operation_id", sent_id)
		if boosters_queue_path != BOOSTERS_QUEUE_PATH or DisplayServer.get_name() != "headless":
			save_pending_booster_uses()
		if not pending_booster_uses.is_empty():
			flush_pending_booster_uses()
	elif response_code == 401:
		handle_unauthorized()
	elif response_code == 409 or response_code == 422:
		push_warning("Serwer odrzucił zużycie wzmocnienia (%s, HTTP %d): %s" % [sent_id, response_code, body.get_string_from_utf8()])
		pending_booster_uses = _remove_by_key(pending_booster_uses, "operation_id", sent_id)
		if boosters_queue_path != BOOSTERS_QUEUE_PATH or DisplayServer.get_name() != "headless":
			save_pending_booster_uses()
		if not pending_booster_uses.is_empty():
			flush_pending_booster_uses()

func save_pending_booster_uses() -> void:
	_save_json_file(boosters_queue_path, {"pending_booster_uses": pending_booster_uses}, "kolejki wzmocnień")

func load_pending_booster_uses() -> void:
	pending_booster_uses = _load_json_array(boosters_queue_path, "pending_booster_uses", "operation_id")

## Zapis gry w chmurze (GET/PUT /api/me/save) z sumą kontrolną SHA-256 i rozwiązaniem konfliktu.
static func compute_save_checksum(level: int, checkpoint: String, gems: int, saved_at: int, game_version: String) -> String:
	return ("%d|%s|%d|%d|%s" % [level, checkpoint, gems, saved_at, game_version]).sha256_text()

func fetch_cloud_save() -> bool:
	if session_token.is_empty() or _http_save == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	if not _save_req_kind.is_empty():
		return false
	_save_req_kind = "get"
	var headers := PackedStringArray(["Authorization: Bearer " + session_token, "Accept: application/json"])
	var err: Error = _http_save.request(api_base_url.trim_suffix("/") + "/me/save", headers, HTTPClient.METHOD_GET)
	if err != OK:
		_save_req_kind = ""
		return false
	return true

func upload_cloud_save(level: int, checkpoint: String, gems: int, force: bool = false, custom_saved_at: int = -1) -> bool:
	if not is_linked or session_token.is_empty() or _http_save == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	if _http_save.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_save.cancel_request()
	var lvl := clampi(level, 1, 10000)
	var cp := checkpoint.strip_edges().substr(0, 64)
	var gm := clampi(gems, 0, 100000)
	var ts := custom_saved_at if custom_saved_at >= 0 else int(Time.get_unix_time_from_system())
	var payload: Dictionary = {
		"level": lvl,
		"checkpoint": cp,
		"gems": gm,
		"saved_at": ts,
		"game_version": GAME_VERSION,
		"checksum": compute_save_checksum(lvl, cp, gm, ts, GAME_VERSION)
	}
	_last_local_save_payload = payload.duplicate(true)
	_save_req_kind = "put"
	var url := api_base_url.trim_suffix("/") + "/me/save" + ("?force=true" if force else "")
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + session_token])
	var err: Error = _http_save.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(payload))
	if err != OK:
		_save_req_kind = ""
		return false
	return true

func resolve_save_conflict(keep_local: bool) -> void:
	if keep_local and not _last_local_save_payload.is_empty():
		upload_cloud_save(
			int(_last_local_save_payload.get("level", 1)),
			String(_last_local_save_payload.get("checkpoint", "")),
			int(_last_local_save_payload.get("gems", 0)),
			true
		)
	elif not save_conflict_server.is_empty():
		cloud_save = save_conflict_server.duplicate(true)
		save_conflict_server = {}
		if is_instance_valid(Events):
			Events.portal_cloud_save_loaded.emit(cloud_save)

func _on_save_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _save_req_kind
	_save_req_kind = ""
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		var data := parsed as Dictionary
		if kind == "get":
			var s: Variant = data.get("save")
			cloud_save = (s as Dictionary).duplicate(true) if s is Dictionary else {}
		else:
			cloud_save = data.duplicate(true)
			save_conflict_server = {}
		if is_instance_valid(Events):
			Events.portal_cloud_save_loaded.emit(cloud_save)
	elif response_code == 409 and parsed is Dictionary:
		var err_dict: Variant = (parsed as Dictionary).get("error")
		if err_dict is Dictionary and (err_dict as Dictionary).get("details") is Dictionary:
			var details := (err_dict as Dictionary)["details"] as Dictionary
			if details.get("server_save") is Dictionary:
				save_conflict_server = (details["server_save"] as Dictionary).duplicate(true)
				if is_instance_valid(Events):
					Events.portal_save_conflict.emit(_last_local_save_payload, save_conflict_server)
	elif response_code == 401:
		handle_unauthorized()

## Nagroda dzienna z portalu (GET /api/me/daily-reward i POST /api/me/daily-reward/claim).
func fetch_daily_reward() -> bool:
	if session_token.is_empty() or _http_daily == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	if not _daily_req_kind.is_empty():
		return false
	_daily_req_kind = "get"
	var headers := PackedStringArray(["Authorization: Bearer " + session_token, "Accept: application/json"])
	var err: Error = _http_daily.request(api_base_url.trim_suffix("/") + "/me/daily-reward", headers, HTTPClient.METHOD_GET)
	if err != OK:
		_daily_req_kind = ""
		return false
	return true

func claim_daily_reward() -> bool:
	if not is_linked or session_token.is_empty() or _http_daily == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	if _http_daily.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_daily.cancel_request()
	_daily_req_kind = "claim"
	var headers := PackedStringArray(["Authorization: Bearer " + session_token, "Content-Type: application/json"])
	var err: Error = _http_daily.request(api_base_url.trim_suffix("/") + "/me/daily-reward/claim", headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		_daily_req_kind = ""
		return false
	return true

func _on_daily_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _daily_req_kind
	_daily_req_kind = ""
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200 and parsed is Dictionary:
		daily_reward_state = (parsed as Dictionary).duplicate(true)
		if kind == "claim" and daily_reward_state.has("balance"):
			player_profile["gems"] = int(daily_reward_state["balance"])
			if is_instance_valid(Events) and is_instance_valid(Events.wallet_sync) and Events.wallet_sync.has_method("sync_server_balance"):
				Events.wallet_sync.sync_server_balance(int(player_profile["gems"]))
			if is_instance_valid(Events):
				Events.portal_profile_synced.emit(build_current_state_payload())
		if is_instance_valid(Events):
			Events.portal_daily_reward_updated.emit(daily_reward_state)
	elif response_code == 409:
		daily_reward_state["available"] = false
		if is_instance_valid(Events):
			Events.portal_daily_reward_updated.emit(daily_reward_state)
	elif response_code == 401:
		handle_unauthorized()
	elif kind == "claim" and is_instance_valid(Events):
		Events.portal_daily_reward_updated.emit(daily_reward_state)

## Kolejkuje i wysyła wynik rozgrywki do POST /api/game/runs (gdy gra jest sparowana z kontem).
func submit_game_run(run_session_id: String, level: int, completed: bool, score: int, time_s: float, gems: int, enemies_defeated: int = 0) -> bool:
	if not is_linked and session_token.is_empty():
		return false
	var sid := run_session_id.strip_edges()
	if sid.is_empty() or not sid.begins_with("SES-"):
		sid = "SES-%d-%04d" % [int(Time.get_unix_time_from_system()), randi() % 9000 + 1000]
	for item in pending_runs:
		if String(item.get("session_id", "")) == sid:
			return false
	var entry: Dictionary = {
		"session_id": sid,
		"level": clampi(level, 1, 10000),
		"completed": completed,
		"score": clampi(score, 0, 1000000),
		"time_s": snappedf(clampf(time_s, 0.0, 36000.0), 0.1),
		"gems": clampi(gems, 0, 10000),
		"enemies_defeated": clampi(enemies_defeated, 0, 10000)
	}
	pending_runs.append(entry)
	if runs_queue_path != RUNS_QUEUE_PATH or DisplayServer.get_name() != "headless":
		save_pending_runs()
	flush_pending_runs()
	return true

func flush_pending_runs() -> bool:
	if pending_runs.is_empty() or not _sending_run_id.is_empty():
		return false
	if session_token.is_empty() or _http_runs == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return false
	var run_data: Dictionary = pending_runs[0]
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + session_token
	])
	var body: String = JSON.stringify(run_data)
	var err: Error = _http_runs.request(api_base_url.trim_suffix("/") + "/game/runs", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		return false
	_sending_run_id = String(run_data.get("session_id", ""))
	return true

func _on_run_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sent_id := _sending_run_id
	_sending_run_id = ""
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	if response_code == 200:
		pending_runs = _remove_by_key(pending_runs, "session_id", sent_id)
		if runs_queue_path != RUNS_QUEUE_PATH or DisplayServer.get_name() != "headless":
			save_pending_runs()
		if is_instance_valid(Events):
			Events.portal_run_synced.emit(parsed if parsed is Dictionary else {})
		if not pending_runs.is_empty():
			flush_pending_runs()
		else:
			request_sync_from_web()
	elif response_code == 401:
		handle_unauthorized()
	elif response_code == 409 or response_code == 422:
		push_warning("Serwer odrzucił wynik gry (%s, HTTP %d): %s" % [sent_id, response_code, body.get_string_from_utf8()])
		pending_runs = _remove_by_key(pending_runs, "session_id", sent_id)
		if runs_queue_path != RUNS_QUEUE_PATH or DisplayServer.get_name() != "headless":
			save_pending_runs()
		if not pending_runs.is_empty():
			flush_pending_runs()

func save_pending_runs() -> void:
	_save_json_file(runs_queue_path, {"pending_runs": pending_runs}, "kolejki wyników")

func load_pending_runs() -> void:
	pending_runs = _load_json_array(runs_queue_path, "pending_runs", "session_id")

static func _remove_by_key(items: Array[Dictionary], key: String, value: String) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for item in items:
		if String(item.get(key, "")) != value:
			kept.append(item)
	return kept

func _save_json_file(path: String, data: Dictionary, label: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Nie udało się zapisać %s: %s" % [label, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data))

static func _load_json_array(path: String, array_key: String, required_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return result
	var parsed: Variant = safe_parse_json(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return result
	for item in (parsed as Dictionary).get(array_key, []):
		if item is Dictionary and (item as Dictionary).has(required_key):
			result.append((item as Dictionary).duplicate(true))
	return result

static func _extract_api_error(parsed: Variant, fallback_code: String, fallback_msg: String) -> Dictionary:
	var code := fallback_code
	var msg := fallback_msg
	if parsed is Dictionary and (parsed as Dictionary).get("error") is Dictionary:
		var err := (parsed as Dictionary)["error"] as Dictionary
		code = String(err.get("code", fallback_code))
		msg = String(err.get("message", fallback_msg))
	return {"code": code, "message": msg}

func _save_session() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("portal", "session_token", session_token)
	cfg.set_value("portal", "is_linked", is_linked)
	cfg.set_value("portal", "username", player_profile.get("username", "Gość"))
	cfg.save(SESSION_SAVE_PATH)

func _load_saved_session() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_SAVE_PATH) == OK:
		var tok := String(cfg.get_value("portal", "session_token", ""))
		if tok.begins_with("tok_") and tok.ends_with("_demo"):
			session_token = ""
			is_linked = false
			_save_session()
			return
		session_token = tok
		is_linked = bool(cfg.get_value("portal", "is_linked", false))
		player_profile["username"] = String(cfg.get_value("portal", "username", "Gość"))

static func safe_parse_json(text: String) -> Variant:
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) == OK:
		return json.data
	return null
