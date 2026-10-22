extends RigidBody3D
class_name PhysicsCrate

## Dynamische Metallkiste mit Jolt Physics.
## Kann durch Schuesse, Raketen und Explosionen im Raum herumgeschleudert werden und
## zerplatzt nach genug Schaden in leuchtende Wuerfel.

@export var max_health: float = 60.0
var current_health: float = 60.0
var _destroyed: bool = false


func _ready() -> void:
	current_health = max_health
	collision_layer = Layers.PROPS
	collision_mask = Layers.WORLD | Layers.CHARACTERS | Layers.PROPS
	BulletHole.mark_dynamic(self)


func take_damage(damage_info: DamageInfo) -> void:
	if damage_info.direction.length_squared() > 0.001:
		var push := damage_info.direction.normalized() * clampf(damage_info.amount * 0.45, 3.0, 18.0)
		if damage_info.position.length_squared() > 0.001:
			apply_impulse(push, damage_info.position - global_position)
		else:
			apply_central_impulse(push)
	
	# Im Netzspiel meldet der Host, wann die Kiste zerbricht
	if Net.is_client():
		return
	current_health -= damage_info.amount
	if current_health <= 0.0:
		destroy()


func destroy(_push: Vector3 = Vector3.ZERO) -> void:
	if _destroyed:
		return
	_destroyed = true
	Net.on_prop_destroyed(self)
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	var color: Color = mesh.mesh.material.emission if mesh and mesh.mesh.material else Color(0.2, 0.6, 0.8)
	PropFx.burst(self, color)
	PropFx.play_sound(self, SoundGenerator.create_crate_break_sound())
	queue_free()
