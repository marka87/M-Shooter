extends Control

## Hauptmenue-Steuerung fuer den Arena-Shooter
## Ermoeglicht Spielstart, Anpassen von Mausempfindlichkeit & Lautstaerke sowie Beenden.

@onready var main_buttons: VBoxContainer = $CenterContainer/MainButtons
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel

@onready var sens_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/SensContainer/HBox/SensSlider
@onready var sens_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/SensContainer/HBox/SensValueLabel

@onready var volume_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/VolumeContainer/HBox/VolumeSlider
@onready var volume_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/VolumeContainer/HBox/VolumeValueLabel


func _ready() -> void:
	# Mauszeiger im Menue sichtbar machen und Spiel entpausieren
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	
	GameManager.current_state = GameManager.GameState.MENU
	
	# Schieberegler mit den gespeicherten Einstellungen initialisieren
	if sens_slider:
		sens_slider.value = GameManager.mouse_sensitivity
		_update_sens_label(GameManager.mouse_sensitivity)
	
	if volume_slider:
		volume_slider.value = GameManager.master_volume
		_update_volume_label(GameManager.master_volume)
	
	# Signale verbinden
	if sens_slider:
		sens_slider.value_changed.connect(_on_sens_changed)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)


## Spiel in der Test-Arena starten
func _on_start_button_pressed() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://levels/test_arena.tscn")


## Einstellungs-Menue anzeigen
func _on_settings_button_pressed() -> void:
	main_buttons.visible = false
	settings_panel.visible = true


## Zurueck zu den Haupt-Buttons
func _on_back_button_pressed() -> void:
	GameManager.save_settings()
	settings_panel.visible = false
	main_buttons.visible = true


## Spiel beenden
func _on_quit_button_pressed() -> void:
	get_tree().quit()


## Mausempfindlichkeit aendern
func _on_sens_changed(val: float) -> void:
	GameManager.mouse_sensitivity = val
	_update_sens_label(val)


## Master-Lautstaerke aendern
func _on_volume_changed(val: float) -> void:
	GameManager.master_volume = val
	GameManager.apply_master_volume()

	_update_volume_label(val)


func _update_sens_label(val: float) -> void:
	if sens_value_label:
		sens_value_label.text = "%.4f" % val


func _update_volume_label(val: float) -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(val * 100)
