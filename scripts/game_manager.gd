extends Node

## GameManager Autoload-Singleton
## Verwaltet den globalen Spielzustand, Punktestand (Frags, Tode),
## Respawn-Logik und Benutzereinstellungen (Sensitivitaet, Lautstaerke).

# Signale fuer UI und Spielereignisse
signal score_updated(player_frags: int, player_deaths: int)
signal game_paused(is_paused: bool)
signal player_died()
## Fuer den Killfeed: Wer hat wen womit erwischt (killer_name leer = Umgebung)
signal kill_registered(killer_name: String, victim_name: String, weapon_name: String)
## Die Punktetabelle hat sich geaendert (fuer das Scoreboard)
signal scoreboard_changed()

# Spielzustand
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.PLAYING

# Statistik
var player_frags: int = 0
var player_deaths: int = 0
var bot_frags: int = 0
## Punktetabelle: Name -> { "frags": int, "deaths": int, "is_player": bool }
var scores: Dictionary = {}

# Einstellungen (werden vom Hauptmenue und Spieler genutzt)
var mouse_sensitivity: float = 0.002
var master_volume: float = 1.0
## Horizontales Sichtfeld in Grad (Quake-Spieler nutzen oft 100-110)
var fov: float = 100.0

# Match-Einstellungen
## Anzahl Bots in der Arena (1-7)
var bot_count: int = 3
## Schwierigkeit der Bots (Index in Bot.SKILL_PRESETS, 0 = Anfaenger ... 4 = Gott)
var bot_skill: int = 2
const MAX_BOTS: int = 7
## Spielbare Arenen: Anzeigename und Szene
const MAPS: Array[Dictionary] = [
	{ "name": "Neon Foundry", "scene": "res://levels/neon_foundry.tscn" },
	{ "name": "Testarena", "scene": "res://levels/test_arena.tscn" },
]
## Index in MAPS
var selected_map: int = 0

# Referenz auf den aktuellen Spieler im Level
var current_player: CharacterBody3D = null

# Einblendung fuer die Pause (scenes/ui/pause_menu.tscn)
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
var _pause_layer: PauseMenu = null

# Speicherort der Benutzereinstellungen
const SETTINGS_PATH := "user://settings.cfg"

# Liste von Spawnpunkten im aktuellen Level
var spawn_points: Array[Node3D] = []



func _ready() -> void:
	# Prozess laeuft auch waehrend das Spiel pausiert ist
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_build_pause_overlay()


## Spiel sauber beenden: erst die laufende Szene freigeben, dann schliessen.
## Direktes quit() mitten im Match meldet sonst "material is null", weil Godot
## Materialien vor den Objekten freigibt, die sie noch benutzen.
func quit_game() -> void:
	get_tree().paused = false
	var scene := get_tree().current_scene
	if scene:
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _exit_tree() -> void:
	SoundGenerator.clear_cache()


## ESC (Aktion "pause") schaltet die Pause um
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


## Pause-Menue aus der eigenen Szene erzeugen (anfangs ausgeblendet)
func _build_pause_overlay() -> void:
	_pause_layer = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_layer)


## Meldet einen Teilnehmer (Spieler oder Bot) fuer die Punktetabelle an
func register_participant(display_name: String, is_player: bool = false) -> void:
	if not scores.has(display_name):
		scores[display_name] = { "frags": 0, "deaths": 0, "is_player": is_player }
		scoreboard_changed.emit()


## Wertet einen Abschuss aus. killer == victim oder null = Selbstmord (-1 Frag wie in Quake)
func register_kill(killer: Node, victim: Node, weapon_name: String) -> void:
	var victim_name := _name_of(victim)
	var suicide := killer == null or killer == victim or not is_instance_valid(killer)
	var killer_name := victim_name if suicide else _name_of(killer)

	_score(victim_name, victim is Player).deaths += 1
	if suicide:
		_score(victim_name, victim is Player).frags -= 1
	else:
		_score(killer_name, killer is Player).frags += 1

	# Kurzwerte fuer HUD und Tests
	if victim is Player:
		player_deaths += 1
		if suicide:
			player_frags -= 1
	if not suicide and killer is Player:
		player_frags += 1
	if not suicide and killer is Bot:
		bot_frags += 1

	kill_registered.emit(killer_name, victim_name, weapon_name)
	score_updated.emit(player_frags, player_deaths)
	scoreboard_changed.emit()
	if victim is Player:
		player_died.emit()


## Punktetabelle sortiert nach Frags (absteigend), bei Gleichstand weniger Tode zuerst
func get_scoreboard() -> Array:
	var rows: Array = []
	for n in scores:
		rows.append({ "name": n, "frags": scores[n].frags, "deaths": scores[n].deaths, "is_player": scores[n].is_player })
	rows.sort_custom(func(a, b):
		return a.frags > b.frags or (a.frags == b.frags and a.deaths < b.deaths))
	return rows


func _score(display_name: String, is_player: bool) -> Dictionary:
	register_participant(display_name, is_player)
	return scores[display_name]


func _name_of(node: Node) -> String:
	if node and node.get("display_name"):
		return node.display_name
	return node.name if node else "Welt"


## Setzt alle Spielwerte fuer eine neue Runde zurueck
func reset_game() -> void:
	player_frags = 0
	player_deaths = 0
	bot_frags = 0
	scores.clear()
	score_updated.emit(player_frags, player_deaths)
	scoreboard_changed.emit()
	current_state = GameState.PLAYING


## Umschalten des Pause-Zustands

func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause_layer.visible = true
		game_paused.emit(true)
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_pause_layer.visible = false
		game_paused.emit(false)


## Laedt Mausempfindlichkeit und Lautstaerke und wendet die Lautstaerke an
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
		master_volume = cfg.get_value("audio", "master_volume", master_volume)
		fov = cfg.get_value("video", "fov", fov)
		bot_count = clampi(cfg.get_value("match", "bot_count", bot_count), 1, MAX_BOTS)
		bot_skill = clampi(cfg.get_value("match", "bot_skill", bot_skill), 0, 4)
		selected_map = clampi(cfg.get_value("match", "map", selected_map), 0, MAPS.size() - 1)
	apply_master_volume()


## Speichert die aktuellen Einstellungen
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("match", "bot_count", bot_count)
	cfg.set_value("match", "bot_skill", bot_skill)
	cfg.set_value("match", "map", selected_map)
	cfg.save(SETTINGS_PATH)


## Setzt die Master-Lautstaerke (0 = stumm)
func apply_master_volume() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, master_volume <= 0.01)
	if master_volume > 0.01:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))


## Registriert einen Spawnpunkt aus dem Level
func register_spawn_point(point: Node3D) -> void:
	if not spawn_points.has(point):
		spawn_points.append(point)


## Spawnpunkt mit moeglichst grossem Abstand zu allen anderen lebenden Kaempfern.
## Unter den zwei besten wird zufaellig gewaehlt, damit der Spawn nicht vorhersagbar ist.
func get_spawn_transform(for_node: Node3D) -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 1.5, 0.0))
	var others: Array[Node3D] = []
	for group in ["player", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			if node != for_node and node.get("health") != null and not node.health.is_dead:
				others.append(node)
	var rated: Array = []
	for point in spawn_points:
		var nearest: float = INF
		for other in others:
			nearest = minf(nearest, point.global_position.distance_to(other.global_position))
		rated.append({ "point": point, "dist": nearest })
	rated.sort_custom(func(a, b): return a.dist > b.dist)
	var pick: int = randi() % mini(2, rated.size())
	return rated[pick].point.global_transform


## Gibt einen zufaelligen Spawnpunkt zurueck
func get_random_spawn_transform() -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 1.5, 0.0))
	var random_index: int = randi() % spawn_points.size()
	return spawn_points[random_index].global_transform
