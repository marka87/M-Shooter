extends Area3D
class_name ItemPickup

## Drehbares, schwebendes Item-Pickup fuer Munition, Leben, Ruestung und Power-ups.
## Wird beim Beruehren aufgesammelt und respawnt automatisch nach einigen Sekunden.
## Spieler und Bots sammeln alles (Bots haben ein BotArsenal als weapon_manager).

enum PickupType { AMMO_BOX, WEAPON_AMMO, HEALTH, ARMOR, QUAD_DAMAGE, MEGA_HEALTH, WEAPON }

@export var pickup_type: PickupType = PickupType.AMMO_BOX
@export var respawn_time: float = 8.0

@export_group("Mengen")
## Munitionskiste: Mengen stehen in der WeaponData jeder Waffe (ammo_box_amount)
## Nur fuer WEAPON_AMMO: Waffe (WeaponData.id) und Menge
@export var weapon_id: StringName = &""
@export var weapon_ammo_amount: int = 10
@export var health_amount: float = 35.0
@export var armor_amount: float = 50.0
## Dauer von Quad Damage (s)
@export var quad_seconds: float = 30.0
## Mega Health: Heilung ueber das Maximum hinaus
@export var mega_amount: float = 100.0
## Nur fuer WEAPON: Waffenmodell, das ueber dem Sockel schwebt (Skripte werden entfernt)
@export var weapon_scene: PackedScene
## Anzeigename fuer die Ansage beim Einsammeln
@export var display_name: String = ""
## Beim Tod fallen gelassen (Quad mit Restzeit): laeuft liegend weiter ab, respawnt nicht
var dropped: bool = false

@onready var visual_mesh: Node3D = $VisualMesh
@onready var light: OmniLight3D = $OmniLight3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

const RIM_SHADER: Shader = preload("res://assets/shaders/rim_hologram.gdshader")

var initial_y: float = 0.0
# Leuchtender Rand in der Item-Farbe, beim Respawn kurz als Hologramm
var _rim: ShaderMaterial
var anim_time: float = 0.0
var is_active: bool = true
var _respawn_timer: SceneTreeTimer

## Grosse Items, deren Respawn-Zeit die Bots kennen (wie Spieler in Quake, die das Item-Timing lernen)
const TIMED_TYPES: Array[PickupType] = [PickupType.QUAD_DAMAGE, PickupType.MEGA_HEALTH, PickupType.ARMOR]
## So viele Sekunden vor dem Respawn laufen Bots schon zu einem grossen Item
const RESPAWN_LOOKAHEAD: float = 6.0


func _ready() -> void:
	# Instagib: keine Items in der Arena
	if GameManager.instagib:
		is_active = false
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	initial_y = position.y
	
	# Pickup-Audio vorbereiten
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
	match pickup_type:
		PickupType.WEAPON:
			audio_player.stream = SoundGenerator.create_weapon_pickup_sound()
		PickupType.QUAD_DAMAGE:
			audio_player.stream = SoundGenerator.create_quad_pickup_sound()
		PickupType.MEGA_HEALTH:
			audio_player.stream = SoundGenerator.create_mega_pickup_sound()
		_:
			audio_player.stream = SoundGenerator.create_pickup_sound()
	
	if pickup_type == PickupType.WEAPON and weapon_scene:
		_build_weapon_visual()
	_rim = ShaderMaterial.new()
	_rim.shader = RIM_SHADER
	_rim.set_shader_parameter("rim_color", light.light_color if light else Color(0.3, 0.9, 1.0))
	for mesh in visual_mesh.find_children("*", "GeometryInstance3D", true, false):
		mesh.material_overlay = _rim

	# Signal verbinden; Gruppe "pickups" nutzen die Bots zur Item-Suche
	body_entered.connect(_on_body_entered)
	add_to_group("pickups")


func _process(delta: float) -> void:
	if not is_active:
		return
	if dropped:
		quad_seconds -= delta
		if quad_seconds <= 0.0:
			queue_free()
	
	# Schwebende Drehung und Wippen (Quake-Stil)
	anim_time += delta
	if visual_mesh:
		visual_mesh.rotate_y(delta * 2.2)
		visual_mesh.position.y = sin(anim_time * 3.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	# Im Netzspiel sammelt nur der Host ein und meldet es allen (Net._ev_pickup)
	if not is_active or Net.is_client():
		return
	
	if not (body.is_in_group("player") or body.is_in_group("enemies")):
		return
	if _apply_to(body):
		if body.has_method("on_item_picked"):
			body.on_item_picked(pickup_type, display_name)
		_collect()
		Net.on_picked(self, body)


## Client im Netzspiel: Der Host meldet, wer das Item bekommen hat
func net_pickup(body: Node3D) -> void:
	_apply_to(body)
	if body.has_method("on_item_picked"):
		body.on_item_picked(pickup_type, display_name)
	_collect()


## Wirkung auf den Kaempfer. Nur einsammeln, wenn es etwas bringt (volle Werte lassen das Item liegen).
func _apply_to(body: Node3D) -> bool:
	var has_weapons: bool = body.get("weapon_manager") != null
	var picked_up: bool = false
	match pickup_type:
		PickupType.AMMO_BOX:
			picked_up = has_weapons and body.weapon_manager.add_ammo_box()
		PickupType.WEAPON_AMMO:
			picked_up = has_weapons and body.weapon_manager.add_ammo(weapon_id, weapon_ammo_amount)
		PickupType.HEALTH:
			picked_up = body.health.heal(health_amount)
		PickupType.ARMOR:
			picked_up = body.health.add_armor(armor_amount)
		PickupType.QUAD_DAMAGE:
			var powerups := body.get_node_or_null("Powerups") as PowerupComponent
			if powerups and not body.health.is_dead:
				powerups.give_quad(quad_seconds)
				picked_up = true
		PickupType.MEGA_HEALTH:
			picked_up = body.health.mega_heal(mega_amount)
		PickupType.WEAPON:
			picked_up = has_weapons and body.weapon_manager.give_weapon(weapon_id, weapon_ammo_amount)
	return picked_up


## Waffenmodell als Anzeige: Szene instanziieren, Skripte entfernen (keine Waffenlogik),
## vergroessern und leicht schraeg stellen
func _build_weapon_visual() -> void:
	var model := weapon_scene.instantiate()
	_strip_scripts(model)
	model.scale = Vector3.ONE * 2.2
	model.rotation_degrees = Vector3(0, 90, -12)
	model.position = Vector3(0.0, 0.0, -0.5)
	visual_mesh.add_child(model)


func _strip_scripts(node: Node) -> void:
	# Das Modell-Skript richtet nur das Mesh aus und faerbt es ein, keine Waffenlogik
	if node is WeaponModel:
		return
	node.set_script(null)
	for child in node.get_children():
		if child is AudioStreamPlayer3D or child is Light3D:
			child.queue_free()
		else:
			_strip_scripts(child)


## Lohnt es sich fuer diesen Kaempfer, das Item zu holen? (fuer die Bot-Planung)
## Grosse Items gelten schon kurz vor dem Respawn als lohnend, damit Bots rechtzeitig dort sind.
func is_useful_for(body: Node) -> bool:
	if body.get("health") == null:
		return false
	if not is_active and not (pickup_type in TIMED_TYPES and seconds_until_respawn() <= RESPAWN_LOOKAHEAD):
		return false
	var arsenal = body.get("weapon_manager")
	match pickup_type:
		PickupType.HEALTH:
			return body.health.health < body.health.max_health
		PickupType.ARMOR:
			return body.health.armor < body.health.max_armor
		PickupType.QUAD_DAMAGE:
			return true
		PickupType.MEGA_HEALTH:
			return body.health.health < body.health.overheal_max
		PickupType.WEAPON:
			return arsenal != null and not arsenal.get_weapon(weapon_id).owned
		PickupType.AMMO_BOX:
			return arsenal != null and arsenal.has_method("needs_ammo") and arsenal.needs_ammo()
	return false


## Sekunden bis das Item wieder da ist (0 = liegt bereit)
func seconds_until_respawn() -> float:
	if is_active:
		return 0.0
	return _respawn_timer.time_left if _respawn_timer else INF


## Wie wertvoll ist das Item (fuer die Bot-Planung)? Power-ups am meisten.
func value_for(body: Node) -> float:
	match pickup_type:
		PickupType.QUAD_DAMAGE:
			return 100.0
		PickupType.MEGA_HEALTH:
			return 80.0
		PickupType.HEALTH:
			return 60.0 * (1.0 - body.health.health / body.health.max_health) + 10.0
		PickupType.ARMOR:
			return 40.0 * (1.0 - body.health.armor / body.health.max_armor) + 10.0
		PickupType.WEAPON:
			return 50.0
		PickupType.AMMO_BOX:
			return 25.0
	return 0.0


## silent: beim Beitritt zum Netzspiel (Item ist beim Host schon weg)
func _collect(silent: bool = false) -> void:
	is_active = false
	if audio_player and not silent:
		audio_player.pitch_scale = randf_range(0.98, 1.05)
		audio_player.play()
	
	if visual_mesh:
		visual_mesh.visible = false
	if light:
		light.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	if dropped:
		get_tree().create_timer(1.0).timeout.connect(queue_free)  # Sound ausklingen lassen
		return
	# Nach Ablauf der Respawn-Zeit wieder anzeigen (im Netzspiel meldet das der Host)
	if not Net.is_client():
		_respawn_timer = get_tree().create_timer(respawn_time, false)
		_respawn_timer.timeout.connect(_respawn)


func _respawn() -> void:
	is_active = true
	_respawn_timer = null
	Net.on_item_respawned(self)
	if visual_mesh:
		visual_mesh.visible = true
		# Hologramm-Respawn: Scanlines klingen ab, das Item ploppt auf
		visual_mesh.scale = Vector3.ONE * 0.4
		var tween := create_tween().set_parallel()
		tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(v: float): _rim.set_shader_parameter("hologram", v), 1.0, 0.0, 0.9)
	if light:
		light.visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
