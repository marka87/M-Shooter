extends MeshInstance3D
class_name Tracer

## Leuchtspur eines Hitscan-Schusses von der Muendung zum Treffpunkt.
## Ein duenner, leuchtender Balken, der sehr schnell duenner wird und verschwindet.
## Abgelaufene Spuren werden versteckt und beim naechsten Schuss wiederverwendet (Pool).

const TRACER_SCENE: PackedScene = preload("res://scenes/effects/tracer.tscn")

@export var duration: float = 0.09

## Versteckte Spuren, bereit zur Wiederverwendung
static var _free: Array[Tracer] = []

var _mat: StandardMaterial3D


## Erzeugt eine Leuchtspur in der Welt (parent = Knoten, unter den sie gehaengt wird)
static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color, width: float = 0.03, life: float = 0.09) -> void:
	var length: float = from.distance_to(to)
	if length < 0.3:
		return
	var tracer: Tracer = null
	while tracer == null and not _free.is_empty():
		# Untypisiert holen: nach einem Mapwechsel liegen freigegebene Spuren im Pool (typisiert waere das ein Fehler)
		var candidate = _free.pop_back()
		if is_instance_valid(candidate):
			tracer = candidate
	if tracer:
		if tracer.get_parent() != parent:
			tracer.reparent(parent, false)
		tracer.show()
	else:
		tracer = TRACER_SCENE.instantiate()
		parent.add_child(tracer)
	tracer.duration = life
	tracer.setup(from, to, color, width)


func setup(from: Vector3, to: Vector3, color: Color, width: float) -> void:
	var length: float = from.distance_to(to)
	# Wiederverwendete Spuren haben am Ende Breite 0; look_at braucht eine gueltige Basis
	scale = Vector3.ONE
	global_position = from.lerp(to, 0.5)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.FORWARD
	look_at(to, up)
	scale = Vector3(width, width, length)

	if _mat == null:
		_mat = (mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		material_override = _mat
	_mat.albedo_color = color
	_mat.emission = color

	var tween := create_tween()
	tween.tween_property(self, "scale:x", 0.0, duration)
	tween.parallel().tween_property(self, "scale:y", 0.0, duration)
	tween.tween_callback(_release)


func _release() -> void:
	hide()
	_free.append(self)
