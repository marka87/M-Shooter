extends SceneTree

# Prueft die Weltraum-Arena Orbital Void:
# - Map-Laden, 8 Spawnpunkte, Navmesh
# - Begehbarkeit der Plattformen und Rampen
# - Jump-Pad Flugbahnen (Spire, Flanken, Rueckkehr)
# - Aufsammeln von Railgun, Rocket Launcher, Mega-Health
# - Tödliche Void-Kill-Zone beim Sturz in den Abgrund
# - Bot-Spawn und Bot-Abschuss ueber dem Abgrund
#
# Start: Godot_console.exe --headless --path . -s res://tests/orbital_void_test.gd

var fails := 0


func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	run()


## Laeuft seconds lang in eine Richtung
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
	var gm = root.get_node_or_null("GameManager")
	check(gm != null, "GameManager-Autoload vorhanden")
	if gm == null:
		quit(1)
		return

	gm.bot_count = 1
	gm.match_countdown = 0.0
	gm.frag_limit = 0
	gm.time_limit_minutes = 0.0
	gm.reset_game()
	change_scene_to_file("res://levels/orbital_void.tscn")
	await create_timer(1.2).timeout

	var current_scene = root.get_node("OrbitalVoid")
	var player = gm.current_player
	check(player != null, "Spieler in Orbital Void instanziiert")
	check(gm.spawn_points.size() == 8, "8 Spawnpunkte vorhanden (%d)" % gm.spawn_points.size())

	# Hinweis: Bot ohne statischen Typ ansprechen (verhindert GDScript-Autoload-Zirkel)
	var bots := get_nodes_in_group("enemies")
	check(bots.size() == 1, "1 Bot in der Arena vorhanden (%d)" % bots.size())
	var bot = bots[0] if bots.size() > 0 else null
	if bot:
		bot.set_physics_process(false)
		bot.global_position = Vector3(8.0, 1.0, 8.0)

	# 1. Begehbarkeit: Spieler laeuft ueber die Sued-Rampe von Base (y=0) auf Center-Terrasse (y=1.6)
	var p: Vector3 = await walk(player, Vector3(0.0, 0.2, 10.0), Vector3(0.0, 0.0, -1.0), 3.0)
	print("Spieler nach Rampe: ", p)
	check(p.y >= 1.5 and p.z < 6.0, "Rampe auf Center-Terrasse begehbar")

	# 2. Jump-Pad Katapult zur Spire-Plattform
	var pad_spire = current_scene.get_node("JumpPads/PadToSpire")
	var spire_target: Vector3 = current_scene.get_node("JumpPads/SpireTarget").global_position
	player.velocity = Vector3.ZERO
	player.global_position = pad_spire.global_position + Vector3(0, 0.3, 0)
	await create_timer(2.3).timeout
	var dist_spire: float = player.global_position.distance_to(spire_target)
	print("Landung nach PadToSpire: ", player.global_position, " (Distanz: ", dist_spire, ")")
	check(player.global_position.y >= 13.5 and dist_spire < 3.5, "Jump-Pad bringt Spieler auf den Spire")

	# 3. Railgun & Mega-Health auf Spire einsammeln
	player.global_position = Vector3(0.0, 14.5, -34.0)
	await create_timer(0.4).timeout
	var has_railgun: bool = player.weapon_manager.weapons.size() > 5 and player.weapon_manager.weapons[5].owned
	check(has_railgun, "Railgun auf Spire eingesammelt")

	# 4. Jump-Pad Rueckkehr vom Spire zur Center-Plattform
	var pad_down = current_scene.get_node("JumpPads/PadSpireDown")
	var center_target: Vector3 = current_scene.get_node("JumpPads/CenterTarget").global_position
	player.velocity = Vector3.ZERO
	player.global_position = pad_down.global_position + Vector3(0, 0.3, 0)
	await create_timer(2.3).timeout
	var dist_down: float = player.global_position.distance_to(center_target)
	print("Landung nach PadSpireDown: ", player.global_position, " (Distanz: ", dist_down, ")")
	check(player.global_position.y < 3.5 and dist_down < 4.0, "Jump-Pad bringt Spieler vom Spire zurueck")

	# 5. Jump-Pad zur West-Flanke
	var pad_west = current_scene.get_node("JumpPads/PadToWest")
	var west_target: Vector3 = current_scene.get_node("JumpPads/WestTarget").global_position
	player.velocity = Vector3.ZERO
	player.global_position = pad_west.global_position + Vector3(0, 0.3, 0)
	await create_timer(1.8).timeout
	var dist_west: float = player.global_position.distance_to(west_target)
	print("Landung auf West-Flanke: ", player.global_position, " (Distanz: ", dist_west, ")")
	check(player.global_position.y >= 3.0 and dist_west < 3.5, "Jump-Pad zur West-Flanke funktioniert")

	# 6. Jump-Pad von West-Flanke zurueck zur Center-Plattform
	var pad_from_west = current_scene.get_node("JumpPads/PadFromWest")
	var center_west_target: Vector3 = current_scene.get_node("JumpPads/CenterWestTarget").global_position
	player.velocity = Vector3.ZERO
	player.global_position = pad_from_west.global_position + Vector3(0, 0.3, 0)
	await create_timer(1.8).timeout
	var dist_back: float = player.global_position.distance_to(center_west_target)
	print("Landung von West-Flanke zurueck: ", player.global_position, " (Distanz: ", dist_back, ")")
	check(dist_back < 3.5, "Jump-Pad von West-Flanke zurueck zur Mitte")

	# 7. Void Kill Zone: Sturz in den Abgrund
	var deaths_before: int = gm.scores[gm._name_of(player)].deaths
	player.velocity = Vector3(0.0, -10.0, 0.0)
	player.global_position = Vector3(0.0, -15.0, 0.0)
	await create_timer(1.0).timeout
	var deaths_after: int = gm.scores[gm._name_of(player)].deaths
	check(deaths_after > deaths_before or player.health.is_dead, "Void-Kill-Zone toetet Spieler bei Fall ins All")

	# 8. Bot-Kampf & Ragdoll im Weltraum
	if bot:
		bot.set_physics_process(true)
		bot.global_position = Vector3(0.0, 1.8, 0.0)
		await create_timer(0.5).timeout
		var dmg := DamageInfo.create(150.0, player, bot.global_position, Vector3(0, 0.5, -1.0).normalized(), "Railgun")
		bot.take_damage(dmg)
		await create_timer(0.5).timeout
		check(bot.health.is_dead, "Bot stirbt bei Railgun-Treffer")

	print("FEHLER: ", fails)
	quit(fails)
