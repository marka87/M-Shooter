extends Node3D

## Treffer-Funke mit Einschussloch (Decal) an Waenden und Boeden.
## Der Funke verlischt schnell, der Rand glueht kurz nach, das Loch bleibt einige Sekunden.
## Damit Dauerfeuer nicht unbegrenzt Decals erzeugt, verschwindet bei zu vielen das aelteste.

@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: CPUParticles3D = $CPUParticles3D
@onready var decal: Decal = $Decal

var lifetime: float = 0.35
## Wie lange das Einschussloch sichtbar bleibt (s)
const DECAL_SECONDS: float = 6.0
const MAX_DECALS: int = 60

static var _active: Array[Node3D] = []


func _ready() -> void:
	if particles:
		particles.emitting = true
	_active.append(self)
	while _active.size() > MAX_DECALS:
		var oldest: Node3D = _active.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, lifetime)
	# Glut am Rand des Lochs kuehlt ab, das Loch selbst bleibt
	tween.parallel().tween_property(decal, "emission_energy", 0.0, 2.5).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DECAL_SECONDS)
	tween.tween_property(decal, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)


func _exit_tree() -> void:
	_active.erase(self)
