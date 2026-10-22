extends Node3D
class_name ViewHands

## Ego-Hand (assets/characters/Arm/hand.glb) rechts am Griff der aktuellen Waffe, Werte pro Waffe
## aus dem ViewmodelTuner (resources/viewmodel.cfg). Haengt am WeaponHolder, schwankt also mit der Waffe.
## Jedes Fingerglied ist ein eigener Knoten (index_0 -> index_1 -> index_2 ..., ebenso thumb):
## Glieder beugen sich um die eigene X-Achse, das Wurzelglied spreizt zusaetzlich um Y.
## Modell-Achsen: Finger nach -Z, Unterarm nach +Z, Handflaeche nach -Y, Daumen auf +X (linke Hand,
## deshalb gespiegelt).

const HAND: PackedScene = preload("res://assets/characters/Arm/hand.glb")
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
## Grundlage im System der Waffe: Finger zeigen nach vorn, Handflaeche zum Griff (links); Feinheiten per hand_rot
const BASE_FINGERS := Vector3(-0.3, 0.2, -1.0)
const BASE_PALM := Vector3(-1, 0, 0)
## Handflaechen-Mitte im Modell (Einheiten): dieser Punkt liegt am Griffpunkt der Waffe
const PALM_CENTER := Vector3(0, -0.4, -1.1)

var weapon_manager: Node3D
## Werte der aktuellen Waffe (ViewmodelTuner.defaults() als Vorlage)
var settings: Dictionary = {}
var _hand: Node3D


func _ready() -> void:
	# Heller Handschuh mit leichtem Randlicht, damit die Hand vor dunklen Waffen und Waenden erkennbar ist
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.55, 0.57, 0.62)
	body.metallic = 0.3
	body.roughness = 0.5
	body.rim_enabled = true
	body.rim = 0.6
	_hand = HAND.instantiate()
	_hand.name = "HandR"
	add_child(_hand)
	for mesh: MeshInstance3D in _hand.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = body
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Gleiche Render-Ebene wie die Waffen (eigenes Viewmodel-Licht)
		mesh.layers = WeaponManager.VIEWMODEL_LAYER


## Fingerhaltung aus settings.fingers: je Finger Vector4(Glied 1, Glied 2, Glied 3, Spreizen) in Grad
func apply_pose() -> void:
	for finger in FINGERS:
		var pose: Vector4 = settings.fingers[finger]
		for joint in 3:
			var node := _hand.find_child("%s_%d" % [finger, joint], true, false) as Node3D
			if node:
				node.rotation = Vector3(-deg_to_rad(pose[joint]), deg_to_rad(pose.w) if joint == 0 else 0.0, 0.0)


func _process(_delta: float) -> void:
	var weapon: Node3D = weapon_manager.get_current_weapon() if weapon_manager else null
	var model: WeaponModel = weapon.get_node_or_null("Model") as WeaponModel if weapon else null
	visible = model != null and weapon.visible and settings.get("hand", false)
	if not visible:
		return
	# Drehung aus Finger- und Handflaechen-Richtung, Zusatzdrehung, dann spiegeln (Modell ist eine linke Hand)
	var z := -BASE_FINGERS.normalized()
	var y := -BASE_PALM
	y = (y - z * y.dot(z)).normalized()
	var turn := Basis.from_euler(settings.hand_rot * PI / 180.0)
	var basis := weapon.basis * turn * Basis(y.cross(z), y, z).scaled(Vector3.ONE * settings.hand_scale) * Basis.from_scale(Vector3(-1, 1, 1))
	_hand.transform = Transform3D(basis, weapon.transform * (model.grip_point() + settings.hand_offset) - basis * PALM_CENTER)
