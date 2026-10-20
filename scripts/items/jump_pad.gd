extends Area3D
class_name JumpPad

## Quake-3-Sprungpad: schleudert Spieler und Bots in einem Bogen zu einem Zielpunkt.
## Die Startgeschwindigkeit wird aus Ziel, Scheitelhoehe und Schwerkraft der Figur berechnet,
## dadurch landet man unabhaengig vom Anlauf immer am Ziel.
## Ein NavigationLink3D sorgt dafuer, dass Bots das Pad als Weg zum Ziel nutzen.

## Landepunkt (Marker3D oder beliebiger Node3D)
@export var target: Node3D
## Wie hoch der Bogen ueber dem hoeheren von Start- und Zielpunkt liegt (m)
@export var apex_height: float = 4.0

@onready var nav_link: NavigationLink3D = $NavigationLink3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var glow: MeshInstance3D = $Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	audio_player.stream = SoundGenerator.create_jump_pad_sound()
	if target and nav_link:
		# Link-Positionen sind lokal zum Link-Knoten
		nav_link.start_position = Vector3.ZERO
		nav_link.end_position = nav_link.to_local(target.global_position)


func _on_body_entered(body: Node3D) -> void:
	if not target or not body is CharacterBody3D:
		return
	var gravity: float = body.get("gravity") if body.get("gravity") != null else 22.0
	var launch_velocity := calculate_launch_velocity(body.global_position, target.global_position, gravity)
	if body.has_method("launch"):
		body.launch(launch_velocity)
	else:
		(body as CharacterBody3D).velocity = launch_velocity

	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()
	_pulse()


## Startgeschwindigkeit fuer einen ballistischen Bogen von start nach end
func calculate_launch_velocity(start: Vector3, end: Vector3, gravity: float) -> Vector3:
	var apex_y: float = maxf(start.y, end.y) + apex_height
	var up_speed: float = sqrt(2.0 * gravity * (apex_y - start.y))
	var time_up: float = up_speed / gravity
	var time_down: float = sqrt(2.0 * (apex_y - end.y) / gravity)
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	var horizontal: Vector3 = flat / (time_up + time_down)
	return Vector3(horizontal.x, up_speed, horizontal.z)


## Kurzes Aufleuchten beim Ausloesen
func _pulse() -> void:
	glow.scale = Vector3.ONE * 1.4
	var tween := create_tween()
	tween.tween_property(glow, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
