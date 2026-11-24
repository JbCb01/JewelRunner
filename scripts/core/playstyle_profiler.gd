extends Node
class_name PlayStyleProfiler

## Profil stylu gry gracza – trwała analiza (user://playstyle_profile.json) wszystkich przejść poziomów.
## Zbiera:
##  - ruchy: skoki, podwójne skoki, dashe, wślizgi, sekundy tricków i wspinaczki,
##  - błędy w strefach wyzwań (SkillZone: trafienia i upadki w przepaść per mechanika),
##  - wybory tras na rozwidleniach (wysoka/ryzykowna vs niska/bezpieczna),
##  - eksplorację (odsetek zebranych klejnotów, sekrety), tempo (czas przejścia) i porażki.
## Z tego wylicza profil używany przez kompozytor poziomu AI (Szachownica / Cyber Matrix):
## ulubione i unikane mechaniki, mechanikę sprawiającą najwięcej kłopotu, apetyt na ryzyko,
## styl eksploratora vs speedrunnera oraz szacowany poziom umiejętności.

const SAVE_PATH := "user://playstyle_profile.json"
const MECHANICS: Array[String] = ["double_jump", "dash", "wall_climb", "wall_jump", "slide", "trick", "trampoline"]
const RISKY_ROUTES: Array[String] = ["high", "sky", "canopy"]

var save_path: String = SAVE_PATH
var data: Dictionary = {}

# stan bieżącego przelotu
var _active_zones: Dictionary = {}      # "tag|uid" -> tag
var _entered_once: Dictionary = {}      # "tag|uid" -> true (w tym przelocie)
var _routes_recorded: Dictionary = {}   # uid -> true
var _run_start_ms: int = 0
var _run_level: int = 0
var _run_jewels: int = 0
var _run_jewel_total: int = 0
var _run_active: bool = false

func _ready() -> void:
	_reset_data()
	load_profile()
	if not is_instance_valid(Events):
		return
	Events.player_jumped.connect(_on_jumped)
	Events.player_dashed.connect(func(_d): _bump("dash"))
	Events.player_slid.connect(func(): _bump("slide"))
	Events.trick_performed.connect(func(points: int): _add_move("trick", float(points) / 120.0))
	Events.player_hit.connect(func(_dmg: int): _on_mistake("hits"))
	Events.player_fell_in_abyss.connect(func(_p): _on_mistake("falls"))
	Events.player_died.connect(_on_died)
	Events.jewel_collected.connect(func(_v, _p): _run_jewels += 1)
	Events.jewels_progress_updated.connect(func(_c: int, total: int): _run_jewel_total = max(_run_jewel_total, total))
	Events.special_jewel_collected.connect(func(_id, _n, _r, owned: bool): _inc("secrets_found", 0 if owned else 1))
	Events.enemy_defeated.connect(func(): _inc("enemies_defeated", 1))
	Events.level_started.connect(_on_level_started)
	Events.level_completed.connect(_on_level_completed)

func _reset_data() -> void:
	data = {
		"version": 1, "runs": 0, "completions": 0, "deaths": 0, "hits": 0, "falls": 0, "play_seconds": 0.0,
		"moves": {"jump": 0.0, "double_jump": 0.0, "dash": 0.0, "wall_climb": 0.0, "wall_jump": 0.0, "slide": 0.0, "trick": 0.0, "trampoline": 0.0},
		"zones": {},          # tag -> {entries, hits, falls}
		"routes": {"risky": 0, "safe": 0},
		"jewels_collected": 0, "jewels_available": 0, "secrets_found": 0, "enemies_defeated": 0,
		"best_times": {}
	}

# ------------------------------------------------------------------ zbieranie
func _on_jumped(is_double: bool) -> void:
	_bump("double_jump" if is_double else "jump")
	if not is_double and _active_tag("wall_jump"):
		_bump("wall_jump")

func _bump(move: String) -> void:
	_add_move(move, 1.0)

func _add_move(move: String, amount: float) -> void:
	var moves: Dictionary = data["moves"]
	moves[move] = float(moves.get(move, 0.0)) + amount

func _inc(key: String, amount: int) -> void:
	data[key] = int(data.get(key, 0)) + amount

func _active_tag(tag: String) -> bool:
	for k in _active_zones.keys():
		if String(_active_zones[k]) == tag:
			return true
	return false

func zone_entered(tag: String, uid: String) -> void:
	var key := "%s|%s" % [tag, uid]
	_active_zones[key] = tag
	if tag.begins_with("route:"):
		if not _routes_recorded.has(uid):
			_routes_recorded[uid] = true
			var route: String = tag.substr(6)
			var routes: Dictionary = data["routes"]
			var bucket: String = "risky" if RISKY_ROUTES.has(route) else "safe"
			routes[bucket] = int(routes.get(bucket, 0)) + 1
		return
	if not _entered_once.has(key):
		_entered_once[key] = true
		_zone(tag)["entries"] = int(_zone(tag)["entries"]) + 1
		if tag == "trampoline":
			_bump("trampoline")

func zone_exited(tag: String, uid: String) -> void:
	_active_zones.erase("%s|%s" % [tag, uid])

func _zone(tag: String) -> Dictionary:
	var zones: Dictionary = data["zones"]
	if not zones.has(tag):
		zones[tag] = {"entries": 0, "hits": 0, "falls": 0}
	return zones[tag]

func _on_mistake(kind: String) -> void:
	_inc(kind, 1)
	var tags: Dictionary = {}
	for k in _active_zones.keys():
		var t: String = String(_active_zones[k])
		if not t.begins_with("route:"):
			tags[t] = true
	for t in tags.keys():
		var z: Dictionary = _zone(t)
		z[kind] = int(z.get(kind, 0)) + 1
	if kind == "falls":
		_active_zones.clear()

func _on_level_started() -> void:
	_run_start_ms = Time.get_ticks_msec()
	_run_level = int(Events.selected_level_profile) if "selected_level_profile" in Events else 0
	_run_jewels = 0
	_run_jewel_total = 0
	_active_zones.clear()
	_entered_once.clear()
	_routes_recorded.clear()
	_run_active = true
	_inc("runs", 1)

func _close_run(completed: bool) -> void:
	if not _run_active:
		return
	_run_active = false
	var secs: float = float(Time.get_ticks_msec() - _run_start_ms) / 1000.0
	data["play_seconds"] = float(data.get("play_seconds", 0.0)) + secs
	data["jewels_collected"] = int(data.get("jewels_collected", 0)) + _run_jewels
	data["jewels_available"] = int(data.get("jewels_available", 0)) + max(_run_jewel_total, _run_jewels)
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		_add_move("wall_climb", float(Events.ai_director.move_total_uses.get("wall_climb", 0.0)))
	if completed:
		_inc("completions", 1)
		var bt: Dictionary = data["best_times"]
		var key := str(_run_level)
		if not bt.has(key) or secs < float(bt[key]):
			bt[key] = secs
	save_profile()
	_push_history_to_director()

func _on_level_completed() -> void:
	_close_run(true)

func _on_died() -> void:
	_inc("deaths", 1)
	_close_run(false)

# ------------------------------------------------------------------ zapis / odczyt
func save_profile() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_profile() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) == OK and json.data is Dictionary:
		var loaded: Dictionary = json.data
		for k in loaded.keys():
			data[k] = loaded[k]
	_push_history_to_director()

## Historia ruchów z poprzednich sesji trafia do Reżysera AI (ulubiony / unikany ruch przetrwa restart gry).
func _push_history_to_director() -> void:
	if not is_instance_valid(Events) or not is_instance_valid(Events.ai_director):
		return
	var moves: Dictionary = data["moves"]
	var hist: Dictionary = Events.ai_director.historical_move_uses
	hist["double_jump"] = max(float(hist.get("double_jump", 0.0)), float(moves.get("double_jump", 0.0)))
	hist["dash"] = max(float(hist.get("dash", 0.0)), float(moves.get("dash", 0.0)))
	hist["wall_climb"] = max(float(hist.get("wall_climb", 0.0)), float(moves.get("wall_climb", 0.0)) + float(moves.get("wall_jump", 0.0)))

func reset_profile() -> void:
	_reset_data()
	save_profile()

# ------------------------------------------------------------------ analiza
## Zwraca wyliczony profil stylu gry (wszystkie wartości znormalizowane 0..1 tam, gdzie to ma sens).
func get_profile() -> Dictionary:
	var moves: Dictionary = data["moves"]
	var minutes: float = max(1.0, float(data.get("play_seconds", 0.0)) / 60.0)
	var usage: Dictionary = {}
	var total_use: float = 0.0
	for m in MECHANICS:
		var v: float = float(moves.get(m, 0.0)) / minutes
		if m == "trick" or m == "wall_climb":
			v *= 3.0                       # sekundy -> porównywalne z liczbą użyć
		usage[m] = v
		total_use += v
	var shares: Dictionary = {}
	for m in MECHANICS:
		shares[m] = (float(usage[m]) / total_use) if total_use > 0.0 else 1.0 / float(MECHANICS.size())

	# trudność per mechanika: (trafienia + 2*upadki) / (wejścia + 2) – wygładzone, by 1 błąd nie przesądzał
	var struggle: Dictionary = {}
	var zones: Dictionary = data["zones"]
	for m in MECHANICS:
		var z: Dictionary = zones.get(m, {})
		var e: float = float(z.get("entries", 0))
		struggle[m] = (float(z.get("hits", 0)) + 2.0 * float(z.get("falls", 0))) / (e + 2.0)

	var routes: Dictionary = data["routes"]
	var risky: float = float(routes.get("risky", 0))
	var safe: float = float(routes.get("safe", 0))
	var risk_appetite: float = (risky + 1.0) / (risky + safe + 2.0)

	var avail: float = float(data.get("jewels_available", 0))
	var explorer: float = (float(data.get("jewels_collected", 0)) / avail) if avail > 0.0 else 0.5

	var runs: float = max(1.0, float(data.get("runs", 0)))
	var completion_rate: float = float(data.get("completions", 0)) / runs
	var mistakes_per_min: float = (float(data.get("hits", 0)) + 2.0 * float(data.get("falls", 0))) / minutes
	var skill: float = clampf(0.25 + 0.45 * completion_rate + 0.3 * clampf(1.0 - mistakes_per_min / 3.0, 0.0, 1.0), 0.0, 1.0)
	if float(data.get("runs", 0)) < 1.0:
		skill = 0.4

	var ranked: Array = MECHANICS.duplicate()
	ranked.sort_custom(func(a, b) -> bool: return float(shares[a]) > float(shares[b]))
	var weakest: String = ""
	var worst: float = 0.0
	for m in MECHANICS:
		if float(zones.get(m, {}).get("entries", 0)) >= 2.0 and float(struggle[m]) > worst:
			worst = float(struggle[m])
			weakest = m
	return {
		"has_data": float(data.get("runs", 0)) > 0.0,
		"runs": int(data.get("runs", 0)), "completions": int(data.get("completions", 0)),
		"usage_shares": shares, "favorite": String(ranked[0]), "least_used": String(ranked[ranked.size() - 1]),
		"ranked_mechanics": ranked, "struggle": struggle, "weakest": weakest, "weakest_rate": worst,
		"risk_appetite": risk_appetite, "explorer": explorer, "secrets_found": int(data.get("secrets_found", 0)),
		"skill": skill, "mistakes_per_min": mistakes_per_min, "completion_rate": completion_rate
	}
