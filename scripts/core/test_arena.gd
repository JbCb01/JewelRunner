extends Node2D

## Główny skrypt Areny Testowej
## Obsługuje restart, pauzę, zbieranie klejnotów, ekran porażki (Game Over) oraz ukończenie poziomu (Win Screen).

@onready var respawn_point: Marker2D = $RespawnPoint
@onready var hud_stamina_bar: ProgressBar = $HUD/StaminaPanel/HBox/HudStaminaBar
@onready var hud_score_label: Label = $HUD/ScorePanel/ScoreText if has_node("HUD/ScorePanel/ScoreText") else get_node_or_null("HUD/JewelPanel/JewelText")
@onready var hud_time_label: Label = $HUD.get_node_or_null("TimePanel/TimeText")
@onready var hud_session_label: Label = $HUD.get_node_or_null("SessionLabel")
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var game_over_menu: Control = $HUD/GameOverMenu
@onready var win_screen: Control = $HUD/WinScreen
@onready var win_score_label: Label = $HUD/WinScreen/ScoreResultText if has_node("HUD/WinScreen/ScoreResultText") else get_node_or_null("HUD/WinScreen/JewelResultText")
@onready var win_time_label: Label = $HUD/WinScreen.get_node_or_null("TimeResultText")
@onready var win_session_label: Label = $HUD/WinScreen.get_node_or_null("SessionResultText")

@onready var audio_pause: AudioStreamPlayer = $HUD/AudioPause
@onready var audio_win: AudioStreamPlayer = $HUD/AudioWin
@onready var audio_pickup: AudioStreamPlayer = $HUD/AudioPickup
@onready var music_level: AudioStreamPlayer = $MusicLevel if has_node("MusicLevel") else get_node_or_null("HUD/MusicLevel")

@onready var finish_goal: Area2D = $FinishGoal

var total_score: int = 0
var collected_jewels: int = 0
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
	
	# Inicjalizacja ID sesji i start zegara poziomu
	session_id = Events.generate_session_id()
	elapsed_time = 0.0
	is_timer_running = true
	
	if pause_menu: pause_menu.visible = false
	if game_over_menu: game_over_menu.visible = false
	if win_screen: win_screen.visible = false
	
	_update_score_hud()
	_update_time_hud()
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
	
	if finish_goal:
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
	_update_score_hud()
	if audio_pickup:
		audio_pickup.play()

func _on_score_added(amount: int) -> void:
	total_score += amount
	_update_score_hud()

func _update_score_hud() -> void:
	if hud_score_label:
		hud_score_label.text = " SCORE: %d " % total_score

func _on_goal_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_game_over and not is_stage_cleared:
		is_stage_cleared = true
		is_timer_running = false
		get_tree().paused = true
		Events.complete_level(1)
		
		if music_level:
			music_level.stop()
			
		if win_score_label:
			win_score_label.text = "SCORE: %d PTS" % total_score
			
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
	Events.player_died.emit()
