extends SceneTree

# LAN-Test mit zwei Prozessen: Dieser hostet die Testarena (ein Bot, steht still), ein zweiter Prozess
# (dasselbe Skript mit "-- client") findet den Host per LAN-Suche, tritt bei, bewegt sich, schiesst,
# stirbt, respawnt und sammelt ein Item ein. Der Client schreibt seine Pruefungen in eine Datei.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/net_test.gd
# Exit-Code 0 = alles bestanden.

const RESULT_PATH := "user://net_client_result.txt"

var fails := 0
var lines: PackedStringArray = []


func check(cond: bool, label: String) -> void:
	var line := ("PASS " if cond else "FAIL ") + label
	print(line)
	lines.append(line)
	if not cond:
		fails += 1


func wait_for(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await create_timer(0.05).timeout
		t += 0.05
	return cond.call()


func _initialize() -> void:
	# 2 = ItemPickup.PickupType.HEALTH (Klassen mit GameManager-Bezug hier nicht nennen, siehe smoke_test)
	if "client" in OS.get_cmdline_user_args():
		run_client()
	else:
		run_host()


func run_host() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	var net = root.get_node("Net")
	for i in gm.MAPS.size():
		if gm.MAPS[i].scene.ends_with("test_arena.tscn"):
			gm.selected_map = i
	gm.game_mode = gm.Mode.DEATHMATCH
	gm.bot_count = 1
	gm.frag_limit = 0
	gm.time_limit_minutes = 0.0
	gm.instagib = false
	check(net.host_game("Host") == "", "Host startet den Server")
	gm.reset_game()
	change_scene_to_file(gm.MAPS[gm.selected_map].scene)
	await create_timer(1.0).timeout
	var host_player = gm.current_player
	host_player.set_physics_process(false)
	host_player.global_position = Vector3(30, 40, 30)
	var bot = net.node_of("Bot1")
	bot.set_physics_process(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT_PATH))

	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/net_test.gd", "--", "client"])
	check(pid > 0, "Client-Prozess gestartet")

	var puppet_id := func() -> String:
		for key in net.entities:
			if key != "P1" and key.begins_with("P"):
				return key
		return ""
	check(await wait_for(func(): return puppet_id.call() != "", 20.0), "Client tritt bei, Host baut seine Puppe")
	var eid: String = puppet_id.call()
	var puppet = net.node_of(eid)
	check(puppet != null and puppet.display_name == "Gast" and puppet.puppet, "Puppe heisst Gast")

	var in_front: Vector3 = bot.global_position + Vector3(0, 0, 6)
	check(await wait_for(func(): return puppet.global_position.distance_to(in_front) < 1.5, 10.0),
		"Host sieht die Bewegung des Clients (%s)" % puppet.global_position.snappedf(0.1))
	check(await wait_for(func(): return bot.health.health < bot.health.max_health, 10.0),
		"Railgun-Treffer des Clients zaehlt beim Host (Bot %d HP)" % bot.health.health)

	await create_timer(0.5).timeout
	puppet.take_damage(DamageInfo.create(500.0, host_player, puppet.global_position, Vector3.ZERO, "Test"))
	check(puppet.health.is_dead and gm.scores["Host"].frags == 1, "Host toetet die Puppe, Frag fuer den Host")
	check(await wait_for(func(): return not puppet.health.is_dead, 8.0), "Puppe respawnt")
	await create_timer(1.0).timeout
	puppet.take_damage(DamageInfo.create(50.0, null, puppet.global_position, Vector3.ZERO, "Test"))
	check(await wait_for(func(): return puppet.health.health > 50.0, 12.0), "Client sammelt Leben ein (der Host entscheidet)")

	# Schuesse des Hosts sieht der Client, das Matchende bestimmt der Host
	await create_timer(2.5).timeout
	for i in 3:
		host_player.weapon_manager.fire_current_weapon()
		await create_timer(0.15).timeout
	await create_timer(1.0).timeout
	gm.end_match("Test")

	check(await wait_for(func(): return not OS.is_process_running(pid), 30.0), "Client beendet sich")
	var file := FileAccess.open(RESULT_PATH, FileAccess.READ)
	check(file != null, "Ergebnis des Clients liegt vor")
	if file:
		for line in file.get_as_text().split("\n", false):
			print("  [Client] " + line)
			if line.begins_with("FAIL"):
				fails += 1
	check(await wait_for(func(): return not net.entities.has(eid), 5.0), "Puppe verschwindet nach dem Verlassen")
	net.leave()
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)


func run_client() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	var net = root.get_node("Net")
	net.start_listening()
	check(await wait_for(func(): return net.servers.size() > 0, 5.0), "LAN-Suche findet den Host %s" % [net.servers.keys()])
	net.stop_listening()
	net.join_game("127.0.0.1", "Gast")
	check(await wait_for(func(): return is_instance_valid(net._level) and gm.current_player != null, 20.0), "Client laedt die Map des Hosts")
	var player = gm.current_player
	check(player.display_name == "Gast", "Eigener Name kommt vom Host")
	check(await wait_for(func(): return net.node_of("P1") != null and net.node_of("Bot1") != null, 5.0), "Client sieht Host und Bot als Puppen")
	var bot = net.node_of("Bot1")
	check(await wait_for(func(): return bot.global_position.y > -100.0, 5.0), "Bot-Puppe folgt dem Host (%s)" % bot.global_position.snappedf(0.1))
	await create_timer(0.5).timeout

	# Vor den Bot stellen (6 m, Blick nach -Z), Railgun nehmen und schiessen, bis der Host den Treffer meldet
	player.global_position = bot.global_position + Vector3(0, 0, 6)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.camera_pitch = 0.0
	player.head.rotation.x = 0.0
	player.weapon_manager.give_weapon(&"railgun", 10)
	player.weapon_manager.switch_to_weapon_id(&"railgun")
	await create_timer(1.0).timeout
	var hit := false
	for i in 40:
		player.weapon_manager.fire_current_weapon()
		await create_timer(0.1).timeout
		if bot.health.health < bot.health.max_health:
			hit = true
			break
	check(hit, "Client sieht den Schaden am Bot (Ereignis vom Host, %d HP)" % bot.health.health)

	check(await wait_for(func(): return player.is_dead, 10.0), "Client stirbt, wenn der Host es sagt")
	check(gm.scores.has("Host") and gm.scores["Host"].frags == 1, "Kill zaehlt auch beim Client")
	check(await wait_for(func(): return not player.is_dead, 8.0), "Client respawnt auf Befehl des Hosts")
	check(await wait_for(func(): return player.health.health <= 50.0, 8.0), "Schaden vom Host kommt an (%d HP)" % player.health.health)

	# Zum naechsten Lebens-Item laufen (hinstellen)
	var item = null
	for candidate in root.get_tree().get_nodes_in_group("pickups"):
		if candidate.pickup_type == 2 and candidate.is_active:
			if item == null or candidate.global_position.distance_to(player.global_position) < item.global_position.distance_to(player.global_position):
				item = candidate
	check(item != null, "Lebens-Item gefunden")
	if item:
		player.global_position = item.global_position + Vector3(0, -0.5, 0)
		player.velocity = Vector3.ZERO
		check(await wait_for(func(): return player.health.health > 50.0, 6.0), "Client bekommt Leben aus dem Item (%d HP)" % player.health.health)
		check(not item.is_active, "Item ist beim Client weg")

	var count_tracers := func() -> int: return current_scene.find_children("*", "Tracer", false, false).size()
	check(await wait_for(func(): return count_tracers.call() > 0, 8.0), "Client sieht die Schuesse des Hosts")
	check(await wait_for(func(): return gm.current_state == gm.GameState.GAME_OVER, 8.0), "Matchende kommt vom Host")

	await create_timer(0.5).timeout
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	net.leave()
	quit(1 if fails > 0 else 0)
