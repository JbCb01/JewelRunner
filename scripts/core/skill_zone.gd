extends Area2D
class_name SkillZone

## Niewidoczny czujnik obszaru wyzwania (np. "dash", "slide", "route:high").
## Zgłasza wejście/wyjście gracza do PlayStyleProfiler, który na tej podstawie liczy,
## które mechaniki sprawiają graczowi kłopot i jakie trasy wybiera na rozwidleniach.

@export var tag: String = ""
@export var module_uid: String = ""

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _profiler() -> Node:
	if is_instance_valid(Events) and "playstyle_profiler" in Events:
		return Events.playstyle_profiler
	return null

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var p := _profiler()
	if p and p.has_method("zone_entered"):
		p.zone_entered(tag, module_uid)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var p := _profiler()
	if p and p.has_method("zone_exited"):
		p.zone_exited(tag, module_uid)
