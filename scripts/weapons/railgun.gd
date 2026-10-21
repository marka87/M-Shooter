extends WeaponBase

## Railgun: Extrem praeziser Hitscan-Fernkampf mit sofortigem Schadensstrahl und langer Abklingzeit

@export var max_range: float = 300.0

var beam_scene: PackedScene = preload("res://scenes/weapons/beam.tscn")


func _ready() -> void:
	super._ready()
	
	if audio_player:
		audio_player.stream = SoundGenerator.create_railgun_sound()


func _on_fire(shooter: Node3D, camera: Node3D) -> void:
	if audio_player:
		audio_player.pitch_scale = randf_range(0.98, 1.02)
		audio_player.play()
	
	var space_state := camera.get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var to: Vector3 = from + forward * max_range
	var hit_pos: Vector3 = to
	
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	if shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var result := space_state.intersect_ray(query)
	if result:
		hit_pos = result.position
		var hit_normal: Vector3 = result.normal
		var collider: Object = result.collider
		
		# Funken am Treffpunkt
		HitSpark.spawn(shooter.get_parent(), hit_pos, hit_normal)
		
		# Hoher Schaden am Ziel
		if collider and collider.has_method("take_damage"):
			var headshot := DamageInfo.is_head_hit(collider, hit_pos)
			var amount: float = GameManager.INSTAGIB_DAMAGE if GameManager.instagib else damage
			if headshot:
				amount *= DamageInfo.HEADSHOT_MULTIPLIER
			var info := DamageInfo.create(amount, shooter, hit_pos, forward, weapon_name)
			info.is_headshot = headshot
			collider.take_damage(info)
			if shooter and shooter.has_method("on_enemy_hit"):
				shooter.on_enemy_hit(headshot)
	
	# Sichtbaren Railgun-Lichtstrahl zwischen Muendung und Treffpunkt erzeugen
	if beam_scene:
		var beam := beam_scene.instantiate() as Node3D
		shooter.get_parent().add_child(beam)
		var start_pos: Vector3 = muzzle.global_position if muzzle else from + forward * 0.5
		beam.setup_beam(start_pos, hit_pos)
