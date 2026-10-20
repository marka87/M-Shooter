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
	var orig_frag_limit: int = gm.frag_limit
	var orig_time_limit: float = gm.time_limit_minutes
	gm.bot_count = 1
	gm.match_countdown = 0.0
	gm.frag_limit = 0
	gm.time_limit_minutes = 0.0
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

	# Quad Damage auf der Mittelplattform: Spieler sammelt es ein, Schaden x3
	var quad: Node3D = current_scene.get_node("Items/QuadCenter")
	player.velocity = Vector3.ZERO
	player.global_position = quad.global_position - Vector3(0, 0.8, 0)
	await create_timer(0.5).timeout
	check(player.powerups.has_quad, "Quad Damage eingesammelt (%.0f s)" % player.powerups.quad_time_left)
	check(not quad.is_active, "Quad-Pickup danach weg")
	var probe := DamageInfo.create(10.0, player, Vector3.ZERO, Vector3.ZERO, "Test")
	check(is_equal_approx(probe.amount, 30.0), "Quad verdreifacht Schaden (%.0f)" % probe.amount)
	player.powerups.clear()

	# Mega Health auf dem Suedwest-Turm: Leben ueber 100, danach langsamer Abbau
	var mega: Node3D = current_scene.get_node("Items/MegaTowerSW")
	player.velocity = Vector3.ZERO
	player.global_position = mega.global_position - Vector3(0, 0.8, 0)
	await create_timer(0.5).timeout
	var hp_after: float = player.health.health
	check(hp_after > 150.0, "Mega Health hebt Leben ueber 100 (%.0f)" % hp_after)
	await create_timer(2.0).timeout
	check(player.health.health < hp_after, "Ueberheilung baut sich ab (%.1f)" % player.health.health)
	player.health.reset()

	# --- Neue Waffen ---
	var wm = player.weapon_manager
	var target_bot = bots[0]
	# Im Test schnell respawnen, damit der Bot nach einem Kill gleich wieder Ziel sein kann
	target_bot.respawn_delay = 0.2
	check(not wm.get_weapon(&"plasma").owned, "Plasma am Anfang nicht im Besitz")
	wm.switch_to_weapon_id(&"plasma")
	check(wm.get_current_weapon().weapon_id != &"plasma", "Wechsel zu fehlender Waffe wird ignoriert")

	# Plasma einsammeln (Nord-Ring) -> Besitz und automatischer Wechsel
	player.velocity = Vector3.ZERO
	player.global_position = current_scene.get_node("Items/PlasmaRingN").global_position - Vector3(0, 0.9, 0)
	await create_timer(0.4).timeout
	check(wm.get_current_weapon().weapon_id == &"plasma", "Plasma eingesammelt und ausgeruestet")

	# Schiessstand am Boden: Spieler bei x=-10, Bot 6 m weiter westlich
	var stand := func():
		if target_bot.health.is_dead:
			await create_timer(0.5).timeout
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(-10, 0.05, 0)
		player.look_at(Vector3(-20, 0.05, 0), Vector3.UP)
		player.camera_pitch = 0.0
		player.head.rotation.x = 0.0
		target_bot.global_position = Vector3(-16, 0.05, 0)
		target_bot.velocity = Vector3.ZERO
		target_bot.health.reset()
	await stand.call()
	await create_timer(0.3).timeout
	var plasma_hits: Array = []
	var on_plasma := func(info: DamageInfo, _lost: float): plasma_hits.append(info.amount)
	target_bot.health.damaged.connect(on_plasma)
	for i in 60:
		wm.fire_current_weapon()
		await physics_frame
	await create_timer(0.4).timeout
	target_bot.health.damaged.disconnect(on_plasma)
	print("Plasma-Treffer: ", plasma_hits.size())
	check(plasma_hits.size() >= 3, "Plasma-Bolzen treffen (%d Treffer)" % plasma_hits.size())

	# Lightning Gun (Boden Ost) einsammeln und 0,5 s auf den Bot halten
	player.velocity = Vector3.ZERO
	player.global_position = current_scene.get_node("Items/LightningGroundE").global_position - Vector3(0, 0.9, 0)
	await create_timer(0.4).timeout
	check(wm.get_current_weapon().weapon_id == &"lightning", "Lightning Gun eingesammelt")
	await stand.call()
	await create_timer(0.3).timeout
	for i in 60:
		wm.fire_current_weapon()
		await physics_frame
	print("Bot-HP nach Lightning: ", target_bot.health.health)
	check(target_bot.health.health <= 100.0 - 50.0 or target_bot.health.is_dead, "Lightning Gun Dauerstrahl trifft (%.0f HP)" % target_bot.health.health)

	# Shock Rifle (Sued-Ring): Strahl und Combo
	player.velocity = Vector3.ZERO
	player.global_position = current_scene.get_node("Items/ShockRingS").global_position - Vector3(0, 0.9, 0)
	await create_timer(0.4).timeout
	check(wm.get_current_weapon().weapon_id == &"shock_rifle", "Shock Rifle eingesammelt")
	await stand.call()
	await create_timer(1.0).timeout
	wm.fire_current_weapon()
	await physics_frame
	check(is_equal_approx(target_bot.health.health, 55.0), "Shock-Strahl trifft (%.0f HP)" % target_bot.health.health)

	await stand.call()
	await create_timer(1.0).timeout
	var combo_kills: Array = []
	var on_kill := func(k, v, w): combo_kills.append(w)
	gm.kill_registered.connect(on_kill)
	wm.fire_current_weapon_alt()
	check(get_nodes_in_group("shock_balls").size() == 1, "Shock-Kugel abgefeuert")
	await create_timer(0.3).timeout
	var shock = wm.get_current_weapon()
	shock.cooldown_timer = 0.0
	wm.fire_current_weapon()
	await create_timer(0.3).timeout
	gm.kill_registered.disconnect(on_kill)
	print("Combo: Kugeln uebrig ", get_nodes_in_group("shock_balls").size(), ", Kills ", combo_kills, ", Bot-HP ", target_bot.health.health)
	check(get_nodes_in_group("shock_balls").is_empty(), "Strahl zuendet die Kugel")
	check("Shock-Combo" in combo_kills, "Shock-Combo toetet den Bot")

	# Tod: neue Waffen sind weg, zurueck zum MG
	player.take_damage(DamageInfo.create(1000.0, target_bot, player.global_position, Vector3.ZERO, "Test"))
	await create_timer(3.5).timeout
	check(not wm.get_weapon(&"shock_rifle").owned and wm.current_weapon_index == 0, "Nach Respawn nur Start-Waffen")
	if target_bot.health.is_dead:
		target_bot._respawn()
	target_bot.set_physics_process(false)

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
	bot.target = null
	bot._switch_state(bot.State.PATROL)
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

	# Bot holt sich das Quad Damage, sobald es wieder da ist
	quad._respawn()
	await create_timer(0.2).timeout
	bot.global_position = Vector3(0, 0.1, 18)
	bot.velocity = Vector3.ZERO
	bot.target = null
	bot.patrol_wait_timer = 0.0
	bot._switch_state(bot.State.PATROL)
	var got_quad := false
	for i in 50:
		await create_timer(0.5).timeout
		if bot.patrol_wait_timer > 0.0:
			bot.patrol_wait_timer = 0.0
		if bot.powerups.has_quad:
			got_quad = true
			break
	print("Bot nach Quad-Suche: ", bot.global_position, " Zustand ", bot.current_state, " Ziel ", bot.patrol_target,
		" Item ", bot.patrol_item.name if is_instance_valid(bot.patrol_item) else "-", " Quad aktiv ", quad.is_active,
		" geflogen ", bot.is_launched, " tot ", bot.health.is_dead)
	check(got_quad, "Bot holt sich Quad Damage")
	player.add_to_group("player")

	gm.bot_count = orig_count
	gm.frag_limit = orig_frag_limit
	gm.time_limit_minutes = orig_time_limit
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
