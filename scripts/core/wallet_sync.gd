extends Node

## Bufor salda klejnotów (historyjka 7.1, zadanie „Buforowanie offline i synchronizacja salda klejnotów”).
##
## Klejnoty zebrane w ukończonym poziomie trafiają do lokalnej kolejki zapisanej w user://.
## Kolejka jest wysyłana na serwer (POST /api/me/wallet/sync), gdy gra ma połączenie i jest sparowana
## z kontem. Bez internetu nic nie ginie: operacje czekają w pliku i są wysyłane przy następnej próbie
## (co 30 s, po starcie gry i po ukończeniu poziomu). Każda operacja ma stały identyfikator (ID sesji
## gry), więc ponowne wysłanie nie dolicza klejnotów drugi raz – serwer odpowiada „duplicates”.
##
## Saldo widoczne w grze = ostatnie saldo z serwera + klejnoty czekające w kolejce.

signal balance_changed(balance: int, pending_gems: int)

const QUEUE_PATH: String = "user://wallet_queue.json"
const RETRY_INTERVAL_S: float = 30.0
# Limity serwera: maks. 500 klejnotów w operacji, 50 operacji i 2000 klejnotów w jednym żądaniu.
const MAX_GEMS_PER_OPERATION: int = 500
const MAX_OPERATIONS_PER_REQUEST: int = 50
const MAX_GEMS_PER_REQUEST: int = 2000

## Operacje czekające na wysłanie: [{"id": String, "gems": int, "reason": String}]
var pending: Array[Dictionary] = []
## Saldo potwierdzone przez serwer przy ostatniej udanej synchronizacji.
var server_balance: int = 0
## Ścieżka pliku kolejki; testy podmieniają ją na plik tymczasowy.
var queue_path: String = QUEUE_PATH

var _run_gems: int = 0
var _sending_ids: Array[String] = []
var _http: HTTPRequest = null
var _timer: Timer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_queue()
	_http = HTTPRequest.new()
	_http.name = "HttpWallet"
	_http.timeout = 30.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_timer = Timer.new()
	_timer.wait_time = RETRY_INTERVAL_S
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(flush)

	if is_instance_valid(Events):
		Events.jewel_collected.connect(_on_jewel_collected)
		Events.level_completed.connect(_on_level_completed)
		Events.session_started.connect(_on_new_run)
		Events.run_restarted.connect(_on_new_run)
	flush.call_deferred()

# ---------------------------------------------------------------- rozgrywka

func _on_jewel_collected(_value: int, _position: Vector2) -> void:
	_run_gems += 1

func _on_new_run(_arg: Variant = null) -> void:
	# Restart poziomu przepada: klejnoty liczą się dopiero po ukończeniu.
	_run_gems = 0

func _on_level_completed() -> void:
	if _run_gems <= 0:
		return
	var run_id: String = Events.session_id if is_instance_valid(Events) and not Events.session_id.is_empty() else ""
	if run_id.is_empty():
		run_id = "RUN-%d-%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
	enqueue(run_id, _run_gems, "poziom")
	_run_gems = 0

# ---------------------------------------------------------------- kolejka

## Dodaje klejnoty do kolejki. Duża liczba jest dzielona na operacje po maks. 500 (id-1, id-2, ...).
func enqueue(operation_id: String, gems: int, reason: String = "rozgrywka") -> void:
	if gems <= 0:
		return
	var parts: int = int(ceil(float(gems) / MAX_GEMS_PER_OPERATION))
	var left: int = gems
	for i in range(parts):
		var amount: int = mini(left, MAX_GEMS_PER_OPERATION)
		var op_id: String = operation_id if parts == 1 else "%s-%d" % [operation_id, i + 1]
		left -= amount
		if _has_operation(op_id):
			continue
		pending.append({"id": op_id, "gems": amount, "reason": reason})
	save_queue()
	_emit_balance()
	flush()

func pending_gems() -> int:
	var total: int = 0
	for op in pending:
		total += int(op.get("gems", 0))
	return total

## Saldo do pokazania w grze, także bez internetu.
func local_balance() -> int:
	return server_balance + pending_gems()

## Najstarsze operacje mieszczące się w limitach serwera.
func next_batch() -> Array[Dictionary]:
	var batch: Array[Dictionary] = []
	var gems: int = 0
	for op in pending:
		var amount: int = int(op.get("gems", 0))
		if batch.size() >= MAX_OPERATIONS_PER_REQUEST or gems + amount > MAX_GEMS_PER_REQUEST:
			break
		batch.append(op)
		gems += amount
	return batch

func _has_operation(op_id: String) -> bool:
	for op in pending:
		if String(op.get("id", "")) == op_id:
			return true
	return false

# ---------------------------------------------------------------- serwer

## Wysyła kolejkę, jeśli gra jest sparowana z kontem. Zwraca true, gdy żądanie zostało wysłane.
func flush() -> bool:
	if pending.is_empty() or not _sending_ids.is_empty():
		return false
	var token: String = _session_token()
	if token.is_empty() or _http == null or not is_inside_tree():
		return false  # gra bez konta albo jeszcze niesparowana: kolejka czeka
	var batch: Array[Dictionary] = next_batch()
	if batch.is_empty():
		return false
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	])
	var body: String = JSON.stringify({"operations": batch})
	var err: Error = _http.request(_api_base_url() + "/me/wallet/sync", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		return false
	_sending_ids.clear()
	for op in batch:
		_sending_ids.append(String(op["id"]))
	return true

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = safe_parse_json(body.get_string_from_utf8())
	var sent: Array[String] = _sending_ids.duplicate()
	_sending_ids.clear()
	if response_code == 401 and is_inside_tree() and is_instance_valid(Events) and is_instance_valid(Events.portal_sync) and Events.portal_sync.has_method("handle_unauthorized"):
		Events.portal_sync.handle_unauthorized()
	if apply_response(response_code, parsed, sent) and not pending.is_empty():
		flush()

## Przetwarza odpowiedź serwera. Zwraca true, gdy synchronizacja się udała.
## Wydzielone z obsługi HTTP, żeby dało się to przetestować bez serwera.
func apply_response(response_code: int, parsed: Variant, sent_ids: Array[String]) -> bool:
	if response_code == 200 and parsed is Dictionary:
		var data := parsed as Dictionary
		var done: Array[String] = []
		for id in data.get("applied", []):
			done.append(String(id))
		for id in data.get("duplicates", []):
			done.append(String(id))
		_remove_operations(done)
		server_balance = int(data.get("gems", server_balance))
		save_queue()
		_update_portal_profile()
		_emit_balance()
		return true
	if response_code == 422:
		# Serwer odrzucił dane (np. zły format). Ponawianie nic nie da, a zablokowałoby kolejkę.
		push_warning("Serwer odrzucił operacje salda klejnotów: %s" % [sent_ids])
		_remove_operations(sent_ids)
		save_queue()
		_emit_balance()
		return false
	# 0 (brak internetu), 401 (trzeba ponownie sparować), 429 (limit), 5xx: kolejka zostaje do następnej próby.
	return false

func _remove_operations(ids: Array[String]) -> void:
	var kept: Array[Dictionary] = []
	for op in pending:
		if not ids.has(String(op.get("id", ""))):
			kept.append(op)
	pending = kept

func _session_token() -> String:
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		return String(Events.portal_sync.get("session_token"))
	return ""

func _api_base_url() -> String:
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		return String(Events.portal_sync.get("api_base_url")).trim_suffix("/")
	var env_api: String = OS.get_environment("JEWELRUNNER_API_URL").strip_edges()
	if not env_api.is_empty():
		return env_api.trim_suffix("/")
	return "https://jewelrunner-app.azurewebsites.net/api"

func sync_server_balance(balance: int) -> void:
	server_balance = maxi(0, balance)
	if queue_path != QUEUE_PATH or DisplayServer.get_name() != "headless":
		save_queue()
	_emit_balance()

func _update_portal_profile() -> void:
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var profile: Variant = Events.portal_sync.get("player_profile")
		if profile is Dictionary:
			(profile as Dictionary)["gems"] = local_balance()

func _emit_balance() -> void:
	balance_changed.emit(local_balance(), pending_gems())

# ---------------------------------------------------------------- plik kolejki

func save_queue() -> void:
	var file := FileAccess.open(queue_path, FileAccess.WRITE)
	if file == null:
		push_warning("Nie udało się zapisać kolejki klejnotów: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"server_balance": server_balance, "pending": pending}))

func load_queue() -> void:
	pending.clear()
	if not FileAccess.file_exists(queue_path):
		return
	var parsed: Variant = safe_parse_json(FileAccess.get_file_as_string(queue_path))
	if not parsed is Dictionary:
		push_warning("Plik kolejki klejnotów jest uszkodzony; zaczynamy od pustej kolejki.")
		return
	var data := parsed as Dictionary
	server_balance = int(data.get("server_balance", 0))
	for op in data.get("pending", []):
		if op is Dictionary and (op as Dictionary).has("id") and int((op as Dictionary).get("gems", 0)) > 0:
			pending.append({
				"id": String(op["id"]),
				"gems": int(op["gems"]),
				"reason": String((op as Dictionary).get("reason", "rozgrywka")),
			})

static func safe_parse_json(text: String) -> Variant:
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) == OK:
		return json.data
	return null
