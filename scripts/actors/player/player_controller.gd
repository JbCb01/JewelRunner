extends CharacterBody2D
class_name PlayerController

## Zaawansowany kontroler gracza 2D dla JewelRunner (Etap 1 - Makieta)
## Obsługuje: bieg, skok o zmiennej wysokości, podwójny skok, coyote time, jump buffer,
## poziomy dash, kucanie, wślizg (slide) z ochroną sufitu, wspinaczkę po ścianie z limitem staminy i wall jump.

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

# --- Parametry Ruchu ---
@export_group("Ruch Poziomy")
@export var speed: float = 175.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0
@export var air_acceleration: float = 800.0
@export var air_friction: float = 300.0

@export_group("Skoki")
@export var jump_velocity: float = -330.0
@export var double_jump_velocity: float = -290.0
@export var jump_cut_multiplier: float = 0.5
@export var gravity: float = 980.0
@export var max_fall_speed: float = 450.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Dash (Zryw)")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

@export_group("Kucanie i Wślizg")
@export var crouch_speed: float = 70.0
@export var slide_initial_speed: float = 320.0
@export var slide_friction: float = 450.0
@export var slide_min_speed: float = 90.0

@export_group("Ściany (Wall Actions)")
@export var wall_slide_speed: float = 55.0
@export var wall_climb_speed: float = 100.0
@export var wall_climb_max_stamina: float = 2.0
@export var wall_jump_velocity: Vector2 = Vector2(230.0, -310.0)

@export_group("Tricki w Powietrzu")
@export var trick_points_per_second: float = 120.0

# --- Referencje do Węzłów ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ceiling_checker: ShapeCast2D = $CeilingChecker
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var visuals: Node2D = $Visuals
@onready var anim_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D

@onready var audio_jump: AudioStreamPlayer2D = $AudioJump
@onready var audio_dash: AudioStreamPlayer2D = $AudioDash
@onready var audio_appear: AudioStreamPlayer2D = $AudioAppear

# --- Zmienne Wewnętrzne / Timery ---
var facing_direction: float = 1.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var can_double_jump: bool = false
var can_air_dash: bool = true

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0

var slide_timer: float = 0.0
var slide_direction: float = 1.0

var wall_stamina: float = 0.0
var last_wall_normal: Vector2 = Vector2.ZERO
var idle_trick_timer: float = 0.0

var is_tricking: bool = false
var trick_point_buffer: float = 0.0

# Domyślne rozmiary collidera (stojący vs kucający/wślizg)
var standing_shape_size: Vector2 = Vector2(18, 30)
var standing_shape_position: Vector2 = Vector2(0, 0)
var crouch_shape_size: Vector2 = Vector2(18, 16)
var crouch_shape_position: Vector2 = Vector2(0, 7)

func _ready() -> void:
	add_to_group("player")
	wall_stamina = wall_climb_max_stamina
	_set_collider_crouched(false)
	_update_stamina_bar()
	Events.player_spawned.emit(self)
	Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
	
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play("appear")
	_play_sfx(audio_appear)

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation == "appear":
		anim_sprite.play("idle")

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	
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
			
	move_and_slide()
	_update_visuals()

# --- Aktualizacja Timerów i Staminy ---
func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		can_double_jump = true
		can_air_dash = true
		if wall_stamina < wall_climb_max_stamina:
			wall_stamina = wall_climb_max_stamina
			Events.player_stamina_changed.emit(wall_stamina, wall_climb_max_stamina)
			_update_stamina_bar()
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
		
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)

func _update_stamina(delta: float, is_draining: bool) -> void:
	if is_draining:
		wall_stamina = max(0.0, wall_stamina - delta)
	elif is_on_floor():
		wall_stamina = wall_climb_max_stamina
		
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
		var ratio = wall_stamina / wall_climb_max_stamina
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

func _is_trick_pressed() -> bool:
	return Input.is_action_pressed("trick") or Input.is_physical_key_pressed(KEY_C)

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
		
	# Exit logic ze stanów kucania/wślizgu
	if current_state == State.CROUCH or current_state == State.SLIDE:
		if new_state != State.CROUCH and new_state != State.SLIDE:
			if not _can_stand_up():
				# Nie pozwalamy wyjść ze stanu kucania jeśli sufit blokuje postać!
				return
			_set_collider_crouched(false)
			
	current_state = new_state
	Events.player_state_changed.emit(State.keys()[new_state])

# --- Logika Stanów ---

# 1. Ziemia (IDLE & RUN)
func _state_ground(delta: float) -> void:
	var input_x = _get_input_direction()
	
	# Wejście w Dash
	if _is_dash_just_pressed() and dash_cooldown_timer <= 0.0:
		_start_dash(input_x)
		return
		
	# Wejście w Kucanie lub Wślizg
	if _is_crouch_pressed():
		if abs(velocity.x) > 110.0:
			_start_slide()
			return
		else:
			_change_state(State.CROUCH)
			_set_collider_crouched(true)
			return
			
	# Wejście w Skok
	if _is_jump_just_pressed() or jump_buffer_timer > 0.0:
		_execute_jump()
		return
		
	# Rozpoczęcie wspinaczki bezpośrednio przy ścianie po naciśnięciu W (góra)
	if is_on_wall() and _get_vertical_input() < 0.0 and wall_stamina > 0.0:
		var wall_norm = get_wall_normal()
		if abs(wall_norm.x) > 0.7:
			last_wall_normal = wall_norm
			facing_direction = -sign(wall_norm.x)
			_change_state(State.WALL_CLIMB)
			return
		
	# Zejście z platformy
	if not is_on_floor():
		_change_state(State.FALL)
		return
		
	# Ruch poziomy
	if input_x != 0.0:
		is_tricking = false
		trick_point_buffer = 0.0
		facing_direction = input_x
		velocity.x = move_toward(velocity.x, input_x * speed, acceleration * delta)
		_change_state(State.RUN)
	else:
		is_tricking = false
		trick_point_buffer = 0.0
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_change_state(State.IDLE)
		
	velocity.y = 0.0

# 2. Powietrze (JUMP & FALL)
func _state_air(delta: float) -> void:
	idle_trick_timer = 0.0
	var input_x = _get_input_direction()
	
	if input_x != 0.0:
		facing_direction = input_x
		velocity.x = move_toward(velocity.x, input_x * speed, air_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
		
	# Wejście w Dash w powietrzu
	if _is_dash_just_pressed() and can_air_dash and dash_cooldown_timer <= 0.0:
		can_air_dash = false
		is_tricking = false
		trick_point_buffer = 0.0
		_start_dash(input_x)
		return
		
	# Obsługa tricku w powietrzu (trzymanie C podczas skoków i spadków)
	if _is_trick_pressed() and not is_on_wall():
		if not is_tricking:
			is_tricking = true
			if anim_sprite:
				anim_sprite.play("trick")
		# Gromadzenie punktów za trzymanie klawisza C w locie
		trick_point_buffer += trick_points_per_second * delta
		if trick_point_buffer >= 10.0:
			var pts: int = int(trick_point_buffer)
			trick_point_buffer -= pts
			Events.score_added.emit(pts)
			Events.trick_performed.emit(pts)
	else:
		if is_tricking:
			is_tricking = false
			trick_point_buffer = 0.0

	# Grawitacja i zmienna wysokość skoku
	if velocity.y < 0.0 and not _is_jump_pressed():
		velocity.y += gravity * delta * (1.0 / jump_cut_multiplier)
	else:
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
		
	# Buforowanie skoku i podwójny skok
	if _is_jump_just_pressed():
		if coyote_timer > 0.0:
			_execute_jump()
			return
		elif can_double_jump:
			_execute_double_jump()
			return
		else:
			jump_buffer_timer = jump_buffer_time
			
	# Detekcja lądowania
	if is_on_floor():
		is_tricking = false
		trick_point_buffer = 0.0
		if jump_buffer_timer > 0.0:
			_execute_jump()
		else:
			_change_state(State.RUN if input_x != 0.0 else State.IDLE)
		return
		
	# Detekcja ściany (Wall slide / climb)
	if is_on_wall():
		var wall_norm = get_wall_normal()
		if abs(wall_norm.x) > 0.7:
			var pushing_into_wall = (input_x != 0.0 and sign(input_x) == -sign(wall_norm.x))
			var climbing_up = (_get_vertical_input() < 0.0 and wall_stamina > 0.0)
			
			# Chwytamy ścianę jeśli naciskamy w jej stronę LUB chcemy się wspinać
			if pushing_into_wall or climbing_up:
				is_tricking = false
				trick_point_buffer = 0.0
				last_wall_normal = wall_norm
				facing_direction = -sign(wall_norm.x)
				_change_state(State.WALL_CLIMB if climbing_up else State.WALL_SLIDE)
				return

# 3. Dash (Zryw poziomy)
func _state_dash(delta: float) -> void:
	idle_trick_timer = 0.0
	dash_timer -= delta
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0
	
	if dash_timer <= 0.0:
		if is_on_floor():
			_change_state(State.RUN if _get_input_direction() != 0.0 else State.IDLE)
		else:
			_change_state(State.FALL)

func _start_dash(input_x: float) -> void:
	is_tricking = false
	trick_point_buffer = 0.0
	dash_direction = input_x if input_x != 0.0 else facing_direction
	facing_direction = dash_direction
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	_change_state(State.DASH)
	if anim_sprite:
		anim_sprite.play("dash")
	_play_sfx(audio_dash)
	Events.player_dashed.emit(Vector2(dash_direction, 0.0))

# 4. Kucanie (CROUCH)
func _state_crouch(delta: float) -> void:
	idle_trick_timer = 0.0
	var input_x = _get_input_direction()
	
	# Jeśli puszcza klawisz kucania i sufit jest wolny -> wstaje płynnie
	if not _is_crouch_pressed():
		if _can_stand_up():
			_set_collider_crouched(false)
			_change_state(State.RUN if input_x != 0.0 else State.IDLE)
			return
		# Jeśli sufit blokuje, postać POZOSTAJE w kucaniu (nie blokuje ruchu!)
		
	# Skok z kucania tylko gdy sufit jest wolny
	if _is_jump_just_pressed():
		if _can_stand_up():
			_set_collider_crouched(false)
			_execute_jump()
			return
		
	# Poruszanie się w kucaniu (czołganie)
	if input_x != 0.0:
		facing_direction = input_x
		velocity.x = move_toward(velocity.x, input_x * crouch_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		
	# Obsługa podłoża w kucaniu
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
		if _can_stand_up():
			_set_collider_crouched(false)
			_change_state(State.FALL)
			return
	else:
		velocity.y = 0.0

# 5. Wślizg (SLIDE)
func _state_slide(delta: float) -> void:
	idle_trick_timer = 0.0
	# Wyhamowywanie wślizgu
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	velocity.y = 0.0
	
	# Możliwość wyskoczenia z wślizgu tylko gdy sufit wolny
	if _is_jump_just_pressed() and _can_stand_up():
		_set_collider_crouched(false)
		_execute_jump()
		return
		
	# Koniec wślizgu przy niskiej prędkości
	if abs(velocity.x) < slide_min_speed:
		if _is_crouch_pressed() or not _can_stand_up():
			_change_state(State.CROUCH)
		else:
			_set_collider_crouched(false)
			_change_state(State.IDLE)
		return
			
	if not is_on_floor():
		if _can_stand_up():
			_set_collider_crouched(false)
			_change_state(State.FALL)
		else:
			_change_state(State.CROUCH)

func _start_slide() -> void:
	slide_direction = facing_direction
	velocity.x = slide_direction * slide_initial_speed
	_set_collider_crouched(true)
	_change_state(State.SLIDE)
	if anim_sprite:
		anim_sprite.play("slide")
	Events.player_slid.emit()

# 6. Ściany (WALL SLIDE & WALL CLIMB)
func _state_wall(delta: float) -> void:
	idle_trick_timer = 0.0
	if is_on_floor():
		_change_state(State.RUN if _get_input_direction() != 0.0 else State.IDLE)
		return
		
	if not is_on_wall():
		_change_state(State.FALL)
		return
		
	last_wall_normal = get_wall_normal()
	var vertical_input = _get_vertical_input()
	var horizontal_input = _get_input_direction()
	
	# Wall Jump
	if _is_jump_just_pressed():
		_execute_wall_jump()
		return
		
	# Odklejenie się od ściany w przeciwną stronę
	if horizontal_input != 0.0 and sign(horizontal_input) == sign(last_wall_normal.x):
		_change_state(State.FALL)
		return
		
	# Docisk poziomy do ściany, by utrzymać kontakt z colliderem w move_and_slide
	velocity.x = -last_wall_normal.x * 20.0
	
	# Wspinaczka w górę (Wall Climb) z limitem staminy
	if vertical_input < 0.0 and wall_stamina > 0.0:
		_change_state(State.WALL_CLIMB)
		_update_stamina(delta, true)
		velocity.y = -wall_climb_speed
	elif vertical_input > 0.0:
		# Szybsze zsuwanie się w dół
		_change_state(State.WALL_SLIDE)
		velocity.y = wall_slide_speed * 1.8
	else:
		# Zwykłe zsuwanie się (Wall Slide)
		_change_state(State.WALL_SLIDE)
		velocity.y = wall_slide_speed

# --- Akcje Skoków ---
func _execute_jump() -> void:
	velocity.y = jump_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_change_state(State.JUMP)
	if anim_sprite:
		anim_sprite.play("jump")
	_play_sfx(audio_jump)
	Events.player_jumped.emit(false)

func _execute_double_jump() -> void:
	velocity.y = double_jump_velocity
	can_double_jump = false
	jump_buffer_timer = 0.0
	_change_state(State.JUMP)
	if anim_sprite:
		anim_sprite.play("double_jump")
	_play_sfx(audio_jump)
	Events.player_jumped.emit(true)

func _execute_wall_jump() -> void:
	velocity.x = last_wall_normal.x * wall_jump_velocity.x
	velocity.y = wall_jump_velocity.y
	facing_direction = sign(velocity.x)
	can_double_jump = true
	can_air_dash = true
	jump_buffer_timer = 0.0
	_change_state(State.JUMP)
	if anim_sprite:
		anim_sprite.play("jump")
	_play_sfx(audio_jump)
	Events.player_jumped.emit(false)

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

func _update_visuals() -> void:
	# Zwrot postaci
	visuals.scale.x = facing_direction
	visuals.scale.y = 1.0
	visuals.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if not anim_sprite:
		return
		
	# Jeśli postać odgrywa animację pojawienia, pozwólmy jej dokończyć
	if anim_sprite.animation == "appear" and anim_sprite.is_playing():
		return
		
	# Priorytet dla tricku w powietrzu
	if is_tricking:
		if anim_sprite.animation != "trick":
			anim_sprite.play("trick")
		return
		
	# Wybór animacji na podstawie maszyny stanów
	match current_state:
		State.IDLE:
			anim_sprite.play("idle")
		State.RUN:
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
			# W klatce wspinaczki ręce sięgają w lewo, więc odwracamy w stronę normalnej ściany
			visuals.scale.x = sign(last_wall_normal.x) if last_wall_normal.x != 0.0 else -facing_direction
		State.WALL_CLIMB:
			anim_sprite.play("wall_climb")
			visuals.scale.x = sign(last_wall_normal.x) if last_wall_normal.x != 0.0 else -facing_direction
