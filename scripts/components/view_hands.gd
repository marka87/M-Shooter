extends Node3D
class_name ViewHands

## Ego-Hand (assets/characters/Arm/hand.glb) rechts am Griff der aktuellen Waffe.
## Haengt am WeaponHolder, schwankt und federt also mit der Waffe. Die Finger sind eigene Knoten
## (index_0 -> index_1 -> index_2 ...) und werden per Drehung um den Griff gekruemmt.
## Modell-Achsen: Finger nach -Z, Unterarm nach +Z, Handflaeche nach -Y, Daumen auf +X (linke Hand,
## deshalb gespiegelt).

const HAND: PackedScene = preload("res://assets/characters/Arm/hand.glb")
const FINGERS := ["index", "middle", "ring", "pinky"]

## Modell-Einheiten -> Meter (im WeaponHolder, der selbst noch vergroessert)
@export var hand_scale: float = 0.06
## Handlage im Koordinatensystem der Waffe: wohin die Finger zeigen, wohin die Handflaeche schaut
@export var fingers: Vector3 = Vector3(-0.3, 0.2, -1.0)
@export var palm: Vector3 = Vector3(-1, 0, 0)
## Kruemmung der Fingerglieder (Grad, Wurzel -> Spitze) und des Daumens
@export var curl: Vector3 = Vector3(60, 75, 55)
@export var thumb_curl: Vector3 = Vector3(20, 30, 25)
## Handflaechen-Mitte im Modell (Einheiten): dieser Punkt liegt am Griff
@export var palm_center: Vector3 = Vector3(0, -0.4, -1.1)
## Feinjustierung (Viewmodel-Editor, F4): Versatz in Metern und Zusatzdrehung in Grad, beides im System der Waffe
@export var hand_offset: Vector3 = Vector3.ZERO
@export var hand_rot: Vector3 = Vector3.ZERO

var weapon_manager: Node3D
var _hand: Node3D


func _ready() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.12, 0.13, 0.16)
	body.metallic = 0.6
	body.roughness = 0.35
	_hand = HAND.instantiate()
	_hand.name = "HandR"
	add_child(_hand)
	for mesh: MeshInstance3D in _hand.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = body
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Gleiche Render-Ebene wie die Waffen (eigenes Viewmodel-Licht)
		mesh.layers = WeaponManager.VIEWMODEL_LAYER
	apply_curl()


## Fingerglieder um die eigene X-Achse zur Handflaeche (-Y) kruemmen (curl / thumb_curl)
func apply_curl() -> void:
	for finger in FINGERS + ["thumb"]:
		var angles: Vector3 = thumb_curl if finger == "thumb" else curl
		for joint in 3:
			var node := _hand.find_child("%s_%d" % [finger, joint], true, false) as Node3D
			if node:
				node.rotation.x = -deg_to_rad(angles[joint])


func _process(_delta: float) -> void:
	var weapon: Node3D = weapon_manager.get_current_weapon() if weapon_manager else null
	var model: WeaponModel = weapon.get_node_or_null("Model") as WeaponModel if weapon else null
	visible = model != null and weapon.visible
	if not visible:
		return
	# Drehung aus Finger- und Handflaechen-Richtung, dann spiegeln (Modell ist eine linke Hand)
	var z := -fingers.normalized()
	var y := -palm
	y = (y - z * y.dot(z)).normalized()
	var basis := weapon.basis * Basis.from_euler(hand_rot * PI / 180.0) * Basis(y.cross(z), y, z).scaled(Vector3.ONE * hand_scale) * Basis.from_scale(Vector3(-1, 1, 1))
	_hand.transform = Transform3D(basis, weapon.transform * (model.grip_point() + hand_offset) - basis * palm_center)
