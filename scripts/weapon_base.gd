extends Node3D
class_name WeaponBase

## Basisklasse fuer alle Waffen im Spiel
## Regelt Munition, Abklingzeit, Schuss-Verhalten, Rueckstoss und Audio.
## Die Werte der einzelnen Waffen stehen in deren .tscn und sind im Inspector einstellbar.

signal fired()
signal ammo_changed(current: int, max_val: int)

@export_group("Waffen-Eigenschaften")
@export var weapon_name: String = "Waffe"
@export var damage: float = 25.0
@export var cooldown: float = 0.2 # Zeit in Sekunden zwischen zwei Schuesssen
@export var max_ammo: int = 100
@export var current_ammo: int = 50
@export var recoil_distance: float = 0.08 # Optischer Rueckstoss des Waffenmodells (m)
@export var recoil_recovery_speed: float = 12.0 # Wie schnell die Waffe nach dem Rueckstoss zurueckkehrt

# Knoten-Referenzen
@onready var muzzle: Node3D = $Muzzle
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Interner Zustand
var cooldown_timer: float = 0.0
var initial_position: Vector3 = Vector3.ZERO
var current_recoil: float = 0.0


func _ready() -> void:
	initial_position = position


func _process(delta: float) -> void:
	# Abklingzeit verringern (der Ueberhang unter 0 bleibt erhalten, siehe try_fire)
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	# Rueckstoss-Animation weich zurueckfedern
	if current_recoil > 0.0:
		current_recoil = max(current_recoil - delta * recoil_recovery_speed, 0.0)
		position = initial_position + Vector3(0.0, 0.0, current_recoil)


## Prueft, ob die Waffe feuerbereit ist
func can_fire() -> bool:
	return cooldown_timer <= 0.0 and current_ammo > 0


## Haupt-Schussfunktion, die vom Spieler aufgerufen wird
func try_fire(shooter: Node3D, camera: Camera3D) -> bool:
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
	
	# Munition abziehen und Abklingzeit setzen
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
func _on_fire(_shooter: Node3D, _camera: Camera3D) -> void:
	pass


## Waffe ausruesten
func equip() -> void:
	show()
	ammo_changed.emit(current_ammo, max_ammo)


## Waffe wegstecken
func unequip() -> void:
	hide()


## Munition auffuellen
func add_ammo(amount: int) -> void:
	current_ammo = clampi(current_ammo + amount, 0, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)
