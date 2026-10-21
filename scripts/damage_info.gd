extends RefCounted
class_name DamageInfo

## Beschreibt einen einzelnen Treffer. Wird an take_damage() uebergeben, damit Ziele,
## Killfeed, Ansager und spaeter LAN-Synchronisation dieselben Daten sehen.

## Schadensmenge vor Ruestungs-Abzug
var amount: float = 0.0
## Verursacher (Spieler oder Bot), null bei Umgebungsschaden
var attacker: Node = null
## Trefferpunkt in Weltkoordinaten (z. B. fuer Schadenszahlen)
var position: Vector3 = Vector3.ZERO
## Alias fuer position (verhindert Skript-Abbrueche bei Verwechslung)
var hit_position: Vector3:
	get:
		return position
	set(v):
		position = v
## Richtung fuer den Rueckstoss. Vector3.ZERO = kein zusaetzlicher Rueckstoss
var direction: Vector3 = Vector3.ZERO
## Name der Waffe (fuer Killfeed und Statistik)
var weapon_name: String = ""
## Flaechenschaden einer Explosion statt direkter Treffer
var is_splash: bool = false
## Kopftreffer (Railgun, Shock Rifle)
var is_headshot: bool = false

## Ab dieser Hoehe ueber den Fuessen zaehlt ein Treffer als Kopftreffer (Spieler und Bots sind 1,8 m gross)
const HEAD_HEIGHT: float = 1.5
## Schadens-Bonus bei Kopftreffern
const HEADSHOT_MULTIPLIER: float = 1.5


## Trifft ein Hitscan-Strahl bei hit_pos den Kopf eines Kaempfers?
static func is_head_hit(target: Object, hit_pos: Vector3) -> bool:
	return target is CharacterBody3D and hit_pos.y - (target as CharacterBody3D).global_position.y >= HEAD_HEIGHT


static func create(p_amount: float, p_attacker: Node, p_position: Vector3, p_direction: Vector3, p_weapon_name: String = "", p_is_splash: bool = false) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	# Power-ups des Angreifers (z. B. Quad Damage) verstaerken den Schaden, auch beim Selbsttreffer
	if is_instance_valid(p_attacker):
		var powerups := p_attacker.get_node_or_null("Powerups") as PowerupComponent
		if powerups:
			info.amount *= powerups.damage_multiplier
	info.attacker = p_attacker
	info.position = p_position
	info.direction = p_direction
	info.weapon_name = p_weapon_name
	info.is_splash = p_is_splash
	return info
