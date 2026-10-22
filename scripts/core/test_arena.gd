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

