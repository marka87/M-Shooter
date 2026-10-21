extends WeaponBase

## Lightning Gun: Dauerstrahl auf kurze Distanz. Jeder "Schuss" ist ein Strahl-Tick (20 pro Sekunde),
## der sofort trifft. Der Strahl wird als zuckender Zickzack aus kurzen Leuchtspuren gezeichnet.

@export var max_range: float = 24.0
@export var beam_color: Color = Color(0.7, 0.9, 1.0)

var _tick: int = 0


func _ready() -> void:
	super._ready()
	audio_player.stream = SoundGenerator.create_lightning_sound()
	audio_player.volume_db = -9.0


func _on_fire(shooter: Node3D, camera: Node3D) -> void:
	_tick += 1
	if _tick % 2 == 0:
		audio_player.pitch_scale = randf_range(0.9, 1.15)
		audio_player.play()

	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var to: Vector3 = from + forward * max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	query.exclude = [shooter.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else to

	_draw_bolt(shooter.get_parent(), muzzle.global_position, end, camera)

	if hit:
		var collider: Object = hit.collider
		if collider and collider.has_method("take_damage"):
			collider.take_damage(DamageInfo.create(damage, shooter, end, forward * 0.2, weapon_name))
			if shooter.has_method("on_enemy_hit") and _tick % 3 == 0:
				shooter.on_enemy_hit()
		elif _tick % 3 == 0:
			HitSpark.spawn(shooter.get_parent(), end, hit.normal)


## Zickzack-Blitz: seitlich versetzte Knickpunkte plus duenne weisse Kernlinie.
## Jede Leuchtspur lebt nur kurz, bei Dauerfeuer entsteht ein zuckender Strahl.
func _draw_bolt(parent: Node, start: Vector3, end: Vector3, camera: Node3D) -> void:
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y
	var segments: int = clampi(int(start.distance_to(end) / 2.0), 3, 12)
	# Zwei unabhaengig zuckende Blitzstraenge: ein dicker, ein duenner
	for strand in 2:
		var prev: Vector3 = start
		var jitter: float = 0.3 if strand == 0 else 0.45
		var width: float = 0.07 if strand == 0 else 0.03
		for i in range(1, segments + 1):
			var t: float = float(i) / segments
			var point: Vector3 = start.lerp(end, t)
			if i < segments:
				point += (right * randf_range(-1, 1) + up * randf_range(-1, 1)) * jitter
			Tracer.spawn(parent, prev, point, beam_color, width, 0.07)
			prev = point
	Tracer.spawn(parent, start, end, Color(1, 1, 1), 0.02, 0.06)
