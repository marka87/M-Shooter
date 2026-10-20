extends Resource
class_name WeaponData

## Werte einer Waffe als Resource (.tres in res://resources/weapons/).
## Neue Waffen brauchen nur eine neue .tres-Datei und eine Szene mit WeaponBase-Skript.

## Eindeutige Kennung, z. B. fuer Munitions-Pickups (&"machine_gun")
@export var id: StringName = &""
@export var weapon_name: String = "Waffe"
@export var damage: float = 25.0
## Zeit in Sekunden zwischen zwei Schuessen
@export var cooldown: float = 0.2
@export var max_ammo: int = 100
@export var start_ammo: int = 50
## Munition aus einer allgemeinen Munitionskiste
@export var ammo_box_amount: int = 10
## Optischer Rueckstoss des Waffenmodells (m)
@export var recoil_distance: float = 0.08
## Hat man die Waffe von Anfang an (sonst erst nach dem Einsammeln, beim Respawn wieder weg)
@export var start_owned: bool = true
## Zeit zwischen zwei Alt-Schuessen (rechte Maustaste), 0 = kein Alt-Feuer
@export var alt_cooldown: float = 0.0
## Munitionsverbrauch pro Alt-Schuss
@export var alt_ammo_cost: int = 1
## Farbe fuer Pickup, Leuchtspuren und HUD
@export var color: Color = Color(1.0, 0.8, 0.3)
