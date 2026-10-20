extends SceneTree

# Begehbarkeitstest fuer die Neon Foundry: Treppen, Bruecken, Jump-Pads und Bot-Wege.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/neon_foundry_test.gd
# Exit-Code 0 = alles bestanden.

var fails := 0


func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	run()


## Spieler an start stellen, Richtung look_dir schauen, seconds lang vorwaerts laufen
func walk(player, start: Vector3, look_dir: Vector3, seconds: float) -> Vector3:
	player.velocity = Vector3.ZERO
	player.global_position = start
	player.look_at(start + look_dir, Vector3.UP)
	await physics_frame
	Input.action_press("move_forward")
	await create_timer(seconds).timeout
	Input.action_release("move_forward")
	await create_timer(0.3).timeout
	return player.global_position


func run() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	var orig_count: int = gm.bot_count
	gm.bot_count = 1
	gm.reset_game()
	change_scene_to_file("res://levels/neon_foundry.tscn")
	await create_timer(1.0).timeout
	var player = gm.current_player
	var bots := get_nodes_in_group("enemies")
	for b in bots:
		b.set_physics_process(false)
		b.global_position = Vector3(0, -50, 0)

	check(gm.spawn_points.size() == 8, "8 Spawnpunkte (%d)" % gm.spawn_points.size())

	# Treppe S1: Boden -> Nord-Ring
	var p: Vector3 = await walk(player, Vector3(-12.5, 0.1, -13), Vector3(0, 0, -1), 2.5)
	print("S1 Ende: ", p)
	check(p.y > 3.8 and p.z < -25.0, "Treppe Boden -> Ring (S1)")

	# Treppe S3: Boden -> Ost-Ring
	p = await walk(player, Vector3(13, 0.1, 12.5), Vector3(1, 0, 0), 2.5)
	print("S3 Ende: ", p)
	check(p.y > 3.8 and p.x > 25.0, "Treppe Boden -> Ring (S3)")

	# Treppe Ring -> Turm Nordost
	p = await walk(player, Vector3(7, 4.1, -30), Vector3(1, 0, 0), 2.5)
	print("Turmtreppe Ende: ", p)
	check(p.y > 7.8 and p.x > 19.0, "Treppe Ring -> Turm Nordost")

	# Bruecke Ost-Ring -> Mittelplattform
	p = await walk(player, Vector3(28, 4.1, 0), Vector3(-1, 0, 0), 3.3)
	print("Bruecke Ende: ", p)
	check(p.y > 3.8 and absf(p.x) < 5.0, "Bruecke Ring -> Mitte")

	# Durchgang in der Ostwand (x=18) am Boden
	p = await walk(player, Vector3(12, 0.1, 0), Vector3(1, 0, 0), 1.2)
	print("Durchgang Ende: ", p)
	check(p.x > 19.0 and p.y < 1.0, "Tuer in der Durchgangswand")

	# Jump-Pad zum Turm Nordost
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(22, 0.3, -12)
	await create_timer(3.0).timeout
	p = player.global_position
	print("Jump-Pad Landung: ", p)
	check(p.y > 7.8, "Jump-Pad Boden -> Turm Nordost")

	# Jump-Pad zur Mittelplattform
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.3, 10)
	await create_timer(3.0).timeout
	p = player.global_position
	print("Mitte-Pad Landung: ", p)
	check(p.y > 3.8 and absf(p.x) < 5.0 and absf(p.z) < 5.0, "Jump-Pad Boden -> Mittelplattform")

	# Navigationsnetz: Wege vom Boden auf Ring, Mitte und Tuerme
	var map_rid: RID = bots[0].nav_agent.get_navigation_map()
	var from := NavigationServer3D.map_get_closest_point(map_rid, Vector3(0, 0, 25))
	for target in [Vector3(0, 4, -28), Vector3(0, 4, 0), Vector3(25, 8, -25), Vector3(-25, 8, 25)]:
		var path := NavigationServer3D.map_get_path(map_rid, from, target, true)
		var end: Vector3 = path[path.size() - 1] if path.size() > 0 else Vector3(999, 999, 999)
		check(end.distance_to(target) < 1.5, "Bot-Weg vom Boden nach %s (%d Punkte)" % [target, path.size()])

	# Bot laeuft wirklich auf den Turm Suedwest (Treppe vom Sued-Ring)
	var bot = bots[0]
	player.remove_from_group("player")
	bot.global_position = Vector3(0, 0.1, 22)
	bot.set_physics_process(true)
	bot.patrol_target = Vector3(-26, 8.0, 26)
	bot.nav_agent.target_position = bot.patrol_target
	bot.patrol_travel_timer = -100.0
	var reached := false
	for i in 40:
		await create_timer(0.5).timeout
		bot.patrol_target = Vector3(-26, 8.0, 26)
		bot.patrol_wait_timer = 0.0
		if bot.global_position.y > 7.5:
			reached = true
			break
	print("Bot-Position: ", bot.global_position)
	check(reached, "Bot erreicht Turm Suedwest")
	player.add_to_group("player")

	gm.bot_count = orig_count
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
