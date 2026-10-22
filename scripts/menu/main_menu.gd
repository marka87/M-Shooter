extends Control

## Hauptmenue-Steuerung fuer den Arena-Shooter
## Ermoeglicht Spielstart (mit Bot-Anzahl und Schwierigkeit), Einstellungen sowie Beenden.

@onready var main_buttons: VBoxContainer = $CenterContainer/MainButtons
@onready var version_label: Label = $VersionLabel
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel
@onready var match_panel: PanelContainer = $CenterContainer/MatchPanel

@onready var bot_slider: HSlider = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/BotsContainer/HBox/BotSlider
@onready var bot_value_label: Label = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/BotsContainer/HBox/BotValueLabel
@onready var map_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/MapContainer/MapOption
@onready var frag_limit_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/LimitsContainer/FragBox/FragLimitOption
@onready var time_limit_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/LimitsContainer/TimeBox/TimeLimitOption
@onready var skill_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/SkillContainer/SkillOption
@onready var duel_check: CheckButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/DuelCheck
@onready var game_mode_option: OptionButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/ModeContainer/ModeOption
@onready var instagib_check: CheckButton = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/InstagibCheck
@onready var fight_button: Button = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/FightButton
@onready var match_back_button: Button = $CenterContainer/MatchPanel/MarginContainer/VBoxContainer/MatchBackButton

@onready var sens_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/SensContainer/HBox/SensSlider
@onready var sens_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/SensContainer/HBox/SensValueLabel

@onready var volume_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/VolumeContainer/HBox/VolumeSlider
@onready var volume_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/VolumeContainer/HBox/VolumeValueLabel

@onready var music_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/MusicContainer/HBox/MusicSlider
@onready var music_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/MusicContainer/HBox/MusicValueLabel
@onready var camera_fx_check: CheckButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/CameraFxCheck
@onready var fov_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/FovContainer/HBox/FovSlider
@onready var fov_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/FovContainer/HBox/FovValueLabel
@onready var graphics_option: OptionButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/GraphicsOption
@onready var vsync_check: CheckButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/VsyncCheck
@onready var mode_option: OptionButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/DisplayRow/ModeOption
@onready var resolution_option: OptionButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/DisplayRow/ResolutionOption
@onready var keys_grid: GridContainer = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/KeysGrid
@onready var sfx_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/SfxContainer/HBox/SfxSlider
@onready var sfx_value_label: Label = $CenterContainer/SettingsPanel/MarginContainer/Columns/VBoxContainer/SfxContainer/HBox/SfxValueLabel
@onready var shape_option: OptionButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/CrosshairRow/ShapeOption
@onready var color_option: OptionButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/CrosshairRow/ColorOption
@onready var size_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/SizeSlider
@onready var hitmarker_check: CheckButton = $CenterContainer/SettingsPanel/MarginContainer/Columns/RightColumn/HitmarkerCheck

# Aktion, die gerade neu belegt wird (leer = keine), und ihr Button
var _rebind_action: StringName = &""
var _rebind_button: Button = null


func _ready() -> void:
	# Mauszeiger im Menue sichtbar machen und Spiel entpausieren
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	
	GameManager.current_state = GameManager.GameState.MENU

	# Versionsnummer aus den Projekteinstellungen (application/config/version) und Engine-Version
	var engine := Engine.get_version_info()
	version_label.text = "Version %s  ·  Godot %s.%s.%s" % [
		ProjectSettings.get_setting("application/config/version", "?"), engine.major, engine.minor, engine.patch]
	
	# Schieberegler mit den gespeicherten Einstellungen initialisieren
	if sens_slider:
		sens_slider.value = GameManager.mouse_sensitivity
		_update_sens_label(GameManager.mouse_sensitivity)
	
	if volume_slider:
		volume_slider.value = GameManager.master_volume
		_update_volume_label(GameManager.master_volume)
	
	music_slider.value = GameManager.music_volume
	music_value_label.text = "%d%%" % int(GameManager.music_volume * 100)
	music_slider.value_changed.connect(func(v: float):
		GameManager.music_volume = v
		GameManager.apply_music_volume()
		music_value_label.text = "%d%%" % int(v * 100))
	camera_fx_check.button_pressed = GameManager.camera_effects
	camera_fx_check.toggled.connect(func(on: bool): GameManager.camera_effects = on)
	fov_slider.value = GameManager.fov
	_update_fov_label(GameManager.fov)
	for preset_name in GameManager.GRAPHICS_PRESETS:
		graphics_option.add_item(preset_name)
	graphics_option.selected = GameManager.graphics_preset
	graphics_option.item_selected.connect(func(i: int):
		GameManager.graphics_preset = i
		GameManager.apply_graphics())
	for mode_name in GameManager.WINDOW_MODES:
		mode_option.add_item(mode_name)
	mode_option.selected = GameManager.window_mode
	var resolutions := GameManager.available_resolutions()
	for res in resolutions:
		resolution_option.add_item("%d × %d" % [res.x, res.y])
	resolution_option.selected = maxi(resolutions.find(GameManager.resolution), 0)
	# Aufloesung gilt nur im Fenster; im Vollbild gibt der Bildschirm sie vor
	resolution_option.disabled = GameManager.window_mode != 0
	mode_option.item_selected.connect(func(i: int):
		GameManager.window_mode = i
		resolution_option.disabled = i != 0
		GameManager.apply_display())
	resolution_option.item_selected.connect(func(i: int):
		GameManager.resolution = resolutions[i]
		GameManager.apply_display())
	vsync_check.button_pressed = GameManager.vsync
	vsync_check.toggled.connect(func(on: bool):
		GameManager.vsync = on
		GameManager.apply_graphics())
	_build_key_rows()
	sfx_slider.value = GameManager.sfx_volume
	sfx_value_label.text = "%d%%" % int(GameManager.sfx_volume * 100)
	sfx_slider.value_changed.connect(func(v: float):
		GameManager.sfx_volume = v
		GameManager.apply_sfx_volume()
		sfx_value_label.text = "%d%%" % int(v * 100))
	for shape_name in Crosshair.SHAPES:
		shape_option.add_item(shape_name)
	shape_option.selected = GameManager.crosshair_shape
	shape_option.item_selected.connect(func(i: int): GameManager.crosshair_shape = i)
	for color_name in Crosshair.COLOR_NAMES:
		color_option.add_item(color_name)
	color_option.selected = GameManager.crosshair_color
	color_option.item_selected.connect(func(i: int): GameManager.crosshair_color = i)
	size_slider.value = GameManager.crosshair_size
	size_slider.value_changed.connect(func(v: float): GameManager.crosshair_size = v)
	hitmarker_check.button_pressed = GameManager.hitmarker_enabled
	hitmarker_check.toggled.connect(func(on: bool): GameManager.hitmarker_enabled = on)

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
	instagib_check.button_pressed = GameManager.instagib
	duel_check.button_pressed = GameManager.duel
	# Duell gibt es nur im Deathmatch (eins gegen eins ohne Teams)
	for mode_name in GameManager.MODE_NAMES:
		game_mode_option.add_item(mode_name)
	game_mode_option.selected = GameManager.game_mode
	duel_check.disabled = GameManager.is_team_mode()
	bot_slider.editable = not (GameManager.duel and not GameManager.is_team_mode())
	game_mode_option.item_selected.connect(func(i: int):
		GameManager.game_mode = i
		duel_check.disabled = GameManager.is_team_mode()
		bot_slider.editable = not (GameManager.duel and not GameManager.is_team_mode()))
	duel_check.toggled.connect(func(on: bool):
		GameManager.duel = on
		bot_slider.editable = not on)
	instagib_check.toggled.connect(func(on: bool): GameManager.instagib = on)

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


## Eine Zeile pro belegbarer Aktion: Name und Button mit der aktuellen Taste
func _build_key_rows() -> void:
	for action in GameManager.BINDABLE_ACTIONS:
		var label := Label.new()
		label.text = GameManager.BINDABLE_ACTIONS[action]
		keys_grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, 30)
		button.text = GameManager.binding_text(action)
		button.pressed.connect(func():
			_cancel_rebind()
			_rebind_action = action
			_rebind_button = button
			button.text = "Taste drücken ...")
		keys_grid.add_child(button)


func _cancel_rebind() -> void:
	if _rebind_button:
		_rebind_button.text = GameManager.binding_text(_rebind_action)
	_rebind_action = &""
	_rebind_button = null


## Waehrend einer Neubelegung die naechste Taste oder Maustaste uebernehmen (ESC bricht ab)
func _input(event: InputEvent) -> void:
	if _rebind_action == &"" or not event.is_pressed() or event.is_echo():
		return
	var is_key := event is InputEventKey
	var is_button := event is InputEventMouseButton and (event as InputEventMouseButton).button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if not (is_key or is_button):
		return
	get_viewport().set_input_as_handled()
	if is_key and (event as InputEventKey).keycode == KEY_ESCAPE:
		_cancel_rebind()
		return
	if not GameManager.set_binding(_rebind_action, event):
		_rebind_button.text = "Belegt – andere Taste"
		return
	_cancel_rebind()


## Zurueck zu den Haupt-Buttons
func _on_back_button_pressed() -> void:
	_cancel_rebind()
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
