extends Node3D
class_name ScorchDecal

## Brandfleck-Decal fuer Explosionen (Raketenwerfer, Shock-Combos).
## Glueht anfangs noch heiss nach, kuehlt ab und verblasst nach einigen Sekunden.

@onready var decal: Decal = $Decal

const MAX_SCORCH_DECALS: int = 35
static var _active_decals: Array[Node3D] = []

var lifetime: float = 14.0


func _ready() -> void:
	_active_decals.append(self)
	while _active_decals.size() > MAX_SCORCH_DECALS:
		var oldest: Node3D = _active_decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	
	# Glut kuehlt ab
	var tween := create_tween()
	tween.tween_property(decal, "emission_energy", 0.0, 2.5).set_ease(Tween.EASE_OUT)
	tween.tween_interval(lifetime)
	tween.tween_property(decal, "modulate:a", 0.0, 1.5)
	tween.tween_callback(queue_free)


func setup_scorch(normal: Vector3, radius: float = 3.0, tint_color: Color = Color(1.0, 0.45, 0.1)) -> void:
	if normal.length_squared() > 0.001:
		look_at(global_position + normal, Vector3.UP if absf(normal.y) < 0.98 else Vector3.FORWARD)
	decal.size = Vector3(radius * 0.85, 0.5, radius * 0.85)
	if tint_color != Color(1.0, 0.45, 0.1) and tint_color.a > 0.0:
		decal.modulate = Color(tint_color.r * 0.4, tint_color.g * 0.4, tint_color.b * 0.4, 1.0)


func _exit_tree() -> void:
	_active_decals.erase(self)
