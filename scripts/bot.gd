extends CharacterBody3D
class_name Bot

## Gegner-Bot fuer die Arena mit Zustandsmaschine (Patrouille, Verfolgen, Angreifen, Tot).
## Jeder gegen jeden: Ziel ist der naechste sichtbare Gegner (Spieler oder anderer Bot).
## Verwendet NavigationAgent3D fuer die Wegfindung und schiesst mit Streuung je nach Schwierigkeit.

# ==============================================================================
# ZUSTAENDE (STATE MACHINE)
# ==============================================================================

enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.PATROL

# ==============================================================================
# EINSTELLBARE VARIABLEN
# ==============================================================================

@export_group("Bot Eigenschaften")
## Name in Killfeed, Scoreboard und Namensschild (leer = Knotenname)
@export var display_name: String = ""
@export var patrol_speed: float = 4.5
@export var chase_speed: float = 7.5
@export var combat_speed: float = 3.5
@export var attack_range: float = 16.0
@export var sight_range: float = 35.0
@export var shoot_interval: float = 0.28 # Zeit zwischen Schuessen im Angriffsmodus
@export var damage_per_shot: float = 8.0 # Schaden pro Treffer
@export var inaccuracy_degrees: float = 4.0 # Ungenauigkeit (Streuung) in Grad
@export var respawn_delay: float = 4.0 # Zeit in Sekunden bis zum Wiederbeleben
@export var gravity: float = 22.0
## Zeit vom Entdecken eines Ziels bis zum ersten Schuss (s)
@export var reaction_time: float = 0.4
## Leuchtfarbe (Visier, Brustlicht, Schulterpanzer), damit Bots gut unterscheidbar sind
@export var skin_color: Color = Color(1.0, 0.25, 0.2)

# ==============================================================================
# SCHWIERIGKEIT
# ==============================================================================

## Namen der Stufen (Index = GameManager.bot_skill)
const SKILL_NAMES: Array[String] = ["Anfänger", "Normal", "Erfahren", "Profi", "Gott"]
## Werte je Stufe: Streuung (Grad), Reaktionszeit (s), Zeit zwischen Schuessen (s),
## Ausweichtempo im Kampf (m/s), Sichtweite (m)
const SKILL_PRESETS: Array[Dictionary] = [
	{ "inaccuracy": 9.0, "reaction": 0.9, "interval": 0.45, "combat_speed": 2.0, "sight": 25.0 },
	{ "inaccuracy": 6.0, "reaction": 0.6, "interval": 0.35, "combat_speed": 3.0, "sight": 30.0 },
	{ "inaccuracy": 4.0, "reaction": 0.4, "interval": 0.28, "combat_speed": 3.5, "sight": 35.0 },
	{ "inaccuracy": 2.5, "reaction": 0.25, "interval": 0.22, "combat_speed": 4.5, "sight": 45.0 },
	{ "inaccuracy": 1.2, "reaction": 0.12, "interval": 0.18, "combat_speed": 5.5, "sight": 60.0 },
]

# ==============================================================================
# KNOTEN-REFERENZEN
# ==============================================================================

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var nameplate: Label3D = $Nameplate
@onready var muzzle: Node3D = $Muzzle
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health: HealthComponent = $Health

# ==============================================================================
# INTERNE VARIABLEN
# ==============================================================================

var shoot_timer: float = 0.0
# Aktuelles Ziel (Spieler oder Bot) und Timer fuer die naechste Zielsuche
var target: CharacterBody3D = null
var target_scan_timer: float = 0.0
# Verbleibende Reaktionszeit bis zum ersten Schuss auf ein neues Ziel
var reaction_timer: float = 0.0
var lose_target_timer: float = 0.0
var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer: float = 0.0
var strafe_direction: float = 1.0
var strafe_timer: float = 0.0
# Einmal ausgewuerfelte Dauer bis zum naechsten Richtungswechsel beim Strafen
var strafe_duration: float = 1.5
# Laufzeit zum aktuellen Patrouillenziel (gegen Haengenbleiben)
var patrol_travel_timer: float = 0.0
# Im Flug nach einem Jump-Pad: keine eigene Steuerung bis zur Landung
var is_launched: bool = false
var original_mesh_transform: Transform3D
var hit_spark_scene: PackedScene = preload("res://scenes/weapons/hit_spark.tscn")
var floating_number_scene: PackedScene = preload("res://scenes/effects/floating_number.tscn")
# Vorgenerierte Sounds und Trefferfarbe (einmal pro Bot statt bei jedem Schuss)
var snd_shot: AudioStream
var snd_hurt: AudioStream
var snd_death: AudioStream
var flash_mat: StandardMaterial3D



func _ready() -> void:
	if display_name.is_empty():
		display_name = name
	GameManager.register_participant(display_name, false)
	original_mesh_transform = body_mesh.transform

	snd_shot = SoundGenerator.create_machinegun_sound()
	snd_hurt = SoundGenerator.create_bot_hurt_sound()
	snd_death = SoundGenerator.create_bot_death_sound()

	flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 1.0, 1.0)
	flash_mat.emission_energy_multiplier = 2.0

	if muzzle_flash:
		muzzle_flash.visible = false
	_apply_skin_color()

	nav_agent.target_desired_distance = 1.5
	nav_agent.path_desired_distance = 1.0
	health.changed.connect(func(_h: float, _a: float): _update_nameplate())
	health.died.connect(_die)
	_update_nameplate()

	# Kurze Pause bis der Navigationsserver synchronisiert ist, erst dann gibt es Zufallspunkte
	await get_tree().physics_frame
	_pick_new_patrol_point()


func _physics_process(delta: float) -> void:
	# Tot-Zustand: Keine Bewegung
	if current_state == State.DEAD:
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
		return

	# Flug nach Jump-Pad: nur Schwerkraft, bis der Bot wieder steht
	if is_launched:
		velocity.y -= gravity * delta
		move_and_slide()
		if is_on_floor() and velocity.y <= 0.0:
			is_launched = false
		return

	# Schwerkraft anwenden
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Timer aktualisieren
	if shoot_timer > 0.0:
		shoot_timer -= delta

	# Ziel regelmaessig neu waehlen (nicht jeden Frame, das spart Raycasts)
	target_scan_timer -= delta
	if target_scan_timer <= 0.0:
		target_scan_timer = 0.25
		_update_target()

	var target_visible: bool = false
	var distance_to_target: float = 9999.0
	if _is_alive(target):
		distance_to_target = global_position.distance_to(target.global_position)
		target_visible = _check_line_of_sight(target)

	# Zustandsmaschine abarbeiten
	match current_state:
		State.PATROL:
			_process_patrol(delta, target, target_visible, distance_to_target)
		State.CHASE:
			_process_chase(delta, target, target_visible, distance_to_target)
		State.ATTACK:
			_process_attack(delta, target, target_visible, distance_to_target)

	# Bewegung ausfuehren
	move_and_slide()


# ==============================================================================
# ZUSTANDS-LOGIK (PATROL, CHASE, ATTACK, DEAD)
# ==============================================================================

## Patrouille: Zufaellige Wegpunkte ansteuern und nach Gegnern Ausschau halten
func _process_patrol(delta: float, _target: CharacterBody3D, target_visible: bool, distance: float) -> void:
	# Wenn ein Gegner in Sicht und Reichweite ist -> Verfolgung aufnehmen
	if target_visible and distance < sight_range:
		_switch_state(State.CHASE)
		return

	# Wartezeit am Wegpunkt
	if patrol_wait_timer > 0.0:
		patrol_wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		return

	# Zum Patrouillen-Zielpunkt laufen (nur horizontal messen, sonst wird ein Ziel auf
	# anderer Hoehe nie "erreicht"). Nach 12 Sekunden ohne Ankunft neues Ziel waehlen.
	patrol_travel_timer += delta
	var to_target := patrol_target - global_position
	to_target.y = 0.0
	if to_target.length() < 2.0 or nav_agent.is_navigation_finished() or patrol_travel_timer > 12.0:
		patrol_wait_timer = randf_range(1.5, 3.5)
		_pick_new_patrol_point()
		return

	_move_towards(patrol_target, patrol_speed, delta)


## Verfolgen: Mit Navigationsagent auf das Ziel zulaufen
func _process_chase(delta: float, chase_target: CharacterBody3D, target_visible: bool, distance: float) -> void:
	if not _is_alive(chase_target):
		_switch_state(State.PATROL)
		return

	# In Angriffsmodus wechseln, wenn nahe genug und freie Schussbahn
	if target_visible and distance <= attack_range:
		_switch_state(State.ATTACK)
		reaction_timer = reaction_time
		return

	# Wenn das Ziel nicht mehr sichtbar ist, Timer starten
	if not target_visible:
		lose_target_timer += delta
		if lose_target_timer > 5.0:
			_switch_state(State.PATROL)
			return
	else:
		lose_target_timer = 0.0

	# Weg zum Ziel berechnen
	_move_towards(chase_target.global_position, chase_speed, delta)


## Angreifen: Ziel fixieren, seitlich strafen und gezielt feuern
func _process_attack(delta: float, attack_target: CharacterBody3D, target_visible: bool, distance: float) -> void:
	if not _is_alive(attack_target):
		_switch_state(State.PATROL)
		return

	# Wenn das Ziel ausser Reichweite oder hinter einer Wand verschwunden ist
	if not target_visible or distance > attack_range * 1.35:
		lose_target_timer += delta
		if lose_target_timer > 1.2:
			_switch_state(State.CHASE)
			return
	else:
		lose_target_timer = 0.0

	# Das Ziel horizontal ansehen
	_look_towards(attack_target.global_position)

	# Seitliches Strafe-Ausweichmanoever
	strafe_timer += delta
	if strafe_timer > strafe_duration:
		strafe_timer = 0.0
		strafe_duration = randf_range(1.2, 2.0)
		strafe_direction = -strafe_direction if randf() > 0.3 else strafe_direction

	var right_vec := transform.basis.x
	var combat_velocity := right_vec * (strafe_direction * combat_speed)

	# Zu nah am Ziel? Leicht zurueckweichen
	if distance < 6.0:
		combat_velocity -= transform.basis.z * (combat_speed * 0.8)

	velocity.x = combat_velocity.x
	velocity.z = combat_velocity.z

	# Erst nach der Reaktionszeit schiessen, dann im Takt der Abklingzeit
	reaction_timer -= delta
	if reaction_timer <= 0.0 and shoot_timer <= 0.0 and target_visible:
		_bot_fire(attack_target)
		shoot_timer = shoot_interval


## Zustand wechseln und vorbereiten
func _switch_state(new_state: State) -> void:
	current_state = new_state
	lose_target_timer = 0.0
	_update_nameplate()


# ==============================================================================
# SCHIESSEN & SICHTLINIE
# ==============================================================================

## Prueft, ob freie Sichtlinie (Line of Sight) zu einem Ziel besteht
func _check_line_of_sight(los_target: Node3D) -> bool:
	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0.0, 1.4, 0.0)
	var to: Vector3 = los_target.global_position + Vector3(0.0, 1.0, 0.0)

	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := space_state.intersect_ray(query)
	if hit:
		return hit.collider == los_target
	return false


## Lebender Kaempfer (Spieler oder Bot)?
func _is_alive(node: Node) -> bool:
	return is_instance_valid(node) and node.get("health") != null and not node.health.is_dead


## Naechsten sichtbaren Gegner in Sichtweite waehlen. Ein sichtbares Ziel wird behalten,
## ein verdecktes ebenfalls (zum Verfolgen), bis ein anderer Gegner sichtbar wird.
func _update_target() -> void:
	if _is_alive(target) and _check_line_of_sight(target):
		return
	var best: CharacterBody3D = null
	var best_dist: float = sight_range
	for group in ["player", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or not _is_alive(node):
				continue
			var dist: float = global_position.distance_to(node.global_position)
			if dist < best_dist and _check_line_of_sight(node):
				best = node
				best_dist = dist
	if best:
		if best != target:
			reaction_timer = reaction_time
		target = best
	elif not _is_alive(target):
		target = null


## Werte einer Schwierigkeitsstufe uebernehmen (0 = Anfaenger ... 4 = Gott)
func apply_skill(level: int) -> void:
	var preset: Dictionary = SKILL_PRESETS[clampi(level, 0, SKILL_PRESETS.size() - 1)]
	inaccuracy_degrees = preset.inaccuracy
	reaction_time = preset.reaction
	shoot_interval = preset.interval
	combat_speed = preset.combat_speed
	sight_range = preset.sight


## Bot schiesst mit Streuung auf sein Ziel (trifft auch, wer im Weg steht)
func _bot_fire(fire_target: CharacterBody3D) -> void:
	# Schuss-Sound
	if audio_player:
		audio_player.stream = snd_shot
		audio_player.pitch_scale = randf_range(0.85, 0.95)
		audio_player.play()

	# Muendungsfeuer aufblitzen lassen
	_flash_muzzle()

	var from: Vector3 = muzzle.global_position if muzzle else global_position + Vector3(0.0, 1.2, 0.0)
	var target_chest: Vector3 = fire_target.global_position + Vector3(0.0, 1.0, 0.0)
	var base_dir: Vector3 = (target_chest - from).normalized()

	# Leichte Ungenauigkeit hinzufuegen (faire Bot-Praezision)
	var spread_rad: float = deg_to_rad(inaccuracy_degrees)
	var random_offset := Vector3(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad)
	)
	var shoot_dir: Vector3 = (base_dir + random_offset).normalized()
	var to: Vector3 = from + shoot_dir * 100.0

	# Raycast fuer Schuss
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.HITTABLE)
	query.exclude = [get_rid()]

	var hit := space_state.intersect_ray(query)
	if hit:
		var hit_collider: Object = hit.collider
		var hit_pos: Vector3 = hit.position
		var hit_normal: Vector3 = hit.normal

		# Funken am Treffpunkt
		if hit_spark_scene:
			var spark := hit_spark_scene.instantiate() as Node3D
			get_parent().add_child(spark)
			spark.global_position = hit_pos + hit_normal * 0.05
			# Zur Oberflaeche ausrichten, damit das Einschussloch richtig auf der Wand liegt
			if hit_normal.length_squared() > 0.001:
				spark.look_at(spark.global_position + hit_normal, Vector3.UP if absf(hit_normal.y) < 0.98 else Vector3.FORWARD)

		# Schaden am Getroffenen anrichten
		if hit_collider and hit_collider.has_method("take_damage"):
			hit_collider.take_damage(DamageInfo.create(damage_per_shot, self, hit_pos, shoot_dir, "Maschinengewehr"))


func _flash_muzzle() -> void:
	if muzzle_flash:
		muzzle_flash.visible = true
		get_tree().create_timer(0.05, false).timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false
		)


# ==============================================================================
# SCHADEN, TOD & RESPAWN
# ==============================================================================

## Wird von Jump-Pads aufgerufen
func launch(launch_velocity: Vector3) -> void:
	velocity = launch_velocity
	is_launched = true


## Schadens-Empfang (wird von Maschinengewehr, Railgun und Explosionen aufgerufen)
func take_damage(info: DamageInfo) -> void:
	if current_state == State.DEAD:
		return
	var amount: float = info.amount

	# Schwebende 3D-Schadenszahl erzeugen
	if floating_number_scene:
		var fn := floating_number_scene.instantiate() as FloatingNumber
		get_parent().add_child(fn)
		# Bei Flaechenschaden liegt der Trefferpunkt in der Explosion, deshalb ueber dem Kopf anzeigen
		var spawn_pos: Vector3 = global_position + Vector3(0.0, 1.4, 0.0) if info.is_splash else info.position
		fn.setup(amount, spawn_pos)

	# Treffer-Sound abspielen
	if audio_player:
		audio_player.stream = snd_hurt
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()

	# Treffer-Impuls (z.B. durch Raketen-Explosion)
	velocity += info.direction * (amount * 0.12)

	# Optischer Trefferblitz (Mesh kurz weiss aufleuchten lassen)
	_flash_hit()

	# Rache: Wer schiesst, wird zum Ziel (ausser bei Selbsttreffern)
	if info.attacker != self and _is_alive(info.attacker) and info.attacker is CharacterBody3D:
		if info.attacker != target:
			target = info.attacker
			reaction_timer = reaction_time
		if current_state == State.PATROL:
			_switch_state(State.CHASE)

	# Schaden zuletzt anwenden: Bei Tod startet health.died -> _die() mit Todes-Sound,
	# der sonst vom Treffer-Sound oben ueberschrieben wuerde
	health.apply_damage(info)


## Kurzes optisches Aufblitzen bei Treffern (ganzes Modell kurz weiss)
func _flash_hit() -> void:
	var meshes := _model_meshes()
	for mesh in meshes:
		mesh.material_override = flash_mat
	get_tree().create_timer(0.08, false).timeout.connect(func():
		for mesh in meshes:
			if is_instance_valid(mesh):
				mesh.material_override = null
	)


## Alle sichtbaren Teile des Roboters
func _model_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = [body_mesh]
	for child in body_mesh.get_children():
		if child is MeshInstance3D:
			result.append(child)
	return result


## Leuchtteile (Material Mat_BotAccent) und Lackteile (Mat_BotPaint) in skin_color einfaerben.
## Jeder Bot bekommt eigene Kopien, die Szene selbst bleibt unveraendert.
func _apply_skin_color() -> void:
	var recolored: Dictionary = {}
	for mesh in _model_meshes():
		var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat == null or not mat.emission_enabled or mesh.name == "GunMesh":
			continue
		if not recolored.has(mat):
			var copy: StandardMaterial3D = mat.duplicate()
			copy.albedo_color = skin_color
			copy.emission = skin_color
			recolored[mat] = copy
		mesh.set_surface_override_material(0, recolored[mat])


## Tod des Bots: Kollision abschalten, Sound, Frag fuer Spieler und Respawn-Timer
func _die(info: DamageInfo) -> void:
	_switch_state(State.DEAD)

	# Todes-Sound
	if audio_player:
		audio_player.stream = snd_death
		audio_player.play()

	# Abschuss melden (Frag fuer den Schuetzen, Killfeed)
	GameManager.register_kill(info.attacker, self, info.weapon_name)

	# Kollision temporaer deaktivieren
	if collision_shape:
		collision_shape.disabled = true

	# Umfall-Animation per Tween
	var tween := create_tween()
	tween.tween_property(body_mesh, "rotation_degrees:x", 85.0, 0.3)

	# Respawn nach Verzoegerung
	get_tree().create_timer(respawn_delay, false).timeout.connect(_respawn)


## Respawn: Reaktiviert den Bot an einem Spawnpunkt
func _respawn() -> void:
	health.reset()

	# Am Spawnpunkt mit dem groessten Abstand zu anderen Kaempfern
	global_transform = GameManager.get_spawn_transform(self)
	target = null

	# Mesh-Drehung und Kollision zuruecksetzen
	body_mesh.transform = original_mesh_transform
	if collision_shape:
		collision_shape.disabled = false

	velocity = Vector3.ZERO
	_switch_state(State.PATROL)
	_pick_new_patrol_point()


# ==============================================================================
# HILFSFUNKTIONEN (BEWEGUNG & NAVIGATION)
# ==============================================================================

## Bewegt den Bot zu einer Zielposition (ueber NavAgent oder direkte Lenkung)
func _move_towards(target_pos: Vector3, speed: float, _delta: float) -> void:
	nav_agent.target_position = target_pos

	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = (next_path_pos - global_position)
	dir.y = 0.0

	# Falls Navigationsnetz nicht bereit oder Ziel direkt erreichbar
	if dir.length_squared() < 0.01:
		dir = (target_pos - global_position)
		dir.y = 0.0

	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_look_towards(global_position + dir)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## Dreht den Bot horizontal in die angegebene Richtung
func _look_towards(target_pos: Vector3) -> void:
	var look_target := Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)


## Waehlt einen neuen zufaelligen, erreichbaren Punkt auf dem Navigationsnetz
func _pick_new_patrol_point() -> void:
	patrol_travel_timer = 0.0
	var nav_map: RID = nav_agent.get_navigation_map()
	if nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
		patrol_target = NavigationServer3D.map_get_random_point(nav_map, nav_agent.navigation_layers, false)
	else:
		# Fallback, solange das Navigationsnetz noch nicht bereit ist
		patrol_target = Vector3(randf_range(-30.0, 30.0), 1.0, randf_range(-30.0, 30.0))
	# Ziel sofort setzen, damit is_navigation_finished() nicht noch vom alten Ziel true meldet
	nav_agent.target_position = patrol_target


## Aktualisiert das schwebende 3D-Namensschild ueber dem Kopf
func _update_nameplate() -> void:
	if not nameplate:
		return

	var state_text: String = ""
	match current_state:
		State.PATROL: state_text = "Patrouille"
		State.CHASE: state_text = "Verfolgen"
		State.ATTACK: state_text = "Angriff"
		State.DEAD: state_text = "TOT"

	nameplate.text = "%s [%s] - %d HP" % [display_name, state_text, int(health.health)]

	if health.is_dead:
		nameplate.modulate = Color(0.5, 0.5, 0.5)
	elif current_state == State.ATTACK:
		nameplate.modulate = Color(1.0, 0.25, 0.2)
	elif current_state == State.CHASE:
		nameplate.modulate = Color(1.0, 0.7, 0.1)
	else:
		nameplate.modulate = Color(0.3, 0.8, 1.0)
