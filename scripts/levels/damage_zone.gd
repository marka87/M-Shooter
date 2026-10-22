extends Area3D
class_name DamageZone

## Schadens-Zone (Energie-Schlamm, Lava): wer drinsteht, verliert alle 0,5 s Leben.
## In Schueben statt jedes Frame, damit Schadenszahlen und Trefferton nicht im Takt rattern.

@export var damage_per_second: float = 20.0
## Farbe des leuchtenden Dunsts ueber der Zone (volumetrischer Nebel)
@export var haze_color: Color = Color(1.0, 0.8, 0.2)
const TICK: float = 0.5

var _timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.CHARACTERS
	var box := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if box and box.shape is BoxShape3D:
		var haze := FogVolume.new()
		haze.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		haze.size = (box.shape as BoxShape3D).size + Vector3(0.0, 1.5, 0.0)
		haze.position = box.position + Vector3(0.0, 0.75, 0.0)
		var mat := FogMaterial.new()
		mat.density = 0.35
		mat.albedo = haze_color
		mat.emission = haze_color * 0.5
		mat.height_falloff = 1.2
		mat.edge_fade = 0.3
		haze.material = mat
		add_child(haze)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(DamageInfo.create(damage_per_second * TICK, null, body.global_position, Vector3.ZERO, "Schlamm"))
