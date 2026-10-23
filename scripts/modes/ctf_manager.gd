extends Node3D
class_name CtfManager

## Capture the Flag (Roadmap 6.5): zwei Basen an den am weitesten entfernten Spawnpunkten, je eine Flagge.
## Regeln: gegnerische Flagge beruehren = nehmen, mit ihr zur eigenen Basis (eigene Flagge steht dort)
## = Eroberung; eigene liegende Flagge beruehren = zurueck zur Basis. Liefert den Bots ihre Ziele.

var flags: Array[CtfFlag] = []


## Basen aus den Spawnpunkten bestimmen und die Flaggen aufstellen (Aufruf nach dem Registrieren der Spawnpunkte)
func setup() -> void:
	# Basen aus den Spawns von Hand (die Arena ergaenzt zufaellige aus dem Navigationsnetz)
	var points: Array[Node3D] = GameManager.spawn_points.filter(func(p): return not p.has_meta(&"nav_spawn"))
	var pair := [Vector3(-20, 0, 0), Vector3(20, 0, 0)]
	var best := -1.0
	for a in points:
		for b in points:
			var d: float = a.global_position.distance_squared_to(b.global_position)
			if d > best:
				best = d
				pair = [a.global_position, b.global_position]
	for team in 2:
		var flag := CtfFlag.new()
		flag.name = "Flag" + GameManager.TEAM_NAMES[team]
		flag.team = team
		flag.home = _floor_below(pair[team])
		flag.manager = self
		add_child(flag)
		flags.append(flag)
		_add_base_ring(flag.home, GameManager.TEAM_COLORS[team])


func home_of(team: int) -> Vector3:
	return flags[team].home


func on_flag_touched(flag: CtfFlag, body: Node) -> void:
	if not (body is Player or body is Bot) or body.health.is_dead:
		return
	var team: int = GameManager.team_of(body)
	if team < 0:
		return
	if team != flag.team:
		if flag.state != CtfFlag.FlagState.CARRIED:
			flag.pick_up(body)
			announce("%s hat die Flagge von %s!" % [GameManager._name_of(body), GameManager.TEAM_NAMES[flag.team]], team)
	elif flag.state == CtfFlag.FlagState.DROPPED:
		flag.return_home()
		announce("%s bringt die Flagge zurück" % GameManager._name_of(body), team)
	elif flag.state == CtfFlag.FlagState.HOME and flags[1 - team].carrier == body:
		flags[1 - team].return_home()
		GameManager.register_capture(team, body)


## Ziel eines Bots: { pos, value } fuer die Utility-AI (value hoeher = wichtiger als anderes)
func objective_for(bot: Node3D) -> Dictionary:
	var team: int = GameManager.team_of(bot)
	if team < 0:
		return {}
	var own := flags[team]
	var enemy := flags[1 - team]
	if enemy.carrier == bot:
		return { "pos": own.home, "value": 1.2 }  # mit der Flagge heim, wichtiger als Kaempfen
	if own.state == CtfFlag.FlagState.DROPPED:
		return { "pos": own.global_position, "value": 0.85 }
	if own.state == CtfFlag.FlagState.CARRIED and is_instance_valid(own.carrier):
		return { "pos": own.carrier.global_position, "value": 0.8 }
	if _is_defender(bot):
		return { "pos": own.home, "value": 0.45 }
	if enemy.state == CtfFlag.FlagState.CARRIED and is_instance_valid(enemy.carrier):
		return { "pos": enemy.carrier.global_position, "value": 0.7 }  # eigenen Traeger begleiten (allein kommt er selten heim)
	return { "pos": enemy.global_position, "value": 0.65 }


## Spawnpunkt auf der eigenen Kartenhaelfte?
func is_own_half(point: Vector3, team: int) -> bool:
	return point.distance_squared_to(flags[team].home) < point.distance_squared_to(flags[1 - team].home)


func announce(text: String, team: int) -> void:
	GameManager.player_announcement.emit(text, GameManager.TEAM_COLORS[team])
	Net.on_announce(text, GameManager.TEAM_COLORS[team])


## Jeder zweite Bot eines Teams verteidigt (bei einem Bot im Team greift er an)
func _is_defender(bot: Node3D) -> bool:
	var mates: Array = get_tree().get_nodes_in_group("enemies").filter(func(b): return b.team == bot.team)
	return mates.find(bot) % 2 == 1


func _floor_below(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN * 20.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else point


func _add_base_ring(pos: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	ring.mesh.inner_radius = 1.2
	ring.mesh.outer_radius = 1.4
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.5
	ring.material_override = glow
	add_child(ring)
	ring.global_position = pos + Vector3(0, 0.05, 0)
