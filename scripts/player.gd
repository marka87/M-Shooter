extends CharacterBody3D
class_name Player

## Spieler: First-Person-Kamera mit Mausblick, Eingaben, Schaden, Tod und Respawn, Schritte und
## Pickups. Die Bewegungsphysik (Strafe-Jumping, Bunnyhop, Doppelsprung, Dodge) steckt im
## MovementController (Knoten "Movement"), der Spieler fuettert ihn nur mit den Eingaben.

# ==============================================================================
# EINSTELLBARE VARIABLEN (TUNING)
# ==============================================================================

@export_group("Maus und Blickfeld")
## Mausempfindlichkeit fuer die Blickdrehung
@export var mouse_sensitivity: float = 0.002
## Minimaler Blickwinkel nach unten (Grad)
@export var min_pitch: float = -89.0
## Maximaler Blickwinkel nach oben (Grad)
@export var max_pitch: float = 89.0

# ==============================================================================
# INTERNE KNOTENREFERENZEN
# ==============================================================================

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_manager: WeaponManager = $Head/Camera3D/WeaponHolder
@onready var health: HealthComponent = $Health
@onready var powerups: PowerupComponent = $Powerups
@onready var hud: HUD = $HUD
@onready var hurt_audio: AudioStreamPlayer = $HurtAudioPlayer
@onready var hitsound_audio: AudioStreamPlayer = $HitsoundAudioPlayer
var _kill_audio: AudioStreamPlayer
@onready var jump_audio: AudioStreamPlayer = $JumpAudioPlayer
@onready var camera_feedback: CameraFeedback = $CameraFeedback
@onready var movement: MovementController = $Movement

## Eigener Treffer an einem Gegner (fuer Hitmarker im HUD)
signal enemy_hit()
## Item eingesammelt (fuer Ansagen im HUD), Wert aus ItemPickup.PickupType
signal item_picked(pickup_type: int, item_name: String)
## Dodge ausgefuehrt (weitergereicht vom MovementController, z. B. fuer die Kamera-Neigung)
signal dodged(local_dir: Vector3, wall: bool)

# ==============================================================================
# STATUS
# ==============================================================================

## Name in Killfeed und Scoreboard
@export var display_name: String = "Spieler"

@export_group("Respawn")
## Sekunden bis zum Respawn nach dem Tod
@export var respawn_delay: float = 3.0

## Verbleibende Zeit bis zum Respawn (wird vom HUD angezeigt)
var death_timer: float = 0.0
## Kurzform fuer health.is_dead (z. B. fuer den WeaponManager)
var is_dead: bool:
	get: return health.is_dead

# ==============================================================================
# INTERNE VARIABLEN
# ==============================================================================

# Aktueller Nickwinkel der Kamera (Rauf/Runter in Radiant)
var camera_pitch: float = 0.0
# Abstand Kopf ueber den Fuessen (aus der Szene)
var _head_offset: Vector3
# Schritte: zurueckgelegte Strecke seit dem letzten Schrittgeraeusch
const STEP_DISTANCE: float = 2.3
var _step_distance: float = 0.0
var _step_audio: AudioStreamPlayer = null


func _ready() -> void:
	# Mauszeiger fangen fuer First-Person-Steuerung
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Physik-Interpolation: Der Kopf (Kamera, Waffen) folgt in _process der interpolierten
	# Koerperposition, die Blickrichtung kommt direkt von der Maus (keine Verzoegerung)
	_head_offset = head.position
	head.top_level = true
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	# Empfindlichkeit aus den gespeicherten Einstellungen uebernehmen
	if GameManager.mouse_sensitivity > 0.0:
		mouse_sensitivity = GameManager.mouse_sensitivity

	# Sichtfeld aus den Einstellungen (horizontal, damit Breitbild nicht "zoomt")
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = GameManager.fov

	# Spieler im GameManager registrieren
	GameManager.current_player = self
	GameManager.register_participant(display_name, true)

	# Maximale Neigung fuer Boeden (verhindert das Hochklettern steiler Waende)
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.2

	# Sounds zuweisen (Treffer am Spieler, Quake-Trefferton, Doppelsprung)
	hurt_audio.stream = SoundGenerator.create_bot_hurt_sound()
	hitsound_audio.stream = SoundGenerator.create_hitsound()
	jump_audio.stream = SoundGenerator.create_double_jump_sound()
	_kill_audio = AudioStreamPlayer.new()
	_kill_audio.stream = SoundGenerator.create_kill_sound()
	add_child(_kill_audio)

	health.died.connect(_on_died)
	hud.bind(self)

	_step_audio = AudioStreamPlayer.new()
	_step_audio.volume_db = -9.0
	add_child(_step_audio)

	movement.jumped.connect(func(): _play_step(SoundGenerator.create_jump_sound(), -12.0))
	movement.double_jumped.connect(func():
		jump_audio.pitch_scale = randf_range(1.1, 1.25)
		jump_audio.play())
	movement.dodged.connect(func(local_dir: Vector3, wall: bool):
		_play_step(SoundGenerator.create_dodge_sound(), -4.0)
		dodged.emit(local_dir, wall))
	movement.landed.connect(_on_landed)


func _unhandled_input(event: InputEvent) -> void:
	# Mausbewegung zur Blicksteuerung (Pause mit ESC laeuft ueber den GameManager)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontale Drehung (Yaw) auf den ganzen Koerper anwenden
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Vertikale Drehung (Pitch) nur auf den Kopf/die Kamera anwenden
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		head.rotation.x = camera_pitch

	# Doppeltipp auf eine Richtungstaste = Dodge (nicht tot, nicht im Countdown)
	if is_dead or GameManager.is_frozen():
		return
	for action in MovementController.DODGE_DIRECTIONS:
		if event.is_action_pressed(action) and not event.is_echo():
			movement.handle_direction_tap(action)


func _physics_process(delta: float) -> void:
	# Tot: keine Eingabe, nur Schwerkraft und Respawn-Countdown (pausiert automatisch mit dem Spiel)
	if is_dead:
		death_timer -= delta
		if death_timer <= 0.0:
			_respawn()
			return
		movement.step_idle(delta)
		return

	# Countdown / Siegerbildschirm: stehen bleiben, nur Schwerkraft
	if GameManager.is_frozen():
		movement.step_idle(delta)
		return

	movement.step(get_input_direction(), Input.is_action_just_pressed("jump"), Input.is_action_pressed("jump"),
		Input.is_action_pressed("sprint"), delta)
	_update_step_sounds(delta)


## Landung: Kamera knickt ein, Fallschaden, Aufprall-Geraeusch nach hohem Fall
func _on_landed(fall_speed: float) -> void:
	camera_feedback.land(fall_speed)
	var fall_damage := movement.fall_damage_for(fall_speed)
	if fall_damage > 0.0:
		take_damage(DamageInfo.create(fall_damage, null, global_position, Vector3.ZERO, "Sturz"))
	if fall_speed < -7.0:
		_play_step(SoundGenerator.create_land_sound(), 0.0)
		_step_distance = 0.0


## Schritte beim Laufen: je schneller, desto oefter und lauter
func _update_step_sounds(delta: float) -> void:
	if not is_on_floor():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 1.5:
		_step_distance += speed * delta
		if _step_distance >= STEP_DISTANCE:
			_step_distance = 0.0
			# Leise beim Gehen, laut bei Sprint und Strafe-Jump-Tempo
			_play_step(SoundGenerator.create_footstep_sound(randi_range(1, 4)), lerpf(-14.0, -6.0, clampf((speed - 4.0) / 8.0, 0.0, 1.0)))


func _play_step(stream: AudioStream, volume_db: float) -> void:
	_step_audio.stream = stream
	_step_audio.volume_db = volume_db
	_step_audio.pitch_scale = randf_range(0.93, 1.07)
	_step_audio.play()


## Ermittelt die normalisierte Wunsch-Bewegungsrichtung im Weltkoordinatensystem
func get_input_direction() -> Vector3:
	# Pruefung ueber Action-Namen (InputMap), damit Tasten frei belegbar bleiben.
	# get_vector begrenzt die Laenge bereits auf 1 (keine schnellere Diagonale).
	var raw_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Richtung relativ zur Koerperausrichtung berechnen
	var direction: Vector3 = (transform.basis * Vector3(raw_dir.x, 0.0, raw_dir.y))
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	return direction


## Wird von Jump-Pads aufgerufen (gleiche Schnittstelle wie beim Bot)
func launch(launch_velocity: Vector3) -> void:
	movement.launch(launch_velocity)


## Schadens-Empfang (von Bots, Raketen-Selbsttreffern und Explosionen)
func take_damage(info: DamageInfo) -> void:
	if is_dead:
		return
	GameManager.register_damage(info, self)
	health.apply_damage(info)

	# Physikalischer Impuls auf den Spieler
	velocity += info.direction * (info.amount * 0.15)
	camera_feedback.hit(info.amount)

	# Treffer-Sound abspielen (Bildschirmblitz macht das HUD)
	hurt_audio.pitch_scale = randf_range(0.95, 1.05)
	hurt_audio.play()


func _process(_delta: float) -> void:
	head.global_position = get_global_transform_interpolated().origin + _head_offset
	head.global_rotation = Vector3(camera_pitch, global_rotation.y, 0.0)


## Spieler stirbt: Tod zaehlen, Respawn laeuft ueber death_timer in _physics_process
func _on_died(info: DamageInfo) -> void:
	death_timer = respawn_delay
	powerups.clear()
	# Selbsttreffer (Rocket-Jump) zaehlt als Selbstmord
	GameManager.register_kill(info.attacker, self, info.weapon_name, info.is_headshot)


## Respawn des Spielers an einem Spawnpunkt
func _respawn() -> void:
	health.reset()
	weapon_manager.reset_loadout()
	global_transform = GameManager.get_spawn_transform(self)
	reset_physics_interpolation()

	# Blick wieder geradeaus richten
	camera_pitch = 0.0
	head.rotation.x = 0.0

	velocity = Vector3.ZERO
	movement.reset()


## Nach einem Teleporter: geradeaus schauen, kurzes Kamerawackeln
func on_teleported() -> void:
	camera_pitch = 0.0
	head.rotation.x = 0.0
	movement.launch_grace = 0.1
	camera_feedback.add_trauma(0.25)


## Wird vom Pickup aufgerufen, das HUD zeigt dann z. B. "QUAD DAMAGE!"
func on_item_picked(pickup_type: int, item_name: String = "") -> void:
	item_picked.emit(pickup_type, item_name)
	match pickup_type:
		ItemPickup.PickupType.QUAD_DAMAGE:
			GameManager.play_announcer("quad_damage")
		ItemPickup.PickupType.MEGA_HEALTH:
			GameManager.play_announcer("mega_health")


## Treffer-Feedback: Quake-Trefferton (Kopftreffer mit eigenem Ton), Hitmarker zeigt das HUD
func on_enemy_hit(headshot: bool = false) -> void:
	hitsound_audio.stream = SoundGenerator.create_headshot_sound() if headshot else SoundGenerator.create_hitsound()
	hitsound_audio.pitch_scale = 1.0 if headshot else randf_range(0.98, 1.05)
	hitsound_audio.play()
	enemy_hit.emit()


## Eigener Ton, wenn ein Treffer einen Gegner erledigt (ruft der GameManager)
func on_enemy_killed() -> void:
	_kill_audio.play()
