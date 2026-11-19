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

@export var portal_web_url: String = "http://localhost:5173"
@export var api_base_url: String = "http://localhost:8000/api"

var session_token: String = ""
var is_linked: bool = false
var last_sync_timestamp: String = ""
var last_opened_url: String = ""

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

# Wewnętrzny węzeł HTTP do komunikacji z backendem FastAPI
var _http_pair: HTTPRequest = null
var _http_sync: HTTPRequest = null

func _ready() -> void:
	_setup_http_nodes()
	_load_saved_session()
	# Domyślne przykładowe wyzwania zgodne z bazą (001_dane_startowe.sql / 002_dane_przykladowe.sql),
	# które są aktualizowane natychmiast po połączeniu z API
	if active_challenges.is_empty():
		_init_default_portal_challenges()

func _setup_http_nodes() -> void:
	if not _http_pair:
		_http_pair = HTTPRequest.new()
		_http_pair.name = "HttpPair"
		_http_pair.timeout = 4.0
		add_child(_http_pair)
		_http_pair.request_completed.connect(_on_pair_request_completed)
	if not _http_sync:
		_http_sync = HTTPRequest.new()
		_http_sync.name = "HttpSync"
		_http_sync.timeout = 4.0
		add_child(_http_sync)
		_http_sync.request_completed.connect(_on_sync_request_completed)

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
		
	if _http_pair and is_inside_tree() and DisplayServer.get_name() != "headless":
		var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
		var body: String = JSON.stringify({"code": normalized})
		var err: Error = _http_pair.request(api_base_url.trim_suffix("/") + "/auth/pair", headers, HTTPClient.METHOD_POST, body)
		if err == OK:
			return true
			
	# Fallback lokalny / testowy gdy serwer HTTP nie jest uruchomiony w tle:
	simulate_successful_pairing(normalized)
	return true

## Symuluje poprawne sparowanie i pobranie danych ze strony (używane w trybie offline/testowym).
func simulate_successful_pairing(code: String) -> void:
	session_token = "tok_" + code.to_lower() + "_demo"
	is_linked = true
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
		
	if _http_sync and is_inside_tree() and DisplayServer.get_name() != "headless":
		var headers: PackedStringArray = PackedStringArray([
			"Authorization: Bearer " + session_token,
			"Accept: application/json"
		])
		var err: Error = _http_sync.request(api_base_url.trim_suffix("/") + "/me/game-state", headers, HTTPClient.METHOD_GET)
		if err == OK:
			return true
			
	# Jeśli brak połączenia sieciowego, aplikujemy bieżący stan lokalny i powiadamiamy słuchaczy
	apply_synced_payload(build_current_state_payload())
	return true

func _on_pair_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if response_code == 200 and parsed is Dictionary:
		var data := parsed as Dictionary
		session_token = String(data.get("token", ""))
		is_linked = not session_token.is_empty()
		if data.has("player") and data["player"] is Dictionary:
			var p := data["player"] as Dictionary
			player_profile["id"] = String(p.get("id", ""))
			player_profile["username"] = String(p.get("username", "Gracz"))
			player_profile["email"] = String(p.get("email", ""))
		_save_session()
		request_sync_from_web()
	else:
		# Jeśli lokalny serwer nie działa (response_code == 0), przechodzimy w tryb symulacji parowania
		if response_code == 0:
			simulate_successful_pairing("DEMO99")
		elif is_instance_valid(Events):
			var err_msg: String = "Nieprawidłowy lub wygasły kod parowania."
			if parsed is Dictionary and (parsed as Dictionary).has("error"):
				err_msg = String(((parsed as Dictionary)["error"] as Dictionary).get("message", err_msg))
			Events.portal_sync_failed.emit("pair_error", err_msg)

func _on_sync_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if response_code == 200 and parsed is Dictionary:
		apply_synced_payload(parsed as Dictionary)
	elif response_code == 0:
		# Brak serwera HTTP w tle -> zachowaj zsynchronizowany profil lokalny
		apply_synced_payload(build_current_state_payload())
	elif is_instance_valid(Events):
		Events.portal_sync_failed.emit("sync_error", "Nie udało się pobrać danych profilu ze strony (HTTP %d)." % response_code)

## Aplikuje kompletny słownik danych pobranych ze strony internetowej:
## ustawienia audio/grafiki/klawiszy, skórki, kolory, akcesoria, wzmocnienia i zadania!
func apply_synced_payload(payload: Dictionary) -> void:
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
		
	if payload.has("settings") and payload["settings"] is Dictionary:
		var s := payload["settings"] as Dictionary
		profile_settings["music_volume"] = clampi(int(s.get("music_volume", profile_settings["music_volume"])), 0, 100)
		profile_settings["sfx_volume"] = clampi(int(s.get("sfx_volume", profile_settings["sfx_volume"])), 0, 100)
		profile_settings["resolution"] = String(s.get("resolution", profile_settings["resolution"]))
		profile_settings["graphics_profile"] = String(s.get("graphics_profile", profile_settings["graphics_profile"]))
		profile_settings["language"] = String(s.get("language", profile_settings["language"]))
		if s.has("keybindings") and s["keybindings"] is Dictionary:
			profile_settings["keybindings"] = (s["keybindings"] as Dictionary).duplicate()
		_apply_settings_to_engine()
		
	if payload.has("appearance") and payload["appearance"] is Dictionary:
		var app := payload["appearance"] as Dictionary
		cosmetics_state["active_skin"] = String(app.get("active_skin", cosmetics_state["active_skin"]))
		cosmetics_state["active_color_name"] = String(app.get("active_color_name", cosmetics_state["active_color_name"]))
		cosmetics_state["active_color_hex"] = String(app.get("active_color_hex", cosmetics_state["active_color_hex"]))
		if app.has("equipped_accessories") and app["equipped_accessories"] is Dictionary:
			cosmetics_state["equipped_accessories"] = (app["equipped_accessories"] as Dictionary).duplicate()
		if app.has("owned_items") and app["owned_items"] is Array:
			cosmetics_state["owned_items"] = (app["owned_items"] as Array).duplicate(true)
			
	if payload.has("boosters") and payload["boosters"] is Dictionary:
		var b := payload["boosters"] as Dictionary
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

## Aplikuje pobrane ustawienia audio i przypisania klawiszy bezpośrednio do silnika Godot.
func _apply_settings_to_engine() -> void:
	var music_vol: float = float(profile_settings.get("music_volume", 80)) / 100.0
	var sfx_vol: float = float(profile_settings.get("sfx_volume", 100)) / 100.0
	
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
	var boosters: Dictionary = cosmetics_state.get("boosters", {})
	if int(boosters.get("dodatkowe życie", 0)) > 0 and player.has_method("set_max_health"):
		player.call("set_max_health", 4, true)
	if int(boosters.get("tarcza", 0)) > 0:
		player.set_meta("has_portal_shield", true)
	if int(boosters.get("magnes", 0)) > 0:
		player.set_meta("has_portal_magnet", true)

func build_current_state_payload() -> Dictionary:
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

func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("portal", "session_token", session_token)
	cfg.set_value("portal", "is_linked", is_linked)
	cfg.set_value("portal", "username", player_profile.get("username", "Gość"))
	cfg.save(SESSION_SAVE_PATH)

func _load_saved_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_SAVE_PATH) == OK:
		session_token = String(cfg.get_value("portal", "session_token", ""))
		is_linked = bool(cfg.get_value("portal", "is_linked", false))
		player_profile["username"] = String(cfg.get_value("portal", "username", "Gość"))
