extends Node

## LAN-Multiplayer (Roadmap Phase 8). Ein Spieler hostet (ENet-Server): Der Host entscheidet ueber Schaden,
## Tod, Respawn, Items, Punkte und Matchende und laesst die Bots laufen. Jeder steuert seinen eigenen Spieler
## selbst und meldet Position und Schuesse. Alle anderen Kaempfer sind auf jedem Rechner Bot-Puppen
## (Bot.puppet), die den Netzdaten folgen. Schuesse werden ueberall nachgespielt (Effekte, Projektile,
## Rueckstoss); Schaden zaehlt nur auf dem Host und kommt als Ereignis mit dem neuen Lebensstand zurueck.
##
## Kennungen: Spieler "P<peer-id>" (Host = "P1"), Bots ihr Knotenname ("Bot3").

const PORT: int = 24510
## LAN-Suche: der Host sendet jede Sekunde einen Broadcast an diesen Port
const DISCOVERY_PORT: int = 24511
const PROTOCOL: int = 1
const SEND_INTERVAL: float = 1.0 / 30.0
const BOT_SCENE: PackedScene = preload("res://scenes/bot.tscn")
## Farben fuer menschliche Mitspieler im Deathmatch
const PLAYER_COLORS: Array[Color] = [Color(0.2, 0.9, 1.0), Color(1.0, 0.8, 0.1), Color(0.55, 1.0, 0.2),
	Color(1.0, 0.3, 0.75), Color(1.0, 0.45, 0.05), Color(0.8, 0.3, 1.0), Color(0.95, 0.95, 0.95), Color(1.0, 0.22, 0.18)]

## Verbindungsversuch als Client beendet (ok = Match-Daten erhalten, sonst Grund)
signal join_result(ok: bool, message: String)
## Liste der gefundenen LAN-Spiele hat sich geaendert
signal servers_changed()

var active: bool = false
## Eigener Spielername im Netzspiel (vom Host eindeutig gemacht) und Team
var my_name: String = ""
var my_team: int = -1
## Kennung -> Knoten (eigener Spieler oder Puppe) im aktuellen Level
var entities: Dictionary = {}
## Gefundene Spiele: IP -> { name, map, players, max, seen }
var servers: Dictionary = {}
## Grund der letzten Trennung (zeigt das Hauptmenue an)
var last_error: String = ""

var _level: Node = null
var _send_timer: float = 0.0
var _beacon_timer: float = 0.0
var _beacon: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
## Host: Peer-ID -> { name, team, color, ready }
var _clients: Dictionary = {}
## Host: Clients, die schon fertig geladen haben, waehrend der Host noch laedt (Neustart)
var _pending_ready: Array[int] = []
## Host: zerstoerte Objekte dieses Levels (fuer spaeter Beitretende)
var _destroyed_props: Array[NodePath] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Verbindung fehlgeschlagen"))
	multiplayer.server_disconnected.connect(func(): _fail("Verbindung zum Host verloren"))


func is_host() -> bool:
	return active and multiplayer.is_server()


func is_client() -> bool:
	return active and not multiplayer.is_server()


# ==============================================================================
# VERBINDUNG
# ==============================================================================

## Spiel hosten (danach startet das Hauptmenue das Level wie ein normales Match)
func host_game(player_name: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, GameManager.MAX_BOTS)
	if err != OK:
		return "Port %d belegt (läuft schon ein Spiel?)" % PORT
	multiplayer.multiplayer_peer = peer
	active = true
	my_name = player_name
	my_team = GameManager.PLAYER_TEAM if GameManager.is_team_mode() else -1
	_clients.clear()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	return ""


## Einem Spiel beitreten; das Ergebnis kommt ueber join_result
func join_game(ip: String, player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		join_result.emit(false, "Ungültige Adresse")
		return
	multiplayer.multiplayer_peer = peer
	active = true
	my_name = player_name


## Netzspiel verlassen (Hauptmenue, Fehler)
func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	active = false
	entities.clear()
	_clients.clear()
	_pending_ready.clear()
	_level = null
	_beacon = null


func _fail(message: String) -> void:
	var was_in_game := is_instance_valid(_level)
	leave()
	last_error = message
	join_result.emit(false, message)
	if was_in_game:
		GameManager.return_to_menu()


func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, my_name)


## Client -> Host: Anmeldung. Der Host antwortet mit den Match-Einstellungen oder lehnt ab.
@rpc("any_peer", "reliable")
func _hello(protocol: int, wanted_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rejected.rpc_id(id, "Andere Spielversion")
		return
	var humans := _clients.size() + 1
	if humans >= GameManager.MAPS[GameManager.selected_map].max_players:
		_rejected.rpc_id(id, "Server voll")
		return
	var info := { "name": _unique_name(wanted_name), "team": _smaller_team(), "color": PLAYER_COLORS[(humans) % PLAYER_COLORS.size()] }
	_clients[id] = info
	var settings := {
		"map": GameManager.selected_map, "mode": GameManager.game_mode, "frag_limit": GameManager.frag_limit,
		"time_limit": GameManager.time_limit_minutes, "capture_limit": GameManager.capture_limit,
		"instagib": GameManager.instagib, "name": info.name, "team": info.team,
	}
	_match_info.rpc_id(id, settings)


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	_fail(reason)


## Host -> Client: Einstellungen uebernehmen und das Level laden
@rpc("authority", "reliable")
func _match_info(settings: Dictionary) -> void:
	GameManager.selected_map = settings.map
	GameManager.game_mode = settings.mode
	GameManager.frag_limit = settings.frag_limit
	GameManager.time_limit_minutes = settings.time_limit
	GameManager.capture_limit = settings.capture_limit
	GameManager.instagib = settings.instagib
	GameManager.duel = false
	my_name = settings.name
	my_team = settings.team
	join_result.emit(true, "")
	GameManager.reset_game()
	get_tree().change_scene_to_file(GameManager.MAPS[GameManager.selected_map].scene)


func _unique_name(wanted: String) -> String:
	var base := wanted.strip_edges().left(16)
	if base.is_empty():
		base = "Spieler"
	var taken: Array = [my_name] + _clients.values().map(func(c): return c.name)
	for node in entities.values():
		taken.append(GameManager._name_of(node))
	var candidate := base
	var n := 2
	while candidate in taken:
		candidate = "%s %d" % [base, n]
		n += 1
	return candidate


func _smaller_team() -> int:
	if not GameManager.is_team_mode():
		return -1
	var counts := _team_counts()
	for id in _clients:
		if not entities.has("P%d" % id) and _clients[id].team >= 0:
			counts[_clients[id].team] += 1
	# Gleichstand: Rot, denn der Host spielt Blau (dann ersetzt der Neue einen roten Bot)
	return 0 if counts[0] <= counts[1] else 1


func _team_counts() -> Array:
	var counts := [0, 0]
	for node in entities.values():
		if node.team >= 0:
			counts[node.team] += 1
	return counts


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	_clients.erase(id)
	_remove_entity("P%d" % id)
	_remove_entity.rpc("P%d" % id)


# ==============================================================================
# LEVEL
# ==============================================================================

## Vom Level nach dem Laden (nach den Bots): Kaempfer registrieren bzw. beim Host anmelden
func on_level_ready(level: Node) -> void:
	if not active:
		return
	_level = level
	entities.clear()
	_destroyed_props.clear()
	if is_host():
		entities["P1"] = GameManager.current_player
		for bot in get_tree().get_nodes_in_group("enemies"):
			entities[bot.name] = bot
		for id in _clients:
			_clients[id].erase("ready")
		for id in _pending_ready:
			_add_client(id)
		_pending_ready.clear()
	else:
		entities["P%d" % multiplayer.get_unique_id()] = GameManager.current_player
		if GameManager.ctf:
			for flag in GameManager.ctf.flags:
				flag.set_physics_process(false)
		_client_ready.rpc_id(1)


## Client -> Host: Level geladen. Der Host baut die Puppe, meldet sie allen und schickt den Spielstand.
@rpc("any_peer", "reliable")
func _client_ready() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _clients.has(id):
		return
	if is_instance_valid(_level):
		_add_client(id)
	else:
		_pending_ready.append(id)


func _add_client(id: int) -> void:
	var info: Dictionary = _clients[id]
	var eid := "P%d" % id
	# Ein Bot macht Platz, wenn das Haus voll ist oder das Team des Neuen sonst groesser wuerde
	var counts := _team_counts()
	if entities.size() >= GameManager.MAPS[GameManager.selected_map].max_players 			or (info.team >= 0 and counts[info.team] >= counts[1 - info.team]):
		for node in entities.values():
			if node is Bot and not node.puppet and (info.team < 0 or node.team == info.team):
				_remove_entity(node.name)
				_remove_entity.rpc(node.name)
				break
	_spawn_puppet(eid, info.name, info.team, info.color)
	var roster: Array = []
	for key in entities:
		roster.append(_entry(key))
	var hidden: Array = []
	for item in get_tree().get_nodes_in_group("pickups"):
		if not item.is_active:
			hidden.append(_level.get_path_to(item))
	_welcome.rpc_id(id, roster, GameManager.scores, GameManager.team_scores, hidden, _destroyed_props)
	for other in _clients:
		if other != id and _clients[other].has("ready"):
			_add_entity.rpc_id(other, _entry(eid))
	info["ready"] = true


func _entry(eid: String) -> Dictionary:
	var node: Node = entities[eid]
	var color: Color = node.skin_color if node is Bot else PLAYER_COLORS[0]
	if node.team >= 0:
		color = GameManager.TEAM_COLORS[node.team]
	return { "id": eid, "name": GameManager._name_of(node), "team": node.team, "color": color }


## Host -> Client: alle Kaempfer, Punkte und eingesammelte Items
@rpc("authority", "reliable")
func _welcome(roster: Array, scores: Dictionary, team_scores: Array, hidden: Array, destroyed: Array) -> void:
	for entry in roster:
		_add_entity(entry)
	GameManager.scores = scores.duplicate(true)
	for row_name in GameManager.scores:
		GameManager.scores[row_name].is_player = row_name == my_name
	GameManager.team_scores.assign(team_scores)
	GameManager.scoreboard_changed.emit()
	for path in hidden:
		var item := _level.get_node_or_null(path)
		if item:
			item._collect(true)
	for path in destroyed:
		var prop := _level.get_node_or_null(path)
		if prop:
			prop.queue_free()


@rpc("authority", "reliable")
func _add_entity(entry: Dictionary) -> void:
	if entities.has(entry.id) or not is_instance_valid(_level):
		return
	_spawn_puppet(entry.id, entry.name, entry.team, entry.color)


@rpc("authority", "reliable")
func _remove_entity(eid: String) -> void:
	var node: Node = entities.get(eid)
	entities.erase(eid)
	if node is Bot:
		GameManager.scores.erase(GameManager._name_of(node))
		GameManager.scoreboard_changed.emit()
		node.queue_free()


func _spawn_puppet(eid: String, display_name: String, team: int, color: Color) -> void:
	var bot: Bot = BOT_SCENE.instantiate()
	bot.name = eid
	bot.display_name = display_name
	bot.team = team
	bot.skin_color = color
	bot.puppet = true
	_level.add_child(bot)
	bot.global_position = Vector3(0, -500, 0)  # bis der erste Netzstand kommt
	entities[eid] = bot


func id_of(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if node == GameManager.current_player:
		return "P%d" % multiplayer.get_unique_id()
	return node.name


func node_of(eid: String) -> Node:
	var node: Node = entities.get(eid)
	return node if is_instance_valid(node) else null


# ==============================================================================
# LAUFENDER ABGLEICH (Positionen)
# ==============================================================================

func _process(delta: float) -> void:
	_poll_listener()
	if not active:
		return
	if is_host() and _beacon:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = 1.0
			var text := "MSHOOTER|%d|%s|%s|%d|%d" % [PROTOCOL, my_name, GameManager.MAPS[GameManager.selected_map].name,
				_clients.size() + 1, GameManager.MAPS[GameManager.selected_map].max_players]
			_beacon.put_packet(text.to_utf8_buffer())
	if not is_instance_valid(_level) or multiplayer.multiplayer_peer == null:
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = SEND_INTERVAL
	if is_host():
		var states: Array = []
		for eid in entities:
			var node: Node = node_of(eid)
			if node:
				states.append([eid] + _state_of(node))
		var flags: Array = []
		if GameManager.ctf:
			for flag in GameManager.ctf.flags:
				flags.append([flag.state, id_of(flag.carrier), flag.global_position])
		_snapshot.rpc(states, flags, GameManager.match_time_left)
	elif GameManager.current_player:
		_client_state.rpc_id(1, _state_of(GameManager.current_player))


## [Position, Blick (Yaw), Neigung, Tempo, Waffe, am Boden, zielt]
func _state_of(node: Node) -> Array:
	if node is Player:
		return [node.global_position, node.rotation.y, node.camera_pitch, node.velocity,
			node.weapon_manager.get_current_weapon().weapon_id, node.is_on_floor(), true]
	if node.puppet:
		return node.net_state()
	return [node.global_position, node.rotation.y, 0.0, node.velocity, node.weapon_manager.current.weapon_id,
		node.is_on_floor(), node.current_state == Bot.State.ATTACK]


@rpc("any_peer", "unreliable_ordered")
func _client_state(state: Array) -> void:
	var puppet := node_of("P%d" % multiplayer.get_remote_sender_id())
	if puppet:
		puppet.net_update(state)


@rpc("authority", "unreliable_ordered")
func _snapshot(states: Array, flags: Array, time_left: float) -> void:
	var own := "P%d" % multiplayer.get_unique_id()
	for state in states:
		if state[0] == own:
			continue
		var node := node_of(state[0])
		if node is Bot:
			node.net_update(state.slice(1))
	if GameManager.ctf:
		for i in mini(flags.size(), GameManager.ctf.flags.size()):
			var flag: CtfFlag = GameManager.ctf.flags[i]
			flag.state = flags[i][0]
			flag.carrier = node_of(flags[i][1])
			flag.global_position = flags[i][2]
	GameManager.match_time_left = time_left


# ==============================================================================
# EREIGNISSE
# ==============================================================================

## Schuss eines Kaempfers: Host -> alle Clients, Client -> Host (der spielt ihn mit Schaden nach)
func on_fired(shooter: Node, weapon_id: StringName, alt: bool, aim: Transform3D) -> void:
	if not active or not is_instance_valid(_level):
		return
	if is_host():
		_ev_fire.rpc(id_of(shooter), weapon_id, alt, aim)
	elif shooter == GameManager.current_player:
		_client_fire.rpc_id(1, weapon_id, alt, aim)


@rpc("any_peer", "reliable")
func _client_fire(weapon_id: StringName, alt: bool, aim: Transform3D) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var eid := "P%d" % sender
	var puppet := node_of(eid)
	if puppet == null or puppet.health.is_dead:
		return
	puppet.net_fire(weapon_id, alt, aim)
	for id in _clients:
		if id != sender:
			_ev_fire.rpc_id(id, eid, weapon_id, alt, aim)


@rpc("authority", "reliable")
func _ev_fire(eid: String, weapon_id: StringName, alt: bool, aim: Transform3D) -> void:
	var node := node_of(eid)
	if node is Bot:
		node.net_fire(weapon_id, alt, aim)


## Host: ein Kaempfer hat Schaden genommen (nach health.apply_damage)
func on_damaged(victim: Node, info: DamageInfo) -> void:
	if not is_host():
		return
	_ev_damage.rpc(id_of(victim), info.amount, id_of(info.attacker), info.position, info.direction,
		info.weapon_name, info.is_splash, info.is_headshot, victim.health.health, victim.health.armor, victim.health.is_dead)


@rpc("authority", "reliable")
func _ev_damage(eid: String, amount: float, attacker: String, pos: Vector3, dir: Vector3, weapon_name: String,
		splash: bool, headshot: bool, health: float, armor: float, dead: bool) -> void:
	var victim := node_of(eid)
	if victim == null:
		return
	var info := DamageInfo.new()
	info.amount = amount
	info.attacker = node_of(attacker)
	info.position = pos
	info.direction = dir
	info.weapon_name = weapon_name
	info.is_splash = splash
	info.is_headshot = headshot
	victim.net_damaged(info, health, armor, dead)


## Client: eigener Fallschaden (den kennt nur der Client); der Host wendet ihn auf die Puppe an
func send_self_damage(amount: float, weapon_name: String) -> void:
	_client_self_damage.rpc_id(1, amount, weapon_name)


@rpc("any_peer", "reliable")
func _client_self_damage(amount: float, weapon_name: String) -> void:
	var puppet := node_of("P%d" % multiplayer.get_remote_sender_id())
	if puppet:
		puppet.take_damage(DamageInfo.create(amount, null, puppet.global_position, Vector3.ZERO, weapon_name))


## Host: Respawn an einem Spawnpunkt
func on_respawned(node: Node, at: Transform3D) -> void:
	if is_host():
		_ev_respawn.rpc(id_of(node), at)


@rpc("authority", "reliable")
func _ev_respawn(eid: String, at: Transform3D) -> void:
	var node := node_of(eid)
	if node:
		node._respawn(at)


## Host: Item eingesammelt / wieder da
func on_picked(item: Node, body: Node) -> void:
	if is_host() and is_instance_valid(_level):
		_ev_pickup.rpc(_level.get_path_to(item), id_of(body))


func on_item_respawned(item: Node) -> void:
	if is_host() and is_instance_valid(_level):
		_ev_item_respawn.rpc(_level.get_path_to(item))


@rpc("authority", "reliable")
func _ev_pickup(path: NodePath, eid: String) -> void:
	var item := _level.get_node_or_null(path) if is_instance_valid(_level) else null
	var body := node_of(eid)
	if item and body:
		item.net_pickup(body)


@rpc("authority", "reliable")
func _ev_item_respawn(path: NodePath) -> void:
	var item := _level.get_node_or_null(path) if is_instance_valid(_level) else null
	if item:
		item._respawn()


## Host: Kiste, Fass oder Glasscheibe zerstoert
func on_prop_destroyed(prop: Node) -> void:
	if is_host() and is_instance_valid(_level):
		var path := _level.get_path_to(prop)
		_destroyed_props.append(path)
		_ev_prop_destroyed.rpc(path)


@rpc("authority", "reliable")
func _ev_prop_destroyed(path: NodePath) -> void:
	var prop := _level.get_node_or_null(path) if is_instance_valid(_level) else null
	if prop:
		prop.destroy()


## Host: CTF-Eroberung und Ansagen
func on_capture(team: int, carrier: Node) -> void:
	if is_host():
		_ev_capture.rpc(team, id_of(carrier))


@rpc("authority", "reliable")
func _ev_capture(team: int, eid: String) -> void:
	GameManager.register_capture(team, node_of(eid))


func on_announce(text: String, color: Color) -> void:
	if is_host():
		_ev_announce.rpc(text, color)


@rpc("authority", "reliable")
func _ev_announce(text: String, color: Color) -> void:
	GameManager.player_announcement.emit(text, color)


## Host: Matchende und Neustart fuer alle
func on_match_over(reason: String) -> void:
	if is_host():
		_ev_match_over.rpc(reason)


@rpc("authority", "reliable")
func _ev_match_over(reason: String) -> void:
	GameManager.end_match(reason)


func on_restart() -> void:
	if is_host():
		_level = null  # Clients, die vor dem Host fertig laden, warten in _pending_ready
		_ev_restart.rpc()


@rpc("authority", "reliable")
func _ev_restart() -> void:
	GameManager.restart_match()


# ==============================================================================
# LAN-SUCHE
# ==============================================================================

## Nach Spielen im LAN lauschen (Hauptmenue); stop_listening beendet es
func start_listening() -> void:
	if _listener:
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null


func stop_listening() -> void:
	if _listener:
		_listener.close()
	_listener = null
	servers.clear()


func _poll_listener() -> void:
	if _listener == null:
		return
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var parts := _listener.get_packet().get_string_from_utf8().split("|")
		var ip := _listener.get_packet_ip()
		if parts.size() == 6 and parts[0] == "MSHOOTER" and int(parts[1]) == PROTOCOL:
			changed = changed or not servers.has(ip)
			servers[ip] = { "name": parts[2], "map": parts[3], "players": int(parts[4]), "max": int(parts[5]), "seen": Time.get_ticks_msec() }
	for ip in servers.keys():
		if Time.get_ticks_msec() - servers[ip].seen > 3500:
			servers.erase(ip)
			changed = true
	if changed:
		servers_changed.emit()
