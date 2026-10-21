extends CanvasLayer
class_name ViewmodelTuner

## Viewmodel-Editor: Waffe, Hand und Finger live mit den Pfeiltasten verschieben.
## F4 an/aus, F5 naechster Wert, Pfeile links/rechts und hoch/runter, Shift + hoch/runter = vor/zurueck
## (bei Drehung: rollen), Strg = feine Schritte, F6 speichern (user://viewmodel.cfg, beim Start geladen)
## und als Code in die Zwischenablage kopieren.

const SAVE_PATH := "user://viewmodel.cfg"
const ITEMS := ["Waffe Position", "Waffe Groesse", "Hand Position", "Hand Drehung", "Hand Groesse", "Finger", "Daumen"]

var weapon_manager: WeaponManager
var hands: ViewHands
var _active := false
var _item := 0
var _label: Label


func _ready() -> void:
	layer = 50
	_label = Label.new()
	_label.position = Vector2(24, 260)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.visible = false
	add_child(_label)
	_load()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_F4 and not key.echo:
		_active = not _active
		_label.visible = _active
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	var fine := key.ctrl_pressed
	var dir := Vector3.ZERO
	match key.keycode:
		KEY_F5:
			_item = (_item + 1) % ITEMS.size()
		KEY_F6:
			_save()
		KEY_LEFT:
			dir.x = -1
		KEY_RIGHT:
			dir.x = 1
		KEY_UP:
			if key.shift_pressed: dir.z = -1
			else: dir.y = 1
		KEY_DOWN:
			if key.shift_pressed: dir.z = 1
			else: dir.y = -1
		_:
			return
	if dir != Vector3.ZERO:
		_nudge(dir, fine)
	_refresh()
	get_viewport().set_input_as_handled()


## Einen Schritt in Richtung dir auf den gewaehlten Wert anwenden
func _nudge(dir: Vector3, fine: bool) -> void:
	var m := 0.2 if fine else 1.0
	match _item:
		0: weapon_manager.default_pos += dir * 0.01 * m
		1:
			weapon_manager.view_scale = maxf(weapon_manager.view_scale + dir.y * 0.05 * m, 0.2)
			weapon_manager.scale = Vector3.ONE * weapon_manager.view_scale
		2: hands.hand_offset += dir * 0.005 * m
		# Pfeile links/rechts = gieren, hoch/runter = nicken, Shift = rollen
		3: hands.hand_rot += Vector3(dir.y, -dir.x, -dir.z) * 5.0 * m
		4: hands.hand_scale = maxf(hands.hand_scale + dir.y * 0.002 * m, 0.005)
		# Finger und Daumen: hoch/runter alle Glieder, links/rechts nur die Spitze
		5:
			hands.curl += Vector3(dir.y, dir.y, dir.y + dir.x) * 5.0 * m
			hands.apply_curl()
		6:
			hands.thumb_curl += Vector3(dir.y, dir.y, dir.y + dir.x) * 5.0 * m
			hands.apply_curl()


func _refresh() -> void:
	var lines := PackedStringArray(["VIEWMODEL-EDITOR  (F4 aus, F5 weiter, F6 speichern, Strg = fein)", ""])
	for i in ITEMS.size():
		lines.append(("> " if i == _item else "   ") + "%s: %s" % [ITEMS[i], _value_text(i)])
	_label.text = "\n".join(lines)


func _value_text(i: int) -> String:
	match i:
		0: return _vec(weapon_manager.default_pos)
		1: return "%.2f" % weapon_manager.view_scale
		2: return _vec(hands.hand_offset)
		3: return _vec(hands.hand_rot)
		4: return "%.3f" % hands.hand_scale
		5: return _vec(hands.curl)
		_: return _vec(hands.thumb_curl)


func _vec(v: Vector3) -> String:
	return "Vector3(%s, %s, %s)" % [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("weapon", "default_pos", weapon_manager.default_pos)
	cfg.set_value("weapon", "view_scale", weapon_manager.view_scale)
	cfg.set_value("hand", "hand_offset", hands.hand_offset)
	cfg.set_value("hand", "hand_rot", hands.hand_rot)
	cfg.set_value("hand", "hand_scale", hands.hand_scale)
	cfg.set_value("hand", "curl", hands.curl)
	cfg.set_value("hand", "thumb_curl", hands.thumb_curl)
	cfg.save(SAVE_PATH)
	# Als Code zum Einfuegen in weapon_manager.gd / view_hands.gd
	DisplayServer.clipboard_set("\n".join([
		"var default_pos: Vector3 = " + _vec(weapon_manager.default_pos),
		"var view_scale: float = %.2f" % weapon_manager.view_scale,
		"@export var hand_offset: Vector3 = " + _vec(hands.hand_offset),
		"@export var hand_rot: Vector3 = " + _vec(hands.hand_rot),
		"@export var hand_scale: float = %.3f" % hands.hand_scale,
		"@export var curl: Vector3 = " + _vec(hands.curl),
		"@export var thumb_curl: Vector3 = " + _vec(hands.thumb_curl),
	]))
	_label.text += "\n\nGespeichert + in Zwischenablage kopiert"


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	weapon_manager.default_pos = cfg.get_value("weapon", "default_pos", weapon_manager.default_pos)
	weapon_manager.view_scale = cfg.get_value("weapon", "view_scale", weapon_manager.view_scale)
	weapon_manager.scale = Vector3.ONE * weapon_manager.view_scale
	hands.hand_offset = cfg.get_value("hand", "hand_offset", hands.hand_offset)
	hands.hand_rot = cfg.get_value("hand", "hand_rot", hands.hand_rot)
	hands.hand_scale = cfg.get_value("hand", "hand_scale", hands.hand_scale)
	hands.curl = cfg.get_value("hand", "curl", hands.curl)
	hands.thumb_curl = cfg.get_value("hand", "thumb_curl", hands.thumb_curl)
	hands.apply_curl()
