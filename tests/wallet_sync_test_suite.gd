extends Node

## Testy bufora salda klejnotów (wallet_sync.gd): kolejka offline, limity serwera,
## obsługa odpowiedzi serwera i zapis kolejki na dysku. Nie wymagają serwera.
## Uruchomienie: Godot --headless res://scenes/wallet_sync_test_scene.tscn

const WalletSyncScript = preload("res://scripts/core/wallet_sync.gd")
const TEST_QUEUE: String = "user://test_wallet_queue.json"

var passCnt: int = 0
var failCnt: int = 0

func _ready() -> void:
	print("=== TESTY BUFORA SALDA KLEJNOTÓW (WALLET SYNC) ===")
	utEnqueueAndLocalBalance()
	utSameOperationIsNotDuplicated()
	utLargeAmountIsSplit()
	utBatchRespectsServerLimits()
	utSuccessRemovesAppliedAndDuplicates()
	utOfflineKeepsQueue()
	utUnauthorizedKeepsQueue()
	utRejectedOperationsAreDropped()
	utQueueSurvivesRestart()
	utCorruptedQueueFileStartsEmpty()
	utLevelRunAddsCollectedGems()
	utRestartDiscardsRunGems()
	utNoTokenDoesNotSend()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_QUEUE))
	print("PODSUMOWANIE WALLET SYNC: ZALICZONE: %d | BŁĘDY: %d" % [passCnt, failCnt])
	get_tree().quit(1 if failCnt > 0 else 0)

func assertCond(cond: bool, testId: String, desc: String) -> void:
	if cond:
		passCnt += 1
		print("[PASS] %s: %s" % [testId, desc])
	else:
		failCnt += 1
		print("[FAIL] %s: %s" % [testId, desc])

## Instancja bez dodawania do drzewa: bez HTTP i timera, z tymczasowym plikiem kolejki.
func _wallet() -> Node:
	var w: Node = WalletSyncScript.new()
	w.queue_path = TEST_QUEUE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_QUEUE))
	return w

func _ids(arr: Array[String]) -> Array[String]:
	return arr

func utEnqueueAndLocalBalance() -> void:
	var w := _wallet()
	w.server_balance = 100
	w.enqueue("SES-1-0001", 15)
	w.enqueue("SES-1-0002", 5)
	assertCond(w.pending.size() == 2 and w.local_balance() == 120, "WAL-01",
		"Klejnoty z kolejki doliczają się do salda w grze (100 + 15 + 5 = 120)")
	w.free()

func utSameOperationIsNotDuplicated() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 15)
	w.enqueue("SES-1-0001", 15)
	assertCond(w.pending.size() == 1 and w.pending_gems() == 15, "WAL-02",
		"Ta sama operacja dodana dwa razy jest w kolejce raz")
	w.free()

func utLargeAmountIsSplit() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 1200)
	var amounts: Array = w.pending.map(func(op): return op["gems"])
	assertCond(amounts == [500, 500, 200] and w.pending[2]["id"] == "SES-1-0001-3", "WAL-03",
		"1200 klejnotów dzieli się na operacje po maks. 500 (limit serwera)")
	w.free()

func utBatchRespectsServerLimits() -> void:
	var w := _wallet()
	for i in range(6):
		w.enqueue("SES-2-%04d" % i, 500)
	var batch: Array[Dictionary] = w.next_batch()
	var w2 := _wallet()
	for i in range(60):
		w2.enqueue("SES-3-%04d" % i, 1)
	assertCond(batch.size() == 4 and w2.next_batch().size() == 50, "WAL-04",
		"Paczka mieści się w limitach serwera: maks. 2000 klejnotów i 50 operacji")
	w.free()
	w2.free()

func utSuccessRemovesAppliedAndDuplicates() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 15)
	w.enqueue("SES-1-0002", 5)
	w.enqueue("SES-1-0003", 7)
	var ok: bool = w.apply_response(200, {"gems": 40, "applied": ["SES-1-0002"], "duplicates": ["SES-1-0001"]},
		_ids(["SES-1-0001", "SES-1-0002"]))
	assertCond(ok and w.pending.size() == 1 and w.server_balance == 40 and w.local_balance() == 47, "WAL-05",
		"Po udanej synchronizacji wysłane operacje znikają z kolejki, a saldo pochodzi z serwera")
	w.free()

func utOfflineKeepsQueue() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 15)
	var ok: bool = w.apply_response(0, null, _ids(["SES-1-0001"]))
	assertCond(not ok and w.pending.size() == 1, "WAL-06", "Brak internetu: kolejka zostaje do następnej próby")
	w.free()

func utUnauthorizedKeepsQueue() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 15)
	w.apply_response(401, {"error": {"code": "unauthorized"}}, _ids(["SES-1-0001"]))
	w.apply_response(503, null, _ids(["SES-1-0001"]))
	assertCond(w.pending.size() == 1, "WAL-07", "Wygasła sesja lub błąd serwera nie kasują zebranych klejnotów")
	w.free()

func utRejectedOperationsAreDropped() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 15)
	w.enqueue("SES-1-0002", 5)
	w.apply_response(422, {"error": {"code": "validation_error"}}, _ids(["SES-1-0001"]))
	assertCond(w.pending.size() == 1 and w.pending[0]["id"] == "SES-1-0002", "WAL-08",
		"Operacje odrzucone przez serwer (422) są usuwane, żeby nie blokowały kolejki")
	w.free()

func utQueueSurvivesRestart() -> void:
	var w := _wallet()
	w.server_balance = 30
	w.enqueue("SES-1-0001", 15)
	w.free()
	var again: Node = WalletSyncScript.new()
	again.queue_path = TEST_QUEUE
	again.load_queue()
	assertCond(again.pending.size() == 1 and again.local_balance() == 45, "WAL-09",
		"Kolejka i saldo są zapisane na dysku i wracają po ponownym uruchomieniu gry")
	again.free()

func utCorruptedQueueFileStartsEmpty() -> void:
	var file := FileAccess.open(TEST_QUEUE, FileAccess.WRITE)
	file.store_string("{to nie jest json")
	file.close()
	var w: Node = WalletSyncScript.new()
	w.queue_path = TEST_QUEUE
	w.load_queue()
	assertCond(w.pending.is_empty(), "WAL-10", "Uszkodzony plik kolejki nie wywraca gry")
	w.free()

func utLevelRunAddsCollectedGems() -> void:
	var w := _wallet()
	Events.session_id = "SES-1700000000-1234"
	w._on_new_run("SES-1700000000-1234")
	for i in range(3):
		w._on_jewel_collected(10, Vector2.ZERO)
	w._on_level_completed()
	assertCond(w.pending.size() == 1 and w.pending[0]["id"] == "SES-1700000000-1234" and w.pending[0]["gems"] == 3,
		"WAL-11", "Ukończony poziom dodaje do kolejki zebrane klejnoty z ID sesji gry")
	w.free()

func utRestartDiscardsRunGems() -> void:
	var w := _wallet()
	w._on_jewel_collected(10, Vector2.ZERO)
	w._on_new_run()
	w._on_level_completed()
	assertCond(w.pending.is_empty(), "WAL-12", "Restart poziomu nie dolicza klejnotów z przerwanej próby")
	w.free()

func utNoTokenDoesNotSend() -> void:
	var w := _wallet()
	w.enqueue("SES-1-0001", 15)
	assertCond(not w.flush() and w.pending.size() == 1, "WAL-13",
		"Gra niesparowana z kontem nie wysyła kolejki, klejnoty czekają")
	w.free()
