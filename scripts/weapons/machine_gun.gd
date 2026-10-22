extends WeaponBase

## Maschinengewehr: Schnelle Hitscan-Waffe mit leichtem Rueckstoss und hoher Feuerrate

@export var max_range: float = 200.0
@export var spread_angle: float = 0.015 # Leichte Streuung

@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var muzzle_mesh: MeshInstance3D = $Muzzle/MuzzleMesh
## Ausgeworfene Huelsen: laufen, solange geschossen wird
@onready var casings: GPUParticles3D = $Casings
var _casing_time: float = 0.0


func _ready() -> void:
	super._ready()
	
	# Prozeduralen Schusssound generieren
	if audio_player:
		audio_player.stream = SoundGenerator.create_machinegun_sound()
		audio_player.volume_db = -5.0
	
	if muzzle_flash:
		muzzle_flash.visible = false
	if muzzle_mesh:
		muzzle_mesh.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	if _casing_time > 0.0:
		_casing_time -= delta
		if _casing_time <= 0.0:
			casings.emitting = false


func _on_fire(shooter: Node3D, camera: Node3D) -> void:
	# Schuss-Sound abspielen (mit leichter Tonhoehenvariation fuer Realismus)
	if audio_player:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()
	
	# Muendungsfeuer kurz aufblitzen lassen, Huelse auswerfen
	_flash_muzzle()
	casings.emitting = true
	_casing_time = 0.12
	
	# Hitscan-Raycast aus der Mitte der Kamera durchfuehren
	var space_state := camera.get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	
	# Streuung berechnen
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y
	var spread_offset: Vector3 = (right * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0)) * spread_angle
	var to: Vector3 = from + (forward + spread_offset).normalized() * max_range
	
	# Raycast-Parameter: Spieler selbst ausschliessen
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	query.exclude = [shooter.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result := space_state.intersect_ray(query)
	# Leuchtspur von der Muendung zum Treffpunkt (oder bis zur maximalen Reichweite)
	Tracer.spawn(shooter.get_parent(), muzzle.global_position, result.position if result else to, Color(1.0, 0.75, 0.25))
	if result:
		var hit_pos: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		var collider: Object = result.collider
		
		# Funken-Effekt am Einschlagpunkt erzeugen
		HitSpark.spawn(shooter.get_parent(), hit_pos, hit_normal)
		
		# Schaden am Ziel anrichten (fuer Bots und Ziele in spaeteren Schritten)
		if collider and collider.has_method("take_damage"):
			collider.take_damage(DamageInfo.create(damage, shooter, hit_pos, forward, weapon_name))
			if shooter and shooter.has_method("on_enemy_hit"):
				shooter.on_enemy_hit(false, collider)


func _flash_muzzle() -> void:
	if muzzle_flash and muzzle_mesh:
		muzzle_flash.visible = true
		muzzle_mesh.visible = true
		var timer := get_tree().create_timer(0.04, false)
		timer.timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false
			if is_instance_valid(muzzle_mesh):
				muzzle_mesh.visible = false
		)
