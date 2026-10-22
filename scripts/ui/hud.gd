extends CanvasLayer
class_name HUD

## Spieler-HUD: Leben, Ruestung, Waffe, Munition, Frags, Tacho, Treffer-Feedback, Todes-Overlay.
## Haengt sich per bind() an die Signale des Spielers und zeigt nur an, spielt keine Logik.

@onready var speed_label: Label = $SpeedLabel
@onready var frags_label: Label = $FragsLabel
@onready var health_label: Label = $Vitals/HealthBox/Row/HealthLabel
@onready var health_bar: ProgressBar = $Vitals/HealthBox/HealthBar
@onready var armor_label: Label = $Vitals/ArmorBox/Row/ArmorLabel
@onready var armor_bar: ProgressBar = $Vitals/ArmorBox/ArmorBar
@onready var ammo_label: Label = $AmmoBox/AmmoLabel
@onready var ammo_bar: ProgressBar = $AmmoBox/AmmoBar
@onready var weapon_name_label: Label = $AmmoBox/WeaponNameLabel
@onready var weapon_slots: HBoxContainer = $AmmoBox/WeaponBar
@onready var control_hints: Label = $ControlHints
@onready var announce_label: Label = $AnnounceLabel
@onready var quad_label: Label = $QuadLabel
@onready var timer_label: Label = $TimerLabel
var _announce_tween: Tween = null
@onready var damage_flash: ColorRect = $DamageFlash
@onready var hitmarker: Control = $CrosshairContainer/Hitmarker
@onready var death_overlay: Control = $DeathOverlay
@onready var respawn_countdown_label: Label = $DeathOverlay/VBox/RespawnCountdownLabel
@onready var kill_feed: VBoxContainer = $KillFeed
@onready var scoreboard: PanelContainer = $Scoreboard
@onready var scoreboard_grid: GridContainer = $Scoreboard/Margin/VBox/Grid

## Kurznamen in der Waffenleiste
const SLOT_NAMES := { &"machine_gun": "MG", &"shotgun": "SG", &"plasma": "PL", &"rocket_launcher": "RL",
	&"lightning": "LG", &"railgun": "RG", &"shock_rifle": "SR" }

## Wie viele Killfeed-Zeilen gleichzeitig sichtbar sind und wie lange
const KILL_FEED_MAX: int = 5
const KILL_FEED_SECONDS: float = 4.0

var player: Player = null
# Debug-Anzeige fuer Movement-Tuning (F3): Luftzeit und Spitzentempo des aktuellen Sprungs
var debug_label: Label
var chat_box: VBoxContainer
const CHAT_MAX: int = 4
const CHAT_SECONDS: float = 6.0
var _air_time: float = 0.0
var _peak_speed: float = 0.0


## Verbindet das HUD mit einem Spieler und zeigt sofort dessen aktuellen Stand
func bind(p: Player) -> void:
	player = p
	player.health.changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_damaged)
	player.health.died.connect(func(_info: DamageInfo): death_overlay.show())
	player.enemy_hit.connect(show_hitmarker)
	player.item_picked.connect(_on_item_picked)
	player.weapon_manager.weapon_switched.connect(_on_weapon_switched)
	player.weapon_manager.ammo_updated.connect(_on_ammo_updated)
	player.weapon_manager.loadout_changed.connect(_refresh_slots)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.kill_registered.connect(add_kill_entry)
	GameManager.scoreboard_changed.connect(_refresh_scoreboard)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.player_announcement.connect(announce)
	_refresh_scoreboard()

	debug_label = Label.new()
	debug_label.visible = false
	debug_label.position = Vector2(20, 200)
	debug_label.add_theme_font_size_override("font_size", 15)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_constant_override("outline_size", 5)
	add_child(debug_label)

	chat_box = VBoxContainer.new()
	chat_box.name = "ChatBox"
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.offset_left = 36.0
	chat_box.offset_right = 520.0
	chat_box.offset_top = -260.0
	chat_box.offset_bottom = -140.0
	chat_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(chat_box)
	GameManager.bot_chat.connect(add_chat_line)

	health_bar.max_value = player.health.max_health
	armor_bar.max_value = player.health.max_armor
	_on_health_changed(player.health.health, player.health.armor)

	# Tastenhilfe nach ein paar Sekunden ausblenden
	var hints_tween := create_tween()
	hints_tween.tween_interval(8.0)
	hints_tween.tween_property(control_hints, "modulate:a", 0.0, 1.5)
	_on_score_updated(GameManager.player_frags, GameManager.player_deaths)
	var weapon := player.weapon_manager.get_current_weapon()
	if weapon:
		_on_weapon_switched(weapon.weapon_name, weapon.current_ammo, weapon.max_ammo)


func _process(delta: float) -> void:
	if not player:
		return
	_update_speed()
	_update_debug(delta)
	_update_quad()
	_update_timer()
	# Scoreboard nur solange Tab gehalten wird
	scoreboard.visible = Input.is_action_pressed("scoreboard")
	# Countdown im Todes-Overlay (death_timer pausiert mit dem Spiel)
	if player.is_dead:
		respawn_countdown_label.text = "Respawn in %.1f Sekunden..." % maxf(player.death_timer, 0.0)


## Quad-Countdown ueber der Waffenleiste und violetter Bildrand (CRT-Overlay)
func _update_quad() -> void:
	var t: float = player.powerups.quad_time_left
	quad_label.visible = t > 0.0
	if t > 0.0:
		quad_label.text = "QUAD %d" % ceili(t)
		# Letzte 3 Sekunden blinken
		quad_label.modulate.a = 1.0 if t > 3.0 or fmod(t, 0.5) > 0.25 else 0.3
	var crt := player.get_node_or_null("CRTOverlay/Screen") as ColorRect
	if crt and crt.material:
		(crt.material as ShaderMaterial).set_shader_parameter("quad_glow", 0.6 if t > 0.0 else 0.0)


## Restzeit oben (mm:ss), letzte 30 Sekunden rot. Ohne Zeitlimit ausgeblendet.
func _update_timer() -> void:
	timer_label.visible = GameManager.time_limit_minutes > 0.0
	if not timer_label.visible:
		return
	var t: int = ceili(GameManager.match_time_left)
	timer_label.text = "%d:%02d" % [t / 60, t % 60]
	timer_label.modulate = Color(1.0, 0.35, 0.3) if t <= 30 else Color.WHITE


## Countdown vor dem Start: 3, 2, 1, FIGHT!
func _on_countdown_tick(seconds_left: int) -> void:
	if seconds_left > 0:
		announce(str(seconds_left), Color(0.85, 0.95, 1.0))
	else:
		announce("FIGHT!", Color(1.0, 0.45, 0.15))


## Grosse Ansage in der Bildmitte, blendet nach kurzer Zeit aus
func announce(text: String, color: Color) -> void:
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	announce_label.modulate.a = 1.0
	announce_label.scale = Vector2.ONE * 1.3
	announce_label.pivot_offset = announce_label.size / 2.0
	_announce_tween = create_tween()
	_announce_tween.tween_property(announce_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_interval(0.6 if text.length() <= 2 else 1.4)
	_announce_tween.tween_property(announce_label, "modulate:a", 0.0, 0.4)


func _on_item_picked(pickup_type: int, item_name: String) -> void:
	match pickup_type:
		ItemPickup.PickupType.WEAPON:
			var weapon := player.weapon_manager.get_current_weapon()
			announce(item_name.to_upper(), weapon.data.color if weapon else Color.WHITE)
		ItemPickup.PickupType.QUAD_DAMAGE:
			announce("QUAD DAMAGE!", Color(0.8, 0.5, 1.0))
		ItemPickup.PickupType.MEGA_HEALTH:
			announce("MEGA HEALTH", Color(0.4, 0.75, 1.0))


## Tacho mit FPS: gruen bei Strafe-Jump-Tempo, gelb beim Sprinten
func _update_speed() -> void:
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var ground_state: String = "BODEN" if player.is_on_floor() else "LUFT"
	speed_label.text = "Geschwindigkeit: %4.1f m/s [%s]   %d FPS" % [horizontal_speed, ground_state, Engine.get_frames_per_second()]
	if horizontal_speed > player.movement.sprint_speed + 1.0:
		speed_label.modulate = Color(0.2, 1.0, 0.4)
	elif player.movement.is_sprinting:
		speed_label.modulate = Color(1.0, 0.8, 0.2)
	else:
		speed_label.modulate = Color(1.0, 1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_label.visible = not debug_label.visible


## Movement-Werte (F3): Tempo waagrecht/senkrecht, Spitzentempo und Luftzeit des Sprungs, Eingaberichtung
func _update_debug(delta: float) -> void:
	var h_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if player.is_on_floor():
		if _air_time > 0.0:
			_air_time = 0.0
			_peak_speed = 0.0
	else:
		_air_time += delta
	_peak_speed = maxf(_peak_speed, h_speed)
	if not debug_label.visible:
		return
	var wish: Vector3 = player.get_input_direction()
	debug_label.text = "Tempo  %5.1f m/s  (senkrecht %5.1f)\nSpitze %5.1f m/s im Sprung\nLuftzeit %4.2f s\nEingabe (%4.1f, %4.1f)  %s\n%d FPS" % [
		h_speed, player.velocity.y, _peak_speed, _air_time, wish.x, wish.z,
		"Boden" if player.is_on_floor() else "Luft", Engine.get_frames_per_second()]


func _on_health_changed(health: float, armor: float) -> void:
	# Nach dem Respawn (health.reset) das Todes-Overlay wieder ausblenden
	if not player.is_dead:
		death_overlay.hide()
	health_label.text = str(int(maxf(health, 0.0)))
	health_bar.value = health
	# Wenig Leben: Zahl rot
	# Wenig Leben: rot, Ueberheilung durch Mega Health: blau
	if health <= 25.0:
		health_label.modulate = Color(1.0, 0.3, 0.3)
	elif health > player.health.max_health:
		health_label.modulate = Color(0.5, 0.8, 1.0)
	else:
		health_label.modulate = Color.WHITE
	armor_label.text = str(int(maxf(armor, 0.0)))
	armor_bar.value = armor


## Roter Bildschirmblitz bei Treffern, dazu ein kurzer Puls im CRT-Overlay (roter Rand, Farbsaum)
## und die Lebensanzeige zuckt rot
func _on_damaged(info: DamageInfo, health_lost: float) -> void:
	_show_hit_direction(info)
	health_label.self_modulate = Color(1.0, 0.3, 0.3)
	create_tween().tween_property(health_label, "self_modulate", Color.WHITE, 0.3)
	damage_flash.color = Color(0.9, 0.1, 0.1, 0.18)
	var tween := create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.25)
	var crt := player.get_node_or_null("CRTOverlay/Screen") as ColorRect
	if crt and crt.material:
		var mat := crt.material as ShaderMaterial
		mat.set_shader_parameter("damage_pulse", clampf(0.3 + health_lost / 40.0, 0.3, 1.0))
		var pulse := create_tween()
		pulse.tween_method(func(v: float): mat.set_shader_parameter("damage_pulse", v), mat.get_shader_parameter("damage_pulse"), 0.0, 0.4)
		# Ruestung hat einen Teil geschluckt: blauer Schild am Rand
		if player.health.last_absorbed > 0.0:
			var shield := create_tween()
			shield.tween_method(func(v: float): mat.set_shader_parameter("shield_pulse", v), 0.8, 0.0, 0.45)


## Bot-Spruch: "Name: Text" in der Bot-Farbe, verschwindet nach ein paar Sekunden
func add_chat_line(sender: String, text: String, color: Color) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("normal_font_size", 16)
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 5)
	line.text = "[color=#%s]%s:[/color] %s" % [color.to_html(false), sender, text]
	chat_box.add_child(line)
	while chat_box.get_child_count() > CHAT_MAX:
		chat_box.get_child(0).free()
	var tween := line.create_tween()
	tween.tween_interval(CHAT_SECONDS)
	tween.tween_property(line, "modulate:a", 0.0, 0.6)
	tween.tween_callback(line.queue_free)


## Rote Markierung um das Fadenkreuz in Richtung des Schuetzen (bei Explosionen: Richtung der Explosion)
func _show_hit_direction(info: DamageInfo) -> void:
	var source: Vector3
	if is_instance_valid(info.attacker) and info.attacker != player:
		source = (info.attacker as Node3D).global_position
	elif info.is_splash:
		source = info.position
	else:
		return
	var local: Vector3 = player.global_transform.basis.inverse() * (source - player.global_position)
	if Vector2(local.x, local.z).length() < 0.5:
		return
	var angle: float = atan2(local.x, -local.z)  # 0 = vorn, positiv = rechts
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-26, 8), Vector2(26, 8), Vector2(0, -10)])
	marker.color = Color(1.0, 0.15, 0.1, 0.85)
	marker.position = get_viewport().get_visible_rect().size / 2.0 + Vector2(sin(angle), -cos(angle)) * 120.0
	marker.rotation = angle
	add_child(marker)
	var tween := marker.create_tween()
	tween.tween_property(marker, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(marker.queue_free)


## Roter Hitmarker am Fadenkreuz
func show_hitmarker() -> void:
	if not GameManager.hitmarker_enabled:
		return
	hitmarker.visible = true
	hitmarker.modulate = Color(1.0, 0.25, 0.25, 1.0)
	var tween := create_tween()
	tween.tween_property(hitmarker, "modulate:a", 0.0, 0.12)
	tween.tween_callback(hitmarker.hide)


func _on_weapon_switched(w_name: String, current_ammo: int, max_ammo: int) -> void:
	weapon_name_label.text = w_name.to_upper()
	var weapon := player.weapon_manager.get_current_weapon()
	if weapon:
		weapon_name_label.add_theme_color_override("font_color", weapon.data.color.lightened(0.2))
	_on_ammo_updated(current_ammo, max_ammo)
	_refresh_slots()


## Waffenleiste: Taste und Kurzname; aktive Waffe in ihrer Farbe, eingesammelte hell, fehlende kaum sichtbar
func _refresh_slots() -> void:
	var weapons: Array[WeaponBase] = player.weapon_manager.weapons
	var active: int = player.weapon_manager.current_weapon_index
	for i in weapon_slots.get_child_count():
		var slot := weapon_slots.get_child(i) as Label
		if i >= weapons.size():
			slot.visible = false
			continue
		slot.text = "%d %s" % [i + 1, SLOT_NAMES.get(weapons[i].weapon_id, "")]
		if i == active:
			slot.modulate = weapons[i].data.color.lightened(0.2)
		elif weapons[i].owned:
			slot.modulate = Color(1, 1, 1, 0.6)
		else:
			slot.modulate = Color(1, 1, 1, 0.12)


func _on_ammo_updated(current_ammo: int, max_ammo: int) -> void:
	ammo_label.text = str(current_ammo)
	ammo_bar.max_value = max_ammo
	ammo_bar.value = current_ammo
	# Wenig Munition: Zahl orange
	ammo_label.modulate = Color(1.0, 0.55, 0.2) if current_ammo <= max_ammo * 0.15 else Color.WHITE


func _on_score_updated(frags: int, _deaths: int) -> void:
	if GameManager.is_team_mode():
		var limit := " / %d" % GameManager.frag_limit if GameManager.frag_limit > 0 and GameManager.game_mode == GameManager.Mode.TEAM_DEATHMATCH else ""
		frags_label.text = "Rot %d : %d Blau%s" % [GameManager.team_scores[0], GameManager.team_scores[1], limit]
	elif GameManager.frag_limit > 0:
		frags_label.text = "Frags: %d / %d" % [frags, GameManager.frag_limit]
	else:
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
		if GameManager.is_team_mode() and row.team >= 0:
			color = GameManager.TEAM_COLORS[row.team].lightened(0.35 if row.is_player else 0.0)
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
