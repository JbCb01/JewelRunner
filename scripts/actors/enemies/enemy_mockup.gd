extends Area2D
class_name EnemyMockup

## Wróg ze spritesheetu (enemies-spritesheet-export.png) z obsługą 3 archetypów AI i 4 wariantów biomowych.
## Mechaniki walki i interakcji:
## 1. Skok na wroga z góry (Stomp): pokonuje wroga i odbija gracza w górę.
## 2. Dash przez wroga: gracz na dashu (is_dashing) unika trafienia bez utraty HP.
## 3. Zwykły kontakt: gracz otrzymuje obrażenia kontaktowe (take_damage).

enum EnemyArchetype { SLIME = 0, BAT = 1, SPIDER = 2 }
enum AIState { PATROL, ALERT, CHASE, RETURN }

@export var contact_damage: int = 1
@export var bounce_velocity: float = -280.0
@export var move_speed: float = 35.0
@export var patrol_range: float = 40.0

@export_group("AI i Wygląd")
@export var archetype: EnemyArchetype = EnemyArchetype.SLIME
@export var color_variant: int = 0
@export var detection_radius: float = 135.0
@export var chase_speed_multiplier: float = 1.65
@export var hover_amplitude: float = 10.0
@export var hover_frequency: float = 3.2
@export var enable_ai: bool = true

var start_x: float = 0.0
var start_pos: Vector2 = Vector2.ZERO
var move_dir: float = 1.0
var is_dead: bool = false
var anim_timer: float = 0.0
var current_frame: int = 0

var ai_state: AIState = AIState.PATROL
var ai_timer: float = 0.0
var state_timer: float = 0.0
var lunge_cooldown: float = 0.0
var swoop_target: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	add_to_group("enemies")
	start_pos = position
	start_x = position.x
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_setup_sprite_texture()

func configure(
	p_archetype: int,
	p_color_variant: int,
	p_patrol_range: float = 48.0,
	p_move_speed: float = 38.0,
	p_detection_radius: float = 135.0
) -> void:
	archetype = clampi(p_archetype, EnemyArchetype.SLIME, EnemyArchetype.SPIDER) as EnemyArchetype
	color_variant = clampi(p_color_variant, 0, 3)
	patrol_range = max(0.0, p_patrol_range)
	move_speed = max(0.0, p_move_speed)
	detection_radius = max(0.0, p_detection_radius)
	start_pos = position
	start_x = position.x
	ai_state = AIState.PATROL
	state_timer = 0.0
	lunge_cooldown = 0.0
	_setup_sprite_texture()

func _get_sprite_row() -> int:
	return clampi(int(archetype) * 4 + clampi(color_variant, 0, 3), 0, 11)

func _setup_sprite_texture() -> void:
	if not sprite:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite and ResourceLoader.exists("res://assets/enemies-spritesheet-export.png"):
		sprite.texture = load("res://assets/enemies-spritesheet-export.png")
		sprite.hframes = 4
		sprite.vframes = 12
		sprite.frame = _get_sprite_row() * 4 + current_frame

func _process(delta: float) -> void:
	if is_dead:
		return

	var anim_interval: float = 0.10 if (ai_state == AIState.CHASE or ai_state == AIState.ALERT) else 0.15
	anim_timer += delta
	if anim_timer >= anim_interval:
		anim_timer = 0.0
		current_frame = (current_frame + 1) % 4

	_update_ai_movement(delta)
	_update_sprite_visual_state()

func _update_sprite_visual_state() -> void:
	if not sprite:
		return
	sprite.frame = _get_sprite_row() * 4 + current_frame
	sprite.flip_h = (move_dir < 0.0)
	match ai_state:
		AIState.ALERT:
			sprite.modulate = Color(1.0, 0.78, 0.55, 1.0)
		AIState.CHASE:
			sprite.modulate = Color(1.0, 0.88, 0.88, 1.0)
		_:
			sprite.modulate = Color.WHITE
	if archetype == EnemyArchetype.SLIME:
		var hop_height: float = 5.0 if ai_state == AIState.CHASE else 2.5
		sprite.position.y = -abs(sin(ai_timer * 7.5)) * hop_height
	else:
		sprite.position.y = 0.0

func _find_target_player() -> Node2D:
	if not enable_ai or not is_inside_tree():
		return null
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	var best: Node2D = null
	var best_dist_sq: float = INF
	for p in players:
		if p is Node2D and is_instance_valid(p):
			var d_sq: float = global_position.distance_squared_to((p as Node2D).global_position)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best = p as Node2D
	return best

func _update_ai_movement(delta: float) -> void:
	ai_timer += delta
	if lunge_cooldown > 0.0:
		lunge_cooldown = max(0.0, lunge_cooldown - delta)

	var target: Node2D = _find_target_player()
	match archetype:
		EnemyArchetype.BAT:
			_ai_bat(delta, target)
		EnemyArchetype.SPIDER:
			_ai_spider(delta, target)
		_:
			_ai_slime(delta, target)

func _patrol_horizontal(delta: float, speed_mult: float = 1.0) -> void:
	if patrol_range <= 0.0:
		return
	var min_x: float = start_pos.x - patrol_range
	var max_x: float = start_pos.x + patrol_range
	position.x += move_dir * move_speed * speed_mult * delta
	if position.x >= max_x:
		position.x = max_x
		move_dir = -1.0
	elif position.x <= min_x:
		position.x = min_x
		move_dir = 1.0

func _ai_slime(delta: float, target: Node2D) -> void:
	var min_x: float = start_pos.x - patrol_range
	var max_x: float = start_pos.x + patrol_range
	var dx: float = 0.0
	var dy: float = INF
	if target != null:
		dx = target.global_position.x - global_position.x
		dy = abs(target.global_position.y - global_position.y)

	if ai_state == AIState.PATROL:
		if target != null and patrol_range > 0.0 and abs(dx) <= detection_radius and dy <= 48.0:
			ai_state = AIState.CHASE
		else:
			_patrol_horizontal(delta, 1.0)
	elif ai_state == AIState.CHASE:
		if target == null or abs(dx) > detection_radius * 1.35 or dy > 72.0:
			ai_state = AIState.PATROL
			return
		if abs(dx) > 4.0:
			move_dir = sign(dx)
		position.x = clampf(position.x + move_dir * move_speed * chase_speed_multiplier * delta, min_x, max_x)

func _ai_bat(delta: float, target: Node2D) -> void:
	var min_x: float = start_pos.x - patrol_range
	var max_x: float = start_pos.x + patrol_range

	match ai_state:
		AIState.PATROL:
			_patrol_horizontal(delta, 1.0)
			position.y = start_pos.y + sin(ai_timer * hover_frequency) * hover_amplitude
			if target != null and lunge_cooldown <= 0.0 and global_position.distance_to(target.global_position) <= detection_radius:
				ai_state = AIState.ALERT
				state_timer = 0.22
				var rel: Vector2 = target.global_position - global_position
				swoop_target = Vector2(
					clampf(position.x + rel.x, start_pos.x - patrol_range * 1.4, start_pos.x + patrol_range * 1.4),
					clampf(position.y + rel.y, start_pos.y - 72.0, start_pos.y + 72.0)
				)
		AIState.ALERT:
			position.y = move_toward(position.y, start_pos.y - 12.0, move_speed * 0.8 * delta)
			if target != null:
				var dx_alert: float = target.global_position.x - global_position.x
				if abs(dx_alert) > 2.0:
					move_dir = sign(dx_alert)
			state_timer -= delta
			if state_timer <= 0.0:
				ai_state = AIState.CHASE
				state_timer = 1.4
		AIState.CHASE:
			if target != null:
				var rel_chase: Vector2 = target.global_position - global_position
				var desired := Vector2(
					clampf(position.x + rel_chase.x, start_pos.x - patrol_range * 1.4, start_pos.x + patrol_range * 1.4),
					clampf(position.y + rel_chase.y, start_pos.y - 72.0, start_pos.y + 72.0)
				)
				swoop_target = swoop_target.lerp(desired, min(1.0, delta * 4.0))
			var to_target: Vector2 = swoop_target - position
			if abs(to_target.x) > 2.0:
				move_dir = sign(to_target.x)
			position = position.move_toward(swoop_target, move_speed * 1.9 * delta)
			state_timer -= delta
			if state_timer <= 0.0 or position.distance_to(swoop_target) <= 6.0:
				ai_state = AIState.RETURN
				lunge_cooldown = 1.1
		AIState.RETURN:
			var home := Vector2(clampf(position.x, min_x, max_x), start_pos.y)
			var to_home: Vector2 = home - position
			if abs(to_home.x) > 2.0:
				move_dir = sign(to_home.x)
			position = position.move_toward(home, move_speed * 1.35 * delta)
			if position.distance_to(home) <= 3.0:
				ai_state = AIState.PATROL

func _ai_spider(delta: float, target: Node2D) -> void:
	var min_x: float = start_pos.x - patrol_range
	var max_x: float = start_pos.x + patrol_range

	match ai_state:
		AIState.PATROL:
			_patrol_horizontal(delta, 1.25)
			if target != null and lunge_cooldown <= 0.0 and patrol_range > 0.0:
				var dx: float = target.global_position.x - global_position.x
				var dy: float = abs(target.global_position.y - global_position.y)
				if abs(dx) <= detection_radius and dy <= 56.0:
					ai_state = AIState.ALERT
					state_timer = 0.18
					if abs(dx) > 2.0:
						move_dir = sign(dx)
		AIState.ALERT:
			if target != null:
				var dx_alert: float = target.global_position.x - global_position.x
				if abs(dx_alert) > 2.0:
					move_dir = sign(dx_alert)
			state_timer -= delta
			if state_timer <= 0.0:
				ai_state = AIState.CHASE
				state_timer = 0.75
		AIState.CHASE:
			position.x = clampf(position.x + move_dir * move_speed * 2.15 * delta, min_x, max_x)
			state_timer -= delta
			var hit_edge: bool = (position.x <= min_x and move_dir < 0.0) or (position.x >= max_x and move_dir > 0.0)
			if state_timer <= 0.0 or hit_edge:
				ai_state = AIState.PATROL
				lunge_cooldown = 0.85
		AIState.RETURN:
			ai_state = AIState.PATROL

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
	if is_instance_valid(Events):
		Events.enemy_defeated.emit()

	# Odbicie gracza w górę po nadeptaniu na wroga
	if killer is CharacterBody2D:
		killer.velocity.y = bounce_velocity
		if "can_double_jump" in killer:
			killer.can_double_jump = true

	queue_free()
