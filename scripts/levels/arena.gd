extends Node3D

## Level-Skript fuer die Test-Arena
## Backt das Navigationsnetz, registriert die Spawnpunkte und erzeugt die Bots
## nach den Match-Einstellungen (Anzahl und Schwierigkeit) aus dem GameManager.

const BOT_SCENE: PackedScene = preload("res://scenes/bot.tscn")
const BOT_NAMES: Array[String] = ["Vex", "Kortex", "Rhea", "Nyx", "Talon", "Orbit", "Grimm"]
## Leuchtfarbe je Bot (gut unterscheidbar, keine davon nahe am Cyan des Bodens)
const BOT_COLORS: Array[Color] = [
	Color(1.0, 0.22, 0.18), Color(1.0, 0.8, 0.1), Color(0.55, 1.0, 0.2), Color(0.8, 0.3, 1.0),
	Color(1.0, 0.45, 0.05), Color(1.0, 0.3, 0.75), Color(0.95, 0.95, 0.95),
]

@onready var spawn_points_container: Node3D = $SpawnPoints


func _ready() -> void:
	# Navigationsnetz aus der Geometrie backen, damit Bots Waenden und Pfeilern ausweichen
	var nav_region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if nav_region:
		nav_region.bake_navigation_mesh(false)

	GameManager.spawn_points.clear()

	# Alle Spawnpunkte im GameManager registrieren
	if spawn_points_container:
		for spawn in spawn_points_container.get_children():
			if spawn is Node3D:
				GameManager.register_spawn_point(spawn)

	_spawn_bots()
	GameManager.apply_graphics(self)
	GameManager.start_match()


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
