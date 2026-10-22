extends WeaponBase

## Shotgun: Feuert mehrere Schrotkugeln gleichzeitig (Hitscan mit Streuung).
## Stark auf kurze Distanz, schwach auf weite. Schaden pro Kugel steht in der WeaponData.

@export var pellet_count: int = 11
## Streuung als Anteil der Blickrichtung (0.06 entspricht ca. 3,4 Grad)
@export var spread: float = 0.06
@export var max_range: float = 120.0

@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var muzzle_mesh: MeshInstance3D = $Muzzle/MuzzleMesh


func _ready() -> void:
	super._ready()
	audio_player.stream = SoundGenerator.create_shotgun_sound()
	muzzle_flash.visible = false
	muzzle_mesh.visible = false


func _on_fire(shooter: Node3D, camera: Node3D) -> void:
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()
	_flash_muzzle()

	var space_state := camera.get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y

	# Schaden pro Ziel sammeln: ein Treffer mit Gesamtschaden statt 11 einzelner Schadenszahlen
	var damage_per_target: Dictionary = {}
	var hit_pos_per_target: Dictionary = {}

	for i in pellet_count:
		# Gleichmaessig in einer Scheibe verteilen (Wurzel sorgt fuer gleiche Dichte)
		var angle: float = randf() * TAU
		var radius: float = sqrt(randf()) * spread
		var offset: Vector3 = (right * cos(angle) + up * sin(angle)) * radius
		var to: Vector3 = from + (forward + offset).normalized() * max_range

		var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
		query.exclude = [shooter.get_rid()]
		var result := space_state.intersect_ray(query)
		Tracer.spawn(shooter.get_parent(), muzzle.global_position, result.position if result else to, Color(1.0, 0.55, 0.15), 0.018)
		if not result:
			continue

		var hit_pos: Vector3 = result.position
		var collider: Object = result.collider
		HitSpark.spawn(shooter.get_parent(), hit_pos, result.normal, 0.6)  # Schrot: viele kleine Loecher

		if collider and collider.has_method("take_damage"):
			damage_per_target[collider] = damage_per_target.get(collider, 0.0) + damage
			hit_pos_per_target[collider] = hit_pos

	for target in damage_per_target:
		if not is_instance_valid(target):
			continue
		target.take_damage(DamageInfo.create(damage_per_target[target], shooter, hit_pos_per_target[target], forward, weapon_name))
		if shooter.has_method("on_enemy_hit"):
			shooter.on_enemy_hit(false, target)


func _flash_muzzle() -> void:
	muzzle_flash.visible = true
	muzzle_mesh.visible = true
	get_tree().create_timer(0.06, false).timeout.connect(func():
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
		if is_instance_valid(muzzle_mesh):
			muzzle_mesh.visible = false
	)
