extends WeaponBase

## Raketenwerfer: Feuert sichtbare Projektile mit Explosions- und Rocket-Jump-Effekt

var rocket_scene: PackedScene = preload("res://scenes/weapons/rocket.tscn")


func _ready() -> void:
	super._ready()
	
	if audio_player:
		audio_player.stream = SoundGenerator.create_rocket_fire_sound()


func _on_fire(shooter: Node3D, camera: Camera3D) -> void:
	if audio_player:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()
	
	if not rocket_scene:
		return
	
	# Zielpunkt aus der Kamera-Mitte ermitteln, damit die Rakete exakt dorthin fliegt, wo das Fadenkreuz hinzeigt
	var space_state := camera.get_world_3d().direct_space_state
	var cam_pos: Vector3 = camera.global_position
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	var target_point: Vector3 = cam_pos + cam_forward * 100.0
	
	var query := PhysicsRayQueryParameters3D.create(cam_pos, target_point, Layers.HITTABLE)
	if shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit:
		target_point = hit.position
	
	# Rakete im Level instanziieren
	var rocket := rocket_scene.instantiate() as Node3D
	rocket.shooter = shooter
	rocket.weapon_name = weapon_name
	shooter.get_parent().add_child(rocket)
	
	var spawn_pos: Vector3 = muzzle.global_position if muzzle else cam_pos + cam_forward * 0.8
	rocket.global_position = spawn_pos
	
	# Rakete auf den Zielpunkt ausrichten
	var aim_dir: Vector3 = (target_point - spawn_pos).normalized()
	if aim_dir.length_squared() > 0.001:
		rocket.look_at(spawn_pos + aim_dir, Vector3.UP)
	rocket.reset_physics_interpolation()
