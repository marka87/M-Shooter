extends Area3D
class_name DamageZone

## Schadens-Zone (Energie-Schlamm, Lava): wer drinsteht, verliert alle 0,5 s Leben.
## In Schueben statt jedes Frame, damit Schadenszahlen und Trefferton nicht im Takt rattern.

@export var damage_per_second: float = 20.0
const TICK: float = 0.5

var _timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.CHARACTERS


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(DamageInfo.create(damage_per_second * TICK, null, body.global_position, Vector3.ZERO, "Schlamm"))
