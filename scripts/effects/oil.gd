extends RefCounted
class_name Oil

## Robo-Gore: Figuren bluten dunkles, bernsteinfarben schimmerndes Oel. Treffer spritzen Tropfen und hinterlassen Flecken
## an Boden und Waenden (in Schussrichtung), Tote eine Lache. Grosse Treffer zerlegen die Figur in Teile
## (Kopf, Arme, Beine, Rumpf), die herumspringen, und rundherum spritzt es. Flecken teilen sich einen Pool.

const POOL_SIZE := 90
const STAY_SECONDS := 40.0
## Hoechstens so viele Spritzer-Partikel gleichzeitig (MG-Dauerfeuer auf viele Bots)
const MAX_SPRAYS := 24
const PART_SECONDS := 10.0
## Koerperteile beim Zerlegen: Mesh, Groesse, Hoehe ueber den Fuessen
const PARTS := [
	["sphere", Vector3(0.32, 0.32, 0.32), 1.65], ["box", Vector3(0.42, 0.34, 0.24), 1.3], ["box", Vector3(0.36, 0.3, 0.22), 1.0],
	["capsule", Vector3(0.1, 0.62, 0.1), 1.25], ["capsule", Vector3(0.1, 0.62, 0.1), 1.25],
	["capsule", Vector3(0.12, 0.8, 0.12), 0.5], ["capsule", Vector3(0.12, 0.8, 0.12), 0.5],
]

static var _pool: Array[Decal] = []
static var _sprays: int = 0
static var _splat_tex: GradientTexture2D
static var _glow_tex: GradientTexture2D
static var _drop_mesh: SphereMesh


## Treffer: Tropfen in Schussrichtung, Flecken dort, wo sie auftreffen (Wand dahinter, Boden darunter)
static func spray(parent: Node, pos: Vector3, dir: Vector3, amount: float) -> void:
	if not parent.is_inside_tree():
		return
	var d := dir.normalized() if dir.length_squared() > 0.01 else Vector3.UP
	if _sprays < MAX_SPRAYS:
		_spawn_drops(parent, pos, d, clampi(int(amount / 3.0), 6, 40))
	var space := parent.get_viewport().find_world_3d().direct_space_state
	var reach: float = clampf(amount / 20.0, 1.5, 5.0)
	var size: float = clampf(amount / 60.0, 0.35, 1.0)
	for ray in [d * reach, (d + Vector3.DOWN).normalized() * reach, Vector3.DOWN * 2.5]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos, pos + ray, Layers.WORLD))
		if hit:
			splat(parent, hit.position, hit.normal, size * randf_range(0.7, 1.3))


## Lache unter einer Leiche (Boden bis 3 m darunter)
static func pool(parent: Node, pos: Vector3) -> void:
	var space := parent.get_viewport().find_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 3.0, Layers.WORLD))
	if hit:
		splat(parent, hit.position, hit.normal, randf_range(1.6, 2.2))


## Zerlegen: Koerperteile in der Farbe der Figur fliegen weg (Schwung push), Oel spritzt rundherum
static func gib(parent: Node, feet: Vector3, color: Color, push: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.12)
	mat.metallic = 0.7
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	for part in PARTS:
		var body := RigidBody3D.new()
		body.collision_layer = 0  # niemand stolpert darueber, Schuesse fliegen durch
		body.collision_mask = Layers.WORLD | Layers.PROPS
		var mesh_inst := MeshInstance3D.new()
		var shape := CollisionShape3D.new()
		var s: Vector3 = part[1]
		match part[0]:
			"sphere":
				mesh_inst.mesh = SphereMesh.new()
				mesh_inst.mesh.radius = s.x / 2.0
				mesh_inst.mesh.height = s.x
				shape.shape = SphereShape3D.new()
				shape.shape.radius = s.x / 2.0
			"capsule":
				mesh_inst.mesh = CapsuleMesh.new()
				mesh_inst.mesh.radius = s.x
				mesh_inst.mesh.height = s.y
				shape.shape = CapsuleShape3D.new()
				shape.shape.radius = s.x
				shape.shape.height = s.y
			_:
				mesh_inst.mesh = BoxMesh.new()
				mesh_inst.mesh.size = s
				shape.shape = BoxShape3D.new()
				shape.shape.size = s
		mesh_inst.material_override = mat
		mesh_inst.layers = BulletHole.DYNAMIC_LAYER
		body.add_child(mesh_inst)
		body.add_child(shape)
		parent.add_child(body)
		body.global_position = feet + Vector3(randf_range(-0.2, 0.2), part[2], randf_range(-0.2, 0.2))
		body.rotation = Vector3(randf(), randf(), randf()) * TAU
		var out := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.4), randf_range(-1.0, 1.0))
		body.linear_velocity = push * 0.5 + out * randf_range(3.0, 7.0)
		body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 10.0
		var tween := body.create_tween()
		tween.tween_interval(PART_SECONDS)
		tween.tween_property(mesh_inst, "scale", Vector3.ZERO, 0.6)
		tween.tween_callback(body.queue_free)
	var center := feet + Vector3.UP * 1.0
	if _sprays < MAX_SPRAYS:
		_spawn_drops(parent, center, Vector3.UP, 60, 70.0)
	var space := parent.get_viewport().find_world_3d().direct_space_state
	for i in 10:
		var ray := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 0.3), randf_range(-1.0, 1.0)).normalized() * 4.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center, center + ray, Layers.WORLD))
		if hit:
			splat(parent, hit.position, hit.normal, randf_range(0.6, 1.4))
	pool(parent, feet)


## Ein Oelfleck auf einer Flaeche; bei vollem Pool wandert der aelteste an die neue Stelle
static func splat(parent: Node, pos: Vector3, normal: Vector3, radius: float) -> void:
	if normal.length_squared() < 0.001:
		return
	_pool = _pool.filter(func(d): return is_instance_valid(d))
	var decal: Decal
	if _pool.size() >= POOL_SIZE:
		decal = _pool.pop_front()
		if decal.get_parent() != parent:
			decal.reparent(parent, false)
	else:
		decal = Decal.new()
		decal.texture_albedo = _texture()
		# Schwaches Schimmern: auf den schwarzen Neon-Boeden waere reines Schwarz unsichtbar
		decal.texture_emission = _texture(true)
		decal.emission_energy = 1.3
		decal.modulate = Color(1, 1, 1, 1)
		decal.cull_mask = 1  # nicht auf Figuren und Kisten (BulletHole.DYNAMIC_LAYER)
		decal.upper_fade = 0.05
		decal.lower_fade = 0.05
		parent.add_child(decal)
	_pool.append(decal)
	decal.global_position = pos + normal * 0.03
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.98 else Vector3.FORWARD).normalized()
	decal.global_basis = Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	# Laenglich und unregelmaessig gross, damit nicht jeder Fleck ein Kreis ist
	decal.size = Vector3(radius * randf_range(0.7, 1.4), 0.5, radius * randf_range(0.7, 1.0))
	decal.modulate.a = 1.0
	var tween := decal.create_tween()
	tween.tween_interval(STAY_SECONDS)
	tween.tween_property(decal, "modulate:a", 0.0, 3.0)


## Runder Fleck: gleiche Farbe, nur die Deckkraft laeuft aus (sonst leuchtet der Rand als Ring).
## glow: fuer das Leuchten, das die Deckkraft ignoriert, laeuft stattdessen die Farbe auf Schwarz aus.
static func _texture(glow: bool = false) -> GradientTexture2D:
	if (_glow_tex if glow else _splat_tex) == null:
		var oil := Color(0.32, 0.16, 0.04)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
		var fade: Array = [0.97, 0.9, 0.45, 0.0]
		g.colors = PackedColorArray(fade.map(func(a): return oil * a if glow else Color(oil, a)))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		if glow:
			_glow_tex = tex
		else:
			_splat_tex = tex
	return _glow_tex if glow else _splat_tex


## Glaenzende schwarze Tropfen als einmaliger Partikelstoss
static func _spawn_drops(parent: Node, pos: Vector3, dir: Vector3, count: int, spread: float = 30.0) -> void:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.035
		_drop_mesh.height = 0.07
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.02, 0.01)
		mat.metallic = 0.9
		mat.roughness = 0.12
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.2, 0.05)
		mat.emission_energy_multiplier = 1.2
		_drop_mesh.material = mat
	var drops := GPUParticles3D.new()
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.amount = count
	drops.lifetime = 0.9
	drops.layers = BulletHole.DYNAMIC_LAYER
	drops.draw_pass_1 = _drop_mesh
	var process := ParticleProcessMaterial.new()
	process.direction = dir
	process.spread = spread
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0, -18, 0)
	process.scale_min = 0.6
	process.scale_max = 1.6
	drops.process_material = process
	parent.add_child(drops)
	drops.global_position = pos
	drops.emitting = true
	_sprays += 1
	drops.finished.connect(func():
		_sprays -= 1
		drops.queue_free())
