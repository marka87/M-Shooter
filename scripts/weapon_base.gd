extends Node3D
class_name WeaponBase

## Basisklasse fuer alle Waffen im Spiel
## Regelt Munition, Abklingzeit, Schuss-Verhalten, Rueckstoss und Audio.
## Die Werte (Schaden, Feuerrate, Munition) kommen aus einer WeaponData-Resource.

signal fired()
signal ammo_changed(current: int, max_val: int)

@export_group("Waffen-Eigenschaften")
## Werte der Waffe (res://resources/weapons/*.tres)
@export var data: WeaponData
## Wie schnell die Waffe nach dem Rueckstoss zurueckkehrt
@export var recoil_recovery_speed: float = 12.0
## Dauer des Hochziehens beim Waffenwechsel (s, kurz wie in Quake 3); so lange feuert die Waffe nicht
const RAISE_TIME: float = 0.15

# Bequemer Zugriff auf die Resource-Werte
var weapon_id: StringName:
	get: return data.id
var weapon_name: String:
	get: return data.weapon_name
var damage: float:
	get: return data.damage
var cooldown: float:
	get: return data.cooldown
var max_ammo: int:
	get: return data.max_ammo
var recoil_distance: float:
	get: return data.recoil_distance

var current_ammo: int = 0
## Besitzt der Spieler die Waffe? (Waffen ohne start_owned muessen erst eingesammelt werden)
var owned: bool = true

# Knoten-Referenzen
@onready var muzzle: Node3D = $Muzzle
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Interner Zustand
var cooldown_timer: float = 0.0
var initial_position: Vector3 = Vector3.ZERO
var current_recoil: float = 0.0
var initial_rotation: Vector3 = Vector3.ZERO
# Fortschritt beim Hochziehen: 1 = ganz unten, 0 = in Position
var _raise: float = 0.0


func _ready() -> void:
	assert(data != null, "%s: WeaponData fehlt" % name)
	initial_position = position
	initial_rotation = rotation
	reset_loadout()


## Zustand wie beim Spawn: Besitz und Start-Munition laut WeaponData
func reset_loadout() -> void:
	owned = data.start_owned
	current_ammo = data.start_ammo
	if GameManager.instagib:
		owned = weapon_id == &"railgun"
		current_ammo = max_ammo
	cooldown_timer = 0.0


func _process(delta: float) -> void:
	# Abklingzeit verringern (der Ueberhang unter 0 bleibt erhalten, siehe try_fire)
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	# Rueckstoss weich zurueckfedern, beim Waffenwechsel von unten hochschwenken
	if current_recoil > 0.0 or _raise > 0.0:
		current_recoil = maxf(current_recoil - delta * recoil_recovery_speed, 0.0)
		_raise = maxf(_raise - delta / RAISE_TIME, 0.0)
		var drop: float = _raise * _raise
		position = initial_position + Vector3(0.0, -0.3 * drop, current_recoil)
		rotation = initial_rotation + Vector3(-0.7 * drop, 0.0, 0.0)


## Prueft, ob die Waffe feuerbereit ist
func can_fire() -> bool:
	return cooldown_timer <= 0.0 and current_ammo > 0


## Haupt-Schussfunktion. camera = Zielknoten: Schuss von dort entlang -Z (Spielerkamera oder Zielknoten des Bots)
func try_fire(shooter: Node3D, camera: Node3D) -> bool:
	if cooldown_timer > 0.0:
		return false
	
	# Wenn leer: Klick-Geraeusch abspielen
	if current_ammo <= 0:
		cooldown_timer = 0.25
		if audio_player:
			audio_player.stream = SoundGenerator.create_empty_click_sound()
			audio_player.pitch_scale = randf_range(0.95, 1.05)
			audio_player.play()
		return false
	
	# Munition abziehen (Instagib: unendlich) und Abklingzeit setzen
	if not GameManager.instagib:
		current_ammo -= 1
	# Addieren statt Setzen: Der Rest des letzten Frames wird mitgenommen,
	# so ist die Feuerrate unabhaengig von der Framerate (MG: 11 statt 10 Schuss/s bei 60 FPS)
	cooldown_timer += cooldown
	ammo_changed.emit(current_ammo, max_ammo)
	
	# Optischer Rueckstoss
	current_recoil = recoil_distance
	
	# Spezifische Schuss-Implementierung der Waffe ausfuehren
	_on_fire(shooter, camera)
	
	fired.emit()
	return true


## Virtuelle Methode: Wird von Maschinengewehr, Raketenwerfer etc. ueberschrieben
func _on_fire(_shooter: Node3D, _camera: Node3D) -> void:
	pass


## Alt-Feuer (rechte Maustaste). Nur Waffen mit alt_cooldown > 0 haben eins.
func try_fire_alt(shooter: Node3D, camera: Node3D) -> bool:
	if data.alt_cooldown <= 0.0 or cooldown_timer > 0.0:
		return false
	if current_ammo < data.alt_ammo_cost:
		return try_fire(shooter, camera)  # spielt den Leer-Klick
	current_ammo -= data.alt_ammo_cost
	cooldown_timer += data.alt_cooldown
	ammo_changed.emit(current_ammo, max_ammo)
	current_recoil = recoil_distance
	_on_fire_alt(shooter, camera)
	fired.emit()
	return true


## Virtuelle Methode fuer das Alt-Feuer
func _on_fire_alt(_shooter: Node3D, _camera: Node3D) -> void:
	pass


## Waffe ausruesten
func equip() -> void:
	show()
	_raise = 1.0
	cooldown_timer = maxf(cooldown_timer, RAISE_TIME)
	ammo_changed.emit(current_ammo, max_ammo)


## Waffe wegstecken
func unequip() -> void:
	hide()


## Munition auffuellen. Gibt false zurueck, wenn die Waffe schon voll war.
func add_ammo(amount: int) -> bool:
	if current_ammo >= max_ammo:
		return false
	current_ammo = clampi(current_ammo + amount, 0, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)
	return true
