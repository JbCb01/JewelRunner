extends Node2D

## Granice kamery dla ręcznie zaprojektowanego poziomu (Level 1).
## Węzeł leży w "Geometry", więc poziomy generowane proceduralnie go usuwają i nie dziedziczą tych granic.
## limit_top jest wyżej niż widok z ziemi, dlatego "podniebna" ścieżka nad ekranem jest niewidoczna z dołu.

@export var limit_left: int = 0
@export var limit_top: int = -208
@export var limit_right: int = 3392
@export var limit_bottom: int = 352

func _ready() -> void:
	_apply.call_deferred()

func _apply() -> void:
	# Generator innych profili usuwa ten węzeł w _ready areny – wtedy nic nie zmieniamy.
	if not is_inside_tree():
		return
	var arena: Node = get_parent().get_parent() if get_parent() else null
	if not arena:
		return
	var cam: Camera2D = arena.get_node_or_null("Player/Camera2D") as Camera2D
	if not cam:
		return
	cam.limit_left = limit_left
	cam.limit_top = limit_top
	cam.limit_right = limit_right
	cam.limit_bottom = limit_bottom
	cam.reset_smoothing()
