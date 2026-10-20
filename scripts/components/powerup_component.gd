extends Node
class_name PowerupComponent

## Aktive Power-ups eines Kaempfers (Spieler oder Bot). Bisher: Quad Damage.
## Der Schaden wird in DamageInfo.create() mit damage_multiplier des Angreifers multipliziert.
## Waehrend Quad aktiv ist, leuchtet der Traeger violett (eigenes Licht am Besitzer).

signal quad_started()
signal quad_ended()

## Schadensfaktor waehrend Quad Damage (Quake 3: 3-fach)
@export var quad_multiplier: float = 3.0
@export var quad_glow_color: Color = Color(0.65, 0.3, 1.0)
## Leuchten am Traeger anzeigen (beim Spieler aus, sonst faerbt es die eigene Sicht lila)
@export var show_glow: bool = true

var quad_time_left: float = 0.0
var _glow: OmniLight3D = null

## Aktueller Schadensfaktor (1.0 ohne Power-up)
var damage_multiplier: float:
	get: return quad_multiplier if quad_time_left > 0.0 else 1.0

var has_quad: bool:
	get: return quad_time_left > 0.0


func _ready() -> void:
	# Violettes Licht am Besitzer, sichtbar fuer alle anderen
	_glow = OmniLight3D.new()
	_glow.light_color = quad_glow_color
	_glow.light_energy = 3.0
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 1.2, 0)
	_glow.visible = false
	get_parent().add_child.call_deferred(_glow)


func _process(delta: float) -> void:
	if quad_time_left <= 0.0:
		return
	quad_time_left -= delta
	# Pulsieren, in den letzten 3 Sekunden schneller (Warnung: laeuft ab)
	var speed := 14.0 if quad_time_left < 3.0 else 5.0
	_glow.light_energy = 2.2 + sin(Time.get_ticks_msec() / 1000.0 * speed) * 1.0
	if quad_time_left <= 0.0:
		clear()


## Quad Damage starten oder verlaengern
func give_quad(seconds: float) -> void:
	var was_active := has_quad
	quad_time_left = maxf(quad_time_left, 0.0) + seconds
	_glow.visible = show_glow
	if not was_active:
		quad_started.emit()


## Alle Power-ups sofort beenden (Tod, Respawn)
func clear() -> void:
	var was_active := quad_time_left > 0.0
	quad_time_left = 0.0
	if _glow:
		_glow.visible = false
	if was_active:
		quad_ended.emit()
