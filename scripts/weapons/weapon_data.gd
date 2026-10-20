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
