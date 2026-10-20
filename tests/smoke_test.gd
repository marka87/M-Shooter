extends SceneTree

# Automatischer Rauchtest: laedt die Arena und spielt Kampf, Tod, Respawn, Pickups und Pause durch.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test.gd
# Exit-Code 0 = alles bestanden.

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
	var gm = root.get_node_or_null("GameManager")
	check(gm != null, "GameManager-Autoload vorhanden")
	if gm == null:
		quit(1)
		return
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await wait(1.5)

	var player = gm.current_player
	check(is_instance_valid(player), "Spieler registriert")
	var bots := get_nodes_in_group("enemies")
	check(bots.size() == 2, "2 Bots in der Arena (%d)" % bots.size())
	print("Ticks/s: ", Engine.physics_ticks_per_second, "  Physik: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	# Bots patrouillieren?
	var b1 = bots[0]
	var start_pos: Vector3 = b1.global_position
	await wait(3.0)
	print("Bot1 bewegt: ", start_pos.distance_to(b1.global_position), " m, Zustand ", b1.current_state, ", Ziel ", b1.patrol_target)

	# MG auf Bot
	var wm = player.weapon_manager
	b1.set_physics_process(false)
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
	b1.set_physics_process(true)

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
	check(player.hud.health_label.text == "HP: %d" % int(player.health.health), "HUD zeigt HP (%s)" % player.hud.health_label.text)

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
	player.take_damage(DamageInfo.create(1000.0, b2, player.global_position, Vector3.ZERO, "Test"))
	check(player.is_dead, "Spieler stirbt")
	check(gm.bot_frags == 1, "Bot-Frag gezaehlt (%d)" % gm.bot_frags)

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

	# Einstellungen
	gm.save_settings()
	check(FileAccess.file_exists("user://settings.cfg"), "Einstellungen gespeichert")

	# Sound-Daten signed: Stille nahe 0
	var snd: AudioStreamWAV = SoundGenerator.create_hitsound()
	check(snd == SoundGenerator.create_hitsound(), "Sound-Cache liefert dieselbe Instanz")

	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
