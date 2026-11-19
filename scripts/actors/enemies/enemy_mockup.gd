extends Area2D
class_name EnemyMockup

## Wróg ze spritesheetu (enemies-spritesheet-export.png)
## Mechaniki walki i interakcji:
## 1. Skok na wroga z góry (Stomp): pokonuje wroga i odbija gracza w górę.
## 2. Dash przez wroga: gracz na dashu (is_dashing) unika trafienia bez utraty HP.
## 3. Zwykły kontakt: gracz otrzymuje obrażenia kontaktowe (take_damage).

@export var contact_damage: int = 1
@export var bounce_velocity: float = -280.0
@export var move_speed: float = 35.0
@export var patrol_range: float = 40.0

var start_x: float = 0.0
var move_dir: float = 1.0
var is_dead: bool = false
var anim_timer: float = 0.0
var current_frame: int = 0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	add_to_group("enemies")
	start_x = position.x
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_setup_sprite_texture()

func _setup_sprite_texture() -> void:
	if sprite and ResourceLoader.exists("res://assets/enemies-spritesheet-export.png"):
		sprite.texture = load("res://assets/enemies-spritesheet-export.png")
		sprite.hframes = 4
		sprite.vframes = 12
		sprite.frame = 0

func _process(delta: float) -> void:
	if is_dead:
		return
		
	# Animacja klatek pierwszego wroga (klatki 0-3 w pierwszym wierszu spritesheetu)
	anim_timer += delta
	if anim_timer >= 0.15:
		anim_timer = 0.0
		current_frame = (current_frame + 1) % 4
		if sprite:
			sprite.frame = current_frame
			
	# Prosty patrol lewo-prawo
	if patrol_range > 0.0:
		position.x += move_dir * move_speed * delta
		if sprite:
			sprite.flip_h = (move_dir < 0.0)
		if abs(position.x - start_x) >= patrol_range:
			move_dir = -move_dir

func _on_body_entered(body: Node2D) -> void:
	if is_dead or not body.is_in_group("player"):
		return
		
	# 1. Gracz wykonuje dash -> unika obrażeń (i-frame dasha)
	if body.has_method("is_dashing") and body.is_dashing():
		return
	if "current_state" in body and body.current_state == 4: # PlayerController.State.DASH
		return
		
	# 2. Gracz skacze na wroga z góry (Stomp)
	# Sprawdzamy czy gracz opada (velocity.y > 0) i czy jego pozycja pionowa jest powyżej wroga
	if body.velocity.y > 0.0 and (body.global_position.y < global_position.y + 4.0):
		defeat(body)
		return
		
	# 3. Zwykły kontakt -> gracz otrzymuje obrażenia
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)

func defeat(killer: Node2D = null) -> void:
	if is_dead:
		return
	is_dead = true
	
	# Odbicie gracza w górę po nadeptaniu na wroga
	if killer is CharacterBody2D:
		killer.velocity.y = bounce_velocity
		if "can_double_jump" in killer:
			killer.can_double_jump = true
			
	queue_free()
