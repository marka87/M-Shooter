extends Node3D

## Sichtbares Raketen-Projektil mit hoher Geschwindigkeit und Kollisionserkennung

@export var speed: float = 38.0
@export var direct_damage: float = 50.0 # Direkter Trefferschaden zusaetzlich zur Explosion
@export var lifetime: float = 8.0

var shooter: Node = null
var weapon_name: String = "Raketenwerfer"
var shooter_rid: RID
var explosion_scene: PackedScene = preload("res://scenes/weapons/explosion.tscn")
var timer: float = 0.0


func _ready() -> void:
	if shooter and shooter is CollisionObject3D:
		shooter_rid = (shooter as CollisionObject3D).get_rid()


func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		_explode(global_position, null)
		return
	
	# Kontinuierlicher Raycast-Sweep verhindert das Durchtunneln von Waenden und Zielen
	var space_state := get_world_3d().direct_space_state
	var move_vector: Vector3 = -global_transform.basis.z * speed * delta
	var next_pos: Vector3 = global_position + move_vector
	
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos)
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
	query.collision_mask = Layers.HITTABLE
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result := space_state.intersect_ray(query)
	if result:
		# Etwas von der Oberflaeche abheben, damit der Sichtlinien-Test der Explosion nicht in der Wand startet
		_explode(result.position + result.normal * 0.1, result.collider)
	else:
		global_position = next_pos


func _explode(pos: Vector3, direct_target: Object = null) -> void:
	# Direkttreffer-Schaden zufuegen, falls eine Einheit direkt getroffen wurde
	if direct_target and direct_target.has_method("take_damage") and direct_target != shooter:
		direct_target.take_damage(DamageInfo.create(direct_damage, shooter, pos, -global_transform.basis.z, weapon_name))
		if shooter and shooter.has_method("on_enemy_hit"):
			shooter.on_enemy_hit()
	
	# Explosions-Flaechenschaden erzeugen
	if explosion_scene:
		var explosion := explosion_scene.instantiate() as Node3D
		explosion.shooter_node = shooter
		explosion.weapon_name = weapon_name
		# Position setzen, BEVOR der Knoten in den SceneTree eingefuegt wird!
		explosion.position = pos
		get_parent().add_child(explosion)
		explosion.global_position = pos
	
	queue_free()
