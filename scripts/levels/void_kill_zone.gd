extends Area3D
class_name VoidKillZone

## Tötet alle Wesen (Spieler, Bots), die in den Weltraum-Abgrund stürzen,
## und entfernt lose herabfallende Physik-Props.

func _ready() -> void:
	# Layer 2 (Spieler), 3 (Bots), 5 (Props) überwachen
	collision_layer = 0
	collision_mask = Layers.BLASTABLE
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	if body.has_method("take_damage"):
		var info := DamageInfo.create(9999.0, null, body.global_position, Vector3.DOWN, "Abgrund")
		body.take_damage(info)
	elif body is RigidBody3D:
		body.queue_free()
