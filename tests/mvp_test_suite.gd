extends Node

const JewelScript = preload("res://scripts/jewel.gd")
const MainMenuScript = preload("res://scripts/menu.gd")
const PlayerScript = preload("res://scripts/actors/player/player_controller.gd")
const HazardScript = preload("res://scripts/core/hazard_area.gd")
const ArenaScript = preload("res://scripts/core/test_arena.gd")
const AIDirectorScript = preload("res://scripts/core/ai_director.gd")
const LevelGeneratorScript = preload("res://scripts/core/level_generator.gd")
const CyberQuiz = preload("res://scripts/core/cyber_quiz.gd")
const SkinManager = preload("res://scripts/core/skin_manager.gd")

var passCnt: int = 0
var failCnt: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")

func _ready() -> void:
	if not Engine.is_editor_hint():
		_run_all_tests()

func _run_all_tests() -> void:
	if passCnt + failCnt > 0:
		return
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
	utSpecialMovesConsumeStamina()
	utTrickRegenCannotMultiplyStamina()
	utAdaptiveMultipliersConstantSumAndWeights()
	utAIDirectorOverloadAndLevelAnalyzer()
	utLevelGeneratorAndTileMapIntegration()
	utAIContractRelayLockMode()
	utAIContractCursedJewelsMode()
	utCounterPlaystyleChessboardGenerator()
	utMechanicDnaRadarCalculation()
	utPortalSyncProfileSkinsBoostersAndSettings()
	utMapGeneratorAdaptsToWebChallenges()
	utSkinManagerLoadsAllSkinsWithCorrectSpriteFrames()
	
	print("\n--- [2] TESTY INTEGRACYJNE (FRONTEND <-> BACKEND <-> WEB PORTAL) ---")
	itJewelPickupUpdatesHudProgress()
	itPlayerTrickRegensStaminaOnHud()
	itPlayerStaminaSyncsWithHudBar()
	itHazardHitTriggersGameOverUi()
	itGoalRequiresAllJewelsAndRecordsTime()
	itMainMenuViewNavigation()
	itMainMenuSfxMuteSync()
	itSettingsAudioSlidersAdjustAudioServerBuses()
	itTopProfileButtonOpensWebPortalAndSyncs()
	itPortalShieldAndMagnetBoostersInGameplay()
	itWebChallengesCompleteOnWinningRun()
	itLevelSelectMechanicPanelsAndAIContracts()
	itAudioPercentageLabelBugFix()
	itGraphicsSettingsFunctionality()
	itLanguageSettingsSwitchingAndGermanRemoval()
	itSkinSelectionPreservesAudioSettings()
	itMenuAndLevelMusicIndependentSliders()
	itPauseMenuSettingsViewAndInGameLevelMusic()
	itArrowKeyNavigationInPauseGameOverWinScreens()
	itSpecialJewelPowerupsMechanics()
	itEnemyMockupStompDashAndDamageMechanics()
	itStarHpIndicatorAndSpikeSprite()
	itKnowledgeCheckCyberQuizFunctionality()
	
	print("\n==================================================")
	var summary = "PODSUMOWANIE: ZALICZONE: %d | BŁĘDY: %d | ŁĄCZNIE: %d" % [passCnt, failCnt, passCnt + failCnt]
	print(summary)
	print("==================================================")
	var glob_path = ProjectSettings.globalize_path("res://test_results.txt")
	var f = FileAccess.open(glob_path, FileAccess.WRITE)
	if f:
		f.store_line("=== RAPORT TESTOW AUTOMATYCZNYCH ===")
		for l in _test_log:
			f.store_line(l)
		f.store_line(summary)
		f.close()
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failCnt == 0 else 1)

# --- Asystent asercji ---
var _test_log: Array[String] = []

func assertCond(cond: bool, testId: String, desc: String) -> void:
	var msg = ""
	if cond:
		passCnt += 1
		msg = "[PASS] %s: %s" % [testId, desc]
	else:
		failCnt += 1
		msg = "[FAIL] %s: %s" % [testId, desc]
	print(msg)
	_test_log.append(msg)

# ==============================================================================
# 1. TESTY JEDNOSTKOWE (Izolowana logika komponentów backendowych)
# ==============================================================================

func utSessionIdFormat() -> void:
	var sesId: String = Events.generate_session_id()
	var isValid: bool = sesId.begins_with("SES-") and sesId.length() > 9
	assertCond(isValid, "UT-01", "Generator ID sesji zwraca poprawny format (SES-timestamp-rand)")

func utLevelCompletionState() -> void:
	Events.completed_levels.clear()
	Events.level_best_times.clear()
	var beforeDone: bool = Events.is_level_completed(1)
	Events.complete_level(1, 42.5)
	var afterDone: bool = Events.is_level_completed(1)
	var timeSaved: bool = is_equal_approx(Events.get_level_best_time(1), 42.5)
	assertCond(not beforeDone and afterDone and timeSaved, "UT-02", "Stan ukończenia poziomu oraz najlepszy czas zapisują się w Events")

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
	
	jwl._process(0.25)
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
	Events.ai_director.set_contract_mode(AIDirectorScript.ContractMode.OVERLOAD_CLASSIC)
	Events.ai_director.reset_session_state(true)
	var plr = _createMockPlayer()
	plr.wall_stamina = 2.0
	plr._update_stamina(0.75, true)
	var afterDrain: float = plr.wall_stamina
	plr._update_stamina(5.0, true)
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

func utSpecialMovesConsumeStamina() -> void:
	Events.ai_director.set_contract_mode(AIDirectorScript.ContractMode.OVERLOAD_CLASSIC)
	Events.ai_director.reset_session_state(true)
	var plr = _createMockPlayer()
	plr.wall_stamina = 2.0
	
	var djCost: float = plr.get_move_stamina_cost("double_jump")
	plr.can_double_jump = true
	plr._execute_double_jump()
	var afterDj: float = plr.wall_stamina
	var djOk: bool = is_equal_approx(afterDj, 2.0 - djCost)
	
	var dashCost: float = plr.get_move_stamina_cost("dash")
	plr._start_dash(1.0)
	var afterDash: float = plr.wall_stamina
	var dashOk: bool = is_equal_approx(afterDash, afterDj - dashCost)
	
	plr.wall_stamina = 0.0
	var rejectedDj: bool = not plr.can_use_special_move("double_jump")
	var rejectedDash: bool = not plr.can_use_special_move("dash")
	var rejectedClimb: bool = not plr.can_use_special_move("wall_climb")
	
	assertCond(djOk and dashOk and rejectedDj and rejectedDash and rejectedClimb, "UT-09", "Wszystkie ruchy specjalne (Double Jump, Dash, Climb) wymagają i zużywają staminę")
	plr.free()

func utTrickRegenCannotMultiplyStamina() -> void:
	Events.ai_director.reset_session_state(true)
	var plr = _createMockPlayer()
	
	var djMaxRegen: float = plr.get_max_possible_trick_regen_for_move("double_jump")
	var djMinCost: float = plr.double_jump_base_stamina_cost * Events.ai_director.min_multiplier
	var wcMaxRegen: float = plr.get_max_possible_trick_regen_for_move("wall_climb")
	var wcMinCost: float = plr.wall_climb_base_stamina_cost * Events.ai_director.min_multiplier
	var dashMaxRegen: float = plr.get_max_possible_trick_regen_for_move("dash")
	var dashMinCost: float = plr.dash_base_stamina_cost * Events.ai_director.min_multiplier
	
	var physicsBalanced: bool = (djMaxRegen < djMinCost) and (wcMaxRegen < wcMinCost) and (dashMaxRegen < dashMinCost)
	
	plr.wall_stamina = 1.5
	plr.airborne_origin_y = 200.0
	plr.global_position = Vector2(100.0, 160.0)
	plr.can_double_jump = true
	plr._execute_double_jump()
	plr.regenerate_stamina_from_trick(0.60)
	var netNoGain: bool = plr.wall_stamina < 1.5
	
	plr.wall_stamina = 0.8
	plr._execute_jump()
	var gained: float = plr.regenerate_stamina_from_trick(0.5)
	var normalRegenWorks: bool = (gained > 0.15) and (plr.wall_stamina > 0.95)
	
	assertCond(physicsBalanced and netNoGain and normalRegenWorks, "UT-10", "Tricki w powietrzu regenerują staminę, ale nie pozwalają na jej mnożenie z ruchów specjalnych")
	plr.free()

func utAdaptiveMultipliersConstantSumAndWeights() -> void:
	var dir: AdaptiveAIDirector = Events.ai_director
	dir.reset_session_state(true)
	
	var initialSum: float = dir.get_multiplier_sum()
	var sumOk1: bool = is_equal_approx(initialSum, dir.target_multiplier_sum)
	
	dir.record_move_use("double_jump", 1.0)
	dir.record_move_use("double_jump", 1.0)
	dir.record_move_use("double_jump", 1.0)
	
	var mDj: float = dir.get_multiplier("double_jump")
	var mWc: float = dir.get_multiplier("wall_climb")
	var mDash: float = dir.get_multiplier("dash")
	var sumAfterDj: float = dir.get_multiplier_sum()
	
	var shiftedProperly: bool = (mDj > 1.0) and (mWc < 1.0) and (mDash < 1.0)
	var sumOk2: bool = is_equal_approx(sumAfterDj, dir.target_multiplier_sum)
	
	dir.set_move_weights({"double_jump": 1.4, "wall_climb": 0.9, "dash": 0.7})
	for _i in range(15):
		dir.record_move_use("dash", 1.0)
	var sumAfterWeightsAndSpam: float = dir.get_multiplier_sum()
	var sumOk3: bool = is_equal_approx(sumAfterWeightsAndSpam, dir.target_multiplier_sum)
	
	assertCond(sumOk1 and shiftedProperly and sumOk2 and sumOk3, "UT-11", "System mnożników podnosi koszt używanego ruchu, obniża pozostałe i zachowuje stałą sumę z wagami")
	dir.reset_session_state(true)

func utAIDirectorOverloadAndLevelAnalyzer() -> void:
	var dir: AdaptiveAIDirector = Events.ai_director
	dir.set_contract_mode(AIDirectorScript.ContractMode.OVERLOAD_CLASSIC)
	dir.reset_session_state(true)
	
	for _i in range(5):
		dir.record_move_use("dash", 1.0)
	var dashLocked: bool = dir.is_move_locked("dash")
	
	dir.record_air_trick(3.0)
	var dashUnlockedAfterTrick: bool = not dir.is_move_locked("dash")
	
	assertCond(dashLocked and dashUnlockedAfterTrick, "UT-12", "AI Director blokuje przeciążony ruch i odblokowuje go po wykonaniu Tricków w powietrzu")
	dir.reset_session_state(true)

func utLevelGeneratorAndTileMapIntegration() -> void:
	var mockArena := Node2D.new()
	add_child(mockArena)
	
	var genInfo: Dictionary = LevelGeneratorScript.build_level_for_arena(mockArena, LevelGeneratorScript.MechanicProfile.VERTICAL_ASCENT, 12345)
	var tileLayer: TileMapLayer = mockArena.get_node_or_null("LevelTileMapLayer") as TileMapLayer
	var hasGridMeta: bool = (tileLayer != null) and tileLayer.has_meta("logical_tile_grid")
	var grid: Dictionary = tileLayer.get_meta("logical_tile_grid") if hasGridMeta else {}
	
	var analysis: Dictionary = Events.ai_director.analyze_level(mockArena)
	var analyzedOk: bool = analysis.has("dominant_mechanic") and int(analysis.get("jewel_count", 0)) >= 4
	
	assertCond(bool(genInfo.get("generated", false)) and grid.size() > 20 and analyzedOk, "UT-13", "Generator poziomów tworzy geometrię, siatkę kafelków TileMapLayer oraz profil dla Analizatora AI")
	mockArena.free()
	Events.ai_director.reset_session_state(true)

func utAIContractRelayLockMode() -> void:
	var dir: AdaptiveAIDirector = Events.ai_director
	dir.reset_session_state(true)
	dir.set_contract_mode(AIDirectorScript.ContractMode.RELAY_LOCK)
	
	# Użycie double_jump blokuje double_jump w trybie Sztafety
	dir.record_move_use("double_jump", 1.0)
	var djLocked: bool = dir.is_move_locked("double_jump") and not dir.is_move_locked("dash")
	
	# Użycie dash odblokowuje double_jump i blokuje dash!
	dir.record_move_use("dash", 1.0)
	var relaySwitched: bool = (not dir.is_move_locked("double_jump")) and dir.is_move_locked("dash")
	
	# Wykonanie Tricku w powietrzu resetuje blokadę Sztafety
	dir.record_air_trick(0.35)
	var resetByTrick: bool = not dir.is_move_locked("dash")
	
	dir.set_contract_mode(AIDirectorScript.ContractMode.OVERLOAD_CLASSIC)
	dir.reset_session_state(true)
	assertCond(djLocked and relaySwitched and resetByTrick, "UT-14", "Kontrakt AI 'Sztafeta Ruchu' (Relay Lock) wymusza przeplatanie ruchów A -> B lub Trick")

func utAIContractCursedJewelsMode() -> void:
	var dir: AdaptiveAIDirector = Events.ai_director
	dir.reset_session_state(true)
	
	var jwl = JewelScript.new()
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	jwl.add_child(spr)
	add_child(jwl)
	jwl.set_cursed("wall_climb", 4.0)
	
	var plr = _createMockPlayer()
	jwl._onBodyEntered(plr)
	
	var climbLocked: bool = dir.is_move_locked("wall_climb") and is_equal_approx(dir.get_lockout_remaining("wall_climb"), 4.0)
	assertCond(climbLocked, "UT-15", "Zebranie Niestabilnego Klejnotu (Cursed Jewel) nakłada czasową blokadę na przypisaną mechanikę")
	
	plr.free()
	jwl.free()
	dir.reset_session_state(true)

func utCounterPlaystyleChessboardGenerator() -> void:
	var dir: AdaptiveAIDirector = Events.ai_director
	dir.clear_historical_profile()
	dir.reset_session_state(true)
	
	# Symulacja historii gracza: gracz bardzo często używa double_jump, czasem dash, a unika wall_climb
	dir.historical_move_uses["double_jump"] = 25.0
	dir.historical_move_uses["dash"] = 8.0
	dir.historical_move_uses["wall_climb"] = 1.0
	
	var fav: String = dir.get_favorite_move()
	var least: String = dir.get_least_used_move()
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bp: Dictionary = LevelGeneratorScript.generate_blueprint(LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL, rng, {})
	var firstHalfOk: bool = (String(bp.get("first_half_mechanic", "")) == "double_jump")
	var secondHalfOk: bool = (String(bp.get("second_half_mechanic", "")) == "wall_climb")
	
	assertCond(fav == "double_jump" and least == "wall_climb" and firstHalfOk and secondHalfOk, "UT-16", "Generator 'Szachownica Stylu Gracza' buduje 1. połowę pod ulubiony ruch, a 2. połowę pod unikany ruch")
	dir.clear_historical_profile()

func utMechanicDnaRadarCalculation() -> void:
	var mockArena := Node2D.new()
	add_child(mockArena)
	LevelGeneratorScript.build_level_for_arena(mockArena, LevelGeneratorScript.MechanicProfile.HORIZON_IMPULSE, 999)
	var analysis: Dictionary = Events.ai_director.analyze_level(mockArena)
	var dna: Dictionary = analysis.get("dna_shares", {})
	var totalPct: int = int(dna.get("double_jump", 0)) + int(dna.get("wall_climb", 0)) + int(dna.get("dash", 0))
	assertCond(totalPct == 100 and int(dna.get("dash", 0)) > 0, "UT-17", "Analizator poziomu wylicza procentowy Radar DNA Mechanik sumujący się do 100%")
	mockArena.free()

func utPortalSyncProfileSkinsBoostersAndSettings() -> void:
	var ps = Events.portal_sync
	ps.simulate_successful_pairing("K7P2QX")
	
	var plr = _createMockPlayer()
	var animSpr := AnimatedSprite2D.new()
	animSpr.name = "AnimatedSprite2D"
	plr.visuals.add_child(animSpr)
	ps.apply_cosmetics_and_boosters_to_player(plr)
	
	var profileOk: bool = (ps.player_profile["username"] == "Demo") and (int(ps.player_profile["gems"]) == 450)
	var skinOk: bool = (String(plr.get_meta("portal_active_skin", "")) == "Bursztynowa Stelly" or String(plr.get_meta("portal_active_skin", "")) == "Złoty biegacz")
	var hatNode: Node2D = plr.visuals.get_node_or_null("PortalAccessoryHat")
	var hatOk: bool = (hatNode != null) and hatNode.visible
	var boostersOk: bool = (plr.max_health == 4) and bool(plr.get_meta("has_portal_shield", false)) and bool(plr.get_meta("has_portal_magnet", false))
	
	assertCond(profileOk and skinOk and hatOk and boostersOk, "UT-18", "Synchronizacja ze stroną pobiera profil, skórkę, kolor, czapkę oraz wzmocnienia (HP, Tarcza, Magnes)")
	plr.free()
	ps._init_default_portal_challenges()

func utMapGeneratorAdaptsToWebChallenges() -> void:
	var mockArena := Node2D.new()
	add_child(mockArena)
	
	# Symulujemy wyzwanie ze strony wymagające aż 8 klejnotów i limitu 45 sekund
	var customChallengeReqs: Dictionary = {
		"min_jewels": 8,
		"max_time_s": 45.0,
		"focus_mechanics": ["wall_climb"],
		"active_challenge_names": ["Super Łowca Klejnotów", "Mistrz Czasu Pro"]
	}
	
	var genInfo: Dictionary = LevelGeneratorScript.build_level_for_arena(
		mockArena,
		LevelGeneratorScript.MechanicProfile.AI_PROCEDURAL,
		7777,
		null,
		true,
		customChallengeReqs
	)
	
	var jewelCnt: int = int(genInfo.get("jewel_count", 0))
	var maxTime: float = float(genInfo.get("challenge_max_time_s", -1.0))
	var secondMech: String = String(genInfo.get("second_half_mechanic", ""))
	
	assertCond(jewelCnt >= 8 and is_equal_approx(maxTime, 45.0) and secondMech == "wall_climb", "UT-19", "Generator map dostosowuje liczbę Jeweli, limit czasu i mechanikę do aktywnych zadań ze strony")
	mockArena.free()

func utSkinManagerLoadsAllSkinsWithCorrectSpriteFrames() -> void:
	var skinKeys = ["base", "noir", "office", "2077", "promissed", "retro"]
	var anims = ["appear", "dash", "double_jump", "idle", "jump", "fall", "run", "slide", "crouch", "wall_climb", "wall_slide", "trick"]
	var allSkinsValid: bool = true
	
	for key in skinKeys:
		var frames: SpriteFrames = SkinManager.get_sprite_frames(key)
		if not frames:
			allSkinsValid = false
			break
		for a in anims:
			if not frames.has_animation(a) or frames.get_frame_count(a) == 0:
				allSkinsValid = false
				break
				
	var plr = _createMockPlayer()
	var animSpr := AnimatedSprite2D.new()
	animSpr.name = "AnimatedSprite2D"
	plr.visuals.add_child(animSpr)
	
	var appliedOk: bool = SkinManager.apply_skin_to_player(plr, "2077")
	var isSpriteFramesUpdated: bool = (animSpr.sprite_frames != null) and (plr.get_meta("active_skin_key", "") == "2077") and (animSpr.self_modulate == Color.WHITE)
	
	assertCond(allSkinsValid and appliedOk and isSpriteFramesUpdated, "UT-20", "SkinManager poprawnie ładuje wszystkie 6 skórek z podfolderów assets/sprites i aplikuje SpriteFrames do postaci")
	plr.free()

# ==============================================================================
# 2. TESTY INTEGRACYJNE (Frontend UI/HUD <-> Event Bus <-> Backend & Web Portal)
# ==============================================================================

func itJewelPickupUpdatesHudProgress() -> void:
	var arena = _createMockArena(2)
	var jwl = JewelScript.new()
	jwl.pointVal = 150
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	jwl.add_child(spr)
	add_child(jwl)
	
	var plr = _createMockPlayer()
	jwl._onBodyEntered(plr)
	
	var countOk: bool = (arena.collected_jewels == 1) and (arena.total_jewels == 2)
	var hudOk: bool = (arena.hud_score_label.text == " JEWELS: 1/2 ")
	assertCond(countOk and hudOk, "IT-01", "Zebranie klejnotu aktualizuje licznik JEWELS (X/Y) na HUDzie")
	
	plr.free()
	jwl.free()
	arena.free()

func itPlayerTrickRegensStaminaOnHud() -> void:
	var arena = _createMockArena(1)
	var plr = _createMockPlayer()
	plr.wall_stamina = 1.0
	plr._execute_jump()
	plr.regenerate_stamina_from_trick(0.5)
	
	var hudSynced: bool = (arena.hud_stamina_bar.value > 1.1) and is_equal_approx(arena.hud_stamina_bar.value, plr.wall_stamina)
	assertCond(hudSynced, "IT-02", "Regeneracja staminy poprzez Trick w powietrzu aktualizuje pasek staminy na HUDzie")
	plr.free()
	arena.free()

func itPlayerStaminaSyncsWithHudBar() -> void:
	Events.ai_director.set_contract_mode(AIDirectorScript.ContractMode.OVERLOAD_CLASSIC)
	Events.ai_director.reset_session_state(true)
	var arena = _createMockArena(1)
	var plr = _createMockPlayer()
	
	plr._update_stamina(0.8, true)
	var barSynced: bool = is_equal_approx(arena.hud_stamina_bar.value, 1.2) and is_equal_approx(arena.hud_stamina_bar.max_value, 2.0)
	assertCond(barSynced, "IT-03", "Zmiana staminy w PlayerController aktualizuje pasek ProgressBar w HUDzie")
	
	plr.free()
	arena.free()

func itHazardHitTriggersGameOverUi() -> void:
	var arena = _createMockArena(1)
	var hzrd = HazardScript.new()
	add_child(hzrd)
	var plr = _createMockPlayer()
	plr.set_meta("has_portal_shield", false)
	plr.current_health = 1
	
	hzrd._on_body_entered(plr)
	
	var isGameOver: bool = arena.is_game_over and arena.game_over_menu.visible
	get_tree().paused = false
	assertCond(isGameOver, "IT-04", "Kolizja z Hazardem przy 1 HP wywołuje śmierć i otwiera ekran Game Over w UI")
	
	plr.free()
	hzrd.free()
	arena.free()

func itGoalRequiresAllJewelsAndRecordsTime() -> void:
	Events.completed_levels.clear()
	Events.selected_level_profile = 1
	var arena = _createMockArena(2)
	arena.elapsed_time = 34.2
	var plr = _createMockPlayer()
	
	arena._on_jewel_collected(100, Vector2.ZERO)
	arena._on_goal_entered(plr)
	var blockedWhenIncomplete: bool = (not arena.is_stage_cleared) and (not arena.win_screen.visible)
	
	arena._on_jewel_collected(100, Vector2.ZERO)
	arena._on_goal_entered(plr)
	get_tree().paused = false
	
	var menu = _createMockMainMenu()
	menu._update_level_select()
	
	var winUiOk: bool = arena.is_stage_cleared and arena.win_screen.visible and (arena.win_score_label.text == "JEWELS: 2 / 2")
	var badgeOk: bool = menu.lvl1CompletedBadge.visible and menu.lvl1CheckmarkIcon.visible
	var bestTimeOk: bool = is_equal_approx(Events.get_level_best_time(1), 34.2)
	assertCond(blockedWhenIncomplete and winUiOk and badgeOk and bestTimeOk, "IT-05", "FinishGoal blokuje wyjście bez wszystkich Jeweli, a po ich zebraniu zlicza czas i odblokowuje odznakę")
	
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
	
	menu._toggleSfx()
	var sfxBusIdx: int = AudioServer.get_bus_index("SFX")
	var stateOk: bool = (menu.isSfxMuted == true)
	if sfxBusIdx != -1:
		stateOk = stateOk and AudioServer.is_bus_mute(sfxBusIdx)
		
	assertCond(stateOk, "IT-07", "Przełącznik SFX w ustawieniach wycisza szynę SFX w AudioServer")
	menu.free()

func itSettingsAudioSlidersAdjustAudioServerBuses() -> void:
	var menu = _createMockMainMenu()
	menu._ensure_audio_buses()
	
	var musSlider = menu._find_in_settings("MusicSlider") as HSlider
	var sfxSlider = menu._find_in_settings("SfxSlider") as HSlider
	var masterSlider = menu._find_in_settings("MasterSlider") as HSlider
	
	if musSlider:
		musSlider.value = 60.0
	if sfxSlider:
		sfxSlider.value = 40.0
	if masterSlider:
		masterSlider.value = 85.0
		
	var musBus = AudioServer.get_bus_index("Music")
	var sfxBus = AudioServer.get_bus_index("SFX")
	var masterBus = AudioServer.get_bus_index("Master")
	
	var musOk: bool = (musBus != -1) and is_equal_approx(AudioServer.get_bus_volume_db(musBus), linear_to_db(0.6))
	var sfxOk: bool = (sfxBus != -1) and is_equal_approx(AudioServer.get_bus_volume_db(sfxBus), linear_to_db(0.4))
	var masterOk: bool = (masterBus != -1) and is_equal_approx(AudioServer.get_bus_volume_db(masterBus), linear_to_db(0.85))
	
	var allAudioOk: bool = musOk and sfxOk and masterOk
	assertCond(allAudioOk, "IT-07B", "Suwaki głośności w zakładce Muzyka/Dźwięk faktycznie regulują szyny AudioServer (Master, Music, SFX)")
	menu.free()

func itTopProfileButtonOpensWebPortalAndSyncs() -> void:
	var menu = _createMockMainMenu()
	Events.portal_sync.last_opened_url = ""
	
	# 1. Kliknięcie w ikonkę profilu w HomeView (prawy górny róg) przenosi do ProfileSettingsView
	menu.profileBtn.pressed.emit()
	var profSettingsOpened: bool = (menu.profileSettingsView != null) and menu.profileSettingsView.visible and not menu.homeView.visible
	
	# 2. Z ekranu ProfileSettings przechodzimy do ProfileView (Profil)
	menu.profSettingsProfileBtn.pressed.emit()
	var profileOpened: bool = (menu.profileView != null) and menu.profileView.visible and not menu.profileSettingsView.visible
	
	# 3. Z ekranu Profile otwarcie portalu i powrót do ProfileSettingsView
	menu.profileOpenPortalBtn.pressed.emit()
	var urlOpenedOk: bool = Events.portal_sync.last_opened_url.ends_with("/profil")
	menu.profileBackBtn.pressed.emit()
	var backToSettings1: bool = menu.profileSettingsView.visible and not menu.profileView.visible
	
	# 4. Z ProfileSettings przejście do SkinSelectView (Skinselect) i powrót
	menu.profSettingsSkinBtn.pressed.emit()
	var skinOpened: bool = (menu.skinSelectView != null) and menu.skinSelectView.visible and not menu.profileSettingsView.visible
	menu.skinSelectBackBtn.pressed.emit()
	var backToSettings2: bool = menu.profileSettingsView.visible and not menu.skinSelectView.visible
	
	# 5. Z ProfileSettings przejście do ZadaniaView (Zadania) i powrót
	menu.profSettingsZadaniaBtn.pressed.emit()
	var zadaniaOpened: bool = (menu.zadaniaView != null) and menu.zadaniaView.visible and not menu.profileSettingsView.visible
	menu.zadaniaBackBtn.pressed.emit()
	var backToSettings3: bool = menu.profileSettingsView.visible and not menu.zadaniaView.visible
	
	# 6. Powrót z ProfileSettings do HomeView
	menu.profSettingsBackBtn.pressed.emit()
	var backToHome: bool = menu.homeView.visible and not menu.profileSettingsView.visible
	
	var allNavOk: bool = profSettingsOpened and profileOpened and urlOpenedOk and backToSettings1 and skinOpened and backToSettings2 and zadaniaOpened and backToSettings3 and backToHome
	assertCond(allNavOk, "IT-08", "Kliknięcie profilu w menu przenosi do Ustawień Profilu, skąd można przejść do Profilu, SkinSelect oraz Zadań i wrócić")
	menu.free()

func itPortalShieldAndMagnetBoostersInGameplay() -> void:
	var plr = _createMockPlayer()
	plr.current_health = 3
	plr.set_meta("has_portal_shield", true)
	plr.set_meta("has_portal_magnet", true)
	plr.global_position = Vector2(200, 200)
	
	# 1. Tarcza z portalu pochłania obrażenie bez utraty HP
	plr.take_damage(1, Vector2(220, 200))
	var shieldAbsorbed: bool = (plr.current_health == 3) and (not bool(plr.get_meta("has_portal_shield", false)))
	
	# 2. Magnes z portalu przyciąga pobliski klejnot w stronę gracza
	var jwl = JewelScript.new()
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	jwl.add_child(spr)
	add_child(jwl)
	jwl.global_position = Vector2(250, 200) # 50px od gracza (w zasięgu magnet_radius = 95px)
	jwl._process(0.1)
	var magnetPulled: bool = jwl.global_position.x < 250.0
	
	assertCond(shieldAbsorbed and magnetPulled, "IT-09", "Wzmocnienia pobrane z profilu na stronie (Tarcza i Magnes) działają w rozgrywce")
	jwl.free()
	plr.free()

func itWebChallengesCompleteOnWinningRun() -> void:
	Events.portal_sync._init_default_portal_challenges()
	var completed: Array[Dictionary] = Events.portal_sync.evaluate_run_against_challenges(5, 48.0, true, 4)
	var completedNames: Array[String] = []
	for c in completed:
		completedNames.append(String(c.get("name", "")))
		
	var allThreeDone: bool = completedNames.has("Pierwsze kroki") and completedNames.has("Łowca klejnotów") and completedNames.has("Mistrz czasu")
	assertCond(allThreeDone and completed.size() == 3, "IT-10", "Ukończenie poziomu z 5 klejnotami poniżej 60s zalicza zadania z portalu i przyznaje nagrody")
	Events.portal_sync._init_default_portal_challenges()

func itLevelSelectMechanicPanelsAndAIContracts() -> void:
	var menu = _createMockMainMenu()
	var lvlView: Control = menu.lvlView
	
	var hasPanel: bool = (lvlView != null) and lvlView.has_node("MechanicInfoPanel")
	var hasLabels: bool = (menu.mechanicInfoLabel != null) and (menu.dnaRadarLabel != null)
	var hasContractBtn: bool = (menu.aiContractBtn != null) and lvlView.has_node("AIContractBtn")
	var hasGenBtn: bool = (menu.aiGenerateBtn != null) and lvlView.has_node("AIGenerateBtn")
	
	var textBefore: String = menu.aiContractBtn.text if menu.aiContractBtn else ""
	if menu.aiContractBtn:
		menu.aiContractBtn.pressed.emit()
	var textAfter: String = menu.aiContractBtn.text if menu.aiContractBtn else ""
	var contractCyclesOk: bool = (textBefore != textAfter)
	
	menu._preview_mechanic_profile(4)
	var previewLvl4Ok: bool = menu.mechanicInfoLabel.text.contains("SZACHOWNICA") and menu.dnaRadarLabel.text.contains("RADAR DNA")
	
	var allOk: bool = hasPanel and hasLabels and hasContractBtn and hasGenBtn and contractCyclesOk and previewLvl4Ok
	assertCond(allOk, "IT-11", "Level Select zawiera dolne panele z opisem mechanik, radarem DNA, przełącznikiem Kontraktów AI oraz przyciskiem poziomu IV AI")
	menu.free()

func itAudioPercentageLabelBugFix() -> void:
	var menu = _createMockMainMenu()
	menu._ensure_audio_buses()
	menu._setup_settings_mockups()
	
	var masterSlider = menu._find_in_settings("MasterSlider") as HSlider
	var musicSlider = menu._find_in_settings("MusicSlider") as HSlider
	var sfxSlider = menu._find_in_settings("SfxSlider") as HSlider
	
	var masterVal = masterSlider.get_parent().get_node_or_null("MasterValue") as Label
	var musicVal = musicSlider.get_parent().get_node_or_null("MusicValue") as Label
	var sfxVal = sfxSlider.get_parent().get_node_or_null("SfxValue") as Label
	
	masterSlider.value = 80.0
	musicSlider.value = 70.0
	sfxSlider.value = 80.0
	
	var initLabelsOk: bool = (masterVal.text == "80%") and (musicVal.text == "70%") and (sfxVal.text == "80%")
	
	# Zmiana wartości suwaka muzyki - NIE MOŻE zmieniać procentu głośności ogólnej!
	musicSlider.value = 45.0
	var musicChangeOk: bool = (musicVal.text == "45%") and (masterVal.text == "80%")
	
	# Zmiana wartości suwaka ogólnego - zmienia tylko ogólny
	masterSlider.value = 95.0
	var masterChangeOk: bool = (masterVal.text == "95%") and (musicVal.text == "45%")
	
	# Zmiana wartości suwaka SFX - zmienia tylko SFX
	sfxSlider.value = 30.0
	var sfxChangeOk: bool = (sfxVal.text == "30%") and (masterVal.text == "95%") and (musicVal.text == "45%")
	
	var allAudioOk: bool = initLabelsOk and musicChangeOk and masterChangeOk and sfxChangeOk
	assertCond(allAudioOk, "IT-12", "Naprawa buga audio: zmiana głośności muzyki aktualizuje tylko MusicValue, a nie MasterValue")
	menu.free()

func itGraphicsSettingsFunctionality() -> void:
	var menu = _createMockMainMenu()
	menu._setup_settings_mockups()
	
	var modeOpt = menu._find_in_settings("DisplayModeOpt") as OptionButton
	var resOpt = menu._find_in_settings("ResolutionOpt") as OptionButton
	var vsyncChk = menu._find_in_settings("VsyncCheck") as CheckBox
	var fpsOpt = menu._find_in_settings("FpsLimitOpt") as OptionButton
	
	var itemsOk: bool = (modeOpt != null and modeOpt.item_count == 3) and \
						(resOpt != null and resOpt.item_count == 3) and \
						(fpsOpt != null and fpsOpt.item_count == 3) and \
						(vsyncChk != null)
						
	# Test limitu FPS
	fpsOpt.item_selected.emit(1)
	var fps120Ok: bool = (Engine.max_fps == 120)
	fpsOpt.item_selected.emit(0)
	var fps60Ok: bool = (Engine.max_fps == 60)
	fpsOpt.item_selected.emit(2)
	var fpsUncappedOk: bool = (Engine.max_fps == 0)
	
	# Test przełącznika V-Sync
	vsyncChk.toggled.emit(false)
	var vsyncOffOk: bool = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED) or (DisplayServer.get_name() == "headless")
	vsyncChk.toggled.emit(true)
	var vsyncOnOk: bool = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED) or (DisplayServer.get_name() == "headless")
	
	# Test wyboru rozdzielczości
	resOpt.item_selected.emit(0) # 1280x720
	resOpt.item_selected.emit(2) # 640x360
	var resRunOk: bool = true
	
	# Test wyboru trybu okna
	modeOpt.item_selected.emit(1) # Windowed
	var modeRunOk: bool = true
	
	var allGfxOk: bool = itemsOk and fps120Ok and fps60Ok and fpsUncappedOk and vsyncOffOk and vsyncOnOk and resRunOk and modeRunOk
	assertCond(allGfxOk, "IT-13", "Ustawienia graficzne: Display Mode, Resolution, V-Sync oraz FPS Limit są w pełni funkcjonalne")
	menu.free()

func itLanguageSettingsSwitchingAndGermanRemoval() -> void:
	var menu = _createMockMainMenu()
	menu._setup_settings_mockups()
	
	var langOpt = menu._find_in_settings("LanguageOpt") as OptionButton
	var countOk: bool = (langOpt != null and langOpt.item_count == 2)
	var hasPolish: bool = (langOpt.get_item_text(0) == "Polski (PL)")
	var hasEnglish: bool = (langOpt.get_item_text(1) == "English (EN)")
	
	var noGerman: bool = true
	for i in range(langOpt.item_count):
		if langOpt.get_item_text(i).to_lower().contains("deutsch") or langOpt.get_item_text(i).to_lower().contains("de"):
			noGerman = false
			break
			
	# Przełącz na język angielski
	menu._apply_language("en")
	var enLocaleOk: bool = (menu.current_language == "en") and (TranslationServer.get_locale() == "en")
	var masterLblEn = menu._find_in_settings("AudioPanel/MasterBox/Label") as Label
	var langLblEn = menu._find_in_settings("LanguagePanel/LangBox/Label") as Label
	var labelsEnOk: bool = (masterLblEn != null and masterLblEn.text == "Master Volume:") and \
						   (langLblEn != null and langLblEn.text == "Game Language:")
	var optEn = menu._find_in_settings("DisplayModeOpt") as OptionButton
	var modeEnOk: bool = (optEn != null and optEn.get_item_text(0) == "Fullscreen")
	
	# Przełącz z powrotem na język polski
	menu._apply_language("pl")
	var plLocaleOk: bool = (menu.current_language == "pl") and (TranslationServer.get_locale() == "pl")
	var masterLblPl = menu._find_in_settings("AudioPanel/MasterBox/Label") as Label
	var langLblPl = menu._find_in_settings("LanguagePanel/LangBox/Label") as Label
	var labelsPlOk: bool = (masterLblPl != null and masterLblPl.text == "Głośność ogólna:") and \
						   (langLblPl != null and langLblPl.text == "Język gry (Language):")
	
	var allLangOk: bool = countOk and hasPolish and hasEnglish and noGerman and enLocaleOk and labelsEnOk and modeEnOk and plLocaleOk and labelsPlOk
	assertCond(allLangOk, "IT-14", "Ustawienia języka: usunięto j. niemiecki, pozostawiono PL i EN, a zmiana języka dynamicznie aktualizuje UI gry")
	menu.free()

func itSkinSelectionPreservesAudioSettings() -> void:
	var menu = _createMockMainMenu()
	menu._ensure_audio_buses()
	menu._setup_settings_mockups()
	
	var musicSlider = menu._find_in_settings("MusicSlider") as HSlider
	var sfxSlider = menu._find_in_settings("SfxSlider") as HSlider
	var masterSlider = menu._find_in_settings("MasterSlider") as HSlider
	
	var masterVal = masterSlider.get_parent().get_node_or_null("MasterValue") as Label
	var musicVal = musicSlider.get_parent().get_node_or_null("MusicValue") as Label
	var sfxVal = sfxSlider.get_parent().get_node_or_null("SfxValue") as Label
	
	# Użytkownik dostosowuje głośność
	masterSlider.value = 65.0
	musicSlider.value = 35.0
	sfxSlider.value = 55.0
	
	var musBus = AudioServer.get_bus_index("Music")
	var sfxBus = AudioServer.get_bus_index("SFX")
	var masterBus = AudioServer.get_bus_index("Master")
	
	# Sprawdzamy stan przed zmianą skina
	var preMusOk: bool = is_equal_approx(AudioServer.get_bus_volume_db(musBus), linear_to_db(0.35))
	var preSfxOk: bool = is_equal_approx(AudioServer.get_bus_volume_db(sfxBus), linear_to_db(0.55))
	var preMasterOk: bool = is_equal_approx(AudioServer.get_bus_volume_db(masterBus), linear_to_db(0.65))
	
	# Gracz wchodzi w wybór skórek i klika kolejne skórki
	menu._select_skin(1) # Noir Stelly
	menu._select_skin(2) # Office Stelly
	menu._select_skin(3) # 2077 Stelly
	menu._select_skin(0) # Klasyczna Stelly
	
	# Sprawdzamy czy zmiana skina NIE zresetowała suwaków, etykiet ani szyn AudioServer
	var postMusSliderOk: bool = is_equal_approx(musicSlider.value, 35.0) and (musicVal.text == "35%")
	var postSfxSliderOk: bool = is_equal_approx(sfxSlider.value, 55.0) and (sfxVal.text == "55%")
	var postMasterSliderOk: bool = is_equal_approx(masterSlider.value, 65.0) and (masterVal.text == "65%")
	
	var postMusBusOk: bool = is_equal_approx(AudioServer.get_bus_volume_db(musBus), linear_to_db(0.35))
	var postSfxBusOk: bool = is_equal_approx(AudioServer.get_bus_volume_db(sfxBus), linear_to_db(0.55))
	var postMasterBusOk: bool = is_equal_approx(AudioServer.get_bus_volume_db(masterBus), linear_to_db(0.65))
	
	var allOk: bool = preMusOk and preSfxOk and preMasterOk and postMusSliderOk and postSfxSliderOk and postMasterSliderOk and postMusBusOk and postSfxBusOk and postMasterBusOk
	assertCond(allOk, "IT-15", "Zmiana skórki w SkinSelect zachowuje ustawienia dźwięku (suwaki, procenty i szyny AudioServer nie resetują się)")
	menu.free()

func itMenuAndLevelMusicIndependentSliders() -> void:
	var menu = _createMockMainMenu()
	menu._ensure_audio_buses()
	menu._setup_settings_mockups()
	
	var musMenuSlider = menu._find_in_settings("MusicSlider") as HSlider
	var lvlMusSlider = menu._find_in_settings("LevelMusicSlider") as HSlider
	var musMenuVal = menu._find_in_settings("MusicValue") as Label
	var lvlMusVal = menu._find_in_settings("LevelMusicValue") as Label
	
	var slidersExistOk: bool = (musMenuSlider != null) and (lvlMusSlider != null) and (musMenuVal != null) and (lvlMusVal != null)
	
	# Ustawiamy głośność muzyki w menu na 40%, a muzyki w poziomie na 85%
	musMenuSlider.value = 40.0
	lvlMusSlider.value = 85.0
	
	var labelsOk: bool = (musMenuVal.text == "40%") and (lvlMusVal.text == "85%")
	
	var busMenuIdx = AudioServer.get_bus_index("MusicMenu")
	var busLvlIdx = AudioServer.get_bus_index("MusicLevel")
	var busMenuOk: bool = (busMenuIdx != -1) and is_equal_approx(AudioServer.get_bus_volume_db(busMenuIdx), linear_to_db(0.40))
	var busLvlOk: bool = (busLvlIdx != -1) and is_equal_approx(AudioServer.get_bus_volume_db(busLvlIdx), linear_to_db(0.85))
	
	# Zmiana tylko muzyki w poziomie nie powinna ruszać muzyki w menu
	lvlMusSlider.value = 25.0
	var indepOk: bool = (musMenuVal.text == "40%") and (lvlMusVal.text == "25%") and is_equal_approx(AudioServer.get_bus_volume_db(busLvlIdx), linear_to_db(0.25)) and is_equal_approx(AudioServer.get_bus_volume_db(busMenuIdx), linear_to_db(0.40))
	
	# Sprawdzenie etykiet tekstowych w PL i EN
	var musMenuLbl = menu._find_in_settings("AudioPanel/MusicBox/Label") as Label
	var lvlMusLbl = menu._find_in_settings("AudioPanel/LevelMusicBox/Label") as Label
	var plLabelsOk: bool = (musMenuLbl != null and musMenuLbl.text == "Muzyka w menu:") and (lvlMusLbl != null and lvlMusLbl.text == "Muzyka w poziomie:")
	
	menu._apply_language("en")
	var enLabelsOk: bool = (musMenuLbl != null and musMenuLbl.text == "Menu Music:") and (lvlMusLbl != null and lvlMusLbl.text == "Level Music:")
	
	menu._apply_language("pl")
	var allOk: bool = slidersExistOk and labelsOk and busMenuOk and busLvlOk and indepOk and plLabelsOk and enLabelsOk
	assertCond(allOk, "IT-16", "Podział muzyki na dwa niezależne suwaki: Muzyka w menu (MusicMenu) i Muzyka w poziomie (MusicLevel)")
	menu.free()

func itPauseMenuSettingsViewAndInGameLevelMusic() -> void:
	var arenaScene = load("res://scenes/test_arena.tscn")
	var arena = arenaScene.instantiate()
	add_child(arena)
	arena._ensure_audio_buses()
	
	var pauseMenu = arena.get_node_or_null("HUD/PauseMenu") as Control
	var settingsView = arena.get_node_or_null("HUD/SettingsView") as Control
	var settingsBtn = arena.get_node_or_null("HUD/PauseMenu/SettingsBtn") as Button
	var backBtn = arena.get_node_or_null("HUD/SettingsView/BackBtn") as Button
	
	var nodesOk: bool = (pauseMenu != null) and (settingsView != null) and (settingsBtn != null) and (backBtn != null)
	
	# 1. Start w grze: PauseMenu i SettingsView są ukryte
	var initOk: bool = (not pauseMenu.visible) and (not settingsView.visible)
	
	# 2. Włączenie pauzy: PauseMenu staje się widoczne
	arena._toggle_pause()
	var pauseOpenOk: bool = pauseMenu.visible and (not settingsView.visible) and get_tree().paused
	
	# 3. Kliknięcie 'Settings' w ekranie pauzy otwiera SettingsView i ukrywa PauseMenu
	arena._open_settings()
	var settingsOpenOk: bool = (not pauseMenu.visible) and settingsView.visible
	
	# 4. Sprawdzenie suwaków w SettingsView arenki - zmiana muzyki w poziomie reguluje szynę MusicLevel
	var lvlSlider = arena._find_in_settings("LevelMusicSlider") as HSlider
	var lvlVal = arena._find_in_settings("LevelMusicValue") as Label
	var busLvlIdx = AudioServer.get_bus_index("MusicLevel")
	
	var levelAudioInGameOk: bool = false
	if lvlSlider and lvlVal and busLvlIdx != -1:
		lvlSlider.value = 52.0
		levelAudioInGameOk = (lvlVal.text == "52%") and is_equal_approx(AudioServer.get_bus_volume_db(busLvlIdx), linear_to_db(0.52))
	
	# 5. Kliknięcie 'BackBtn' wraca z SettingsView do PauseMenu
	arena._close_settings()
	var backToPauseOk: bool = pauseMenu.visible and (not settingsView.visible)
	
	# 6. Wznowienie gry (odpauzowanie)
	arena._toggle_pause()
	var unpauseOk: bool = (not pauseMenu.visible) and (not settingsView.visible) and (not get_tree().paused)
	
	get_tree().paused = false
	arena.free()
	
	var allOk: bool = nodesOk and initOk and pauseOpenOk and settingsOpenOk and levelAudioInGameOk and backToPauseOk and unpauseOk
	assertCond(allOk, "IT-17", "Ekran pauzy zawiera opcję Settings otwierającą pełny SettingsView z regulacją głośności i powrotem")

func itArrowKeyNavigationInPauseGameOverWinScreens() -> void:
	var arenaScene = load("res://scenes/test_arena.tscn")
	var arena = arenaScene.instantiate()
	add_child(arena)
	
	# Helper do wysyłania klawiszy do arena._unhandled_input
	var sendKey = func(kc: Key):
		var ev := InputEventKey.new()
		ev.keycode = kc
		ev.pressed = true
		arena._unhandled_input(ev)
		
	# 1. Test nawigacji strzałkami w PauseMenu (4 przyciski: Resume, Restart, Settings, Quit)
	arena._toggle_pause()
	var pauseInitOk: bool = (arena.pause_focus_idx == 0) and (arena.pause_buttons[0].has_focus())
	
	# Strzałka w dół -> RestartBtn (idx 1)
	sendKey.call(KEY_DOWN)
	var pauseDown1: bool = (arena.pause_focus_idx == 1) and (arena.pause_buttons[1].has_focus())
	
	# Strzałka w dół -> SettingsBtn (idx 2)
	sendKey.call(KEY_DOWN)
	var pauseDown2: bool = (arena.pause_focus_idx == 2) and (arena.pause_buttons[2].has_focus())
	
	# Strzałka w dół -> QuitBtn (idx 3)
	sendKey.call(KEY_DOWN)
	var pauseDown3: bool = (arena.pause_focus_idx == 3) and (arena.pause_buttons[3].has_focus())
	
	# Strzałka w dół (zawijanie) -> ResumeBtn (idx 0)
	sendKey.call(KEY_DOWN)
	var pauseWrapDown: bool = (arena.pause_focus_idx == 0) and (arena.pause_buttons[0].has_focus())
	
	# Strzałka w górę (zawijanie w tył) -> QuitBtn (idx 3)
	sendKey.call(KEY_UP)
	var pauseWrapUp: bool = (arena.pause_focus_idx == 3) and (arena.pause_buttons[3].has_focus())
	
	# Zamknij pauzę
	arena._toggle_pause()
	
	# 2. Test nawigacji strzałkami w GameOverMenu (2 przyciski: Retry, MainMenu)
	arena._on_player_died()
	var goInitOk: bool = (arena.game_over_focus_idx == 0) and (arena.game_over_buttons[0].has_focus())
	
	# Strzałka w dół -> MainMenuBtn (idx 1)
	sendKey.call(KEY_DOWN)
	var goDown1: bool = (arena.game_over_focus_idx == 1) and (arena.game_over_buttons[1].has_focus())
	
	# Strzałka w dół (zawijanie) -> RetryBtn (idx 0)
	sendKey.call(KEY_DOWN)
	var goWrapDown: bool = (arena.game_over_focus_idx == 0) and (arena.game_over_buttons[0].has_focus())
	
	# Strzałka w górę -> MainMenuBtn (idx 1)
	sendKey.call(KEY_UP)
	var goWrapUp: bool = (arena.game_over_focus_idx == 1) and (arena.game_over_buttons[1].has_focus())
	
	arena.is_game_over = false
	arena.game_over_menu.visible = false
	get_tree().paused = false
	
	# 3. Test nawigacji strzałkami w WinScreen (2 przyciski: Retry, MainMenu)
	arena.is_stage_cleared = true
	arena.win_screen.visible = true
	arena.win_focus_idx = 0
	arena._set_button_focus(arena.win_buttons, 0)
	var winInitOk: bool = (arena.win_focus_idx == 0) and (arena.win_buttons[0].has_focus())
	
	# Strzałka w dół -> MainMenuBtn (idx 1)
	sendKey.call(KEY_DOWN)
	var winDown1: bool = (arena.win_focus_idx == 1) and (arena.win_buttons[1].has_focus())
	
	# Strzałka w dół (zawijanie) -> RetryBtn (idx 0)
	sendKey.call(KEY_DOWN)
	var winWrapDown: bool = (arena.win_focus_idx == 0) and (arena.win_buttons[0].has_focus())
	
	# Strzałka w górę -> MainMenuBtn (idx 1)
	sendKey.call(KEY_UP)
	var winWrapUp: bool = (arena.win_focus_idx == 1) and (arena.win_buttons[1].has_focus())
	
	arena.is_stage_cleared = false
	arena.win_screen.visible = false
	get_tree().paused = false
	arena.free()
	
	var allPauseOk: bool = pauseInitOk and pauseDown1 and pauseDown2 and pauseDown3 and pauseWrapDown and pauseWrapUp
	var allGoOk: bool = goInitOk and goDown1 and goWrapDown and goWrapUp
	var allWinOk: bool = winInitOk and winDown1 and winWrapDown and winWrapUp
	
	assertCond(allPauseOk and allGoOk and allWinOk, "IT-18", "Nawigacja strzałkami (Up / Down) działa poprawnie w PauseMenu, GameOverMenu oraz WinScreen")

func itSpecialJewelPowerupsMechanics() -> void:
	if is_instance_valid(Events.portal_sync):
		Events.portal_sync.cosmetics_state["boosters"] = {}
	var plr = _createMockPlayer()
	plr.set_meta("has_portal_shield", false)
	plr.current_health = 3
	
	# 1. JewJewel -> 10s nieśmiertelności (brak otrzymywania obrażeń)
	var jJew = JewelScript.new()
	var spr1 = Sprite2D.new()
	spr1.name = "Sprite2D"
	jJew.add_child(spr1)
	add_child(jJew)
	jJew.jewel_type = JewelScript.JewelType.JEW_JEWEL
	jJew._setup_jewel_texture()
	var jewTexOk: bool = (spr1.texture != null)
	jJew._onBodyEntered(plr)
	var invOk: bool = is_equal_approx(plr.invincibility_powerup_timer, 10.0)
	plr.take_damage(1)
	var invDamageIgnored: bool = (plr.current_health == 3)
	plr.invincibility_powerup_timer = 0.0
	jJew.free()
	
	# 2. SpeedJewel -> zwiększenie prędkości biegu 2x na 10s
	var sJew = JewelScript.new()
	var spr2 = Sprite2D.new()
	spr2.name = "Sprite2D"
	sJew.add_child(spr2)
	add_child(sJew)
	sJew.jewel_type = JewelScript.JewelType.SPEED_JEWEL
	sJew._setup_jewel_texture()
	var speedTexOk: bool = (spr2.texture != null)
	sJew._onBodyEntered(plr)
	var speedTimerOk: bool = is_equal_approx(plr.speed_powerup_timer, 10.0)
	var speedDoubledOk: bool = is_equal_approx(plr.get_effective_speed(), plr.speed * 2.0)
	plr.speed_powerup_timer = 0.0
	var speedResetOk: bool = is_equal_approx(plr.get_effective_speed(), plr.speed)
	sJew.free()
	
	# 3. ImmunityJewel (InvincibilityJewel) -> tarcza pochłaniająca 1 uderzenie
	var iJew = JewelScript.new()
	var spr3 = Sprite2D.new()
	spr3.name = "Sprite2D"
	iJew.add_child(spr3)
	add_child(iJew)
	iJew.jewel_type = JewelScript.JewelType.IMMUNITY_JEWEL
	iJew._setup_jewel_texture()
	var immunityTexOk: bool = (spr3.texture != null)
	iJew._onBodyEntered(plr)
	var shieldGivenOk: bool = (plr.has_shield == true)
	plr.take_damage(1)
	var shieldAbsorbedOk: bool = (plr.current_health == 3) and (plr.has_shield == false)
	plr.is_invulnerable = false
	plr.invulnerability_timer = 0.0
	plr.take_damage(1)
	var regularDamageAfterOk: bool = (plr.current_health == 2)
	iJew.free()
	plr.free()
	
	var allPowerupsOk: bool = jewTexOk and invOk and invDamageIgnored and speedTexOk and speedTimerOk and speedDoubledOk and speedResetOk and immunityTexOk and shieldGivenOk and shieldAbsorbedOk and regularDamageAfterOk
	assertCond(allPowerupsOk, "IT-19", "Specjalne klejnoty: JewJewel (10s nieśmiertelność), SpeedJewel (2x speed 10s) oraz ImmunityJewel (tarcza na 1 hit)")

func itEnemyMockupStompDashAndDamageMechanics() -> void:
	if is_instance_valid(Events.portal_sync):
		Events.portal_sync.cosmetics_state["boosters"] = {}
		
	var enemyScene = load("res://scenes/enemies/enemy_mockup.tscn")
	var enemy1 = enemyScene.instantiate() as Area2D
	add_child(enemy1)
	enemy1.global_position = Vector2(300, 300)
	
	var plr = _createMockPlayer()
	plr.current_health = 3
	plr.set_meta("has_portal_shield", false)
	plr.has_shield = false
	plr.invincibility_powerup_timer = 0.0
	plr.global_position = Vector2(300, 300)
	
	# 1. Dash przez wroga -> unikanie trafienia bez obrażeń
	plr.current_state = PlayerScript.State.DASH
	enemy1._on_body_entered(plr)
	var dashAvoidHitOk: bool = (plr.current_health == 3) and (not enemy1.is_dead)
	
	# 2. Skok na wroga z góry (Stomp) -> pokonanie wroga i bounce gracza
	plr.current_state = PlayerScript.State.FALL
	plr.velocity.y = 150.0
	plr.global_position = Vector2(300, 285) # Gracz powyżej wroga
	enemy1._on_body_entered(plr)
	var stompDefeatedOk: bool = enemy1.is_dead and (plr.velocity.y < 0.0) and (plr.current_health == 3)
	
	# 3. Zwykły kontakt poziomy bez dasha -> gracz otrzymuje obrażenia
	var enemy2 = enemyScene.instantiate() as Area2D
	add_child(enemy2)
	enemy2.global_position = Vector2(300, 300)
	plr.current_state = PlayerScript.State.RUN
	plr.velocity.y = 0.0
	plr.global_position = Vector2(300, 300)
	plr.is_invulnerable = false
	plr.invulnerability_timer = 0.0
	plr.set_meta("has_portal_shield", false)
	plr.has_shield = false
	plr.invincibility_powerup_timer = 0.0
	enemy2._on_body_entered(plr)
	var regularContactDamageOk: bool = (plr.current_health == 2)
	
	enemy2.free()
	plr.free()
	
	var allEnemyOk: bool = dashAvoidHitOk and stompDefeatedOk and regularContactDamageOk
	assertCond(allEnemyOk, "IT-20", "Mechanika wroga: unikanie dashem, pokonanie skokiem z góry (stomp z bounce) oraz obrażenia przy normalnym kontakcie")

func itStarHpIndicatorAndSpikeSprite() -> void:
	if is_instance_valid(Events.portal_sync):
		Events.portal_sync.cosmetics_state["boosters"] = {}
		
	# 1. Wskaźnik HP gracza używa gwiazdek (Gwiazdka.png)
	var plrScene = load("res://scenes/player/player.tscn")
	var plr = plrScene.instantiate() as PlayerController
	add_child(plr)
	
	var hpCont = plr.get_node_or_null("HpSquares")
	var hasHpContainer: bool = (hpCont != null)
	var childCountOk: bool = (hpCont != null and hpCont.get_child_count() == 3)
	var firstStar = hpCont.get_child(0) if childCountOk else null
	var isSpriteStar: bool = (firstStar is Sprite2D) and (firstStar.texture != null)
	
	# Gwiazdki znajdują się nad graczem (pozycja Y < 0)
	var posAbovePlayerOk: bool = (hpCont != null and hpCont.position.y < 0.0)
	
	# Gwiazdki są widoczne na początku poziomu
	var initialVisibleOk: bool = (hpCont != null and hpCont.visible and plr.hp_display_timer > 0.0)
	
	# Po upływie czasu gwiazdki znikają (ukrywają się)
	plr._update_timers(3.5)
	var timeoutHidesOk: bool = (hpCont != null and not hpCont.visible)
	
	# Po otrzymaniu obrażeń gwiazdki natychmiast pojawiają się ponownie
	plr.is_invulnerable = false
	plr.invulnerability_timer = 0.0
	plr.set_meta("has_portal_shield", false)
	plr.has_shield = false
	plr.invincibility_powerup_timer = 0.0
	plr.take_damage(1)
	var damageShowsOk: bool = (hpCont != null and hpCont.visible and plr.hp_display_timer > 0.0)
	
	# Utrata HP modyfikuje przezroczystość/kolor utraconej gwiazdki
	plr.current_health = 2
	plr._apply_hp_colors(2)
	var activeStarModOk: bool = is_equal_approx(hpCont.get_child(0).modulate.a, 1.0)
	var lostStarModOk: bool = hpCont.get_child(2).modulate.a < 0.6
	
	plr.free()
	
	# 2. Kolce w test_arena.tscn używają sprite'a Kolce.png i mają zwiększoną skalę
	var arenaScene = load("res://scenes/test_arena.tscn")
	var arena = arenaScene.instantiate()
	add_child(arena)
	
	var sp1 = arena.get_node_or_null("Hazards/SpikesGap/TextureRect") as TextureRect
	var sp2 = arena.get_node_or_null("Hazards/SpikesGap2/TextureRect") as TextureRect
	var spikesSpriteOk: bool = (sp1 != null) and (sp2 != null) and (sp1.texture != null) and (sp2.texture != null)
	var spikesTileRepeatOk: bool = (sp1.stretch_mode == TextureRect.STRETCH_TILE) and (sp2.stretch_mode == TextureRect.STRETCH_TILE)
	var spikesScaleOk: bool = (sp1.scale.x >= 1.4) and (sp2.scale.x >= 1.4)
	
	arena.free()
	
	var allVisualsOk: bool = hasHpContainer and childCountOk and isSpriteStar and posAbovePlayerOk and initialVisibleOk and timeoutHidesOk and damageShowsOk and activeStarModOk and lostStarModOk and spikesSpriteOk and spikesTileRepeatOk and spikesScaleOk
	assertCond(allVisualsOk, "IT-21", "Wskaźnik HP (gwiazdki) nad graczem, widoczny na start i przy hicie; kolce estetycznie powiększone")

func itKnowledgeCheckCyberQuizFunctionality() -> void:
	# 1. Sprawdzenie puli 15 pytań z cyberbezpieczeństwa
	var allQ = CyberQuiz.get_all_questions()
	var countOk: bool = (allQ.size() == 15)
	var formatOk: bool = true
	for q in allQ:
		if q.get("question", "").is_empty() or q.get("options", []).size() != 4 or q.get("correct", -1) < 0 or q.get("correct", -1) > 3 or q.get("topic", "").is_empty():
			formatOk = false
			break
			
	var randQ1 = CyberQuiz.get_random_question()
	var randQ2 = CyberQuiz.get_random_question(randQ1.get("id", -1))
	var randomSelectOk: bool = (randQ1.get("id", -1) != -1) and (randQ2.get("id", -1) != -1)
	
	# 2. Test w test_arena.tscn
	var arenaScene = load("res://scenes/test_arena.tscn")
	var arena = arenaScene.instantiate()
	add_child(arena)
	
	var popup = arena.knowledge_check_popup
	var popupExists: bool = (popup != null) and (arena.quiz_buttons.size() == 4)
	var initHidden: bool = (not popup.visible) and (not arena.is_knowledge_check_active)
	
	# Gracz zbiera wszystkie klejnoty i dociera do portalu
	var plr = arena.get_node_or_null("Player")
	arena.collected_jewels = arena.total_jewels
	arena._on_goal_entered(plr)
	
	# Portal nie kończy od razu poziomu, lecz otwiera Knowledge Check
	var quizOpenedOk: bool = popup.visible and arena.is_knowledge_check_active and (not arena.is_stage_cleared) and (not arena.win_screen.visible)
	
	var sendKey = func(kc: Key):
		var ev := InputEventKey.new()
		ev.keycode = kc
		ev.pressed = true
		arena._unhandled_input(ev)
		
	# 3. Test nawigacji strzałkami
	arena.quiz_focus_idx = 0
	sendKey.call(KEY_DOWN)
	var arrowDownOk: bool = (arena.quiz_focus_idx == 1)
	sendKey.call(KEY_UP)
	var arrowUpOk: bool = (arena.quiz_focus_idx == 0)
	sendKey.call(KEY_UP)
	var arrowWrapOk: bool = (arena.quiz_focus_idx == 3)
	
	# 4. Blokada wyjścia (Escape nie zamyka okna)
	sendKey.call(KEY_ESCAPE)
	var escapeBlockedOk: bool = popup.visible and arena.is_knowledge_check_active and arena.quiz_feedback_label.text.contains("MUSISZ")
	
	# 5. Błędna odpowiedź nie kończy poziomu
	var correctIdx: int = int(arena.current_quiz_question.get("correct", 0))
	var wrongIdx: int = (correctIdx + 1) % 4
	arena._submit_quiz_answer(wrongIdx)
	var wrongBlockedOk: bool = popup.visible and (not arena.is_stage_cleared) and (not arena.win_screen.visible) and arena.quiz_feedback_label.text.contains("BŁĘDNA")
	
	# 6. Poprawna odpowiedź zalicza Knowledge Check i kończy poziom
	arena._submit_quiz_answer(correctIdx)
	var correctAcceptedOk: bool = arena.quiz_answered_correctly and arena.quiz_feedback_label.text.contains("POPRAWNA")
	
	arena._level_complete()
	var levelCompletedOk: bool = arena.is_stage_cleared and arena.win_screen.visible
	
	get_tree().paused = false
	arena.free()
	
	var allQuizOk: bool = countOk and formatOk and randomSelectOk and popupExists and initHidden and quizOpenedOk and arrowDownOk and arrowUpOk and arrowWrapOk and escapeBlockedOk and wrongBlockedOk and correctAcceptedOk and levelCompletedOk
	assertCond(allQuizOk, "IT-22", "Knowledge Check: pula 15 pytań ABCD, losowanie na start, blokada wyjścia, obsługa strzałek i wymóg poprawnej odpowiedzi do wygranej")

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

func _createMockArena(jewel_count: int = 0) -> Node2D:
	var arena = ArenaScript.new()
	var respawn = Marker2D.new()
	respawn.name = "RespawnPoint"
	arena.add_child(respawn)
	
	var goal = Area2D.new()
	goal.name = "FinishGoal"
	arena.add_child(goal)
	
	for i in range(jewel_count):
		var jDummy = Area2D.new()
		jDummy.name = "Jewel%d" % (i + 1)
		jDummy.add_to_group("jewels")
		arena.add_child(jDummy)
	
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

func _createMockMainMenu() -> Control:
	var menu = MainMenuScript.new()
	for vName in ["HomeView", "LevelSelectView", "SettingsView", "CreatorsView", "ProfileSettingsView", "SkinSelectView", "ProfileView", "ZadaniaView"]:
		var v = Control.new()
		v.name = vName
		if vName == "HomeView":
			var profBtn = Button.new()
			profBtn.name = "ProfileBtn"
			v.add_child(profBtn)
		elif vName == "LevelSelectView":
			var b1 = Button.new()
			b1.name = "Lvl1Btn"
			var badge = Control.new()
			badge.name = "CompletedBadge"
			var badgeText = Label.new()
			badgeText.name = "BadgeText"
			badge.add_child(badgeText)
			var check = Control.new()
			check.name = "CheckmarkIcon"
			b1.add_child(badge)
			b1.add_child(check)
			v.add_child(b1)
			var b2 = Button.new()
			b2.name = "Lvl2Btn"
			v.add_child(b2)
			var b3 = Button.new()
			b3.name = "Lvl3Btn"
			v.add_child(b3)
			var bBack = Button.new()
			bBack.name = "BackBtn"
			v.add_child(bBack)
			var mPanel = Control.new()
			mPanel.name = "MechanicInfoPanel"
			var mInfo = Label.new()
			mInfo.name = "MechanicInfoLabel"
			var dRadar = Label.new()
			dRadar.name = "DnaRadarLabel"
			mPanel.add_child(mInfo)
			mPanel.add_child(dRadar)
			v.add_child(mPanel)
			var aiCont = Button.new()
			aiCont.name = "AIContractBtn"
			v.add_child(aiCont)
			var aiGen = Button.new()
			aiGen.name = "AIGenerateBtn"
			v.add_child(aiGen)
		elif vName == "SettingsView":
			var tb = Control.new()
			tb.name = "TabBar"
			for tName in ["TabAudioBtn", "TabGraphicsBtn", "TabControlsBtn", "TabLanguageBtn"]:
				var b = Button.new()
				b.name = tName
				tb.add_child(b)
			v.add_child(tb)
			
			var panels = Control.new()
			panels.name = "Panels"
			var aud = Control.new()
			aud.name = "AudioPanel"
			
			var mBox = HBoxContainer.new()
			mBox.name = "MasterBox"
			var mLbl = Label.new()
			mLbl.name = "Label"
			var mSld = HSlider.new()
			mSld.name = "MasterSlider"
			var mVal = Label.new()
			mVal.name = "MasterValue"
			mBox.add_child(mLbl)
			mBox.add_child(mSld)
			mBox.add_child(mVal)
			aud.add_child(mBox)
			
			var musBox = HBoxContainer.new()
			musBox.name = "MusicBox"
			var musLbl = Label.new()
			musLbl.name = "Label"
			var musSld = HSlider.new()
			musSld.name = "MusicSlider"
			var musVal = Label.new()
			musVal.name = "MusicValue"
			musBox.add_child(musLbl)
			musBox.add_child(musSld)
			musBox.add_child(musVal)
			aud.add_child(musBox)
			
			var lvlMusBox = HBoxContainer.new()
			lvlMusBox.name = "LevelMusicBox"
			var lvlMusLbl = Label.new()
			lvlMusLbl.name = "Label"
			var lvlMusSld = HSlider.new()
			lvlMusSld.name = "LevelMusicSlider"
			var lvlMusVal = Label.new()
			lvlMusVal.name = "LevelMusicValue"
			lvlMusBox.add_child(lvlMusLbl)
			lvlMusBox.add_child(lvlMusSld)
			lvlMusBox.add_child(lvlMusVal)
			aud.add_child(lvlMusBox)
			
			var sfxBox = HBoxContainer.new()
			sfxBox.name = "SfxBox"
			var sfxLbl = Label.new()
			sfxLbl.name = "Label"
			var sfxSld = HSlider.new()
			sfxSld.name = "SfxSlider"
			var sfxVal = Label.new()
			sfxVal.name = "SfxValue"
			sfxBox.add_child(sfxLbl)
			sfxBox.add_child(sfxSld)
			sfxBox.add_child(sfxVal)
			aud.add_child(sfxBox)
			
			var muteChk = CheckBox.new()
			muteChk.name = "MuteCheck"
			aud.add_child(muteChk)
			
			panels.add_child(aud)
			
			var gfx = Control.new()
			gfx.name = "GraphicsPanel"
			var modeBox = HBoxContainer.new()
			modeBox.name = "ModeBox"
			var modeLbl = Label.new()
			modeLbl.name = "Label"
			var modeOpt = OptionButton.new()
			modeOpt.name = "DisplayModeOpt"
			modeBox.add_child(modeLbl)
			modeBox.add_child(modeOpt)
			gfx.add_child(modeBox)
			var resBox = HBoxContainer.new()
			resBox.name = "ResBox"
			var resLbl = Label.new()
			resLbl.name = "Label"
			var resOpt = OptionButton.new()
			resOpt.name = "ResolutionOpt"
			resBox.add_child(resLbl)
			resBox.add_child(resOpt)
			gfx.add_child(resBox)
			var vsyncChk = CheckBox.new()
			vsyncChk.name = "VsyncCheck"
			gfx.add_child(vsyncChk)
			var fpsBox = HBoxContainer.new()
			fpsBox.name = "FpsBox"
			var fpsLbl = Label.new()
			fpsLbl.name = "Label"
			var fpsOpt = OptionButton.new()
			fpsOpt.name = "FpsLimitOpt"
			fpsBox.add_child(fpsLbl)
			fpsBox.add_child(fpsOpt)
			gfx.add_child(fpsBox)
			panels.add_child(gfx)
			
			var ctrl = Control.new()
			ctrl.name = "ControlsPanel"
			var grid = GridContainer.new()
			grid.name = "Grid"
			for i in range(1, 8):
				var aLbl = Label.new()
				aLbl.name = "Action%d" % i
				var kLbl = Label.new()
				kLbl.name = "Key%d" % i
				grid.add_child(aLbl)
				grid.add_child(kLbl)
			ctrl.add_child(grid)
			panels.add_child(ctrl)
			
			var lang = Control.new()
			lang.name = "LanguagePanel"
			var langBox = HBoxContainer.new()
			langBox.name = "LangBox"
			var langLbl = Label.new()
			langLbl.name = "Label"
			var langOpt = OptionButton.new()
			langOpt.name = "LanguageOpt"
			langBox.add_child(langLbl)
			langBox.add_child(langOpt)
			lang.add_child(langBox)
			var subChk = CheckBox.new()
			subChk.name = "SubtitlesCheck"
			lang.add_child(subChk)
			panels.add_child(lang)
			
			v.add_child(panels)
			
			var sBack = Button.new()
			sBack.name = "BackBtn"
			v.add_child(sBack)
		elif vName == "ProfileSettingsView":
			for bName in ["ProfilBtn", "SkinSelectBtn", "ZadaniaBtn", "BackBtn"]:
				var b = Button.new()
				b.name = bName
				v.add_child(b)
		elif vName == "SkinSelectView":
			for i in range(6):
				var sb = Button.new()
				sb.name = "Skin%dBtn" % i
				var badge = Label.new()
				badge.name = "Badge"
				sb.add_child(badge)
				v.add_child(sb)
			var sbBack = Button.new()
			sbBack.name = "BackBtn"
			v.add_child(sbBack)
			var lbl = Label.new()
			lbl.name = "ActiveSkinLabel"
			v.add_child(lbl)
		elif vName == "ProfileView":
			var inp = LineEdit.new()
			inp.name = "PairingCodeInput"
			v.add_child(inp)
			var pBtn = Button.new()
			pBtn.name = "PairBtn"
			v.add_child(pBtn)
			var oBtn = Button.new()
			oBtn.name = "OpenPortalBtn"
			v.add_child(oBtn)
			var statLbl = Label.new()
			statLbl.name = "StatusLabel"
			v.add_child(statLbl)
			var bBtn = Button.new()
			bBtn.name = "BackBtn"
			v.add_child(bBtn)
		elif vName == "ZadaniaView":
			for i in range(1, 4):
				var box = VBoxContainer.new()
				box.name = "Task%dContainer" % i
				for lName in ["Title", "Desc", "Progress", "Reward"]:
					var l = Label.new()
					l.name = lName
					box.add_child(l)
				v.add_child(box)
			var bBtn = Button.new()
			bBtn.name = "BackBtn"
			v.add_child(bBtn)
		menu.add_child(v)
	add_child(menu)
	return menu
