extends WeaponBase

## Plasma-Gewehr: schnelle Folge leuchtender Energie-Bolzen mit kleinem Flaechenschaden.
## Stark auf mittlere Distanz und gegen Gegner hinter Kanten (Splash).

const BOLT_SCENE: PackedScene = preload("res://scenes/weapons/plasma_bolt.tscn")


func _ready() -> void:
	super._ready()
	audio_player.stream = SoundGenerator.create_plasma_sound()


func _on_fire(shooter: Node3D, camera: Camera3D) -> void:
	audio_player.pitch_scale = randf_range(0.92, 1.08)
	audio_player.play()
	var bolt := BOLT_SCENE.instantiate() as EnergyProjectile
	bolt.shooter = shooter
	bolt.weapon_name = weapon_name
	shooter.get_parent().add_child(bolt)
	bolt.global_position = muzzle.global_position
	aim_projectile(bolt, camera, shooter)


## Projektil auf den Punkt unter dem Fadenkreuz ausrichten (nicht parallel zur Kamera,
## sonst fliegt es wegen der seitlich sitzenden Muendung am Ziel vorbei)
static func aim_projectile(projectile: Node3D, camera: Camera3D, shooter: Node3D) -> void:
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var target: Vector3 = from + forward * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, target, Layers.HITTABLE)
	query.exclude = [shooter.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		target = hit.position
	var dir: Vector3 = (target - projectile.global_position).normalized()
	projectile.look_at(projectile.global_position + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
