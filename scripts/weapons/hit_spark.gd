extends Node3D
class_name HitSpark

## Treffer-Funke mit Licht und Einschlag-Sound; das Einschussloch setzt BulletHole.
## Funken werden wiederverwendet (Pool): Abgelaufene werden nur versteckt, und bei mehr als
## MAX_SPARKS gleichzeitig wird der aelteste an die neue Stelle gesetzt.

const SCENE: PackedScene = preload("res://scenes/weapons/hit_spark.tscn")

@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $Sparks

var lifetime: float = 0.35
const MAX_SPARKS: int = 24

## Alle Funken der aktuellen Szene, zuletzt benutzter hinten
static var _pool: Array[HitSpark] = []
## Schrot und Blitz erzeugen viele Funken pro Frame: hoechstens ein Einschlag-Sound alle 50 ms
static var _last_sound_msec: int = -1000

var _light_energy: float
var _tween: Tween
var _audio: AudioStreamPlayer3D


## Funke mit Einschussloch an hit_pos, ausgerichtet an der Oberflaechennormale.
## hole_size: Groesse des Lochs (1 = MG, 0 = keins), glow: Hitze seines Randes
static func spawn(parent: Node, hit_pos: Vector3, normal: Vector3, hole_size: float = 1.0, glow: float = 1.0) -> void:
	BulletHole.spawn(parent, hit_pos, normal, hole_size, glow)
	_pool = _pool.filter(func(s): return is_instance_valid(s))
	var spark: HitSpark
	# Der vorderste ist der aelteste: abgelaufen (versteckt) oder bei vollem Pool der aelteste
	if not _pool.is_empty() and (not _pool[0].visible or _pool.size() >= MAX_SPARKS):
		spark = _pool.pop_front()
		if spark.get_parent() != parent:
			spark.reparent(parent, false)
	else:
		spark = SCENE.instantiate()
		parent.add_child(spark)
	_pool.append(spark)
	spark.global_position = hit_pos + normal * 0.05
	if normal.length_squared() > 0.001:
		spark.look_at(spark.global_position + normal, Vector3.UP if absf(normal.y) < 0.98 else Vector3.FORWARD)
	spark._start()


func _ready() -> void:
	_light_energy = light.light_energy
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = SoundGenerator.create_impact_sound()
	_audio.volume_db = -8.0
	_audio.max_distance = 40.0
	add_child(_audio)


func _start() -> void:
	visible = true
	light.light_energy = _light_energy
	particles.restart()
	particles.emitting = true
	var now := Time.get_ticks_msec()
	if now - _last_sound_msec >= 50:
		_last_sound_msec = now
		_audio.pitch_scale = randf_range(0.85, 1.15)
		_audio.play()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(light, "light_energy", 0.0, lifetime)
	_tween.tween_interval(maxf(particles.lifetime - lifetime, 0.0))
	_tween.tween_callback(hide)
