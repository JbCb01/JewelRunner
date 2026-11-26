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
const TrampolineScript = preload("res://scripts/core/trampoline_pad.gd")
const AILevelComposerScript = preload("res://scripts/core/ai_level_composer.gd")
const EnemyScene = preload("res://scenes/enemies/enemy_mockup.tscn")

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
	utLevelSpecificMusicTracks()
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
	utHudMinimalistMultipliersAndColorFade()

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

	print("\n--- [9] TESTY TILESETU, 3 POZIOMÓW, TRAMPOLIN, AI WROGÓW I SZACHOWNICY AI ---")
	utTilesetLoadsAndRendersAllBiomesWithoutQuestionBlocks()
	utThreeFullLevelsHaveDistinctBiomesEnemiesAndTrampolines()
	utTrampolinePadLaunchesPlayerAndRefreshesAirMoves()
	utEnemyArchetypesAiStatesAndSpriteRows()
	utSzachownicaAiSeedDeterminismVariationAndValidation()

	print("\n--- [10] TESTY PROFILU STYLU GRY I POZIOMU AI (CYBER MATRIX) ---")
	utPlaystyleProfilerTracksZonesRoutesAndPersists()
	utAiLevelAdaptsToPlaystyleProfile()
	
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

func utLevelSpecificMusicTracks() -> void:
	var stream1: AudioStream = ArenaScript.get_level_music_stream(1)
	var stream2: AudioStream = ArenaScript.get_level_music_stream(2)
	var stream3: AudioStream = ArenaScript.get_level_music_stream(3)
	
	var validStreams: bool = (stream1 != null) and (stream2 != null) and (stream3 != null)
	var distinctStreams: bool = (stream1 != stream2) and (stream2 != stream3) and (stream1 != stream3)
	
	var s1Path: String = stream1.resource_path
	var s2Path: String = stream2.resource_path
	var s3Path: String = stream3.resource_path
	var pathsOk: bool = s1Path.ends_with("yessirski.wav") and s2Path.ends_with("onmymommaimthegoat.wav") and s3Path.ends_with("onsumbull.wav")
	
	var arena = ArenaScript.new()
	add_child(arena)
	var musicPlayer = AudioStreamPlayer.new()
	musicPlayer.name = "MusicLevel"
	arena.add_child(musicPlayer)
	arena.music_level = musicPlayer
	
	arena._setup_level_music(2)
	var arenaLvl2Ok: bool = (arena.music_level.stream == stream2) and arena.music_level.playing
	arena._setup_level_music(3)
	var arenaLvl3Ok: bool = (arena.music_level.stream == stream3) and arena.music_level.playing
	arena._setup_level_music(1)
	var arenaLvl1Ok: bool = (arena.music_level.stream == stream1) and arena.music_level.playing
	
	remove_child(arena)
	arena.free()
	
	var allOk: bool = validStreams and distinctStreams and pathsOk and arenaLvl1Ok and arenaLvl2Ok and arenaLvl3Ok
	assertCond(allOk, "LVL-04", "Kolejne poziomy wykorzystują nowe ścieżki dźwiękowe: Poziom 2 (onmymommaimthegoat) i Poziom 3 (onsumbull)")

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

func utHudMinimalistMultipliersAndColorFade() -> void:
	Events.selected_level_profile = 1
	Events.patryk.reset_session_state(true)
	var arenaScene := load("res://scenes/test_arena.tscn") as PackedScene
	var arena := arenaScene.instantiate()
	add_child(arena)

	var noControlsBarOk: bool = (arena.get_node_or_null("HUD/ControlsPanel") == null)
	var multText: String = arena.get_multipliers_hud_text()
	var minimalistFormatOk: bool = (multText == "Double Jump: 1.0x | Wall Climb: 1.0x | Dash: 1.0x") and (not multText.contains("Σ")) and (not multText.contains("PROFIL"))

	var djLbl: Label = arena.hud_mult_labels.get("double_jump") as Label
	var wcLbl: Label = arena.hud_mult_labels.get("wall_climb") as Label
	var daLbl: Label = arena.hud_mult_labels.get("dash") as Label
	var initGrayOk: bool = is_equal_approx(float(arena.mult_highlights.get("double_jump", -1.0)), 0.0) and (djLbl != null)

	# Użycie double_jump podnosi jego mnożnik (zielony) i obniża pozostałe (czerwone)
	Events.patryk.record_move_use("double_jump", 1.0)
	var djCol: Color = djLbl.get_theme_color("font_color")
	var wcCol: Color = wcLbl.get_theme_color("font_color")
	var daCol: Color = daLbl.get_theme_color("font_color")
	var upGreenOk: bool = (djCol.g > djCol.r + 0.25) and (djCol.g > djCol.b + 0.2)
	var downRedOk: bool = (wcCol.r > wcCol.g + 0.25) and (wcCol.r > wcCol.b + 0.2) and (daCol.r > daCol.g + 0.25) and (daCol.r > daCol.b + 0.2)

	# Brak zmian wygasza podświetlenia stopniowo z powrotem do szarości
	arena._update_multiplier_hud_highlights(3.0)
	var settledCol: Color = djLbl.get_theme_color("font_color")
	var fadedToGrayOk: bool = (float(arena.mult_highlights.get("double_jump", 1.0)) <= 0.05) and (abs(settledCol.r - settledCol.g) < 0.12) and (abs(settledCol.g - settledCol.b) < 0.12)

	arena.free()
	Events.patryk.reset_session_state(true)
	assertCond(noControlsBarOk and minimalistFormatOk and initGrayOk and upGreenOk and downRedOk and fadedToGrayOk, "HUD-02", "Minimalistyczny HUD bez paska sterowania; mnożniki podświetlają wzrost na zielono, spadek na czerwono i szarzeją")

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
# 9. TESTY TILESETU, 3 POZIOMÓW, TRAMPOLIN, AI WROGÓW I SZACHOWNICY AI
# ==============================================================================

func utTilesetLoadsAndRendersAllBiomesWithoutQuestionBlocks() -> void:
	var ts: TileSet = LevelGeneratorScript.get_default_tileset()
	var tsOk: bool = (ts != null) and (ts.tile_size == Vector2i(16, 16)) and (ts.get_source_count() >= 1)
	var forbiddenQ: Array[Vector2i] = [Vector2i(0, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(7, 2)]

	var allLayersOk: bool = tsOk
	var noQuestionBlocksOk: bool = true
	for pid in [1, 2, 3, 4]:
		var mockArena := Node2D.new()
		add_child(mockArena)
		var fg := Area2D.new()
		fg.name = "FinishGoal"
		mockArena.add_child(fg)

		LevelGeneratorScript.build_level_for_arena(mockArena, pid, 4242, ts)

		var lvlLayer := mockArena.get_node_or_null("LevelTileMapLayer") as TileMapLayer
		var bgLayer := mockArena.get_node_or_null("BgTileMapLayer") as TileMapLayer
		var decorLayer := mockArena.get_node_or_null("DecorTileMapLayer") as TileMapLayer
		var ceilLayer := mockArena.get_node_or_null("CeilingTileMapLayer") as TileMapLayer

		# Tło: dawniej pas kafelków BgTileMapLayer, obecnie obraz/animacja (LevelBackground) lub TextureRect lasu
		var hasBackground: bool = (bgLayer != null and bgLayer.get_used_cells().size() >= 20) \
			or mockArena.get_node_or_null("Geometry/LevelBackground") != null \
			or mockArena.get_node_or_null("Background") is TextureRect
		if lvlLayer == null or decorLayer == null or not hasBackground:
			allLayersOk = false
		else:
			if lvlLayer.get_used_cells().size() < 40 or decorLayer.get_used_cells().is_empty():
				allLayersOk = false
			for layer in [lvlLayer, bgLayer, decorLayer, ceilLayer]:
				if layer == null:
					continue
				for cell in layer.get_used_cells():
					var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
					if forbiddenQ.has(atlas):
						noQuestionBlocksOk = false
		mockArena.free()

	assertCond(tsOk and allLayersOk and noQuestionBlocksOk, "LVL-05", "TileSet 16x16 ładuje się i renderuje wszystkie 4 biomy na warstwach TileMapLayer bez bloków '?'")

func utThreeFullLevelsHaveDistinctBiomesEnemiesAndTrampolines() -> void:
	var expectedBiomes: Dictionary = {
		1: LevelGeneratorScript.BiomeId.FOREST,
		2: LevelGeneratorScript.BiomeId.WINTER,
		3: LevelGeneratorScript.BiomeId.AUTUMN
	}
	var expectedEnemyColors: Dictionary = {1: 2, 2: 1, 3: 3}
	var allLevelsOk: bool = true

	for pid in [1, 2, 3]:
		var mockArena := Node2D.new()
		add_child(mockArena)
		var fg := Area2D.new()
		fg.name = "FinishGoal"
		mockArena.add_child(fg)

		var info: Dictionary = LevelGeneratorScript.build_level_for_arena(mockArena, pid, 1000 + pid)
		var biomeOk: bool = (int(info.get("biome_id", 0)) == int(expectedBiomes[pid]))
		var lengthOk: bool = (fg.position.x >= 2800.0)
		var validOk: bool = bool(info.get("validation", {}).get("passed", false))

		var enemiesNode := mockArena.get_node_or_null("Enemies")
		var trampNode := mockArena.get_node_or_null("Trampolines")
		var cpNode := mockArena.get_node_or_null("Checkpoints")

		var enemyCntOk: bool = (enemiesNode != null) and (enemiesNode.get_child_count() >= 5)
		var enemyColorOk: bool = true
		if enemiesNode != null:
			for e in enemiesNode.get_children():
				if int(e.get("color_variant")) != int(expectedEnemyColors[pid]):
					enemyColorOk = false

		var trampOk: bool = (trampNode != null) and (trampNode.get_child_count() >= 2)
		var cpOk: bool = (cpNode != null) and (cpNode.get_child_count() >= 2)

		var hasSecret: bool = false
		for ch in mockArena.get_children():
			if ch.get("is_secret_special") == true and String(ch.get("special_id")) == "SEC-LVL-%d" % pid:
				hasSecret = true
				break

		if not (biomeOk and lengthOk and validOk and enemyCntOk and enemyColorOk and trampOk and cpOk and hasSecret):
			allLevelsOk = false
		mockArena.free()

	assertCond(allLevelsOk, "LVL-06", "Poziomy 1-3 mają pełną skalę (>=2800px), własne biomy, wrogów AI, trampoliny '!', checkpointy i sekretne klejnoty")

func utTrampolinePadLaunchesPlayerAndRefreshesAirMoves() -> void:
	var pad := Area2D.new()
	pad.set_script(TrampolineScript)
	pad.call("configure", Vector2i(1, 2), -480.0)
	add_child(pad)

	var plr := _createMockPlayer()
	plr.current_state = PlayerScript.State.FALL
	plr.velocity.y = 120.0
	plr.can_double_jump = false
	plr.can_air_dash = false

	pad._on_body_entered(plr)
	var bouncedOk: bool = is_equal_approx(plr.velocity.y, -480.0) and plr.can_double_jump and plr.can_air_dash and (plr.current_state == PlayerScript.State.JUMP)

	# Natychmiastowe ponowne wejście podczas cooldownu nie powinno nadpisywać
	plr.velocity.y = 50.0
	pad._on_body_entered(plr)
	var cooldownOk: bool = is_equal_approx(plr.velocity.y, 50.0)

	pad._process(0.2)
	pad._on_body_entered(plr)
	var retriggerOk: bool = is_equal_approx(plr.velocity.y, -480.0)

	assertCond(bouncedOk and cooldownOk and retriggerOk, "LVL-07", "Trampolina '!' wybija gracza w górę, odnawia double jump/air dash i respektuje cooldown")
	plr.free()
	pad.free()

func utEnemyArchetypesAiStatesAndSpriteRows() -> void:
	var plr := _createMockPlayer()
	plr.global_position = Vector2(560, 294)

	# 1. Slime: rząd = 0 * 4 + 2 = 2, przechodzi w CHASE gdy gracz blisko
	var slime := EnemyScene.instantiate() as Area2D
	slime.position = Vector2(500, 294)
	add_child(slime)
	slime.configure(0, 2, 64.0, 40.0, 140.0)
	var slimeRowOk: bool = (slime._get_sprite_row() == 2)
	slime._process(0.05)
	slime._process(0.10)
	var slimeChaseOk: bool = (slime.ai_state == EnemyScript.AIState.CHASE) and (slime.position.x > 500.0) and (slime.position.x <= 564.0)

	# 2. Bat: rząd = 1 * 4 + 1 = 5, przechodzi w ALERT -> CHASE
	var bat := EnemyScene.instantiate() as Area2D
	bat.position = Vector2(510, 250)
	add_child(bat)
	bat.configure(1, 1, 56.0, 42.0, 140.0)
	var batRowOk: bool = (bat._get_sprite_row() == 5)
	bat._process(0.05)
	var batAlertOk: bool = (bat.ai_state == EnemyScript.AIState.ALERT)
	bat._process(0.25)
	var batChaseOk: bool = (bat.ai_state == EnemyScript.AIState.CHASE)

	# 3. Spider: rząd = 2 * 4 + 3 = 11, przechodzi w ALERT -> CHASE i mieści się w patrol_range
	var spider := EnemyScene.instantiate() as Area2D
	spider.position = Vector2(500, 294)
	add_child(spider)
	spider.configure(2, 3, 48.0, 44.0, 140.0)
	var spiderRowOk: bool = (spider._get_sprite_row() == 11)
	spider._process(0.05)
	var spiderAlertOk: bool = (spider.ai_state == EnemyScript.AIState.ALERT)
	spider._process(0.20)
	spider._process(0.15)
	var spiderChaseOk: bool = (spider.ai_state == EnemyScript.AIState.CHASE) and (spider.position.x > 500.0) and (spider.position.x <= 548.0)

	assertCond(slimeRowOk and slimeChaseOk and batRowOk and batAlertOk and batChaseOk and spiderRowOk and spiderAlertOk and spiderChaseOk, "LVL-08", "Archetypy AI wrogów (Slime, Bat, Spider) wybierają właściwe rzędy spritesheetu oraz stany ALERT/CHASE")
	slime.free()
	bat.free()
	spider.free()
	plr.free()

func utSzachownicaAiSeedDeterminismVariationAndValidation() -> void:
	var patryk: AdaptiveAIDirector = Events.patryk
	patryk.clear_historical_profile()
	patryk.reset_session_state(true)
	patryk.historical_move_uses["wall_climb"] = 20.0
	patryk.historical_move_uses["dash"] = 5.0
	patryk.historical_move_uses["double_jump"] = 1.0

	var rngA := RandomNumberGenerator.new()
	rngA.seed = 424242
	var bpA: Dictionary = LevelGeneratorScript.generate_blueprint(LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL, rngA, {})

	var rngB := RandomNumberGenerator.new()
	rngB.seed = 424242
	var bpB: Dictionary = LevelGeneratorScript.generate_blueprint(LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL, rngB, {})

	var detOk: bool = (bpA.get("chunk_sequence", []) == bpB.get("chunk_sequence", [])) and (bpA["blocks"].size() == bpB["blocks"].size()) and (bpA["finish_pos"] == bpB["finish_pos"])

	var uniqueLayouts: Dictionary = {}
	var allSeedsValid: bool = true
	var singleBiomeOk: bool = true
	var playstyleOk: bool = true
	for s in range(101, 111):
		var rngS := RandomNumberGenerator.new()
		rngS.seed = s
		var bpS: Dictionary = LevelGeneratorScript.generate_blueprint(LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL, rngS, {})
		if int(bpS.get("biome_id", 0)) != LevelGeneratorScript.BiomeId.AETHER:
			singleBiomeOk = false
		if not bool(bpS.get("validation", {}).get("passed", false)):
			allSeedsValid = false
		if String(bpS.get("first_half_mechanic", "")) != "wall_climb" or String(bpS.get("second_half_mechanic", "")) != "double_jump":
			playstyleOk = false
		var sig: String = "|".join(bpS.get("chunk_sequence", [])) + ":" + str(bpS["finish_pos"].x)
		uniqueLayouts[sig] = true

	var variationOk: bool = (uniqueLayouts.size() >= 2)

	var rngC := RandomNumberGenerator.new()
	rngC.seed = 777
	var bpChallenge: Dictionary = LevelGeneratorScript.generate_blueprint(
		LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL,
		rngC,
		{"min_jewels": 9, "max_time_s": 45.0, "focus_mechanics": ["dash"]}
	)
	var challengeOk: bool = (bpChallenge["jewels"].size() >= 9) and (String(bpChallenge.get("second_half_mechanic", "")) == "dash") and bool(bpChallenge.get("validation", {}).get("passed", false))

	patryk.clear_historical_profile()
	patryk.reset_session_state(true)
	assertCond(detOk and singleBiomeOk and allSeedsValid and playstyleOk and variationOk and challengeOk, "LVL-09", "Szachownica AI jest deterministyczna po seedzie, trzyma jeden biom Aether, kontruje styl i przechodzi walidator")

# ==============================================================================
# 10. TESTY PROFILU STYLU GRY I POZIOMU AI (Cyber Matrix)
# ==============================================================================

func utPlaystyleProfilerTracksZonesRoutesAndPersists() -> void:
	var prof = Events.playstyle_profiler
	var saved_data: Dictionary = prof.data.duplicate(true)
	var saved_path: String = prof.save_path
	prof.save_path = "user://playstyle_profile_test.json"
	prof.reset_profile()

	Events.level_started.emit()
	# Gracz wybiera dolną (bezpieczną) trasę, dwa razy wchodzi w strefę wspinaczki i obrywa w niej
	prof.zone_entered("route:low", "fork_hill#2")
	prof.zone_entered("route:high", "fork_hill#2")   # drugi wybór na tym samym rozwidleniu się nie liczy
	prof.zone_entered("wall_climb", "climb_wall#3")
	Events.player_hit.emit(1)
	prof.zone_exited("wall_climb", "climb_wall#3")
	prof.zone_entered("wall_climb", "climb_wall_high#5")
	Events.player_fell_in_abyss.emit(Vector2.ZERO)
	for i in range(6):
		Events.player_dashed.emit(Vector2.RIGHT)
	Events.player_jumped.emit(true)
	Events.level_completed.emit()

	var p: Dictionary = prof.get_profile()
	var zonesOk: bool = int(prof.data["zones"]["wall_climb"]["entries"]) == 2 and int(prof.data["zones"]["wall_climb"]["hits"]) == 1 and int(prof.data["zones"]["wall_climb"]["falls"]) == 1
	var routeOk: bool = int(prof.data["routes"]["safe"]) == 1 and int(prof.data["routes"]["risky"]) == 0 and float(p["risk_appetite"]) < 0.5
	var analysisOk: bool = String(p["favorite"]) == "dash" and String(p["weakest"]) == "wall_climb" and bool(p["has_data"])

	# Zapis -> odczyt
	var before: Dictionary = prof.data.duplicate(true)
	prof.reset_profile()
	prof.data = before
	prof.save_profile()
	prof._reset_data()
	prof.load_profile()
	var persistOk: bool = int(prof.data["moves"]["dash"]) == 6 and int(prof.data["completions"]) == 1

	assertCond(zonesOk and routeOk and analysisOk and persistOk, "AI-01", "Profil stylu gry zlicza ruchy, błędy w strefach mechanik i wybory tras oraz przetrwa zapis/odczyt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prof.save_path))
	prof.save_path = saved_path
	prof.data = saved_data

func utAiLevelAdaptsToPlaystyleProfile() -> void:
	var prof = Events.playstyle_profiler
	var saved_data: Dictionary = prof.data.duplicate(true)
	var patryk: AdaptiveAIDirector = Events.patryk
	patryk.clear_historical_profile()
	patryk.historical_move_uses["dash"] = 30.0
	patryk.historical_move_uses["double_jump"] = 10.0
	patryk.historical_move_uses["wall_climb"] = 1.0

	# Profil A: gracz bez historii
	prof._reset_data()
	var rngA := RandomNumberGenerator.new()
	rngA.seed = 5150
	var bpA: Dictionary = LevelGeneratorScript.generate_blueprint(LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL, rngA, {})

	# Profil B: wprawny gracz, który ciągle obrywa przy wspinaczce i omija górne trasy, zbiera wszystko
	prof._reset_data()
	prof.data["runs"] = 8
	prof.data["completions"] = 8
	prof.data["play_seconds"] = 900.0
	prof.data["moves"]["dash"] = 120.0
	prof.data["moves"]["double_jump"] = 60.0
	prof.data["moves"]["slide"] = 2.0
	prof.data["moves"]["trick"] = 1.0
	prof.data["zones"]["wall_climb"] = {"entries": 6, "hits": 5, "falls": 2}
	prof.data["routes"] = {"risky": 0, "safe": 5}
	prof.data["jewels_collected"] = 190
	prof.data["jewels_available"] = 200
	var rngB := RandomNumberGenerator.new()
	rngB.seed = 5150
	var bpB: Dictionary = LevelGeneratorScript.generate_blueprint(LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL, rngB, {})

	var seqA: Array = bpA["chunk_sequence"]
	var seqB: Array = bpB["chunk_sequence"]
	var reasons: Array = bpB["playstyle_report"]["reasons"]
	var joined: String = " ".join(reasons)
	var adaptsOk: bool = seqA != seqB and joined.contains("tarczą") and joined.contains("omijasz") and joined.contains("Zbierasz")
	var halvesOk: bool = String(bpB["first_half_mechanic"]) == "dash" and String(bpB["second_half_mechanic"]) == "wall_climb"
	var shieldOk: bool = false
	for j in bpB["jewels"]:
		if int(j.get("jewel_type", 0)) == 3:
			shieldOk = true
	var validOk: bool = bool(bpA["validation"]["passed"]) and bool(bpB["validation"]["passed"])
	assertCond(adaptsOk and halvesOk and shieldOk and validOk, "AI-02", "Poziom AI (Cyber Matrix) dobiera moduły, tarczę, sekret i trudność pod profil stylu gry, przechodząc walidator")
	prof.data = saved_data
	patryk.clear_historical_profile()

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
		
	for audName in ["AudioPause", "AudioWin", "AudioGameOver", "AudioPickup"]:
		var aud = AudioStreamPlayer.new()
		aud.name = audName
		hud.add_child(aud)
		
	add_child(arena)
	return arena
