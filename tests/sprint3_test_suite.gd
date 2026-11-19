extends Node

## Zestaw Testów Automatycznych - Sprint 3 (S23KC2S1P1-250 & S23KC2S1P1-279)
## Zakres: Testy wrogów, wzmocnień (power-upów), życia i poziomów oraz reguł nadpisywania

const PlayerScript = preload("res://scripts/actors/player/player_controller.gd")
const EnemyScript = preload("res://scripts/actors/enemies/enemy_mockup.gd")
const PowerUpScript = preload("res://scripts/power_up.gd")
const HazardScript = preload("res://scripts/core/hazard_area.gd")
const ArenaScript = preload("res://scripts/core/test_arena.gd")
const JewelScript = preload("res://scripts/jewel.gd")
const CheckpointScript = preload("res://scripts/core/checkpoint.gd")
const LevelGeneratorScript = preload("res://scripts/core/level_generator.gd")
const PortalSyncScript = preload("res://scripts/core/portal_sync.gd")

var passCnt: int = 0
var failCnt: int = 0

func _ready() -> void:
	print("==================================================================")
	print("  START TESTÓW AUTOMATYCZNYCH SPRINT 3 - JEWELRUNNER              ")
	print("  Zadanie: S23KC2S1P1-250 (Wrogowie, Wzmocnienia, Życie, Poziomy) ")
	print("  Zadanie: S23KC2S1P1-279 (Logika Power-upów, Timer i Nadpisywanie)")
	print("==================================================================\n")
	
	print("--- [1] TESTY WROGÓW (ENEMY UNIT & DAMAGE TESTS) ---")
	utEnemyContactDealsDamage()
	utEnemyKnockbackVector()
	utEnemyInvulnerabilityWindow()
	utEnemyNoDamageDuringInvulnerability()
	
	print("\n--- [2] TESTY WZMOCNIEŃ I REGUŁ NADPISYWANIA (POWER-UPS & OVERRIDE RULES) ---")
	utPowerUpSpeedBoostApplied()
	utPowerUpTimerCountdownAndExpiration()
	utPowerUpOverrideRefreshRule()
	utPowerUpOverrideHigherTierReplacesLower()
	utPowerUpOverrideLowerTierRejected()
	utPowerUpInvincibilityBlocksDamage()
	utPowerUpShieldAbsorbsHit()
	
	print("\n--- [3] TESTY PUNTÓW ŻYCIA I MECHANIKI PORAŻKI (HEALTH & DEATH TESTS) ---")
	utHealthInitializationState()
	utHealthHealCannotExceedMax()
	utHealthZeroTriggersPlayerDiedSignal()
	utHealthDeadPlayerCannotReceiveHealing()
	utHealthChangeSignalPayload()
	
	print("\n--- [4] TESTY POZIOMÓW I INTEGRACJI ŚWIATA (LEVEL & INTEGRATION TESTS) ---")
	utLevelStartAndUniqueSessionGeneration()
	utLevelCompletionRecording()
	utLevelScoreTracking()
	itEnemyMockupCollisionIntegration()
	itPowerUpAreaPickupIntegration()

	print("\n--- [5] TESTY CHECKPOINTÓW, KOLCÓW I PRZEPAŚCI (S23KC2S1P1-276 / 278 / 110) ---")
	utCheckpointActivationUpdatesRespawnPosition()
	utAbyssFallDealsDamageAndRespawnsAtCheckpoint()
	utLevelGeneratorPlacesCheckpointsAndAbyss()

	print("\n--- [6] TESTY SPECJALNYCH KLEJNOTÓW I HUD (S23KC2S1P1-284 / 87 / 282 / 85) ---")
	utSecretSpecialJewelFirstCollectionAndRaritySignal()
	utSecretSpecialJewelAlreadyOwnedSemiTransparentAndNormalPoints()
	utHudJewelCounterGroupedAnimationAndWalletBalance()

	print("\n--- [7] TESTY WYSYŁKI WYNIKÓW I KOLEJKI OFFLINE (S23KC2S1P1-273) ---")
	utScoreSubmissionQueuedAndDeduplicated()
	utScoreQueueOfflineRetryKeepsPending()
	utScoreQueueSuccessRemovesFromDisk()

	print("\n--- [8] TESTY PERSONALIZACJI, SKLEPU I NAGRODY DZIENNEJ (S23KC2S1P1-253) ---")
	utCustomizationSkinColorAndAccessoriesSync()
	utCustomizationLockedSkinRejected()
	utBoosterUseQueueAndIdempotency()
	utCloudSaveChecksumAndConflictResolution()
	utDailyRewardClaimUpdatesWalletBalance()
	
	print("\n==================================================================")
	print(" PODSUMOWANIE SPRINT 3: ZALICZONE: %d | BŁĘDY: %d | ŁĄCZNIE: %d" % [passCnt, failCnt, passCnt + failCnt])
	print("==================================================================")
	get_tree().quit(1 if failCnt > 0 else 0)

func assertCond(cond: bool, testId: String, desc: String) -> void:
	if cond:
		passCnt += 1
		print("[PASS] %s: %s" % [testId, desc])
	else:
		failCnt += 1
		print("[FAIL] %s: %s" % [testId, desc])

# ==============================================================================
# 1. TESTY WROGÓW
# ==============================================================================

func utEnemyContactDealsDamage() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 3
	plr.take_damage(1, Vector2.ZERO)
	var hpOk: bool = (plr.current_health == 2)
	assertCond(hpOk, "ENM-01", "Kontakt z wrogiem redukuje punkty życia o wartość obrażeń (3 -> 2)")
	plr.free()

func utEnemyKnockbackVector() -> void:
	var plr = _createMockPlayer()
	plr.global_position = Vector2(100, 100)
	var enemy_pos = Vector2(150, 100) # Wróg po prawej stronie gracza
	plr.take_damage(1, enemy_pos)
	# Odrzut powinien skierować gracza w lewo (velocity.x < 0) oraz lekko w górę (velocity.y < 0)
	var knockOk: bool = (plr.velocity.x < 0.0) and (plr.velocity.y < 0.0)
	assertCond(knockOk, "ENM-02", "Odrzut (Knockback) odpycha gracza w stronę przeciwną do pozycji wroga")
	plr.free()

func utEnemyInvulnerabilityWindow() -> void:
	var plr = _createMockPlayer()
	plr.invulnerability_duration = 1.0
	plr.take_damage(1, Vector2.ZERO)
	var invOk: bool = plr.is_invulnerable and is_equal_approx(plr.invulnerability_timer, 1.0)
	assertCond(invOk, "ENM-03", "Otrzymanie obrażeń aktywuje stan nietykalności i ustawia invulnerability_timer")
	plr.free()

func utEnemyNoDamageDuringInvulnerability() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 3
	plr.take_damage(1, Vector2.ZERO) # HP = 2, is_invulnerable = true
	plr.take_damage(1, Vector2.ZERO) # Drugi atak powinien zostać zignorowany
	var immuneOk: bool = (plr.current_health == 2)
	assertCond(immuneOk, "ENM-04", "Kolejne ataki w oknie nietykalności nie zadają obrażeń graczowi")
	plr.free()

# ==============================================================================
# 2. TESTY WZMOCNIEŃ I REGUŁ NADPISYWANIA (S23KC2S1P1-279)
# ==============================================================================

func utPowerUpSpeedBoostApplied() -> void:
	var plr = _createMockPlayer()
	var base_spd = plr.speed
	plr.apply_powerup("SPEED_BOOST", 5.0, 1.5, 1)
	var spdOk: bool = is_equal_approx(plr.speed, base_spd * 1.5) and plr.has_powerup("SPEED_BOOST")
	assertCond(spdOk, "PWR-01", "Aktywacja SPEED_BOOST poprawnie zwiększa prędkość biegu gracza o mnożnik (1.5x)")
	plr.free()

func utPowerUpTimerCountdownAndExpiration() -> void:
	var plr = _createMockPlayer()
	var base_spd = plr.speed
	plr.apply_powerup("SPEED_BOOST", 1.0, 1.5, 1)
	
	plr._update_timers(0.4)
	var midOk: bool = is_equal_approx(plr.get_powerup_time_left("SPEED_BOOST"), 0.6)
	
	plr._update_timers(0.7) # Czas minął (0.6 - 0.7 <= 0)
	var expiredOk: bool = not plr.has_powerup("SPEED_BOOST") and is_equal_approx(plr.speed, base_spd)
	assertCond(midOk and expiredOk, "PWR-02", "Timer wzmocnienia odlicza czas i przywraca bazową prędkość po wygaśnięciu")
	plr.free()

func utPowerUpOverrideRefreshRule() -> void:
	var plr = _createMockPlayer()
	plr.apply_powerup("SPEED_BOOST", 5.0, 1.5, 1)
	plr._update_timers(3.0) # Pozostało 2.0s
	
	# Ponowne zebranie tego samego wzmocnienia (ten sam tier) - Reguła Odświeżenia (Refresh)
	plr.apply_powerup("SPEED_BOOST", 5.0, 1.5, 1)
	var refreshedOk: bool = is_equal_approx(plr.get_powerup_time_left("SPEED_BOOST"), 5.0)
	assertCond(refreshedOk, "PWR-03", "Reguła odświeżenia: zebranie tego samego wzmocnienia resetuje timer do pełnego czasu")
	plr.free()

func utPowerUpOverrideHigherTierReplacesLower() -> void:
	var plr = _createMockPlayer()
	plr.apply_powerup("SPEED_BOOST", 5.0, 1.2, 1) # Tier 1 (1.2x)
	# Zebranie wyższego poziomu wzmocnienia (Tier 2 - 1.8x)
	plr.apply_powerup("SPEED_BOOST", 8.0, 1.8, 2)
	var tierOk: bool = is_equal_approx(plr.speed, plr.base_speed * 1.8) and is_equal_approx(plr.get_powerup_time_left("SPEED_BOOST"), 8.0)
	assertCond(tierOk, "PWR-04", "Reguła nadpisywania: wzmocnienie o wyższym poziomie (Tier 2) natychmiast zastępuje Tier 1")
	plr.free()

func utPowerUpOverrideLowerTierRejected() -> void:
	var plr = _createMockPlayer()
	plr.apply_powerup("SPEED_BOOST", 8.0, 2.0, 3) # Tier 3
	# Próba nadpisania słabszym wzmocnieniem (Tier 1)
	plr.apply_powerup("SPEED_BOOST", 4.0, 1.2, 1)
	var rejectedOk: bool = is_equal_approx(plr.speed, plr.base_speed * 2.0) and is_equal_approx(plr.get_powerup_time_left("SPEED_BOOST"), 8.0)
	assertCond(rejectedOk, "PWR-05", "Reguła ochrony: wzmocnienie niższego rzędu nie nadpisuje aktywnego wyższego rzędu")
	plr.free()

func utPowerUpInvincibilityBlocksDamage() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 3
	plr.apply_powerup("INVINCIBILITY", 5.0, 1.0, 1)
	plr.take_damage(2, Vector2.ZERO)
	var blockOk: bool = (plr.current_health == 3)
	assertCond(blockOk, "PWR-06", "Wzmocnienie INVINCIBILITY całkowicie blokuje utratę punktów życia")
	plr.free()

func utPowerUpShieldAbsorbsHit() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 3
	plr.apply_powerup("SHIELD", 10.0, 1.0, 1)
	plr.take_damage(1, Vector2.ZERO) # Tarcza powinna pochłonąć obrażenia i zniknąć
	var shieldOk: bool = (plr.current_health == 3) and not plr.has_powerup("SHIELD")
	assertCond(shieldOk, "PWR-07", "Wzmocnienie SHIELD pochłania cios wroga bez utraty HP i ulega zużyciu")
	plr.free()

# ==============================================================================
# 3. TESTY PUNKTÓW ŻYCIA I MECHANIKI PORAŻKI (S23KC2S1P1-250)
# ==============================================================================

func utHealthInitializationState() -> void:
	var plr = _createMockPlayer()
	var initOk: bool = (plr.current_health == plr.max_health) and (plr.max_health >= 3)
	assertCond(initOk, "HP-01", "Prawidłowa inicjalizacja życia: current_health równe max_health (3 HP)")
	plr.free()

func utHealthHealCannotExceedMax() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 2
	plr.heal(5) # Próba uleczenia ponad stan maksymalny
	var healOk: bool = (plr.current_health == plr.max_health)
	assertCond(healOk, "HP-02", "Funkcja heal uzupełnia punkty życia, blokując przekroczenie limitu max_health")
	plr.free()

func utHealthZeroTriggersPlayerDiedSignal() -> void:
	var plr = _createMockPlayer()
	var diedEmitted := [false]
	var cb = func(): diedEmitted[0] = true
	Events.player_died.connect(cb)
	
	plr.take_damage(plr.max_health, Vector2.ZERO)
	Events.player_died.disconnect(cb)
	
	var deadOk: bool = (plr.current_health == 0) and diedEmitted[0]
	assertCond(deadOk, "HP-03", "Spadek punktów życia do zera emituje sygnał Events.player_died")
	plr.free()

func utHealthDeadPlayerCannotReceiveHealing() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 0 # Gracz martwy
	plr.heal(2)
	var healBlockOk: bool = (plr.current_health == 0)
	assertCond(healBlockOk, "HP-04", "Martwy gracz (0 HP) nie może zostać uleczony metodą heal")
	plr.free()

func utHealthChangeSignalPayload() -> void:
	var plr = _createMockPlayer()
	var receivedPayload := [-1, -1]
	var cb = func(cur: int, max_hp: int):
		receivedPayload[0] = cur
		receivedPayload[1] = max_hp
	Events.player_health_changed.connect(cb)
	
	plr.take_damage(1, Vector2.ZERO)
	Events.player_health_changed.disconnect(cb)
	
	var payloadOk: bool = (receivedPayload[0] == 2) and (receivedPayload[1] == 3)
	assertCond(payloadOk, "HP-05", "Sygnał player_health_changed poprawnie przekazuje wartości aktualnego i maksymalnego HP")
	plr.free()

# ==============================================================================
# 4. TESTY POZIOMÓW I INTEGRACJI ŚWIATA (S23KC2S1P1-250)
# ==============================================================================

func utLevelStartAndUniqueSessionGeneration() -> void:
	var s1 = Events.generate_session_id()
	var s2 = Events.generate_session_id()
	var validSess: bool = s1.begins_with("SES-") and s2.begins_with("SES-") and (s1 != s2)
	assertCond(validSess, "LVL-01", "Rozpoczęcie poziomu generuje unikalne identyfikatory sesji telemetrycznej")

func utLevelCompletionRecording() -> void:
	Events.completed_levels.clear()
	Events.complete_level(2)
	var lvlOk: bool = Events.is_level_completed(2) and not Events.is_level_completed(3)
	assertCond(lvlOk, "LVL-02", "Events.complete_level(2) trwale zapisuje ukończenie wskazanego poziomu")

func utLevelScoreTracking() -> void:
	var arena = _createMockArena()
	arena.total_score = 0
	Events.score_added.emit(50)
	Events.score_added.emit(100)
	var scoreOk: bool = (arena.total_score == 150)
	assertCond(scoreOk, "LVL-03", "Zbieranie punktów w pętli poziomu kumuluje łączny wynik Areny")
	arena.free()

func itEnemyMockupCollisionIntegration() -> void:
	var enemy = EnemyScript.new()
	enemy.contact_damage = 1
	add_child(enemy)
	
	var plr = _createMockPlayer()
	plr.current_health = 3
	enemy._on_body_entered(plr) # Symulacja kolizji silnika fizyki Godot
	
	var colOk: bool = (plr.current_health == 2) and plr.is_invulnerable
	assertCond(colOk, "IT-ENM", "Integracja kolizji: wejście w obszar EnemyMockup wywołuje take_damage na graczu")
	
	plr.free()
	enemy.free()

func itPowerUpAreaPickupIntegration() -> void:
	var pwr = PowerUpScript.new()
	pwr.powerup_type = "SPEED_BOOST"
	pwr.duration = 4.0
	pwr.value = 1.6
	pwr.tier = 1
	add_child(pwr)
	
	var plr = _createMockPlayer()
	pwr._on_body_entered(plr) # Symulacja zebrania obiektu wzmocnienia w świecie gry
	
	var pickOk: bool = plr.has_powerup("SPEED_BOOST") and is_equal_approx(plr.speed, plr.base_speed * 1.6)
	assertCond(pickOk, "IT-PWR", "Integracja świata: zebranie obiektu PowerUp w świecie gry nadaje wzmocnienie graczowi")
	
	plr.free()
	pwr.free()

# ==============================================================================
# 5. TESTY CHECKPOINTÓW, KOLCÓW I PRZEPAŚCI (S23KC2S1P1-276 / 278 / 110)
# ==============================================================================

func utCheckpointActivationUpdatesRespawnPosition() -> void:
	var cp = CheckpointScript.new()
	cp.checkpoint_id = "CP-1"
	cp.global_position = Vector2(450, 280)
	add_child(cp)

	var plr = _createMockPlayer()
	plr.global_position = Vector2(70, 270)
	cp._on_body_entered(plr)

	var cpOk: bool = cp.is_activated and (plr.last_checkpoint_pos == Vector2(450, 280)) and (plr.last_checkpoint_id == "CP-1")
	assertCond(cpOk, "CHK-01", "Wejście w checkpoint aktywuje go i zapisuje nową pozycję odrodzenia gracza")

	plr.free()
	cp.free()

func utAbyssFallDealsDamageAndRespawnsAtCheckpoint() -> void:
	var plr = _createMockPlayer()
	plr.set_meta("has_portal_shield", false)
	plr.current_health = 3
	plr.is_invulnerable = false
	plr.set_checkpoint(Vector2(450, 280), "CP-1")
	plr.global_position = Vector2(800, 420)

	var hz = HazardScript.new()
	hz.is_abyss = true
	hz.damage = 1
	add_child(hz)

	hz._on_body_entered(plr)

	var respawnedOk: bool = (plr.current_health == 2) and (plr.global_position == Vector2(450, 280)) and plr.is_invulnerable
	assertCond(respawnedOk, "CHK-02", "Wpadnięcie w strefę przepaści odejmuje 1 HP, włącza i-frames i cofa do ostatniego checkpointu")

	hz.free()
	plr.free()

func utLevelGeneratorPlacesCheckpointsAndAbyss() -> void:
	var mockArena := Node2D.new()
	add_child(mockArena)

	LevelGeneratorScript.build_level_for_arena(mockArena, LevelGeneratorScript.MechanicProfile.VERTICAL_ASCENT, 12345)

	var cpRoot = mockArena.get_node_or_null("Checkpoints")
	var hasCheckpoints: bool = (cpRoot != null) and (cpRoot.get_child_count() >= 2)
	var abyssNode = mockArena.get_node_or_null("Hazards/AbyssZone")
	var hasAbyss: bool = (abyssNode != null) and (abyssNode.get("is_abyss") == true)
	var hasSecretJewel: bool = false
	for child in mockArena.get_children():
		if child.get("is_secret_special") == true:
			hasSecretJewel = true
			break

	assertCond(hasCheckpoints and hasAbyss and hasSecretJewel, "CHK-03", "Generator poziomów rozmieszcza checkpointy, strefę przepaści oraz sekretny klejnot")
	mockArena.free()

# ==============================================================================
# 6. TESTY SPECJALNYCH KLEJNOTÓW I HUD (S23KC2S1P1-284 / 87 / 282 / 85)
# ==============================================================================

const TEST_SPECIAL_PATH: String = "user://test_special_jewels.json"

func utSecretSpecialJewelFirstCollectionAndRaritySignal() -> void:
	var prev_path: String = Events.special_jewels_save_path
	Events.special_jewels_save_path = TEST_SPECIAL_PATH
	Events.collected_special_jewels.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SPECIAL_PATH))

	var plr = _createMockPlayer()
	var jwl = JewelScript.new()
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	jwl.add_child(spr)
	add_child(jwl)
	jwl.configure_secret_jewel("SEC-TEST-1", "Klejnot Testowy", "Legendarny")

	var preVisualOk: bool = (not jwl.is_already_owned_special) and is_equal_approx(jwl.modulate.a, 1.0)

	var specialPayload := ["", "", "", true]
	var jewelPoints := [0]
	var cbSpec = func(sid: String, jname: String, rarity: String, owned: bool):
		specialPayload[0] = sid
		specialPayload[1] = jname
		specialPayload[2] = rarity
		specialPayload[3] = owned
	var cbPts = func(val: int, _pos: Vector2):
		jewelPoints[0] = val

	Events.special_jewel_collected.connect(cbSpec)
	Events.jewel_collected.connect(cbPts)
	jwl._onBodyEntered(plr)
	Events.special_jewel_collected.disconnect(cbSpec)
	Events.jewel_collected.disconnect(cbPts)

	var sigOk: bool = (specialPayload[0] == "SEC-TEST-1") and (specialPayload[1] == "Klejnot Testowy") and (specialPayload[2] == "Legendarny") and (specialPayload[3] == false)
	var savedOk: bool = Events.is_special_jewel_owned("SEC-TEST-1") and (jewelPoints[0] == jwl.special_point_val)

	assertCond(preVisualOk and sigOk and savedOk, "SPC-01", "Pierwsze zebranie sekretnego klejnotu zapisuje go w kolekcji i emituje powiadomienie o rzadkości")

	plr.free()
	Events.special_jewels_save_path = prev_path
	Events.load_special_jewels()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SPECIAL_PATH))

func utSecretSpecialJewelAlreadyOwnedSemiTransparentAndNormalPoints() -> void:
	var prev_path: String = Events.special_jewels_save_path
	Events.special_jewels_save_path = TEST_SPECIAL_PATH
	Events.collected_special_jewels.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SPECIAL_PATH))
	Events.register_special_jewel("SEC-TEST-OWNED", "Klejnot Eteru", "Legendarny")

	var plr = _createMockPlayer()
	var jwl = JewelScript.new()
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	jwl.add_child(spr)
	add_child(jwl)
	jwl.configure_secret_jewel("SEC-TEST-OWNED", "Klejnot Eteru", "Legendarny")

	var visualSemiOk: bool = jwl.is_already_owned_special and is_equal_approx(jwl.modulate.a, 0.45)

	var wasOwnedSig := [false]
	var ptsCollected := [0]
	var cbSpec = func(_sid: String, _jname: String, _rarity: String, owned: bool):
		wasOwnedSig[0] = owned
	var cbPts = func(val: int, _pos: Vector2):
		ptsCollected[0] = val

	Events.special_jewel_collected.connect(cbSpec)
	Events.jewel_collected.connect(cbPts)
	jwl._onBodyEntered(plr)
	Events.special_jewel_collected.disconnect(cbSpec)
	Events.jewel_collected.disconnect(cbPts)

	var ownedCollectOk: bool = wasOwnedSig[0] and (ptsCollected[0] == jwl.pointVal)
	assertCond(visualSemiOk and ownedCollectOk, "SPC-02", "Posiadany specjalny klejnot renderuje się półprzezroczyście i po zebraniu przyznaje zwykłe punkty")

	plr.free()
	Events.special_jewels_save_path = prev_path
	Events.load_special_jewels()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SPECIAL_PATH))

func utHudJewelCounterGroupedAnimationAndWalletBalance() -> void:
	var arena = _createMockArena()
	arena.total_jewels = 5
	arena.collected_jewels = 0
	arena._update_score_hud()

	arena._on_jewel_collected(100, Vector2.ZERO)
	arena._on_jewel_collected(100, Vector2.ZERO)

	var textOk: bool = (arena.hud_score_label.text == " JEWELS: 2/5 ")
	var groupedOk: bool = (arena.jewel_anim_batch_count == 2) and (arena.jewel_anim_timer > 0.0) and (arena.hud_score_label.scale.x > 1.0)
	var walletOk: bool = (arena.hud_wallet_label != null) and arena.hud_wallet_label.text.contains("(+2)")

	arena._update_jewel_hud_animation(0.75)
	var settledOk: bool = (arena.jewel_anim_batch_count == 0) and is_equal_approx(arena.hud_score_label.scale.x, 1.0) and (not arena.hud_wallet_label.text.contains("(+"))

	assertCond(textOk and groupedOk and walletOk and settledOk, "HUD-01", "Licznik klejnotów na HUD grupuje szybkie inkrementacje w jedną animację i pokazuje saldo portfela")
	arena.free()

# ==============================================================================
# 7. TESTY WYSYŁKI WYNIKÓW I KOLEJKI OFFLINE (S23KC2S1P1-273)
# ==============================================================================

const TEST_RUNS_QUEUE_PATH: String = "user://test_runs_queue.json"

func utScoreSubmissionQueuedAndDeduplicated() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RUNS_QUEUE_PATH))
	var ps = PortalSyncScript.new()
	ps.runs_queue_path = TEST_RUNS_QUEUE_PATH
	ps.is_linked = true
	ps.session_token = "tok_test_score"

	var q1: bool = ps.submit_score("SES-1763500000-0101", 1, 500, 32.5, 5, true, 2)
	var q2: bool = ps.submit_score("SES-1763500000-0101", 1, 500, 32.5, 5, true, 2)

	var ok: bool = q1 and (not q2) and (ps.pending_runs.size() == 1) and (int(ps.pending_runs[0]["score"]) == 500)
	assertCond(ok, "SCR-01", "Wysyłka wyniku biegu (submit_score) kolejkuje wynik z deduplikacją po session_id")

	ps.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RUNS_QUEUE_PATH))

func utScoreQueueOfflineRetryKeepsPending() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RUNS_QUEUE_PATH))
	var ps = PortalSyncScript.new()
	ps.runs_queue_path = TEST_RUNS_QUEUE_PATH
	ps.is_linked = true
	ps.session_token = "tok_test_score"

	ps.submit_score("SES-1763500000-0102", 2, 750, 41.2, 8)
	var res0: bool = ps.apply_run_response(0, null, "SES-1763500000-0102")
	var res503: bool = ps.apply_run_response(503, null, "SES-1763500000-0102")
	ps.free()

	var ps2 = PortalSyncScript.new()
	ps2.runs_queue_path = TEST_RUNS_QUEUE_PATH
	ps2.load_pending_runs()
	var keptOk: bool = (not res0) and (not res503) and (ps2.pending_runs.size() == 1) and (ps2.pending_runs[0]["session_id"] == "SES-1763500000-0102")
	assertCond(keptOk, "SCR-02", "Brak sieci lub błąd 503 zachowuje wynik w lokalnej kolejce ponowień na dysku")

	ps2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RUNS_QUEUE_PATH))

func utScoreQueueSuccessRemovesFromDisk() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RUNS_QUEUE_PATH))
	var ps = PortalSyncScript.new()
	ps.runs_queue_path = TEST_RUNS_QUEUE_PATH
	ps.is_linked = true
	ps.session_token = "tok_test_score"

	ps.submit_score("SES-1763500000-0103", 1, 900, 28.0, 6)
	var synced: bool = ps.apply_run_response(200, {"best_score": 900}, "SES-1763500000-0103")
	ps.free()

	var ps2 = PortalSyncScript.new()
	ps2.runs_queue_path = TEST_RUNS_QUEUE_PATH
	ps2.load_pending_runs()
	var clearedOk: bool = synced and ps2.pending_runs.is_empty()
	assertCond(clearedOk, "SCR-03", "Poprawna odpowiedź serwera (HTTP 200) usuwa wysłany wynik z kolejki i z pliku na dysku")

	ps2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RUNS_QUEUE_PATH))

# ==============================================================================
# 8. TESTY PERSONALIZACJI, SKLEPU I NAGRODY DZIENNEJ (S23KC2S1P1-253)
# ==============================================================================

const TEST_BOOSTERS_QUEUE_PATH: String = "user://test_boosters_queue.json"

func utCustomizationSkinColorAndAccessoriesSync() -> void:
	var ps = PortalSyncScript.new()
	ps.apply_synced_payload({
		"player": {"id": "u1", "username": "Mati", "email": "mati@example.com"},
		"appearance": {
			"active_skin": "Noir Stelly",
			"active_color_name": "Monochrom",
			"active_color_hex": "#505050",
			"equipped_accessories": {"głowa": "Czapka"},
			"owned_items": [
				{"id": 101, "type": "skórka", "name": "Skórka podstawowa"},
				{"id": 102, "type": "skórka", "name": "Noir Stelly"},
				{"id": 201, "type": "kolor", "name": "Monochrom", "color_hex": "#505050"},
				{"id": 301, "type": "akcesorium", "name": "Czapka", "mount_point": "głowa"}
			]
		}
	})

	var plr = _createMockPlayer()
	ps.apply_cosmetics_and_boosters_to_player(plr)

	var hatNode: Node2D = plr.visuals.get_node_or_null("PortalAccessoryHat")
	var skinAppliedOk: bool = (String(plr.get_meta("active_skin_key", "")) == "noir") and (hatNode != null and hatNode.visible)
	assertCond(skinAppliedOk, "SHP-01", "Personalizacja poprawnie nakłada wybraną skórkę, kolor i akcesorium głowy na postać")

	plr.free()
	ps.free()

func utCustomizationLockedSkinRejected() -> void:
	var ps = PortalSyncScript.new()
	ps.is_linked = true
	ps.session_token = "tok_test_cust"
	ps.cosmetics_state["owned_items"] = [
		{"id": 101, "type": "skórka", "name": "Skórka podstawowa"},
		{"id": 102, "type": "skórka", "name": "Noir Stelly"},
		{"id": 201, "type": "kolor", "name": "Fioletowy"}
	]

	var lockedId: int = ps.find_owned_element_id("skórka", "2077 Stelly")
	var ownedId: int = ps.find_owned_element_id("skórka", "Noir Stelly")
	var saveRejected: bool = not ps.save_appearance_to_web("2077 Stelly")

	assertCond((lockedId == 0) and (ownedId == 102) and saveRejected, "SHP-02", "Zablokowana skórka nie jest na liście posiadanych i próba jej zapisu zostaje odrzucona")
	ps.free()

func utBoosterUseQueueAndIdempotency() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BOOSTERS_QUEUE_PATH))
	var ps = PortalSyncScript.new()
	ps.boosters_queue_path = TEST_BOOSTERS_QUEUE_PATH
	ps.is_linked = true
	ps.session_token = "tok_test_bst"
	ps.cosmetics_state["boosters"] = {"tarcza": 2, "magnes": 1}

	var u1: bool = ps.report_booster_used("tarcza", "OP-SHIELD-0001")
	var u2: bool = ps.report_booster_used("tarcza", "OP-SHIELD-0001")
	var remainingAfterUse: int = int(ps.cosmetics_state["boosters"]["tarcza"])
	ps.free()

	var ps2 = PortalSyncScript.new()
	ps2.boosters_queue_path = TEST_BOOSTERS_QUEUE_PATH
	ps2.load_pending_booster_uses()
	var ok: bool = u1 and (not u2) and (remainingAfterUse == 1) and (ps2.pending_booster_uses.size() == 1)
	assertCond(ok, "SHP-03", "Użycie zakupionego boostera jest idempotentne po operation_id i zapisuje się w kolejce offline")

	ps2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BOOSTERS_QUEUE_PATH))

func utCloudSaveChecksumAndConflictResolution() -> void:
	var cs1: String = PortalSyncScript.compute_save_checksum(2, "CP-1", 12, 1763600000, "0.3.0")
	var cs2: String = PortalSyncScript.compute_save_checksum(2, "CP-1", 12, 1763600000, "0.3.0")
	var csDiff: String = PortalSyncScript.compute_save_checksum(2, "CP-2", 12, 1763600000, "0.3.0")
	var checksumOk: bool = (cs1.length() == 64) and (cs1 == cs2) and (cs1 != csDiff)

	var ps = PortalSyncScript.new()
	ps._last_local_save_payload = {"level": 2, "checkpoint": "CP-1", "gems": 12}
	var conflictBody := JSON.stringify({
		"error": {
			"code": "save_conflict",
			"details": {"server_save": {"level": 3, "checkpoint": "CP-2", "gems": 20}}
		}
	}).to_utf8_buffer()
	ps._on_save_request_completed(0, 409, PackedStringArray(), conflictBody)
	var conflictDetected: bool = (int(ps.save_conflict_server.get("level", 0)) == 3)
	ps.resolve_save_conflict(false)
	var resolvedServerOk: bool = (int(ps.cloud_save.get("level", 0)) == 3) and ps.save_conflict_server.is_empty()

	assertCond(checksumOk and conflictDetected and resolvedServerOk, "SHP-04", "Suma kontrolna SHA-256 zapisu gry i rozwiązywanie konfliktu wersji (409) działają poprawnie")
	ps.free()

func utDailyRewardClaimUpdatesWalletBalance() -> void:
	var ps = PortalSyncScript.new()
	ps.player_profile["gems"] = 100
	ps._daily_req_kind = "claim"
	var claimBody := JSON.stringify({
		"available": false,
		"streak_day": 3,
		"reward_gems": 50,
		"balance": 150
	}).to_utf8_buffer()
	ps._on_daily_request_completed(0, 200, PackedStringArray(), claimBody)
	var claimedOk: bool = (int(ps.player_profile["gems"]) == 150) and (int(ps.daily_reward_state.get("streak_day", 0)) == 3)

	ps._daily_req_kind = "claim"
	ps._on_daily_request_completed(0, 409, PackedStringArray(), PackedByteArray())
	var duplicateBlockedOk: bool = (bool(ps.daily_reward_state.get("available", true)) == false)

	assertCond(claimedOk and duplicateBlockedOk, "SHP-05", "Odbiór nagrody dziennej aktualizuje saldo klejnotów, a ponowne odebranie tego samego dnia jest blokowane (409)")
	ps.free()

# ==============================================================================
# FUNKCJE POMOCNICZE
# ==============================================================================

func _createMockPlayer() -> CharacterBody2D:
	var plr = PlayerScript.new()
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = RectangleShape2D.new()
	plr.add_child(col)
	
	var ceilCheck = ShapeCast2D.new()
	ceilCheck.name = "CeilingChecker"
	plr.add_child(ceilCheck)
	
	var stamBar = ProgressBar.new()
	stamBar.name = "StaminaBar"
	plr.add_child(stamBar)
	
	var vis = Node2D.new()
	vis.name = "Visuals"
	var anim = AnimatedSprite2D.new()
	anim.name = "AnimatedSprite2D"
	var sf = SpriteFrames.new()
	sf.add_animation("appear")
	sf.add_animation("idle")
	sf.add_animation("trick")
	anim.sprite_frames = sf
	vis.add_child(anim)
	plr.add_child(vis)
	
	for aName in ["AudioJump", "AudioDash", "AudioAppear"]:
		var a = AudioStreamPlayer2D.new()
		a.name = aName
		plr.add_child(a)
	
	var hpBox = Node2D.new()
	hpBox.name = "HpSquares"
	plr.add_child(hpBox)
	
	add_child(plr)
	return plr

func _createMockArena() -> Node2D:
	var arena = ArenaScript.new()
	var respawn = Marker2D.new()
	respawn.name = "RespawnPoint"
	arena.add_child(respawn)
	
	var goal = Area2D.new()
	goal.name = "FinishGoal"
	arena.add_child(goal)
	
	var hud = Node.new()
	hud.name = "HUD"
	arena.add_child(hud)
	
	var stamPanel = Node.new()
	stamPanel.name = "StaminaPanel"
	var hbox = Node.new()
	hbox.name = "HBox"
	var stamBar = ProgressBar.new()
	stamBar.name = "HudStaminaBar"
	hbox.add_child(stamBar)
	stamPanel.add_child(hbox)
	hud.add_child(stamPanel)
	
	var scorePanel = Node.new()
	scorePanel.name = "ScorePanel"
	var scoreLbl = Label.new()
	scoreLbl.name = "ScoreText"
	scorePanel.add_child(scoreLbl)
	hud.add_child(scorePanel)
	
	for menuName in ["PauseMenu", "GameOverMenu", "WinScreen"]:
		var ctrl = Control.new()
		ctrl.name = menuName
		if menuName == "WinScreen":
			var resScore = Label.new()
			resScore.name = "ScoreResultText"
			ctrl.add_child(resScore)
		hud.add_child(ctrl)
		
	for audName in ["AudioPause", "AudioWin", "AudioPickup"]:
		var aud = AudioStreamPlayer.new()
		aud.name = audName
		hud.add_child(aud)
		
	add_child(arena)
	return arena
