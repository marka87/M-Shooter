extends Node3D
class_name VoxelBurst

## Todes-Effekt: Die Figur zerplatzt in leuchtende Wuerfel in ihrer Farbe,
## die ueber den Boden springen und verglimmen. Entfernt sich danach selbst.

@onready var cubes: GPUParticles3D = $Cubes
@onready var flash: OmniLight3D = $Flash


## Farbe setzen und Effekt starten (nach add_child aufrufen)
func burst(color: Color) -> void:
	var mat: StandardMaterial3D = (cubes.draw_pass_1.surface_get_material(0) as StandardMaterial3D).duplicate()
	mat.albedo_color = color
	mat.emission = color
	cubes.material_override = mat
	flash.light_color = color
	cubes.restart()
	cubes.emitting = true

	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_interval(cubes.lifetime + 0.2)
	tween.tween_callback(queue_free)
