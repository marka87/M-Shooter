extends Node
class_name HealthComponent

## Lebenspunkte und Ruestung fuer Spieler und Bots.
## Der Besitzer leitet take_damage(info) hierher weiter und reagiert auf die Signale.

## Leben oder Ruestung haben sich geaendert (fuer HUD und Namensschilder)
signal changed(health: float, armor: float)
## Treffer eingesteckt (health_lost = tatsaechlicher Lebensverlust nach Ruestung)
signal damaged(info: DamageInfo, health_lost: float)
## Leben auf 0 gefallen
signal died(info: DamageInfo)

@export var max_health: float = 100.0
@export var max_armor: float = 100.0
## Ruestung beim Start und nach jedem Respawn
@export var start_armor: float = 0.0
## Anteil des Schadens, den die Ruestung abfaengt (Quake: 66 %)
@export_range(0.0, 1.0) var armor_absorption: float = 0.66

var health: float = 0.0
var armor: float = 0.0
var is_dead: bool = false
## Letzter Treffer (z. B. um den Killer zu bestimmen)
var last_damage: DamageInfo = null


func _ready() -> void:
	reset()


## Volle Lebenspunkte, Start-Ruestung, lebendig
func reset() -> void:
	health = max_health
	armor = start_armor
	is_dead = false
	last_damage = null
	changed.emit(health, armor)


func apply_damage(info: DamageInfo) -> void:
	if is_dead:
		return
	last_damage = info
	var absorbed: float = minf(armor, info.amount * armor_absorption)
	var health_lost: float = minf(info.amount - absorbed, health)
	armor -= absorbed
	health -= health_lost
	damaged.emit(info, health_lost)
	changed.emit(health, armor)
	if health <= 0.0:
		health = 0.0
		is_dead = true
		died.emit(info)


## Heilt bis max_health. False, wenn schon voll oder tot.
func heal(amount: float) -> bool:
	if is_dead or health >= max_health:
		return false
	health = minf(health + amount, max_health)
	changed.emit(health, armor)
	return true


## Ruestung bis max_armor. False, wenn schon voll oder tot.
func add_armor(amount: float) -> bool:
	if is_dead or armor >= max_armor:
		return false
	armor = minf(armor + amount, max_armor)
	changed.emit(health, armor)
	return true
