extends RigidBody3D
class_name PhysicsBarrel

## Dynamisches Physik-Fass mit Jolt Physics.
## Reagiert auf Beschuss und Druckwellen mit physischem Impuls.
## Rote Faesser explodieren bei Zerstoerung und richten Umgebungsschaden an.

@export var max_health: float = 45.0
@export var is_explosive: bool = true
@export var explosion_damage: float = 85.0
@export var explosion_radius: float = 5.5

var current_health: float = 45.0
var _exploded: bool = false
var explosion_scene: PackedScene = preload("res://scenes/weapons/explosion.tscn")


func _ready() -> void:
	current_health = max_health
	collision_layer = Layers.PROPS
	collision_mask = Layers.WORLD | Layers.CHARACTERS | Layers.PROPS


func take_damage(damage_info: DamageInfo) -> void:
	if _exploded:
		return
	
	# Physischer Impuls durch das Projektil oder den Treffer
	if damage_info.direction.length_squared() > 0.001:
		var push := damage_info.direction.normalized() * clampf(damage_info.amount * 0.35, 2.0, 14.0)
		if damage_info.position.length_squared() > 0.001:
			apply_impulse(push, damage_info.position - global_position)
		else:
			apply_central_impulse(push)
	
	current_health -= damage_info.amount
	if current_health <= 0.0:
		_destroy(damage_info.attacker)


func _destroy(killer: Node) -> void:
	_exploded = true
	if is_explosive and explosion_scene:
		var expl := explosion_scene.instantiate() as Node3D
		expl.max_damage = explosion_damage
		expl.blast_radius = explosion_radius
		expl.shooter_node = killer
		expl.weapon_name = "Explosiv-Fass"
		expl.position = global_position + Vector3(0.0, 0.4, 0.0)
		get_parent().add_child(expl)
	queue_free()
