extends Node3D
class_name HitSpark

## Treffer-Funke mit Einschussloch (Decal) an Waenden und Boeden.
## Der Funke verlischt schnell, der Rand glueht kurz nach, das Loch bleibt einige Sekunden.
## Funken werden wiederverwendet (Pool): Abgelaufene werden nur versteckt, und bei mehr als
## MAX_DECALS Einschussloechern wird das aelteste an die neue Stelle gesetzt.

const SCENE: PackedScene = preload("res://scenes/weapons/hit_spark.tscn")

@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $Sparks
@onready var decal: Decal = $Decal

var lifetime: float = 0.35
## Wie lange das Einschussloch sichtbar bleibt (s)
const DECAL_SECONDS: float = 6.0
const MAX_DECALS: int = 60

## Alle Funken der aktuellen Szene, zuletzt benutzter hinten
static var _pool: Array[HitSpark] = []
## Schrot und Blitz erzeugen viele Funken pro Frame: hoechstens ein Einschlag-Sound alle 50 ms
static var _last_sound_msec: int = -1000

var _light_energy: float
var _decal_emission: float
var _tween: Tween
var _audio: AudioStreamPlayer3D


## Funke mit Einschussloch an hit_pos, ausgerichtet an der Oberflaechennormale
static func spawn(parent: Node, hit_pos: Vector3, normal: Vector3) -> void:
	_pool = _pool.filter(func(s): return is_instance_valid(s))
	var spark: HitSpark
	# Der vorderste ist der aelteste: abgelaufen (versteckt) oder bei vollem Pool das aelteste Loch
	if not _pool.is_empty() and (not _pool[0].visible or _pool.size() >= MAX_DECALS):
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
	_decal_emission = decal.emission_energy
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = SoundGenerator.create_impact_sound()
	_audio.volume_db = -8.0
	_audio.max_distance = 40.0
	add_child(_audio)


func _start() -> void:
	visible = true
	light.light_energy = _light_energy
	decal.emission_energy = _decal_emission
	decal.modulate.a = 1.0
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
	# Glut am Rand des Lochs kuehlt ab, das Loch selbst bleibt
	_tween.parallel().tween_property(decal, "emission_energy", 0.0, 2.5).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(DECAL_SECONDS)
	_tween.tween_property(decal, "modulate:a", 0.0, 1.0)
	_tween.tween_callback(hide)
