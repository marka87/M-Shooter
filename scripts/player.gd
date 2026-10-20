extends CharacterBody3D
class_name Player

## Spieler-Skript mit Quake/UT-artiger Bewegung (Strafe-Jumping, Bunnyhop, Luftkontrolle)
## Basiert auf CharacterBody3D mit First-Person-Kamera und praeziser Physik.

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

@export_group("Bodenbewegung")
## Standard-Laufgeschwindigkeit am Boden (m/s)
@export var walk_speed: float = 8.0
## Erhoehte Laufgeschwindigkeit beim Sprinten mit Shift (m/s)
@export var sprint_speed: float = 12.0
## Bodenbeschleunigung (wie schnell der Spieler die Zielgeschwindigkeit erreicht)
@export var ground_accel: float = 12.0
## Bodenreibung (wie stark der Spieler bremst, wenn keine Richtungstaste gedrueckt wird)
@export var ground_friction: float = 6.0

@export_group("Quake-Luftbewegung & Strafe-Jumping")
## Beschleunigungsfaktor in der Luft bei seitlicher Eingabe (Strafe-Jump Mechanik)
@export var air_accel: float = 10.0
## Quake-Wunschgeschwindigkeit fuer die Luftprojektion (niedriger Wert erlaubt Strafe-Beschleunigung)
@export var air_wish_speed: float = 2.5
## Maximale horizontale Geschwindigkeit, die durch Strafe-Jumping erreicht werden kann
@export var air_max_speed: float = 28.0
## Zusaetzliche Quake-CPM-Luftlenkung (erlaubt geschmeidige Kurven in der Luft)
@export var air_control: float = 0.35

@export_group("Sprung und Schwerkraft")
## Aufwaertsimpuls beim Sprung (m/s)
@export var jump_velocity: float = 7.5
## Erhoehte Schwerkraft fuer schnelles, praezises Quake-Gefuehl (m/s²)
@export var gravity: float = 22.0
## Zeitfenster in Sekunden, um einen Sprung kurz vor der Landung zu puffern (Jump-Buffer)
@export var jump_buffer_time: float = 0.15
## Maximale Spruenge (2 = Doppelsprung im UT-Stil)
@export var max_jumps: int = 2
## Aufwaertsimpuls fuer den Doppelsprung in der Luft (m/s)
@export var double_jump_velocity: float = 8.0

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
@onready var jump_audio: AudioStreamPlayer = $JumpAudioPlayer

## Eigener Treffer an einem Gegner (fuer Hitmarker im HUD)
signal enemy_hit()
## Item eingesammelt (fuer Ansagen im HUD), Wert aus ItemPickup.PickupType
signal item_picked(pickup_type: int, item_name: String)

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
# INTERNE PHYSIK-VARIABLEN
# ==============================================================================

# Aktueller Nickwinkel der Kamera (Rauf/Runter in Radiant)
var camera_pitch: float = 0.0
# Puffer-Timer fuer Sprungeingabe kurz vor dem Bodenkontakt
var jump_buffer_timer: float = 0.0
# Ob der Spieler gerade rennt
var is_sprinting: bool = false
# Verbleibende Spruenge (fuer Doppelsprung)
var jumps_remaining: int = 2
# Kurz nach einem Jump-Pad-Start keine Bodenbewegung (sonst bremst die Reibung den Start)
var launch_grace: float = 0.0


func _ready() -> void:
	# Mauszeiger fangen fuer First-Person-Steuerung
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

	health.died.connect(_on_died)
	hud.bind(self)



func _unhandled_input(event: InputEvent) -> void:
	# Mausbewegung zur Blicksteuerung (Pause mit ESC laeuft ueber den GameManager)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontale Drehung (Yaw) auf den ganzen Koerper anwenden
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Vertikale Drehung (Pitch) nur auf den Kopf/die Kamera anwenden
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		head.rotation.x = camera_pitch



func _physics_process(delta: float) -> void:
	# Tot: keine Eingabe, nur noch Schwerkraft und Respawn-Countdown aktualisieren
	if is_dead:
		death_timer -= delta
		# Respawn ueber denselben Countdown wie die HUD-Anzeige (pausiert automatisch mit dem Spiel)
		if death_timer <= 0.0:
			_respawn()
			return
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Countdown / Siegerbildschirm: stehen bleiben, nur Schwerkraft
	if GameManager.is_frozen():
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Eingaberichtung aus der InputMap lesen (standardmaessig WASD)
	var wish_dir: Vector3 = get_input_direction()

	# Sprungzaehler auf dem Boden zuruecksetzen
	if is_on_floor():
		jumps_remaining = max_jumps

	# Sprinten pruefen (Shift-Taste)
	is_sprinting = is_sprint_pressed()

	# Sprung-Puffer aktualisieren
	if is_jump_just_pressed():
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# Boden- oder Luftbewegung ausfuehren
	launch_grace = maxf(launch_grace - delta, 0.0)
	if is_on_floor() and launch_grace <= 0.0:
		_process_ground_movement(wish_dir, delta)
	else:
		_process_air_movement(wish_dir, delta)

	# Physik-Bewegung ausfuehren (inklusive Wand-Gleitverhalten)
	move_and_slide()


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


## Prueft, ob die Sprint-Taste gedrueckt wird
func is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint")


## Prueft, ob die Sprungtaste gerade gedrueckt wurde
func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump")


## Prueft, ob die Sprungtaste gehalten wird (fuer automatisches Bunnyhopping)
func is_jump_held() -> bool:
	return Input.is_action_pressed("jump")


## Verarbeitung der Bewegung auf dem Boden (Reibung + Quake-Bodenbeschleunigung)
func _process_ground_movement(wish_dir: Vector3, delta: float) -> void:
	# 1. Bunnyhop: Wenn die Sprungtaste gehalten wird oder im Puffer ist, sofort springen
	if jump_buffer_timer > 0.0 or is_jump_held():
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		jumps_remaining = max_jumps - 1
		# Wichtig: Vor dem Sprung wird KEINE Bodenreibung angewendet, damit die Geschwindigkeit erhalten bleibt!
		return
	
	# 2. Bodenreibung anwenden (bremst horizontal ab)
	_apply_ground_friction(delta)
	
	# 3. Zielgeschwindigkeit bestimmen (Walk vs. Sprint)
	var target_max_speed: float = sprint_speed if is_sprinting else walk_speed
	
	# 4. Quake-Bodenbeschleunigung in Wunschrichtung
	if wish_dir.length_squared() > 0.001:
		var current_speed_in_wish_dir: float = velocity.dot(wish_dir)
		var add_speed: float = target_max_speed - current_speed_in_wish_dir
		if add_speed > 0.0:
			var accel_speed: float = ground_accel * delta * target_max_speed
			accel_speed = min(accel_speed, add_speed)
			velocity.x += wish_dir.x * accel_speed
			velocity.z += wish_dir.z * accel_speed


## Wendet Reibung auf die horizontale Geschwindigkeit an
func _apply_ground_friction(delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	if current_speed < 0.0001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	
	# Reibungsverlust berechnen
	var drop: float = current_speed * ground_friction * delta
	var new_speed: float = max(current_speed - drop, 0.0)
	var friction_factor: float = new_speed / current_speed
	velocity.x *= friction_factor
	velocity.z *= friction_factor


## Verarbeitung der Bewegung in der Luft (Schwerkraft, Strafe-Jumping & Luftkontrolle)
func _process_air_movement(wish_dir: Vector3, delta: float) -> void:
	# 1. Schwerkraft anwenden
	velocity.y -= gravity * delta
	
	# 2. Doppelsprung in der Luft (Unreal Tournament Style)
	if is_jump_just_pressed() and jumps_remaining > 0:
		jumps_remaining -= 1
		velocity.y = double_jump_velocity
		# Knackiger Richtungs-Wechsel in der Luft bei Richtungs-Eingabe
		if wish_dir.length_squared() > 0.001:
			var cur_h_speed := Vector2(velocity.x, velocity.z).length()
			var target_h_speed := maxf(cur_h_speed, walk_speed * 1.15)
			velocity.x = wish_dir.x * target_h_speed
			velocity.z = wish_dir.z * target_h_speed
		if jump_audio:
			jump_audio.pitch_scale = randf_range(1.1, 1.25)
			jump_audio.play()
	
	# 3. Quake Strafe-Jumping-Beschleunigung:
	# Durch diagonale Eingabe und synchrone Mausdrehung steht wish_dir nahezu senkrecht
	# zur aktuellen Geschwindigkeit. proj_speed ist dadurch klein, was add_speed hoch haelt
	# und die Gesamtgeschwindigkeit erhoeht!
	if wish_dir.length_squared() > 0.001:
		var proj_speed: float = velocity.dot(wish_dir)
		var add_speed: float = air_wish_speed - proj_speed
		
		if add_speed > 0.0:
			var accel_speed: float = air_accel * delta * air_wish_speed
			accel_speed = min(accel_speed, add_speed)
			velocity.x += wish_dir.x * accel_speed
			velocity.z += wish_dir.z * accel_speed
		
		# 3. Zusaetzliche CPM-Luftkontrolle (lenkt das Momentum geschmeidig in Blickrichtung um)
		if air_control > 0.0:
			_apply_air_control(wish_dir, delta)
	
	# Horizontale Maximalgeschwindigkeit begrenzen, um Glitches zu vermeiden
	var horizontal_vel: Vector2 = Vector2(velocity.x, velocity.z)
	if horizontal_vel.length() > air_max_speed:
		horizontal_vel = horizontal_vel.normalized() * air_max_speed
		velocity.x = horizontal_vel.x
		velocity.z = horizontal_vel.y


## Quake 3 CPM Air Control: erlaubt praezises Umlenken von Schwung in engen Kurven
func _apply_air_control(wish_dir: Vector3, delta: float) -> void:
	var horizontal_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = horizontal_vel.length()
	if speed < 0.1:
		return
	
	# Umlenken nur dann, wenn Vorwaertsbewegung gewuenscht wird
	var original_dir: Vector3 = horizontal_vel / speed
	var dot: float = original_dir.dot(wish_dir)
	if dot > 0.0:
		var k: float = air_control * dot * dot * delta * 32.0
		var new_dir: Vector3 = (original_dir * speed + wish_dir * k).normalized()
		velocity.x = new_dir.x * speed
		velocity.z = new_dir.z * speed


## Wird von Jump-Pads aufgerufen: Geschwindigkeit komplett ersetzen
func launch(launch_velocity: Vector3) -> void:
	velocity = launch_velocity
	launch_grace = 0.15
	jumps_remaining = max_jumps - 1


## Schadens-Empfang (von Bots, Raketen-Selbsttreffern und Explosionen)
func take_damage(info: DamageInfo) -> void:
	if is_dead:
		return
	GameManager.register_damage(info, self)
	health.apply_damage(info)

	# Physikalischer Impuls auf den Spieler
	velocity += info.direction * (info.amount * 0.15)

	# Treffer-Sound abspielen (Bildschirmblitz macht das HUD)
	hurt_audio.pitch_scale = randf_range(0.95, 1.05)
	hurt_audio.play()


## Spieler stirbt: Tod zaehlen, Respawn laeuft ueber death_timer in _physics_process
func _on_died(info: DamageInfo) -> void:
	death_timer = respawn_delay
	powerups.clear()
	# Selbsttreffer (Rocket-Jump) zaehlt als Selbstmord
	GameManager.register_kill(info.attacker, self, info.weapon_name)


## Respawn des Spielers an einem Spawnpunkt
func _respawn() -> void:
	health.reset()
	weapon_manager.reset_loadout()
	global_transform = GameManager.get_spawn_transform(self)

	# Blick wieder geradeaus richten
	camera_pitch = 0.0
	head.rotation.x = 0.0

	velocity = Vector3.ZERO


## Wird vom Pickup aufgerufen, das HUD zeigt dann z. B. "QUAD DAMAGE!"
func on_item_picked(pickup_type: int, item_name: String = "") -> void:
	item_picked.emit(pickup_type, item_name)


## Treffer-Feedback: Quake-Trefferton, Hitmarker zeigt das HUD
func on_enemy_hit() -> void:
	hitsound_audio.pitch_scale = randf_range(0.98, 1.05)
	hitsound_audio.play()
	enemy_hit.emit()
