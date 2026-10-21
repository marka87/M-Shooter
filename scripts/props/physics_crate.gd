extends RigidBody3D
class_name PhysicsCrate

## Dynamische Metallkiste mit Jolt Physics.
## Kann durch Schuesse, Raketen und Explosionen im Raum herumgeschleudert werden.

@export var max_health: float = 60.0
var current_health: float = 60.0


func _ready() -> void:
	current_health = max_health
	collision_layer = Layers.PROPS
	collision_mask = Layers.WORLD | Layers.CHARACTERS | Layers.PROPS


func take_damage(damage_info: DamageInfo) -> void:
	if damage_info.direction.length_squared() > 0.001:
		var push := damage_info.direction.normalized() * clampf(damage_info.amount * 0.45, 3.0, 18.0)
		if damage_info.position.length_squared() > 0.001:
			apply_impulse(push, damage_info.position - global_position)
		else:
			apply_central_impulse(push)
	
	current_health -= damage_info.amount
	if current_health <= 0.0:
		queue_free()
