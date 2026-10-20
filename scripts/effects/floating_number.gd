extends Node3D
class_name FloatingNumber

## Schwebende 3D-Schadenszahl ueber getroffenen Einheiten
## Steigt nach oben, skaliert dynamisch und blendet sich sanft aus.

@onready var label: Label3D = $Label3D


func setup(amount: float, hit_position: Vector3) -> void:
	# Position mit kleiner Zufaelligkeit
	global_position = hit_position + Vector3(
		randf_range(-0.3, 0.3),
		randf_range(0.2, 0.5),
		randf_range(-0.3, 0.3)
	)
	
	if not label:
		label = $Label3D
	
	var damage_val := int(amount)
	label.text = "-%d" % damage_val
	
	# Farbgebung je nach Schadenshoehe
	if damage_val >= 90:
		# Railgun / Direkter Raketentreffer (Kritisch/Sehr hoch)
		label.modulate = Color(1.0, 0.2, 0.15)
		scale = Vector3.ONE * 1.5
	elif damage_val >= 40:
		# Mittlerer Schaden (Raketensplash)
		label.modulate = Color(1.0, 0.65, 0.1)
		scale = Vector3.ONE * 1.25
	else:
		# Maschinengewehr
		label.modulate = Color(1.0, 0.9, 0.2)
		scale = Vector3.ONE * 1.0
	
	# Aufsteig- und Ausblend-Animation per Tween
	var tween := create_tween()
	var target_y := global_position.y + 1.2
	tween.parallel().tween_property(self, "global_position:y", target_y, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.25)
	tween.tween_callback(queue_free)
