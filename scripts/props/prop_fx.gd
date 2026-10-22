class_name PropFx

## Gemeinsame Effekte fuer zerstoerbare Objekte (Kisten, Faesser, Glas)

const VOXEL_BURST: PackedScene = preload("res://scenes/effects/voxel_burst.tscn")


## 3D-Sound an der Stelle von node, der weiterlaeuft, auch wenn node verschwindet
static func play_sound(node: Node3D, stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.92, 1.08)
	player.max_distance = 45.0
	node.get_parent().add_child(player)
	player.global_position = node.global_position
	player.finished.connect(player.queue_free)
	player.play()


## Leuchtende Wuerfel in der Farbe des Objekts (wie beim Zerplatzen eines Bots)
static func burst(node: Node3D, color: Color) -> void:
	var fx := VOXEL_BURST.instantiate() as VoxelBurst
	node.get_parent().add_child(fx)
	fx.global_position = node.global_position
	fx.burst(color)
