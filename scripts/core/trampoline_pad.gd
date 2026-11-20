extends Area2D
class_name TrampolinePad

## Trampolina (blok `!` z tilesetu) wybijająca gracza w górę.
## Odświeża zdolność podwójnego skoku i dasha w powietrzu.

const TILESET_TEXTURE_PATH := "res://assets/tilesett.png"

@export var bounce_velocity: float = -470.0
@export var cooldown_time: float = 0.12
@export var tile_coords: Vector2i = Vector2i(1, 2)

var cooldown_timer: float = 0.0
var sprite: Sprite2D = null
var anim_tween: Tween = null

func _ready() -> void:
	add_to_group("trampolines")
	collision_layer = 0
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_ensure_nodes()
	_refresh_sprite_region()

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = max(0.0, cooldown_timer - delta)

func configure(p_tile_coords: Vector2i, p_bounce_velocity: float = -470.0) -> void:
	tile_coords = p_tile_coords
	bounce_velocity = p_bounce_velocity
	_refresh_sprite_region()

func _ensure_nodes() -> void:
	if not get_node_or_null("TriggerShape"):
		var trigger_col := CollisionShape2D.new()
		trigger_col.name = "TriggerShape"
		trigger_col.position = Vector2(0, -4)
		var trigger_shape := RectangleShape2D.new()
		trigger_shape.size = Vector2(18, 12)
		trigger_col.shape = trigger_shape
		add_child(trigger_col)

	if not get_node_or_null("SolidBase"):
		var base := StaticBody2D.new()
		base.name = "SolidBase"
		base.collision_layer = 1
		base.collision_mask = 0
		var base_col := CollisionShape2D.new()
		base_col.name = "CollisionShape2D"
		var base_shape := RectangleShape2D.new()
		base_shape.size = Vector2(16, 16)
		base_col.shape = base_shape
		base.add_child(base_col)
		add_child(base)

	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

func _refresh_sprite_region() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	if ResourceLoader.exists(TILESET_TEXTURE_PATH):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(TILESET_TEXTURE_PATH)
		atlas.region = Rect2(tile_coords.x * 16, tile_coords.y * 16, 16, 16)
		sprite.texture = atlas

func _on_body_entered(body: Node2D) -> void:
	if cooldown_timer > 0.0 or not body or not body.is_in_group("player"):
		return
	cooldown_timer = cooldown_time

	if body.has_method("apply_trampoline_bounce"):
		body.apply_trampoline_bounce(bounce_velocity)
	elif body is CharacterBody2D:
		body.velocity.y = bounce_velocity
		if "can_double_jump" in body:
			body.can_double_jump = true
		if "can_air_dash" in body:
			body.can_air_dash = true

	_play_bounce_animation()

func _play_bounce_animation() -> void:
	if not is_inside_tree() or sprite == null:
		return
	if anim_tween != null and anim_tween.is_valid():
		anim_tween.kill()
	sprite.scale = Vector2(1.28, 0.72)
	sprite.position.y = 2.0
	anim_tween = create_tween()
	anim_tween.set_parallel(true)
	anim_tween.tween_property(sprite, "scale", Vector2(0.88, 1.22), 0.09)
	anim_tween.tween_property(sprite, "position:y", -3.0, 0.09)
	anim_tween.chain().set_parallel(true)
	anim_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.14)
	anim_tween.tween_property(sprite, "position:y", 0.0, 0.14)
