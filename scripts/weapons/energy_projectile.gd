extends Node3D
class_name EnergyProjectile

## Leuchtendes Energie-Projektil (Plasma-Bolzen, Shock-Kugel).
## Fliegt geradeaus, prueft per Raycast-Sweep auf Treffer (kein Durchtunneln),
## macht Direktschaden plus kleinen Flaechenschaden und hinterlaesst einen farbigen Einschlag.
## Shock-Kugeln (is_shock_ball) koennen vom Shock-Strahl zur Combo gezuendet werden.

const IMPACT_SCENE: PackedScene = preload("res://scenes/effects/energy_impact.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/weapons/explosion.tscn")

@export var speed: float = 40.0
@export var direct_damage: float = 20.0
@export var splash_damage: float = 15.0
@export var splash_radius: float = 1.5
@export var lifetime: float = 4.0
@export var color: Color = Color(0.3, 0.8, 1.0)
## Shock-Kugel: kann vom Shock-Strahl zur Combo-Explosion gezuendet werden
@export var is_shock_ball: bool = false
@export var combo_damage: float = 150.0
@export var combo_radius: float = 7.0

var shooter: Node = null
@export var weapon_name: String = "Plasma"
var _shooter_rid: RID
var _age: float = 0.0
var _done: bool = false


func _ready() -> void:
	if shooter is CollisionObject3D:
		_shooter_rid = (shooter as CollisionObject3D).get_rid()
	if is_shock_ball:
		add_to_group("shock_balls")


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age >= lifetime:
		_impact(global_position, Vector3.UP, null)
		return

	var next_pos: Vector3 = global_position - global_transform.basis.z * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, Layers.HITTABLE)
	if _shooter_rid.is_valid():
		query.exclude = [_shooter_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_impact(hit.position + hit.normal * 0.05, hit.normal, hit.collider)
	else:
		global_position = next_pos


## Einschlag: Direktschaden, Flaechenschaden, Effekt, entfernen
func _impact(pos: Vector3, normal: Vector3, direct_target: Object) -> void:
	_done = true
	var dir: Vector3 = -global_transform.basis.z
	if direct_target and direct_target != shooter and direct_target.has_method("take_damage"):
		direct_target.take_damage(DamageInfo.create(direct_damage, shooter, pos, dir * 0.3, weapon_name))
		if is_instance_valid(shooter) and shooter.has_method("on_enemy_hit"):
			shooter.on_enemy_hit()
	_splash(pos, direct_target)

	var impact := IMPACT_SCENE.instantiate()
	get_parent().add_child(impact)
	impact.global_position = pos
	impact.setup(color, normal, 1.6 if is_shock_ball else 1.0)
	queue_free()


## Kleiner Flaechenschaden um den Einschlag (ohne den direkt Getroffenen), nicht durch Waende
func _splash(pos: Vector3, skip: Object) -> void:
	if splash_damage <= 0.0 or splash_radius <= 0.0:
		return
	var space := get_world_3d().direct_space_state
	for body in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if body == skip or not body.has_method("take_damage"):
			continue
		var center: Vector3 = body.global_position + Vector3(0, 0.9, 0)
		var dist: float = pos.distance_to(center)
		if dist > splash_radius:
			continue
		var los := PhysicsRayQueryParameters3D.create(pos, center, Layers.WORLD)
		if not space.intersect_ray(los).is_empty():
			continue
		var amount: float = splash_damage * (1.0 - dist / splash_radius)
		if body == shooter:
			amount *= 0.5
		body.take_damage(DamageInfo.create(amount, shooter, pos, Vector3.ZERO, weapon_name, true))


## Shock-Combo: Kugel explodiert gross (vom Shock-Strahl ausgeloest). Der Ausloeser bekommt den Frag.
func detonate_combo(by: Node) -> void:
	if _done:
		return
	_done = true
	var explosion := EXPLOSION_SCENE.instantiate()
	explosion.shooter_node = by
	explosion.weapon_name = "Shock-Combo"
	explosion.max_damage = combo_damage
	explosion.blast_radius = combo_radius
	explosion.tint = color
	explosion.position = global_position
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	var audio := AudioStreamPlayer3D.new()
	audio.stream = SoundGenerator.create_combo_sound()
	audio.max_distance = 80.0
	audio.unit_size = 10.0
	explosion.add_child(audio)
	audio.play()
	queue_free()
