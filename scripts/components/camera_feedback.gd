extends Node
class_name CameraFeedback

## Kamera-Feedback des Spielers: Einknicken beim Landen, Rucken bei Treffern und Rueckstoss,
## Wackeln bei nahen Explosionen (Trauma-System), Neigung beim Dodge und etwas weiteres
## Sichtfeld bei hohem Tempo. Abschaltbar ueber GameManager.camera_effects.
## Wirkt auf die lokale Position/Drehung der Kamera; der Blick (Kopf) bleibt unberuehrt.

## Groesster Zusatz zum Sichtfeld bei hohem Tempo (Grad)
@export var max_fov_bonus: float = 10.0
## Ab diesem Tempo waechst das Sichtfeld, bei speed_fov_full ist der volle Zusatz erreicht (m/s)
@export var speed_fov_start: float = 13.0
@export var speed_fov_full: float = 26.0
## Rechte Maustaste bei Waffen ohne Alt-Feuer: halber Zoom (doppelte Vergroesserung)
const ZOOM_MAGNIFY := 2.0

var player: Player
var camera: Camera3D
var base_fov: float = 100.0
## Zoom gerade gehalten (der Spieler verlangsamt dann die Maus)
var zoomed: bool = false

var _dip: float = 0.0          # Absenkung der Kamera nach der Landung (m)
var _punch: Vector3 = Vector3.ZERO  # Nicken/Gieren/Rollen durch Treffer und Rueckstoss (rad)
var _roll: float = 0.0          # Neigung beim Dodge (rad)
var _trauma: float = 0.0        # 0..1, Wackeln (quadratisch)
var _time: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	# Direkt ueber den Pfad: Diese Komponente startet vor dem Spieler, dessen @onready-Werte fehlen noch
	camera = player.get_node("Head/Camera3D") as Camera3D
	base_fov = GameManager.fov
	player.dodged.connect(_on_dodged)


## Landung: je schneller der Fall, desto staerker knickt die Kamera ein
func land(fall_speed: float) -> void:
	var strength: float = clampf((-fall_speed - 4.0) / 20.0, 0.0, 1.0)
	_dip = minf(_dip, -0.28 * strength)
	if fall_speed < -16.0:
		add_trauma(0.25)


## Treffer: Kamera ruckt nach oben und leicht zur Seite, staerker bei mehr Schaden
func hit(amount: float) -> void:
	var k: float = clampf(amount / 60.0, 0.15, 1.0)
	_punch += Vector3(0.05 * k, randf_range(-0.03, 0.03) * k, randf_range(-0.06, 0.06) * k)
	add_trauma(0.15 * k)


## Rueckstoss beim Schiessen (aus WeaponData.recoil_distance)
func recoil(amount: float) -> void:
	_punch.x += amount * 0.25


## Wackeln hinzufuegen (z. B. Explosion in der Naehe), wird automatisch abgebaut
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _on_dodged(local_dir: Vector3, _wall: bool) -> void:
	# Beim seitlichen Dodge kippt die Kamera kurz in die Sprungrichtung
	_roll = -local_dir.x * 0.09


func _process(delta: float) -> void:
	var weapon := player.weapon_manager.get_current_weapon()
	zoomed = Input.is_action_pressed("shoot_alt") and weapon != null and weapon.data.alt_cooldown <= 0.0 and not player.is_dead
	var zoom_fov: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) / 2.0) / ZOOM_MAGNIFY))
	if not GameManager.camera_effects:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.fov = zoom_fov if zoomed else base_fov
		return
	_time += delta

	# Alles federt mit der Zeit zurueck auf null
	_dip = lerpf(_dip, 0.0, 1.0 - exp(-9.0 * delta))
	_punch = _punch.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
	_roll = lerpf(_roll, 0.0, 1.0 - exp(-7.0 * delta))
	_trauma = maxf(_trauma - delta * 1.4, 0.0)

	# Wackeln: Staerke quadratisch zum Trauma, glatte Bewegung aus ueberlagerten Sinuswellen
	var shake: float = _trauma * _trauma
	var sx: float = sin(_time * 37.0) * 0.6 + sin(_time * 23.0 + 1.3) * 0.4
	var sy: float = sin(_time * 41.0 + 2.1) * 0.6 + sin(_time * 19.0 + 0.4) * 0.4
	var sr: float = sin(_time * 29.0 + 0.7)

	camera.position = Vector3(sx * 0.06 * shake, _dip + sy * 0.06 * shake, 0.0)
	camera.rotation = Vector3(_punch.x + sy * 0.03 * shake, _punch.y + sx * 0.02 * shake, _punch.z + _roll + sr * 0.04 * shake)

	# Sichtfeld waechst mit dem Tempo (Gefuehl von Geschwindigkeit beim Strafe-Jumping)
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var t: float = clampf((speed - speed_fov_start) / (speed_fov_full - speed_fov_start), 0.0, 1.0)
	var target_fov: float = zoom_fov if zoomed else base_fov + max_fov_bonus * t
	# Zoom rein und raus zuegig, das Tempo-Sichtfeld weich
	var rate: float = 14.0 if zoomed or camera.fov < base_fov - 0.5 else 6.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-rate * delta))
