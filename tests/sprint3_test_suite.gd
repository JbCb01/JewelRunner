extends Node

## Zestaw Testów Automatycznych - Sprint 3 (S23KC2S1P1-250 & S23KC2S1P1-279)
## Zakres: Testy wrogów, wzmocnień (power-upów), życia i poziomów oraz reguł nadpisywania

const PlayerScript = preload("res://scripts/actors/player/player_controller.gd")
const EnemyScript = preload("res://scripts/actors/enemies/enemy_mockup.gd")
const PowerUpScript = preload("res://scripts/power_up.gd")
const HazardScript = preload("res://scripts/core/hazard_area.gd")
const ArenaScript = preload("res://scripts/core/test_arena.gd")
const JewelScript = preload("res://scripts/jewel.gd")

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
	
	print("\n==================================================================")
	print(" PODSUMOWANIE SPRINT 3: ZALICZONE: %d | BŁĘDY: %d | ŁĄCZNIE: %d" % [passCnt, failCnt, passCnt + failCnt])
	print("==================================================================")

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
