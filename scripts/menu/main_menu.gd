extends Control

## Hauptmenue-Steuerung fuer den Arena-Shooter
## Ermoeglicht Spielstart (mit Bot-Anzahl und Schwierigkeit), Einstellungen sowie Beenden.

@onready var main_buttons: VBoxContainer = $CenterContainer/MainButtons
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel
@onready var match_panel: PanelContainer = $CenterContainer/MatchPanel

@onready var bot_slider: HSlider = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/BotsContainer/HBox/BotSlider
@onready var bot_value_label: Label = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/BotsContainer/HBox/BotValueLabel
@onready var map_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/MapContainer/MapOption
@onready var frag_limit_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/LimitsContainer/FragBox/FragLimitOption
@onready var time_limit_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/LimitsContainer/TimeBox/TimeLimitOption
@onready var skill_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/SkillContainer/SkillOption
@onready var fight_button: Button = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/FightButton
@onready var match_back_button: Button = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/MatchBackButton

@onready var sens_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/SensContainer/HBox/SensSlider
@onready var sens_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/SensContainer/HBox/SensValueLabel

@onready var volume_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/VolumeContainer/HBox/VolumeSlider
@onready var volume_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/VolumeContainer/HBox/VolumeValueLabel

@onready var fov_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/FovContainer/HBox/FovSlider
@onready var fov_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/FovContainer/HBox/FovValueLabel


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
	
	fov_slider.value = GameManager.fov
	_update_fov_label(GameManager.fov)

	# Match-Einstellungen
	bot_slider.max_value = GameManager.MAX_BOTS
	bot_slider.value = GameManager.bot_count
	bot_value_label.text = str(GameManager.bot_count)
	for map_info in GameManager.MAPS:
		map_option.add_item(map_info.name)
	map_option.selected = GameManager.selected_map
	map_option.item_selected.connect(func(index: int): GameManager.selected_map = index)
	# Frag- und Zeit-Limit (0 = kein Limit)
	for limit in GameManager.FRAG_LIMITS:
		frag_limit_option.add_item(str(limit) if limit > 0 else "Kein")
	frag_limit_option.selected = maxi(GameManager.FRAG_LIMITS.find(GameManager.frag_limit), 0)
	frag_limit_option.item_selected.connect(func(i: int): GameManager.frag_limit = GameManager.FRAG_LIMITS[i])
	for minutes in GameManager.TIME_LIMITS:
		time_limit_option.add_item("%d Min" % minutes if minutes > 0 else "Kein")
	time_limit_option.selected = maxi(GameManager.TIME_LIMITS.find(int(GameManager.time_limit_minutes)), 0)
	time_limit_option.item_selected.connect(func(i: int): GameManager.time_limit_minutes = GameManager.TIME_LIMITS[i])
	for skill_name in Bot.SKILL_NAMES:
		skill_option.add_item(skill_name)
	skill_option.selected = GameManager.bot_skill

	# Signale verbinden
	bot_slider.value_changed.connect(_on_bot_count_changed)
	skill_option.item_selected.connect(_on_skill_selected)
	fight_button.pressed.connect(_on_fight_pressed)
	match_back_button.pressed.connect(_on_match_back_pressed)
	fov_slider.value_changed.connect(_on_fov_changed)
	if sens_slider:
		sens_slider.value_changed.connect(_on_sens_changed)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)


## Match-Fenster (Bots, Schwierigkeit) anzeigen
func _on_start_button_pressed() -> void:
	main_buttons.visible = false
	match_panel.visible = true
	fight_button.grab_focus()


## Match mit den gewaehlten Einstellungen in der gewaehlten Arena starten
func _on_fight_pressed() -> void:
	GameManager.save_settings()
	GameManager.reset_game()
	get_tree().change_scene_to_file(GameManager.MAPS[GameManager.selected_map].scene)


func _on_match_back_pressed() -> void:
	GameManager.save_settings()
	match_panel.visible = false
	main_buttons.visible = true


func _on_bot_count_changed(val: float) -> void:
	GameManager.bot_count = int(val)
	bot_value_label.text = str(int(val))


func _on_skill_selected(index: int) -> void:
	GameManager.bot_skill = index


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
	GameManager.quit_game()


## Mausempfindlichkeit aendern
func _on_sens_changed(val: float) -> void:
	GameManager.mouse_sensitivity = val
	_update_sens_label(val)


## Master-Lautstaerke aendern
func _on_volume_changed(val: float) -> void:
	GameManager.master_volume = val
	GameManager.apply_master_volume()

	_update_volume_label(val)


## Sichtfeld aendern
func _on_fov_changed(val: float) -> void:
	GameManager.fov = val
	_update_fov_label(val)


func _update_fov_label(val: float) -> void:
	fov_value_label.text = "%d°" % int(val)


func _update_sens_label(val: float) -> void:
	if sens_value_label:
		sens_value_label.text = "%.4f" % val


func _update_volume_label(val: float) -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(val * 100)
