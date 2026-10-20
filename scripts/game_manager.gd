extends Node

## GameManager Autoload-Singleton
## Verwaltet den globalen Spielzustand, Punktestand (Frags, Tode),
## Respawn-Logik und Benutzereinstellungen (Sensitivitaet, Lautstaerke).

# Signale fuer UI und Spielereignisse
signal score_updated(player_frags: int, player_deaths: int)
signal game_paused(is_paused: bool)
signal player_died()
signal player_respawned(player_node: Node)

# Spielzustand
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
var current_state: GameState = GameState.PLAYING

# Statistik
var player_frags: int = 0
var player_deaths: int = 0
var bot_frags: int = 0

# Einstellungen (werden vom Hauptmenue und Spieler genutzt)
var mouse_sensitivity: float = 0.002
var master_volume: float = 1.0

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


## ESC (Aktion "pause") schaltet die Pause um
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


## Pause-Menue aus der eigenen Szene erzeugen (anfangs ausgeblendet)
func _build_pause_overlay() -> void:
	_pause_layer = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_layer)


## Registriert einen Frag (Abschuss) fuer den Spieler
func add_player_frag() -> void:
	player_frags += 1
	score_updated.emit(player_frags, player_deaths)


## Registriert einen Tod des Spielers (bei Tod durch einen Bot zaehlt ein Bot-Frag)
func add_player_death(killed_by_bot: bool = false) -> void:
	player_deaths += 1
	if killed_by_bot:
		bot_frags += 1
	score_updated.emit(player_frags, player_deaths)
	player_died.emit()


## Setzt alle Spielwerte fuer eine neue Runde zurueck
func reset_game() -> void:
	player_frags = 0
	player_deaths = 0
	bot_frags = 0
	score_updated.emit(player_frags, player_deaths)
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
	apply_master_volume()


## Speichert die aktuellen Einstellungen
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
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


## Gibt einen zufaelligen Spawnpunkt zurueck
func get_random_spawn_transform() -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 1.5, 0.0))
	var random_index: int = randi() % spawn_points.size()
	return spawn_points[random_index].global_transform
