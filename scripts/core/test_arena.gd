extends Node2D

## Główny skrypt Areny Poziomu (JewelRunner)
## Obsługuje:
## - Zbieranie wszystkich klejnotów (Jewels) jako warunek otwarcia wyjścia (FinishGoal)
## - Pomiar czasu ukończenia poziomu (bez konceptu Score)
## - Integrację z Adaptacyjnym Reżyserem AI (mnożniki staminy o stałej sumie, blokady przeciążonych ruchów, analiza poziomu)
## - Integrację z Generatorem Poziomów AI oraz adapterem pod przyszły TileSet (TileMapLayer)

const LevelGenerator = preload("res://scripts/core/level_generator.gd")

@export var custom_tileset: TileSet = null

@onready var respawn_point: Marker2D = get_node_or_null("RespawnPoint")
@onready var hud_stamina_bar: ProgressBar = get_node_or_null("HUD/StaminaPanel/HBox/HudStaminaBar")
@onready var hud_score_label: Label = get_node_or_null("HUD/ScorePanel/ScoreText") if has_node("HUD/ScorePanel/ScoreText") else get_node_or_null("HUD/JewelPanel/JewelText")
@onready var hud_time_label: Label = get_node_or_null("HUD/TimePanel/TimeText")
@onready var hud_session_label: Label = get_node_or_null("HUD/SessionLabel")
@onready var pause_menu: Control = get_node_or_null("HUD/PauseMenu")
@onready var game_over_menu: Control = get_node_or_null("HUD/GameOverMenu")
@onready var win_screen: Control = get_node_or_null("HUD/WinScreen")
@onready var win_score_label: Label = get_node_or_null("HUD/WinScreen/ScoreResultText") if has_node("HUD/WinScreen/ScoreResultText") else get_node_or_null("HUD/WinScreen/JewelResultText")
@onready var win_time_label: Label = get_node_or_null("HUD/WinScreen/TimeResultText")
@onready var win_session_label: Label = get_node_or_null("HUD/WinScreen/SessionResultText")

@onready var audio_pause: AudioStreamPlayer = get_node_or_null("HUD/AudioPause")
@onready var audio_win: AudioStreamPlayer = get_node_or_null("HUD/AudioWin")
@onready var audio_pickup: AudioStreamPlayer = get_node_or_null("HUD/AudioPickup")
@onready var music_level: AudioStreamPlayer = get_node_or_null("MusicLevel") if has_node("MusicLevel") else get_node_or_null("HUD/MusicLevel")

@onready var finish_goal: Area2D = get_node_or_null("FinishGoal")

var hud_ai_label: Label = null

var total_score: int = 0
var collected_jewels: int = 0
var total_jewels: int = 0
var tricks_performed_count: int = 0
var challenge_time_limit_s: float = -1.0
var is_game_over: bool = false
var is_stage_cleared: bool = false
var session_id: String = ""
var elapsed_time: float = 0.0
var is_timer_running: bool = false

func _ready() -> void:
	get_tree().paused = false
	is_game_over = false
	is_stage_cleared = false
	total_score = 0
	collected_jewels = 0
	
	# Budowa poziomu wg wybranego w Level Select profilu mechaniki (oraz przygotowanie warstwy TileMapLayer)
	var profile_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	var seed_val: int = Events.selected_level_seed if is_instance_valid(Events) else 0
	if has_node("Geometry") or profile_id != 1:
		var gen_res: Dictionary = LevelGenerator.build_level_for_arena(self, profile_id, seed_val, custom_tileset)
		challenge_time_limit_s = float(gen_res.get("challenge_max_time_s", -1.0))
		
	# Zliczenie wszystkich klejnotów na poziomie (wymaganych do odblokowania wyjścia)
	refresh_jewel_count()
	
	# Reset sesji AI Directora i analiza geometrii bieżącego poziomu
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		Events.ai_director.reset_session_state(true)
		Events.ai_director.analyze_level(self)
	
	# Inicjalizacja ID sesji i start zegara poziomu
	session_id = Events.generate_session_id()
	elapsed_time = 0.0
	is_timer_running = true
	
	if pause_menu: pause_menu.visible = false
	if game_over_menu: game_over_menu.visible = false
	if win_screen: win_screen.visible = false
	
	_ensure_ai_hud_panel()
	_update_score_hud()
	_update_time_hud()
	_update_goal_visuals()
	_update_ai_hud()
	
	if hud_session_label:
		hud_session_label.text = "ID: %s" % session_id
		
	if music_level:
		if not music_level.finished.is_connected(music_level.play):
			music_level.finished.connect(music_level.play)
		music_level.play()
	
	Events.player_died.connect(_on_player_died)
	Events.player_hit.connect(_on_player_hit)
	Events.player_stamina_changed.connect(_on_player_stamina_changed)
	Events.jewel_collected.connect(_on_jewel_collected)
	Events.score_added.connect(_on_score_added)
	Events.stamina_multipliers_updated.connect(_on_multipliers_updated)
	Events.mechanic_lockout_changed.connect(_on_mechanic_lockout_changed)
	Events.stamina_action_rejected.connect(_on_stamina_action_rejected)
	Events.trick_performed.connect(_on_trick_performed)
	Events.cursed_jewel_triggered.connect(_on_cursed_jewel_triggered)
	
	if finish_goal and not finish_goal.body_entered.is_connected(_on_goal_entered):
		finish_goal.body_entered.connect(_on_goal_entered)
	
	# Podpięcie przycisków pauzy
	var resume_btn: Button = get_node_or_null("HUD/PauseMenu/ResumeBtn")
	var restart_btn: Button = get_node_or_null("HUD/PauseMenu/RestartBtn")
	var quit_btn: Button = get_node_or_null("HUD/PauseMenu/QuitBtn")
	
	if resume_btn: resume_btn.pressed.connect(_toggle_pause)
	if restart_btn: restart_btn.pressed.connect(_restart_game)
	if quit_btn: quit_btn.pressed.connect(_quit_or_menu)
	
	# Podpięcie przycisków Game Over
	var retry_btn: Button = get_node_or_null("HUD/GameOverMenu/RetryBtn")
	var gameover_menu_btn: Button = get_node_or_null("HUD/GameOverMenu/MainMenuBtn")
	
	if retry_btn: retry_btn.pressed.connect(_restart_game)
	if gameover_menu_btn: gameover_menu_btn.pressed.connect(_quit_or_menu)
	
	# Podpięcie przycisków Win Screen
	var win_retry_btn: Button = get_node_or_null("HUD/WinScreen/RetryBtn")
	var win_menu_btn: Button = get_node_or_null("HUD/WinScreen/MainMenuBtn")
	
	if win_retry_btn: win_retry_btn.pressed.connect(_restart_game)
	if win_menu_btn: win_menu_btn.pressed.connect(_quit_or_menu)

func _process(delta: float) -> void:
	if is_timer_running and not get_tree().paused:
		elapsed_time += delta
		_update_time_hud()

## Zlicza wszystkie klejnoty obecne aktualnie na scenie.
func refresh_jewel_count() -> int:
	var count: int = 0
	for child in get_children():
		var scr: Script = child.get_script()
		var scr_path: String = scr.resource_path if scr else ""
		if child.is_in_group("jewels") or scr_path.ends_with("jewel.gd") or child.name.begins_with("Jewel"):
			count += 1
	total_jewels = count
	Events.jewels_progress_updated.emit(collected_jewels, total_jewels)
	_update_score_hud()
	_update_goal_visuals()
	return total_jewels

## Sprawdza, czy gracz zebrał wszystkie klejnoty wymagane do opuszczenia poziomu.
func can_exit_level() -> bool:
	return collected_jewels >= total_jewels

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	var tenths := int((seconds - int(seconds)) * 10)
	return "%02d:%02d.%d" % [mins, secs, tenths]

func _update_time_hud() -> void:
	if hud_time_label:
		hud_time_label.text = " TIME: %s " % _format_time(elapsed_time)

func _on_player_stamina_changed(current: float, max_stamina: float) -> void:
	if hud_stamina_bar:
		hud_stamina_bar.max_value = max_stamina
		hud_stamina_bar.value = current

func _on_jewel_collected(val: int, _pos: Vector2) -> void:
	collected_jewels += 1
	total_score += val
	Events.jewels_progress_updated.emit(collected_jewels, total_jewels)
	_update_score_hud()
	_update_goal_visuals()
	if total_jewels > 0 and collected_jewels >= total_jewels:
		Events.all_jewels_collected.emit()
	if audio_pickup:
		audio_pickup.play()

func _on_score_added(amount: int) -> void:
	total_score += amount

func _on_trick_performed(_pts: int) -> void:
	tricks_performed_count += 1

func _on_cursed_jewel_triggered(mechanic_name: String, duration: float) -> void:
	if hud_ai_label:
		hud_ai_label.text = "[!] PRZEKLĘTY KLEJNOT! Utracono %s na %.1fs! Użyj innych ruchów i Tricku [C]!" % [mechanic_name.to_upper(), duration]
		hud_ai_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.85, 1.0))

func _update_score_hud() -> void:
	if hud_score_label:
		if total_jewels > 0:
			hud_score_label.text = " JEWELS: %d/%d " % [collected_jewels, total_jewels]
		else:
			hud_score_label.text = " JEWELS: %d " % collected_jewels

func _update_goal_visuals() -> void:
	if not finish_goal:
		return
	var lbl: Label = finish_goal.get_node_or_null("LabelGoal")
	var aura: ColorRect = finish_goal.get_node_or_null("Aura")
	var unlocked: bool = can_exit_level()
	if lbl:
		if unlocked:
			lbl.text = "EXIT OPEN"
			lbl.modulate = Color(0.4, 1.0, 0.6, 1.0)
		else:
			lbl.text = "LOCKED %d/%d" % [collected_jewels, total_jewels]
			lbl.modulate = Color(1.0, 0.55, 0.45, 1.0)
	if aura:
		aura.color = Color(0.2, 0.9, 0.7, 0.38) if unlocked else Color(0.9, 0.25, 0.25, 0.30)

func _ensure_ai_hud_panel() -> void:
	var hud: Node = get_node_or_null("HUD")
	if not hud:
		return
	hud_ai_label = hud.get_node_or_null("AIMultipliersLabel") as Label
	if not hud_ai_label:
		hud_ai_label = Label.new()
		hud_ai_label.name = "AIMultipliersLabel"
		hud_ai_label.position = Vector2(12, 72)
		hud_ai_label.size = Vector2(616, 20)
		hud_ai_label.add_theme_font_size_override("font_size", 11)
		hud_ai_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 0.92))
		hud.add_child(hud_ai_label)

func _update_ai_hud() -> void:
	if not hud_ai_label or not is_instance_valid(Events) or not is_instance_valid(Events.ai_director):
		return
	var dir: AdaptiveAIDirector = Events.ai_director
	var m_dj: float = dir.get_multiplier("double_jump")
	var m_wc: float = dir.get_multiplier("wall_climb")
	var m_da: float = dir.get_multiplier("dash")
	var dom_lbl: String = dir.get_dominant_mechanic_label()
	
	var lock_warnings: Array[String] = []
	for move in AdaptiveAIDirector.TRACKED_MOVES:
		if dir.is_move_locked(move):
			lock_warnings.append("%s LOCKED (%.1fs)" % [move.to_upper(), dir.get_lockout_remaining(move)])
			
	if not lock_warnings.is_empty():
		hud_ai_label.text = "KOSZT STAMINY: DJ x%.2f | CLIMB x%.2f | DASH x%.2f  [!] %s" % [
			m_dj, m_wc, m_da, " , ".join(lock_warnings)
		]
		hud_ai_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45, 1.0))
	else:
		hud_ai_label.text = "KOSZT STAMINY (Σ=%.1f): DJ x%.2f | CLIMB x%.2f | DASH x%.2f   |   PROFIL: %s" % [
			dir.get_multiplier_sum(), m_dj, m_wc, m_da, dom_lbl
		]
		hud_ai_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 0.92))

func _on_multipliers_updated(_multipliers: Dictionary) -> void:
	_update_ai_hud()

func _on_mechanic_lockout_changed(_move_name: String, _is_locked: bool, _duration: float) -> void:
	_update_ai_hud()

func _on_stamina_action_rejected(move_name: String, _req: float, _cur: float) -> void:
	if hud_ai_label:
		if is_instance_valid(Events) and is_instance_valid(Events.ai_director) and Events.ai_director.is_move_locked(move_name):
			hud_ai_label.text = "[!] RUCH ZABLOKOWANY PRZEZ PRZECIĄŻENIE (%s)! Wykonaj inny ruch lub Trick [C] w locie!" % move_name.to_upper()
		else:
			hud_ai_label.text = "[!] BRAK STAMINY NA %s! Wykonaj skok + Trick [C] w powietrzu, aby zregenerować!" % move_name.to_upper()
		hud_ai_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))

func _on_goal_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_game_over and not is_stage_cleared:
		# Sprawdzenie, czy zebrano wszystkie klejnoty na poziomie!
		if not can_exit_level():
			if finish_goal:
				var lbl: Label = finish_goal.get_node_or_null("LabelGoal")
				if lbl:
					lbl.text = "BRAK: %d/%d!" % [collected_jewels, total_jewels]
			if hud_ai_label:
				hud_ai_label.text = "[!] ZBIERZ WSZYSTKIE KLEJNOTY (%d/%d), ABY ODBLOKOWAĆ WYJŚCIE!" % [collected_jewels, total_jewels]
				hud_ai_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3, 1.0))
			return
			
		is_stage_cleared = true
		is_timer_running = false
		get_tree().paused = true
		var lvl_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
		Events.complete_level(lvl_id, elapsed_time)
		if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
			Events.portal_sync.evaluate_run_against_challenges(collected_jewels, elapsed_time, true, tricks_performed_count)
		
		if music_level:
			music_level.stop()
			
		if win_score_label:
			win_score_label.text = "JEWELS: %d / %d" % [collected_jewels, total_jewels]
			
		if win_time_label:
			win_time_label.text = "TIME: %s" % _format_time(elapsed_time)
			
		if win_session_label:
			win_session_label.text = "SESSION: %s" % session_id
			
		if win_screen:
			win_screen.visible = true
			
		if audio_win:
			audio_win.play()

func _unhandled_input(event: InputEvent) -> void:
	if is_stage_cleared or is_game_over:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_R or event.keycode == KEY_SPACE)):
			_restart_game()
		elif event.is_action_pressed("ui_cancel"):
			_quit_or_menu()
		return
		
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
		_toggle_pause()
	elif not get_tree().paused and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart_game()

func _toggle_pause() -> void:
	if is_game_over or is_stage_cleared:
		return
		
	var paused = not get_tree().paused
	get_tree().paused = paused
	if pause_menu:
		pause_menu.visible = paused
		
	if paused and audio_pause:
		audio_pause.play()

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit_or_menu() -> void:
	get_tree().paused = false
	if ResourceLoader.exists("res://scenes/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().quit()

func _on_player_died() -> void:
	if is_game_over or is_stage_cleared:
		return
	is_game_over = true
	get_tree().paused = true
	if music_level:
		music_level.stop()
	if game_over_menu:
		game_over_menu.visible = true

func _on_player_hit(_damage: int) -> void:
	pass
