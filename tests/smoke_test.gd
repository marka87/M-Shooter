extends SceneTree

# Automatischer Rauchtest: laedt die Arena und spielt Kampf, Tod, Respawn, Pickups und Pause durch.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test.gd
# Exit-Code 0 = alles bestanden.
# Hinweis: Klassen wie Bot oder Player hier nicht direkt nennen. Sonst werden ihre Skripte
# kompiliert, bevor der Autoload GameManager existiert, und der Test bricht ab.

var fails := 0

func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	run()

func aim_at(player: Node3D, target: Vector3) -> void:
	var flat := Vector3(target.x, player.global_position.y, target.z)
	player.look_at(flat, Vector3.UP)
	player.camera_pitch = 0.0
	player.head.rotation.x = 0.0

func fire_for(wm, sec: float) -> void:
	var t := 0.0
	while t < sec:
		wm.fire_current_weapon()
		await physics_frame
		t += 1.0 / 120.0

func run() -> void:
	# Einen Frame warten: Erst dann hat der GameManager die gespeicherten Einstellungen geladen
	await process_frame
	var gm = root.get_node_or_null("GameManager")
	check(gm != null, "GameManager-Autoload vorhanden")
	if gm == null:
		quit(1)
		return
	# Testwerte setzen, die echten Einstellungen am Ende wiederherstellen
	var orig_bot_count: int = gm.bot_count
	var orig_bot_skill: int = gm.bot_skill
	gm.bot_count = 2
	gm.bot_skill = 4
	# Ohne Countdown und Limits, sonst endet das Match mitten im Test
	var orig_frag_limit: int = gm.frag_limit
	var orig_time_limit: float = gm.time_limit_minutes
	gm.match_countdown = 0.0
	gm.frag_limit = 0
	gm.time_limit_minutes = 0.0
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await wait(1.5)

	var player = gm.current_player
	check(is_instance_valid(player), "Spieler registriert")
	var bots := get_nodes_in_group("enemies")
	check(bots.size() == gm.bot_count, "Bot-Anzahl aus Einstellungen (%d)" % bots.size())
	check(bots[0].inaccuracy_degrees == bots[0].SKILL_PRESETS[4].inaccuracy and bots[0].reaction_time == bots[0].SKILL_PRESETS[4].reaction, "Schwierigkeit 'Gott' uebernommen")
	check(bots[0].display_name == "Vex" and bots[1].display_name == "Kortex", "Bot-Namen vergeben")
	print("Ticks/s: ", Engine.physics_ticks_per_second, "  Physik: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	# Bots patrouillieren?
	var b1 = bots[0]
	var start_pos: Vector3 = b1.global_position
	await wait(3.0)
	print("Bot1 bewegt: ", start_pos.distance_to(b1.global_position), " m, Zustand ", b1.current_state, ", Ziel ", b1.patrol_target)

	# MG auf Bot
	var wm = player.weapon_manager
	for b in bots:
		b.set_physics_process(false)
	b1.velocity = Vector3.ZERO
	var clear := false
	for ang in [0.0, 90.0, 180.0, 270.0, 45.0, 135.0, 225.0, 315.0]:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ang))
		b1.global_position = player.global_position + dir * 5.0
		await physics_frame
		await physics_frame
		aim_at(player, b1.global_position)
		await physics_frame
		var cam: Camera3D = player.camera
		var q0 := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 50.0, Layers.HITTABLE)
		q0.exclude = [player.get_rid()]
		if cam.get_world_3d().direct_space_state.intersect_ray(q0).get("collider") == b1:
			clear = true
			break
	check(clear, "Freie Schussbahn zum Bot gefunden")
	wm.switch_to_weapon(0)
	var hp_before: float = b1.health.health
	var ammo_before: int = wm.get_current_weapon().current_ammo
	await fire_for(wm, 1.0)
	var shots: int = ammo_before - wm.get_current_weapon().current_ammo
	print("MG-Schuesse in 1 s: ", shots)
	check(shots >= 10 and shots <= 12, "MG-Feuerrate ~11/s (%d)" % shots)
	check(b1.health.health < hp_before, "MG trifft Bot (%.0f -> %.0f)" % [hp_before, b1.health.health])

	# Railgun toetet Bot
	b1.health.health = 50.0
	if b1.current_state == b1.State.DEAD:
		b1._respawn()
		b1.global_position = player.global_position - player.global_transform.basis.z * 5.0
		b1.health.health = 50.0
		b1.set_physics_process(false)
		await physics_frame
	# Shotgun: alle Kugeln auf 5 m in einem einzigen Treffer zusammengefasst
	b1.health.health = 100.0
	var dmg_events: Array = []
	var on_dmg := func(info: DamageInfo, _lost: float): dmg_events.append(info.amount)
	b1.health.damaged.connect(on_dmg)
	wm.switch_to_weapon_id(&"shotgun")
	await wait(0.2)
	check(wm.get_current_weapon().weapon_name == "Shotgun", "Taste 2 = Shotgun")
	wm.fire_current_weapon()
	await physics_frame
	b1.health.damaged.disconnect(on_dmg)
	print("Shotgun-Treffer: ", dmg_events)
	check(dmg_events.size() == 1 and dmg_events[0] >= 45.0, "Shotgun: ein Treffer mit >= 45 Schaden")

	b1.health.health = 50.0
	var frags_before: int = gm.player_frags
	wm.switch_to_weapon_id(&"railgun")
	await wait(0.2)
	wm.fire_current_weapon()
	await physics_frame
	check(b1.current_state == b1.State.DEAD, "Railgun toetet Bot")
	check(gm.player_frags == frags_before + 1, "Frag gezaehlt (%d)" % gm.player_frags)
	var feed: VBoxContainer = player.hud.kill_feed
	check(feed.get_child_count() >= 1 and b1.display_name in feed.get_child(feed.get_child_count() - 1).text, "Killfeed zeigt Abschuss")
	var board: Array = gm.get_scoreboard()
	check(board.size() == 3 and board[0].name == player.display_name, "Scoreboard: 3 Eintraege, Spieler vorn")

	# Koerpertreffer mit 100 Schaden -> Ragdoll faellt um; Kopf landet nahe am Boden.
	# (Der Railgun-Schuss oben war auf Augenhoehe ein Kopftreffer mit 150 Schaden -> Gib.)
	b1._respawn()
	b1.set_physics_process(false)
	b1.take_damage(DamageInfo.create(100.0, player, b1.global_position + Vector3(0, 1.0, 0), Vector3.FORWARD, "Test"))
	check(b1.model.visible and b1.ragdoll.is_simulating_physics(), "Bot faellt als Ragdoll um")
	await wait(2.0)
	# Die Waffe haengt am Handknochen und zeigt so, dass das sichtbare Modell dem Ragdoll folgt
	var head_y: float = b1.ragdoll.get_node("Rag_DEF-head").global_position.y - b1.global_position.y
	var gun_y: float = b1.gun_mesh.global_position.y - b1.global_position.y
	check(head_y < 0.7 and gun_y < 0.7, "Ragdoll liegt am Boden (Kopf %.2f m, Waffe %.2f m hoch)" % [head_y, gun_y])
	b1._respawn()
	b1.set_physics_process(false)
	check(not b1.ragdoll.is_simulating_physics() and b1.anim_tree.active, "Respawn beendet den Ragdoll")
	# Grosser Treffer -> Wuerfel statt Ragdoll
	b1.take_damage(DamageInfo.create(200.0, player, b1.global_position, Vector3.FORWARD, "Test"))
	check(not b1.model.visible and not b1.ragdoll.is_simulating_physics(), "Grosser Treffer: Bot zerplatzt (Gib)")
	b1._respawn()
	b1.set_physics_process(false)
	# Bots bleiben bis zum Bot-gegen-Bot-Test eingefroren, sonst stoeren sie die folgenden Pruefungen

	# Rocket-Jump: nach unten schiessen
	wm.switch_to_weapon_id(&"rocket_launcher")
	await wait(0.3)
	player.camera_pitch = deg_to_rad(-89.0)
	player.head.rotation.x = player.camera_pitch
	var hp_p: float = player.health.health + player.health.armor
	wm.fire_current_weapon()
	var max_vy := 0.0
	for i in 60:
		await physics_frame
		max_vy = max(max_vy, player.velocity.y)
	print("Rocket-Jump max. vy: ", max_vy, "  HP+Armor: ", hp_p, " -> ", player.health.health + player.health.armor)
	check(max_vy > 5.0, "Rocket-Jump hebt Spieler an")
	check(player.health.health + player.health.armor < hp_p, "Eigenschaden durch Rakete")
	player.camera_pitch = 0.0
	player.head.rotation.x = 0.0

	# FOV aus den Einstellungen
	check(absf(player.camera.fov - gm.fov) < 0.01, "FOV angewendet (%.0f)" % player.camera.fov)

	# Jump-Pad: Spieler landet auf der Turm-Plattform
	var pad: Node3D = current_scene.get_node("JumpPads/PadTower")
	var tower_target: Vector3 = current_scene.get_node("JumpPads/TowerTarget").global_position
	player.velocity = Vector3.ZERO
	player.global_position = pad.global_position + Vector3(0, 0.3, 0)
	await wait(3.0)
	var flat_dist := Vector2(player.global_position.x - tower_target.x, player.global_position.z - tower_target.z).length()
	print("Jump-Pad Landung: ", player.global_position, " Abstand zum Ziel ", flat_dist)
	check(player.global_position.y > 5.5 and flat_dist < 3.0, "Jump-Pad bringt Spieler auf den Turm")

	# Pickup: Health
	player.health.health = 40.0
	var health_pickup: Node3D = null
	for item in current_scene.get_node("Items").get_children():
		if item.pickup_type == item.PickupType.HEALTH:
			health_pickup = item
			break
	player.global_position = health_pickup.global_position - Vector3(0, 0.5, 0)
	await wait(0.5)
	check(player.health.health > 40.0, "Health-Pickup wirkt (%.0f)" % player.health.health)
	check(not health_pickup.is_active, "Pickup danach inaktiv")

	# HUD zeigt die Lebenspunkte
	check(player.hud.health_label.text == str(int(player.health.health)), "HUD zeigt HP (%s)" % player.hud.health_label.text)

	# Munitionskiste: nur einsammeln, wenn etwas fehlt
	var ammo_box: Node3D = null
	for item in current_scene.get_node("Items").get_children():
		if item.pickup_type == item.PickupType.AMMO_BOX:
			ammo_box = item
			break
	for w in wm.weapons:
		w.current_ammo = w.max_ammo
	player.global_position = ammo_box.global_position - Vector3(0, 0.5, 0)
	await wait(0.5)
	check(ammo_box.is_active, "Volle Munition: Kiste bleibt liegen")
	player.global_position = Vector3(0, 30, 0)
	await wait(0.2)
	var rail = wm.get_weapon(&"railgun")
	rail.current_ammo = 1
	player.global_position = ammo_box.global_position - Vector3(0, 0.5, 0)
	await wait(0.5)
	check(not ammo_box.is_active, "Munitionskiste eingesammelt")
	check(rail.current_ammo == 1 + rail.data.ammo_box_amount, "Railgun +%d Munition (%d)" % [rail.data.ammo_box_amount, rail.current_ammo])
	check(wm.get_current_weapon().weapon_name == player.hud.weapon_name_label.text, "HUD zeigt aktive Waffe")

	# Tod durch Bot und Respawn
	var b2 = bots[1]
	var bot_frags_before: int = gm.bot_frags
	player.take_damage(DamageInfo.create(1000.0, b2, player.global_position, Vector3.ZERO, "Test"))
	check(player.is_dead, "Spieler stirbt")
	check(gm.bot_frags == bot_frags_before + 1, "Bot-Frag gezaehlt (%d)" % gm.bot_frags)

	# Pause waehrend des Todes: Respawn darf nicht weiterlaufen
	gm.current_state = gm.GameState.PLAYING
	gm.toggle_pause()
	check(paused, "Pause aktiv")
	check(gm._pause_layer.visible, "Pause-Menue sichtbar")
	check(player.hud.death_overlay.visible, "Todes-Overlay sichtbar")
	await wait(4.0)
	check(player.is_dead, "Respawn wartet waehrend Pause")
	gm.toggle_pause()
	for b in bots:
		b.set_physics_process(false)
	await wait(3.5)
	check(not player.is_dead, "Respawn nach Pause")
	check(player.health.armor == player.health.start_armor, "Start-Ruestung nach Respawn")

	# Spawn: Der gewaehlte Punkt liegt weit weg von allen anderen Kaempfern
	var spawn_pos: Vector3 = gm.get_spawn_transform(player).origin
	var nearest := INF
	for b in bots:
		if not b.health.is_dead:
			nearest = minf(nearest, spawn_pos.distance_to(b.global_position))
	check(nearest > 15.0, "Spawn weit weg von Bots (%.0f m)" % nearest)

	# Jeder gegen jeden: Bots greifen sich gegenseitig an, wenn der Spieler nicht zu sehen ist
	player.remove_from_group("player")
	var bot_hits: Array = []
	var on_bot_hit := func(info: DamageInfo, _lost: float):
		if is_instance_valid(info.attacker) and info.attacker.is_in_group("enemies"):
			bot_hits.append(info.attacker.display_name)
	for b in bots:
		if b.health.is_dead:
			b._respawn()
		b.health.damaged.connect(on_bot_hit)
		b.set_physics_process(true)
	bots[0].global_position = Vector3(-35, 1.0, 30)
	bots[1].global_position = Vector3(-35, 1.0, 12)
	await wait(5.0)
	for b in bots:
		b.health.damaged.disconnect(on_bot_hit)
	player.add_to_group("player")
	print("Bot-gegen-Bot-Treffer: ", bot_hits.size())
	check(bot_hits.size() > 0, "Bots kaempfen gegeneinander (%d Treffer)" % bot_hits.size())

	# Einstellungen (echte Werte wiederherstellen, damit der Test sie nicht ueberschreibt)
	gm.bot_count = orig_bot_count
	gm.bot_skill = orig_bot_skill
	gm.frag_limit = orig_frag_limit
	gm.time_limit_minutes = orig_time_limit
	gm.save_settings()
	check(FileAccess.file_exists("user://settings.cfg"), "Einstellungen gespeichert")

	# Sound-Daten signed: Stille nahe 0
	var snd: AudioStream = SoundGenerator.create_hitsound()
	check(snd == SoundGenerator.create_hitsound(), "Sound-Cache liefert dieselbe Instanz")

	# Pools: Funken bleiben bei Dauerfeuer begrenzt, abgelaufene Leuchtspuren werden wiederverwendet
	var count_sparks := func() -> int: return current_scene.find_children("*", "HitSpark", false, false).size()
	var sparks_before: int = count_sparks.call()
	for i in 80:
		HitSpark.spawn(current_scene, Vector3(i * 0.1, 0.0, 40.0), Vector3.UP)
	check(count_sparks.call() <= HitSpark.MAX_DECALS, "Funken-Pool begrenzt (%d -> %d)" % [sparks_before, count_sparks.call()])
	await wait(0.5)
	var count_tracers := func() -> int: return current_scene.find_children("*", "Tracer", false, false).size()
	var tracers_before: int = count_tracers.call()
	for i in 5:
		Tracer.spawn(current_scene, Vector3(0, 2, 0), Vector3(0, 2, -10), Color.WHITE)
		await wait(0.2)
	check(count_tracers.call() <= tracers_before + 1, "Leuchtspuren werden wiederverwendet (%d -> %d)" % [tracers_before, count_tracers.call()])

	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
