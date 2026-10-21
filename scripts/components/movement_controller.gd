extends Node
class_name MovementController

## Quake/UT-Bewegung fuer einen CharacterBody3D (Eltern-Knoten): Bodenbewegung mit Reibung, Bunnyhop,
## Treppensteigen (Step-Up), Rampen-Sliding mit Ramp-Jump, Strafe-Jumping und CPM-Luftkontrolle, Doppelsprung, Dodge und Wall-Dodge, Jump-Pad-Starts.
## Arbeitet nur mit uebergebenen Eingabewerten (Richtung, Sprung, Sprint) statt direkt mit Input,
## damit dieselbe Bewegung spaeter auch fuer Netzwerk-Eingaben oder Bots nutzbar ist.
## Ton und Kamera haengen sich an die Signale.

signal jumped()
signal double_jumped()
## Dodge ausgefuehrt (lokale Richtung, z. B. (1, 0, 0) = rechts; wall = Wall-Dodge)
signal dodged(local_dir: Vector3, wall: bool)
## Wieder auf dem Boden (fall_speed = staerkste Fallgeschwindigkeit, negativ)
signal landed(fall_speed: float)

@export_group("Bodenbewegung")
## Standard-Laufgeschwindigkeit am Boden (m/s)
@export var walk_speed: float = 8.0
## Erhoehte Laufgeschwindigkeit beim Sprinten (m/s)
@export var sprint_speed: float = 12.0
## Bodenbeschleunigung (wie schnell die Zielgeschwindigkeit erreicht wird)
@export var ground_accel: float = 12.0
## Bodenreibung (wie stark ohne Richtungstaste gebremst wird)
@export var ground_friction: float = 6.0
## Hoechste Stufe, die man ohne Springen hochlaeuft (m, Quake: 18 Einheiten)
@export var step_height: float = 0.45
## Ab diesem Tempo auf einer Rampe keine Bodenreibung: man rutscht mit Schwung weiter (m/s)
@export var ramp_slide_speed: float = 14.0
## Wie weit vor der Stufe nach Boden gesucht wird (etwa der Kapselradius, m)
const STEP_PROBE: float = 0.45

@export_group("Quake-Luftbewegung & Strafe-Jumping")
## Beschleunigungsfaktor in der Luft bei seitlicher Eingabe (Strafe-Jump-Mechanik)
@export var air_accel: float = 10.0
## Quake-Wunschgeschwindigkeit fuer die Luftprojektion (niedriger Wert erlaubt Strafe-Beschleunigung)
@export var air_wish_speed: float = 2.5
## Maximale horizontale Geschwindigkeit durch Strafe-Jumping
@export var air_max_speed: float = 28.0
## Zusaetzliche CPM-Luftlenkung (geschmeidige Kurven in der Luft)
@export var air_control: float = 0.35

@export_group("Sprung und Schwerkraft")
## Aufwaertsimpuls beim Sprung (m/s)
@export var jump_velocity: float = 7.5
## Erhoehte Schwerkraft fuer schnelles, praezises Quake-Gefuehl (m/s²)
@export var gravity: float = 22.0
## Zeitfenster, um einen Sprung kurz vor der Landung zu puffern (s)
@export var jump_buffer_time: float = 0.15
## Maximale Spruenge (2 = Doppelsprung im UT-Stil)
@export var max_jumps: int = 2
## Aufwaertsimpuls fuer den Doppelsprung (m/s)
@export var double_jump_velocity: float = 8.0

@export_group("Dodge (Unreal Tournament)")
## Richtungstaste zweimal innerhalb dieser Zeit = Dodge
@export var double_tap_time: float = 0.25
## Tempo und Hoehe des Dodge-Sprungs am Boden (m/s)
@export var dodge_speed: float = 13.0
@export var dodge_up: float = 5.0
## Wall-Dodge: in der Luft von einer Wand abstossen (einmal pro Sprung)
@export var wall_dodge_speed: float = 12.0
@export var wall_dodge_up: float = 6.5
## Wie nah eine Wand hinter einem sein muss (m)
@export var wall_dodge_reach: float = 0.7
@export var dodge_cooldown: float = 0.35

const DODGE_DIRECTIONS := {
	"move_forward": Vector3(0, 0, -1), "move_backward": Vector3(0, 0, 1),
	"move_left": Vector3(-1, 0, 0), "move_right": Vector3(1, 0, 0),
}

## Rennt gerade (fuer Tacho und HUD)
var is_sprinting: bool = false
## Verbleibende Spruenge (Doppelsprung)
var jumps_remaining: int = 2
## Kurz nach einem Start (Jump-Pad, Dodge, Teleporter) keine Bodenbewegung, sonst bremst die Reibung
var launch_grace: float = 0.0
var jump_buffer_timer: float = 0.0
var _last_tap: Dictionary = {}
var _dodge_cooldown_left: float = 0.0
var _wall_dodge_used: bool = false
var _fall_speed: float = 0.0
var _was_on_floor: bool = true

@onready var body: CharacterBody3D = get_parent() as CharacterBody3D


## Ein Physik-Tick: Eingaben auswerten, Geschwindigkeit setzen, bewegen, Landung melden
func step(wish_dir: Vector3, jump_pressed: bool, jump_held: bool, sprint: bool, delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	if body.is_on_floor() and launch_grace <= 0.0:
		jumps_remaining = max_jumps
		_wall_dodge_used = false
	is_sprinting = sprint
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	launch_grace = maxf(launch_grace - delta, 0.0)
	var grounded := body.is_on_floor() and launch_grace <= 0.0
	if grounded and _is_ramp_sliding():
		_ramp_slide(wish_dir, jump_held, delta)
	elif grounded:
		_ground_move(wish_dir, jump_held, delta)
	else:
		_air_move(wish_dir, jump_pressed, delta)

	_fall_speed = minf(_fall_speed, body.velocity.y)
	var intended := body.velocity
	body.move_and_slide()
	if grounded and body.is_on_wall() and _try_step_up(Vector3(intended.x, 0.0, intended.z) * delta):
		# Tempo vor der Kante behalten (move_and_slide hat es an der Stufe abgebremst)
		body.velocity.x = intended.x
		body.velocity.z = intended.z
	_check_landing()


## Ohne Steuerung (tot, Countdown): nur Schwerkraft, waagrecht stehen bleiben
func step_idle(delta: float) -> void:
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	body.move_and_slide()


## Zweiter Tastendruck derselben Richtung kurz nach dem ersten loest den Dodge aus
func handle_direction_tap(action: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_tap.get(action, -10.0) <= double_tap_time and try_dodge(action):
		_last_tap[action] = -10.0
	else:
		_last_tap[action] = now


## Dodge in Richtung der Taste: am Boden ein flacher, schneller Sprung, in der Luft nur als
## Wall-Dodge (eine Wand muss direkt hinter einem sein). True bei Erfolg.
func try_dodge(action: String) -> bool:
	if _dodge_cooldown_left > 0.0:
		return false
	var local: Vector3 = DODGE_DIRECTIONS[action]
	var dir: Vector3 = body.global_transform.basis * local
	dir.y = 0.0
	dir = dir.normalized()
	var wall := false
	if body.is_on_floor():
		body.velocity.x = dir.x * dodge_speed
		body.velocity.z = dir.z * dodge_speed
		body.velocity.y = dodge_up
		# Nach dem Dodge ist noch ein Luftsprung moeglich (Dodge-Jump wie in UT2004)
		jumps_remaining = max_jumps - 1
	elif not _wall_dodge_used and body.test_move(body.global_transform, -dir * wall_dodge_reach):
		body.velocity.x = dir.x * wall_dodge_speed
		body.velocity.z = dir.z * wall_dodge_speed
		body.velocity.y = maxf(body.velocity.y, wall_dodge_up)
		_wall_dodge_used = true
		wall = true
	else:
		return false
	launch_grace = 0.12
	_dodge_cooldown_left = dodge_cooldown
	dodged.emit(local, wall)
	return true


## Jump-Pad: Geschwindigkeit komplett ersetzen
func launch(launch_velocity: Vector3) -> void:
	body.velocity = launch_velocity
	launch_grace = 0.15
	jumps_remaining = max_jumps - 1


## Fallschaden wie in Quake: ab 12 m Fallhoehe 5, ab 20 m 10, darueber mehr (Jump-Pads und
## normale Rocket-Jumps bleiben darunter)
func fall_damage_for(fall_speed: float) -> float:
	var height: float = fall_speed * fall_speed / (2.0 * gravity)
	if height < 12.0:
		return 0.0
	if height < 20.0:
		return 5.0
	return 10.0 + floorf(height - 20.0)


## Zustand wie beim Spawn (keine laufenden Dodge-/Sprung-Timer)
func reset() -> void:
	jumps_remaining = max_jumps
	launch_grace = 0.0
	jump_buffer_timer = 0.0
	_dodge_cooldown_left = 0.0
	_wall_dodge_used = false
	_fall_speed = 0.0
	_last_tap.clear()


func _check_landing() -> void:
	var on_floor := body.is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(_fall_speed)
	if on_floor:
		_fall_speed = 0.0
	_was_on_floor = on_floor


## Stufe hochsteigen: hoch, vor, wieder runter auf begehbaren Boden. False, wenn es keine Stufe ist
## (Wand hoeher als step_height, Decke darueber oder zu steiler Untergrund oben)
func _try_step_up(motion: Vector3) -> bool:
	if motion.length_squared() < 0.000001 or absf(body.get_wall_normal().y) > 0.1:
		return false
	# Mindestens ein paar Zentimeter vor, sonst reicht der Schritt bei langsamem Gehen nicht auf die Stufe
	motion = motion.normalized() * maxf(motion.length(), 0.05)
	var t := body.global_transform
	var up := Vector3.UP * step_height
	if body.test_move(t, up):
		return false
	t.origin += up
	if body.test_move(t, motion):
		return false
	# Boden oben eine Kapselbreite weiter vorn pruefen: direkt an der Kante trifft die Rundung nur die Ecke
	var hit := KinematicCollision3D.new()
	if not body.test_move(t.translated(motion.normalized() * STEP_PROBE), -up, hit) or hit.get_normal().angle_to(Vector3.UP) > body.floor_max_angle:
		return false
	# Nur so weit absenken, wie es an der echten Position geht (dort kann die Ecke frueher bremsen)
	t.origin += motion
	var drop := hit.get_travel()
	var corner := KinematicCollision3D.new()
	body.global_position = t.origin + (corner.get_travel() if body.test_move(t, drop, corner) else drop)
	return true


## Schnell auf schraegem Boden? Dann gleitet man wie in der Luft (keine Reibung), Schwerkraft zieht hangab
func _is_ramp_sliding() -> bool:
	return body.get_floor_normal().y < 0.985 and Vector2(body.velocity.x, body.velocity.z).length() > ramp_slide_speed


## Rampen-Sliding: Luftbewegung ohne Doppelsprung. Ein Sprung behaelt den Schwung nach oben (Ramp-Jump)
func _ramp_slide(wish_dir: Vector3, jump_held: bool, delta: float) -> void:
	if jump_buffer_timer > 0.0 or jump_held:
		body.velocity.y = maxf(body.velocity.y, 0.0) + jump_velocity
		jump_buffer_timer = 0.0
		jumps_remaining = max_jumps - 1
		jumped.emit()
		return
	_air_move(wish_dir, false, delta)
	# move_and_slide liefert am Boden nur waagrechtes Tempo: auf die Rampenebene legen und
	# Hangabtrieb dazu (hangab schneller, hangauf langsamer)
	var n := body.get_floor_normal()
	var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
	body.velocity = flat + Vector3.UP * (-flat.dot(n) / n.y) + (Vector3.DOWN * gravity * delta).slide(n)


## Boden: Bunnyhop (Sprung ohne Reibung), sonst Reibung und Quake-Bodenbeschleunigung
func _ground_move(wish_dir: Vector3, jump_held: bool, delta: float) -> void:
	if jump_buffer_timer > 0.0 or jump_held:
		body.velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		jumps_remaining = max_jumps - 1
		jumped.emit()
		# Vor dem Sprung KEINE Bodenreibung, damit das Tempo erhalten bleibt
		return
	_apply_friction(delta)
	var target_max_speed: float = sprint_speed if is_sprinting else walk_speed
	if wish_dir.length_squared() > 0.001:
		var add_speed: float = target_max_speed - body.velocity.dot(wish_dir)
		if add_speed > 0.0:
			var accel_speed: float = minf(ground_accel * delta * target_max_speed, add_speed)
			body.velocity.x += wish_dir.x * accel_speed
			body.velocity.z += wish_dir.z * accel_speed


func _apply_friction(delta: float) -> void:
	var current_speed: float = Vector2(body.velocity.x, body.velocity.z).length()
	if current_speed < 0.0001:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		return
	var factor: float = maxf(current_speed - current_speed * ground_friction * delta, 0.0) / current_speed
	body.velocity.x *= factor
	body.velocity.z *= factor


## Luft: Schwerkraft, Doppelsprung, Strafe-Jump-Beschleunigung, CPM-Luftkontrolle, Tempo-Grenze
func _air_move(wish_dir: Vector3, jump_pressed: bool, delta: float) -> void:
	body.velocity.y -= gravity * delta

	if jump_pressed and jumps_remaining > 0:
		jumps_remaining -= 1
		body.velocity.y = double_jump_velocity
		# Knackiger Richtungswechsel beim Doppelsprung
		if wish_dir.length_squared() > 0.001:
			var target_h_speed := maxf(Vector2(body.velocity.x, body.velocity.z).length(), walk_speed * 1.15)
			body.velocity.x = wish_dir.x * target_h_speed
			body.velocity.z = wish_dir.z * target_h_speed
		double_jumped.emit()

	# Strafe-Jumping: wish_dir steht fast senkrecht zur Geschwindigkeit, die Projektion ist klein,
	# add_speed bleibt hoch und das Gesamttempo steigt
	if wish_dir.length_squared() > 0.001:
		var add_speed: float = air_wish_speed - body.velocity.dot(wish_dir)
		if add_speed > 0.0:
			var accel_speed: float = minf(air_accel * delta * air_wish_speed, add_speed)
			body.velocity.x += wish_dir.x * accel_speed
			body.velocity.z += wish_dir.z * accel_speed
		if air_control > 0.0:
			_apply_air_control(wish_dir, delta)

	var horizontal := Vector2(body.velocity.x, body.velocity.z)
	if horizontal.length() > air_max_speed:
		horizontal = horizontal.normalized() * air_max_speed
		body.velocity.x = horizontal.x
		body.velocity.z = horizontal.y


## Quake 3 CPM Air Control: Schwung in engen Kurven praezise umlenken (nur bei Vorwaerts-Eingabe)
func _apply_air_control(wish_dir: Vector3, delta: float) -> void:
	var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed: float = horizontal.length()
	if speed < 0.1:
		return
	var original_dir: Vector3 = horizontal / speed
	var dot: float = original_dir.dot(wish_dir)
	if dot > 0.0:
		var k: float = air_control * dot * dot * delta * 32.0
		var new_dir: Vector3 = (original_dir * speed + wish_dir * k).normalized()
		body.velocity.x = new_dir.x * speed
		body.velocity.z = new_dir.z * speed
