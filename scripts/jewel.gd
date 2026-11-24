extends Area2D

enum JewelType {
	NORMAL,
	JEW_JEWEL,        ## Nieśmiertelność na 10s (brak otrzymywania obrażeń)
	SPEED_JEWEL,      ## Boost przyspieszania postaci na 10s
	IMMUNITY_JEWEL    ## Tarcza chroniąca przed 1 uderzeniem (brak obrażeń na 1 hit)
}

@export var jewel_type: JewelType = JewelType.NORMAL
@export var powerup_duration: float = 10.0
@export var pointVal: int = 100
@export var bobSpeed: float = 4.0
@export var bobHeight: float = 3.0

## Czy klejnot jest „Niestabilny / Przeklęty” (Kontrakt AI: Cursed Jewels) - po zebraniu blokuje wskazaną mechanikę.
@export var is_cursed: bool = false
@export var cursed_mechanic: String = ""
@export var curse_duration: float = 4.0
@export var magnet_radius: float = 95.0
@export var magnet_speed: float = 210.0

## Czy klejnot jest sekretnym specjalnym klejnotem kolekcji (S23KC2S1P1-284 / S23KC2S1P1-87)
@export var is_secret_special: bool = false
@export var special_id: String = ""
@export var special_name: String = "Klejnot Eteru"
@export var special_rarity: String = "Legendarny"
@export var special_point_val: int = 500
var is_already_owned_special: bool = false

@onready var spriteNode: Sprite2D = get_node_or_null("Sprite2D")
var startY: float = 0.0
var timePassed: float = 0.0

func _ready() -> void:
	add_to_group("jewels")
	if spriteNode:
		startY = spriteNode.position.y
	_setup_jewel_texture()
	_apply_cursed_visuals()
	_apply_special_collectible_visuals()
	if not body_entered.is_connected(_onBodyEntered):
		body_entered.connect(_onBodyEntered)

func configure_secret_jewel(id: String, j_name: String = "Klejnot Eteru", rarity: String = "Legendarny") -> void:
	is_secret_special = true
	special_id = id
	special_name = j_name
	special_rarity = rarity
	_apply_special_collectible_visuals()

func _apply_special_collectible_visuals() -> void:
	if not is_secret_special or special_id.is_empty():
		return
	is_already_owned_special = Events.is_special_jewel_owned(special_id) if is_instance_valid(Events) else false
	var r_tag: Label = get_node_or_null("RarityTag") as Label
	if is_already_owned_special:
		modulate.a = 0.45
		if spriteNode:
			spriteNode.modulate = Color(0.85, 0.85, 0.9, 0.45)
		if r_tag:
			r_tag.visible = false
	else:
		modulate.a = 1.0
		if spriteNode:
			spriteNode.modulate = Color(1.0, 0.85, 0.25, 1.0)
		if not r_tag:
			r_tag = Label.new()
			r_tag.name = "RarityTag"
			r_tag.position = Vector2(-36, -24)
			r_tag.size = Vector2(72, 14)
			r_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_tag.add_theme_font_size_override("font_size", 8)
			r_tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
			add_child(r_tag)
		r_tag.text = "[%s]" % special_rarity
		r_tag.visible = true

func set_jewel_type(type: JewelType) -> void:
	jewel_type = type
	_setup_jewel_texture()

func _setup_jewel_texture() -> void:
	if not spriteNode:
		return
	match jewel_type:
		JewelType.JEW_JEWEL:
			if ResourceLoader.exists("res://assets/JewJewel.png"):
				spriteNode.texture = load("res://assets/JewJewel.png")
		JewelType.SPEED_JEWEL:
			if ResourceLoader.exists("res://assets/SpeedJewel.png"):
				spriteNode.texture = load("res://assets/SpeedJewel.png")
		JewelType.IMMUNITY_JEWEL:
			if ResourceLoader.exists("res://assets/ImmunityJewel.png"):
				spriteNode.texture = load("res://assets/ImmunityJewel.png")
		_:
			if spriteNode.texture == null and ResourceLoader.exists("res://assets/Jewel.png"):
				spriteNode.texture = load("res://assets/Jewel.png")

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
					if DisplayServer.get_name() != "headless" and not bool(p2d.get_meta("portal_magnet_reported", false)):
						if is_instance_valid(Events) and is_instance_valid(Events.portal_sync) and Events.portal_sync.is_linked:
							p2d.set_meta("portal_magnet_reported", true)
							Events.portal_sync.report_booster_used("magnes", Events.session_id + "-magnet")
					global_position = global_position.move_toward(p2d.global_position, magnet_speed * delta)

func _onBodyEntered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_secret_special and not special_id.is_empty():
			var was_owned: bool = is_already_owned_special or (is_instance_valid(Events) and Events.is_special_jewel_owned(special_id))
			if was_owned:
				Events.jewel_collected.emit(pointVal, global_position)
				if is_instance_valid(Events):
					Events.special_jewel_collected.emit(special_id, special_name, special_rarity, true)
			else:
				if is_instance_valid(Events):
					Events.register_special_jewel(special_id, special_name, special_rarity)
				Events.jewel_collected.emit(special_point_val, global_position)
				if is_instance_valid(Events):
					Events.special_jewel_collected.emit(special_id, special_name, special_rarity, false)
			queue_free()
			return

		# Aktywacja mechanik specjalnych klejnotów (power-upów)
		match jewel_type:
			JewelType.JEW_JEWEL:
				if body.has_method("apply_invincibility"):
					body.apply_invincibility(powerup_duration)
			JewelType.SPEED_JEWEL:
				if body.has_method("apply_speed_boost"):
					body.apply_speed_boost(powerup_duration)
			JewelType.IMMUNITY_JEWEL:
				if body.has_method("apply_shield"):
					body.apply_shield()
					
		if is_cursed and not cursed_mechanic.is_empty():
			if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
				Events.ai_director.apply_cursed_jewel_lock(cursed_mechanic, curse_duration)
			if is_instance_valid(Events):
				Events.cursed_jewel_triggered.emit(cursed_mechanic, curse_duration)
		Events.jewel_collected.emit(pointVal, global_position)
		queue_free()
