extends WeaponBase

## Shock Rifle (wie in Unreal Tournament): Linksklick = sofortiger Energiestrahl,
## Rechtsklick = langsame Shock-Kugel. Trifft der Strahl eine Shock-Kugel, explodiert sie
## als grosse Combo (hoher Flaechenschaden, Frag fuer den Schuetzen).

const BALL_SCENE: PackedScene = preload("res://scenes/weapons/shock_ball.tscn")

@export var max_range: float = 300.0
## Wie nah der Strahl an einer Kugel vorbei muss, um sie zu zuenden (m)
@export var combo_hit_radius: float = 0.9


func _ready() -> void:
	super._ready()
	audio_player.stream = SoundGenerator.create_shock_beam_sound()


func _on_fire(shooter: Node3D, camera: Camera3D) -> void:
	audio_player.stream = SoundGenerator.create_shock_beam_sound()
	audio_player.pitch_scale = randf_range(0.97, 1.03)
	audio_player.play()

	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var to: Vector3 = from + forward * max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	query.exclude = [shooter.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else to

	# Combo: Liegt eine Shock-Kugel auf dem Strahl (vor dem Treffpunkt), wird sie gezuendet
	var ball := _ball_on_ray(from, end)
	if ball:
		Tracer.spawn(shooter.get_parent(), muzzle.global_position, ball.global_position, data.color, 0.07, 0.25)
		ball.detonate_combo(shooter)
		return

	Tracer.spawn(shooter.get_parent(), muzzle.global_position, end, data.color, 0.07, 0.25)
	Tracer.spawn(shooter.get_parent(), muzzle.global_position, end, Color(1, 1, 1), 0.02, 0.2)
	if hit:
		var collider: Object = hit.collider
		if collider and collider.has_method("take_damage"):
			var headshot := DamageInfo.is_head_hit(collider, end)
			var info := DamageInfo.create(damage * (DamageInfo.HEADSHOT_MULTIPLIER if headshot else 1.0), shooter, end, forward, weapon_name)
			info.is_headshot = headshot
			collider.take_damage(info)
			if shooter.has_method("on_enemy_hit"):
				shooter.on_enemy_hit(headshot)
		HitSpark.spawn(shooter.get_parent(), end, hit.normal)


func _on_fire_alt(shooter: Node3D, camera: Camera3D) -> void:
	audio_player.stream = SoundGenerator.create_shock_ball_sound()
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()
	var ball := BALL_SCENE.instantiate() as EnergyProjectile
	ball.shooter = shooter
	shooter.get_parent().add_child(ball)
	ball.global_position = muzzle.global_position
	# Kugel fliegt genau in Blickrichtung, damit man sie mit dem Strahl leicht nachzielen kann
	var forward: Vector3 = -camera.global_transform.basis.z
	ball.look_at(ball.global_position + forward, Vector3.UP if absf(forward.y) < 0.98 else Vector3.FORWARD)
	ball.reset_physics_interpolation()


## Naechste Shock-Kugel nahe der Strecke from -> to (die erste vom Schuetzen aus gesehen)
func _ball_on_ray(from: Vector3, to: Vector3) -> EnergyProjectile:
	var best: EnergyProjectile = null
	var best_t: float = INF
	var seg: Vector3 = to - from
	var seg_len_sq: float = seg.length_squared()
	if seg_len_sq < 0.0001:
		return null
	for node in get_tree().get_nodes_in_group("shock_balls"):
		var ball := node as EnergyProjectile
		if ball == null or ball._done:
			continue
		var t: float = clampf((ball.global_position - from).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest: Vector3 = from + seg * t
		if closest.distance_to(ball.global_position) <= combo_hit_radius and t < best_t:
			best = ball
			best_t = t
	return best
