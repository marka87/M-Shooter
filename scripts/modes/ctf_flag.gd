extends Area3D
class_name CtfFlag

## Flagge eines Teams (Capture the Flag). Steht an der Basis, wird getragen oder liegt nach dem Tod
## des Traegers am Boden (nach RETURN_TIME automatisch zurueck). Beruehrungen meldet sie dem CtfManager.

enum FlagState { HOME, CARRIED, DROPPED }

## Liegt die Flagge so lange herum, kehrt sie von selbst zur Basis zurueck (s)
const RETURN_TIME: float = 20.0

var team: int = 0
var home: Vector3 = Vector3.ZERO
var state: FlagState = FlagState.HOME
var carrier: Node3D = null
var manager: CtfManager
var _return_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER | Layers.BOT
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 1.1
	shape.position.y = 1.0
	add_child(shape)
	_build_visual()
	global_position = home


func _physics_process(delta: float) -> void:
	match state:
		FlagState.CARRIED:
			if not is_instance_valid(carrier) or carrier.health.is_dead:
				drop()
				return
			global_position = carrier.global_position + Vector3(0, 1.2, 0)
		FlagState.DROPPED:
			_return_timer -= delta
			if _return_timer <= 0.0:
				return_home()
				manager.announce("Die Flagge von %s ist zurück" % GameManager.TEAM_NAMES[team], team)
				return
	# Ueberlappungen jedes Frame pruefen: body_entered verpasst, wer schon drinsteht (Spawn, Rueckkehr)
	for body in get_overlapping_bodies():
		manager.on_flag_touched(self, body)


func pick_up(body: Node3D) -> void:
	state = FlagState.CARRIED
	carrier = body


## Traeger tot: Flagge faellt an seiner Stelle auf den Boden. Kein Boden darunter (Abgrund) -> zurueck zur Basis.
func drop() -> void:
	var from: Vector3 = carrier.global_position + Vector3.UP if is_instance_valid(carrier) else global_position
	carrier = null
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return_home()
		return
	state = FlagState.DROPPED
	_return_timer = RETURN_TIME
	global_position = hit.position


func return_home() -> void:
	state = FlagState.HOME
	carrier = null
	global_position = home


## Stange mit leuchtendem Tuch und Licht in der Teamfarbe
func _build_visual() -> void:
	var color: Color = GameManager.TEAM_COLORS[team]
	var pole := MeshInstance3D.new()
	pole.mesh = CylinderMesh.new()
	pole.mesh.top_radius = 0.04
	pole.mesh.bottom_radius = 0.04
	pole.mesh.height = 2.2
	pole.position.y = 1.1
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.7, 0.72, 0.78)
	metal.metallic = 0.8
	pole.material_override = metal
	add_child(pole)
	var cloth := MeshInstance3D.new()
	cloth.mesh = BoxMesh.new()
	cloth.mesh.size = Vector3(0.9, 0.55, 0.04)
	cloth.position = Vector3(0.47, 1.9, 0)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 3.0
	cloth.material_override = glow
	add_child(cloth)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position.y = 1.8
	add_child(light)
