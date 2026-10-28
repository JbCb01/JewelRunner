extends Node

const JewelScript = preload("res://scripts/jewel.gd")
const MainMenuScript = preload("res://scripts/menu.gd")
const PlayerScript = preload("res://scripts/actors/player/player_controller.gd")
const HazardScript = preload("res://scripts/core/hazard_area.gd")
const ArenaScript = preload("res://scripts/core/test_arena.gd")

var passCnt: int = 0
var failCnt: int = 0

func _ready() -> void:
	print("==================================================")
	print("   START TESTÓW AUTOMATYCZNYCH MVP - JEWELRUNNER  ")
	print("==================================================\n")
	
	print("--- [1] TESTY JEDNOSTKOWE (UNIT TESTS) ---")
	utSessionIdFormat()
	utLevelCompletionState()
	utDefaultInputMapSetup()
	utArenaTimeFormatting()
	utJewelBobbingMath()
	utPlayerColliderResize()
	utPlayerStaminaCalculation()
	utPlayerCoyoteAndCooldownTimers()
	
	print("\n--- [2] TESTY INTEGRACYJNE (FRONTEND <-> BACKEND) ---")
	itJewelPickupUpdatesHudScore()
	itPlayerTrickAddsScoreToHud()
	itPlayerStaminaSyncsWithHudBar()
	itHazardHitTriggersGameOverUi()
	itGoalEnteredCompletesLevelAndUpdatesMenuBadge()
	itMainMenuViewNavigation()
	itMainMenuSfxMuteSync()
	
	print("\n==================================================")
	print(" PODSUMOWANIE: ZALICZONE: %d | BŁĘDY: %d | ŁĄCZNIE: %d" % [passCnt, failCnt, passCnt + failCnt])
	print("==================================================")

# --- Asystent asercji ---
func assertCond(cond: bool, testId: String, desc: String) -> void:
	if cond:
		passCnt += 1
		print("[PASS] %s: %s" % [testId, desc])
	else:
		failCnt += 1
		print("[FAIL] %s: %s" % [testId, desc])

# ==============================================================================
# 1. TESTY JEDNOSTKOWE (Izolowana logika komponentów backendowych)
# ==============================================================================

func utSessionIdFormat() -> void:
	var sesId: String = Events.generate_session_id()
	var isValid: bool = sesId.begins_with("SES-") and sesId.length() > 9
	assertCond(isValid, "UT-01", "Generator ID sesji zwraca poprawny format (SES-timestamp-rand)")

func utLevelCompletionState() -> void:
	Events.completed_levels.clear()
	var beforeDone: bool = Events.is_level_completed(1)
	Events.complete_level(1)
	var afterDone: bool = Events.is_level_completed(1)
	assertCond(not beforeDone and afterDone, "UT-02", "Stan ukończenia poziomu zapisuje się w słowniku Events")

func utDefaultInputMapSetup() -> void:
	Events._setup_default_inputs()
	var hasJump: bool = InputMap.has_action("jump")
	var hasDash: bool = InputMap.has_action("dash")
	var hasTrick: bool = InputMap.has_action("trick")
	assertCond(hasJump and hasDash and hasTrick, "UT-03", "Automatyczna rejestracja akcji w InputMap działa poprawnie")

func utArenaTimeFormatting() -> void:
	var arena = ArenaScript.new()
	var formattedStr: String = arena._format_time(65.43)
	assertCond(formattedStr == "01:05.4", "UT-04", "Formatowanie czasu przelicza 65.43s na '01:05.4'")
	arena.free()

func utJewelBobbingMath() -> void:
	var jwl = JewelScript.new()
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	spr.position.y = 10.0
	jwl.add_child(spr)
	add_child(jwl)
	
	jwl._process(0.25) # timePassed = 0.25 * 4.0 = 1.0 rad
	var expectedY: float = 10.0 + sin(1.0) * 3.0
	var isClose: bool = is_equal_approx(spr.position.y, expectedY)
	assertCond(isClose, "UT-05", "Obliczanie oscylacji (bobbing) klejnotu w funkcji _process")
	jwl.free()

func utPlayerColliderResize() -> void:
	var plr = _createMockPlayer()
	plr._set_collider_crouched(true)
	var crouchSize: Vector2 = (plr.collision_shape.shape as RectangleShape2D).size
	plr._set_collider_crouched(false)
	var standSize: Vector2 = (plr.collision_shape.shape as RectangleShape2D).size
	
	var isCorrect: bool = (crouchSize == Vector2(18, 16)) and (standSize == Vector2(18, 30))
	assertCond(isCorrect, "UT-06", "Zmiana wymiarów hitboxa gracza między staniem (18x30) a kucaniem (18x16)")
	plr.free()

func utPlayerStaminaCalculation() -> void:
	var plr = _createMockPlayer()
	plr.wall_stamina = 2.0
	plr._update_stamina(0.75, true)
	var afterDrain: float = plr.wall_stamina
	plr._update_stamina(5.0, true) # Test dolnej granicy (0.0)
	var afterOverdrain: float = plr.wall_stamina
	
	assertCond(is_equal_approx(afterDrain, 1.25) and is_equal_approx(afterOverdrain, 0.0), "UT-07", "Drenaż staminy podczas wspinaczki oraz blokada spadku poniżej 0.0")
	plr.free()

func utPlayerCoyoteAndCooldownTimers() -> void:
	var plr = _createMockPlayer()
	plr.coyote_timer = 0.12
	plr.dash_cooldown_timer = 0.6
	plr._update_timers(0.1)
	
	var coyoteOk: bool = is_equal_approx(plr.coyote_timer, 0.02)
	var dashOk: bool = is_equal_approx(plr.dash_cooldown_timer, 0.5)
	assertCond(coyoteOk and dashOk, "UT-08", "Dekrementacja timerów coyote_time oraz dash_cooldown w każdej klatce")
	plr.free()

# ==============================================================================
# 2. TESTY INTEGRACYJNE (Frontend UI/HUD <-> Event Bus <-> Backend Logiki)
# ==============================================================================

func itJewelPickupUpdatesHudScore() -> void:
	var arena = _createMockArena()
	var jwl = JewelScript.new()
	jwl.pointVal = 150
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	jwl.add_child(spr)
	add_child(jwl)
	
	var plr = _createMockPlayer()
	jwl._onBodyEntered(plr) # Symulacja wejścia gracza w klejnot (Backend -> Events -> HUD)
	
	var scoreOk: bool = (arena.total_score == 150) and (arena.collected_jewels == 1)
	var hudOk: bool = (arena.hud_score_label.text == " SCORE: 150 ")
	assertCond(scoreOk and hudOk, "IT-01", "Zebranie klejnotu aktualizuje stan punktów w Backendzie i tekst na HUDzie")
	
	plr.free()
	jwl.free()
	arena.free()

func itPlayerTrickAddsScoreToHud() -> void:
	var arena = _createMockArena()
	# Symulacja naliczenia paczki punktów z tricku powietrznego przez szynę Events
	Events.score_added.emit(20)
	
	var hudOk: bool = (arena.total_score == 20) and (arena.hud_score_label.text == " SCORE: 20 ")
	assertCond(hudOk, "IT-02", "Punkty za trick z kontrolera gracza aktualizują licznik na HUDzie Areny")
	arena.free()

func itPlayerStaminaSyncsWithHudBar() -> void:
	var arena = _createMockArena()
	var plr = _createMockPlayer()
	
	plr._update_stamina(0.8, true) # Zmniejsza staminę z 2.0 do 1.2 i emituje sygnał do HUD
	var barSynced: bool = is_equal_approx(arena.hud_stamina_bar.value, 1.2) and is_equal_approx(arena.hud_stamina_bar.max_value, 2.0)
	assertCond(barSynced, "IT-03", "Zmiana staminy w PlayerController aktualizuje pasek ProgressBar w HUDzie")
	
	plr.free()
	arena.free()

func itHazardHitTriggersGameOverUi() -> void:
	var arena = _createMockArena()
	var hzrd = HazardScript.new()
	add_child(hzrd)
	var plr = _createMockPlayer()
	
	hzrd._on_body_entered(plr) # Gracz wpada na kolce -> Hazard -> Events.player_hit -> Arena -> GameOverMenu
	
	var isGameOver: bool = arena.is_game_over and arena.game_over_menu.visible
	get_tree().paused = false # Odblokowanie drzewa po teście
	assertCond(isGameOver, "IT-04", "Kolizja z Hazardem wywołuje stan śmierci i otwiera ekran Game Over w UI")
	
	plr.free()
	hzrd.free()
	arena.free()

func itGoalEnteredCompletesLevelAndUpdatesMenuBadge() -> void:
	Events.completed_levels.clear()
	var arena = _createMockArena()
	var plr = _createMockPlayer()
	arena.total_score = 350
	
	# Gracz wchodzi w metę na arenie
	arena._on_goal_entered(plr)
	get_tree().paused = false
	
	# Inicjalizacja MainMenu i sprawdzenie czy Frontend odczytał ukończenie poziomu z Events
	var menu = _createMockMainMenu()
	menu._update_level_select()
	
	var winUiOk: bool = arena.is_stage_cleared and arena.win_screen.visible and (arena.win_score_label.text == "SCORE: 350 PTS")
	var badgeOk: bool = menu.lvl1CompletedBadge.visible and menu.lvl1CheckmarkIcon.visible
	assertCond(winUiOk and badgeOk, "IT-05", "Wejście w FinishGoal wyświetla WinScreen oraz odblokowuje odznakę w MainMenu")
	
	menu.free()
	plr.free()
	arena.free()

func itMainMenuViewNavigation() -> void:
	var menu = _createMockMainMenu()
	menu._showView(menu.setView)
	var setVis: bool = menu.setView.visible and not menu.homeView.visible
	menu._showView(menu.lvlView)
	var lvlVis: bool = menu.lvlView.visible and not menu.setView.visible
	
	assertCond(setVis and lvlVis, "IT-06", "Nawigacja w MainMenu poprawnie przełącza widoczność kontenerów widoków")
	menu.free()

func itMainMenuSfxMuteSync() -> void:
	var menu = _createMockMainMenu()
	menu.isMusicMuted = false
	menu.isSfxMuted = false
	
	menu._toggleSfx() # Przełącza isSfxMuted na true
	var sfxBusIdx: int = AudioServer.get_bus_index("SFX")
	var stateOk: bool = (menu.isSfxMuted == true)
	if sfxBusIdx != -1:
		stateOk = stateOk and AudioServer.is_bus_mute(sfxBusIdx)
		
	assertCond(stateOk, "IT-07", "Przełącznik SFX w ustawieniach wycisza szynę SFX w AudioServer")
	menu.free()

# ==============================================================================
# FUNKCJE POMOCNICZE (Tworzenie struktur węzłów w pamięci dla testów)
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
	plr.add_child(vis)
	
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
	
	# Stamina HUD
	var stamPanel = Node.new()
	stamPanel.name = "StaminaPanel"
	var hbox = Node.new()
	hbox.name = "HBox"
	var stamBar = ProgressBar.new()
	stamBar.name = "HudStaminaBar"
	hbox.add_child(stamBar)
	stamPanel.add_child(hbox)
	hud.add_child(stamPanel)
	
	# Score HUD
	var scorePanel = Node.new()
	scorePanel.name = "ScorePanel"
	var scoreLbl = Label.new()
	scoreLbl.name = "ScoreText"
	scorePanel.add_child(scoreLbl)
	hud.add_child(scorePanel)
	
	# Menus
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

func _createMockMainMenu() -> Control:
	var menu = MainMenuScript.new()
	for vName in ["HomeView", "LevelSelectView", "SettingsView", "CreatorsView"]:
		var v = Control.new()
		v.name = vName
		if vName == "LevelSelectView":
			var b1 = Button.new()
			b1.name = "Lvl1Btn"
			var badge = Control.new()
			badge.name = "CompletedBadge"
			var check = Control.new()
			check.name = "CheckmarkIcon"
			b1.add_child(badge)
			b1.add_child(check)
			v.add_child(b1)
		menu.add_child(v)
	add_child(menu)
	return menu
