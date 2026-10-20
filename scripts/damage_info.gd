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
## Richtung fuer den Rueckstoss. Vector3.ZERO = kein zusaetzlicher Rueckstoss
var direction: Vector3 = Vector3.ZERO
## Name der Waffe (fuer Killfeed und Statistik)
var weapon_name: String = ""
## Flaechenschaden einer Explosion statt direkter Treffer
var is_splash: bool = false


static func create(p_amount: float, p_attacker: Node, p_position: Vector3, p_direction: Vector3, p_weapon_name: String = "", p_is_splash: bool = false) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.attacker = p_attacker
	info.position = p_position
	info.direction = p_direction
	info.weapon_name = p_weapon_name
	info.is_splash = p_is_splash
	return info
