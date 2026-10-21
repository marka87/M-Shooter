extends SceneTree

# Bewegung und Kamera: Dodge, Wall-Dodge, Abklingzeit, Kamera-Feedback (Landung, Tempo-Sichtfeld,
# Treffer, Explosion), Abschalten der Kamera-Effekte, Waffe bei Fall und Landung, Kopf mit
# Physik-Interpolation, Hochziehen beim Waffenwechsel.
# Start (aus dem Projektordner):
#   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/movement_test.gd
# Exit-Code 0 = alles bestanden.

var fails := 0


func check(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails += 1


func _initialize() -> void:
	run()


## Spieler an eine Stelle setzen, Blick nach Norden (-Z), stillstehen lassen
func place(player, pos: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.rotation = Vector3.ZERO
	player.movement._dodge_cooldown_left = 0.0
	player.movement._last_tap.clear()
	for i in 6:
		await physics_frame


## Feste Box (Layer World) in die Szene, optional um X gekippt (Rampe)
func add_box(size: Vector3, pos: Vector3, tilt_x: float = 0.0) -> void:
	var box := StaticBody3D.new()
	box.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	box.add_child(shape)
	current_scene.add_child(box)
	box.global_position = pos
	box.rotation.x = tilt_x


## n Physik-Ticks mit fester Eingabe direkt an den MovementController
func drive(mv, wish: Vector3, jump_held: bool, ticks: int) -> void:
	for i in ticks:
		mv.step(wish, false, jump_held, false, 1.0 / 120.0)
		await physics_frame


func run() -> void:
	await process_frame
	var gm = root.get_node("GameManager")
	var orig := [gm.bot_count, gm.frag_limit, gm.time_limit_minutes, gm.match_countdown, gm.camera_effects]
	gm.bot_count = 1
	gm.frag_limit = 0
	gm.time_limit_minutes = 0.0
	gm.match_countdown = 0.0
	gm.camera_effects = true
	gm.reset_game()
	change_scene_to_file("res://levels/test_arena.tscn")
	await create_timer(0.5).timeout
	var player = gm.current_player
	for b in get_nodes_in_group("enemies"):
		b.set_physics_process(false)
		b.global_position = Vector3(0, -50, 0)

	# --- Dodge am Boden: zweimal rechts -> schnell nach rechts (+X) und etwas nach oben ---
	await place(player, Vector3(-20, 0.1, 30))
	player.movement.handle_direction_tap("move_right")
	await create_timer(0.1).timeout
	player.movement.handle_direction_tap("move_right")
	check(player.velocity.x > 12.0 and player.velocity.y > 4.0, "Dodge rechts (v = %s)" % player.velocity)
	await create_timer(0.6).timeout
	check(player.global_position.x > -15.0, "Dodge bringt ca. 5 m+ (x = %.1f)" % player.global_position.x)

	# Zu langsam getippt -> kein Dodge
	await place(player, Vector3(-20, 0.1, 30))
	player.movement.handle_direction_tap("move_left")
	await create_timer(0.4).timeout
	player.movement.handle_direction_tap("move_left")
	check(absf(player.velocity.x) < 1.0, "Langsames Doppeltippen loest keinen Dodge aus")

	# Abklingzeit: direkt nach einem Dodge kein zweiter
	await place(player, Vector3(-20, 0.1, 30))
	check(player.movement.try_dodge("move_forward"), "Dodge vorwaerts")
	check(not player.movement.try_dodge("move_backward"), "Zweiter Dodge sofort danach gesperrt")

	# --- Wall-Dodge: in der Luft mit dem Ruecken zur Nordwand (Innenseite z = -44) ---
	await place(player, Vector3(0, 3.0, -43.2))
	player.rotation = Vector3(0, PI, 0)  # Blick nach Sueden, Wand im Ruecken
	await physics_frame
	var ok_wall: bool = player.movement.try_dodge("move_forward")
	check(ok_wall and player.velocity.z > 10.0, "Wall-Dodge von der Wand weg (v = %s)" % player.velocity)
	player.movement._dodge_cooldown_left = 0.0
	check(not player.movement.try_dodge("move_forward"), "Nur ein Wall-Dodge pro Sprung")

	# Strafe-Jumping: Sprung gehalten (Bunnyhop), Eingabe fast quer zur Flugrichtung -> Tempo steigt
	# ueber das Sprint-Tempo. Der MovementController bekommt die Eingaben direkt.
	await place(player, Vector3(-30, 0.1, 30))
	player.set_physics_process(false)
	var mv = player.movement
	player.velocity = Vector3(0, 0, -8)
	for i in 150:
		var flat := Vector3(player.velocity.x, 0, player.velocity.z).normalized()
		mv.step(flat.rotated(Vector3.UP, deg_to_rad(-80.0)), false, true, false, 1.0 / 120.0)
		await physics_frame
	var strafe_speed := Vector2(player.velocity.x, player.velocity.z).length()
	player.set_physics_process(true)
	check(strafe_speed > mv.sprint_speed, "Strafe-Jumping beschleunigt ueber Sprint-Tempo (%.1f m/s)" % strafe_speed)

	# --- Stufen, Rampen, Bunnyhop: eigene Geometrie hoch ueber der Arena (Boden bei y = 40) ---
	add_box(Vector3(40, 1, 200), Vector3(70, 39.5, 0))
	add_box(Vector3(10, 0.4, 10), Vector3(55, 40.2, -8))  # Stufe 0,4 m, Vorderkante bei z = -3
	add_box(Vector3(10, 1.0, 10), Vector3(85, 40.5, -8))  # Mauer 1 m
	var slope := deg_to_rad(20.0)
	add_box(Vector3(10, 1, 80), Vector3(-60, 40, 0), slope)  # Rampe (Richtung hangab aus der Bodennormale)
	player.set_physics_process(false)

	await place(player, Vector3(55, 40.05, 0))
	await drive(mv, Vector3.FORWARD, false, 120)
	check(player.global_position.y > 40.35 and player.global_position.z < -4.0, "Stufe 0,4 m wird hochgelaufen (%s)" % player.global_position)
	await place(player, Vector3(85, 40.05, 0))
	await drive(mv, Vector3.FORWARD, false, 120)
	check(player.global_position.y < 40.2 and player.global_position.z > -3.0, "Mauer 1 m bleibt eine Mauer (%s)" % player.global_position)

	# Bunnyhop: Sprung gehalten, keine Richtung -> Tempo bleibt ueber viele Landungen erhalten
	await place(player, Vector3(70, 40.05, 80))
	player.velocity = Vector3(0, 0, -15)
	await drive(mv, Vector3.ZERO, true, 360)
	var hop_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(hop_speed > 14.9, "Bunnyhop verliert kein Tempo (15 -> %.2f m/s)" % hop_speed)

	# Rampen-Sliding: schnell hangab ohne Eingabe -> keine Reibung, die Schwerkraft beschleunigt
	await place(player, Vector3(-60, 40.5 + 30.0 * tan(slope), -10))
	await drive(mv, Vector3.ZERO, false, 120)
	var n: Vector3 = mv.body.get_floor_normal()
	var downhill := Vector3(n.x, 0, n.z).normalized()
	player.velocity = (downhill * 16.0).slide(n).normalized() * 16.0 / cos(slope)
	await drive(mv, Vector3.ZERO, false, 60)
	var slide_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(mv.body.is_on_floor() and slide_speed > 16.0, "Rampen-Sliding hangab ohne Bremsen (%.1f m/s)" % slide_speed)
	# Ramp-Jump: schnell hangauf springen -> der Schwung nach oben kommt zum Sprung dazu
	await place(player, Vector3(-60, 40.5 + 30.0 * tan(slope), -10))
	await drive(mv, Vector3.ZERO, false, 120)
	player.velocity = (-downhill * 18.0).slide(n).normalized() * 18.0 / cos(slope)
	await drive(mv, Vector3.ZERO, false, 2)
	await drive(mv, Vector3.ZERO, true, 1)
	check(player.velocity.y > mv.jump_velocity + 3.0, "Ramp-Jump hangauf springt hoeher (vy = %.1f m/s)" % player.velocity.y)
	player.set_physics_process(true)

	# In der Luft ohne Wand -> kein Dodge
	await place(player, Vector3(0, 6.0, 20))
	check(not player.movement.try_dodge("move_right"), "Kein Dodge mitten in der Luft ohne Wand")

	# --- Kamera: Landung aus der Hoehe knickt ein ---
	await place(player, Vector3(-20, 9.0, 30))
	var min_y := 0.0
	for i in 150:
		await physics_frame
		min_y = minf(min_y, player.camera.position.y)
	check(min_y < -0.08, "Kamera knickt bei der Landung ein (%.2f m)" % min_y)

	# Waffe: haengt beim Fallen nach oben, knickt bei der Landung ein
	var wm = player.weapon_manager
	await place(player, Vector3(-20, 9.0, 30))
	var weapon_max := -1.0
	var weapon_min := 1.0
	for i in 150:
		await process_frame
		weapon_max = maxf(weapon_max, wm.position.y - wm.default_pos.y)
		weapon_min = minf(weapon_min, wm.position.y - wm.default_pos.y)
	check(weapon_max > 0.015 and weapon_min < -0.03, "Waffe hebt sich im Fall und knickt bei der Landung ein (%.3f / %.3f m)" % [weapon_max, weapon_min])

	# Physik-Interpolation: Kopf folgt dem Koerper (eigene Ebene), Blick kommt von der Maus
	await place(player, Vector3(-20, 0.1, 30))
	player.camera_pitch = 0.3
	# process_frame kommt vor den _process-Aufrufen, deshalb zwei Frames
	await process_frame
	await process_frame
	var head_gap: float = player.head.global_position.distance_to(player.global_position + player._head_offset)
	check(ProjectSettings.get_setting("physics/common/physics_interpolation") and head_gap < 0.05 and is_equal_approx(player.head.global_rotation.x, 0.3), "Interpolation: Kopf folgt Koerper (%.3f m) und Mausblick" % head_gap)
	player.camera_pitch = 0.0

	# Waffenwechsel: neue Waffe kommt von unten und feuert erst, wenn sie oben ist
	wm.give_weapon(&"shotgun", 10)
	wm.switch_to_weapon_id(&"shotgun")
	await process_frame
	var shotgun = wm.get_current_weapon()
	check(shotgun.position.y < shotgun.initial_position.y - 0.1 and not shotgun.can_fire(), "Waffenwechsel: Waffe unten, noch nicht feuerbereit")
	await create_timer(0.25).timeout
	check(shotgun.position.is_equal_approx(shotgun.initial_position) and shotgun.can_fire(), "Waffenwechsel: nach 0,15 s oben und feuerbereit")

	# Tempo-Sichtfeld: schnell in der Luft -> groesseres FOV
	await place(player, Vector3(-20, 6.0, 30))
	var base_fov: float = player.camera_feedback.base_fov
	for i in 30:
		player.velocity = Vector3(26, 0, 0)
		await process_frame
	check(player.camera.fov > base_fov + 4.0, "Sichtfeld waechst mit Tempo (%.1f > %.1f)" % [player.camera.fov, base_fov])

	# Treffer ruckt die Kamera
	await place(player, Vector3(-20, 0.1, 30))
	player.take_damage(DamageInfo.create(40.0, null, player.global_position, Vector3.ZERO, "Test"))
	await process_frame
	await process_frame
	check(absf(player.camera.rotation.x) > 0.005, "Treffer ruckt die Kamera (%.3f rad)" % player.camera.rotation.x)

	# Explosion in der Naehe laesst die Kamera wackeln
	await create_timer(1.0).timeout
	var explosion: Node3D = load("res://scenes/weapons/explosion.tscn").instantiate()
	explosion.position = player.global_position + Vector3(6, 0, 0)
	current_scene.add_child(explosion)
	await process_frame
	check(player.camera_feedback._trauma > 0.1, "Explosion in der Naehe: Wackeln (%.2f)" % player.camera_feedback._trauma)

	# Kamera-Effekte aus -> Kamera bleibt ruhig
	gm.camera_effects = false
	player.camera_feedback.add_trauma(1.0)
	await process_frame
	await process_frame
	check(player.camera.position == Vector3.ZERO and is_equal_approx(player.camera.fov, base_fov), "Kamera-Effekte abschaltbar")

	gm.bot_count = orig[0]
	gm.frag_limit = orig[1]
	gm.time_limit_minutes = orig[2]
	gm.match_countdown = orig[3]
	gm.camera_effects = orig[4]
	print("FEHLER: ", fails)
	quit(1 if fails > 0 else 0)
