extends Node3D

## Kleiner Treffer-Funke an Waenden und Objekten
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: CPUParticles3D = $CPUParticles3D

var lifetime: float = 0.35


func _ready() -> void:
	if particles:
		particles.emitting = true
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, lifetime)
	tween.tween_callback(queue_free)
