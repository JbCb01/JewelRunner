extends Area2D
class_name CheckpointArea

## Punkt Kontrolny (Checkpoint) na poziomie z pełną animacją flagi (Checkpoint_sheet)
## Po wejściu gracza aktywuje animację wciągania flagi na maszt i zapisuje punkt odrodzenia.

@export var checkpoint_id: String = "CP-1"
var is_activated: bool = false

var anim_sprite: AnimatedSprite2D = null
static var _cached_sprite_frames: SpriteFrames = null

static func get_checkpoint_sprite_frames() -> SpriteFrames:
	if _cached_sprite_frames != null:
		return _cached_sprite_frames

	var tex: Texture2D = load("res://assets/Checkpoint_sheet.png") as Texture2D
	if not tex:
		return null

	var frames := SpriteFrames.new()
	const FRAME_W: int = 64
	const FRAME_H: int = 96

	# 1. Animacja "inactive" (flaga opuszczona na dole masztu, klatki 0..6)
	frames.add_animation("inactive")
	frames.set_animation_speed("inactive", 6.0)
	frames.set_animation_loop("inactive", true)
	for i in range(0, 7):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame("inactive", atlas)

	# 2. Animacja "activating" (wciąganie flagi na szczyt z błyskiem, klatki 7..17)
	frames.add_animation("activating")
	frames.set_animation_speed("activating", 12.0)
	frames.set_animation_loop("activating", false)
	for i in range(7, 18):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame("activating", atlas)

	# 3. Animacja "active" (łopocząca flaga na szczycie masztu, klatki 18..25)
	frames.add_animation("active")
	frames.set_animation_speed("active", 9.0)
	frames.set_animation_loop("active", true)
	for i in range(18, 26):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame("active", atlas)

	_cached_sprite_frames = frames
	return _cached_sprite_frames

func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 2 # Warstwa gracza

	_setup_collision()
	_setup_animated_sprite()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _setup_collision() -> void:
	var existing_col: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D:
			existing_col = child
			break

	if not existing_col:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(36, 64)
		col.position = Vector2(0, -8)
		col.shape = shape
		add_child(col)
	else:
		if existing_col.shape is RectangleShape2D:
			(existing_col.shape as RectangleShape2D).size = Vector2(36, 64)
			existing_col.position = Vector2(0, -8)

func _setup_animated_sprite() -> void:
	# Usuwamy ewentualne prymitywne ColorRecty z poprzednich wersji generatora
	for child in get_children():
		if child is ColorRect and child.name != "Glow":
			child.queue_free()

	anim_sprite = get_node_or_null("AnimatedFlag") as AnimatedSprite2D
	if not anim_sprite:
		var frames := get_checkpoint_sprite_frames()
		if frames:
			anim_sprite = AnimatedSprite2D.new()
			anim_sprite.name = "AnimatedFlag"
			anim_sprite.sprite_frames = frames
			anim_sprite.centered = false
			# Maszt znajduje się na X=15, a podstawa na Y=96.
			# Względem pozycji checkpointu (y=280) ziemia jest na y=24 (304 - 280).
			# Pozycja (-15, -72) stawia maszt w osi X=0 i podstawę dokładnie na ziemi (+24).
			anim_sprite.position = Vector2(-15, -72)
			anim_sprite.z_index = 2
			anim_sprite.animation_finished.connect(_on_animation_finished)
			add_child(anim_sprite)

	if anim_sprite:
		if is_activated:
			anim_sprite.play("active")
		else:
			anim_sprite.play("inactive")

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if is_activated:
		return

	is_activated = true
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(global_position, checkpoint_id)

	_trigger_activation_feedback()

	if is_instance_valid(Events):
		Events.checkpoint_reached.emit(checkpoint_id, global_position)

func _trigger_activation_feedback() -> void:
	if anim_sprite:
		anim_sprite.play("activating")

	# Odtwarzanie dźwięku aktywacji
	var sfx: AudioStream = load("res://audio/sfx/Pickup_poweup.ogg") as AudioStream
	if sfx:
		var sfx_player := AudioStreamPlayer2D.new()
		sfx_player.stream = sfx
		sfx_player.bus = "Master"
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)

	# Pływający napis checkpointu nad flagą
	_spawn_floating_label()

func _spawn_floating_label() -> void:
	var label := Label.new()
	label.text = "[★] CHECKPOINT!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.4, 1.0, 0.6, 1.0)
	label.position = Vector2(-60, -78)
	label.size = Vector2(120, 24)
	label.z_index = 10
	add_child(label)

	var tween: Tween = create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", -108.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(label.queue_free)

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation == "activating":
		anim_sprite.play("active")

func _update_visuals_activated() -> void:
	if anim_sprite:
		if anim_sprite.animation != "activating" and anim_sprite.animation != "active":
			anim_sprite.play("activating")
