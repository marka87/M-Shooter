extends CanvasLayer
class_name HUD

## Spieler-HUD: Leben, Ruestung, Waffe, Munition, Frags, Tacho, Treffer-Feedback, Todes-Overlay.
## Haengt sich per bind() an die Signale des Spielers und zeigt nur an, spielt keine Logik.

@onready var speed_label: Label = $SpeedLabel
@onready var frags_label: Label = $FragsLabel
@onready var health_label: Label = $StatsContainer/HealthLabel
@onready var armor_label: Label = $StatsContainer/ArmorLabel
@onready var weapon_name_label: Label = $WeaponInfo/WeaponNameLabel
@onready var ammo_label: Label = $WeaponInfo/AmmoLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var hitmarker: Control = $CrosshairContainer/Hitmarker
@onready var death_overlay: Control = $DeathOverlay
@onready var respawn_countdown_label: Label = $DeathOverlay/VBox/RespawnCountdownLabel
@onready var kill_feed: VBoxContainer = $KillFeed
@onready var scoreboard: PanelContainer = $Scoreboard
@onready var scoreboard_grid: GridContainer = $Scoreboard/Margin/VBox/Grid

## Wie viele Killfeed-Zeilen gleichzeitig sichtbar sind und wie lange
const KILL_FEED_MAX: int = 5
const KILL_FEED_SECONDS: float = 4.0

var player: Player = null


## Verbindet das HUD mit einem Spieler und zeigt sofort dessen aktuellen Stand
func bind(p: Player) -> void:
	player = p
	player.health.changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_damaged)
	player.health.died.connect(func(_info: DamageInfo): death_overlay.show())
	player.enemy_hit.connect(show_hitmarker)
	player.weapon_manager.weapon_switched.connect(_on_weapon_switched)
	player.weapon_manager.ammo_updated.connect(_on_ammo_updated)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.kill_registered.connect(add_kill_entry)
	GameManager.scoreboard_changed.connect(_refresh_scoreboard)
	_refresh_scoreboard()

	_on_health_changed(player.health.health, player.health.armor)
	_on_score_updated(GameManager.player_frags, GameManager.player_deaths)
	var weapon := player.weapon_manager.get_current_weapon()
	if weapon:
		_on_weapon_switched(weapon.weapon_name, weapon.current_ammo, weapon.max_ammo)


func _process(_delta: float) -> void:
	if not player:
		return
	_update_speed()
	# Scoreboard nur solange Tab gehalten wird
	scoreboard.visible = Input.is_action_pressed("scoreboard")
	# Countdown im Todes-Overlay (death_timer pausiert mit dem Spiel)
	if player.is_dead:
		respawn_countdown_label.text = "Respawn in %.1f Sekunden..." % maxf(player.death_timer, 0.0)


## Tacho: gruen bei Strafe-Jump-Tempo, gelb beim Sprinten
func _update_speed() -> void:
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var ground_state: String = "BODEN" if player.is_on_floor() else "LUFT"
	speed_label.text = "Geschwindigkeit: %4.1f m/s [%s]" % [horizontal_speed, ground_state]
	if horizontal_speed > player.sprint_speed + 1.0:
		speed_label.modulate = Color(0.2, 1.0, 0.4)
	elif player.is_sprinting:
		speed_label.modulate = Color(1.0, 0.8, 0.2)
	else:
		speed_label.modulate = Color(1.0, 1.0, 1.0)


func _on_health_changed(health: float, armor: float) -> void:
	# Nach dem Respawn (health.reset) das Todes-Overlay wieder ausblenden
	if not player.is_dead:
		death_overlay.hide()
	health_label.text = "HP: %d" % int(maxf(health, 0.0))
	health_label.modulate = Color(1.0, 0.2, 0.2) if health <= 25.0 else Color(0.2, 1.0, 0.5)
	armor_label.text = "RÜSTUNG: %d" % int(maxf(armor, 0.0))
	armor_label.modulate = Color(0.2, 0.8, 1.0)


## Roter Bildschirmblitz bei Treffern
func _on_damaged(_info: DamageInfo, _health_lost: float) -> void:
	damage_flash.color = Color(0.9, 0.1, 0.1, 0.35)
	var tween := create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.25)


## Roter Hitmarker am Fadenkreuz
func show_hitmarker() -> void:
	hitmarker.visible = true
	hitmarker.modulate = Color(1.0, 0.25, 0.25, 1.0)
	var tween := create_tween()
	tween.tween_property(hitmarker, "modulate:a", 0.0, 0.12)
	tween.tween_callback(hitmarker.hide)


func _on_weapon_switched(w_name: String, current_ammo: int, max_ammo: int) -> void:
	weapon_name_label.text = w_name
	_on_ammo_updated(current_ammo, max_ammo)


func _on_ammo_updated(current_ammo: int, max_ammo: int) -> void:
	ammo_label.text = "Munition: %d / %d" % [current_ammo, max_ammo]


func _on_score_updated(frags: int, _deaths: int) -> void:
	frags_label.text = "Frags: %d" % frags


## Neue Zeile im Killfeed oben rechts, verschwindet nach ein paar Sekunden
func add_kill_entry(killer_name: String, victim_name: String, weapon_name: String) -> void:
	var entry := Label.new()
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.add_theme_font_size_override("font_size", 17)
	entry.add_theme_color_override("font_outline_color", Color.BLACK)
	entry.add_theme_constant_override("outline_size", 4)
	if killer_name == victim_name:
		entry.text = "%s  [%s]  (Selbstmord)" % [victim_name, weapon_name]
	else:
		entry.text = "%s  [%s]  %s" % [killer_name, weapon_name, victim_name]
	# Eigene Abschuesse gruen, eigene Tode rot hervorheben
	if killer_name == player.display_name and killer_name != victim_name:
		entry.modulate = Color(0.4, 1.0, 0.5)
	elif victim_name == player.display_name:
		entry.modulate = Color(1.0, 0.4, 0.35)
	kill_feed.add_child(entry)

	while kill_feed.get_child_count() > KILL_FEED_MAX:
		var oldest := kill_feed.get_child(0)
		kill_feed.remove_child(oldest)
		oldest.queue_free()

	var tween := entry.create_tween()
	tween.tween_interval(KILL_FEED_SECONDS)
	tween.tween_property(entry, "modulate:a", 0.0, 0.5)
	tween.tween_callback(entry.queue_free)


## Tabelle neu aufbauen: Name | Frags | Tode, sortiert nach Frags
func _refresh_scoreboard() -> void:
	for child in scoreboard_grid.get_children():
		scoreboard_grid.remove_child(child)
		child.queue_free()
	_add_score_row("NAME", "FRAGS", "TODE", Color(0.6, 0.65, 0.75))
	for row in GameManager.get_scoreboard():
		var color := Color(1.0, 0.85, 0.3) if row.is_player else Color.WHITE
		_add_score_row(row.name, str(row.frags), str(row.deaths), color)


func _add_score_row(name_text: String, frags_text: String, deaths_text: String, color: Color) -> void:
	for text in [name_text, frags_text, deaths_text]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 20)
		label.modulate = color
		if text != name_text:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scoreboard_grid.add_child(label)
