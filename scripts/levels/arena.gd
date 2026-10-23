extends Node3D

## Level-Skript fuer die Test-Arena
## Backt das Navigationsnetz, registriert die Spawnpunkte und erzeugt die Bots
## nach den Match-Einstellungen (Anzahl und Schwierigkeit) aus dem GameManager.

const BOT_SCENE: PackedScene = preload("res://scenes/bot.tscn")
const BOT_NAMES: Array[String] = ["Vex", "Kortex", "Rhea", "Nyx", "Talon", "Orbit", "Grimm",
	"Zane", "Pyra", "Echo", "Flux", "Krait", "Moxie", "Rook", "Sable"]
## Leuchtfarbe je Bot (gut unterscheidbar, keine davon nahe am Cyan des Bodens)
const BOT_COLORS: Array[Color] = [
	Color(1.0, 0.22, 0.18), Color(1.0, 0.8, 0.1), Color(0.55, 1.0, 0.2), Color(0.8, 0.3, 1.0),
	Color(1.0, 0.45, 0.05), Color(1.0, 0.3, 0.75), Color(0.95, 0.95, 0.95),
	Color(0.2, 0.9, 1.0), Color(1.0, 0.6, 0.6), Color(0.6, 0.6, 1.0), Color(0.2, 1.0, 0.6),
	Color(0.7, 0.5, 0.2), Color(1.0, 1.0, 0.5), Color(0.5, 0.2, 0.6), Color(0.4, 0.4, 0.4),
]

@onready var spawn_points_container: Node3D = $SpawnPoints


func _ready() -> void:
	# Navigationsnetz aus der Geometrie backen, damit Bots Waenden und Pfeilern ausweichen
	var nav_region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if nav_region:
		nav_region.bake_navigation_mesh(false)

	GameManager.spawn_points.clear()

	# Alle Spawnpunkte im GameManager registrieren, dazu ebenso viele aus dem Navigationsnetz
	if spawn_points_container:
		for spawn in spawn_points_container.get_children():
			if spawn is Node3D:
				GameManager.register_spawn_point(spawn)
		if nav_region:
			_add_navmesh_spawns(nav_region)

	# Capture the Flag: Basen und Flaggen vor den Bots, damit sie schon auf ihrer Haelfte spawnen
	GameManager.ctf = null
	if GameManager.game_mode == GameManager.Mode.CTF:
		var ctf := CtfManager.new()
		ctf.name = "CTF"
		add_child(ctf)
		ctf.setup()
		GameManager.ctf = ctf

	# Netzspiel: Bots laufen nur beim Host, Clients bekommen sie als Puppen (Net)
	if not Net.is_client():
		_spawn_bots()
	_add_map_reverb()
	GameManager.apply_graphics(self)
	GameManager.start_match()
	Net.on_level_ready(self)


## Bots nach Match-Einstellungen erzeugen, jeweils am freiesten Spawnpunkt
func _spawn_bots() -> void:
	var count: int = 1 if GameManager.duel and not GameManager.is_team_mode() else GameManager.bot_count
	for i in clampi(count, 0, BOT_NAMES.size()):
		var bot: Bot = BOT_SCENE.instantiate()
		bot.name = "Bot%d" % (i + 1)
		bot.display_name = BOT_NAMES[i]
		bot.skin_color = BOT_COLORS[i]
		if GameManager.is_team_mode():
			# Abwechselnd Rot und Blau; der Spieler ist Blau, so bleiben die Teams ausgeglichen
			bot.team = (i + 1 - GameManager.PLAYER_TEAM) % 2
			bot.skin_color = GameManager.TEAM_COLORS[bot.team]
		bot.personality = i % Bot.Personality.size()
		bot.apply_skill(GameManager.bot_skill)
		add_child(bot)
		bot.global_transform = GameManager.get_spawn_transform(bot)


## Abstand zwischen Spawnpunkten und zu Items, Pads, Teleportern und Schadenszonen (m)
const SPAWN_SPACING := 5.0
const SPAWN_AREA_MARGIN := 1.5


## Doppelt so viele Spawnpunkte wie von Hand gesetzt (die Maps haben genau so viele wie Spieler erlaubt):
## zufaellige begehbare Stellen aus dem gebackenen Navigationsnetz, mit Platz rundherum, weg von allen
## Area3D (Schadenszonen, Pads, Teleporter, Items, Flaggen), Blick ins Freie (_spawn_look). Fester Zufall je Map.
func _add_navmesh_spawns(nav_region: NavigationRegion3D) -> void:
	var nav := nav_region.navigation_mesh
	var verts: PackedVector3Array = nav.get_vertices()
	if verts.is_empty():
		return
	var xf := nav_region.global_transform
	# Nur das groesste zusammenhaengende Stueck (Polygone mit gemeinsamen Ecken): keine Inseln auf Daechern,
	# die Bots nicht erreichen. Dreiecke nach Flaeche gewichtet, damit grosse Flaechen oefter getroffen werden.
	var main := _largest_navmesh_part(nav)
	var tris: Array[PackedVector3Array] = []
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in main:
		var poly: PackedInt32Array = nav.get_polygon(i)
		for k in range(1, poly.size() - 1):
			var tri := PackedVector3Array([xf * verts[poly[0]], xf * verts[poly[k]], xf * verts[poly[k + 1]]])
			total += (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() * 0.5
			tris.append(tri)
			weights.append(total)
	var blocked: Array[AABB] = []
	for area: Area3D in find_children("*", "Area3D", true, false):
		if area is ReverbZone:
			continue
		for shape: CollisionShape3D in area.find_children("*", "CollisionShape3D", true, false):
			if shape.shape:
				blocked.append((shape.global_transform * _shape_box(shape.shape)).grow(SPAWN_AREA_MARGIN))
	var center := Vector3.ZERO
	for point in GameManager.spawn_points:
		center += point.global_position / GameManager.spawn_points.size()
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene_file_path)
	var wanted := GameManager.spawn_points.size()
	var added := 0
	for attempt in 800:
		if added >= wanted:
			break
		var tri: PackedVector3Array = tris[weights.bsearch(rng.randf() * total)]
		var a := rng.randf()
		var b := rng.randf()
		if a + b > 1.0:
			a = 1.0 - a
			b = 1.0 - b
		var pos: Vector3 = tri[0] + (tri[1] - tri[0]) * a + (tri[2] - tri[0]) * b + Vector3.UP
		if not _spawn_spot_ok(space, pos, blocked):
			continue
		var marker := Marker3D.new()
		marker.name = "NavSpawn%d" % added
		marker.set_meta(&"nav_spawn", true)  # CTF waehlt seine Basen nur aus den Spawns von Hand
		spawn_points_container.add_child(marker)
		marker.global_transform = Transform3D(Basis.looking_at(_spawn_look(space, pos, center)), pos)
		GameManager.register_spawn_point(marker)
		added += 1


## Reichweite fuer die Blickrichtung neuer Spawns (m)
const SPAWN_VIEW := 20.0


## Blickrichtung fuer einen Spawn: von 16 Richtungen die mit der meisten freien Strecke (_open_distance),
## leicht zur Mapmitte gezogen. So schaut man nicht gegen eine Wand oder ueber eine Kante ins Nichts.
func _spawn_look(space: PhysicsDirectSpaceState3D, pos: Vector3, center: Vector3) -> Vector3:
	var to_center := Vector3(center.x - pos.x, 0.0, center.z - pos.z).normalized()
	var dist := PackedFloat32Array()
	for i in 16:
		dist.append(_open_distance(space, pos, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)))
	var look := Vector3.FORWARD
	var best := -INF
	for i in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		# Nachbarrichtungen zaehlen halb mit, sonst steht eine Wand direkt neben der Blickachse
		var score := dist[i] + 0.5 * (dist[i - 1] + dist[(i + 1) % 16]) + 4.0 * dir.dot(to_center)
		if score > best:
			best = score
			look = dir
	return look


## Freie Strecke von pos (1 m ueber dem Boden) in Richtung dir: bis zur ersten Wand in Augenhoehe
## oder bis der Boden aufhoert (alle 2 m nach unten getastet), hoechstens SPAWN_VIEW
func _open_distance(space: PhysicsDirectSpaceState3D, pos: Vector3, dir: Vector3) -> float:
	var mask := Layers.WORLD | Layers.PROPS
	var eye := pos + Vector3.UP * 0.6
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * SPAWN_VIEW, mask))
	var wall: float = eye.distance_to(hit.position) if hit else SPAWN_VIEW
	var d := 2.0
	while d < wall:
		var p := eye + dir * d
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 6.0, mask)):
			return d
		d += 2.0
	return wall


## Polygon-Indizes des groessten zusammenhaengenden Teils des Navigationsnetzes (Union-Find ueber Ecken)
func _largest_navmesh_part(nav: NavigationMesh) -> PackedInt32Array:
	var parent := range(nav.get_polygon_count())
	var find := func(i: int) -> int:
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i
	var owner_of_vertex := {}
	for i in nav.get_polygon_count():
		for v in nav.get_polygon(i):
			if owner_of_vertex.has(v):
				parent[find.call(i)] = find.call(owner_of_vertex[v])
			else:
				owner_of_vertex[v] = i
	var groups := {}
	for i in nav.get_polygon_count():
		var root: int = find.call(i)
		if not groups.has(root):
			groups[root] = PackedInt32Array()
		groups[root].append(i)
	var best := PackedInt32Array()
	for group: PackedInt32Array in groups.values():
		if group.size() > best.size():
			best = group
	return best


## Umriss einer Kollisionsform im eigenen System (Kugel, Kapsel und Zylinder als umschliessender Quader)
func _shape_box(shape: Shape3D) -> AABB:
	var half := Vector3.ONE
	if shape is BoxShape3D:
		half = shape.size / 2.0
	elif shape is SphereShape3D:
		half = Vector3.ONE * shape.radius
	elif shape is CapsuleShape3D or shape is CylinderShape3D:
		half = Vector3(shape.radius, shape.height / 2.0, shape.radius)
	return AABB(-half, half * 2.0)


## Freier Platz (Boden darunter, Kopffreiheit, keine Wand im Weg), weit genug weg von Spawns und Area3D
func _spawn_spot_ok(space: PhysicsDirectSpaceState3D, pos: Vector3, blocked: Array[AABB]) -> bool:
	for point in GameManager.spawn_points:
		if point.global_position.distance_to(pos) < SPAWN_SPACING:
			return false
	for box in blocked:
		if box.has_point(pos):
			return false
	var mask := Layers.WORLD | Layers.PROPS
	if space.intersect_ray(PhysicsRayQueryParameters3D.create(pos, pos + Vector3.UP * 1.4, mask)):
		return false
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 1.5, mask)):
		return false
	var body := PhysicsShapeQueryParameters3D.new()
	body.shape = SphereShape3D.new()
	body.shape.radius = 0.7
	body.transform = Transform3D(Basis(), pos + Vector3.UP * 0.2)
	body.collision_mask = mask
	return space.intersect_shape(body, 1).is_empty()


## Maps ohne eigene Hall-Zonen: eine Zone ueber die ganze Map (Art aus GameManager.MAPS)
func _add_map_reverb() -> void:
	if has_node("ReverbZones"):
		return
	for map_info in GameManager.MAPS:
		if map_info.scene == scene_file_path and map_info.has("reverb"):
			var zone := ReverbZone.new()
			zone.kind = map_info.reverb
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(400.0, 200.0, 400.0)
			zone.add_child(shape)
			add_child(zone)
