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

# --- Referencje do Węzłów ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ceiling_checker: RayCast2D = $CeilingChecker
@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D

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

# Domyślne rozmiary collidera (stojący vs kucający/wślizg)
var standing_shape_size: Vector2 = Vector2(16, 30)
var standing_shape_position: Vector2 = Vector2(0, 0)
var crouch_shape_size: Vector2 = Vector2(16, 16)
var crouch_shape_position: Vector2 = Vector2(0, 7)

func _ready() -> void:
	add_to_group("player")
	wall_stamina = wall_climb_max_stamina
	Events.player_spawned.emit(self)

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

# --- Aktualizacja Timerów ---
func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		can_double_jump = true
		can_air_dash = true
		wall_stamina = wall_climb_max_stamina
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
		
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)

# --- Pomocnicze odczyty wejścia (Input z obsługą fallbacków klawiatury) ---
func _get_input_direction() -> float:
	var left = Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right = Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	return (1.0 if right else 0.0) - (1.0 if left else 0.0)

func _get_vertical_input() -> float:
	var up = Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var down = Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	return (1.0 if down else 0.0) - (1.0 if up else 0.0)

func _is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) and jump_buffer_timer <= 0.0

func _is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE)

func _is_dash_just_pressed() -> bool:
	return Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_SHIFT)

func _is_crouch_pressed() -> bool:
	return Input.is_action_pressed("crouch_slide") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)

# --- Zmiana Stanu ---
func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
		
	# Exit logic
	if current_state == State.CROUCH or current_state == State.SLIDE:
		if new_state != State.CROUCH and new_state != State.SLIDE:
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
	if _check_jump_input():
		_execute_jump()
		return
		
	# Zejście z platformy
	if not is_on_floor():
		_change_state(State.FALL)
		return
		
	# Ruch poziomy
	if input_x != 0.0:
		facing_direction = input_x
		velocity.x = move_toward(velocity.x, input_x * speed, acceleration * delta)
		_change_state(State.RUN)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_change_state(State.IDLE)
		
	velocity.y = 0.0

# 2. Powietrze (JUMP & FALL)
func _state_air(delta: float) -> void:
	var input_x = _get_input_direction()
	
	if input_x != 0.0:
		facing_direction = input_x
		velocity.x = move_toward(velocity.x, input_x * speed, air_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
		
	# Wejście w Dash w powietrzu
	if _is_dash_just_pressed() and can_air_dash and dash_cooldown_timer <= 0.0:
		can_air_dash = false
		_start_dash(input_x)
		return

func _state_ground(delta: float) -> void:
	var input_x = _get_input_direction()
	if input_x != 0.0:
		facing_direction = input_x
		velocity.x = move_toward(velocity.x, input_x * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
