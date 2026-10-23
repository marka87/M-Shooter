extends SceneTree

# Neue Maps aus dem Baukasten (tools/maps/*.py): laedt jede Map und prueft Spawns (auch ihre Blickrichtung), Bot-Wege zu allen
# Spawns und Items (inklusive Jump-Pads und Teleporter), CTF-Basenabstand und eine kurze Bot-Runde.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/maps_test.gd
# Exit-Code 0 = alles bestanden.

const MAPS := ["sky_yard", "duck_17", "twin_spires", "camp_ground", "nova_complex"]

var fails := 0


func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	run()


func run() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	var orig := [gm.bot_count, gm.frag_limit, gm.time_limit_minutes, gm.match_countdown, gm.game_mode, gm.bot_skill]
	gm.bot_skill = 2  # "Erfahren": unabhaengig von den gespeicherten Einstellungen
	gm.frag_limit = 0
	gm.time_limit_minutes = 0.0
	gm.match_countdown = 0.0
	gm.game_mode = gm.Mode.DEATHMATCH
	# Start nur mit MG und Shotgun: Raketenwerfer und Railgun muessen auf jeder Map liegen, die Start-Waffen nicht
	for m in gm.MAPS:
		var text := FileAccess.get_file_as_string(m.scene)
		check(text.contains('weapon_id = &"railgun"') and text.contains('weapon_id = &"rocket_launcher"'),
			"%s: Railgun und Raketenwerfer zum Einsammeln" % m.name)
		check(not text.contains('weapon_id = &"machine_gun"') and not text.contains('weapon_id = &"shotgun"'),
			"%s: keine Start-Waffen (MG, Shotgun) auf der Map" % m.name)
	for map_id in MAPS:
		gm.bot_count = 4
		gm.reset_game()
		change_scene_to_file("res://levels/%s.tscn" % map_id)
		await create_timer(1.0).timeout
		var level := current_scene
		var spawns: Array = level.get_node("SpawnPoints").get_children()
		var max_players: int = gm.MAPS.filter(func(m): return m.scene.ends_with(map_id + ".tscn"))[0].max_players
		check(spawns.size() >= max_players, "%s: %d Spawnpunkte fuer %d Spieler" % [map_id, spawns.size(), max_players])
		# Spawns aus dem Navigationsnetz schauen ins Freie, nicht gegen eine Wand oder ueber eine Kante
		var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
		var cramped: Array = gm.spawn_points.filter(func(p): return p.has_meta(&"nav_spawn") and level._open_distance(space, p.global_position, -p.global_basis.z) < 6.0)
		check(cramped.is_empty(), "%s: neue Spawns schauen ins Freie %s" % [map_id, cramped.map(func(p): return p.name)])
		check(level.get_node("Props").get_child_count() > 0 and level.get_node("FogVolumes").get_child_count() > 0,
			"%s: zerstoerbare Objekte und Nebel" % map_id)

		# Bot-Wege: vom ersten Spawn zu allen Spawns und Items (Navigationsnetz + Pad/Teleporter-Links)
		var nav_map: RID = level.get_world_3d().navigation_map
		var from: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, spawns[0].global_position)
		var targets: Array = spawns.map(func(s): return s.global_position)
		targets += level.get_node("Items").get_children().map(func(i): return i.global_position)
		var missing: Array = []
		for t in targets:
			var path := NavigationServer3D.map_get_path(nav_map, from, t, true)
			if path.is_empty() or path[path.size() - 1].distance_to(t) > 2.5:
				missing.append(t.snappedf(0.1))
		check(missing.is_empty(), "%s: Bots erreichen alle %d Spawns und Items %s" % [map_id, targets.size(), missing])

		# CTF-Basen = die zwei entferntesten Spawnpunkte
		var far := 0.0
		for a in spawns:
			for b in spawns:
				far = maxf(far, a.global_position.distance_to(b.global_position))
		check(far > 50.0, "%s: CTF-Basen %.0f m auseinander" % [map_id, far])

		# Kurze Bot-Runde (Spieler aus dem Spiel genommen): es wird gekaempft
		var player = gm.current_player
		player.set_physics_process(false)
		player.global_position = Vector3(0, -400, 0)
		Engine.time_scale = 4.0
		await create_timer(60.0).timeout  # 60 s Spielzeit
		Engine.time_scale = 1.0
		# Schaden statt Frags: Abstuerze ins Nichts zaehlen -1 und heben Kills sonst auf
		var damage := 0.0
		for n in gm.scores:
			damage += gm.scores[n].damage_dealt
		check(damage > 50.0, "%s: Bots treffen sich und kaempfen (%d Schaden in 60 s)" % [map_id, damage])

	gm.bot_count = orig[0]
	gm.frag_limit = orig[1]
	gm.time_limit_minutes = orig[2]
	gm.match_countdown = orig[3]
	gm.game_mode = orig[4]
	gm.bot_skill = orig[5]
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
