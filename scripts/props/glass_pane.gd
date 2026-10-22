extends StaticBody3D
class_name GlassPane

## Zerbrechliche Glasscheibe: haelt Schuesse, Explosionen und die Sicht der Bots auf, bis sie zerspringt.
## Splitter fliegen in Schussrichtung, danach ist der Durchgang frei (bis zum naechsten Match).

@export var size: Vector3 = Vector3(4.0, 3.0, 0.08)
@export var max_health: float = 25.0
@export var tint: Color = Color(0.4, 0.85, 1.0)

var _health: float
var _broken: bool = false
var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_health = max_health
	collision_layer = Layers.WORLD | Layers.PROPS
	collision_mask = 0
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	_shape.shape.size = size
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	_mesh.mesh.size = size
	_mesh.material_override = _glass_material(0.22)
	_mesh.layers = BulletHole.DYNAMIC_LAYER
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_add_frame()


func take_damage(info: DamageInfo) -> void:
	# Im Netzspiel meldet der Host, wann die Scheibe bricht
	if _broken or Net.is_client():
		return
	_health -= info.amount
	if _health <= 0.0:
		destroy(info.direction)


## Zerspringen (vom Treffer oder vom Host im Netzspiel); push = Flugrichtung der Splitter
func destroy(push: Vector3 = Vector3.ZERO) -> void:
	if _broken:
		return
	_broken = true
	Net.on_prop_destroyed(self)
	_shape.set_deferred("disabled", true)
	_mesh.visible = false
	_spawn_shards(push)
	PropFx.play_sound(self, SoundGenerator.create_glass_break_sound(), 2.0)
	get_tree().create_timer(2.0, false).timeout.connect(queue_free)


func _spawn_shards(push: Vector3) -> void:
	var shards := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = size * 0.5
	# Splitter fliegen vom Treffer weg (lokale Z-Achse = Scheibennormale)
	var away: float = 1.0 if push.dot(global_basis.z) >= 0.0 else -1.0
	process.direction = Vector3(0, 0.3, away)
	process.spread = 55.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 6.0
	process.angular_velocity_min = -540.0
	process.angular_velocity_max = 540.0
	process.gravity = Vector3(0, -18, 0)
	process.scale_min = 0.4
	process.scale_max = 1.2
	shards.process_material = process
	var shard := BoxMesh.new()
	shard.size = Vector3(0.14, 0.12, 0.015)
	shard.material = _glass_material(0.55)
	shards.draw_pass_1 = shard
	shards.amount = clampi(int(size.x * size.y * 10.0), 20, 120)
	shards.lifetime = 1.4
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.layers = BulletHole.DYNAMIC_LAYER
	add_child(shards)
	shards.emitting = true


## Leuchtender Rahmen, damit man die Scheibe als Hindernis erkennt (verschwindet mit ihr)
func _add_frame() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = tint
	glow.emission_enabled = true
	glow.emission = tint
	glow.emission_energy_multiplier = 2.5
	var t := 0.05
	for edge in [[Vector3(size.x, t, size.z + t), Vector3(0, size.y / 2, 0)], [Vector3(size.x, t, size.z + t), Vector3(0, -size.y / 2, 0)],
			[Vector3(t, size.y, size.z + t), Vector3(size.x / 2, 0, 0)], [Vector3(t, size.y, size.z + t), Vector3(-size.x / 2, 0, 0)]]:
		var bar := MeshInstance3D.new()
		bar.mesh = BoxMesh.new()
		bar.mesh.size = edge[0]
		bar.position = edge[1]
		bar.material_override = glow
		bar.layers = BulletHole.DYNAMIC_LAYER
		_mesh.add_child(bar)


func _glass_material(alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint, alpha)
	mat.metallic = 0.6
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.4
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
