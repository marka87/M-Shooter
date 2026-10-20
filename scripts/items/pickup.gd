extends Area3D
class_name ItemPickup

## Drehbares, schwebendes Item-Pickup fuer Munition, Leben oder Ruestung
## Wird beim Beruehren aufgesammelt und respawnt automatisch nach einigen Sekunden.

enum PickupType { ALL_AMMO, MG_AMMO, ROCKET_AMMO, RAIL_AMMO, HEALTH, ARMOR }

@export var pickup_type: PickupType = PickupType.ALL_AMMO
@export var respawn_time: float = 8.0

# Mengen
@export var mg_ammo_amount: int = 60
@export var rocket_ammo_amount: int = 6
@export var rail_ammo_amount: int = 5
@export var health_amount: float = 35.0
@export var armor_amount: float = 50.0

@onready var visual_mesh: Node3D = $VisualMesh
@onready var light: OmniLight3D = $OmniLight3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var initial_y: float = 0.0
var anim_time: float = 0.0
var is_active: bool = true


func _ready() -> void:
	initial_y = position.y
	
	# Pickup-Audio vorbereiten
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
	audio_player.stream = SoundGenerator.create_pickup_sound()
	
	# Signal verbinden
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Schwebende Drehung und Wippen (Quake-Stil)
	anim_time += delta
	if visual_mesh:
		visual_mesh.rotate_y(delta * 2.2)
		visual_mesh.position.y = sin(anim_time * 3.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	
	if not body.is_in_group("player"):
		return
	
	var picked_up: bool = false
	
	# Munition oder Leben auf den Spieler anwenden
	match pickup_type:
		PickupType.ALL_AMMO:
			if body.has_method("add_all_ammo"):
				body.add_all_ammo(mg_ammo_amount, rocket_ammo_amount, rail_ammo_amount)
				picked_up = true
		PickupType.MG_AMMO:
			if body.has_method("add_ammo_by_index"):
				body.add_ammo_by_index(0, mg_ammo_amount)
				picked_up = true
		PickupType.ROCKET_AMMO:
			if body.has_method("add_ammo_by_index"):
				body.add_ammo_by_index(1, rocket_ammo_amount)
				picked_up = true
		PickupType.RAIL_AMMO:
			if body.has_method("add_ammo_by_index"):
				body.add_ammo_by_index(2, rail_ammo_amount)
				picked_up = true
		PickupType.HEALTH:
			if body.has_method("add_health"):
				picked_up = body.add_health(health_amount)
		PickupType.ARMOR:
			if body.has_method("add_armor"):
				picked_up = body.add_armor(armor_amount)
	
	if picked_up:
		_collect()


func _collect() -> void:
	is_active = false
	if audio_player:
		audio_player.pitch_scale = randf_range(0.98, 1.05)
		audio_player.play()
	
	if visual_mesh:
		visual_mesh.visible = false
	if light:
		light.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Nach Ablauf der Respawn-Zeit wieder anzeigen
	get_tree().create_timer(respawn_time, false).timeout.connect(_respawn)


func _respawn() -> void:
	is_active = true
	if visual_mesh:
		visual_mesh.visible = true
	if light:
		light.visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
