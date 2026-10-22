extends Node3D

## Explosions-Effekt mit Flaechenschaden, Abstandsabfall, Quake-Rocket-Jump-Impuls und Sound

@export var max_damage: float = 100.0
@export var blast_radius: float = 6.0
@export var blast_force: float = 24.0 # Wucht fuer Rueckstoss / Rocket-Jumping

@onready var light: OmniLight3D = $OmniLight3D
@onready var blast_sphere: MeshInstance3D = $BlastSphere
@onready var particles: GPUParticles3D = $Debris
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var shooter_node: Node = null
var weapon_name: String = "Raketenwerfer"
## Optionale Einfaerbung (z. B. violett fuer die Shock-Combo). Alpha 0 = Originalfarben.
var tint: Color = Color(0, 0, 0, 0)

var scorch_scene: PackedScene = preload("res://scenes/effects/scorch_decal.tscn")


func _ready() -> void:
	# Explosionssound abspielen
	if audio_player:
		audio_player.stream = SoundGenerator.create_explosion_sound()
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()
	
	if tint.a > 0.0:
		_apply_tint()

	# Partikel starten
	if particles:
		particles.emitting = true
	
	# Brandfleck an der Wand oder am Boden erzeugen
	_spawn_scorch_decal()

	# Flaechenschaden und Explosionswucht auf alle getroffenen Einheiten anwenden
	_apply_blast_damage_and_impulse()
	_shake_player_camera()
	
	# Visuelle Schockwelle expandieren und ausblenden
	var tween := create_tween()
	blast_sphere.scale = Vector3(0.2, 0.2, 0.2)
	tween.parallel().tween_property(blast_sphere, "scale", Vector3.ONE * (blast_radius * 0.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.45)
	
	# Nach Ablauf der Effekte entfernen
	get_tree().create_timer(1.2, false).timeout.connect(queue_free)


## Kamera des Spielers wackelt je nach Entfernung (bis zum dreifachen Explosionsradius)
func _shake_player_camera() -> void:
	var player := GameManager.current_player as Player
	if not is_instance_valid(player):
		return
	var reach: float = blast_radius * 3.0
	var dist: float = player.global_position.distance_to(global_position)
	if dist < reach:
		player.camera_feedback.add_trauma(0.7 * (1.0 - dist / reach) * clampf(max_damage / 100.0, 0.6, 1.5))


## Sucht die naechste Wand/Bodenflaeche und platziert dort einen Brandkrater
func _spawn_scorch_decal() -> void:
	if not scorch_scene or not get_parent():
		return
	var space_state := get_world_3d().direct_space_state
	var ray_targets := [Vector3.DOWN * 2.5, Vector3.UP * 1.5, Vector3.FORWARD * 1.5, Vector3.BACK * 1.5, Vector3.LEFT * 1.5, Vector3.RIGHT * 1.5]
	for dir in ray_targets:
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + dir, Layers.WORLD)
		query.collide_with_areas = false
		var hit := space_state.intersect_ray(query)
		if hit:
			var scorch := scorch_scene.instantiate() as ScorchDecal
			get_parent().add_child(scorch)
			scorch.global_position = hit.position + hit.normal * 0.02
			var tint_col: Color = tint if tint.a > 0.0 else Color(1.0, 0.45, 0.1)
			scorch.setup_scorch(hit.normal, clampf(blast_radius * 0.5, 2.0, 4.5), tint_col)
			break


## Kugel, Licht und Truemmer in der Tint-Farbe einfaerben (eigene Material-Kopien)
func _apply_tint() -> void:
	light.light_color = tint
	var sphere_mat := (blast_sphere.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	sphere_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.75)
	sphere_mat.emission = tint
	blast_sphere.material_override = sphere_mat
	var debris_mat := (particles.draw_pass_1.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	debris_mat.albedo_color = tint.lightened(0.3)
	debris_mat.emission = tint
	particles.material_override = debris_mat


func _apply_blast_damage_and_impulse() -> void:
	var space_state := get_world_3d().direct_space_state
	var explosion_pos: Vector3 = global_position
	
	# Physik-Abfrage fuer alle Koerper im Explosionsradius
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = blast_radius
	
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere_shape
	shape_query.transform = Transform3D(Basis(), explosion_pos)
	# Spieler, Bots und Physik-Props bekommen Schaden und Rueckstoss
	shape_query.collision_mask = Layers.BLASTABLE
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false
	
	var results := space_state.intersect_shape(shape_query, 64)
	# Koerper mit mehreren Kollisionsformen tauchen mehrfach auf, aber nur einmal Schaden
	var already_hit: Array[Object] = []
	for hit in results:
		var body: Object = hit.collider
		if not is_instance_valid(body) or not (body is Node3D) or already_hit.has(body):
			continue
		already_hit.append(body)

		var body_pos: Vector3 = (body as Node3D).global_position
		# Bei Charakteren den Schwerpunkt etwas anheben fuer sauberen Aufwaertsimpuls
		var center: Vector3 = body_pos + Vector3(0.0, 0.8, 0.0)
		var diff: Vector3 = center - explosion_pos
		var distance: float = diff.length()

		if distance > blast_radius:
			continue

		# Keine Wirkung durch Waende hindurch
		if not _has_line_of_sight(space_state, explosion_pos, center):
			continue

		# Linearer Abstandsabfall (1.0 im Zentrum bis 0.0 am Rand)
		var factor: float = clampf(1.0 - (distance / blast_radius), 0.0, 1.0)
		var dir: Vector3 = diff.normalized() if distance > 0.01 else Vector3.UP
		
		# 1. Impuls fuer Rocket-Jumping / Physik-Objekte anwenden (Quake/Jolt-Physik)
		if body is CharacterBody3D:
			var impulse: Vector3 = dir * (blast_force * factor)
			if impulse.y < 5.0 and factor > 0.25:
				impulse.y = 8.5 * factor
			(body as CharacterBody3D).velocity += impulse
		elif body is RigidBody3D:
			var phys_impulse: Vector3 = dir * (blast_force * factor * 1.5) + Vector3.UP * (blast_force * factor * 0.6)
			(body as RigidBody3D).apply_impulse(phys_impulse)
		
		# 2. Schaden anrichten (fuer Spieler, Bots und zerstoerbare Props)
		var actual_damage: float = max_damage * factor
		if body.has_method("take_damage"):
			# Bei Selbsttreffer (Rocket-Jump) 40% Eigenschaden
			if body == shooter_node:
				actual_damage *= 0.4
			body.take_damage(DamageInfo.create(actual_damage, shooter_node, explosion_pos, dir, weapon_name, true))
			if shooter_node and shooter_node != body and shooter_node.has_method("on_enemy_hit"):
				shooter_node.on_enemy_hit(false, body)


## Prueft, ob zwischen Explosion und Ziel keine Wand liegt (andere Figuren schirmen nicht ab)
func _has_line_of_sight(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	query.collide_with_areas = false
	return space_state.intersect_ray(query).is_empty()
