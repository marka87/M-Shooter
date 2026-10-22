extends CanvasLayer
class_name ViewmodelTuner

## Ego-Waffe und -Arme pro Waffe: Werte aus resources/viewmodel.cfg beim Waffenwechsel anwenden,
## und Editor zum Einstellen (F4 an/aus, in der Waffen-Werkstatt sofort an).
## F5 / Shift+F5 = naechster / vorheriger Wert, H = Arme an/aus fuer diese Waffe,
## Pfeile links/rechts und hoch/runter, Shift + hoch/runter = vor/zurueck (Drehung: rollen), Strg = fein.
## F6 speichert alle Waffen nach resources/viewmodel.cfg (wird im Spiel geladen).

const SAVE_PATH := "res://resources/viewmodel.cfg"
const ITEMS := ["Waffe Position", "Waffe Groesse", "Arme Position", "Arme Drehung", "Arme Groesse"]
## Werte der frueheren Einzel-Hand, die beim Laden alter Dateien wegfallen
const OLD_HAND_KEYS := ["hand_offset", "hand_rot", "hand_scale", "fingers"]

var weapon_manager: WeaponManager
var hands: ViewHands
## Waffen-ID -> Werte (siehe defaults())
var settings: Dictionary = {}
var _active := false
var _item := 0
var _label: Label


## Werte einer noch nicht eingestellten Waffe: Position und Groesse wie bisher fuer alle, Arme an
func defaults() -> Dictionary:
	return {
		"pos": weapon_manager.default_pos, "scale": weapon_manager.view_scale,
		"hand": true, "arms_offset": Vector3.ZERO, "arms_rot": Vector3.ZERO, "arms_scale": 1.0,
	}


func _ready() -> void:
	layer = 50
	_label = Label.new()
	_label.position = Vector2(24, 110)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.visible = false
	add_child(_label)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for id in cfg.get_sections():
			var s := defaults()
			s.merge(cfg.get_value(id, "data"), true)
			for key in OLD_HAND_KEYS:
				s.erase(key)
			settings[StringName(id)] = s
	weapon_manager.weapon_switched.connect(func(_n, _a, _m): apply_current())
	apply_current.call_deferred()


## Editor an/aus (die Werkstatt schaltet ihn beim Start an)
func set_active(on: bool) -> void:
	_active = on
	_label.visible = on
	_refresh()


## Werte der aktuellen Waffe (legt sie bei Bedarf mit den Standardwerten an)
func current() -> Dictionary:
	var weapon: WeaponBase = weapon_manager.get_current_weapon()
	if not settings.has(weapon.weapon_id):
		settings[weapon.weapon_id] = defaults()
	return settings[weapon.weapon_id]


## Position, Groesse und Arme der aktuellen Waffe uebernehmen
func apply_current() -> void:
	if weapon_manager.get_current_weapon() == null:
		return
	var s := current()
	weapon_manager.default_pos = s.pos
	weapon_manager.view_scale = s.scale
	weapon_manager.scale = Vector3.ONE * s.scale
	hands.settings = s
	_refresh()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_F4 and not key.echo:
		set_active(not _active)
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	var dir := Vector3.ZERO
	match key.keycode:
		KEY_F5:
			_item = (_item + (ITEMS.size() - 1 if key.shift_pressed else 1)) % ITEMS.size()
		KEY_F6:
			_save()
			get_viewport().set_input_as_handled()
			return
		KEY_H:
			current().hand = not current().hand
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
		_nudge(dir, key.ctrl_pressed)
	apply_current()
	get_viewport().set_input_as_handled()


## Einen Schritt in Richtung dir auf den gewaehlten Wert anwenden
func _nudge(dir: Vector3, fine: bool) -> void:
	var m := 0.2 if fine else 1.0
	var s := current()
	match _item:
		0: s.pos += dir * 0.01 * m
		1: s.scale = maxf(s.scale + dir.y * 0.05 * m, 0.2)
		2: s.arms_offset += dir * 0.005 * m
		# Pfeile links/rechts = gieren, hoch/runter = nicken, Shift = rollen
		3: s.arms_rot += Vector3(dir.y, -dir.x, -dir.z) * 5.0 * m
		4: s.arms_scale = maxf(s.arms_scale + dir.y * 0.02 * m, 0.2)


func _refresh() -> void:
	if not _active or weapon_manager.get_current_weapon() == null:
		return
	var s := current()
	var lines := PackedStringArray([
		"VIEWMODEL-EDITOR – %s" % weapon_manager.get_current_weapon().weapon_name,
		"F4 aus · F5 / Shift+F5 Wert · 1-7 Waffe · H Arme · F6 speichern · Strg fein",
		"Arme: %s" % ("an" if s.hand else "aus (H)"), ""])
	for i in ITEMS.size():
		lines.append(("> " if i == _item else "   ") + "%s: %s" % [ITEMS[i], _value_text(i, s)])
	_label.text = "\n".join(lines)


func _value_text(i: int, s: Dictionary) -> String:
	match i:
		0: return _vec(s.pos)
		1: return "%.2f" % s.scale
		2: return _vec(s.arms_offset)
		3: return _vec(s.arms_rot)
		_: return "%.2f" % s.arms_scale


func _vec(v: Vector3) -> String:
	return "(%s, %s, %s)" % [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _save() -> void:
	var cfg := ConfigFile.new()
	for id in settings:
		cfg.set_value(String(id), "data", settings[id])
	var err := cfg.save(SAVE_PATH)
	_label.text += "\n\n" + ("Gespeichert: " + SAVE_PATH if err == OK else "Speichern fehlgeschlagen (%d)" % err)
