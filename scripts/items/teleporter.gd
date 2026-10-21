extends Area3D
class_name Teleporter

## Quake-Teleporter: Wer hineinlaeuft, erscheint am Ziel, schaut in die Richtung des Ziel-Markers
## und laeuft mit festem Tempo heraus. Steht dort schon jemand, wird er "telefragged".
## Ein NavigationLink3D laesst Bots den Teleporter als Abkuerzung nutzen.

const IMPACT_SCENE: PackedScene = preload("res://scenes/effects/energy_impact.tscn")

## Ziel (Marker3D); seine -Z-Richtung ist die Blickrichtung beim Herauskommen
@export var target: Node3D
## Tempo beim Verlassen des Ziels (m/s)
@export var exit_speed: float = 8.0
@export var color: Color = Color(0.3, 1.0, 0.85)

@onready var nav_link: NavigationLink3D = $NavigationLink3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var swirl: Node3D = $Swirl

# Kurze Sperre je Koerper, damit niemand zweimal hintereinander teleportiert wird
var _cooldowns: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	audio_player.stream = SoundGenerator.create_teleport_sound()
	if target and nav_link:
		nav_link.start_position = Vector3.ZERO
		nav_link.end_position = nav_link.to_local(target.global_position)


func _process(delta: float) -> void:
	swirl.rotate_y(delta * 2.5)


func _on_body_entered(body: Node3D) -> void:
	if not target or not body is CharacterBody3D:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _cooldowns.get(body, 0.0):
		return
	_cooldowns[body] = now + 0.6
	teleport(body as CharacterBody3D)


func teleport(body: CharacterBody3D) -> void:
	var exit_pos: Vector3 = target.global_position
	var forward: Vector3 = -target.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	_telefrag(body, exit_pos)
	_flash(body.global_position)

	body.global_position = exit_pos
	body.reset_physics_interpolation()
	# Blickrichtung des Ziels uebernehmen (nur Drehung um die Hochachse)
	body.look_at(exit_pos + forward, Vector3.UP)
	body.velocity = forward * exit_speed
	if body.has_method("on_teleported"):
		body.on_teleported()

	_flash(exit_pos)
	audio_player.global_position = global_position
	audio_player.play()
	# Ein zweiter Klang am Ziel, damit man das Auftauchen dort hoert
	var exit_audio := AudioStreamPlayer3D.new()
	exit_audio.stream = audio_player.stream
	exit_audio.max_distance = 40.0
	get_parent().add_child(exit_audio)
	exit_audio.global_position = exit_pos
	exit_audio.play()
	exit_audio.finished.connect(exit_audio.queue_free)


## Wer am Ziel steht, stirbt (Quake: Telefrag). Der Teleportierende bekommt den Frag.
func _telefrag(body: Node3D, exit_pos: Vector3) -> void:
	for group in ["player", "enemies"]:
		for other in get_tree().get_nodes_in_group(group):
			if other == body or not other.has_method("take_damage") or other.get("health") == null:
				continue
			if other.health.is_dead:
				continue
			var flat := Vector2(other.global_position.x - exit_pos.x, other.global_position.z - exit_pos.z)
			if flat.length() < 1.1 and absf(other.global_position.y - exit_pos.y) < 2.0:
				other.take_damage(DamageInfo.create(10000.0, body, other.global_position, Vector3.UP, "Telefrag"))


func _flash(pos: Vector3) -> void:
	var impact := IMPACT_SCENE.instantiate()
	get_parent().add_child(impact)
	impact.global_position = pos + Vector3(0, 1.0, 0)
	impact.setup(color, Vector3.UP, 3.0)
