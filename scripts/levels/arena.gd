extends Node3D

## Level-Skript fuer die Test-Arena
## Backt das Navigationsnetz, registriert die Spawnpunkte und erzeugt die Bots
## nach den Match-Einstellungen (Anzahl und Schwierigkeit) aus dem GameManager.

const BOT_SCENE: PackedScene = preload("res://scenes/bot.tscn")
const BOT_NAMES: Array[String] = ["Vex", "Kortex", "Rhea", "Nyx", "Talon", "Orbit", "Grimm"]

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


## Bots nach Match-Einstellungen erzeugen, jeweils am freiesten Spawnpunkt
func _spawn_bots() -> void:
	for i in clampi(GameManager.bot_count, 0, BOT_NAMES.size()):
		var bot: Bot = BOT_SCENE.instantiate()
		bot.name = "Bot%d" % (i + 1)
		bot.display_name = BOT_NAMES[i]
		bot.apply_skill(GameManager.bot_skill)
		add_child(bot)
		bot.global_transform = GameManager.get_spawn_transform(bot)
