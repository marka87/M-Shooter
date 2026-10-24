extends Decal
class_name BulletHole

## Einschussloch an Waenden und Boeden: dunkles Loch mit hellem Metallrand, der erst hell und dann schwach
## nachglueht. Bleibt lange stehen;
## bei vollem Pool (Groesse je Grafikstufe) wandert das aelteste an die neue Stelle. Figuren und
## bewegliche Objekte liegen auf DYNAMIC_LAYER und bekommen keine Loecher (cull_mask = Layer 1).

const SCENE: PackedScene = preload("res://scenes/effects/bullet_hole.tscn")
## Render-Layer fuer Figuren, Kisten und Splitter (keine Decals darauf)
const DYNAMIC_LAYER: int = 1 << 2
## Loecher gleichzeitig je Grafikstufe (Niedrig, Mittel, Hoch, Ultra); pool_size setzt GameManager.apply_graphics
const POOL_SIZES: Array[int] = [40, 100, 180, 300]
static var pool_size: int = 180
## So lange bleibt ein Loch, dann verblasst es (s)
const STAY_SECONDS: float = 30.0

static var _pool: Array[BulletHole] = []

var _base_size: Vector3
var _base_emission: float
var _tween: Tween


## Loch der Groesse size (1 = MG) bei pos an der Oberflaeche mit normal; glow = Hitze des Randes
static func spawn(parent: Node, pos: Vector3, normal: Vector3, size: float = 1.0, glow: float = 1.0) -> void:
	if size <= 0.0 or normal.length_squared() < 0.001:
		return
	_pool = _pool.filter(func(h): return is_instance_valid(h))
	var hole: BulletHole
	if _pool.size() >= pool_size:
		hole = _pool.pop_front()
		if hole.get_parent() != parent:
			hole.reparent(parent, false)
	else:
		hole = SCENE.instantiate()
		parent.add_child(hole)
	_pool.append(hole)
	hole.global_position = pos + normal * 0.02
	hole.global_basis = basis_on(normal)
	hole._start(size, glow)


## Ausrichtung fuer ein Decal auf einer Flaeche: Decals projizieren entlang -Y, Y zeigt also aus der
## Flaeche heraus, zufaellig um diese Achse gedreht (auch fuer Oelflecken)
static func basis_on(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.98 else Vector3.FORWARD).normalized()
	return Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)


## Alle Figuren-Meshes unter node auf den Dynamik-Layer legen (keine Loecher auf Bots und Kisten)
static func mark_dynamic(node: Node) -> void:
	for mesh in node.find_children("*", "GeometryInstance3D", true, false):
		mesh.layers = DYNAMIC_LAYER


func _ready() -> void:
	_base_size = size
	_base_emission = emission_energy


func _start(scale_factor: float, glow: float) -> void:
	size = _base_size * Vector3(scale_factor, 1.0, scale_factor)
	modulate.a = 1.0
	emission_energy = _base_emission * glow
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# Glut kuehlt ab, ein schwacher Rest bleibt (sonst sieht man Loecher auf den dunklen Neon-Waenden kaum)
	_tween.tween_property(self, "emission_energy", _base_emission * 0.12 * glow, 3.0).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(STAY_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, 2.0)
