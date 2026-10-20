extends Node3D
class_name WeaponManager

## Verwaltet die Waffen des Spielers: Ausruesten, Wechseln (1-3 / Mausrad),
## Schiessen (Klick und Halten), optisches Waffen-Schwanken (Sway) und HUD-Signale.

signal weapon_switched(weapon_name: String, current_ammo: int, max_ammo: int)
signal ammo_updated(current_ammo: int, max_ammo: int)

@export var sway_amount: float = 0.0012
@export var max_sway: float = 0.05
@export var sway_smooth: float = 10.0
@export var bob_frequency: float = 12.0
@export var bob_amplitude: float = 0.015

var weapons: Array[WeaponBase] = []
var current_weapon_index: int = 0
var mouse_input: Vector2 = Vector2.ZERO
var bob_time: float = 0.0
# Nach dem Fortsetzen per Mausklick erst wieder schiessen, wenn die Taste losgelassen wurde
var _wait_for_shoot_release: bool = false

@onready var player: CharacterBody3D = owner as CharacterBody3D
@onready var camera: Camera3D = get_parent() as Camera3D
@onready var switch_audio: AudioStreamPlayer = $SwitchAudioPlayer

# Standard-Position der Waffe vor der Kamera (rechts unten)
var default_pos: Vector3 = Vector3(0.24, -0.22, -0.45)


func _ready() -> void:
	position = default_pos
	
	# Audio fuer Waffenwechsel vorbereiten
	if not switch_audio:
		switch_audio = AudioStreamPlayer.new()
		add_child(switch_audio)
	switch_audio.stream = SoundGenerator.create_switch_sound()
	
	# Alle untergeordneten Waffen-Knoten sammeln
	for child in get_children():
		if child is WeaponBase:
			weapons.append(child)
			child.unequip()
			child.ammo_changed.connect(_on_weapon_ammo_changed.bind(child))
	
	# Erste Waffe (Maschinengewehr) ausruesten
	if not weapons.is_empty():
		switch_to_weapon(0)
	
	GameManager.game_paused.connect(_on_game_paused)


func _unhandled_input(event: InputEvent) -> void:
	# Mausbewegung fuer visuelles Waffen-Swaying abfangen
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
	
	# Waffenwechsel per Zahlentasten 1, 2, 3
	if event.is_action_pressed("weapon_1"):
		switch_to_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		switch_to_weapon(2)
	
	# Waffenwechsel per Mausrad
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)


func _process(delta: float) -> void:
	# Dauerfeuer / Einzelschuss pruefen (Linke Maustaste gehalten)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed("shoot") and not _wait_for_shoot_release:
			fire_current_weapon()
		elif not Input.is_action_pressed("shoot"):
			_wait_for_shoot_release = false
	
	# Visuelles Waffen-Swaying (Traegheit beim Umschauen)
	_process_weapon_sway(delta)
	
	# Leichtes Wippen (Bobbing) beim Laufen
	_process_weapon_bob(delta)


## Feuert die aktuell aktive Waffe ab

func fire_current_weapon() -> void:
	# Tote Spieler duerfen nicht schiessen
	if player and player.get("is_dead") == true:
		return
	var weapon := get_current_weapon()
	if weapon:
		weapon.try_fire(player, camera)


## Wechselt zu einem bestimmten Waffen-Index (0 = MG, 1 = Raketenwerfer, 2 = Railgun)
func switch_to_weapon(index: int) -> void:
	if weapons.is_empty() or index < 0 or index >= weapons.size():
		return
	if index == current_weapon_index and weapons[index].visible:
		return
	
	# Aktuelle Waffe wegstecken
	weapons[current_weapon_index].unequip()
	
	# Neue Waffe ausruesten
	current_weapon_index = index
	var new_weapon: WeaponBase = weapons[current_weapon_index]
	new_weapon.equip()
	
	# Klick-Sound beim Wechsel
	if switch_audio:
		switch_audio.pitch_scale = randf_range(0.9, 1.1)
		switch_audio.play()
	
	# Signal an HUD senden
	weapon_switched.emit(new_weapon.weapon_name, new_weapon.current_ammo, new_weapon.max_ammo)


## Weiterschalten der Waffen (Mausrad)
func cycle_weapon(direction: int) -> void:
	if weapons.is_empty():
		return
	var new_index: int = (current_weapon_index + direction) % weapons.size()
	if new_index < 0:
		new_index = weapons.size() - 1
	switch_to_weapon(new_index)


## Gibt die aktuell ausgewaehlte Waffe zurueck
func get_current_weapon() -> WeaponBase:
	if weapons.is_empty():
		return null
	return weapons[current_weapon_index]


## Munitionskiste: jede Waffe bekommt ihre ammo_box_amount. True, wenn irgendetwas aufgefuellt wurde.
func add_ammo_box() -> bool:
	var any := false
	for weapon in weapons:
		if weapon.add_ammo(weapon.data.ammo_box_amount):
			any = true
	return any


## Munition fuer eine bestimmte Waffe (per WeaponData.id). True, wenn aufgefuellt wurde.
func add_ammo(weapon_id: StringName, amount: int) -> bool:
	for weapon in weapons:
		if weapon.weapon_id == weapon_id:
			return weapon.add_ammo(amount)
	return false


func _on_game_paused(is_paused: bool) -> void:
	if not is_paused:
		_wait_for_shoot_release = true


## Nur die Munition der aktiven Waffe ans HUD melden
func _on_weapon_ammo_changed(current: int, max_val: int, weapon: WeaponBase) -> void:
	if weapon == get_current_weapon():
		ammo_updated.emit(current, max_val)


## Berechnet die geschmeidige Waffen-Traegheit beim Drehen des Blickwinkels
func _process_weapon_sway(delta: float) -> void:
	var target_x: float = clampf(-mouse_input.x * sway_amount, -max_sway, max_sway)
	var target_y: float = clampf(mouse_input.y * sway_amount, -max_sway, max_sway)
	var target_offset := Vector3(target_x, target_y, 0.0)
	
	position = position.lerp(default_pos + target_offset, delta * sway_smooth)
	mouse_input = mouse_input.lerp(Vector2.ZERO, delta * sway_smooth)


## Simuliert das Schrittwippen beim Bewegen auf dem Boden
func _process_weapon_bob(delta: float) -> void:
	if not player or not player.is_on_floor():
		return
	
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed > 0.5:
		bob_time += delta * (horizontal_speed * 1.2)
		var bob_offset_y: float = sin(bob_time) * bob_amplitude
		var bob_offset_x: float = cos(bob_time * 0.5) * (bob_amplitude * 0.6)
		position.y += bob_offset_y * delta * 5.0
		position.x += bob_offset_x * delta * 5.0
	else:
		bob_time = 0.0
