extends Area2D

@export var pointVal: int = 100
@export var bobSpeed: float = 4.0
@export var bobHeight: float = 3.0

@onready var spriteNode: Sprite2D = $Sprite2D
var startY: float = 0.0
var timePassed: float = 0.0

func _ready() -> void:
	startY = spriteNode.position.y
	body_entered.connect(_onBodyEntered)

func _process(delta: float) -> void:
	timePassed += delta * bobSpeed
	spriteNode.position.y = startY + sin(timePassed) * bobHeight

func _onBodyEntered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Events.jewel_collected.emit(pointVal, global_position)
		queue_free()
