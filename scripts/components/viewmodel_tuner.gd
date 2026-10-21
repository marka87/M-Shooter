extends CanvasLayer
class_name ViewmodelTuner

## Viewmodel-Editor: Ego-Waffe live mit den Pfeiltasten verschieben und vergroessern.
## F4 an/aus, F5 naechster Wert, Pfeile links/rechts und hoch/runter, Shift + hoch/runter = vor/zurueck,
## Strg = feine Schritte, F6 speichern (user://viewmodel.cfg, beim Start geladen)
## und als Code in die Zwischenablage kopieren.

const SAVE_PATH := "user://viewmodel.cfg"
const ITEMS := ["Waffe Position", "Waffe Groesse"]

var weapon_manager: WeaponManager
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


func _refresh() -> void:
	var lines := PackedStringArray(["VIEWMODEL-EDITOR  (F4 aus, F5 weiter, F6 speichern, Strg = fein)", ""])
	for i in ITEMS.size():
		lines.append(("> " if i == _item else "   ") + "%s: %s" % [ITEMS[i], _value_text(i)])
	_label.text = "\n".join(lines)


func _value_text(i: int) -> String:
	match i:
		0: return _vec(weapon_manager.default_pos)
		_: return "%.2f" % weapon_manager.view_scale


func _vec(v: Vector3) -> String:
	return "Vector3(%s, %s, %s)" % [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("weapon", "default_pos", weapon_manager.default_pos)
	cfg.set_value("weapon", "view_scale", weapon_manager.view_scale)
	cfg.save(SAVE_PATH)
	# Als Code zum Einfuegen in weapon_manager.gd
	DisplayServer.clipboard_set("\n".join([
		"var default_pos: Vector3 = " + _vec(weapon_manager.default_pos),
		"var view_scale: float = %.2f" % weapon_manager.view_scale,
	]))
	_label.text += "\n\nGespeichert + in Zwischenablage kopiert"


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	weapon_manager.default_pos = cfg.get_value("weapon", "default_pos", weapon_manager.default_pos)
	weapon_manager.view_scale = cfg.get_value("weapon", "view_scale", weapon_manager.view_scale)
	weapon_manager.scale = Vector3.ONE * weapon_manager.view_scale
