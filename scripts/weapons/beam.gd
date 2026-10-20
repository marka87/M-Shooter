extends Node3D

## Leuchtender Railgun-Energiestrahl, der kurzzeitig im Raum stehen bleibt und verblasst

@export var duration: float = 0.45

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


## Richtet den Zylinder-Strahl exakt zwischen Start- und Endpunkt aus
func setup_beam(start_pos: Vector3, end_pos: Vector3) -> void:
	var diff: Vector3 = end_pos - start_pos
	var distance: float = diff.length()
	if distance < 0.05:
		queue_free()
		return
	
	# Position in der exakten Mitte
	global_position = start_pos + diff * 0.5
	
	# Ausrichten entlang des Verbindungsvektors
	var up_vector := Vector3.UP if abs(diff.normalized().y) < 0.98 else Vector3.FORWARD
	look_at(end_pos, up_vector)
	
	# Zylinder laengs zur Blickachse drehen und auf Laenge skalieren
	mesh_instance.rotation_degrees.x = 90.0
	mesh_instance.scale = Vector3(1.0, distance, 1.0)
	
	# Material duplizieren fuer weiches Ausblenden
	var mat := mesh_instance.get_active_material(0)
	if mat:
		var unique_mat: StandardMaterial3D = mat.duplicate()
		mesh_instance.set_surface_override_material(0, unique_mat)
		
		var tween := create_tween()
		tween.parallel().tween_property(unique_mat, "albedo_color:a", 0.0, duration)
		tween.parallel().tween_property(unique_mat, "emission_energy_multiplier", 0.0, duration)
		tween.parallel().tween_property(mesh_instance, "scale:x", 0.05, duration)
		tween.parallel().tween_property(mesh_instance, "scale:z", 0.05, duration)
		tween.tween_callback(queue_free)
	else:
		get_tree().create_timer(duration, false).timeout.connect(queue_free)
