extends Node2D

## Główny skrypt Areny Poziomu (JewelRunner)
## Obsługuje:
## - Zbieranie wszystkich klejnotów (Jewels) jako warunek otwarcia wyjścia (FinishGoal)
## - Pomiar czasu ukończenia poziomu (bez konceptu Score)
## - Integrację z Adaptacyjnym Reżyserem AI (mnożniki staminy o stałej sumie, blokady przeciążonych ruchów, analiza poziomu)
## - Integrację z Generatorem Poziomów AI oraz adapterem pod przyszły TileSet (TileMapLayer)

const LevelGenerator = preload("res://scripts/core/level_generator.gd")
const CyberQuizScript = preload("res://scripts/core/cyber_quiz.gd")
const ControlsRebindUIScript = preload("res://scripts/core/controls_rebind_ui.gd")

@export var custom_tileset: TileSet = preload("res://assets/tileset_world.tres")

@onready var respawn_point: Marker2D = get_node_or_null("RespawnPoint")
@onready var hud_stamina_bar: ProgressBar = get_node_or_null("HUD/StaminaPanel/HBox/HudStaminaBar")
@onready var hud_score_label: Label = get_node_or_null("HUD/ScorePanel/ScoreText") if has_node("HUD/ScorePanel/ScoreText") else get_node_or_null("HUD/JewelPanel/JewelText")
@onready var hud_time_label: Label = get_node_or_null("HUD/TimePanel/TimeText")
@onready var hud_session_label: Label = get_node_or_null("HUD/SessionLabel")
@onready var hud_goal_bar: ProgressBar = get_node_or_null("HUD/ScorePanel/GoalBar")
@onready var hud_goal_flag: TextureRect = get_node_or_null("HUD/ScorePanel/GoalFlag")
@onready var hud_powerup_tray: HBoxContainer = get_node_or_null("HUD/PowerupTray")
var _hud_exit_was_open: bool = false
var _hud_low_stamina: bool = false
var _hud_blink_t: float = 0.0
var _powerup_chips: Dictionary = {}
# --- Combo tricków (HUD) ---
var _combo_panel: PanelContainer = null
var _combo_chain_label: Label = null
var _combo_value_label: Label = null
var _combo_hold_t: float = 0.0
var _combo_pop_t: float = 0.0
var _stamina_overflow_bar: ProgressBar = null
var _stamina_overflow_amount: float = 0.0
var combos_finished_count: int = 0
var best_combo_count: int = 0
var is_hud_visible: bool = true
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
@onready var audio_game_over: AudioStreamPlayer = get_node_or_null("HUD/AudioGameOver")
@onready var audio_pickup: AudioStreamPlayer = get_node_or_null("HUD/AudioPickup")
@onready var music_level: AudioStreamPlayer = get_node_or_null("MusicLevel") if has_node("MusicLevel") else get_node_or_null("HUD/MusicLevel")

const LEVEL_MUSIC_TRACKS: Dictionary = {
	1: preload("res://audio/music/yessirski.wav"),
	2: preload("res://audio/music/onmymommaimthegoat.wav"),
	3: preload("res://audio/music/onsumbull.wav"),
}

const SZACHOWNICA_SHUFFLE_FOLDER := "res://audio/music/Szachownica shuffle"

const DEFAULT_SZACHOWNICA_SHUFFLE_TRACKS: Array[String] = [
	"res://audio/music/Szachownica shuffle/Bad Piggies Theme.wav",
	"res://audio/music/Szachownica shuffle/Color Your Night.wav",
	"res://audio/music/Szachownica shuffle/Feel The Heat - SEGA Bass Fishing Music (HD).wav",
	"res://audio/music/Szachownica shuffle/SENTINO - BLACKBERRY ALE TO HYMN DOŻYNEK.wav",
	"res://audio/music/Szachownica shuffle/Sneakman.wav",
	"res://audio/music/Szachownica shuffle/Sonic Riders Zero Gravity Main Menu Theme.wav",
	"res://audio/music/Szachownica shuffle/Sonic Speed Riders - Sonic Riders [OST].wav",
	"res://audio/music/Szachownica shuffle/Tropical Resort (Act 1) - Sonic Colors [OST].wav",
	"res://audio/music/Szachownica shuffle/Vs. Metal Sonic (Stardust Speedway Bad Future JP) - Sonic Generations [OST].wav",
	"res://audio/music/Szachownica shuffle/Work It Out (Instrumental) - Sonic R [OST].wav"
]

## Zwraca listę wszystkich dostępnych ścieżek audio z folderu 'Szachownica shuffle'.
static func get_szachownica_shuffle_tracks() -> Array[String]:
	var tracks: Array[String] = []
	var dir = DirAccess.open(SZACHOWNICA_SHUFFLE_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var lower = file_name.to_lower()
				if lower.ends_with(".wav") or lower.ends_with(".ogg") or lower.ends_with(".mp3"):
					tracks.append(SZACHOWNICA_SHUFFLE_FOLDER + "/" + file_name)
			file_name = dir.get_next()
	if tracks.is_empty():
		tracks = DEFAULT_SZACHOWNICA_SHUFFLE_TRACKS.duplicate()
	else:
		tracks.sort()
	return tracks

## Wybiera losową ścieżkę z folderu 'Szachownica shuffle', unikając powtórzenia ostatniego utworu.
static func get_random_szachownica_shuffle_path() -> String:
	var tracks: Array[String] = get_szachownica_shuffle_tracks()
	if tracks.is_empty():
		return "res://audio/music/onsumbull.wav"
	if tracks.size() == 1:
		return tracks[0]
	
	var last_path: String = ""
	if is_instance_valid(Events):
		last_path = Events.last_szachownica_music_path
	
	var candidates: Array[String] = []
	for p in tracks:
		if p != last_path:
			candidates.append(p)
	if candidates.is_empty():
		candidates = tracks.duplicate()
	
	var chosen: String = candidates[randi() % candidates.size()]
	if is_instance_valid(Events):
		Events.last_szachownica_music_path = chosen
	return chosen

## Zwraca losowy AudioStream z puli 'Szachownica shuffle'.
static func get_random_szachownica_shuffle_stream() -> AudioStream:
	var path: String = get_random_szachownica_shuffle_path()
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		return stream
	return LEVEL_MUSIC_TRACKS.get(3, null)

## Zwraca ścieżkę dźwiękową AudioStream dla wybranego poziomu/profilu.
## Poziom 1: yessirski.wav
## Poziomy 2 i 3: nowe ścieżki dźwiękowe dodane przez merkoo (onmymommaimthegoat.wav, onsumbull.wav)
## Poziom 4 (Cyber Shuffle / Szachownica AI): losowa muzyka z folderu 'Szachownica shuffle'
static func get_level_music_stream(profile_id: int) -> AudioStream:
	if profile_id == 4:
		return get_random_szachownica_shuffle_stream()
	if LEVEL_MUSIC_TRACKS.has(profile_id):
		return LEVEL_MUSIC_TRACKS[profile_id]
	return LEVEL_MUSIC_TRACKS.get(1, null)

## Konfiguruje i uruchamia odtwarzanie muzyki dla wskazanego poziomu.
func _setup_level_music(profile_id: int) -> void:
	if not music_level:
		return
	var stream: AudioStream = get_level_music_stream(profile_id)
	if stream:
		if music_level.stream != stream:
			music_level.stop()
			music_level.stream = stream
	if music_level.stream is AudioStreamWAV:
		(music_level.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	if not music_level.finished.is_connected(_on_music_level_finished):
		if music_level.finished.is_connected(music_level.play):
			music_level.finished.disconnect(music_level.play)
		music_level.finished.connect(_on_music_level_finished)
	if music_level.is_inside_tree() and not music_level.playing:
		music_level.play()

func _on_music_level_finished() -> void:
	if not music_level:
		return
	var current_profile: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	if current_profile == 4:
		var stream: AudioStream = get_random_szachownica_shuffle_stream()
		if stream:
			music_level.stream = stream
			if music_level.stream is AudioStreamWAV:
				(music_level.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
			music_level.play()
	else:
		music_level.play()

@onready var finish_goal: Area2D = get_node_or_null("FinishGoal")

const MULT_COLOR_IDLE := Color(0.78, 0.74, 0.80, 0.85)
const MULT_COLOR_UP := Color8(107, 201, 108)
const MULT_COLOR_DOWN := Color8(234, 98, 98)
const MULT_COLOR_LOCKED := Color8(238, 143, 203)

# --- Pikselowy HUD (paleta gry) ---
const HUD_FONT_PATHS: Array[String] = ["res://assets/ui/hud/hud_font.fnt", "res://assets/ui/hud/hud_font_big.fnt"]
const HUD_ICONS_PATH := "res://assets/ui/hud/hud_icons.png"
const HUD_CHIP_PATH := "res://assets/ui/hud/hud_chip.png"
const HUD_ICON_INDEX: Dictionary = {"shield": 8, "speed": 9, "star": 10}
const STAMINA_COLORS: Array[Color] = [Color8(107, 201, 108), Color8(252, 239, 141), Color8(234, 98, 98)]
const GOAL_COLOR_LOCKED := Color8(212, 110, 179)
const COMBO_COLOR := Color8(252, 239, 141)
const COMBO_FINISH_COLOR := Color8(255, 170, 222)
const COMBO_BAIL_COLOR := Color8(234, 98, 98)
const OVERFLOW_COLOR := Color8(255, 196, 72)
const TRICK_LABELS: Dictionary = {"flip": ["SALTO", "FLIP"], "star": ["GWIAZDA", "STAR"], "finish": ["FINAŁ", "FINALE"]}
const GOAL_COLOR_OPEN := Color8(171, 221, 100)
const MULT_HOLD_DURATION: float = 0.45
const MULT_FADE_SPEED: float = 0.55

var hud_ai_label: Label = null
var hud_ai_panel: PanelContainer = null
var hud_mult_labels: Dictionary = {}
var hud_status_toast: Label = null
var status_toast_timer: float = 0.0
var hud_wallet_label: Label = null

var mult_ref_values: Dictionary = {"double_jump": 1.0, "wall_climb": 1.0, "dash": 1.0}
var mult_last_tenths: Dictionary = {"double_jump": 10, "wall_climb": 10, "dash": 10}
var mult_trends: Dictionary = {"double_jump": 0, "wall_climb": 0, "dash": 0}
var mult_highlights: Dictionary = {"double_jump": 0.0, "wall_climb": 0.0, "dash": 0.0}
var mult_hold_timers: Dictionary = {"double_jump": 0.0, "wall_climb": 0.0, "dash": 0.0}
var _mult_hud_initialized: bool = false

var jewel_anim_batch_count: int = 0
var jewel_anim_timer: float = 0.0
var jewel_hud_scale: float = 1.0
const JEWEL_ANIM_BATCH_WINDOW_S: float = 0.6

var is_knowledge_check_active: bool = false
var current_quiz_question: Dictionary = {}
var quiz_focus_idx: int = 0
var quiz_buttons: Array[Button] = []
var quiz_answered_correctly: bool = false

var total_score: int = 0
var collected_jewels: int = 0
var total_jewels: int = 0
var tricks_performed_count: int = 0
var enemies_defeated_count: int = 0
var _double_points_reported: bool = false
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
var controls_rebind_ui: ControlsRebindUIScript = null

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
	enemies_defeated_count = 0
	_double_points_reported = false
	
	# Budowa poziomu wg wybranego w Level Select profilu mechaniki (oraz przygotowanie warstwy TileMapLayer)
	var profile_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	var seed_val: int = Events.selected_level_seed if is_instance_valid(Events) else 0
	if profile_id != 1:
		var gen_res: Dictionary = LevelGenerator.build_level_for_arena(self, profile_id, seed_val, custom_tileset)
		challenge_time_limit_s = float(gen_res.get("challenge_max_time_s", -1.0))
		
	# Zliczenie wszystkich klejnotów na poziomie (wymaganych do odblokowania wyjścia)
	refresh_jewel_count()
	
	# Reset sesji AI Directora i analiza geometrii bieżącego poziomu
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		Events.ai_director.reset_session_state(true)
		Events.ai_director.analyze_level(self)
	
	# Inicjalizacja ID sesji i start zegara poziomu (startuje po animacji appear)
	session_id = Events.generate_session_id()
	elapsed_time = 0.0
	is_timer_running = false
	_report_active_life_booster()
	
	if pause_menu: pause_menu.visible = false
	if settings_view: settings_view.visible = false
	if game_over_menu: game_over_menu.visible = false
	if win_screen: win_screen.visible = false
	
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var saved_lang = String(Events.portal_sync.cosmetics_state.get("language", Events.portal_sync.profile_settings.get("language", "pl")))
		_apply_language(saved_lang)
	
	_setup_hud_fonts()
	_setup_combo_hud()
	_apply_pixel_font_to_level_labels()
	_refresh_dynamic_control_labels()
	_ensure_ai_hud_panel()
	_update_score_hud()
	_update_time_hud()
	_update_goal_visuals()
	_update_ai_hud()
	
	if hud_session_label:
		hud_session_label.text = "ID: %s" % session_id
		
	_setup_level_music(profile_id)
	_ensure_game_over_audio()
	
	Events.player_died.connect(_on_player_died)
	Events.player_hit.connect(_on_player_hit)
	Events.player_stamina_changed.connect(_on_player_stamina_changed)
	Events.jewel_collected.connect(_on_jewel_collected)
	Events.score_added.connect(_on_score_added)
	Events.stamina_multipliers_updated.connect(_on_multipliers_updated)
	Events.mechanic_lockout_changed.connect(_on_mechanic_lockout_changed)
	Events.stamina_action_rejected.connect(_on_stamina_action_rejected)
	Events.trick_performed.connect(_on_trick_performed)
	Events.trick_combo_updated.connect(_on_trick_combo_updated)
	Events.trick_combo_ended.connect(_on_trick_combo_ended)
	Events.enemy_defeated.connect(_on_enemy_defeated)
	Events.cursed_jewel_triggered.connect(_on_cursed_jewel_triggered)
	Events.portal_profile_synced.connect(_on_arena_portal_profile_synced)
	Events.special_jewel_collected.connect(_on_special_jewel_collected)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)
	Events.player_appear_finished.connect(_on_player_appear_finished)
	if not Events.keybinds_changed.is_connected(_on_keybinds_changed):
		Events.keybinds_changed.connect(_on_keybinds_changed)
	
	# Bezpiecznik: jeśli po 3.0s animacja lub sygnał nie wystąpiły, uruchom zegar
	get_tree().create_timer(3.0).timeout.connect(func():
		if not is_timer_running and not is_stage_cleared and not is_game_over:
			is_timer_running = true
	)
	
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
		_update_jewel_hud_animation(delta)
		_update_multiplier_hud_highlights(delta)
		_update_status_toast(delta)
		_update_hud_effects(delta)

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

## Zwraca liczbę klejnotów wymaganą do odblokowania wyjścia (minimum połowa wszystkich).
func get_required_jewel_count() -> int:
	return maxi(1, int(ceil(float(total_jewels) * 0.5)))

## Sprawdza, czy gracz zebrał wymaganą liczbę klejnotów (minimum połowę) do opuszczenia poziomu.
func can_exit_level() -> bool:
	return collected_jewels >= get_required_jewel_count()

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	var tenths := int((seconds - int(seconds)) * 10)
	return "%02d:%02d.%d" % [mins, secs, tenths]

func _update_time_hud() -> void:
	if hud_time_label:
		hud_time_label.text = _format_time(elapsed_time)

func _on_player_stamina_changed(current: float, max_stamina: float) -> void:
	if hud_stamina_bar:
		hud_stamina_bar.max_value = max_stamina
		hud_stamina_bar.value = current
		if hud_stamina_bar.has_theme_stylebox_override("fill"):
			var fill_sb := hud_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill_sb:
				var ratio: float = current / maxf(0.01, max_stamina)
				var col: Color = STAMINA_COLORS[0] if ratio > 0.5 else (STAMINA_COLORS[1] if ratio > 0.25 else STAMINA_COLORS[2])
				fill_sb.bg_color = col
				fill_sb.border_color = col.lightened(0.35)
				_hud_low_stamina = ratio <= 0.25
	# Overflow staminy z combo: złota warstwa nad pełnym paskiem
	_stamina_overflow_amount = maxf(0.0, current - max_stamina)
	if _stamina_overflow_bar:
		_stamina_overflow_bar.max_value = max_stamina
		_stamina_overflow_bar.value = minf(_stamina_overflow_amount, max_stamina)
		_stamina_overflow_bar.visible = _stamina_overflow_amount > 0.001

func _report_active_life_booster() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	if not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync) or not Events.portal_sync.is_linked:
		return
	if session_id.is_empty():
		return
	for p in get_tree().get_nodes_in_group("player"):
		if p and p.get_meta("has_portal_extra_life", false) and not bool(p.get_meta("portal_life_reported", false)):
			p.set_meta("portal_life_reported", true)
			Events.portal_sync.report_booster_used("dodatkowe życie", session_id + "-life")
			break

func _on_arena_portal_profile_synced(_profile_state: Dictionary) -> void:
	_report_active_life_booster()

func _has_portal_double_points() -> bool:
	if not is_inside_tree():
		return false
	for p in get_tree().get_nodes_in_group("player"):
		if p and bool(p.get_meta("has_portal_double_points", false)):
			if not _double_points_reported and DisplayServer.get_name() != "headless" and is_instance_valid(Events) and is_instance_valid(Events.portal_sync) and Events.portal_sync.is_linked:
				_double_points_reported = true
				Events.portal_sync.report_booster_used("podwójne punkty", session_id + "-dblpts")
			return true
	return false

func _on_jewel_collected(val: int, _pos: Vector2) -> void:
	collected_jewels += 1
	total_score += (val * 2) if _has_portal_double_points() else val
	Events.jewels_progress_updated.emit(collected_jewels, total_jewels)
	_update_score_hud()
	_trigger_grouped_jewel_hud_animation(1)
	_update_goal_visuals()
	if total_jewels > 0 and collected_jewels >= total_jewels:
		Events.all_jewels_collected.emit()
	if audio_pickup:
		audio_pickup.play()

func get_total_wallet_balance() -> int:
	var synced_bal: int = 0
	if is_instance_valid(Events) and is_instance_valid(Events.wallet_sync) and Events.wallet_sync.has_method("local_balance"):
		synced_bal = int(Events.wallet_sync.local_balance())
	return synced_bal + collected_jewels

func _trigger_grouped_jewel_hud_animation(added_count: int = 1) -> void:
	if jewel_anim_timer > 0.0:
		jewel_anim_batch_count += added_count
	else:
		jewel_anim_batch_count = added_count
	jewel_anim_timer = JEWEL_ANIM_BATCH_WINDOW_S
	jewel_hud_scale = minf(1.4, 1.12 + 0.04 * float(jewel_anim_batch_count))
	if hud_score_label:
		hud_score_label.pivot_offset = hud_score_label.size * 0.5
		hud_score_label.scale = Vector2(jewel_hud_scale, jewel_hud_scale)
	if hud_wallet_label:
		hud_wallet_label.text = "%d (+%d)" % [get_total_wallet_balance(), jewel_anim_batch_count]

func _update_jewel_hud_animation(delta: float) -> void:
	if jewel_anim_timer <= 0.0:
		return
	jewel_anim_timer = maxf(0.0, jewel_anim_timer - delta)
	jewel_hud_scale = move_toward(jewel_hud_scale, 1.0, delta * 0.8)
	if hud_score_label:
		hud_score_label.scale = Vector2(jewel_hud_scale, jewel_hud_scale)
	if jewel_anim_timer <= 0.0:
		jewel_anim_batch_count = 0
		jewel_hud_scale = 1.0
		if hud_score_label:
			hud_score_label.scale = Vector2.ONE
		if hud_wallet_label:
			hud_wallet_label.text = "%d" % get_total_wallet_balance()

func _on_special_jewel_collected(_special_id: String, jewel_name: String, rarity: String, already_owned: bool) -> void:
	if already_owned:
		_show_hud_toast("[*] JUŻ POSIADANY: %s (zwykłe punkty)" % jewel_name, Color(0.8, 0.85, 0.9, 1.0))
	else:
		_show_hud_toast("[★] SEKRETNY KLEJNOT: %s [%s]!" % [jewel_name, rarity.to_upper()], Color(1.0, 0.9, 0.35, 1.0))

func _on_checkpoint_reached(_checkpoint_id: String, pos: Vector2) -> void:
	if respawn_point:
		respawn_point.global_position = pos

func _on_player_appear_finished() -> void:
	is_timer_running = true
	elapsed_time = 0.0
	_update_time_hud()

func _on_score_added(amount: int) -> void:
	total_score += (amount * 2) if _has_portal_double_points() else amount

func _on_trick_performed(_pts: int) -> void:
	tricks_performed_count += 1

func _on_enemy_defeated() -> void:
	enemies_defeated_count += 1

func _on_cursed_jewel_triggered(mechanic_name: String, duration: float) -> void:
	_show_hud_toast("[!] PRZEKLĘTY KLEJNOT! Utracono %s na %.1fs!" % [mechanic_name.to_upper(), duration], Color(1.0, 0.45, 0.85, 1.0), 3.0)

func _update_score_hud() -> void:
	if hud_score_label:
		if total_jewels > 0:
			hud_score_label.text = " JEWELS: %d/%d " % [collected_jewels, total_jewels]
		else:
			hud_score_label.text = " JEWELS: %d " % collected_jewels
	if hud_wallet_label and jewel_anim_timer <= 0.0:
		hud_wallet_label.text = "%d" % get_total_wallet_balance()
	_update_goal_bar()

## Pasek postępu do wyjścia: flaga stoi w miejscu wymaganej połowy klejnotów, po jej osiągnięciu pasek zielenieje.
func _update_goal_bar() -> void:
	if not hud_goal_bar:
		return
	var total: int = maxi(1, total_jewels)
	hud_goal_bar.max_value = float(total)
	hud_goal_bar.value = float(collected_jewels)
	var open: bool = total_jewels > 0 and can_exit_level()
	var fill_sb := hud_goal_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_sb:
		fill_sb.bg_color = GOAL_COLOR_OPEN if open else GOAL_COLOR_LOCKED
		fill_sb.border_color = fill_sb.bg_color.lightened(0.4)
	if hud_goal_flag:
		var frac: float = float(get_required_jewel_count()) / float(total)
		hud_goal_flag.position.x = hud_goal_bar.position.x + roundf(hud_goal_bar.size.x * frac) - 2.0
		hud_goal_flag.modulate = Color(0.75, 1.0, 0.6, 1.0) if open else Color(1, 1, 1, 1)
	if open and not _hud_exit_was_open and collected_jewels > 0 and is_inside_tree():
		_show_hud_toast("WYJŚCIE OTWARTE! Zebrano %d/%d klejnotów" % [collected_jewels, total_jewels], Color8(171, 221, 100), 2.6)
	_hud_exit_was_open = open

func _update_goal_visuals() -> void:
	if not finish_goal:
		return
	var lbl: Label = finish_goal.get_node_or_null("LabelGoal")
	var aura: ColorRect = finish_goal.get_node_or_null("Aura")
	var unlocked: bool = can_exit_level()
	var req: int = get_required_jewel_count()
	if lbl:
		if unlocked:
			lbl.text = "EXIT OPEN"
			lbl.modulate = Color(0.4, 1.0, 0.6, 1.0)
		else:
			lbl.text = "LOCKED %d/%d" % [collected_jewels, req]
			lbl.modulate = Color(1.0, 0.55, 0.45, 1.0)
	if aura:
		aura.color = Color(0.2, 0.9, 0.7, 0.38) if unlocked else Color(0.9, 0.25, 0.25, 0.30)

func _make_hud_pill_style(bg_alpha: float = 0.72) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, bg_alpha)
	sb.border_color = Color(0.32, 0.42, 0.58, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb

## Pikselowa czcionka HUD nie ma polskich znaków – brakujące glify bierze z domyślnej czcionki.
func _setup_hud_fonts() -> void:
	for path in HUD_FONT_PATHS:
		if ResourceLoader.exists(path):
			var f := load(path) as Font
			if f and f.fallbacks.is_empty() and ThemeDB.fallback_font:
				f.fallbacks = [ThemeDB.fallback_font]

## Napisy w świecie gry (podpowiedzi, tablica analizy AI) tą samą pikselową czcionką co HUD (rozmiar 2x).
func _apply_pixel_font_to_level_labels() -> void:
	var labels_root: Node = get_node_or_null("Labels")
	if not labels_root or not ResourceLoader.exists(HUD_FONT_PATHS[1]):
		return
	var big := load(HUD_FONT_PATHS[1]) as Font
	for lbl in labels_root.get_children():
		if lbl is Label:
			lbl.add_theme_font_override("font", big)
			lbl.add_theme_constant_override("outline_size", 0)
			lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _refresh_dynamic_control_labels() -> void:
	var labels_root: Node = get_node_or_null("Labels")
	if not labels_root or not is_instance_valid(Events):
		return
	for lbl in labels_root.get_children():
		if lbl is Label:
			var tmpl: String = String(lbl.get_meta("keybind_template", ""))
			if tmpl.is_empty():
				tmpl = Events.normalize_legacy_keybind_template(lbl.text)
				lbl.set_meta("keybind_template", tmpl)
			lbl.text = Events.format_keybind_text(tmpl, current_language)

func _on_keybinds_changed() -> void:
	_refresh_dynamic_control_labels()
	_apply_language(current_language)

func _update_hud_effects(delta: float) -> void:
	_hud_blink_t += delta
	# Ostrzeżenie o niskiej staminie: pulsujący pasek
	if hud_stamina_bar:
		if _hud_low_stamina:
			var a: float = 0.55 + 0.45 * absf(sin(_hud_blink_t * 7.0))
			hud_stamina_bar.modulate = Color(1, 1, 1, a)
		else:
			hud_stamina_bar.modulate = Color.WHITE
	if _stamina_overflow_bar and _stamina_overflow_bar.visible:
		_stamina_overflow_bar.modulate = Color(1, 1, 1, 0.78 + 0.22 * sin(_hud_blink_t * 5.0))
	_update_combo_hud(delta)
	_update_powerup_tray()

## Tworzy panel combo (góra-środek) i złotą warstwę overflow na pasku staminy.
func _setup_combo_hud() -> void:
	var hud: Node = get_node_or_null("HUD")
	if not hud:
		return
	if hud_stamina_bar and not _stamina_overflow_bar:
		_stamina_overflow_bar = ProgressBar.new()
		_stamina_overflow_bar.name = "OverflowBar"
		_stamina_overflow_bar.show_percentage = false
		_stamina_overflow_bar.step = 0.0
		_stamina_overflow_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stamina_overflow_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_stamina_overflow_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		_stamina_overflow_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		var fill := StyleBoxFlat.new()
		fill.bg_color = OVERFLOW_COLOR
		fill.border_color = OVERFLOW_COLOR.lightened(0.45)
		fill.border_width_top = 1
		_stamina_overflow_bar.add_theme_stylebox_override("fill", fill)
		_stamina_overflow_bar.visible = false
		hud_stamina_bar.add_child(_stamina_overflow_bar)
		var ticks: Node = hud_stamina_bar.get_node_or_null("Ticks")
		if ticks:
			hud_stamina_bar.move_child(ticks, -1)
	if _combo_panel:
		return
	_combo_panel = PanelContainer.new()
	_combo_panel.name = "ComboPanel"
	_combo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sb := StyleBoxTexture.new()
	if ResourceLoader.exists(HUD_CHIP_PATH):
		sb.texture = load(HUD_CHIP_PATH)
	sb.set_texture_margin_all(3.0)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	_combo_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_combo_panel.add_child(vb)
	_combo_chain_label = Label.new()
	_combo_chain_label.name = "ComboChain"
	_combo_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_value_label = Label.new()
	_combo_value_label.name = "ComboValue"
	_combo_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(HUD_FONT_PATHS[0]):
		_combo_chain_label.add_theme_font_override("font", load(HUD_FONT_PATHS[0]))
	if ResourceLoader.exists(HUD_FONT_PATHS[1]):
		_combo_value_label.add_theme_font_override("font", load(HUD_FONT_PATHS[1]))
	_combo_chain_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.92, 1.0))
	vb.add_child(_combo_chain_label)
	vb.add_child(_combo_value_label)
	_combo_panel.visible = false
	hud.add_child(_combo_panel)
	# Pod menu (pauza / game over / wygrana / ustawienia): zaraz za paskiem komunikatów
	var first_menu: int = hud.get_child_count() - 1
	for m in [pause_menu, settings_view, game_over_menu, win_screen]:
		if m and m.get_parent() == hud:
			first_menu = mini(first_menu, m.get_index())
	hud.move_child(_combo_panel, first_menu)

## Natychmiast chowa panel combo (game over, pauza, ukończenie poziomu).
func _hide_combo_hud() -> void:
	if _combo_panel:
		_combo_panel.visible = false
		_combo_hold_t = 0.0

func _trick_label(kind: String) -> String:
	var pair: Array = TRICK_LABELS.get(kind, [kind.to_upper(), kind.to_upper()])
	return String(pair[1] if current_language == "en" else pair[0])

func _show_combo(chain: String, value: String, color: Color, hold: float) -> void:
	if not _combo_panel:
		return
	_combo_chain_label.text = chain
	_combo_value_label.text = value
	_combo_value_label.add_theme_color_override("font_color", color)
	_combo_panel.visible = is_hud_visible
	_combo_panel.modulate.a = 1.0
	_combo_hold_t = hold
	_combo_pop_t = 0.18
	_combo_panel.size = Vector2.ZERO
	_combo_panel.reset_size()
	_update_combo_hud(0.0)

func _on_trick_combo_updated(tricks: Array, payout: float, finished: bool) -> void:
	if finished:
		return  # wypłatę pokazuje _on_trick_combo_ended
	var names: PackedStringArray = []
	for t in tricks:
		names.append(_trick_label(String(t)))
	var hint: String = ""
	if tricks.size() >= 2:
		var fk: String = Events.get_action_key_label("trick_finish", current_language) if is_instance_valid(Events) else "C"
		hint = ("  [%s] FINALE!" if current_language == "en" else "  [%s] FINAŁ!") % fk
	_show_combo(" > ".join(names), "x%d  +%.2f%s" % [tricks.size(), payout, hint], COMBO_COLOR, 99.0)

func _on_trick_combo_ended(count: int, stamina_gained: float, finished: bool, bailed: bool) -> void:
	if bailed:
		_show_combo("COMBO x%d" % count, "BAILED!" if current_language == "en" else "WPADKA!", COMBO_BAIL_COLOR, 1.1)
		return
	best_combo_count = maxi(best_combo_count, count)
	if finished:
		combos_finished_count += 1
		var title: String = "GRAND FINALE" if current_language == "en" else "WIELKI FINAŁ"
		var over: String = "  OVERFLOW!" if _stamina_overflow_amount > 0.001 else ""
		_show_combo("%s  x%d" % [title, count], "+%.2f STAMINA%s" % [stamina_gained, over], COMBO_FINISH_COLOR, 1.6)
	else:
		_show_combo("COMBO x%d" % count, "+%.2f STAMINA" % stamina_gained, COMBO_COLOR, 1.2)

func _update_combo_hud(delta: float) -> void:
	if not _combo_panel or not _combo_panel.visible:
		return
	var vp_w: float = 640.0
	if is_inside_tree():
		vp_w = get_viewport().get_visible_rect().size.x
	_combo_pop_t = maxf(0.0, _combo_pop_t - delta)
	var pop: float = 1.0 + 0.6 * _combo_pop_t
	_combo_panel.pivot_offset = _combo_panel.size * 0.5
	_combo_panel.scale = Vector2(pop, pop)
	# Pod górnymi panelami HUD; gdy długi komunikat zajmuje pasek y=90, panel combo schodzi niżej
	var combo_y: float = 92.0
	if hud_status_toast and hud_status_toast.visible and hud_status_toast.position.y >= 80.0:
		combo_y = 92.0 + hud_status_toast.size.y + 4.0
	_combo_panel.position = Vector2(roundf((vp_w - _combo_panel.size.x) * 0.5), combo_y)
	_combo_hold_t -= delta
	if _combo_hold_t <= 0.0:
		_combo_panel.modulate.a = maxf(0.0, _combo_panel.modulate.a - delta * 2.5)
		if _combo_panel.modulate.a <= 0.0:
			_combo_panel.visible = false

func _hud_icon(index: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(HUD_ICONS_PATH)
	at.region = Rect2(index * 12, 0, 12, 12)
	return at

## Aktywne wzmocnienia (tarcza, przyspieszenie, nieśmiertelność) jako chipy z ikoną i licznikiem czasu.
func _update_powerup_tray() -> void:
	if not hud_powerup_tray or not is_inside_tree():
		return
	var plr: Node = get_tree().get_first_node_in_group("player")
	if not plr:
		return
	var active: Dictionary = {}
	var t_inv: float = float(plr.get("invincibility_powerup_timer")) if plr.get("invincibility_powerup_timer") != null else 0.0
	var t_spd: float = float(plr.get("speed_powerup_timer")) if plr.get("speed_powerup_timer") != null else 0.0
	if plr.has_method("get_powerup_time_left"):
		t_inv = maxf(t_inv, float(plr.call("get_powerup_time_left", "INVINCIBILITY")))
		t_spd = maxf(t_spd, float(plr.call("get_powerup_time_left", "SPEED_BOOST")))
	if t_inv > 0.0:
		active["star"] = "%.1fs" % t_inv
	if t_spd > 0.0:
		active["speed"] = "%.1fs" % t_spd
	if bool(plr.get("has_shield")) or bool(plr.get_meta("has_portal_shield", false)):
		active["shield"] = "x1"
	for key in _powerup_chips.keys():
		if not active.has(key):
			var old: Node = _powerup_chips[key]
			if is_instance_valid(old):
				old.queue_free()
			_powerup_chips.erase(key)
	for key in active.keys():
		var chip: PanelContainer = _powerup_chips.get(key) as PanelContainer
		if not is_instance_valid(chip):
			chip = PanelContainer.new()
			chip.name = "Powerup_%s" % key
			chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var sb := StyleBoxTexture.new()
			sb.texture = load(HUD_CHIP_PATH)
			sb.set_texture_margin_all(3.0)
			sb.content_margin_left = 4.0
			sb.content_margin_right = 5.0
			sb.content_margin_top = 2.0
			sb.content_margin_bottom = 2.0
			chip.add_theme_stylebox_override("panel", sb)
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 3)
			chip.add_child(hb)
			var ic := TextureRect.new()
			ic.texture = _hud_icon(int(HUD_ICON_INDEX[key]))
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			ic.custom_minimum_size = Vector2(12, 12)
			hb.add_child(ic)
			var lb := Label.new()
			lb.name = "Time"
			if ResourceLoader.exists(HUD_FONT_PATHS[0]):
				lb.add_theme_font_override("font", load(HUD_FONT_PATHS[0]))
			lb.add_theme_color_override("font_color", Color8(252, 239, 141) if key == "star" else (Color8(171, 221, 100) if key == "speed" else Color8(174, 226, 255)))
			hb.add_child(lb)
			hud_powerup_tray.add_child(chip)
			_powerup_chips[key] = chip
		var tl := chip.find_child("Time", true, false) as Label
		if tl:
			tl.text = String(active[key])
		# miganie w ostatnich 2 sekundach
		var secs: float = String(active[key]).to_float()
		chip.modulate.a = (0.5 + 0.5 * absf(sin(_hud_blink_t * 10.0))) if (secs > 0.0 and secs < 2.0) else 1.0

func _ensure_ai_hud_panel() -> void:
	var hud: Node = get_node_or_null("HUD")
	if not hud:
		return

	# Stary napis sterowania i szeroki napis AIMultipliersLabel nie są już używane
	var old_controls := hud.get_node_or_null("ControlsPanel")
	if old_controls:
		old_controls.queue_free()
	var legacy_ai := hud.get_node_or_null("AIMultipliersLabel")
	if legacy_ai:
		legacy_ai.queue_free()

	# 1. Pigułka portfela w górnym pasku (x=286..392, y=8..32)
	var wallet_panel := hud.get_node_or_null("WalletPanel") as PanelContainer
	if not wallet_panel:
		wallet_panel = PanelContainer.new()
		wallet_panel.name = "WalletPanel"
		wallet_panel.position = Vector2(286, 8)
		wallet_panel.size = Vector2(106, 24)
		wallet_panel.add_theme_stylebox_override("panel", _make_hud_pill_style(0.72))
		hud.add_child(wallet_panel)

	hud_wallet_label = wallet_panel.find_child("WalletBalanceLabel", true, false) as Label
	if not hud_wallet_label:
		hud_wallet_label = Label.new()
		hud_wallet_label.name = "WalletBalanceLabel"
		hud_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hud_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hud_wallet_label.add_theme_font_size_override("font_size", 10)
		hud_wallet_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42, 0.96))
		wallet_panel.add_child(hud_wallet_label)
	hud_wallet_label.text = "%d" % get_total_wallet_balance()

	# 2. Minimalistyczna pigułka mnożników w 2. wierszu (y=37..57)
	hud_ai_panel = hud.get_node_or_null("AIMultipliersPanel") as PanelContainer
	if not hud_ai_panel:
		hud_ai_panel = PanelContainer.new()
		hud_ai_panel.name = "AIMultipliersPanel"
		hud_ai_panel.position = Vector2(10, 37)
		hud_ai_panel.custom_minimum_size = Vector2(0, 20)
		hud_ai_panel.add_theme_stylebox_override("panel", _make_hud_pill_style(0.68))
		hud.add_child(hud_ai_panel)

	var hbox := hud_ai_panel.get_node_or_null("HBox") as HBoxContainer
	if not hbox:
		hbox = HBoxContainer.new()
		hbox.name = "HBox"
		hbox.add_theme_constant_override("separation", 6)
		hud_ai_panel.add_child(hbox)
		var specs: Array = [
			["double_jump", "DoubleJumpMultLabel", "Double Jump: 1.0x"],
			["wall_climb", "WallClimbMultLabel", "Wall Climb: 1.0x"],
			["dash", "DashMultLabel", "Dash: 1.0x"]
		]
		for idx in range(specs.size()):
			if idx > 0:
				var sep := Label.new()
				sep.name = "Sep%d" % idx
				sep.text = "|"
				sep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				sep.add_theme_font_size_override("font_size", 10)
				sep.add_theme_color_override("font_color", Color(0.45, 0.50, 0.60, 0.55))
				hbox.add_child(sep)
			var lbl := Label.new()
			lbl.name = String(specs[idx][1])
			lbl.text = String(specs[idx][2])
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", MULT_COLOR_IDLE)
			hbox.add_child(lbl)

	hud_mult_labels = {
		"double_jump": hbox.get_node_or_null("DoubleJumpMultLabel") as Label,
		"wall_climb": hbox.get_node_or_null("WallClimbMultLabel") as Label,
		"dash": hbox.get_node_or_null("DashMultLabel") as Label
	}

	# 3. Osobny, automatycznie wygasający toast na komunikaty statusu (y=61)
	hud_status_toast = hud.get_node_or_null("StatusToastLabel") as Label
	if not hud_status_toast:
		hud_status_toast = Label.new()
		hud_status_toast.name = "StatusToastLabel"
		hud_status_toast.position = Vector2(12, 61)
		hud_status_toast.size = Vector2(560, 18)
		hud_status_toast.add_theme_font_size_override("font_size", 10)
		hud_status_toast.add_theme_constant_override("outline_size", 3)
		hud_status_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.92))
		hud_status_toast.visible = false
		hud.add_child(hud_status_toast)
	hud_ai_label = hud_status_toast
	_mult_hud_initialized = false

func get_multipliers_hud_text() -> String:
	var parts: Array[String] = []
	for move_key in ["double_jump", "wall_climb", "dash"]:
		var lbl := hud_mult_labels.get(move_key) as Label
		if lbl:
			parts.append(lbl.text)
	return " | ".join(parts)

func _show_hud_toast(msg: String, color: Color, duration: float = 2.6) -> void:
	if not hud_status_toast:
		return
	hud_status_toast.text = msg
	hud_status_toast.add_theme_color_override("font_color", color)
	hud_status_toast.modulate.a = 1.0
	hud_status_toast.visible = is_hud_visible
	status_toast_timer = duration
	# Baner wyśrodkowany u góry ekranu, szerokość dopasowana do tekstu
	hud_status_toast.size = Vector2.ZERO
	hud_status_toast.reset_size()
	var vp_w: float = 640.0
	if is_inside_tree():
		vp_w = get_viewport().get_visible_rect().size.x
	# Mieści się między panelami u góry -> y=8, dłuższy komunikat schodzi pod panele
	var toast_y: float = 8.0 if hud_status_toast.size.x <= vp_w - 2.0 * 156.0 else 90.0
	hud_status_toast.position = Vector2(roundf((vp_w - hud_status_toast.size.x) * 0.5), toast_y)

func _update_status_toast(delta: float) -> void:
	if not hud_status_toast or status_toast_timer <= 0.0:
		return
	status_toast_timer = maxf(0.0, status_toast_timer - delta)
	if status_toast_timer <= 0.0:
		hud_status_toast.visible = false
		hud_status_toast.modulate.a = 1.0
	elif status_toast_timer < 0.6:
		hud_status_toast.modulate.a = status_toast_timer / 0.6

func _update_ai_hud() -> void:
	if hud_mult_labels.is_empty() or not is_instance_valid(Events) or not is_instance_valid(Events.ai_director):
		return
	var dir: AdaptiveAIDirector = Events.ai_director
	var move_defs: Array = [
		["double_jump", "Double Jump"],
		["wall_climb", "Wall Climb"],
		["dash", "Dash"]
	]

	for entry in move_defs:
		var move_key: String = String(entry[0])
		var display_name: String = String(entry[1])
		var lbl := hud_mult_labels.get(move_key) as Label
		if not lbl:
			continue

		var val: float = dir.get_multiplier(move_key)
		var cur_tenth: int = int(round(val * 10.0))

		if not _mult_hud_initialized:
			mult_ref_values[move_key] = val
			mult_last_tenths[move_key] = cur_tenth
			mult_trends[move_key] = 0
			mult_highlights[move_key] = 0.0
			mult_hold_timers[move_key] = 0.0
		else:
			var prev_tenth: int = int(mult_last_tenths.get(move_key, 10))
			var ref_val: float = float(mult_ref_values.get(move_key, 1.0))
			if cur_tenth != prev_tenth:
				var delta_val: float = val - ref_val
				if cur_tenth > prev_tenth or delta_val > 0.0:
					mult_trends[move_key] = 1
				else:
					mult_trends[move_key] = -1
				mult_highlights[move_key] = 1.0
				mult_hold_timers[move_key] = MULT_HOLD_DURATION
				mult_ref_values[move_key] = val
				mult_last_tenths[move_key] = cur_tenth

		if dir.is_move_locked(move_key):
			lbl.text = "%s: LOCK %.1fs" % [display_name, dir.get_lockout_remaining(move_key)]
		else:
			lbl.text = "%s: %.1fx" % [display_name, val]

	_mult_hud_initialized = true
	_apply_multiplier_hud_colors()

func _update_multiplier_hud_highlights(delta: float) -> void:
	if hud_mult_labels.is_empty():
		return
	var dir: AdaptiveAIDirector = Events.ai_director if is_instance_valid(Events) else null
	var display_names: Dictionary = {
		"double_jump": "Double Jump",
		"wall_climb": "Wall Climb",
		"dash": "Dash"
	}
	for move_key in ["double_jump", "wall_climb", "dash"]:
		if dir and dir.is_move_locked(move_key):
			var lbl := hud_mult_labels.get(move_key) as Label
			if lbl:
				lbl.text = "%s: LOCK %.1fs" % [display_names[move_key], dir.get_lockout_remaining(move_key)]
		var fade_dt: float = delta
		var hold_t: float = float(mult_hold_timers.get(move_key, 0.0))
		if hold_t > 0.0:
			var consumed: float = minf(hold_t, fade_dt)
			mult_hold_timers[move_key] = hold_t - consumed
			fade_dt -= consumed
		if fade_dt > 0.0 and float(mult_highlights.get(move_key, 0.0)) > 0.0:
			var next_hi: float = maxf(0.0, float(mult_highlights[move_key]) - fade_dt * MULT_FADE_SPEED)
			mult_highlights[move_key] = next_hi
			if next_hi <= 0.0:
				mult_trends[move_key] = 0
	_apply_multiplier_hud_colors()

func _apply_multiplier_hud_colors() -> void:
	var dir: AdaptiveAIDirector = Events.ai_director if is_instance_valid(Events) else null
	for move_key in ["double_jump", "wall_climb", "dash"]:
		var lbl := hud_mult_labels.get(move_key) as Label
		if not lbl:
			continue
		if dir and dir.is_move_locked(move_key):
			lbl.add_theme_color_override("font_color", MULT_COLOR_LOCKED)
			continue
		var trend: int = int(mult_trends.get(move_key, 0))
		var hi: float = clampf(float(mult_highlights.get(move_key, 0.0)), 0.0, 1.0)
		var target_col: Color = MULT_COLOR_UP if trend > 0 else (MULT_COLOR_DOWN if trend < 0 else MULT_COLOR_IDLE)
		lbl.add_theme_color_override("font_color", MULT_COLOR_IDLE.lerp(target_col, hi))

func _on_multipliers_updated(_multipliers: Dictionary) -> void:
	_update_ai_hud()

func _on_mechanic_lockout_changed(_move_name: String, _is_locked: bool, _duration: float) -> void:
	_update_ai_hud()

func _on_stamina_action_rejected(move_name: String, _req: float, _cur: float) -> void:
	var trick_key := Events.get_trick_keys_label(current_language) if is_instance_valid(Events) else "Z/X/C"
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director) and Events.ai_director.is_move_locked(move_name):
		_show_hud_toast("[!] %s zablokowany! Użyj innego ruchu lub Tricku [%s]" % [move_name.to_upper(), trick_key], Color(1.0, 0.42, 0.42, 1.0), 2.2)
	else:
		_show_hud_toast("[!] Brak staminy na %s! Wykonaj Trick [%s] w locie" % [move_name.to_upper(), trick_key], Color(1.0, 0.48, 0.38, 1.0), 2.2)

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
		# Sprawdzenie, czy zebrano minimum połowę klejnotów na poziomie!
		if not can_exit_level():
			var req: int = get_required_jewel_count()
			if finish_goal:
				var lbl: Label = finish_goal.get_node_or_null("LabelGoal")
				if lbl:
					lbl.text = "LOCKED %d/%d" % [collected_jewels, req]
			_show_hud_toast("[!] ZBIERZ MINIMUM POŁOWĘ KLEJNOTÓW (%d/%d), ABY ODBLOKOWAĆ WYJŚCIE!" % [collected_jewels, req], Color(1.0, 0.75, 0.3, 1.0), 2.5)
			return
			
		# Knowledge Check warunkiem ukończenia poziomu:
		if knowledge_check_popup and not quiz_answered_correctly:
			_open_knowledge_check()
			return
			
		_level_complete()

func _level_complete() -> void:
	if is_stage_cleared:
		return
	is_stage_cleared = true
	is_timer_running = false
	for p in get_tree().get_nodes_in_group("player"):
		if p and p.has_method("clear_powerups"):
			p.clear_powerups()
	get_tree().paused = true
	var lvl_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	Events.complete_level(lvl_id, elapsed_time)
	if is_instance_valid(Events):
		Events.return_to_level_select = true
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.evaluate_run_against_challenges(collected_jewels, elapsed_time, true, tricks_performed_count)
		Events.portal_sync.submit_game_run(session_id, lvl_id, true, total_score, elapsed_time, collected_jewels, enemies_defeated_count)
		Events.portal_sync.upload_cloud_save(lvl_id, "completed", collected_jewels)
	
	if music_level:
		music_level.stop()
		
	if win_score_label:
		win_score_label.text = "JEWELS: %d / %d" % [collected_jewels, total_jewels]
		
	if win_time_label:
		win_time_label.text = "TIME: %s" % _format_time(elapsed_time)
		
	if win_session_label:
		win_session_label.text = "SESSION: %s" % session_id
		
	_hide_combo_hud()
	if win_screen:
		win_screen.visible = true
		win_focus_idx = 0
		_set_button_focus(win_buttons, 0)
		
	if audio_win:
		audio_win.play()

func _toggle_hud_visibility() -> void:
	is_hud_visible = not is_hud_visible
	_update_hud_elements_visibility()

func _update_hud_elements_visibility() -> void:
	var hud_node: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if hud_node:
		var system_nodes = [
			"PauseMenu", "GameOverMenu", "WinScreen",
			"SettingsView", "KnowledgeCheckPopup"
		]
		for child in hud_node.get_children():
			if child is AudioStreamPlayer:
				continue
			if child.name in system_nodes:
				continue
			if child is CanvasItem:
				child.visible = is_hud_visible

	if _combo_panel and is_instance_valid(_combo_panel):
		_combo_panel.visible = is_hud_visible and (_combo_hold_t > 0.0)

	if hud_status_toast and is_instance_valid(hud_status_toast):
		hud_status_toast.visible = is_hud_visible and (status_toast_timer > 0.0)

	# Podpowiedzi na mapie (Labels oraz etykiety podpowiedzi w świecie gry)
	var labels_root: CanvasItem = get_node_or_null("Labels") as CanvasItem
	if labels_root and is_instance_valid(labels_root):
		labels_root.visible = is_hud_visible

	var goal_lbl: CanvasItem = get_node_or_null("FinishGoal/LabelGoal") as CanvasItem
	if goal_lbl and is_instance_valid(goal_lbl):
		goal_lbl.visible = is_hud_visible

	var player = get_node_or_null("Player")
	if player and is_instance_valid(player):
		var hp_container: CanvasItem = player.get_node_or_null("HpSquares") as CanvasItem
		if hp_container:
			if not is_hud_visible:
				hp_container.visible = false
			elif player.get("hp_display_timer") != null and player.hp_display_timer > 0.0:
				hp_container.visible = true

func _unhandled_input(event: InputEvent) -> void:
	# Ciężki skrót klawiszowy do przełączania widoczności HUD (np. Ctrl + Shift + H lub F9)
	# Celowo brak w menu ustawień/keybindach, aby uniknąć przypadkowego włączenia w trakcie gry
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_H and event.ctrl_pressed and event.shift_pressed) or (event.keycode == KEY_F9 and not event.ctrl_pressed and not event.alt_pressed):
			_toggle_hud_visibility()
			get_viewport().set_input_as_handled()
			return

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
		if is_instance_valid(controls_rebind_ui) and controls_rebind_ui.is_listening():
			return
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
	if is_instance_valid(controls_rebind_ui):
		controls_rebind_ui.cancel_listening()
	if settings_view:
		settings_view.visible = false
	_hide_combo_hud()
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

	# Integracja interaktywnej zmiany skrótów klawiszowych w ControlsPanel
	var ctrlP: Control = _find_in_settings("ControlsPanel") as Control
	if ctrlP:
		if not is_instance_valid(controls_rebind_ui):
			controls_rebind_ui = ControlsRebindUIScript.new()
			controls_rebind_ui.name = "ControlsRebindUI"
			ctrlP.add_child(controls_rebind_ui)
		controls_rebind_ui.setup(ctrlP, current_language)

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
		if is_instance_valid(controls_rebind_ui) and controls_rebind_ui.get_first_focusable():
			var first_ctrl: Control = controls_rebind_ui.get_first_focusable()
			tabControlsBtn.focus_neighbor_bottom = first_ctrl.get_path()
			first_ctrl.focus_neighbor_top = tabControlsBtn.get_path()
		elif settingsBackBtn:
			tabControlsBtn.focus_neighbor_bottom = settingsBackBtn.get_path()
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
	if is_instance_valid(controls_rebind_ui):
		controls_rebind_ui.cancel_listening()
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
		Events.portal_sync.queue_settings_sync({"music_volume": int(round(v))})

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
		Events.portal_sync.queue_settings_sync({"level_music_volume": int(round(v))})

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
		Events.portal_sync.queue_settings_sync({"sfx_volume": int(round(v))})

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
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var res_str := "%dx%d" % [target_size.x, target_size.y]
		Events.portal_sync.profile_settings["resolution"] = res_str
		Events.portal_sync.queue_settings_sync({"resolution": res_str})

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
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["language"] = code
		Events.portal_sync.queue_settings_sync({"language": code})

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
	if is_instance_valid(Events):
		Events.apply_audio_slider_tooltips(
			_find_in_settings("MasterSlider") as Slider,
			_find_in_settings("MusicSlider") as Slider,
			_find_in_settings("LevelMusicSlider") as Slider,
			_find_in_settings("SfxSlider") as Slider,
			current_language
		)
	
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
	if ctrlGrid and is_instance_valid(Events):
		Events.update_controls_grid_labels(ctrlGrid, current_language)

	if is_instance_valid(controls_rebind_ui):
		controls_rebind_ui.refresh(current_language)
	_refresh_dynamic_control_labels()
		
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
	if audio_game_over and audio_game_over.playing:
		audio_game_over.stop()
	get_tree().paused = false
	var profile_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	var loading_screen = get_node_or_null("/root/LoadingScreen")
	if loading_screen and loading_screen.has_method("play_transition"):
		loading_screen.play_transition(profile_id, "res://scenes/test_arena.tscn")
	else:
		get_tree().reload_current_scene()

func _quit_or_menu() -> void:
	if audio_game_over and audio_game_over.playing:
		audio_game_over.stop()
	get_tree().paused = false
	if ResourceLoader.exists("res://scenes/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().quit()

const GAME_OVER_SFX_START_OFFSET: float = 0.0

func _ensure_game_over_audio() -> void:
	if not audio_game_over:
		audio_game_over = get_node_or_null("HUD/AudioGameOver") as AudioStreamPlayer
	if not audio_game_over:
		var stream_res: AudioStream = null
		if ResourceLoader.exists("res://audio/sfx/Fahh.wav"):
			stream_res = load("res://audio/sfx/Fahh.wav") as AudioStream
		elif ResourceLoader.exists("res://audio/sfx/Fahh.mp3"):
			stream_res = load("res://audio/sfx/Fahh.mp3") as AudioStream
		if stream_res:
			audio_game_over = AudioStreamPlayer.new()
			audio_game_over.name = "AudioGameOver"
			audio_game_over.process_mode = Node.PROCESS_MODE_ALWAYS
			audio_game_over.stream = stream_res
			audio_game_over.bus = &"SFX"
			var hud_node: Node = get_node_or_null("HUD")
			if hud_node:
				hud_node.add_child(audio_game_over)
			else:
				add_child(audio_game_over)

func _on_player_died() -> void:
	if is_game_over or is_stage_cleared:
		return
	is_game_over = true
	is_timer_running = false
	if music_level:
		music_level.stop()
	_ensure_game_over_audio()
	if audio_game_over:
		audio_game_over.play(GAME_OVER_SFX_START_OFFSET)
	var lvl_id: int = Events.selected_level_profile if is_instance_valid(Events) else 1
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.submit_game_run(session_id, lvl_id, false, total_score, elapsed_time, collected_jewels, enemies_defeated_count)
	_hide_combo_hud()
	get_tree().paused = true
	if game_over_menu:
		game_over_menu.visible = true
		game_over_focus_idx = 0
		_set_button_focus(game_over_buttons, 0)

func _on_player_hit(_damage: int) -> void:
	pass
