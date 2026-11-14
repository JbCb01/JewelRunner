extends Area2D

@export var pointVal: int = 100
@export var bobSpeed: float = 4.0
@export var bobHeight: float = 3.0

## Czy klejnot jest „Niestabilny / Przeklęty” (Kontrakt AI: Cursed Jewels) - po zebraniu blokuje wskazaną mechanikę.
@export var is_cursed: bool = false
@export var cursed_mechanic: String = ""
@export var curse_duration: float = 4.0
@export var magnet_radius: float = 95.0
@export var magnet_speed: float = 210.0

@onready var spriteNode: Sprite2D = get_node_or_null("Sprite2D")
var startY: float = 0.0
var timePassed: float = 0.0

func _ready() -> void:
	add_to_group("jewels")
	if spriteNode:
		startY = spriteNode.position.y
	_apply_cursed_visuals()
	if not body_entered.is_connected(_onBodyEntered):
		body_entered.connect(_onBodyEntered)

func set_cursed(mechanic_name: String, duration: float = 4.0) -> void:
	is_cursed = not mechanic_name.is_empty()
	cursed_mechanic = mechanic_name
	curse_duration = duration
	_apply_cursed_visuals()

func _apply_cursed_visuals() -> void:
	if spriteNode:
		if is_cursed:
			spriteNode.modulate = Color(1.0, 0.35, 0.75, 1.0)
		else:
			spriteNode.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tag: Label = get_node_or_null("CurseTag") as Label
	if is_cursed and not cursed_mechanic.is_empty():
		if not tag:
			tag = Label.new()
			tag.name = "CurseTag"
			tag.position = Vector2(-24, -22)
			tag.size = Vector2(48, 14)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.add_theme_font_size_override("font_size", 8)
			tag.add_theme_color_override("font_color", Color(1.0, 0.45, 0.85, 1.0))
			add_child(tag)
		var short_name: String = "DJ" if cursed_mechanic == "double_jump" else ("CLIMB" if cursed_mechanic == "wall_climb" else "DASH")
		tag.text = "!-%s" % short_name
		tag.visible = true
	elif tag:
		tag.visible = false

func _process(delta: float) -> void:
	timePassed += delta * bobSpeed
	if spriteNode:
		spriteNode.position.y = startY + sin(timePassed) * bobHeight
		
	# Obsługa wzmocnienia "magnes" pobranego z profilu gracza na stronie internetowej
	if is_inside_tree():
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		for p in players:
			if p is Node2D and p.get_meta("has_portal_magnet", false):
				var p2d := p as Node2D
				var dist: float = global_position.distance_to(p2d.global_position)
				if dist > 1.0 and dist <= magnet_radius:
					global_position = global_position.move_toward(p2d.global_position, magnet_speed * delta)

func _onBodyEntered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_cursed and not cursed_mechanic.is_empty():
			if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
				Events.ai_director.apply_cursed_jewel_lock(cursed_mechanic, curse_duration)
			if is_instance_valid(Events):
				Events.cursed_jewel_triggered.emit(cursed_mechanic, curse_duration)
		Events.jewel_collected.emit(pointVal, global_position)
		queue_free()
