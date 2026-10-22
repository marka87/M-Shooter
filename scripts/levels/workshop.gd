extends Node3D

## Waffen-Werkstatt: leere Map ohne Bots, Items und Zeitlimit. Alle Waffen mit voller Munition,
## der Viewmodel-Editor ist sofort an (Waffe und Hand pro Waffe einstellen, F6 speichert).


func _ready() -> void:
	GameManager.spawn_points.clear()
	GameManager.ctf = null
	GameManager.match_time_left = 0.0
	GameManager.current_state = GameManager.GameState.PLAYING
	var player: Player = GameManager.current_player
	for weapon in player.weapon_manager.weapons:
		weapon.owned = true
		weapon.current_ammo = weapon.max_ammo
	player.weapon_manager.loadout_changed.emit()
	# Kein Match: keine Frags (die Uhr bleibt ohne Restzeit ohnehin aus)
	player.hud.frags_label.hide()
	player.hud.control_hints.hide()
	player.get_node("ViewmodelTuner").set_active(true)
