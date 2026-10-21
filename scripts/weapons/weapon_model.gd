@tool
extends Node3D
class_name WeaponModel

## Quaternius-Waffenmodell (CC0, assets/weapons/quaternius) in die Waffen-Konvention bringen:
## Lauf nach -Z, Laufspitze bei front_z, Gesamtlaenge length, Mitte auf Hoehe center_y.
## Das orange Akzent-Material "Main" leuchtet in der Waffenfarbe (Neon-Look wie zuvor).

@export var glow_color: Color = Color.WHITE
@export var front_z: float = -0.6
@export var length: float = 0.8
@export var center_y: float = 0.0

## Name des Akzent-Materials in den Quaternius-Modellen
const ACCENT := "Main"


func _ready() -> void:
	var mesh_root: Node3D = $Mesh
	# Rohmodell: Lauf zeigt nach +X -> um 90 Grad um Y drehen, dann zeigt er nach -Z
	var rot := Basis(Vector3.UP, PI / 2.0)
	mesh_root.transform = Transform3D(rot, Vector3.ZERO)
	var box := _bounds(mesh_root)
	var s := length / box.size.z
	var center := box.get_center() * s
	mesh_root.transform = Transform3D(rot.scaled(Vector3.ONE * s), Vector3(-center.x, center_y - center.y, front_z - box.position.z * s))

	var glow := StandardMaterial3D.new()
	glow.albedo_color = glow_color
	glow.emission_enabled = true
	glow.emission = glow_color
	glow.emission_energy_multiplier = 4.0
	for mesh: MeshInstance3D in mesh_root.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i)
			if mat and mat.resource_name == ACCENT:
				mesh.set_surface_override_material(i, glow)


## Umriss aller Meshes im Koordinatensystem dieses Knotens (ohne global_transform, klappt auch ausserhalb des Baums)
func _bounds(mesh_root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in mesh_root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mesh
		while n != self:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
