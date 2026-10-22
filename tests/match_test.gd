extends SceneTree

# Match-Ablauf: Countdown, Einfrieren, Fraglimit, Multi-Kill-Ansage, Siegerbildschirm,
# Neustart, Zeitlimit, Instagib, Kopftreffer, zurueck ins Hauptmenue.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/match_test.gd
# Exit-Code 0 = alles bestanden.

var fails := 0


func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	run()


func run() -> void:
	# Einen Frame warten: Erst dann hat der GameManager die gespeicherten Einstellungen geladen
	await process_frame
	var gm = root.get_node("GameManager")
	var orig := [gm.bot_count, gm.frag_limit, gm.time_limit_minutes, gm.match_countdown]

	# --- Countdown und Fraglimit ---
	gm.bot_count = 1
	gm.frag_limit = 2
	gm.time_limit_minutes = 0.0
	gm.match_countdown = 1.0
	var ticks: Array = []
	var on_tick := func(n: int): ticks.append(n)
	gm.countdown_tick.connect(on_tick)
	var announcements: Array = []
	var on_announce := func(text: String, _c: Color): announcements.append(text)
	gm.player_announcement.connect(on_announce)

	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await process_frame
	await process_frame
	var player = gm.current_player
	var bot = get_nodes_in_group("enemies")[0]
	bot.respawn_delay = 0.2
	check(gm.current_state == gm.GameState.COUNTDOWN, "Match startet mit Countdown")

	# Im Countdown: nicht laufen, nicht schiessen
	var start_pos: Vector3 = player.global_position
	var ammo_before: int = player.weapon_manager.get_current_weapon().current_ammo
	Input.action_press("move_forward")
	for i in 30:
		player.weapon_manager.fire_current_weapon()
		await physics_frame
	Input.action_release("move_forward")
	var moved: float = Vector2(player.global_position.x - start_pos.x, player.global_position.z - start_pos.z).length()
	check(moved < 0.05, "Im Countdown keine Bewegung (%.2f m)" % moved)
	check(player.weapon_manager.get_current_weapon().current_ammo == ammo_before, "Im Countdown kein Schuss")

	await create_timer(1.2).timeout
	check(gm.current_state == gm.GameState.PLAYING, "Nach dem Countdown laeuft das Match")
	check(ticks == [1, 0], "Countdown-Ansagen 1 und FIGHT (%s)" % str(ticks))

	# Zwei Kills schnell hintereinander -> DOUBLE KILL und Fraglimit 2 erreicht
	bot.take_damage(DamageInfo.create(500.0, player, bot.global_position, Vector3.ZERO, "Railgun"))
	await create_timer(0.5).timeout
	bot.take_damage(DamageInfo.create(500.0, player, bot.global_position, Vector3.ZERO, "Railgun"))
	await process_frame
	await process_frame
	check("DOUBLE KILL" in announcements, "Ansage DOUBLE KILL (%s)" % str(announcements))
	check(gm.current_state == gm.GameState.GAME_OVER, "Fraglimit beendet das Match")
	check(paused, "Spiel angehalten am Matchende")
	var screen = gm._match_end_layer
	check(is_instance_valid(screen) and screen.title_label.text == "SIEG!", "Siegerbildschirm zeigt SIEG!")
	check(is_instance_valid(screen) and screen.grid.get_child_count() == 5 * 3, "Rangliste mit 2 Teilnehmern")
	check(is_instance_valid(screen) and screen.stats_grid.get_child_count() == 12, "Spieler-Statistik mit 6 Werten")
	if is_instance_valid(screen):
		print("Untertitel: ", screen.subtitle_label.text)

	# --- Nochmal: gleiches Level neu, alles zurueckgesetzt ---
	gm.restart_match()
	await process_frame
	await process_frame
	await process_frame
	check(not paused, "Neustart hebt die Pause auf")
	check(gm.player_frags == 0 and gm.current_state == gm.GameState.COUNTDOWN, "Neustart: Frags 0, neuer Countdown")
	check(not is_instance_valid(screen), "Siegerbildschirm geschlossen")

	# --- Zeitlimit (ca. 1,8 s) ---
	gm.match_countdown = 0.0
	gm.time_limit_minutes = 0.03
	gm.frag_limit = 0
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await create_timer(2.5).timeout
	check(gm.current_state == gm.GameState.GAME_OVER, "Zeitlimit beendet das Match")
	screen = gm._match_end_layer
	check(is_instance_valid(screen) and "Zeitlimit" in screen.subtitle_label.text, "Grund: Zeitlimit")

	# --- Instagib: nur Railgun, unendliche Munition, ein Treffer toetet, keine Items ---
	# Das Zeitlimit hat das Spiel angehalten; im Spiel geht es danach ueber das Menue weiter
	paused = false
	gm.instagib = true
	gm.duel = true
	gm.bot_count = 3
	gm.time_limit_minutes = 0.0
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await create_timer(0.5).timeout
	check(get_nodes_in_group("enemies").size() == 1, "Duell: genau ein Bot (trotz 3 eingestellt)")
	gm.duel = false
	gm.bot_count = 1
	player = gm.current_player
	bot = get_nodes_in_group("enemies")[0]
	bot.set_physics_process(false)
	var wm = player.weapon_manager
	var owned_ids: Array = wm.weapons.filter(func(w): return w.owned).map(func(w): return w.weapon_id)
	check(owned_ids == [&"railgun"] and wm.get_current_weapon().weapon_id == &"railgun", "Instagib: nur Railgun (%s)" % [owned_ids])
	var items: Array = current_scene.find_children("*", "Area3D", true, false).filter(func(a): return a.has_method("is_useful_for"))
	check(items.all(func(i): return not i.visible and not i.is_active), "Instagib: keine Items (%d versteckt)" % items.size())
	check(bot.weapon_manager.current.weapon_id == &"railgun" and bot.weapon_manager.weapons.filter(func(w): return w.owned).size() == 1, "Instagib: Bots nur mit Railgun")
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	# 3 m vor dem Spieler (in 5 m steht in der Testarena eine Rampe)
	bot.global_position = player.global_position + Vector3(0, 0, -3)
	# Zwei Frames: Nach dem Entpausieren uebernimmt die Physik die neue Position erst einen Frame spaeter
	await physics_frame
	await physics_frame
	var rail_ammo: int = wm.get_current_weapon().current_ammo
	wm.fire_current_weapon()
	await physics_frame
	check(bot.current_state == bot.State.DEAD, "Instagib: ein Treffer toetet")
	check(wm.get_current_weapon().current_ammo == rail_ammo, "Instagib: unendliche Munition")
	gm.instagib = false

	# --- Kopftreffer: Railgun auf Augenhoehe trifft den Kopf (1,5x Schaden, Ansage), tiefer den Koerper ---
	announcements.clear()
	var hits: Array = []
	var on_hit := func(info: DamageInfo, _lost: float): hits.append([info.amount, info.is_headshot])
	for pitch_deg in [-11.0, 0.0]:
		await create_timer(1.3).timeout  # Railgun-Abklingzeit
		bot._respawn()
		bot.set_physics_process(false)
		bot.global_position = player.global_position + Vector3(0, 0, -3)
		bot.health.damaged.connect(on_hit)
		player.camera_pitch = deg_to_rad(pitch_deg)
		player.head.rotation.x = player.camera_pitch
		await physics_frame
		await physics_frame
		wm.fire_current_weapon()
		await physics_frame
		bot.health.damaged.disconnect(on_hit)
	print("Treffer [Schaden, Kopf]: ", hits)
	check(hits.size() == 2 and hits[0] == [100.0, false], "Koerpertreffer: 100 Schaden")
	check(hits.size() == 2 and hits[1] == [150.0, true], "Kopftreffer: 150 Schaden")
	check("HEADSHOT" in announcements, "Kopftreffer-Kill wird angesagt (%s)" % [announcements])
	player.camera_pitch = 0.0

	# --- Team Deathmatch: Teams ausgeglichen, kein Eigenbeschuss, Teampunkte, Fraglimit fuers Team ---
	gm.game_mode = gm.Mode.TEAM_DEATHMATCH
	gm.bot_count = 3
	gm.frag_limit = 2
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await create_timer(0.5).timeout
	player = gm.current_player
	var team_bots: Array = get_nodes_in_group("enemies")
	for b in team_bots:
		b.set_physics_process(false)
	var bot_teams: Array = team_bots.map(func(b): return b.team)
	check(player.team == gm.PLAYER_TEAM and bot_teams == [0, 1, 0], "TDM: Spieler Blau, Bots Rot/Blau/Rot (%s)" % [bot_teams])
	var mate = team_bots[1]
	var mate_hp: float = mate.health.health
	mate.take_damage(DamageInfo.create(50.0, player, mate.global_position, Vector3.ZERO, "Test"))
	check(mate.health.health == mate_hp, "TDM: kein Schaden am eigenen Team")
	check(not gm.are_teammates(player, player), "TDM: Selbsttreffer bleiben moeglich (Rocket-Jump)")
	team_bots[0].take_damage(DamageInfo.create(500.0, player, team_bots[0].global_position, Vector3.ZERO, "Test"))
	check(gm.team_scores == [0, 1], "TDM: Frag zaehlt fuers Team (%s)" % [gm.team_scores])
	team_bots[2].take_damage(DamageInfo.create(500.0, player, team_bots[2].global_position, Vector3.ZERO, "Test"))
	await process_frame
	check(gm.current_state == gm.GameState.GAME_OVER and gm.team_scores == [0, 2], "TDM: Team-Fraglimit beendet das Match")
	gm._close_match_end()

	# --- Capture the Flag: Basen, Flagge nehmen, erobern, fallen lassen, zurueckbringen ---
	gm.game_mode = gm.Mode.CTF
	gm.bot_count = 1
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await create_timer(0.5).timeout
	player = gm.current_player
	var ctf = gm.ctf
	var red_bot = get_nodes_in_group("enemies")[0]
	red_bot.set_physics_process(false)
	check(ctf != null and ctf.flags.size() == 2 and ctf.home_of(0).distance_to(ctf.home_of(1)) > 20.0, "CTF: zwei Basen weit auseinander")
	var red_flag = ctf.flags[0]
	var blue_flag = ctf.flags[1]
	player.global_position = red_flag.home
	for i in 4:
		await physics_frame
	check(red_flag.carrier == player, "CTF: Spieler nimmt die rote Flagge")
	player.global_position = blue_flag.home
	for i in 4:
		await physics_frame
	check(gm.team_scores == [0, 1] and red_flag.state == red_flag.FlagState.HOME, "CTF: Eroberung zaehlt fuer Blau (%s)" % [gm.team_scores])
	red_bot.global_position = blue_flag.home
	player.global_position = red_flag.home + Vector3(0, 0, 4)
	for i in 4:
		await physics_frame
	check(blue_flag.carrier == red_bot, "CTF: Bot nimmt die blaue Flagge")
	red_bot.take_damage(DamageInfo.create(500.0, player, red_bot.global_position, Vector3.ZERO, "Test"))
	for i in 3:
		await physics_frame
	check(blue_flag.state == blue_flag.FlagState.DROPPED, "CTF: Traeger stirbt, Flagge faellt")
	player.global_position = blue_flag.global_position
	for i in 4:
		await physics_frame
	check(blue_flag.state == blue_flag.FlagState.HOME, "CTF: eigenes Team bringt die Flagge zurueck")
	gm.game_mode = gm.Mode.DEATHMATCH
	gm.bot_count = 1

	# --- Hauptmenue ---
	gm.return_to_menu()
	await process_frame
	await process_frame
	await process_frame
	check(current_scene.name == "MainMenu" and not paused, "Zurueck im Hauptmenue, nicht pausiert")

	# Einstellungen oeffnen und mit "Zurueck" (echtes Button-Signal aus der Szene) schliessen
	var menu = current_scene
	menu._on_settings_button_pressed()
	menu.get_node("CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/BackButton").pressed.emit()
	check(not menu.settings_panel.visible and menu.main_buttons.visible, "Einstellungen: Zurueck funktioniert")
	check(menu.resolution_option.item_count == gm.RESOLUTIONS.size() and menu.mode_option.item_count == 3, "Einstellungen: Aufloesung und Fenstermodus waehlbar")

	gm.countdown_tick.disconnect(on_tick)
	gm.player_announcement.disconnect(on_announce)
	gm.bot_count = orig[0]
	gm.frag_limit = orig[1]
	gm.time_limit_minutes = orig[2]
	gm.match_countdown = orig[3]
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
