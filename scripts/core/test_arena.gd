extends Node2D

## Główny skrypt Areny Poziomu (JewelRunner)
## Obsługuje:
## - Zbieranie wszystkich klejnotów (Jewels) jako warunek otwarcia wyjścia (FinishGoal)
## - Pomiar czasu ukończenia poziomu (bez konceptu Score)
## - Integrację z Adaptacyjnym Reżyserem AI (mnożniki staminy o stałej sumie, blokady przeciążonych ruchów, analiza poziomu)
## - Integrację z Generatorem Poziomów AI oraz adapterem pod przyszły TileSet (TileMapLayer)

const LevelGenerator = preload("res://scripts/core/level_generator.gd")
const CyberQuizScript = preload("res://scripts/core/cyber_quiz.gd")

@export var custom_tileset: TileSet = null

@onready var respawn_point: Marker2D = get_node_or_null("RespawnPoint")
@onready var hud_stamina_bar: ProgressBar = get_node_or_null("HUD/StaminaPanel/HBox/HudStaminaBar")
@onready var hud_score_label: Label = get_node_or_null("HUD/ScorePanel/ScoreText") if has_node("HUD/ScorePanel/ScoreText") else get_node_or_null("HUD/JewelPanel/JewelText")
@onready var hud_time_label: Label = get_node_or_null("HUD/TimePanel/TimeText")
@onready var hud_session_label: Label = get_node_or_null("HUD/SessionLabel")
@onready var pause_menu: Control = get_node_or_null("HUD/PauseMenu")
@onready var settings_view: Control = get_node_or_null("HUD/SettingsView")
@onready var game_over_menu: Control = get_node_or_null("HUD/GameOverMenu")
@onready var win_screen: Control = get_node_or_null("HUD/WinScreen")
@onready var win_score_label: Label = get_node_or_null("HUD/WinScreen/ScoreResultText") if has_node("HUD/WinScreen/ScoreResultText") else get_node_or_null("HUD/WinScreen/JewelResultText")
@onready var win_time_label: Label = get_node_or_null("HUD/WinScreen/TimeResultText")
@onready var win_session_label: Label = get_node_or_null("HUD/WinScreen/SessionResultText")

@onready var knowledge_check_popup: Control = get_node_or_null("HUD/KnowledgeCheckPopup")
@onready var quiz_topic_label: Label = get_node_or_null("HUD/KnowledgeCheckPopup/Panel/TopicBadge")
@onready var quiz_question_label: Label = get_node_or_null("HUD/KnowledgeCheckPopup/Panel/QuestionLabel")
@onready var quiz_feedback_label: Label = get_node_or_null("HUD/KnowledgeCheckPopup/Panel/FeedbackLabel")
@onready var quiz_options_container: VBoxContainer = get_node_or_null("HUD/KnowledgeCheckPopup/Panel/OptionsContainer")

@onready var audio_pause: AudioStreamPlayer = get_node_or_null("HUD/AudioPause")
@onready var audio_win: AudioStreamPlayer = get_node_or_null("HUD/AudioWin")
@onready var audio_pickup: AudioStreamPlayer = get_node_or_null("HUD/AudioPickup")
@onready var music_level: AudioStreamPlayer = get_node_or_null("MusicLevel") if has_node("MusicLevel") else get_node_or_null("HUD/MusicLevel")

@onready var finish_goal: Area2D = get_node_or_null("FinishGoal")

var hud_ai_label: Label = null

var is_knowledge_check_active: bool = false
var current_quiz_question: Dictionary = {}
var quiz_focus_idx: int = 0
var quiz_buttons: Array[Button] = []
var quiz_answered_correctly: bool = false

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

var current_settings_tab: int = 0
var current_language: String = "pl"
var subtitles_enabled: bool = true
var tabNames: Array = ["MUZYKA", "GRAFIKA", "STEROWANIE", "JĘZYK"]

var pause_buttons: Array[Button] = []
var game_over_buttons: Array[Button] = []
var win_buttons: Array[Button] = []

var pause_focus_idx: int = 0
var game_over_focus_idx: int = 0
var win_focus_idx: int = 0

func _set_button_focus(buttons: Array[Button], idx: int) -> int:
	if buttons.is_empty():
		return 0
	var clamped_idx = (idx % buttons.size() + buttons.size()) % buttons.size()
	for i in range(buttons.size()):
		var b = buttons[i]
		if b and i == clamped_idx:
			b.grab_focus()
	return clamped_idx

func _activate_focused_button(buttons: Array[Button], idx: int) -> bool:
	if buttons.is_empty():
		return false
	var clamped_idx = (idx % buttons.size() + buttons.size()) % buttons.size()
	var b = buttons[clamped_idx]
	if b and b.is_inside_tree() and b.visible:
		b.pressed.emit()
		return true
	return false

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
	if settings_view: settings_view.visible = false
	if game_over_menu: game_over_menu.visible = false
	if win_screen: win_screen.visible = false
	
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var saved_lang = String(Events.portal_sync.cosmetics_state.get("language", Events.portal_sync.profile_settings.get("language", "pl")))
		_apply_language(saved_lang)
	
	_ensure_ai_hud_panel()
	_update_score_hud()
	_update_time_hud()
	_update_goal_visuals()
	_update_ai_hud()
	
	if hud_session_label:
		hud_session_label.text = "ID: %s" % session_id
		
	if music_level:
		if music_level.stream is AudioStreamWAV:
			(music_level.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		if not music_level.finished.is_connected(music_level.play):
			music_level.finished.connect(music_level.play)
		if not music_level.playing:
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
	
	# Podpięcie przycisków pauzy i nawigacji
	var resume_btn: Button = get_node_or_null("HUD/PauseMenu/ResumeBtn")
	var restart_btn: Button = get_node_or_null("HUD/PauseMenu/RestartBtn")
	var settings_btn: Button = get_node_or_null("HUD/PauseMenu/SettingsBtn")
	var quit_btn: Button = get_node_or_null("HUD/PauseMenu/QuitBtn")
	
	if resume_btn: resume_btn.pressed.connect(_toggle_pause)
	if restart_btn: restart_btn.pressed.connect(_restart_game)
	if settings_btn: settings_btn.pressed.connect(_open_settings)
	if quit_btn: quit_btn.pressed.connect(_quit_or_menu)
	
	pause_buttons.clear()
	for b in [resume_btn, restart_btn, settings_btn, quit_btn]:
		if b: pause_buttons.append(b)
	for i in range(pause_buttons.size()):
		var b = pause_buttons[i]
		var cap_i = i
		b.mouse_entered.connect(func():
			pause_focus_idx = cap_i
			b.grab_focus()
		)
		b.focus_entered.connect(func():
			pause_focus_idx = cap_i
		)
	
	var settings_back_btn: Button = get_node_or_null("HUD/SettingsView/BackBtn")
	if settings_back_btn: settings_back_btn.pressed.connect(_close_settings)
	
	# Podpięcie przycisków Game Over
	var retry_btn: Button = get_node_or_null("HUD/GameOverMenu/RetryBtn")
	var gameover_menu_btn: Button = get_node_or_null("HUD/GameOverMenu/MainMenuBtn")
	
	if retry_btn: retry_btn.pressed.connect(_restart_game)
	if gameover_menu_btn: gameover_menu_btn.pressed.connect(_quit_or_menu)
	
	game_over_buttons.clear()
	for b in [retry_btn, gameover_menu_btn]:
		if b: game_over_buttons.append(b)
	for i in range(game_over_buttons.size()):
		var b = game_over_buttons[i]
		var cap_i = i
		b.mouse_entered.connect(func():
			game_over_focus_idx = cap_i
			b.grab_focus()
		)
		b.focus_entered.connect(func():
			game_over_focus_idx = cap_i
		)
	
	# Podpięcie przycisków Win Screen
	var win_retry_btn: Button = get_node_or_null("HUD/WinScreen/RetryBtn")
	var win_menu_btn: Button = get_node_or_null("HUD/WinScreen/MainMenuBtn")
	
	if win_retry_btn: win_retry_btn.pressed.connect(_restart_game)
	if win_menu_btn: win_menu_btn.pressed.connect(_quit_or_menu)
	
	win_buttons.clear()
	for b in [win_retry_btn, win_menu_btn]:
		if b: win_buttons.append(b)
	for i in range(win_buttons.size()):
		var b = win_buttons[i]
		var cap_i = i
		b.mouse_entered.connect(func():
			win_focus_idx = cap_i
			b.grab_focus()
		)
		b.focus_entered.connect(func():
			win_focus_idx = cap_i
		)
	
	_init_knowledge_check()

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

func _init_knowledge_check() -> void:
	quiz_buttons.clear()
	quiz_answered_correctly = false
	is_knowledge_check_active = false
	
	if knowledge_check_popup:
		knowledge_check_popup.visible = false
		
	if quiz_options_container:
		for child in quiz_options_container.get_children():
			if child is Button:
				quiz_buttons.append(child)
				var cap_i = quiz_buttons.size() - 1
				if not child.pressed.is_connected(_on_quiz_option_pressed):
					child.pressed.connect(_on_quiz_option_pressed.bind(cap_i))
				child.mouse_entered.connect(func():
					if is_knowledge_check_active:
						quiz_focus_idx = cap_i
						child.grab_focus()
				)
				child.focus_entered.connect(func():
					if is_knowledge_check_active:
						quiz_focus_idx = cap_i
				)
					
	_pick_random_quiz_question()

func _pick_random_quiz_question(excluded_id: int = -1) -> void:
	current_quiz_question = CyberQuizScript.get_random_question(excluded_id)
	_apply_quiz_question_to_ui()

func _apply_quiz_question_to_ui() -> void:
	if current_quiz_question.is_empty():
		return
	if quiz_topic_label:
		quiz_topic_label.text = "KATEGORIA: %s" % String(current_quiz_question.get("topic", "Cyberbezpieczeństwo")).to_upper()
	if quiz_question_label:
		quiz_question_label.text = String(current_quiz_question.get("question", ""))
	var opts: Array = current_quiz_question.get("options", [])
	for i in range(quiz_buttons.size()):
		var b = quiz_buttons[i]
		if i < opts.size():
			b.text = String(opts[i])
			b.visible = true
		else:
			b.visible = false
		_reset_quiz_button_style(b)
	if quiz_feedback_label:
		quiz_feedback_label.text = ""

func _reset_quiz_button_style(btn: Button) -> void:
	if not btn:
		return
	btn.remove_theme_color_override("font_color")

func _open_knowledge_check() -> void:
	if not knowledge_check_popup:
		_level_complete()
		return
		
	is_knowledge_check_active = true
	is_timer_running = false
	get_tree().paused = true
	knowledge_check_popup.visible = true
	_apply_quiz_question_to_ui()
	quiz_focus_idx = 0
	_set_button_focus(quiz_buttons, 0)

func _on_quiz_option_pressed(idx: int) -> void:
	_submit_quiz_answer(idx)

func _submit_quiz_answer(idx: int) -> void:
	if not is_knowledge_check_active or current_quiz_question.is_empty():
		return
		
	var correct_idx: int = int(current_quiz_question.get("correct", 0))
	if idx == correct_idx:
		quiz_answered_correctly = true
		if quiz_feedback_label:
			quiz_feedback_label.text = "[V] POPRAWNA ODPOWIEDŹ! KOD AUTORYZACYJNY PRZYJĘTY."
			quiz_feedback_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45, 1.0))
		if idx < quiz_buttons.size():
			quiz_buttons[idx].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
			
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(self):
			if knowledge_check_popup:
				knowledge_check_popup.visible = false
			is_knowledge_check_active = false
			_level_complete()
	else:
		if quiz_feedback_label:
			quiz_feedback_label.text = "[X] BŁĘDNA ODPOWIEDŹ! Zastanów się i wybierz poprawną opcję."
			quiz_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		if idx < quiz_buttons.size():
			quiz_buttons[idx].add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))

func _on_goal_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_game_over and not is_stage_cleared and not is_knowledge_check_active:
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
			
		# Knowledge Check warunkiem ukończenia poziomu:
		if knowledge_check_popup and not quiz_answered_correctly:
			_open_knowledge_check()
			return
			
		_level_complete()

func _level_complete() -> void:
	is_stage_cleared = true
	is_timer_running = false
	get_tree().paused = true
	var lvl_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	Events.complete_level(lvl_id, elapsed_time)
	if is_instance_valid(Events):
		Events.return_to_level_select = true
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
		win_focus_idx = 0
		_set_button_focus(win_buttons, 0)
		
	if audio_win:
		audio_win.play()

func _unhandled_input(event: InputEvent) -> void:
	# 0. Obsługa Knowledge Check (Cyber Quiz) - nie można wyjść z okna, dopóki nie zaznaczy się odpowiedzi!
	if is_knowledge_check_active and knowledge_check_popup and knowledge_check_popup.visible:
		# Blokada wyjścia z okna (klawisz ESC ani ui_cancel nie może zamknąć okna dopóki nie ma odpowiedzi!)
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			if quiz_feedback_label:
				quiz_feedback_label.text = "[!] MUSISZ ZAZNACZYĆ POPRAWNĄ ODPOWIEDŹ, ABY UKOŃCZYĆ POZIOM!"
				quiz_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3, 1.0))
			get_viewport().set_input_as_handled()
			return
			
		# Nawigacja strzałkami (Up / Down / W / S)
		if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
			quiz_focus_idx = _set_button_focus(quiz_buttons, quiz_focus_idx + 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W)):
			quiz_focus_idx = _set_button_focus(quiz_buttons, quiz_focus_idx - 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
			_submit_quiz_answer(quiz_focus_idx)
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		return

	# 1. Obsługa nawigacji strzałkami w WinScreen
	if is_stage_cleared and win_screen and win_screen.visible:
		if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
			win_focus_idx = _set_button_focus(win_buttons, win_focus_idx + 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W)):
			win_focus_idx = _set_button_focus(win_buttons, win_focus_idx - 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
			_activate_focused_button(win_buttons, win_focus_idx)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_cancel"):
			_quit_or_menu()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_restart_game()
			get_viewport().set_input_as_handled()
			return
		return

	# 2. Obsługa nawigacji strzałkami w GameOverMenu
	if is_game_over and game_over_menu and game_over_menu.visible:
		if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
			game_over_focus_idx = _set_button_focus(game_over_buttons, game_over_focus_idx + 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W)):
			game_over_focus_idx = _set_button_focus(game_over_buttons, game_over_focus_idx - 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
			_activate_focused_button(game_over_buttons, game_over_focus_idx)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_cancel"):
			_quit_or_menu()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_restart_game()
			get_viewport().set_input_as_handled()
			return
		return

	# 3. Obsługa SettingsView w trakcie gry
	if settings_view and settings_view.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
			_close_settings()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_Q or event.keycode == KEY_PAGEUP:
				_switch_settings_tab((current_settings_tab - 1 + 4) % 4)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_E or event.keycode == KEY_PAGEDOWN:
				_switch_settings_tab((current_settings_tab + 1) % 4)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_LEFT:
				var focused = get_viewport().gui_get_focus_owner()
				if not (focused is Slider or focused is OptionButton):
					_switch_settings_tab((current_settings_tab - 1 + 4) % 4)
					get_viewport().set_input_as_handled()
					return
			elif event.keycode == KEY_RIGHT:
				var focused = get_viewport().gui_get_focus_owner()
				if not (focused is Slider or focused is OptionButton):
					_switch_settings_tab((current_settings_tab + 1) % 4)
					get_viewport().set_input_as_handled()
					return
			elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_switch_settings_tab(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()
				return
		
	# 4. Obsługa nawigacji strzałkami w PauseMenu
	if get_tree().paused and pause_menu and pause_menu.visible:
		if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
			pause_focus_idx = _set_button_focus(pause_buttons, pause_focus_idx + 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_W)):
			pause_focus_idx = _set_button_focus(pause_buttons, pause_focus_idx - 1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
			_activate_focused_button(pause_buttons, pause_focus_idx)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return

	# 5. Klawisze w trakcie normalnej rozgrywki
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
		_toggle_pause()
	elif not get_tree().paused and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart_game()

func _toggle_pause() -> void:
	if is_game_over or is_stage_cleared:
		return
		
	if settings_view and settings_view.visible:
		_close_settings()
		return
		
	var paused = not get_tree().paused
	get_tree().paused = paused
	if pause_menu:
		pause_menu.visible = paused
		if paused:
			pause_focus_idx = 0
			_set_button_focus(pause_buttons, 0)
		
	if paused and audio_pause:
		audio_pause.play()

func _open_settings() -> void:
	if pause_menu:
		pause_menu.visible = false
	if settings_view:
		settings_view.visible = true
		_setup_settings_view()
		_switch_settings_tab(0)

func _close_settings() -> void:
	if settings_view:
		settings_view.visible = false
	if pause_menu:
		pause_menu.visible = true
		_set_button_focus(pause_buttons, pause_focus_idx)

func _find_in_settings(child_path: String) -> Node:
	if not settings_view:
		return null
	var direct = settings_view.get_node_or_null(child_path)
	if direct:
		return direct
	var in_panels = settings_view.get_node_or_null("Panels/" + child_path)
	if in_panels:
		return in_panels
	for cat in ["AudioPanel", "GraphicsPanel", "ControlsPanel", "LanguagePanel"]:
		var p_node = settings_view.get_node_or_null("Panels/" + cat + "/" + child_path)
		if p_node:
			return p_node
	var fname = child_path.get_file()
	if fname == "Label" or fname == "Value":
		return null
	return settings_view.find_child(fname, true, false)

func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("MusicMenu") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "MusicMenu")
		AudioServer.set_bus_send(idx, "Music")
	if AudioServer.get_bus_index("MusicLevel") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "MusicLevel")
		AudioServer.set_bus_send(idx, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _set_bus_volume_percent(bus_name: String, pct: float) -> void:
	_ensure_audio_buses()
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if pct <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var linear = clampf(pct / 100.0, 0.0001, 1.0)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))

func _setup_settings_view() -> void:
	_ensure_audio_buses()
	
	# Podpięcie zakładek
	var tabAudioBtn: Button = _find_in_settings("TabAudioBtn") as Button
	var tabGraphicsBtn: Button = _find_in_settings("TabGraphicsBtn") as Button
	var tabControlsBtn: Button = _find_in_settings("TabControlsBtn") as Button
	var tabLanguageBtn: Button = _find_in_settings("TabLanguageBtn") as Button
	
	if tabAudioBtn and not tabAudioBtn.pressed.is_connected(func(): _switch_settings_tab(0)):
		tabAudioBtn.pressed.connect(func(): _switch_settings_tab(0))
	if tabGraphicsBtn and not tabGraphicsBtn.pressed.is_connected(func(): _switch_settings_tab(1)):
		tabGraphicsBtn.pressed.connect(func(): _switch_settings_tab(1))
	if tabControlsBtn and not tabControlsBtn.pressed.is_connected(func(): _switch_settings_tab(2)):
		tabControlsBtn.pressed.connect(func(): _switch_settings_tab(2))
	if tabLanguageBtn and not tabLanguageBtn.pressed.is_connected(func(): _switch_settings_tab(3)):
		tabLanguageBtn.pressed.connect(func(): _switch_settings_tab(3))

	var tab_btns = [tabAudioBtn, tabGraphicsBtn, tabControlsBtn, tabLanguageBtn]
	for idx in range(tab_btns.size()):
		var b = tab_btns[idx]
		if b and not b.focus_entered.is_connected(Callable(self, "_on_tab_focused").bind(idx)):
			b.focus_entered.connect(_on_tab_focused.bind(idx))
		
	# Podpięcie opcji graficznych
	var modeOpt: OptionButton = _find_in_settings("DisplayModeOpt") as OptionButton
	if modeOpt:
		_populate_display_mode_opt(modeOpt)
		
	var resOpt: OptionButton = _find_in_settings("ResolutionOpt") as OptionButton
	if resOpt:
		_populate_resolution_opt(resOpt)
		
	var vsyncCheck: CheckBox = _find_in_settings("VsyncCheck") as CheckBox
	if vsyncCheck:
		vsyncCheck.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
		if not vsyncCheck.toggled.is_connected(_on_vsync_toggled):
			vsyncCheck.toggled.connect(_on_vsync_toggled)

	var fpsOpt: OptionButton = _find_in_settings("FpsLimitOpt") as OptionButton
	if fpsOpt:
		_populate_fps_limit_opt(fpsOpt)
		
	var langOpt: OptionButton = _find_in_settings("LanguageOpt") as OptionButton
	if langOpt:
		langOpt.clear()
		langOpt.add_item("Polski (PL)")
		langOpt.add_item("English (EN)")
		langOpt.selected = 0 if current_language == "pl" else 1
		if not langOpt.item_selected.is_connected(_on_language_selected):
			langOpt.item_selected.connect(_on_language_selected)

	var subsCheck: CheckBox = _find_in_settings("SubtitlesCheck") as CheckBox
	if subsCheck:
		subsCheck.button_pressed = subtitles_enabled
		if not subsCheck.toggled.is_connected(_on_subtitles_toggled):
			subsCheck.toggled.connect(_on_subtitles_toggled)

	# Podpięcie suwaków audio
	var masterSlider: HSlider = _find_in_settings("MasterSlider") as HSlider
	var masterVal: Label = null
	if masterSlider:
		masterVal = masterSlider.get_parent().get_node_or_null("MasterValue") as Label
		if not masterVal: masterVal = masterSlider.get_parent().get_node_or_null("Value") as Label
		if not masterVal: masterVal = _find_in_settings("MasterValue") as Label
		var m_idx = AudioServer.get_bus_index("Master")
		if m_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(m_idx)
			var is_muted = AudioServer.is_bus_mute(m_idx)
			masterSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if masterVal:
			masterVal.text = "%d%%" % int(masterSlider.value)
		if not masterSlider.value_changed.is_connected(_on_master_slider_changed):
			masterSlider.value_changed.connect(_on_master_slider_changed)

	var musicSlider: HSlider = _find_in_settings("MusicSlider") as HSlider
	var musicVal: Label = null
	if musicSlider:
		musicVal = musicSlider.get_parent().get_node_or_null("MusicValue") as Label
		if not musicVal: musicVal = musicSlider.get_parent().get_node_or_null("Value") as Label
		if not musicVal: musicVal = _find_in_settings("MusicValue") as Label
		var mus_idx = AudioServer.get_bus_index("MusicMenu")
		if mus_idx == -1: mus_idx = AudioServer.get_bus_index("Music")
		if mus_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(mus_idx)
			var is_muted = AudioServer.is_bus_mute(mus_idx)
			musicSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if musicVal:
			musicVal.text = "%d%%" % int(musicSlider.value)
		if not musicSlider.value_changed.is_connected(_on_music_slider_changed):
			musicSlider.value_changed.connect(_on_music_slider_changed)

	var levelMusicSlider: HSlider = _find_in_settings("LevelMusicSlider") as HSlider
	var levelMusicVal: Label = null
	if levelMusicSlider:
		levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("LevelMusicValue") as Label
		if not levelMusicVal: levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("Value") as Label
		if not levelMusicVal: levelMusicVal = _find_in_settings("LevelMusicValue") as Label
		var lvl_idx = AudioServer.get_bus_index("MusicLevel")
		if lvl_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(lvl_idx)
			var is_muted = AudioServer.is_bus_mute(lvl_idx)
			levelMusicSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if levelMusicVal:
			levelMusicVal.text = "%d%%" % int(levelMusicSlider.value)
		if not levelMusicSlider.value_changed.is_connected(_on_level_music_slider_changed):
			levelMusicSlider.value_changed.connect(_on_level_music_slider_changed)

	var sfxSlider: HSlider = _find_in_settings("SfxSlider") as HSlider
	var sfxVal: Label = null
	if sfxSlider:
		sfxVal = sfxSlider.get_parent().get_node_or_null("SfxValue") as Label
		if not sfxVal: sfxVal = sfxSlider.get_parent().get_node_or_null("Value") as Label
		if not sfxVal: sfxVal = _find_in_settings("SfxValue") as Label
		var sfx_idx = AudioServer.get_bus_index("SFX")
		if sfx_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(sfx_idx)
			var is_muted = AudioServer.is_bus_mute(sfx_idx)
			sfxSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if sfxVal:
			sfxVal.text = "%d%%" % int(sfxSlider.value)
		if not sfxSlider.value_changed.is_connected(_on_sfx_slider_changed):
			sfxSlider.value_changed.connect(_on_sfx_slider_changed)

	var muteCheck: CheckBox = _find_in_settings("MuteCheck") as CheckBox
	if muteCheck:
		var m_idx = AudioServer.get_bus_index("Master")
		if m_idx != -1:
			muteCheck.button_pressed = AudioServer.is_bus_mute(m_idx)
		if not muteCheck.toggled.is_connected(_on_mute_check_toggled):
			muteCheck.toggled.connect(_on_mute_check_toggled)

	# Focus navigation dla zakładek i kontrolek settings w arenie
	var settingsBackBtn: Button = _find_in_settings("SettingsBackBtn") as Button
	if not settingsBackBtn: settingsBackBtn = _find_in_settings("BackBtn") as Button

	if tabAudioBtn and tabGraphicsBtn and tabControlsBtn and tabLanguageBtn:
		tabAudioBtn.focus_neighbor_left = tabLanguageBtn.get_path()
		tabAudioBtn.focus_neighbor_right = tabGraphicsBtn.get_path()
		tabGraphicsBtn.focus_neighbor_left = tabAudioBtn.get_path()
		tabGraphicsBtn.focus_neighbor_right = tabControlsBtn.get_path()
		tabControlsBtn.focus_neighbor_left = tabGraphicsBtn.get_path()
		tabControlsBtn.focus_neighbor_right = tabLanguageBtn.get_path()
		tabLanguageBtn.focus_neighbor_left = tabControlsBtn.get_path()
		tabLanguageBtn.focus_neighbor_right = tabAudioBtn.get_path()
		if masterSlider: tabAudioBtn.focus_neighbor_bottom = masterSlider.get_path()
		if modeOpt: tabGraphicsBtn.focus_neighbor_bottom = modeOpt.get_path()
		if langOpt: tabLanguageBtn.focus_neighbor_bottom = langOpt.get_path()

	if masterSlider and tabAudioBtn:
		masterSlider.focus_neighbor_top = tabAudioBtn.get_path()
		if musicSlider: masterSlider.focus_neighbor_bottom = musicSlider.get_path()
	if musicSlider and masterSlider:
		musicSlider.focus_neighbor_top = masterSlider.get_path()
		if levelMusicSlider: musicSlider.focus_neighbor_bottom = levelMusicSlider.get_path()
	if levelMusicSlider and musicSlider:
		levelMusicSlider.focus_neighbor_top = musicSlider.get_path()
		if sfxSlider: levelMusicSlider.focus_neighbor_bottom = sfxSlider.get_path()
	if sfxSlider and levelMusicSlider:
		sfxSlider.focus_neighbor_top = levelMusicSlider.get_path()
		if muteCheck: sfxSlider.focus_neighbor_bottom = muteCheck.get_path()
	if muteCheck and sfxSlider:
		muteCheck.focus_neighbor_top = sfxSlider.get_path()
		if settingsBackBtn: muteCheck.focus_neighbor_bottom = settingsBackBtn.get_path()
	if settingsBackBtn and muteCheck:
		settingsBackBtn.focus_neighbor_top = muteCheck.get_path()

func _switch_settings_tab(tabIdx: int) -> void:
	current_settings_tab = clampi(tabIdx, 0, 3)
	
	var audioP = _find_in_settings("AudioPanel")
	var gfxP = _find_in_settings("GraphicsPanel")
	var ctrlP = _find_in_settings("ControlsPanel")
	var langP = _find_in_settings("LanguagePanel")
	var panels = [audioP, gfxP, ctrlP, langP]
	
	var b0: Button = _find_in_settings("TabAudioBtn") as Button
	var b1: Button = _find_in_settings("TabGraphicsBtn") as Button
	var b2: Button = _find_in_settings("TabControlsBtn") as Button
	var b3: Button = _find_in_settings("TabLanguageBtn") as Button
	var buttons = [b0, b1, b2, b3]
	
	for i in range(panels.size()):
		var p = panels[i]
		if p: p.visible = (i == current_settings_tab)
		
	for i in range(buttons.size()):
		var b: Button = buttons[i]
		if b:
			if i == current_settings_tab:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(1.0, 0.88, 0.35, 0.18)
				sb.border_color = Color(1.0, 0.88, 0.35, 0.95)
				sb.set_border_width_all(2)
				sb.set_corner_radius_all(3)
				b.add_theme_stylebox_override("normal", sb)
			else:
				var empty := StyleBoxEmpty.new()
				b.add_theme_stylebox_override("normal", empty)
				
	if buttons[current_settings_tab]:
		buttons[current_settings_tab].grab_focus()

func _on_tab_focused(idx: int) -> void:
	if current_settings_tab != idx:
		_switch_settings_tab(idx)

func _on_master_slider_changed(v: float) -> void:
	var masterSlider: HSlider = _find_in_settings("MasterSlider") as HSlider
	var masterVal: Label = null
	if masterSlider:
		masterVal = masterSlider.get_parent().get_node_or_null("MasterValue") as Label
		if not masterVal: masterVal = masterSlider.get_parent().get_node_or_null("Value") as Label
	if not masterVal: masterVal = _find_in_settings("MasterValue") as Label
	if masterVal: masterVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("Master", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["master_volume"] = v

func _on_music_slider_changed(v: float) -> void:
	var musicSlider: HSlider = _find_in_settings("MusicSlider") as HSlider
	var musicVal: Label = null
	if musicSlider:
		musicVal = musicSlider.get_parent().get_node_or_null("MusicValue") as Label
		if not musicVal: musicVal = musicSlider.get_parent().get_node_or_null("Value") as Label
	if not musicVal: musicVal = _find_in_settings("MusicValue") as Label
	if musicVal: musicVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("MusicMenu", v)
	_set_bus_volume_percent("Music", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["music_volume"] = v
		Events.portal_sync.cosmetics_state["music_volume"] = v / 100.0

func _on_level_music_slider_changed(v: float) -> void:
	var levelMusicSlider: HSlider = _find_in_settings("LevelMusicSlider") as HSlider
	var levelMusicVal: Label = null
	if levelMusicSlider:
		levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("LevelMusicValue") as Label
		if not levelMusicVal: levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("Value") as Label
	if not levelMusicVal: levelMusicVal = _find_in_settings("LevelMusicValue") as Label
	if levelMusicVal: levelMusicVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("MusicLevel", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["level_music_volume"] = v

func _on_sfx_slider_changed(v: float) -> void:
	var sfxSlider: HSlider = _find_in_settings("SfxSlider") as HSlider
	var sfxVal: Label = null
	if sfxSlider:
		sfxVal = sfxSlider.get_parent().get_node_or_null("SfxValue") as Label
		if not sfxVal: sfxVal = sfxSlider.get_parent().get_node_or_null("Value") as Label
	if not sfxVal: sfxVal = _find_in_settings("SfxValue") as Label
	if sfxVal: sfxVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("SFX", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["sfx_volume"] = v
		Events.portal_sync.cosmetics_state["sfx_volume"] = v / 100.0

func _on_mute_check_toggled(toggled_on: bool) -> void:
	var m_idx = AudioServer.get_bus_index("Master")
	if m_idx != -1:
		AudioServer.set_bus_mute(m_idx, toggled_on)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["is_muted"] = toggled_on

func _populate_display_mode_opt(opt: OptionButton) -> void:
	opt.clear()
	if current_language == "en":
		opt.add_item("Fullscreen")
		opt.add_item("Windowed")
		opt.add_item("Borderless Window")
	else:
		opt.add_item("Pełny ekran (Fullscreen)")
		opt.add_item("Okno (Windowed)")
		opt.add_item("Okno bez ramek (Borderless)")
	
	var cur_mode = DisplayServer.window_get_mode()
	var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		opt.selected = 0
	elif is_borderless:
		opt.selected = 2
	else:
		opt.selected = 1
		
	if not opt.item_selected.is_connected(_on_display_mode_selected):
		opt.item_selected.connect(_on_display_mode_selected)

func _on_display_mode_selected(idx: int) -> void:
	match idx:
		0:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _populate_resolution_opt(opt: OptionButton) -> void:
	opt.clear()
	if current_language == "en":
		opt.add_item("1280 x 720 (HD)")
		opt.add_item("1920 x 1080 (FHD)")
		opt.add_item("640 x 360 (Native)")
	else:
		opt.add_item("1280 x 720 (HD)")
		opt.add_item("1920 x 1080 (FHD)")
		opt.add_item("640 x 360 (Natywna)")
		
	var cur_size = DisplayServer.window_get_size()
	if cur_size == Vector2i(1920, 1080):
		opt.selected = 1
	elif cur_size == Vector2i(640, 360):
		opt.selected = 2
	else:
		opt.selected = 0
		
	if not opt.item_selected.is_connected(_on_resolution_selected):
		opt.item_selected.connect(_on_resolution_selected)

func _on_resolution_selected(idx: int) -> void:
	var target_size := Vector2i(1280, 720)
	match idx:
		0: target_size = Vector2i(1280, 720)
		1: target_size = Vector2i(1920, 1080)
		2: target_size = Vector2i(640, 360)
		
	var cur_mode = DisplayServer.window_get_mode()
	if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var modeOpt: OptionButton = _find_in_settings("DisplayModeOpt") as OptionButton
		if modeOpt:
			modeOpt.selected = 1
			
	DisplayServer.window_set_size(target_size)
	var screen_id = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(screen_id)
	DisplayServer.window_set_position((screen_size - target_size) / 2)

func _populate_fps_limit_opt(opt: OptionButton) -> void:
	opt.clear()
	if current_language == "en":
		opt.add_item("60 FPS")
		opt.add_item("120 FPS")
		opt.add_item("Uncapped")
	else:
		opt.add_item("60 FPS")
		opt.add_item("120 FPS")
		opt.add_item("Bez limitu (Uncapped)")
		
	if Engine.max_fps == 60:
		opt.selected = 0
	elif Engine.max_fps == 120:
		opt.selected = 1
	else:
		opt.selected = 2
		
	if not opt.item_selected.is_connected(_on_fps_limit_selected):
		opt.item_selected.connect(_on_fps_limit_selected)

func _on_fps_limit_selected(idx: int) -> void:
	match idx:
		0: Engine.max_fps = 60
		1: Engine.max_fps = 120
		2: Engine.max_fps = 0

func _on_vsync_toggled(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func _on_subtitles_toggled(on: bool) -> void:
	subtitles_enabled = on

func _on_language_selected(idx: int) -> void:
	var code = "pl" if idx == 0 else "en"
	_apply_language(code)

func _apply_language(lang_code: String) -> void:
	current_language = lang_code
	TranslationServer.set_locale(lang_code)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.cosmetics_state["language"] = lang_code
	
	tabNames = ["AUDIO", "GRAPHICS", "CONTROLS", "LANGUAGE"] if current_language == "en" else ["MUZYKA", "GRAFIKA", "STEROWANIE", "JĘZYK"]
	
	# Update Audio Panel labels
	var masterLabel = _find_in_settings("AudioPanel/MasterBox/Label") as Label
	if masterLabel: masterLabel.text = "Master Volume:" if current_language == "en" else "Głośność ogólna:"
	var musicLabel = _find_in_settings("AudioPanel/MusicBox/Label") as Label
	if musicLabel: musicLabel.text = "Menu Music:" if current_language == "en" else "Muzyka w menu:"
	var levelMusicLabel = _find_in_settings("AudioPanel/LevelMusicBox/Label") as Label
	if levelMusicLabel: levelMusicLabel.text = "Level Music:" if current_language == "en" else "Muzyka w poziomie:"
	var sfxLabel = _find_in_settings("AudioPanel/SfxBox/Label") as Label
	if sfxLabel: sfxLabel.text = "Sound Effects (SFX):" if current_language == "en" else "Efekty dźwiękowe (SFX):"
	var muteCheck = _find_in_settings("AudioPanel/MuteCheck") as CheckBox
	if muteCheck: muteCheck.text = "Mute All Sounds" if current_language == "en" else "Wycisz wszystkie dźwięki (Mute All)"
	
	# Update Graphics Panel labels and options
	var modeLabel = _find_in_settings("GraphicsPanel/ModeBox/Label") as Label
	if modeLabel: modeLabel.text = "Display Mode:" if current_language == "en" else "Tryb wyświetlania:"
	var modeOpt = _find_in_settings("DisplayModeOpt") as OptionButton
	if modeOpt:
		var saved_mode = modeOpt.selected
		_populate_display_mode_opt(modeOpt)
		if saved_mode >= 0 and saved_mode < modeOpt.item_count:
			modeOpt.selected = saved_mode
			
	var resLabel = _find_in_settings("GraphicsPanel/ResBox/Label") as Label
	if resLabel: resLabel.text = "Window Resolution:" if current_language == "en" else "Rozdzielczość okna:"
	var resOpt = _find_in_settings("ResolutionOpt") as OptionButton
	if resOpt:
		var saved_res = resOpt.selected
		_populate_resolution_opt(resOpt)
		if saved_res >= 0 and saved_res < resOpt.item_count:
			resOpt.selected = saved_res
			
	var vsyncCheck = _find_in_settings("GraphicsPanel/VsyncCheck") as CheckBox
	if vsyncCheck: vsyncCheck.text = "Vertical Sync (V-Sync)" if current_language == "en" else "Synchronizacja pionowa (V-Sync)"
	
	var fpsLabel = _find_in_settings("GraphicsPanel/FpsBox/Label") as Label
	if fpsLabel: fpsLabel.text = "Frame Rate Limit (FPS):" if current_language == "en" else "Limit klatek (FPS):"
	var fpsOpt = _find_in_settings("FpsLimitOpt") as OptionButton
	if fpsOpt:
		var saved_fps = fpsOpt.selected
		_populate_fps_limit_opt(fpsOpt)
		if saved_fps >= 0 and saved_fps < fpsOpt.item_count:
			fpsOpt.selected = saved_fps
			
	# Update Controls Panel labels
	var ctrlGrid = _find_in_settings("ControlsPanel/Grid")
	if ctrlGrid:
		var a1 = ctrlGrid.get_node_or_null("Action1") as Label
		if a1: a1.text = "Horizontal Movement (Left / Right):" if current_language == "en" else "Ruch poziomy (Lewo / Prawo):"
		var k1 = ctrlGrid.get_node_or_null("Key1") as Label
		if k1: k1.text = "A / D  (or Arrows)" if current_language == "en" else "A / D  (lub Strzałki)"
		var a2 = ctrlGrid.get_node_or_null("Action2") as Label
		if a2: a2.text = "Jump / Double Jump:" if current_language == "en" else "Skok / Podwójny skok:"
		var k2 = ctrlGrid.get_node_or_null("Key2") as Label
		if k2: k2.text = "Space / W" if current_language == "en" else "Spacja / W"
		var a3 = ctrlGrid.get_node_or_null("Action3") as Label
		if a3: a3.text = "Dash:" if current_language == "en" else "Zryw (Dash):"
		var a4 = ctrlGrid.get_node_or_null("Action4") as Label
		if a4: a4.text = "Crouch / Slide:" if current_language == "en" else "Kucanie / Wślizg:"
		var k4 = ctrlGrid.get_node_or_null("Key4") as Label
		if k4: k4.text = "S / Down Arrow" if current_language == "en" else "S / Strzałka w dół"
		var a5 = ctrlGrid.get_node_or_null("Action5") as Label
		if a5: a5.text = "Wall Climb:" if current_language == "en" else "Wspinaczka (przy ścianie):"
		var a6 = ctrlGrid.get_node_or_null("Action6") as Label
		if a6: a6.text = "Mid-air Trick (Charges stamina):" if current_language == "en" else "Trick (w locie - ładuje staminę):"
		var k6 = ctrlGrid.get_node_or_null("Key6") as Label
		if k6: k6.text = "C (Hold in mid-air)" if current_language == "en" else "C (przytrzymaj w locie)"
		var a7 = ctrlGrid.get_node_or_null("Action7") as Label
		if a7: a7.text = "Pause:" if current_language == "en" else "Pauza:"
		
	# Update Language Panel labels
	var langLabel = _find_in_settings("LanguagePanel/LangBox/Label") as Label
	if langLabel: langLabel.text = "Game Language:" if current_language == "en" else "Język gry (Language):"
	var subsCheck = _find_in_settings("LanguagePanel/SubtitlesCheck") as CheckBox
	if subsCheck: subsCheck.text = "Display Subtitles" if current_language == "en" else "Wyświetlaj napisy dialogowe (Subtitles)"
	
	# Update LanguageOpt selection
	var langOpt = _find_in_settings("LanguageOpt") as OptionButton
	if langOpt:
		langOpt.selected = 0 if current_language == "pl" else 1

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
		game_over_focus_idx = 0
		_set_button_focus(game_over_buttons, 0)

func _on_player_hit(_damage: int) -> void:
	pass
