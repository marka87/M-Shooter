extends Node3D

## Farbiger Einschlag von Energie-Projektilen: kurzer Lichtblitz, Funken, kleine Leuchtscheibe.

@onready var light: OmniLight3D = $Light
@onready var sparks: CPUParticles3D = $Sparks
@onready var flash: MeshInstance3D = $Flash


func setup(color: Color, normal: Vector3, size: float = 1.0) -> void:
	light.light_color = color
	var mat := (flash.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	flash.material_override = mat
	sparks.material_override = mat
	if normal.length_squared() > 0.001:
		sparks.direction = normal
	scale = Vector3.ONE * size
	sparks.emitting = true

	var tween := create_tween()
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.25)
	tween.parallel().tween_property(flash, "scale", Vector3.ONE * 2.2, 0.18)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)
