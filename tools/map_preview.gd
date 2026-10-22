extends SceneTree

## Vorschaubilder einer Map: Draufsicht (orthografisch) und Ego-Sicht vom ersten Spawn.
## Aufruf (mit Fenster, nicht headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s res://tools/map_preview.gd -- <map_id> <Ordner>
## Ergebnis: <Ordner>/<map_id>_top.png und <map_id>_ego.png


func _initialize() -> void:
	run()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0]
	var out_dir: String = args[1]
	await process_frame
	var gm = root.get_node("GameManager")
	gm.bot_count = 0
	gm.match_countdown = 0.0
	gm.reset_game()
	change_scene_to_file("res://levels/%s.tscn" % map_id)
	await create_timer(1.5).timeout
	var player = gm.current_player
	for layer in player.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	root.get_texture().get_image().save_png("%s/%s_ego.png" % [out_dir, map_id])
	# Draufsicht: Kamera hoch ueber der Map, Groesse aus den Spawnpunkten
	var box := AABB(player.global_position, Vector3.ZERO)
	for s in current_scene.get_node("SpawnPoints").get_children():
		box = box.expand(s.global_position)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(box.size.x, box.size.z) + 30.0
	current_scene.add_child(cam)
	cam.global_position = box.get_center() + Vector3(0, 120, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.far = 400.0
	cam.current = true
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s_top.png" % [out_dir, map_id])
	quit()
