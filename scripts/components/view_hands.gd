extends Node3D
class_name ViewHands

## Ego-Arme (assets/characters/Arm/arms.glb): Arme und Animationen von DJMaesen (CC BY 4.0) aus dem
## "FPS Hands"-Paket, die AK ist entfernt (tools/strip_arms.py), ihr Knoten "base_ak74_0" bleibt als Bezug.
## Die Arme werden so gelegt, dass der AK-Griff auf dem Griffpunkt der aktuellen Waffe liegt und der AK-Lauf
## in Laufrichtung zeigt; Feinheiten pro Waffe aus dem ViewmodelTuner (resources/viewmodel.cfg).
## Haengt am WeaponHolder, schwankt also mit der Waffe. Die Ruhe-Animation laeuft gestreckt als Atmen,
## beim Schuss kurz die Schuss-Animation; die Bewegung der AK darin wird herausgerechnet,
## unsere Waffe bleibt also fest in den Haenden (Rueckstoss macht weiter der WeaponManager).

const ARMS: PackedScene = preload("res://assets/characters/Arm/arms.glb")
const ANIM := &"allanims"
## Abschnitte in der Animation (Sekunden, 30 fps: Schuss Frame 0-7, Ruhe 199-221) und ihre Spieldauer
const FIRE := Vector2(0.0, 7.0 / 30.0)
const IDLE := Vector2(199.0 / 30.0, 221.0 / 30.0)
const FIRE_SECONDS := 0.1
const IDLE_SECONDS := 5.0
## Griffmitte der rechten Hand im AK-Bezug (Modell-Einheiten ~ cm, AK-Lauf nach +Z)
const AK_GRIP := Vector3(0.0, -3.7, -1.6)
## Grundgroesse: Modell-Einheiten -> Waffen-Einheiten (linke Hand etwa am vorderen Drittel einer 0,8 langen Waffe)
const BASE_SCALE := 0.0105

var weapon_manager: Node3D
## Werte der aktuellen Waffe (ViewmodelTuner.defaults() als Vorlage)
var settings: Dictionary = {}
var _arms: Node3D
var _anim: AnimationPlayer
var _gun: Node3D
var _weapon: WeaponBase
var _time: float = 0.0
var _fire_left: float = 0.0


func _ready() -> void:
	_arms = ARMS.instantiate()
	_arms.name = "Arms"
	add_child(_arms)
	_gun = _arms.find_child("base_ak74_0", true, false)
	_anim = _arms.find_children("*", "AnimationPlayer", true, false)[0]
	_anim.play(ANIM)
	_anim.pause()
	for mesh: MeshInstance3D in _arms.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Gleiche Render-Ebene wie die Waffen (eigenes Viewmodel-Licht)
		mesh.layers = WeaponManager.VIEWMODEL_LAYER
		# Handschuhe und Jacke sind fast schwarz: aufhellen und Randlicht, damit die Arme vor dunklen Waenden lesbar sind
		for i in mesh.get_surface_override_material_count():
			var mat := mesh.get_active_material(i).duplicate() as StandardMaterial3D
			mat.albedo_color = Color(2.2, 2.2, 2.4)
			mat.rim_enabled = true
			mat.rim = 0.6
			mat.rim_tint = 0.3
			mesh.set_surface_override_material(i, mat)


func _process(delta: float) -> void:
	var weapon: WeaponBase = weapon_manager.get_current_weapon() if weapon_manager else null
	var model: WeaponModel = weapon.get_node_or_null("Model") as WeaponModel if weapon else null
	visible = model != null and weapon.visible and settings.get("hand", true)
	if not visible:
		return
	if weapon != _weapon:
		if _weapon:
			_weapon.fired.disconnect(_on_fired)
		_weapon = weapon
		_weapon.fired.connect(_on_fired)

	_time += delta
	var t: float = IDLE.x + fmod(_time / IDLE_SECONDS, 1.0) * (IDLE.y - IDLE.x)
	if _fire_left > 0.0:
		_fire_left -= delta
		t = lerpf(FIRE.x, FIRE.y, clampf(1.0 - _fire_left / FIRE_SECONDS, 0.0, 1.0))
	_anim.seek(t, true)

	# AK-Bezug (animiert) herausrechnen, dann AK-Griff auf unseren Griffpunkt, AK-Lauf (+Z) auf unseren (-Z)
	var gun: Transform3D = _arms.global_transform.affine_inverse() * _gun.global_transform
	var size: float = BASE_SCALE * settings.get("arms_scale", 1.0)
	var turn := Basis.from_euler(settings.get("arms_rot", Vector3.ZERO) * PI / 180.0) * Basis(Vector3.UP, PI)
	var place := Transform3D(weapon.basis * turn * Basis.from_scale(Vector3.ONE * size),
		weapon.transform * (model.grip_point() + settings.get("arms_offset", Vector3.ZERO)))
	_arms.transform = place * Transform3D(Basis(), -AK_GRIP) * gun.affine_inverse()


func _on_fired() -> void:
	_fire_left = FIRE_SECONDS
