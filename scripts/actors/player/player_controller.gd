extends CharacterBody2D
class_name PlayerController

const SkinManager = preload("res://scripts/core/skin_manager.gd")

## Zaawansowany kontroler gracza 2D dla JewelRunner
## Obsługuje: bieg, skok o zmiennej wysokości, podwójny skok, coyote time, jump buffer,
## poziomy dash, kucanie, wślizg (slide) z ochroną sufitu, wspinaczkę po ścianie i wall jump.
## Wszystkie ruchy specjalne (double_jump, wall_climb, dash) zużywają wspólną staminę z dynamicznymi
## mnożnikami (zarządzanymi przez AI Director przy stałej sumie mnożników), a regeneracja staminy
## odbywa się poprzez combo Tricków w powietrzu [Z] Salto / [X] Gwiazda (Finał [C] wypłaca combo z bonusem).

# --- Stany Gracza ---
enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
	CROUCH,
	SLIDE,
	WALL_SLIDE,
	WALL_CLIMB
}

var current_state: State = State.IDLE

# --- Parametry Ruchu (Strojenie na żywo w Inspektorze Godot) ---
@export_group("Ruch Poziomy (Akceleracja / Max Speed / Deakceleracja)")
## Bazowa prędkość biegu na ziemi (px/s), od której włącza się łagodniejsze, nieograniczone przyspieszanie pierwiastkowe.
@export var speed: float = 165.0
## Początkowe przyspieszenie powyżej bazowej prędkości biegu (px/s²). Im wyższe, tym szybciej postać nabiera prędkości po przekroczeniu `speed`.
@export_range(0.0, 200.0, 1.0, "or_greater") var uncapped_accel_rate: float = 48.0
## Parametr krzywej pierwiastkowej (px/s). Im mniejszy, tym wyraźniej maleje przyspieszenie w miarę dalszego rozpędzania się postaci.
@export_range(5.0, 200.0, 1.0, "or_greater") var uncapped_accel_falloff: float = 45.0
## Tempo początkowego rozpędzania na ziemi od zera do bazowej prędkości `speed`.
@export var run_accel_amount: float = 11.0
## Tempo wyhamowywania po puszczeniu klawisza kierunku ruchu.
@export var run_deccel_amount: float = 14.0
## Wykładnik krzywej przyspieszenia/hamowania (wartości < 1 dają ostrzejszy start, > 1 płynniejsze rozpędzanie).
@export_range(0.5, 2.0, 0.02) var vel_power: float = 0.92
## Mnożnik kontroli poziomej podczas przyspieszania w powietrzu (skala względem `run_accel_amount`).
@export_range(0.0, 1.5, 0.05) var accel_in_air: float = 0.65
## Mnożnik hamowania w powietrzu po puszczeniu klawiszy kierunku (skala względem `run_deccel_amount`).
@export_range(0.0, 1.5, 0.05) var deccel_in_air: float = 0.65
## Mnożnik przyspieszenia przy nagłej zmianie kierunku biegu na przeciwny (szybszy zawrót).
@export_range(1.0, 3.0, 0.05) var turnaround_accel_mult: float = 1.6
## Siła tarcia na ziemi zatrzymująca postać po puszczeniu klawiszy ruchu.
@export_range(0.0, 1.0, 0.02) var friction_amount: float = 0.22
## Gdy włączone, postać w locie zachowuje pęd szybszy niż bazowa prędkość zamiast hamować do `speed`.
@export var do_conserve_momentum: bool = true

@export_group("Skoki")
## Początkowa prędkość pionowa zwykłego skoku z ziemi (wartość ujemna = ruch w górę, px/s).
@export var jump_velocity: float = -315.0
## Początkowa prędkość pionowa podwójnego skoku w powietrzu (wartość ujemna = ruch w górę, px/s).
@export var double_jump_velocity: float = -275.0
## Mnożnik skrócenia skoku po wcześniejszym puszczeniu klawisza skoku (mniejsza wartość = mocniejsze ścięcie skoku).
@export var jump_cut_multiplier: float = 0.5
## Podstawowa grawitacja działająca na postać podczas wznoszenia (px/s²).
@export var gravity: float = 880.0
## Maksymalna prędkość opadania w dół (px/s).
@export var max_fall_speed: float = 390.0
## Czas po zejściu z krawędzi (s), w którym nadal można wykonać zwykły skok z ziemi.
@export var coyote_time: float = 0.13
## Czas wyprzedzenia (s), przez który wciśnięty skok przed lądowaniem zostanie wykonany od razu po dotknięciu ziemi.
@export var jump_buffer_time: float = 0.14
## Mnożnik grawitacji podczas opadania (`velocity.y > 0`), przyspiesza spadanie po szczycie skoku.
@export var fall_gravity_multiplier: float = 1.25
## Próg prędkości pionowej (px/s), poniżej którego aktywuje się strefa zawisu na szczycie skoku (apex hang).
@export var jump_hang_time_threshold: float = 45.0
## Mnożnik grawitacji w najwyższym punkcie skoku (mniejsza wartość = dłuższy, bardziej kontrolowany zawis).
@export var jump_hang_gravity_mult: float = 0.55
## Mnożnik przyspieszenia poziomego na szczycie skoku (ułatwia precyzyjne lądowanie).
@export var jump_hang_accel_mult: float = 1.15
## Mnożnik docelowej prędkości poziomej w strefie szczytu skoku.
@export var jump_hang_max_speed_mult: float = 1.10
## Liczba pikseli przesunięcia na boki przy otarciu głową o róg sufitu podczas skoku (corner correction).
@export var corner_correction_pixels: int = 5

@export_group("Dash (Zryw)")
## Minimalna prędkość pozioma podczas zrywu (dasha) w px/s.
@export var dash_speed: float = 480.0
## Czas trwania pojedynczego dasha (s).
@export var dash_duration: float = 0.19
## Czas odnowienia (cooldown) pomiędzy kolejnymi dashami (s).
@export var dash_cooldown: float = 0.50
## Część prędkości dasha zachowywana po jego zakończeniu (o ile postać nie miała wcześniej wyższego pędu).
@export var dash_exit_speed_factor: float = 0.45
## Czas buforowania wciśnięcia dasha przed lądowaniem lub końcem cooldownu (s).
@export var dash_buffer_time: float = 0.12

@export_group("Kucanie i Wślizg")
## Maksymalna prędkość poruszania się podczas zwykłego kucania (px/s).
@export var crouch_speed: float = 70.0
## Prędkość wybicia wślizgu (px/s) – mocny zryw na starcie; szybszy rozpęd (np. power-up) daje jeszcze więcej.
@export var slide_burst_speed: float = 400.0
## Mnożnik aktualnej prędkości przy starcie wślizgu, gdy postać biegnie już szybciej niż slide_burst_speed.
@export var slide_burst_carry: float = 1.08
## Czas fazy zrywu (s), w której wślizg prawie nie traci prędkości.
@export var slide_burst_time: float = 0.10
## Lekkie tarcie w fazie zrywu (px/s²).
@export var slide_burst_friction: float = 150.0
## Opór proporcjonalny do prędkości (1/s) po zrywie: im szybciej, tym mocniej hamuje -> płynna utrata pędu.
@export var slide_drag: float = 2.2
## Stałe tarcie po zrywie (px/s²) – domyka wyhamowanie przy niskich prędkościach.
@export var slide_friction: float = 90.0
## Mnożnik hamowania wślizgu przy wciśnięciu przeciwnego kierunku ruchu.
@export var slide_brake_multiplier: float = 2.2
## Maksymalna prędkość pozioma przenoszona do skoku z wślizgu (px/s) – chroni zasięg skoków w projektach poziomów.
@export var slide_jump_max_speed: float = 250.0
## Próg prędkości (px/s), poniżej którego wślizg przechodzi w kucanie lub stanie.
@export var slide_min_speed: float = 80.0
## Czas odnowienia (cooldown) pomiędzy kolejnymi wślizgami (s).
@export var slide_cooldown: float = 0.35

@export_group("Ściany (Wall Actions)")
## Prędkość zsuwania się po ścianie (px/s).
@export var wall_slide_speed: float = 55.0
## Prędkość wspinania się w górę po ścianie (px/s).
@export var wall_climb_speed: float = 100.0
## Maksymalna pojemność paska staminy na ruchy specjalne (wspinaczka, double jump, dash).
@export var wall_climb_max_stamina: float = 2.0
## Wektor prędkości odbicia przy wall jumpie (X = odepchnięcie od ściany, Y = wybicie w górę).
@export var wall_jump_velocity: Vector2 = Vector2(215.0, -295.0)
## Czas po oderwaniu od ściany (s), w którym wciąż można wykonać wall jump.
@export var wall_coyote_time: float = 0.12
## Krótka blokada odklejenia się od ściany (s), ułatwiająca wykonanie wall jumpa przed odpadnięciem.
@export var wall_stick_time: float = 0.08
## Koszt staminy za kolejny skok z tej samej ściany (zabezpieczenie przed wspinaniem samym wall jumpem).
@export var same_wall_jump_stamina_cost: float = 0.65
## Współczynnik osłabiania kolejnych skoków z tej samej ściany (wykładniczy spadek wysokości wybicia).
@export var same_wall_jump_decay: float = 0.72
## Czas częściowego ograniczenia powrotu sterowania w stronę ściany tuż po wall jumpie (s).
@export var wall_jump_control_lock_time: float = 0.16
## Mnożnik kontroli w stronę opuszczonej ściany podczas trwania `wall_jump_control_lock_time`.
@export_range(0.0, 1.0, 0.05) var wall_jump_air_control_mult: float = 0.25

@export_group("Kamera i Game Feel")
## Mnożnik zachowany dla kompatybilności wyliczeń bazowych w power-upach prędkości.
@export var speed_powerup_multiplier: float = 1.45
## Mnożnik przyspieszania postaci przyznawany po zebraniu Speed Gema lub power-upu prędkości.
@export_range(1.0, 5.0, 0.05) var speed_powerup_accel_multiplier: float = 2.5
## Poziomy margines martwej strefy kamery (ułamek szerokości ekranu zanim kamera zacznie podążać).
@export_range(0.0, 0.5, 0.01) var camera_drag_horizontal_margin: float = 0.22
## Pionowy margines martwej strefy kamery (ułamek wysokości ekranu zanim kamera zacznie podążać).
@export_range(0.0, 0.5, 0.01) var camera_drag_vertical_margin: float = 0.18
## Szybkość płynnego podążania kamery za postacią.
@export_range(1.0, 25.0, 0.5) var camera_smoothing_speed: float = 8.5
## Szybkość powrotu sprita do normalnych proporcji po rozciągnięciu/spłaszczeniu (squash & stretch).
@export var squash_recovery_speed: float = 14.0
## Czas krótkiego zamrożenia klatki (hitstop) po otrzymaniu obrażeń (s).
@export var hitstop_duration: float = 0.045

@export_group("Stamina i Balans Ruchów Specjalnych")
## Bazowy koszt staminy dla Podwójnego Skoku (modyfikowany przez mnożnik double_jump).
@export var double_jump_base_stamina_cost: float = 0.55
## Bazowy koszt staminy dla Dasha (modyfikowany przez mnożnik dash).
@export var dash_base_stamina_cost: float = 0.50
## Bazowy koszt staminy na sekundę Wspinaczki (modyfikowany przez mnożnik wall_climb).
@export var wall_climb_base_stamina_cost: float = 1.00
## Indywidualny mnożnik staminy z combo tricków (ustawiany przez AI Director).
@export var trick_regen_multiplier: float = 1.00
## Powolna, bierna regeneracja staminy na sekundę (gdy postać nie wspina się ani nie wykonuje tricku).
## Konfigurowalna za pomocą suwaka w Inspektorze Godot.
@export_range(0.0, 1.0, 0.01, "or_greater") var passive_stamina_regen_per_sec: float = 0.10

@export_group("Combo Tricków")
## Czas trwania Salta [Z] (s) – zgodny z animacją trick_flip (8 kl. @ 26 fps).
@export var trick_flip_duration: float = 0.30
## Czas trwania Gwiazdy [X] (s) – animacja trick_star (9 kl. @ 32 fps).
@export var trick_star_duration: float = 0.28
## Czas wejścia w pozę Wielkiego Finału [C] (s) – animacja trick_finish (6 kl. @ 20 fps).
@export var trick_finish_duration: float = 0.30
## Bazowa stamina dokładana do puli combo przez każdy trick.
@export var trick_flip_stamina: float = 0.14
@export var trick_star_stamina: float = 0.16
@export var trick_finish_stamina: float = 0.22
## Przyrost mnożnika puli za każdy kolejny trick w combo (x1.0, x1.35, x1.7, ...).
@export var combo_multiplier_step: float = 0.35
## Bonus za zakończenie combo Wielkim Finałem.
@export var combo_finisher_bonus: float = 1.5
## Mnożnik wartości tricku powtórzonego bezpośrednio po tym samym tricku.
@export var combo_repeat_penalty: float = 0.5
## Ułamek czasu tricku, który może jeszcze zostać przy lądowaniu, by liczyło się ono jako czyste.
@export_range(0.0, 1.0, 0.05) var trick_landing_grace: float = 0.35
## Overflow: combo może naładować staminę do (max * ten mnożnik).
@export var stamina_overflow_mult: float = 2.0

@export_group("Punkty Życia (HP) i Odporność")
## Maksymalna liczba punktów życia (gwiazdek HP) postaci.
@export var max_health: int = 3
## Czas nietykalności po otrzymaniu obrażeń lub respawnie przy checkpoincie (s).
@export var invulnerability_duration: float = 1.0

# --- Referencje do Węzłów ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ceiling_checker: ShapeCast2D = $CeilingChecker
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var visuals: Node2D = $Visuals
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

@onready var audio_jump: AudioStreamPlayer2D = get_node_or_null("AudioJump")
@onready var audio_dash: AudioStreamPlayer2D = get_node_or_null("AudioDash")
@onready var audio_appear: AudioStreamPlayer2D = get_node_or_null("AudioAppear")

# --- Zmienne Wewnętrzne / Timery ---
var is_appearing: bool = false
var facing_direction: float = 1.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_buffer_timer: float = 0.0
var wall_coyote_timer: float = 0.0
var wall_stick_timer: float = 0.0
var can_double_jump: bool = false
var can_air_dash: bool = true

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0

var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var slide_direction: float = 1.0
var _slide_needs_release: bool = false

var wall_stamina: float = 2.0
var last_wall_normal: Vector2 = Vector2.ZERO
var last_wall_jump_normal: Vector2 = Vector2.ZERO
var consecutive_same_wall_jumps: int = 0
var wall_jump_lock_timer: float = 0.0
var idle_trick_timer: float = 0.0

var is_tricking: bool = false
var combo_tricks: Array[String] = []
var combo_pending: float = 0.0
var combo_finished: bool = false
var combo_banked: bool = false
var current_trick: String = ""
var queued_trick: String = ""
var trick_time_left: float = 0.0
var trick_buffer_timer: float = 0.0
var trick_buffer_kind: String = ""
var last_combo_payout: float = 0.0

var _was_on_floor: bool = false
var _prev_velocity_y: float = 0.0
var _visual_scale: Vector2 = Vector2.ONE
var _shake_strength: float = 0.0
var _shake_decay: float = 18.0
var _afterimage_timer: float = 0.0
var _hitstop_active: bool = false
var _pre_dash_speed: float = 0.0

# Lokalna kopia mnożników ruchów specjalnych (zsynchronizowana z Events.ai_director)
var move_multipliers: Dictionary = {
	"double_jump": 1.0,
	"wall_climb": 1.0,
	"dash": 1.0
}

# Zabezpieczenie anty-exploitowe przed mnożeniem staminy w powietrzu:
# śledzi pułap staminy dostępny do odzyskania z czasu lotu wygenerowanego przez ruchy specjalne.
var airborne_origin_y: float = 0.0
var airborne_stamina_ceiling: float = 2.0
var used_special_in_current_air: bool = false

var current_health: int = 3
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0

# --- Wyświetlanie Wskaźnika HP (Gwiazdek) ---
## Czas wyświetlania gwiazdek HP nad postacią po starcie poziomu lub utracie życia (s).
@export var hp_display_duration: float = 2.5
var hp_display_timer: float = 3.0 ## Widoczne przez 3s na początku poziomu oraz po otrzymaniu obrażeń

# --- Power-upy (Klejnoty Specjalne i Wzmocnienia) ---
var invincibility_powerup_timer: float = 0.0
var speed_powerup_timer: float = 0.0
var has_shield: bool = false
var base_speed: float = 165.0
var active_powerups: Dictionary = {}
var last_checkpoint_pos: Vector2 = Vector2.ZERO
var last_checkpoint_id: String = "START"

# Domyślne rozmiary collidera (stojący vs kucający/wślizg)
var standing_shape_size: Vector2 = Vector2(18, 30)
var standing_shape_position: Vector2 = Vector2(0, 0)
var crouch_shape_size: Vector2 = Vector2(18, 16)
var crouch_shape_position: Vector2 = Vector2(0, 7)

func _ready() -> void:
	add_to_group("player")
	base_speed = speed
	last_checkpoint_pos = global_position
	current_health = max_health
	wall_stamina = wall_climb_max_stamina
	airborne_stamina_ceiling = wall_climb_max_stamina
	airborne_origin_y = global_position.y
	_set_collider_crouched(false)
	
	if is_instance_valid(Events):
		if not Events.stamina_multipliers_updated.is_connected(_on_stamina_multipliers_updated):
			Events.stamina_multipliers_updated.connect(_on_stamina_multipliers_updated)
		if not Events.portal_profile_synced.is_connected(_on_portal_profile_synced):
			Events.portal_profile_synced.connect(_on_portal_profile_synced)
		if is_instance_valid(Events.ai_director):
			move_multipliers = Events.ai_director.multipliers.duplicate()
		if is_instance_valid(Events.portal_sync):
			Events.portal_sync.apply_cosmetics_and_boosters_to_player(self)
		else:
			SkinManager.apply_skin_to_player(self, "base")
			
	_update_stamina_bar()
	_update_hp_indicator()
	Events.player_spawned.emit(self)
	Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
	Events.player_health_changed.emit(current_health, max_health)
	
	var loading_screen = get_node_or_null("/root/LoadingScreen")
	if loading_screen:
		if loading_screen.is_transitioning:
			is_appearing = true
			visible = false
			if not loading_screen.transition_completed.is_connected(_on_loading_screen_completed):
				loading_screen.transition_completed.connect(_on_loading_screen_completed, CONNECT_ONE_SHOT)
			return
		elif not loading_screen.has_shown_for_scene:
			is_appearing = true
			visible = false
			loading_screen.has_shown_for_scene = true
			if not loading_screen.transition_completed.is_connected(_on_loading_screen_completed):
				loading_screen.transition_completed.connect(_on_loading_screen_completed, CONNECT_ONE_SHOT)
			var prof_id = Events.selected_level_profile if is_instance_valid(Events) else 1
			loading_screen.play_transition_direct(prof_id)
			return
	_start_appear_sequence()

func _on_loading_screen_completed() -> void:
	visible = true
	_start_appear_sequence()

func _start_appear_sequence() -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("appear"):
		if not anim_sprite.animation_finished.is_connected(_on_animation_finished):
			anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play("appear")
		is_appearing = true
	else:
		is_appearing = false
		if is_instance_valid(Events):
			Events.player_appear_finished.emit()
			Events.level_started.emit()
	_play_sfx(audio_appear)

func _on_stamina_multipliers_updated(new_multipliers: Dictionary) -> void:
	for k in new_multipliers.keys():
		move_multipliers[k] = float(new_multipliers[k])

func _on_portal_profile_synced(_profile_state: Dictionary) -> void:
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.apply_cosmetics_and_boosters_to_player(self)

func _on_animation_finished() -> void:
	if not anim_sprite:
		return
	if anim_sprite.animation == "appear":
		is_appearing = false
		anim_sprite.play("idle")
		if is_instance_valid(Events):
			Events.player_appear_finished.emit()
			Events.level_started.emit()
	elif anim_sprite.animation == "run_start" and current_state == State.RUN:
		anim_sprite.play("run")
	elif anim_sprite.animation == "idle_special":
		anim_sprite.play("idle")
		idle_trick_timer = 0.0

func _exit_tree() -> void:
	if _hitstop_active:
		Engine.time_scale = 1.0
		_hitstop_active = false

func _physics_process(delta: float) -> void:
	if is_appearing:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_camera(delta)
		return

	_was_on_floor = is_on_floor()
	_prev_velocity_y = velocity.y
	_update_timers(delta)

	# Globalne buforowanie wejścia (żadne naciśnięcie nie ginie podczas dasha czy przed lądowaniem)
	if _is_jump_just_pressed():
		jump_buffer_timer = jump_buffer_time
	if _is_dash_just_pressed():
		dash_buffer_timer = dash_buffer_time
	var pressed_trick: String = _trick_just_pressed_kind()
	if pressed_trick != "":
		trick_buffer_timer = 0.12
		trick_buffer_kind = pressed_trick
	elif trick_buffer_timer > 0.0:
		trick_buffer_timer -= delta
	
	# Maszyna stanów
	match current_state:
		State.IDLE, State.RUN:
			_state_ground(delta)
		State.JUMP, State.FALL:
			_state_air(delta)
		State.DASH:
			_state_dash(delta)
		State.CROUCH:
			_state_crouch(delta)
		State.SLIDE:
			_state_slide(delta)
		State.WALL_SLIDE, State.WALL_CLIMB:
			_state_wall(delta)

	if velocity.y < 0.0 and (current_state == State.JUMP or current_state == State.FALL):
		_apply_corner_correction()
			
	move_and_slide()

	if not _was_on_floor and is_on_floor():
		_on_landed(_prev_velocity_y)
		if current_state == State.JUMP or current_state == State.FALL:
			if jump_buffer_timer > 0.0:
				_execute_jump()
			elif _is_crouch_pressed() and (_slide_needs_release or absf(velocity.x) <= 95.0):
				_change_state(State.CROUCH)
				_set_collider_crouched(true)
			else:
				_change_state(State.RUN if _get_input_direction() != 0.0 else State.IDLE)

	_update_visuals(delta)
	_update_camera(delta)

	# Bierna, powolna regeneracja staminy
	if current_state != State.WALL_CLIMB and not is_tricking and wall_stamina < wall_climb_max_stamina:
		var prev_stam: float = wall_stamina
		wall_stamina = min(wall_climb_max_stamina, wall_stamina + passive_stamina_regen_per_sec * delta)
		if not is_equal_approx(prev_stam, wall_stamina):
			Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
			_update_stamina_bar()

# --- Obsługa Mnożników i Kosztów Staminy ---

## Zwraca aktualny mnożnik kosztu staminy dla wskazanego ruchu specjalnego.
func get_move_multiplier(move_name: String) -> float:
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		var dir_mult: float = Events.ai_director.get_multiplier(move_name)
		move_multipliers[move_name] = dir_mult
		return dir_mult
	return float(move_multipliers.get(move_name, 1.0))

## Ustawia mnożnik dla wskazanego ruchu (lub trick_regen).
func set_move_multiplier(move_name: String, value: float) -> void:
	if move_name == "trick_regen":
		trick_regen_multiplier = max(0.1, value)
		return
	move_multipliers[move_name] = max(0.1, value)
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		Events.ai_director.multipliers[move_name] = move_multipliers[move_name]

## Oblicza aktualny koszt staminy dla danego ruchu specjalnego z uwzględnieniem jego mnożnika.
func get_move_stamina_cost(move_name: String) -> float:
	var mult: float = get_move_multiplier(move_name)
	match move_name:
		"double_jump":
			return double_jump_base_stamina_cost * mult
		"dash":
			return dash_base_stamina_cost * mult
		"wall_climb":
			return wall_climb_base_stamina_cost * mult
		_:
			return 0.0

## Sprawdza, czy gracz ma wystarczająco staminy oraz czy ruch nie jest zablokowany przez AI Director.
func can_use_special_move(move_name: String) -> bool:
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		if Events.ai_director.is_move_locked(move_name):
			Events.stamina_action_rejected.emit(move_name, get_move_stamina_cost(move_name), wall_stamina)
			return false
			
	if move_name == "wall_climb":
		if wall_stamina <= 0.001:
			Events.stamina_action_rejected.emit(move_name, 0.1, wall_stamina)
			return false
		return true
		
	var cost: float = get_move_stamina_cost(move_name)
	if wall_stamina + 0.001 < cost:
		Events.stamina_action_rejected.emit(move_name, cost, wall_stamina)
		return false
	return true

## Zużywa staminę na dyskretny ruch specjalny (double_jump, dash) i powiadamia AI Director.
func consume_special_move_stamina(move_name: String) -> bool:
	if not can_use_special_move(move_name):
		return false
	var cost: float = get_move_stamina_cost(move_name)
	var pre_stamina: float = wall_stamina
	wall_stamina = max(0.0, wall_stamina - cost)
	
	# Zabezpieczenie przed mnożeniem staminy: użycie ruchu specjalnego obniża pułap staminy
	# możliwy do odzyskania z samego dodatkowego czasu wznoszenia/opadania tego ruchu.
	used_special_in_current_air = true
	airborne_stamina_ceiling = max(wall_stamina, pre_stamina - cost * 0.25)
	
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		Events.ai_director.record_move_use(move_name, 1.0)
		
	Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
	_update_stamina_bar()
	return true

# --- System Combo Tricków ---
# Tricki wykonuje się w locie osobnymi klawiszami (domyślnie):
#   [Z] -> SALTO        (akcja trick_flip,   animacja trick_flip)
#   [X] -> GWIAZDA      (akcja trick_star,   animacja trick_star)
#   [C] -> WIELKI FINAŁ (akcja trick_finish, animacja trick_finish) – kończy combo (wymaga min. 1 tricku)
# Każdy trick dokłada staminę do puli combo; pula rośnie z mnożnikiem za długość combo
# i wypłaca się po Finale (z bonusem) albo po czystym lądowaniu. Lądowanie w trakcie tricku = WPADKA
# (pula przepada). Wypłata może przekroczyć maksymalną staminę (overflow) aż do stamina_overflow_mult * max.

## Zwraca definicję tricku (nazwa animacji, czas trwania, stamina bazowa, punkty, etykieta).
func get_trick_def(kind: String) -> Dictionary:
	match kind:
		"flip":
			return {"anim": "trick_flip", "duration": trick_flip_duration, "stamina": trick_flip_stamina, "points": 100, "label": "SALTO", "label_en": "FLIP"}
		"star":
			return {"anim": "trick_star", "duration": trick_star_duration, "stamina": trick_star_stamina, "points": 120, "label": "GWIAZDA", "label_en": "STAR"}
		"finish":
			return {"anim": "trick_finish", "duration": trick_finish_duration, "stamina": trick_finish_stamina, "points": 250, "label": "WIELKI FINAŁ", "label_en": "GRAND FINALE"}
	return {}

## Maksymalna stamina, którą można zgromadzić dzięki combo (overflow ponad bazowe maksimum).
func get_stamina_overflow_cap() -> float:
	return wall_climb_max_stamina * maxf(1.0, stamina_overflow_mult)

## Mnożnik puli staminy za długość combo (1 trick = x1.0, każdy kolejny +combo_multiplier_step).
func get_combo_multiplier(count: int = -1) -> float:
	var n: int = combo_tricks.size() if count < 0 else count
	return 1.0 + combo_multiplier_step * float(maxi(0, n - 1))

## Aktualna wartość puli combo (ile staminy zostanie wypłacone przy wypłacie teraz).
func get_combo_payout() -> float:
	var total: float = combo_pending * get_combo_multiplier()
	if combo_finished:
		total *= combo_finisher_bonus
	return total

func is_combo_active() -> bool:
	return not combo_tricks.is_empty() and not combo_banked

## Publiczne API: próbuje wykonać (lub zbuforować) trick danego rodzaju. Zwraca true, jeśli trick został przyjęty.
func request_trick(kind: String) -> bool:
	if is_on_floor() or current_state == State.DASH or current_state == State.WALL_SLIDE or current_state == State.WALL_CLIMB:
		return false
	if combo_finished:
		return false
	if kind == "finish":
		var have: int = combo_tricks.size() if not combo_banked else 0
		if have == 0:
			kind = "flip"   # Finał wieńczy combo – bez wcześniejszego tricku wykonujemy salto
	if current_trick != "":
		if current_trick == "finish":
			return false
		queued_trick = kind
		return true
	_start_trick(kind)
	return true

func _start_trick(kind: String) -> void:
	var def: Dictionary = get_trick_def(kind)
	if def.is_empty():
		return
	if combo_banked:
		_reset_combo_state()
	var repeat: bool = (not combo_tricks.is_empty() and combo_tricks[combo_tricks.size() - 1] == kind)
	var value: float = float(def["stamina"]) * trick_regen_multiplier * (combo_repeat_penalty if repeat else 1.0)
	combo_tricks.append(kind)
	combo_pending += value
	current_trick = kind
	trick_time_left = float(def["duration"])
	is_tricking = true
	queued_trick = ""
	_afterimage_timer = 0.0
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(def["anim"]):
		anim_sprite.play(def["anim"])
		anim_sprite.frame = 0
	match kind:
		"flip":
			_apply_squash_stretch(Vector2(0.86, 1.14))
		"star":
			_apply_squash_stretch(Vector2(1.18, 0.88))
			if velocity.y > 0.0:
				velocity.y *= 0.55
		"finish":
			_apply_squash_stretch(Vector2(1.22, 0.82))
			if velocity.y > 0.0:
				velocity.y *= 0.4
	var pts: int = int(def["points"]) * combo_tricks.size()
	Events.trick_performed.emit(pts)
	if is_instance_valid(Events.ai_director):
		Events.ai_director.record_air_trick(float(def["duration"]))
	if kind == "finish":
		combo_finished = true
		_bank_combo(true)
	else:
		Events.trick_combo_updated.emit(combo_tricks.duplicate(), get_combo_payout(), false)

## Aktualizacja trwającego tricku (wywoływana co klatkę w powietrzu).
func _update_trick(delta: float) -> void:
	if current_trick == "":
		return
	trick_time_left -= delta
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = 0.05
		var tint := Color(1.0, 0.88, 0.35, 0.5)
		if current_trick == "star":
			tint = Color(0.68, 0.9, 1.0, 0.5)
		elif current_trick == "finish":
			tint = Color(1.0, 0.55, 0.85, 0.55)
		_spawn_afterimage(tint)
	if trick_time_left > 0.0:
		return
	if current_trick == "finish":
		# Poza finałowa zostaje do lądowania
		current_trick = ""
		trick_time_left = 0.0
		return
	current_trick = ""
	if queued_trick != "":
		var next: String = queued_trick
		queued_trick = ""
		request_trick(next)
	else:
		is_tricking = false

## Rozstrzyga combo: "land" (lądowanie/ściana/dash) lub "lost" (obrażenia, respawn).
func _resolve_combo(reason: String = "land") -> void:
	if combo_tricks.is_empty():
		is_tricking = false
		current_trick = ""
		queued_trick = ""
		return
	if combo_banked:
		_reset_combo_state()
		return
	var def: Dictionary = get_trick_def(current_trick)
	var clean: bool = (reason == "land") and (current_trick == "" or current_trick == "finish" or trick_time_left <= float(def.get("duration", 0.0)) * trick_landing_grace)
	if clean:
		_bank_combo(false)
	else:
		var lost: float = get_combo_payout()
		var count: int = combo_tricks.size()
		_reset_combo_state()
		_apply_squash_stretch(Vector2(1.3, 0.72))
		Events.trick_combo_ended.emit(count, 0.0, false, true)
		if lost > 0.0 and reason == "land":
			_spawn_dust_burst(global_position + Vector2(0, 14), 6, Color(1.0, 0.55, 0.55, 0.8))
	_reset_combo_state()

func _bank_combo(finished: bool) -> void:
	if combo_banked:
		return
	var payout: float = get_combo_payout()
	var count: int = combo_tricks.size()
	var prev: float = wall_stamina
	wall_stamina = minf(get_stamina_overflow_cap(), wall_stamina + payout)
	combo_banked = true
	last_combo_payout = wall_stamina - prev
	Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
	_update_stamina_bar()
	Events.trick_combo_updated.emit(combo_tricks.duplicate(), payout, finished)
	Events.trick_combo_ended.emit(count, last_combo_payout, finished, false)
	if finished:
		_spawn_dust_burst(global_position, 10, Color(1.0, 0.86, 0.4, 0.9))

func _reset_combo_state() -> void:
	combo_tricks.clear()
	combo_pending = 0.0
	combo_finished = false
	combo_banked = false
	current_trick = ""
	queued_trick = ""
	trick_time_left = 0.0
	is_tricking = false

# --- Aktualizacja Timerów i Staminy ---
func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		wall_coyote_timer = 0.0
		wall_stick_timer = 0.0
		wall_jump_lock_timer = 0.0
		last_wall_jump_normal = Vector2.ZERO
		consecutive_same_wall_jumps = 0
		can_double_jump = true
		can_air_dash = true
		used_special_in_current_air = false
		airborne_origin_y = global_position.y
		airborne_stamina_ceiling = wall_climb_max_stamina
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	if dash_buffer_timer > 0.0:
		dash_buffer_timer = max(0.0, dash_buffer_timer - delta)

	if wall_coyote_timer > 0.0:
		wall_coyote_timer = max(0.0, wall_coyote_timer - delta)

	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer = max(0.0, wall_jump_lock_timer - delta)
		
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)

	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer = max(0.0, slide_cooldown_timer - delta)
	if not _is_crouch_pressed():
		_slide_needs_release = false

	if invulnerability_timer > 0.0:
		invulnerability_timer = max(0.0, invulnerability_timer - delta)
		if invulnerability_timer <= 0.0:
			is_invulnerable = false

	if invincibility_powerup_timer > 0.0:
		invincibility_powerup_timer = max(0.0, invincibility_powerup_timer - delta)

	if speed_powerup_timer > 0.0:
		speed_powerup_timer = max(0.0, speed_powerup_timer - delta)

	for p_type in active_powerups.keys().duplicate():
		var entry: Dictionary = active_powerups[p_type]
		var time_left: float = max(0.0, float(entry.get("time_left", 0.0)) - delta)
		if time_left <= 0.0:
			active_powerups.erase(p_type)
			if p_type == "SPEED_BOOST":
				speed = base_speed
			elif p_type == "INVINCIBILITY":
				invincibility_powerup_timer = 0.0
			elif p_type == "SHIELD":
				has_shield = false
			if is_instance_valid(Events):
				Events.powerup_expired.emit(p_type)
		else:
			entry["time_left"] = time_left
			active_powerups[p_type] = entry

	# Obsługa widoczności gwiazdek HP (początek poziomu oraz obrażenia)
	var hp_container: Node2D = get_node_or_null("HpSquares")
	if hp_container:
		if hp_display_timer > 0.0:
			hp_display_timer = max(0.0, hp_display_timer - delta)
			if hp_display_timer <= 0.0:
				hp_container.visible = false
			else:
				hp_container.visible = true
				if hp_display_timer < 0.5:
					hp_container.modulate.a = hp_display_timer / 0.5
				else:
					hp_container.modulate.a = 1.0
		else:
			hp_container.visible = false

func show_hp_indicator(duration: float = -1.0) -> void:
	if duration <= 0.0:
		duration = hp_display_duration
	hp_display_timer = max(hp_display_timer, duration)
	var hp_container: Node2D = get_node_or_null("HpSquares")
	if hp_container:
		hp_container.visible = true
		hp_container.modulate.a = 1.0

func apply_invincibility(duration: float = 10.0) -> void:
	invincibility_powerup_timer = max(invincibility_powerup_timer, duration)

func apply_speed_boost(duration: float = 10.0) -> void:
	speed_powerup_timer = max(speed_powerup_timer, duration)

func apply_shield() -> void:
	has_shield = true

func apply_powerup(powerup_type: String, duration: float = 6.0, value: float = 1.5, tier: int = 1) -> bool:
	if powerup_type == "INSTANT_HEAL":
		heal(maxi(1, int(round(value))))
		if is_instance_valid(Events):
			Events.powerup_collected.emit(powerup_type, 0.0, value)
		return true

	if active_powerups.has(powerup_type):
		var cur: Dictionary = active_powerups[powerup_type]
		var cur_tier: int = int(cur.get("tier", 1))
		if tier < cur_tier:
			return false

	active_powerups[powerup_type] = {
		"time_left": duration,
		"duration": duration,
		"value": value,
		"tier": tier
	}

	match powerup_type:
		"SPEED_BOOST":
			speed = base_speed * value
		"INVINCIBILITY":
			invincibility_powerup_timer = max(invincibility_powerup_timer, duration)
		"SHIELD":
			has_shield = true

	if is_instance_valid(Events):
		Events.powerup_collected.emit(powerup_type, duration, value)
	return true

func has_powerup(powerup_type: String) -> bool:
	if powerup_type == "SHIELD":
		return active_powerups.has("SHIELD") and has_shield
	return active_powerups.has(powerup_type)

func get_powerup_time_left(powerup_type: String) -> float:
	if not active_powerups.has(powerup_type):
		return 0.0
	return float(active_powerups[powerup_type].get("time_left", 0.0))

func clear_powerups() -> void:
	active_powerups.clear()
	speed = base_speed
	invincibility_powerup_timer = 0.0
	speed_powerup_timer = 0.0
	has_shield = false

func set_checkpoint(pos: Vector2, cp_id: String = "CP") -> void:
	last_checkpoint_pos = pos
	last_checkpoint_id = cp_id

func respawn_at_checkpoint() -> void:
	global_position = last_checkpoint_pos
	velocity = Vector2.ZERO
	_resolve_combo("lost")
	last_wall_jump_normal = Vector2.ZERO
	consecutive_same_wall_jumps = 0
	wall_jump_lock_timer = 0.0
	_set_collider_crouched(false)
	_change_state(State.IDLE)
	is_invulnerable = true
	invulnerability_timer = invulnerability_duration

func handle_abyss_fall(dmg: int = 1) -> void:
	if current_health <= 0:
		return
	is_invulnerable = false
	take_damage(maxi(1, dmg), Vector2.ZERO)
	if current_health > 0:
		respawn_at_checkpoint()
		if is_instance_valid(Events):
			Events.player_fell_in_abyss.emit(last_checkpoint_pos)

func apply_trampoline_bounce(launch_velocity: float = -470.0) -> void:
	if current_state == State.CROUCH or current_state == State.SLIDE:
		if not _can_stand_up():
			return
		_set_collider_crouched(false)
	# Trampolina podtrzymuje combo (można je dalej rozbudowywać); zakończone combo się zeruje
	if combo_banked:
		_reset_combo_state()
	velocity.y = launch_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	wall_jump_lock_timer = 0.0
	last_wall_jump_normal = Vector2.ZERO
	consecutive_same_wall_jumps = 0
	can_double_jump = true
	can_air_dash = true
	used_special_in_current_air = false
	airborne_origin_y = global_position.y
	airborne_stamina_ceiling = wall_climb_max_stamina
	_change_state(State.JUMP)
	_apply_squash_stretch(Vector2(0.76, 1.28))
	_spawn_dust_burst(global_position + Vector2(0, 14), 6, Color(0.55, 0.95, 1.0, 0.85))
	add_camera_shake(2.2)
	if anim_sprite:
		anim_sprite.play("jump")
	_play_sfx(audio_jump)
	if is_instance_valid(Events):
		Events.player_jumped.emit(false)

func is_dashing() -> bool:
	return current_state == State.DASH

func get_effective_speed() -> float:
	return speed * (speed_powerup_multiplier if speed_powerup_timer > 0.0 else 1.0)

func get_accel_boost_multiplier() -> float:
	var boost: float = 1.0
	if speed_powerup_timer > 0.0:
		boost = maxf(boost, speed_powerup_accel_multiplier)
	if has_powerup("SPEED_BOOST"):
		var p_val: float = float(active_powerups.get("SPEED_BOOST", {}).get("value", 1.0))
		boost = maxf(boost, maxf(speed_powerup_accel_multiplier, p_val))
	return boost

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or current_health <= 0:
		return
		
	# Power-up JewJewel / INVINCIBILITY: brak otrzymywania obrażeń
	if invincibility_powerup_timer > 0.0 or has_powerup("INVINCIBILITY"):
		return
		
	# Obsługa wzmocnienia "tarcza" (najpierw darmowa tarcza z poziomu, potem tarcza z portalu)
	if has_shield or has_powerup("SHIELD"):
		has_shield = false
		active_powerups.erase("SHIELD")
		is_invulnerable = true
		invulnerability_timer = invulnerability_duration
		show_hp_indicator()
		if is_instance_valid(Events):
			Events.powerup_expired.emit("SHIELD")
		return
	elif get_meta("has_portal_shield", false):
		set_meta("has_portal_shield", false)
		if DisplayServer.get_name() != "headless" and is_instance_valid(Events) and is_instance_valid(Events.portal_sync) and Events.portal_sync.is_linked:
			Events.portal_sync.report_booster_used("tarcza", Events.session_id + "-shield")
		is_invulnerable = true
		invulnerability_timer = invulnerability_duration
		show_hp_indicator()
		return
		
	current_health = max(0, current_health - amount)
	_resolve_combo("lost")
	is_invulnerable = true
	invulnerability_timer = invulnerability_duration
	show_hp_indicator()
	
	# Odrzut gracza (Knockback) od źródła obrażeń
	if source_position != Vector2.ZERO:
		var knock_dir = sign(global_position.x - source_position.x)
		if knock_dir == 0.0:
			knock_dir = -facing_direction
		velocity.x = knock_dir * 180.0
		velocity.y = -160.0
	
	_update_hp_indicator()
	_apply_squash_stretch(Vector2(1.32, 0.72))
	add_camera_shake(4.5)
	if current_health > 0:
		_trigger_hitstop(hitstop_duration)
	Events.player_hit.emit(amount)
	Events.player_health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		Events.player_died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = clampi(current_health + amount, 0, max_health)
	show_hp_indicator()
	_update_hp_indicator()
	Events.player_health_changed.emit(current_health, max_health)

func set_max_health(new_max: int, refill: bool = false) -> void:
	max_health = max(1, new_max)
	if refill:
		current_health = max_health
	else:
		current_health = clampi(current_health, 1, max_health)
	show_hp_indicator()
	_update_hp_indicator()
	Events.player_health_changed.emit(current_health, max_health)

func _update_hp_indicator() -> void:
	var hp_container: Node2D = get_node_or_null("HpSquares")
	if not hp_container:
		return
		
	var existing = hp_container.get_children()
	if existing.size() != max_health:
		for child in existing:
			hp_container.remove_child(child)
			child.queue_free()
		
		var star_tex: Texture2D = null
		if ResourceLoader.exists("res://assets/Gwiazdka.png"):
			star_tex = load("res://assets/Gwiazdka.png")
		
		var spacing = 13.0
		var total_w = (max_health - 1) * spacing
		var start_x = -total_w / 2.0
		
		for i in range(max_health):
			if star_tex:
				var spr = Sprite2D.new()
				spr.name = "Star%d" % (i + 1)
				spr.texture = star_tex
				spr.scale = Vector2(0.65, 0.65)
				spr.position = Vector2(start_x + i * spacing, 0)
				hp_container.add_child(spr)
			else:
				var rect = ColorRect.new()
				rect.name = "Square%d" % (i + 1)
				rect.size = Vector2(5.0, 4.0)
				rect.position = Vector2(start_x + i * spacing, 0)
				rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hp_container.add_child(rect)
		call_deferred("_apply_hp_colors", current_health)
		return
		
	_apply_hp_colors(current_health)

func _apply_hp_colors(health: int) -> void:
	var hp_container: Node2D = get_node_or_null("HpSquares")
	if not hp_container:
		return
	var children = hp_container.get_children()
	for i in range(children.size()):
		var node = children[i]
		var is_active = (i < health)
		if node is Sprite2D or node is TextureRect:
			node.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.25, 0.25, 0.25, 0.35)
		elif node is ColorRect:
			node.color = Color(0.9, 0.2, 0.2, 1.0) if is_active else Color(0.2, 0.2, 0.2, 0.35)

## Aktualizuje drenaż staminy podczas wspinaczki (z uwzględnieniem mnożnika wall_climb).
func _update_stamina(delta: float, is_draining: bool) -> void:
	if is_draining:
		var climb_cost_rate: float = get_move_stamina_cost("wall_climb")
		var drained: float = delta * climb_cost_rate
		var pre_stamina: float = wall_stamina
		wall_stamina = max(0.0, wall_stamina - drained)
		used_special_in_current_air = true
		airborne_stamina_ceiling = max(wall_stamina, pre_stamina - drained * 0.25)
		if is_instance_valid(Events) and is_instance_valid(Events.ai_director) and is_inside_tree():
			Events.ai_director.record_move_use("wall_climb", delta)
		
	Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
	_update_stamina_bar()

func _update_stamina_bar() -> void:
	if not stamina_bar:
		return
	stamina_bar.max_value = wall_climb_max_stamina
	stamina_bar.value = wall_stamina
	
	var show_bar = (wall_stamina < wall_climb_max_stamina - 0.02) or (current_state == State.WALL_CLIMB or current_state == State.WALL_SLIDE)
	stamina_bar.visible = show_bar
	
	if show_bar:
		var ratio = wall_stamina / max(0.01, wall_climb_max_stamina)
		var fill_style = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if ratio > 0.5:
				fill_style.bg_color = Color(0.23, 0.96, 0.42, 1.0)
			elif ratio > 0.25:
				fill_style.bg_color = Color(0.96, 0.82, 0.23, 1.0)
			else:
				fill_style.bg_color = Color(0.96, 0.25, 0.25, 1.0)

# --- Pomocnicze odczyty wejścia ---
func _get_input_direction() -> float:
	return Input.get_axis("move_left", "move_right")

func _get_vertical_input() -> float:
	return Input.get_axis("move_up", "move_down")

func _is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump")

func _is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump")

func _is_dash_just_pressed() -> bool:
	return Input.is_action_just_pressed("dash")

func _is_crouch_pressed() -> bool:
	return Input.is_action_pressed("crouch_slide")

const TRICK_ACTIONS: Dictionary = {"trick_flip": "flip", "trick_star": "star", "trick_finish": "finish"}

func _is_trick_pressed() -> bool:
	for a in TRICK_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false

## Zwraca rodzaj tricku, którego klawisz wciśnięto w tej klatce ("" gdy żaden).
func _trick_just_pressed_kind() -> String:
	for a in TRICK_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return String(TRICK_ACTIONS[a])
	return ""

func _can_stand_up() -> bool:
	if ceiling_checker:
		ceiling_checker.force_shapecast_update()
		return not ceiling_checker.is_colliding()
	return true

func _play_sfx(audio: AudioStreamPlayer2D) -> void:
	if audio and audio.stream:
		audio.play()

# --- Zmiana Stanu ---
func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
		
	if new_state != State.IDLE:
		idle_trick_timer = 0.0
		
	# Exit logic ze stanów kucania/wślizgu
	if current_state == State.CROUCH or current_state == State.SLIDE:
		if new_state != State.CROUCH and new_state != State.SLIDE:
			if not _can_stand_up():
				return
			_set_collider_crouched(false)
			
	current_state = new_state
	Events.player_state_changed.emit(State.keys()[new_state])

# --- Logika Stanów (Model Dawnosaur: Akceleracja / Max Speed / Deakceleracja) ---

func _apply_horizontal_movement(input_x: float, max_spd: float, is_air: bool, is_apex: bool, delta: float, control_scale: float = 1.0, allow_uncapped: bool = true) -> void:
	var target_speed: float = input_x * max_spd
	if is_air and is_apex:
		target_speed *= jump_hang_max_speed_mult

	var accel_boost: float = get_accel_boost_multiplier()
	if allow_uncapped and not is_air and absf(input_x) > 0.01 and signf(velocity.x) == signf(input_x) and absf(velocity.x) >= absf(target_speed):
		var over_speed: float = maxf(0.0, absf(velocity.x) - absf(target_speed))
		var sqrt_accel: float = (uncapped_accel_rate * accel_boost * control_scale) / (1.0 + over_speed / maxf(1.0, uncapped_accel_falloff))
		velocity.x += input_x * sqrt_accel * delta
		return

	var accel_rate: float
	if not is_air:
		accel_rate = (run_accel_amount * accel_boost) if absf(target_speed) > 0.01 else run_deccel_amount
	else:
		accel_rate = (run_accel_amount * accel_boost * accel_in_air) if absf(target_speed) > 0.01 else (run_deccel_amount * deccel_in_air)

	if is_air and is_apex:
		accel_rate *= jump_hang_accel_mult

	if input_x != 0.0 and velocity.x != 0.0 and signf(input_x) != signf(velocity.x):
		accel_rate *= turnaround_accel_mult

	accel_rate *= control_scale

	# Konserwacja pędu (Conserve Momentum): w locie w tę samą stronę nie hamujemy nadmiarowej prędkości
	if do_conserve_momentum and is_air and absf(velocity.x) > absf(target_speed) and signf(velocity.x) == signf(target_speed) and absf(target_speed) > 0.01:
		accel_rate = 0.0

	var speed_dif: float = target_speed - velocity.x
	if accel_rate > 0.0 and absf(speed_dif) > 0.001:
		var movement: float = pow(absf(speed_dif) * accel_rate, vel_power) * signf(speed_dif)
		var next_vx: float = velocity.x + movement * delta
		if (speed_dif > 0.0 and next_vx > target_speed) or (speed_dif < 0.0 and next_vx < target_speed):
			next_vx = target_speed
		velocity.x = next_vx

	if not is_air and absf(input_x) < 0.01:
		var friction_step: float = max_spd * friction_amount * 15.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, friction_step)
		if absf(velocity.x) < 2.0:
			velocity.x = 0.0

# 1. Ziemia (IDLE & RUN)
func _state_ground(delta: float) -> void:
	var input_x = _get_input_direction()
	
	# Wejście w Dash (wymaga staminy, obsługuje bufor!)
	if dash_buffer_timer > 0.0 and dash_cooldown_timer <= 0.0:
		if can_use_special_move("dash"):
			_start_dash(input_x)
			return
		
	# Wejście w Kucanie lub Wślizg
	if _is_crouch_pressed():
		if not _slide_needs_release and slide_cooldown_timer <= 0.0 and abs(velocity.x) > 95.0:
			_start_slide()
			return
		else:
			_change_state(State.CROUCH)
			_set_collider_crouched(true)
			return
			
	# Wejście w Skok (zwykły skok z ziemi nie zużywa staminy)
	if _is_jump_just_pressed() or jump_buffer_timer > 0.0:
		_execute_jump()
		return
		
	# Rozpoczęcie wspinaczki bezpośrednio przy ścianie po naciśnięciu W (góra)
	if is_on_wall() and _get_vertical_input() < 0.0 and can_use_special_move("wall_climb"):
		var wall_norm = get_wall_normal()
		if abs(wall_norm.x) > 0.7:
			last_wall_normal = wall_norm
			facing_direction = -sign(wall_norm.x)
			wall_stick_timer = wall_stick_time
			_change_state(State.WALL_CLIMB)
			return
		
	# Zejście z platformy
	if not is_on_floor():
		airborne_origin_y = global_position.y
		_change_state(State.FALL)
		return
		
	# Ruch poziomy (3 etapy: akceleracja, nieograniczona prędkość pierwiastkowa, deakceleracja + tarcie)
	_resolve_combo("land")
	_apply_horizontal_movement(input_x, speed, false, false, delta, 1.0, true)
	if input_x != 0.0:
		idle_trick_timer = 0.0
		facing_direction = input_x
		_change_state(State.RUN)
	else:
		_change_state(State.IDLE)
		if absf(velocity.x) < 5.0 and is_on_floor():
			idle_trick_timer += delta
			if idle_trick_timer >= 7.0:
				if anim_sprite and anim_sprite.animation != "idle_special":
					if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle_special"):
						anim_sprite.play("idle_special")
		else:
			idle_trick_timer = 0.0
		
	velocity.y = 0.0

# 2. Powietrze (JUMP & FALL)
func _state_air(delta: float) -> void:
	idle_trick_timer = 0.0
	var input_x = _get_input_direction()
	var is_apex: bool = absf(velocity.y) < jump_hang_time_threshold

	var ctrl_scale: float = 1.0
	if wall_jump_lock_timer > 0.0 and input_x != 0.0 and last_wall_jump_normal != Vector2.ZERO and signf(input_x) == -signf(last_wall_jump_normal.x):
		ctrl_scale = wall_jump_air_control_mult

	if input_x != 0.0:
		facing_direction = input_x
	_apply_horizontal_movement(input_x, speed, true, is_apex, delta, ctrl_scale, false)
		
	# Wejście w Dash w powietrzu (wymaga staminy, obsługuje bufor!)
	if dash_buffer_timer > 0.0 and can_air_dash and dash_cooldown_timer <= 0.0:
		if can_use_special_move("dash"):
			can_air_dash = false
			_resolve_combo("land")
			_start_dash(input_x)
			return
		
	# Combo tricków: [Trick] + kierunek (zbuforowane naciśnięcie z ostatnich klatek też się liczy)
	if trick_buffer_timer > 0.0 and not is_on_wall():
		if request_trick(trick_buffer_kind):
			trick_buffer_timer = 0.0
	_update_trick(delta)

	# Grawitacja: Jump Hang Time + szybsze opadanie + zmienna wysokość skoku
	if velocity.y < 0.0 and not _is_jump_pressed():
		velocity.y += gravity * delta * (1.0 / jump_cut_multiplier)
	elif is_apex:
		velocity.y = min(velocity.y + gravity * jump_hang_gravity_mult * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = min(velocity.y + gravity * fall_gravity_multiplier * delta, max_fall_speed)
	else:
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
		
	# Buforowanie skoku, Coyote Time, Wall Coyote Time i Podwójny Skok
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_execute_jump()
		return
	elif jump_buffer_timer > 0.0 and wall_coyote_timer > 0.0:
		_execute_wall_jump()
		return
	elif _is_jump_just_pressed() and can_double_jump and can_use_special_move("double_jump"):
		_execute_double_jump()
		return
			
	# Detekcja lądowania (nie przy ruchu w górę – np. w klatce wybicia z trampoliny
	# is_on_floor() jest jeszcze nieaktualne i zbuforowany skok nadpisałby wybicie)
	if is_on_floor() and velocity.y >= 0.0:
		_resolve_combo("land")
		if jump_buffer_timer > 0.0:
			_execute_jump()
		elif _is_crouch_pressed() and (_slide_needs_release or absf(velocity.x) <= 95.0):
			_change_state(State.CROUCH)
			_set_collider_crouched(true)
		else:
			_change_state(State.RUN if input_x != 0.0 else State.IDLE)
		return
		
	# Detekcja ściany (Wall slide / climb)
	if is_on_wall():
		var wall_norm = get_wall_normal()
		if abs(wall_norm.x) > 0.7:
			var pushing_into_wall = (input_x != 0.0 and sign(input_x) == -sign(wall_norm.x))
			var climbing_up = (_get_vertical_input() < 0.0 and can_use_special_move("wall_climb"))
			
			# Chwytamy ścianę jeśli naciskamy w jej stronę LUB chcemy się wspinać
			if pushing_into_wall or climbing_up:
				_resolve_combo("land")
				last_wall_normal = wall_norm
				facing_direction = -sign(wall_norm.x)
				wall_stick_timer = wall_stick_time
				_change_state(State.WALL_CLIMB if climbing_up else State.WALL_SLIDE)
				return

# 3. Dash (Zryw poziomy - długi i snappy)
func _state_dash(delta: float) -> void:
	idle_trick_timer = 0.0
	dash_timer -= delta
	velocity.x = dash_direction * maxf(dash_speed, _pre_dash_speed)
	velocity.y = 0.0

	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = 0.028
		_spawn_afterimage(Color(0.45, 0.92, 1.0, 0.58))

	var exit_speed: float = maxf(_pre_dash_speed, dash_speed * dash_exit_speed_factor)
	# Pozwala przerwać naziemny dash skokiem z zachowaniem płynnego pędu
	if is_on_floor() and jump_buffer_timer > 0.0:
		velocity.x = dash_direction * exit_speed
		_execute_jump()
		return
	
	if dash_timer <= 0.0:
		velocity.x = dash_direction * exit_speed
		if is_on_floor():
			_change_state(State.RUN if _get_input_direction() != 0.0 else State.IDLE)
		else:
			_change_state(State.FALL)

func _start_dash(input_x: float) -> void:
	if not consume_special_move_stamina("dash"):
		return
	_resolve_combo("land")
	dash_buffer_timer = 0.0
	dash_direction = input_x if input_x != 0.0 else facing_direction
	_pre_dash_speed = absf(velocity.x) if signf(velocity.x) == signf(dash_direction) else 0.0
	facing_direction = dash_direction
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	_afterimage_timer = 0.0
	_change_state(State.DASH)
	_apply_squash_stretch(Vector2(1.38, 0.70))
	_spawn_dust_burst(global_position + Vector2(0, 12), 6, Color(0.5, 0.92, 1.0, 0.85))
	_spawn_afterimage(Color(0.45, 0.92, 1.0, 0.65))
	add_camera_shake(1.8)
	if anim_sprite:
		anim_sprite.play("dash")
	_play_sfx(audio_dash)
	Events.player_dashed.emit(Vector2(dash_direction, 0.0))

# 4. Kucanie (CROUCH)
func _state_crouch(delta: float) -> void:
	idle_trick_timer = 0.0
	var input_x = _get_input_direction()
	
	if not _is_crouch_pressed():
		if _can_stand_up():
			_set_collider_crouched(false)
			_change_state(State.RUN if input_x != 0.0 else State.IDLE)
			return
		
	if jump_buffer_timer > 0.0:
		if _can_stand_up():
			_set_collider_crouched(false)
			_execute_jump()
			return
		
	if input_x != 0.0:
		facing_direction = input_x
	_apply_horizontal_movement(input_x, crouch_speed, false, false, delta, 1.0, false)
		
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
		if _can_stand_up():
			_set_collider_crouched(false)
			_change_state(State.FALL)
			return
	else:
		velocity.y = 0.0

# 5. Wślizg (SLIDE): krótki zryw z pełną prędkością, potem stopniowa utrata pędu
#    (opór proporcjonalny do prędkości + małe stałe tarcie -> szybki start, łagodne wygaszanie).
func _state_slide(delta: float) -> void:
	idle_trick_timer = 0.0
	var input_x: float = _get_input_direction()
	var dir: float = signf(velocity.x) if velocity.x != 0.0 else slide_direction
	var opposing: bool = (input_x != 0.0 and signf(input_x) != dir)
	var brake: float = slide_brake_multiplier if opposing else 1.0
	var spd: float = absf(velocity.x)
	slide_timer -= delta
	if slide_timer > 0.0:
		spd = maxf(0.0, spd - slide_burst_friction * brake * delta)
	else:
		spd = maxf(0.0, spd - (slide_drag * spd + slide_friction) * brake * delta)
	velocity.x = dir * spd
	velocity.y = 0.0

	# Smuga kurzu za szybkim wślizgiem
	if spd > speed:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.06
			_spawn_dust_burst(global_position + Vector2(-dir * 6.0, 14), 2, Color(0.88, 0.88, 0.92, 0.6))

	if jump_buffer_timer > 0.0 and _can_stand_up():
		_set_collider_crouched(false)
		velocity.x = dir * minf(spd, maxf(slide_jump_max_speed, get_effective_speed()))
		_execute_jump()
		return

	# Puszczony przycisk kucania + kierunek zgodny z ruchem: płynne przejście w bieg, gdy pęd spadnie do prędkości biegu
	if not _is_crouch_pressed() and input_x != 0.0 and not opposing and spd <= get_effective_speed() and _can_stand_up():
		_set_collider_crouched(false)
		_change_state(State.RUN)
		return

	if spd < slide_min_speed:
		if _is_crouch_pressed() or not _can_stand_up():
			_change_state(State.CROUCH)
		else:
			_set_collider_crouched(false)
			_change_state(State.RUN if input_x != 0.0 else State.IDLE)
		return

	if not is_on_floor():
		if _can_stand_up():
			_set_collider_crouched(false)
			_change_state(State.FALL)
		else:
			_change_state(State.CROUCH)

func _start_slide() -> void:
	slide_direction = facing_direction
	_slide_needs_release = true
	slide_cooldown_timer = slide_cooldown
	slide_timer = slide_burst_time
	_afterimage_timer = 0.0
	var cur_spd: float = absf(velocity.x)
	var launch_spd: float = maxf(slide_burst_speed, cur_spd * slide_burst_carry)
	velocity.x = slide_direction * launch_spd
	_set_collider_crouched(true)
	_change_state(State.SLIDE)
	_apply_squash_stretch(Vector2(1.32, 0.68))
	_spawn_dust_burst(global_position + Vector2(0, 14), 7, Color(0.88, 0.88, 0.92, 0.75))
	if anim_sprite:
		anim_sprite.play("slide")
	Events.player_slid.emit()

# 6. Ściany (WALL SLIDE & WALL CLIMB)
func _state_wall(delta: float) -> void:
	idle_trick_timer = 0.0
	if is_on_floor():
		wall_coyote_timer = 0.0
		wall_stick_timer = 0.0
		_change_state(State.RUN if _get_input_direction() != 0.0 else State.IDLE)
		return
		
	if not is_on_wall():
		_change_state(State.FALL)
		return
		
	last_wall_normal = get_wall_normal()
	wall_coyote_timer = wall_coyote_time
	var vertical_input = _get_vertical_input()
	var horizontal_input = _get_input_direction()
	
	# Wall Jump (z buforem!)
	if jump_buffer_timer > 0.0:
		_execute_wall_jump()
		return

	# Dash ze ściany (z buforem!)
	if dash_buffer_timer > 0.0 and can_air_dash and dash_cooldown_timer <= 0.0:
		if can_use_special_move("dash"):
			can_air_dash = false
			wall_coyote_timer = 0.0
			wall_stick_timer = 0.0
			var away_dir: float = sign(last_wall_normal.x) if last_wall_normal.x != 0.0 else -facing_direction
			_start_dash(away_dir)
			return
		
	# Odklejenie się od ściany z krótkim oknem Wall-Stick (chroni przed przypadkowym FALL przed Wall Jumpem)
	if horizontal_input != 0.0 and sign(horizontal_input) == sign(last_wall_normal.x):
		wall_stick_timer -= delta
		if wall_stick_timer <= 0.0:
			_change_state(State.FALL)
			return
	else:
		wall_stick_timer = wall_stick_time
		
	# Docisk poziomy do ściany, by utrzymać kontakt z colliderem w move_and_slide
	velocity.x = -last_wall_normal.x * 20.0
	
	# Wspinaczka w górę (Wall Climb) z limitem staminy i dynamicznym mnożnikiem
	if vertical_input < 0.0 and can_use_special_move("wall_climb"):
		_change_state(State.WALL_CLIMB)
		_update_stamina(delta, true)
		velocity.y = -wall_climb_speed
	elif vertical_input > 0.0:
		_change_state(State.WALL_SLIDE)
		velocity.y = wall_slide_speed * 1.8
	else:
		_change_state(State.WALL_SLIDE)
		velocity.y = wall_slide_speed

# --- Akcje Skoków ---
func _execute_jump() -> void:
	airborne_origin_y = global_position.y
	airborne_stamina_ceiling = wall_climb_max_stamina
	used_special_in_current_air = false
	# Skok nigdy nie spowalnia szybszego ruchu w górę (np. zbuforowany skok w klatce wybicia z trampoliny)
	velocity.y = minf(velocity.y, jump_velocity)
	coyote_timer = 0.0
	wall_coyote_timer = 0.0
	wall_stick_timer = 0.0
	jump_buffer_timer = 0.0
	_change_state(State.JUMP)
	_apply_squash_stretch(Vector2(0.78, 1.24))
	_spawn_dust_burst(global_position + Vector2(0, 14), 5, Color(0.88, 0.90, 0.96, 0.8))
	if anim_sprite:
		anim_sprite.play("jump")
	_play_sfx(audio_jump)
	Events.player_jumped.emit(false)

func _execute_double_jump() -> void:
	if not consume_special_move_stamina("double_jump"):
		return
	# Podwójny skok nigdy nie hamuje szybszego wznoszenia (np. tuż po wybiciu z trampoliny)
	velocity.y = minf(velocity.y, double_jump_velocity)
	can_double_jump = false
	jump_buffer_timer = 0.0
	_change_state(State.JUMP)
	_apply_squash_stretch(Vector2(0.76, 1.26))
	_spawn_dust_burst(global_position + Vector2(0, 12), 6, Color(0.55, 0.95, 1.0, 0.85))
	if anim_sprite:
		anim_sprite.play("double_jump")
	_play_sfx(audio_jump)
	Events.player_jumped.emit(true)

func _execute_wall_jump() -> void:
	# Wall Jump z tej samej ściany (np. skakanie w górę po jednej ścianie) jest mocno osłabiony i kosztuje staminę!
	var is_same_wall: bool = (last_wall_jump_normal != Vector2.ZERO and signf(last_wall_normal.x) == signf(last_wall_jump_normal.x))
	var jump_y: float = wall_jump_velocity.y

	if is_same_wall:
		if wall_stamina + 0.001 < same_wall_jump_stamina_cost:
			if is_instance_valid(Events):
				Events.stamina_action_rejected.emit("wall_climb", same_wall_jump_stamina_cost, wall_stamina)
			velocity.x = last_wall_normal.x * 110.0
			velocity.y = maxf(velocity.y, 40.0)
			wall_coyote_timer = 0.0
			wall_stick_timer = 0.0
			jump_buffer_timer = 0.0
			_change_state(State.FALL)
			return
		var pre_stam: float = wall_stamina
		wall_stamina = maxf(0.0, wall_stamina - same_wall_jump_stamina_cost)
		consecutive_same_wall_jumps += 1
		jump_y = wall_jump_velocity.y * pow(same_wall_jump_decay, consecutive_same_wall_jumps)
		airborne_stamina_ceiling = minf(airborne_stamina_ceiling, maxf(wall_stamina, pre_stam - same_wall_jump_stamina_cost * 0.25))
		if is_instance_valid(Events):
			Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
		_update_stamina_bar()
	else:
		consecutive_same_wall_jumps = 0
		can_double_jump = true
		can_air_dash = true
		airborne_stamina_ceiling = minf(airborne_stamina_ceiling, wall_stamina + 0.12)

	used_special_in_current_air = true
	last_wall_jump_normal = last_wall_normal
	wall_jump_lock_timer = wall_jump_control_lock_time
	velocity.x = last_wall_normal.x * wall_jump_velocity.x
	velocity.y = jump_y
	facing_direction = sign(velocity.x) if velocity.x != 0.0 else facing_direction
	coyote_timer = 0.0
	wall_coyote_timer = 0.0
	wall_stick_timer = 0.0
	jump_buffer_timer = 0.0
	_change_state(State.JUMP)
	_apply_squash_stretch(Vector2(0.76, 1.25))
	_spawn_dust_burst(global_position + Vector2(-last_wall_normal.x * 8.0, 0.0), 5, Color(0.90, 0.92, 0.98, 0.8))
	if anim_sprite:
		anim_sprite.play("jump")
	_play_sfx(audio_jump)
	Events.player_jumped.emit(false)

func _apply_corner_correction() -> void:
	if velocity.y >= 0.0 or corner_correction_pixels <= 0:
		return
	if not is_inside_tree() or not collision_shape or not collision_shape.shape:
		return
	if not test_move(global_transform, Vector2(0.0, -4.0)):
		return
	for offset in range(1, corner_correction_pixels + 1):
		var right_clear: bool = not test_move(global_transform.translated(Vector2(offset, 0.0)), Vector2(0.0, -4.0))
		var left_clear: bool = not test_move(global_transform.translated(Vector2(-offset, 0.0)), Vector2(0.0, -4.0))
		if right_clear and not left_clear:
			global_position.x += offset
			return
		elif left_clear and not right_clear:
			global_position.x -= offset
			return

func _on_landed(impact_vy: float) -> void:
	_resolve_combo("land")
	var impact_ratio: float = clampf(abs(impact_vy) / maxf(1.0, max_fall_speed), 0.15, 1.0)
	_apply_squash_stretch(Vector2(1.0 + 0.28 * impact_ratio, 1.0 - 0.24 * impact_ratio))
	var dust_count: int = 4 + int(round(impact_ratio * 4.0))
	_spawn_dust_burst(global_position + Vector2(0, 14), dust_count, Color(0.88, 0.90, 0.96, 0.78))

# --- Pomocnicze funkcje Hitboxa i Wizualiów ---
func _set_collider_crouched(crouched: bool) -> void:
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return
	if crouched:
		shape.size = crouch_shape_size
		collision_shape.position = crouch_shape_position
	else:
		shape.size = standing_shape_size
		collision_shape.position = standing_shape_position
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
		
func _update_visuals(delta: float = 0.016) -> void:
	_visual_scale = _visual_scale.lerp(Vector2.ONE, minf(1.0, squash_recovery_speed * delta))
	var dir_x: float = facing_direction
	if current_state == State.WALL_SLIDE or current_state == State.WALL_CLIMB:
		dir_x = sign(last_wall_normal.x) if last_wall_normal.x != 0.0 else -facing_direction
	visuals.scale = Vector2(dir_x * _visual_scale.x, _visual_scale.y)

	if is_invulnerable:
		visuals.modulate = Color(1.0, 1.0, 1.0, 0.35 if fmod(invulnerability_timer, 0.2) > 0.1 else 1.0)
	elif invincibility_powerup_timer > 0.0:
		var pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		visuals.modulate = Color(1.0, 0.82 + pulse * 0.18, 0.2 + pulse * 0.6, 1.0)
	elif speed_powerup_timer > 0.0 or has_powerup("SPEED_BOOST"):
		var pulse = (sin(Time.get_ticks_msec() * 0.02) + 1.0) * 0.5
		visuals.modulate = Color(0.4 + pulse * 0.3, 0.9, 1.0, 1.0)
	elif is_tricking:
		var pulse = (sin(Time.get_ticks_msec() * 0.022) + 1.0) * 0.5
		visuals.modulate = Color(1.0, 0.92 + pulse * 0.08, 0.65 + pulse * 0.35, 1.0)
	elif has_shield or bool(get_meta("has_portal_shield", false)):
		visuals.modulate = Color(0.7, 0.95, 1.0, 1.0)
	else:
		visuals.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if not anim_sprite:
		return
		
	if anim_sprite.animation == "appear" and anim_sprite.is_playing():
		return
		
	if is_tricking:
		# animację tricku uruchamia _start_trick (trick_flip / trick_star / trick_finish)
		return
		
	match current_state:
		State.IDLE:
			if anim_sprite.animation != "idle_special" or not anim_sprite.is_playing():
				anim_sprite.play("idle")
		State.RUN:
			if anim_sprite.animation != "run_start" and anim_sprite.animation != "run":
				if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("run_start") and absf(velocity.x) < get_effective_speed() * 0.85:
					anim_sprite.play("run_start")
				else:
					anim_sprite.play("run")
		State.JUMP:
			if anim_sprite.animation != "double_jump" or not anim_sprite.is_playing():
				anim_sprite.play("jump")
		State.FALL:
			anim_sprite.play("fall")
		State.DASH:
			anim_sprite.play("dash")
		State.CROUCH:
			anim_sprite.play("crouch")
		State.SLIDE:
			anim_sprite.play("slide")
		State.WALL_SLIDE:
			anim_sprite.play("wall_slide")
		State.WALL_CLIMB:
			anim_sprite.play("wall_climb")

func _apply_squash_stretch(target_scale: Vector2) -> void:
	_visual_scale = target_scale

func add_camera_shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)

func _update_camera(delta: float) -> void:
	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)

	if not camera:
		return
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_left_margin = camera_drag_horizontal_margin
	camera.drag_right_margin = camera_drag_horizontal_margin
	camera.drag_top_margin = camera_drag_vertical_margin
	camera.drag_bottom_margin = camera_drag_vertical_margin
	camera.position_smoothing_speed = camera_smoothing_speed

	var shake_off := Vector2.ZERO
	if _shake_strength > 0.05:
		shake_off = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength))
	camera.offset = shake_off

func _spawn_dust_burst(pos: Vector2, count: int, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree() or not get_parent():
		return
	var parent_node := get_parent()
	for i in range(count):
		var particle := ColorRect.new()
		particle.size = Vector2(3.0, 3.0)
		particle.position = pos - particle.size * 0.5
		particle.color = color
		particle.z_index = 5
		parent_node.add_child(particle)

		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		var dist := randf_range(8.0, 22.0)
		var target_pos := particle.position + Vector2(cos(angle) * dist, sin(angle) * dist * 0.6)
		var tw := particle.create_tween()
		tw.set_parallel(true)
		tw.tween_property(particle, "position", target_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(particle, "modulate:a", 0.0, 0.24)
		tw.tween_property(particle, "scale", Vector2(0.25, 0.25), 0.24)
		tw.chain().tween_callback(particle.queue_free)

func _spawn_afterimage(tint: Color) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree() or not get_parent() or not anim_sprite or not anim_sprite.sprite_frames:
		return
	var anim_name := anim_sprite.animation
	if not anim_sprite.sprite_frames.has_animation(anim_name):
		return
	var tex: Texture2D = anim_sprite.sprite_frames.get_frame_texture(anim_name, anim_sprite.frame)
	if not tex:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.global_position = anim_sprite.global_position
	ghost.scale = Vector2(facing_direction * absf(anim_sprite.scale.x), anim_sprite.scale.y)
	ghost.modulate = tint
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tw.tween_callback(ghost.queue_free)

func _trigger_hitstop(duration: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree() or duration <= 0.0 or _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if is_instance_valid(self):
		_hitstop_active = false
	Engine.time_scale = 1.0
