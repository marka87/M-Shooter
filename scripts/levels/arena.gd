extends Node3D

## Level-Skript fuer die Test-Arena
## Registriert die Spawnpunkte beim GameManager fuer Respawns.

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
