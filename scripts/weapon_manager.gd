extends Node3D
class_name WeaponManager

## Verwaltet die Waffen des Spielers: Ausruesten, Wechseln (1-7 / Mausrad), Waffenbesitz,
## Schiessen (Klick und Halten, rechte Maustaste = Alt-Feuer), Sway und HUD-Signale.

signal weapon_switched(weapon_name: String, current_ammo: int, max_ammo: int)
signal ammo_updated(current_ammo: int, max_ammo: int)
## Waffenbesitz hat sich geaendert (Pickup, Respawn), fuer die Slot-Anzeige im HUD
signal loadout_changed()

@export var sway_amount: float = 0.0012
@export var max_sway: float = 0.05
@export var sway_smooth: float = 10.0
@export var bob_frequency: float = 12.0
@export var bob_amplitude: float = 0.015

var weapons: Array[WeaponBase] = []
var current_weapon_index: int = 0
var mouse_input: Vector2 = Vector2.ZERO
var bob_time: float = 0.0
# Sprung und Landung: Waffe haengt in der Luft nach und knickt beim Aufkommen ein
var _air_offset: float = 0.0
var _land_dip: float = 0.0
var _air_velocity_y: float = 0.0
var _was_on_floor: bool = true
# Nach dem Fortsetzen per Mausklick erst wieder schiessen, wenn die Taste losgelassen wurde
var _wait_for_shoot_release: bool = false

@onready var player: CharacterBody3D = owner as CharacterBody3D
@onready var camera: Camera3D = get_parent() as Camera3D
@onready var switch_audio: AudioStreamPlayer = $SwitchAudioPlayer

# Standard-Position der Waffe vor der Kamera (rechts unten), nah und gross wie in modernen Arena-Shootern
var default_pos: Vector3 = Vector3(0.2, -0.2, -0.3)
## Vergroesserung der Ego-Waffe (Muzzle wandert mit, Schuesse kommen weiter aus dem Lauf)
var view_scale: float = 1.35


func _ready() -> void:
	position = default_pos
	scale = Vector3.ONE * view_scale
	
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
	
	_setup_viewmodel_lighting()

	# Erste Waffe ausruesten (Maschinengewehr, im Instagib die Railgun)
	if not weapons.is_empty():
		switch_to_weapon(_first_owned())
	
	GameManager.game_paused.connect(_on_game_paused)


## Waffen in der Hand auf eigenen Render-Layer legen und mit einem eigenen Licht aufhellen.
## Sonst sind sie in dunklen Ecken fast schwarz. Das Licht wirkt nur auf diesen Layer,
## die Welt bleibt unveraendert. Schatten der Waffen sind aus (wirken sonst falsch).
const VIEWMODEL_LAYER: int = 1 << 1

func _setup_viewmodel_lighting() -> void:
	_apply_viewmodel_layer(self)
	var light := OmniLight3D.new()
	light.name = "ViewmodelLight"
	light.light_cull_mask = VIEWMODEL_LAYER
	light.light_color = Color(0.85, 0.9, 1.0)
	light.light_energy = 2.5
	light.omni_range = 2.5
	light.shadow_enabled = false
	camera.add_child.call_deferred(light)
	light.position = Vector3(0.5, 0.45, 0.2)


func _apply_viewmodel_layer(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			child.layers = VIEWMODEL_LAYER
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_viewmodel_layer(child)


func _unhandled_input(event: InputEvent) -> void:
	# Mausbewegung fuer visuelles Waffen-Swaying abfangen
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
	
	# Waffenwechsel per Zahlentasten 1-7 (Reihenfolge wie unter WeaponHolder in player.tscn)
	for slot in weapons.size():
		if event.is_action_pressed("weapon_%d" % (slot + 1)):
			switch_to_weapon(slot)
			break
	
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
		elif Input.is_action_pressed("shoot_alt") and not _wait_for_shoot_release:
			fire_current_weapon_alt()
		elif not Input.is_action_pressed("shoot") and not Input.is_action_pressed("shoot_alt"):
			_wait_for_shoot_release = false
	
	_process_weapon_jump(delta)

	# Visuelles Waffen-Swaying (Traegheit beim Umschauen)
	_process_weapon_sway(delta)
	
	# Leichtes Wippen (Bobbing) beim Laufen
	_process_weapon_bob(delta)


## Feuert die aktuell aktive Waffe ab

func fire_current_weapon() -> void:
	# Tote Spieler duerfen nicht schiessen
	if player and player.get("is_dead") == true or GameManager.is_frozen():
		return
	var weapon := get_current_weapon()
	if weapon and weapon.try_fire(player, camera):
		GameManager.register_shot()
		player.camera_feedback.recoil(weapon.recoil_distance)


## Alt-Feuer der aktiven Waffe (rechte Maustaste)
func fire_current_weapon_alt() -> void:
	if player and player.get("is_dead") == true or GameManager.is_frozen():
		return
	var weapon := get_current_weapon()
	if weapon and weapon.try_fire_alt(player, camera):
		GameManager.register_shot()
		player.camera_feedback.recoil(weapon.recoil_distance)


## Wechselt zu einem Waffen-Index (0 MG, 1 Shotgun, 2 Plasma, 3 Raketenwerfer,
## 4 Lightning Gun, 5 Railgun, 6 Shock Rifle). Nicht eingesammelte Waffen werden ignoriert.
func switch_to_weapon(index: int) -> void:
	if weapons.is_empty() or index < 0 or index >= weapons.size():
		return
	if not weapons[index].owned:
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
	# Naechste Waffe in der Richtung, die man besitzt
	var new_index: int = current_weapon_index
	for i in weapons.size():
		new_index = posmod(new_index + direction, weapons.size())
		if weapons[new_index].owned:
			break
	switch_to_weapon(new_index)


## Wechselt zur Waffe mit der angegebenen WeaponData.id
func switch_to_weapon_id(weapon_id: StringName) -> void:
	for i in weapons.size():
		if weapons[i].weapon_id == weapon_id:
			switch_to_weapon(i)
			return


## Gibt die Waffe mit der angegebenen WeaponData.id zurueck (oder null)
func get_weapon(weapon_id: StringName) -> WeaponBase:
	for weapon in weapons:
		if weapon.weapon_id == weapon_id:
			return weapon
	return null


## Gibt die aktuell ausgewaehlte Waffe zurueck
func get_current_weapon() -> WeaponBase:
	if weapons.is_empty():
		return null
	return weapons[current_weapon_index]


## Waffen-Pickup: Waffe in Besitz nehmen (und hinwechseln) oder nur Munition auffuellen.
## True, wenn sich etwas geaendert hat.
func give_weapon(weapon_id: StringName, ammo: int) -> bool:
	var weapon := get_weapon(weapon_id)
	if weapon == null:
		return false
	if not weapon.owned:
		weapon.owned = true
		weapon.add_ammo(ammo)
		loadout_changed.emit()
		switch_to_weapon(weapons.find(weapon))
		return true
	return weapon.add_ammo(ammo)


## Nach dem Respawn: Start-Ausruestung laut WeaponData, zurueck zur ersten Waffe
func reset_loadout() -> void:
	for weapon in weapons:
		weapon.reset_loadout()
	weapons[current_weapon_index].unequip()
	current_weapon_index = _first_owned()
	var first: WeaponBase = weapons[current_weapon_index]
	first.equip()
	loadout_changed.emit()
	weapon_switched.emit(first.weapon_name, first.current_ammo, first.max_ammo)


func _first_owned() -> int:
	for i in weapons.size():
		if weapons[i].owned:
			return i
	return 0


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
	
	target_offset.y += _air_offset + _land_dip
	position = position.lerp(default_pos + target_offset, delta * sway_smooth)
	mouse_input = mouse_input.lerp(Vector2.ZERO, delta * sway_smooth)


## In der Luft: Waffe bleibt beim Steigen etwas zurueck (tiefer) und hebt sich beim Fallen.
## Beim Aufkommen knickt sie ein, staerker nach hohem Fall, und federt zurueck.
func _process_weapon_jump(delta: float) -> void:
	if not player:
		return
	var on_floor: bool = player.is_on_floor()
	if on_floor and not _was_on_floor:
		_land_dip = -0.1 * clampf((-_air_velocity_y - 2.0) / 18.0, 0.15, 1.0)
		_air_offset = 0.0
	if not on_floor:
		_air_velocity_y = player.velocity.y
	_was_on_floor = on_floor
	var air_target: float = 0.0 if on_floor else clampf(-player.velocity.y * 0.004, -0.04, 0.04)
	_air_offset = lerpf(_air_offset, air_target, clampf(delta * 8.0, 0.0, 1.0))
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.35)


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
