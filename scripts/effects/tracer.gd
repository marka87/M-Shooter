extends MeshInstance3D
class_name Tracer

## Leuchtspur eines Hitscan-Schusses von der Muendung zum Treffpunkt.
## Ein duenner, leuchtender Balken, der sehr schnell duenner wird und verschwindet.

const TRACER_SCENE: PackedScene = preload("res://scenes/effects/tracer.tscn")

@export var duration: float = 0.09


## Erzeugt eine Leuchtspur in der Welt (parent = Knoten, unter den sie gehaengt wird)
static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color, width: float = 0.03) -> void:
	var length: float = from.distance_to(to)
	if length < 0.3:
		return
	var tracer: Tracer = TRACER_SCENE.instantiate()
	parent.add_child(tracer)
	tracer.setup(from, to, color, width)


func setup(from: Vector3, to: Vector3, color: Color, width: float) -> void:
	var length: float = from.distance_to(to)
	global_position = from.lerp(to, 0.5)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.FORWARD
	look_at(to, up)
	scale = Vector3(width, width, length)

	var mat := (mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	material_override = mat

	var tween := create_tween()
	tween.tween_property(self, "scale:x", 0.0, duration)
	tween.parallel().tween_property(self, "scale:y", 0.0, duration)
	tween.tween_callback(queue_free)
