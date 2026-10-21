extends Node3D
class_name BotArsenal

## Waffen eines Bots: dieselben Waffenszenen wie beim Spieler (Munition, Abklingzeit, Projektile,
## Sounds), sichtbar in der rechten Hand. Pickups sprechen den Bot ueber dieselben Methoden an wie
## den WeaponManager des Spielers (give_weapon, add_ammo, add_ammo_box, get_weapon).

const WEAPON_SCENES: Array[PackedScene] = [
	preload("res://scenes/weapons/machine_gun.tscn"),
	preload("res://scenes/weapons/shotgun.tscn"),
	preload("res://scenes/weapons/plasma_gun.tscn"),
	preload("res://scenes/weapons/rocket_launcher.tscn"),
	preload("res://scenes/weapons/lightning_gun.tscn"),
	preload("res://scenes/weapons/railgun.tscn"),
	preload("res://scenes/weapons/shock_rifle.tscn"),
]
## Einsatzbereich je Waffe: [min. Entfernung, max. Entfernung, Vorrang]
const RANGES := {
	&"shotgun": [0.0, 9.0, 6],
	&"railgun": [18.0, 999.0, 6],
	&"rocket_launcher": [4.5, 25.0, 5],
	&"lightning": [0.0, 22.0, 5],
	&"shock_rifle": [6.0, 60.0, 4],
	&"plasma": [3.0, 30.0, 3],
	&"machine_gun": [0.0, 999.0, 1],
}
## Projektil-Tempo fuer den Vorhalt (m/s), fehlt = Hitscan
const PROJECTILE_SPEED := { &"rocket_launcher": 38.0, &"plasma": 42.0 }

var weapons: Array[WeaponBase] = []
var current: WeaponBase
## Mindestzeit (s) zwischen zwei Waffenwechseln nach Entfernung, damit Bots nicht wie ein PC hin- und herschalten
var switch_hold: float = 0.0
var _next_switch_msec: int = 0


func _ready() -> void:
	for scene in WEAPON_SCENES:
		var weapon: WeaponBase = scene.instantiate()
		add_child(weapon)
		weapon.unequip()
		weapons.append(weapon)
	reset_loadout()


## Beste Waffe fuer diese Entfernung (mit Munition) in die Hand nehmen und zurueckgeben
func choose_for(distance: float) -> WeaponBase:
	var best: WeaponBase = null
	var best_rank: int = -1
	for weapon in weapons:
		var r: Array = RANGES.get(weapon.weapon_id, [0.0, 999.0, 0])
		if weapon.owned and weapon.current_ammo > 0 and distance >= r[0] and distance <= r[1] and r[2] > best_rank:
			best = weapon
			best_rank = r[2]
	if best == null:
		best = _first_with_ammo()
	var now := Time.get_ticks_msec()
	if best != current and (current.current_ammo <= 0 or now >= _next_switch_msec):
		_equip(best)
		_next_switch_msec = now + int(switch_hold * 1000.0)
	return current


func reset_loadout() -> void:
	for weapon in weapons:
		weapon.reset_loadout()
	_equip(_first_with_ammo())


func get_weapon(weapon_id: StringName) -> WeaponBase:
	for weapon in weapons:
		if weapon.weapon_id == weapon_id:
			return weapon
	return null


func give_weapon(weapon_id: StringName, ammo: int) -> bool:
	var weapon := get_weapon(weapon_id)
	if weapon == null:
		return false
	if not weapon.owned:
		weapon.owned = true
		weapon.add_ammo(ammo)
		return true
	return weapon.add_ammo(ammo)


func add_ammo(weapon_id: StringName, amount: int) -> bool:
	var weapon := get_weapon(weapon_id)
	return weapon != null and weapon.add_ammo(amount)


func add_ammo_box() -> bool:
	var any := false
	for weapon in weapons:
		if weapon.add_ammo(weapon.data.ammo_box_amount):
			any = true
	return any


## Lohnt sich eine Munitionskiste? (Waffen, die man hat, unter einem Drittel)
func needs_ammo() -> bool:
	for weapon in weapons:
		if weapon.owned and weapon.current_ammo * 3 < weapon.max_ammo:
			return true
	return false


func _first_with_ammo() -> WeaponBase:
	for weapon in weapons:
		if weapon.owned and weapon.current_ammo > 0:
			return weapon
	for weapon in weapons:
		if weapon.owned:
			return weapon
	return weapons[0]


func _equip(weapon: WeaponBase) -> void:
	if current:
		current.unequip()
	current = weapon
	current.equip()
