extends Node

## GameManager Autoload-Singleton
## Verwaltet den globalen Spielzustand, den Match-Ablauf (Countdown, Frag- und Zeitlimit,
## Siegerbildschirm), Punktestand und Statistik, Respawn-Logik und Benutzereinstellungen.

# Signale fuer UI und Spielereignisse
signal score_updated(player_frags: int, player_deaths: int)
signal game_paused(is_paused: bool)
signal player_died()
## Fuer den Killfeed: Wer hat wen womit erwischt (killer_name leer = Umgebung)
signal kill_registered(killer_name: String, victim_name: String, weapon_name: String)
## Die Punktetabelle hat sich geaendert (fuer das Scoreboard)
signal scoreboard_changed()
## Countdown vor dem Start: 3, 2, 1, dann 0 = "FIGHT!"
signal countdown_tick(seconds_left: int)
signal match_started()
## Match vorbei; results siehe end_match()
signal match_ended(results: Dictionary)
## Ansage fuer den Spieler (Multi-Kill, Serie)
signal player_announcement(text: String, color: Color)
## Chat-Zeile eines Bots (Spruch nach Kill, Tod oder Quad)
signal bot_chat(sender: String, text: String, color: Color)

# Spielzustand
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, COUNTDOWN }
var current_state: GameState = GameState.PLAYING
var _state_before_pause: GameState = GameState.PLAYING

# Match-Regeln (im Match-Fenster waehlbar, 0 = kein Limit)
const FRAG_LIMITS: Array[int] = [5, 10, 15, 20, 30, 0]
const TIME_LIMITS: Array[int] = [5, 10, 15, 20, 0]
var frag_limit: int = 15
var time_limit_minutes: float = 10.0
## Instagib: nur Railgun mit unendlicher Munition, jeder Treffer toetet, keine Items
var instagib: bool = false
## Duell: genau ein Bot, eins gegen eins (Item-Timing entscheidet; nur im Deathmatch)
var duel: bool = false
## Spielmodus (im Match-Fenster waehlbar)
enum Mode { DEATHMATCH, TEAM_DEATHMATCH, CTF }
const MODE_NAMES: Array[String] = ["Deathmatch", "Team Deathmatch", "Capture the Flag"]
var game_mode: int = Mode.DEATHMATCH
## Teams (Team-Modi): 0 = Rot, 1 = Blau. Der Spieler spielt fuer Blau, die Bots werden abwechselnd verteilt.
const TEAM_NAMES: Array[String] = ["Rot", "Blau"]
const TEAM_COLORS: Array[Color] = [Color(1.0, 0.25, 0.2), Color(0.25, 0.55, 1.0)]
const PLAYER_TEAM: int = 1
## Teampunkte (TDM: Frags, CTF: Eroberungen)
var team_scores: Array[int] = [0, 0]
## CTF: so viele Eroberungen gewinnen das Match
var capture_limit: int = 3
## Feste Auswahl im Menue, daneben ist ein beliebiger Wert waehlbar
const CAPTURE_LIMITS: Array[int] = [1, 3, 5]
## CTF: Flaggen und Basen der aktuellen Map (null in anderen Modi)
var ctf: CtfManager = null
const INSTAGIB_DAMAGE: float = 1000.0
## Sekunden Countdown vor dem Start (Tests setzen 0)
var match_countdown: float = 3.0
var match_time_left: float = 0.0
var countdown_left: float = 0.0
var _last_tick: int = -1

# Statistik des Spielers fuer den Siegerbildschirm
var player_shots: int = 0
var player_hits: int = 0
var _player_multi: int = 0
var _player_last_kill: float = -100.0
const MULTI_KILL_WINDOW: float = 3.0
const MULTI_KILL_TEXT := { 2: "DOUBLE KILL", 3: "MULTI KILL", 4: "MEGA KILL", 5: "MONSTER KILL" }
const SPREE_TEXT := { 5: "KILLING SPREE", 10: "RAMPAGE", 15: "DOMINATING", 20: "UNSTOPPABLE", 25: "GODLIKE" }

# Musik (laeuft immer, im Menue/Pause/Matchende gedaempft) und Ansager
var _music: AudioStreamPlayer = null
var _announcer: AudioStreamPlayer = null
var _first_blood_done: bool = false
var _time_warnings_done: Array[int] = []
const PLAYER_ANNOUNCER := {
	"DOUBLE KILL": "double_kill", "MULTI KILL": "multi_kill", "MEGA KILL": "mega_kill",
	"MONSTER KILL": "monster_kill", "KILLING SPREE": "killing_spree", "RAMPAGE": "rampage",
	"DOMINATING": "dominating", "UNSTOPPABLE": "unstoppable", "GODLIKE": "godlike",
}

const MATCH_END_SCENE: PackedScene = preload("res://scenes/ui/match_end.tscn")
var _match_end_layer: CanvasLayer = null

# Statistik
var player_frags: int = 0
var player_deaths: int = 0
var bot_frags: int = 0
## Punktetabelle: Name -> { "frags": int, "deaths": int, "is_player": bool }
var scores: Dictionary = {}

# Einstellungen (werden vom Hauptmenue und Spieler genutzt)
var mouse_sensitivity: float = 0.002
var master_volume: float = 1.0
var music_volume: float = 0.7
## Lautstaerke aller Effekte (Waffen, Schritte, Treffer) auf dem Bus SFX (mit leichtem Hall der Arena)
var sfx_volume: float = 1.0
## Fadenkreuz (Index in Crosshair.SHAPES / Crosshair.COLORS), Groesse in Pixeln, Hitmarker an/aus
var crosshair_shape: int = 2
var crosshair_color: int = 0
var crosshair_size: float = 7.0
var hitmarker_enabled: bool = true
## Horizontales Sichtfeld in Grad (Quake-Spieler nutzen oft 100-110)
var fov: float = 100.0
## Kamera-Feedback (Wackeln, Einknicken, Tempo-Sichtfeld) an/aus
var camera_effects: bool = true

## Grafik-Stufe (Index in GRAPHICS_PRESETS) und V-Sync
const GRAPHICS_PRESETS: Array[String] = ["Niedrig", "Mittel", "Hoch", "Ultra"]
var graphics_preset: int = 2
var vsync: bool = true
## Fenstermodus (Index in WINDOW_MODES) und Fenstergroesse im Fenstermodus
const WINDOW_MODES: Array[String] = ["Fenster", "Vollbild (randlos)", "Vollbild (exklusiv)"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]
var window_mode: int = 0
var resolution: Vector2i = Vector2i(1280, 720)

## Belegbare Aktionen (InputMap) mit Anzeigenamen fuer die Einstellungen
const BINDABLE_ACTIONS := {
	&"move_forward": "Vorwärts", &"move_backward": "Rückwärts", &"move_left": "Links", &"move_right": "Rechts",
	&"jump": "Springen", &"sprint": "Sprinten", &"shoot": "Schießen", &"shoot_alt": "Alt-Feuer",
	&"scoreboard": "Punkteliste",
}

# Match-Einstellungen
## Anzahl Bots in der Arena (1-7)
var bot_count: int = 3
## Name im Netzspiel (LAN)
var player_name: String = "Spieler"
## Zuletzt eingegebene Host-Adresse (LAN beitreten)
var last_host_ip: String = "127.0.0.1"
## Schwierigkeit der Bots (Index in Bot.SKILL_PRESETS, 0 = Anfaenger ... 4 = Gott)
var bot_skill: int = 2
const MAX_BOTS: int = 15
## Spielbare Arenen: Anzeigename und Szene
## max_players: Spieler plus Bots, nach Groesse der Map (jede Map hat mindestens so viele Spawnpunkte).
## reverb: Hall fuer die ganze Map, wenn sie keine eigenen Hall-Zonen hat (Baukasten-Maps haben sie)
const MAPS: Array[Dictionary] = [
	{ "name": "Neon Foundry", "scene": "res://levels/neon_foundry.tscn", "max_players": 8, "reverb": ReverbZone.Kind.HALL },
	{ "name": "Orbital Void", "scene": "res://levels/orbital_void.tscn", "max_players": 8 },
	{ "name": "Sky Yard", "scene": "res://levels/sky_yard.tscn", "max_players": 12 },
	{ "name": "Duck 17", "scene": "res://levels/duck_17.tscn", "max_players": 16 },
	{ "name": "Twin Spires", "scene": "res://levels/twin_spires.tscn", "max_players": 16 },
	{ "name": "Camp Ground", "scene": "res://levels/camp_ground.tscn", "max_players": 12 },
	{ "name": "Testarena", "scene": "res://levels/test_arena.tscn", "max_players": 8, "reverb": ReverbZone.Kind.ROOM },
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
	# Alle Sounds, die auf Master landen wuerden, laufen ueber den Effekt-Bus (Lautstaerke, Hall)
	get_tree().node_added.connect(_route_to_sfx)
	load_settings()
	_build_pause_overlay()
	_setup_audio()


## Musik- und Ansager-Spieler anlegen, Musik als Endlosschleife starten
func _setup_audio() -> void:
	ReverbZone.create_buses()
	_announcer = AudioStreamPlayer.new()
	_announcer.bus = &"Announcer"
	add_child(_announcer)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	var stream := SoundGenerator.load_music("arena_loop")
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	if stream:
		_music.stream = stream
		_music.play()
	apply_music_volume()


func _route_to_sfx(node: Node) -> void:
	if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and node.bus == &"Master":
		node.bus = &"SFX"
	# 3D-Sounds hallen in Raeumen und Hallen (ReverbZone)
	if node is AudioStreamPlayer3D:
		node.area_mask |= Layers.AUDIO_ZONES


func apply_sfx_volume() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, sfx_volume <= 0.01)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, 0.01)))


func apply_music_volume() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, music_volume <= 0.01)
	if music_volume > 0.01:
		AudioServer.set_bus_volume_db(bus, linear_to_db(music_volume) - 4.0)


## Musik gedaempft (Tiefpass) ausser im laufenden Match
func _update_music_filter() -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		var muffled := current_state != GameState.PLAYING and current_state != GameState.COUNTDOWN
		AudioServer.set_bus_effect_enabled(bus, 0, muffled)


## Ansager-Satz abspielen (z. B. "fight", "double_kill"). Ein neuer Satz unterbricht den alten.
func play_announcer(key: String) -> void:
	var stream := SoundGenerator.load_announcer(key)
	if stream and _announcer:
		_announcer.stream = stream
		_announcer.play()


## Spiel sauber beenden: erst die laufende Szene freigeben, dann schliessen.
## Direktes quit() mitten im Match meldet sonst "material is null", weil Godot
## Materialien vor den Objekten freigibt, die sie noch benutzen.
func quit_game() -> void:
	get_tree().paused = false
	# Musik und Ansage anhalten und dem Audio-Thread Zeit geben, die Wiedergabe freizugeben
	for player in [_music, _announcer]:
		if player:
			player.stop()
			player.stream = null
	var scene := get_tree().current_scene
	if scene:
		scene.queue_free()
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.1, true, false, true).timeout
	SoundGenerator.clear_cache()
	get_tree().quit()


func _exit_tree() -> void:
	# Laufende Musik und Ansage freigeben, sonst meldet Godot beim Beenden Speicherlecks
	for player in [_music, _announcer]:
		if player:
			player.stop()
			player.stream = null
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


## Match-Uhr und Countdown (laufen nicht, waehrend das Spiel pausiert ist)
func _process(delta: float) -> void:
	_update_music_filter()
	if get_tree().paused:
		return
	match current_state:
		GameState.COUNTDOWN:
			countdown_left -= delta
			var n: int = ceili(countdown_left)
			if n != _last_tick and n > 0:
				_last_tick = n
				countdown_tick.emit(n)
				if n <= 3:
					play_announcer(["one", "two", "three"][n - 1])
			if countdown_left <= 0.0:
				current_state = GameState.PLAYING
				countdown_tick.emit(0)
				play_announcer("fight")
				match_started.emit()
		GameState.PLAYING:
			# Netzspiel-Client: die Uhr kommt vom Host, das Matchende auch
			if time_limit_minutes > 0.0 and match_time_left > 0.0 and not Net.is_client():
				match_time_left -= delta
				# Zeitansagen bei 5 Minuten und 1 Minute Restzeit
				for warn in [300, 60]:
					if match_time_left <= warn and time_limit_minutes * 60.0 > warn + 5 and not warn in _time_warnings_done:
						_time_warnings_done.append(warn)
						play_announcer("five_minutes" if warn == 300 else "one_minute")
				if match_time_left <= 0.0:
					match_time_left = 0.0
					end_match("Zeitlimit")


## Wird vom Level nach dem Laden aufgerufen: Uhr stellen, Countdown starten
func start_match() -> void:
	match_time_left = time_limit_minutes * 60.0
	_last_tick = -1
	_first_blood_done = false
	_time_warnings_done.clear()
	# Im Netzspiel ohne Countdown (Mitspieler kommen zu verschiedenen Zeiten dazu)
	var countdown: float = 0.0 if Net.active else match_countdown
	if countdown <= 0.0:
		play_announcer("fight")
	if countdown > 0.0:
		current_state = GameState.COUNTDOWN
		countdown_left = match_countdown
	else:
		current_state = GameState.PLAYING
		match_started.emit()


## Waehrend Countdown und Siegerbildschirm: keine Bewegung, kein Schiessen
func is_frozen() -> bool:
	return current_state == GameState.COUNTDOWN or current_state == GameState.GAME_OVER


## Match beenden: Spiel anhalten, Ergebnisse sammeln, Siegerbildschirm zeigen
func end_match(reason: String) -> void:
	if current_state == GameState.GAME_OVER or current_state == GameState.MENU:
		return
	current_state = GameState.GAME_OVER
	Net.on_match_over(reason)
	var rows := get_scoreboard()
	var results := {
		"reason": reason,
		"rows": rows,
		"winner": rows[0].name if rows.size() > 0 else "",
		"player_won": rows.size() > 0 and rows[0].is_player,
		"accuracy": (100.0 * player_hits / player_shots) if player_shots > 0 else 0.0,
	}
	if is_team_mode():
		var blue_lead: int = team_scores[1] - team_scores[0]
		results.winner = "Unentschieden" if blue_lead == 0 else "Team " + TEAM_NAMES[1 if blue_lead > 0 else 0]
		results.player_won = team_scores[PLAYER_TEAM] > team_scores[1 - PLAYER_TEAM]
		results["teams"] = team_scores.duplicate()
	for row in rows:
		if row.is_player:
			results["player"] = row
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_layer.visible = false
	_match_end_layer = MATCH_END_SCENE.instantiate()
	add_child(_match_end_layer)
	_match_end_layer.show_results(results)
	play_announcer("you_win" if results.player_won else "you_lose")
	match_ended.emit(results)


## Siegerbildschirm schliessen und Level neu starten (gleiche Einstellungen)
func restart_match() -> void:
	Net.on_restart()
	_close_match_end()
	reset_game()
	get_tree().reload_current_scene()


## Siegerbildschirm schliessen und ins Hauptmenue
func return_to_menu() -> void:
	Net.leave()
	_close_match_end()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _close_match_end() -> void:
	if is_instance_valid(_match_end_layer):
		_match_end_layer.queue_free()
	_match_end_layer = null
	get_tree().paused = false


## Meldet einen Teilnehmer (Spieler oder Bot) fuer die Punktetabelle an
func register_participant(display_name: String, is_player: bool = false, team: int = -1) -> void:
	if not scores.has(display_name):
		scores[display_name] = {
			"frags": 0, "deaths": 0, "is_player": is_player, "team": team,
			"damage_dealt": 0.0, "damage_taken": 0.0,
			"spree": 0, "best_spree": 0, "weapon_kills": {},
		}
		scoreboard_changed.emit()


## Schaden fuer die Statistik (vom Ziel in take_damage aufgerufen)
func register_damage(info: DamageInfo, victim: Node) -> void:
	# Ueberschaden nicht mitzaehlen: hoechstens, was das Ziel noch an Leben und Ruestung hatte
	var amount: float = info.amount
	var victim_health = victim.get("health")
	if victim_health:
		amount = minf(amount, victim_health.health + victim_health.armor)
	_score(_name_of(victim), victim is Player).damage_taken += amount
	if is_instance_valid(info.attacker) and info.attacker != victim:
		_score(_name_of(info.attacker), info.attacker is Player).damage_dealt += amount
		# Treffsicherheit: nur direkte Treffer zaehlen (Flaechenschaden wuerde sie verfaelschen)
		if info.attacker is Player and not info.is_splash:
			player_hits += 1


## Ein Schuss des Spielers (fuer die Treffsicherheit)
func register_shot() -> void:
	player_shots += 1


## Wertet einen Abschuss aus. killer == victim oder null = Selbstmord (-1 Frag wie in Quake)
func register_kill(killer: Node, victim: Node, weapon_name: String, headshot: bool = false) -> void:
	var victim_name := _name_of(victim)
	var suicide := killer == null or killer == victim or not is_instance_valid(killer)
	var killer_name := victim_name if suicide else _name_of(killer)

	var victim_score := _score(victim_name, victim is Player)
	victim_score.deaths += 1
	victim_score.spree = 0
	if suicide:
		victim_score.frags -= 1
	else:
		var killer_score := _score(killer_name, killer is Player)
		killer_score.frags += 1
		killer_score.spree += 1
		killer_score.best_spree = maxi(killer_score.best_spree, killer_score.spree)
		killer_score.weapon_kills[weapon_name] = killer_score.weapon_kills.get(weapon_name, 0) + 1
		if not _first_blood_done:
			_first_blood_done = true
			if killer is Player:
				player_announcement.emit("FIRST BLOOD", Color(1.0, 0.2, 0.2))
			play_announcer("first_blood")
		elif killer is Player and weapon_name == "Shock-Combo":
			play_announcer("combo")
		elif killer is Player and headshot:
			player_announcement.emit("HEADSHOT", Color(1.0, 0.85, 0.2))
			play_announcer("headshot")
		if killer is Player:
			killer.on_enemy_killed()
			_announce_player_kill(killer_score.spree)

	# Kurzwerte fuer HUD und Tests
	if victim is Player:
		player_deaths += 1
		if suicide:
			player_frags -= 1
	if not suicide and killer is Player:
		player_frags += 1
	if not suicide and killer is Bot:
		bot_frags += 1

	# TDM: Frag fuers Team des Schuetzen, Selbstmord kostet das eigene Team einen Punkt
	if game_mode == Mode.TEAM_DEATHMATCH:
		var team: int = team_of(victim if suicide else killer)
		if team >= 0:
			team_scores[team] += -1 if suicide else 1

	kill_registered.emit(killer_name, victim_name, weapon_name)
	score_updated.emit(player_frags, player_deaths)
	scoreboard_changed.emit()
	if victim is Player:
		player_died.emit()
		_player_multi = 0

	# Fraglimit erreicht? (verzoegert, damit Effekte des letzten Kills noch starten). Im TDM zaehlt das Team,
	# in CTF nur Eroberungen
	if frag_limit > 0 and not suicide and game_mode != Mode.CTF and not Net.is_client():
		var reached: bool = team_scores[team_of(killer)] >= frag_limit if game_mode == Mode.TEAM_DEATHMATCH else scores[killer_name].frags >= frag_limit
		if reached:
			end_match.call_deferred("Fraglimit")


## Multi-Kill (mehrere Kills kurz hintereinander) und Serie (Kills ohne zu sterben) ansagen
func _announce_player_kill(spree: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_player_multi = _player_multi + 1 if now - _player_last_kill <= MULTI_KILL_WINDOW else 1
	_player_last_kill = now
	var text := ""
	var color := Color.WHITE
	if SPREE_TEXT.has(spree):
		text = SPREE_TEXT[spree]
		color = Color(1.0, 0.35, 0.2)
	elif _player_multi >= 2:
		text = MULTI_KILL_TEXT[mini(_player_multi, 5)]
		color = Color(1.0, 0.8, 0.2)
	if text != "":
		player_announcement.emit(text, color)
		play_announcer(PLAYER_ANNOUNCER[text])


## Punktetabelle sortiert nach Frags (absteigend), bei Gleichstand weniger Tode zuerst
func get_scoreboard() -> Array:
	var rows: Array = []
	for n in scores:
		var row: Dictionary = scores[n].duplicate()
		row["name"] = n
		rows.append(row)
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
	player_shots = 0
	player_hits = 0
	_player_multi = 0
	team_scores = [0, 0]
	scores.clear()
	score_updated.emit(player_frags, player_deaths)
	scoreboard_changed.emit()
	current_state = GameState.PLAYING


## Umschalten des Pause-Zustands

func toggle_pause() -> void:
	if current_state == GameState.PLAYING or current_state == GameState.COUNTDOWN:
		_state_before_pause = current_state
		current_state = GameState.PAUSED
		# Im Netzspiel laeuft das Spiel weiter, nur das Menue liegt darueber
		get_tree().paused = not Net.active
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause_layer.visible = true
		game_paused.emit(true)
	elif current_state == GameState.PAUSED:
		current_state = _state_before_pause
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
		music_volume = cfg.get_value("audio", "music_volume", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
		crosshair_shape = cfg.get_value("hud", "crosshair_shape", crosshair_shape)
		crosshair_color = cfg.get_value("hud", "crosshair_color", crosshair_color)
		crosshair_size = cfg.get_value("hud", "crosshair_size", crosshair_size)
		hitmarker_enabled = cfg.get_value("hud", "hitmarker", hitmarker_enabled)
		fov = cfg.get_value("video", "fov", fov)
		camera_effects = cfg.get_value("video", "camera_effects", camera_effects)
		bot_count = clampi(cfg.get_value("match", "bot_count", bot_count), 1, MAX_BOTS)
		bot_skill = clampi(cfg.get_value("match", "bot_skill", bot_skill), 0, 4)
		selected_map = clampi(cfg.get_value("match", "map", selected_map), 0, MAPS.size() - 1)
		frag_limit = cfg.get_value("match", "frag_limit", frag_limit)
		player_name = cfg.get_value("net", "name", player_name)
		last_host_ip = cfg.get_value("net", "host_ip", last_host_ip)
		capture_limit = clampi(cfg.get_value("match", "capture_limit", capture_limit), 1, 99)
		time_limit_minutes = cfg.get_value("match", "time_limit", time_limit_minutes)
		instagib = cfg.get_value("match", "instagib", instagib)
		duel = cfg.get_value("match", "duel", duel)
		game_mode = clampi(cfg.get_value("match", "mode", game_mode), 0, MODE_NAMES.size() - 1)
		graphics_preset = clampi(cfg.get_value("video", "graphics_preset", graphics_preset), 0, GRAPHICS_PRESETS.size() - 1)
		vsync = cfg.get_value("video", "vsync", vsync)
		window_mode = clampi(cfg.get_value("video", "window_mode", window_mode), 0, WINDOW_MODES.size() - 1)
		resolution = cfg.get_value("video", "resolution", resolution)
		for action in BINDABLE_ACTIONS:
			var events = cfg.get_value("keys", action) if cfg.has_section_key("keys", action) else []
			if events is Array and not events.is_empty():
				InputMap.action_erase_events(action)
				for ev in events:
					if ev is InputEvent:
						InputMap.action_add_event(action, ev)
	apply_graphics()
	apply_display()
	apply_master_volume()
	apply_sfx_volume()


## Speichert die aktuellen Einstellungen
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("hud", "crosshair_shape", crosshair_shape)
	cfg.set_value("hud", "crosshair_color", crosshair_color)
	cfg.set_value("hud", "crosshair_size", crosshair_size)
	cfg.set_value("hud", "hitmarker", hitmarker_enabled)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "camera_effects", camera_effects)
	cfg.set_value("match", "bot_count", bot_count)
	cfg.set_value("match", "bot_skill", bot_skill)
	cfg.set_value("match", "map", selected_map)
	cfg.set_value("match", "frag_limit", frag_limit)
	cfg.set_value("net", "name", player_name)
	cfg.set_value("net", "host_ip", last_host_ip)
	cfg.set_value("match", "capture_limit", capture_limit)
	cfg.set_value("match", "time_limit", time_limit_minutes)
	cfg.set_value("match", "instagib", instagib)
	cfg.set_value("match", "duel", duel)
	cfg.set_value("match", "mode", game_mode)
	cfg.set_value("video", "graphics_preset", graphics_preset)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "resolution", resolution)
	for action in BINDABLE_ACTIONS:
		cfg.set_value("keys", action, InputMap.action_get_events(action))
	cfg.save(SETTINGS_PATH)


## Grafik-Stufe anwenden. Niedrig/Mittel rendern mit FSR in geringerer Aufloesung, darunter fallen
## SSAO, Nebel und Schatten weg, Ultra glaettet zusaetzlich mit 4x MSAA, feineren Schatten und
## indirektem Licht (SDFGI). Die Welt-Einstellungen gelten
## fuer die geladene Arena (die Arena ruft das nach dem Laden auf).
func apply_graphics(level: Node = null) -> void:
	var p := graphics_preset
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if p < 2 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = [0.67, 0.85, 1.0, 1.0][p]
	viewport.msaa_3d = Viewport.MSAA_4X if p == 3 else Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if level == null:
		level = get_tree().current_scene
	if level == null:
		return
	for env_node in level.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = env_node.environment
		if p < 2:
			env.ssao_enabled = false
		if p < 1:
			env.volumetric_fog_enabled = false
		env.volumetric_fog_temporal_reprojection_enabled = true
		# Ultra: indirektes Licht in Echtzeit (SDFGI), ohne Backen und fuer jede Map. Neonflaechen
		# werfen ihr Licht auf Boden und Waende. Gebackene Lightmaps gehen nur im Editor.
		env.sdfgi_enabled = p == 3
		if p == 3:
			env.sdfgi_use_occlusion = true
			env.sdfgi_cascades = 4
			env.sdfgi_min_cell_size = 0.2
			env.sdfgi_bounce_feedback = 0.5
	BulletHole.pool_size = BulletHole.POOL_SIZES[p]
	# Aufloesung des volumetrischen Nebels (Lichtkegel, Dunst): feiner je Stufe
	var fog_size: int = [32, 48, 64, 128][p]
	RenderingServer.environment_set_volumetric_fog_volume_size(fog_size, [32, 48, 64, 96][p])
	RenderingServer.environment_set_volumetric_fog_filter_active(p >= 2)
	# Sonnenschatten nur so weit wie die Arena reicht, Filterqualitaet je Stufe
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][p])
	for light in level.find_children("*", "DirectionalLight3D", true, false):
		light.directional_shadow_max_distance = 70.0
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if p == 3 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if p < 1:
		for light in level.find_children("*", "Light3D", true, false):
			light.shadow_enabled = false


## Fenstermodus und Aufloesung anwenden. Im Fenster: gewaehlte Groesse (hoechstens Bildschirmgroesse),
## mittig. Vollbild nutzt die Bildschirmaufloesung; die Grafik-Stufe regelt dort die Renderaufloesung.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen := DisplayServer.window_get_current_screen()
			var screen_size := DisplayServer.screen_get_usable_rect(screen).size
			var size := Vector2i(mini(resolution.x, screen_size.x), mini(resolution.y, screen_size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect(screen).position + (screen_size - size) / 2)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


## Aufloesungen, die auf den aktuellen Bildschirm passen (ohne Bildschirm: alle)
func available_resolutions() -> Array[Vector2i]:
	if DisplayServer.get_name() == "headless":
		return RESOLUTIONS
	var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var fitting: Array[Vector2i] = RESOLUTIONS.filter(func(r: Vector2i): return r.x <= screen_size.x and r.y <= screen_size.y)
	return fitting if not fitting.is_empty() else [RESOLUTIONS[0]]


## Neue Taste fuer eine Aktion (ersetzt die bisherige Belegung). false, wenn eine andere Aktion die Taste schon nutzt
func set_binding(action: StringName, event: InputEvent) -> bool:
	for other in BINDABLE_ACTIONS:
		if other != action and InputMap.event_is_action(event, other, true):
			return false
	var stored := event.duplicate() as InputEvent
	stored.set("pressed", false)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, stored)
	return true


## Lesbarer Name der ersten Taste einer Aktion
func binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "-"
	var ev := events[0]
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Maus links", MOUSE_BUTTON_RIGHT: "Maus rechts", MOUSE_BUTTON_MIDDLE: "Maus Mitte"}.get(ev.button_index, "Maustaste %d" % ev.button_index)
	if ev is InputEventKey:
		var key: InputEventKey = ev
		# Physische Taste in die Beschriftung des aktuellen Tastaturlayouts umrechnen (nicht ohne Bildschirm)
		var code := key.keycode
		if code == KEY_NONE:
			code = key.physical_keycode if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		return OS.get_keycode_string(code)
	return ev.as_text()


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
	# Abstand zu Gegnern zaehlt (im Team-Modus nicht zu den eigenen Leuten)
	var others: Array[Node3D] = []
	for group in ["player", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			if node != for_node and node.get("health") != null and not node.health.is_dead and not are_teammates(node, for_node):
				others.append(node)
	# CTF: nur auf der eigenen Kartenhaelfte spawnen
	var candidates: Array[Node3D] = spawn_points
	if is_instance_valid(ctf) and team_of(for_node) >= 0:
		candidates = spawn_points.filter(func(p): return ctf.is_own_half(p.global_position, team_of(for_node)))
		if candidates.is_empty():
			candidates = spawn_points
	var rated: Array = []
	for point in candidates:
		var nearest: float = INF
		for other in others:
			nearest = minf(nearest, point.global_position.distance_to(other.global_position))
		rated.append({ "point": point, "dist": nearest })
	rated.sort_custom(func(a, b): return a.dist > b.dist)
	var pick: int = randi() % mini(2, rated.size())
	return rated[pick].point.global_transform


## CTF: Team erobert die Flagge (vom CtfManager aufgerufen)
func register_capture(team: int, carrier: Node) -> void:
	team_scores[team] += 1
	Net.on_capture(team, carrier)
	player_announcement.emit("%s erobert die Flagge für %s!" % [_name_of(carrier), TEAM_NAMES[team]], TEAM_COLORS[team])
	score_updated.emit(player_frags, player_deaths)
	scoreboard_changed.emit()
	if capture_limit > 0 and team_scores[team] >= capture_limit and not Net.is_client():
		end_match.call_deferred("Eroberungslimit")


## Team- oder Einzelmodus?
func is_team_mode() -> bool:
	return game_mode != Mode.DEATHMATCH


## Team eines Kaempfers (-1 = keins, z. B. im Deathmatch oder Umgebungsschaden)
func team_of(node: Node) -> int:
	if not is_instance_valid(node) or node.get("team") == null:
		return -1
	return node.team


## Zwei verschiedene Kaempfer im selben Team? (kein Eigenbeschuss, Bots zielen nicht aufeinander)
func are_teammates(a: Node, b: Node) -> bool:
	return is_team_mode() and a != b and team_of(a) >= 0 and team_of(a) == team_of(b)


## Gibt einen zufaelligen Spawnpunkt zurueck
func get_random_spawn_transform() -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 1.5, 0.0))
	var random_index: int = randi() % spawn_points.size()
	return spawn_points[random_index].global_transform
