extends Area3D
class_name ItemPickup

## Drehbares, schwebendes Item-Pickup fuer Munition, Leben oder Ruestung
## Wird beim Beruehren aufgesammelt und respawnt automatisch nach einigen Sekunden.

enum PickupType { AMMO_BOX, WEAPON_AMMO, HEALTH, ARMOR }

@export var pickup_type: PickupType = PickupType.AMMO_BOX
@export var respawn_time: float = 8.0

@export_group("Mengen")
## Munitionskiste: Mengen stehen in der WeaponData jeder Waffe (ammo_box_amount)
## Nur fuer WEAPON_AMMO: Waffe (WeaponData.id) und Menge
@export var weapon_id: StringName = &""
@export var weapon_ammo_amount: int = 10
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
	
	# Nur einsammeln, wenn es dem Spieler etwas bringt (volle Werte lassen das Item liegen)
	var picked_up: bool = false
	match pickup_type:
		PickupType.AMMO_BOX:
			picked_up = body.weapon_manager.add_ammo_box()
		PickupType.WEAPON_AMMO:
			picked_up = body.weapon_manager.add_ammo(weapon_id, weapon_ammo_amount)
		PickupType.HEALTH:
			picked_up = body.health.heal(health_amount)
		PickupType.ARMOR:
			picked_up = body.health.add_armor(armor_amount)
	
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
