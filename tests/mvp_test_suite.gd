extends Node

const JewelScript = preload("res://scripts/jewel.gd")
const MainMenuScript = preload("res://scripts/menu.gd")
const PlayerScript = preload("res://scripts/actors/player/player_controller.gd")
const HazardScript = preload("res://scripts/core/hazard_area.gd")
const ArenaScript = preload("res://scripts/core/test_arena.gd")
const AIDirectorScript = preload("res://scripts/core/ai_director.gd")
const LevelGeneratorScript = preload("res://scripts/core/level_generator.gd")

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
	itTopProfileButtonOpensWebPortalAndSyncs()
	itPortalShieldAndMagnetBoostersInGameplay()
	itWebChallengesCompleteOnWinningRun()
	itLevelSelectMechanicPanelsAndAIContracts()
	
	print("\n==================================================")
	print(" PODSUMOWANIE: ZALICZONE: %d | BŁĘDY: %d | ŁĄCZNIE: %d" % [passCnt, failCnt, passCnt + failCnt])
	print("==================================================")
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failCnt == 0 else 1)

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
		
	for audName in ["AudioPause", "AudioWin", "AudioPickup"]:
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
