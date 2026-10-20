extends RefCounted
class_name SoundGenerator

## Liefert die Sounds des Spiels. Zuerst wird res://assets/sounds/<name>.wav geladen
## (erzeugt von tools/make_sounds.py); fehlt die Datei, wird der Sound wie frueher prozedural
## im RAM berechnet. Jeder Sound wird nur einmal geladen bzw. berechnet (Cache).

const SOUND_DIR := "res://assets/sounds/"

static var _cache: Dictionary = {}


static func create_machinegun_sound() -> AudioStream: return _cached("machinegun", _build_machinegun_sound)
static func create_rocket_fire_sound() -> AudioStream: return _cached("rocket_fire", _build_rocket_fire_sound)
static func create_explosion_sound() -> AudioStream: return _cached("explosion", _build_explosion_sound)
static func create_railgun_sound() -> AudioStream: return _cached("railgun", _build_railgun_sound)
static func create_switch_sound() -> AudioStream: return _cached("switch", _build_switch_sound)
static func create_bot_hurt_sound() -> AudioStream: return _cached("bot_hurt", _build_bot_hurt_sound)
static func create_bot_death_sound() -> AudioStream: return _cached("bot_death", _build_bot_death_sound)
static func create_pickup_sound() -> AudioStream: return _cached("pickup", _build_pickup_sound)
static func create_empty_click_sound() -> AudioStream: return _cached("empty_click", _build_empty_click_sound)
static func create_hitsound() -> AudioStream: return _cached("hitsound", _build_hitsound)
static func create_double_jump_sound() -> AudioStream: return _cached("double_jump", _build_double_jump_sound)
static func create_jump_pad_sound() -> AudioStream: return _cached("jump_pad", _build_jump_pad_sound)
static func create_shotgun_sound() -> AudioStream: return _cached("shotgun", _build_shotgun_sound)
static func create_plasma_sound() -> AudioStream: return _cached("plasma", _build_plasma_sound)
static func create_lightning_sound() -> AudioStream: return _cached("lightning", _build_lightning_sound)
static func create_shock_beam_sound() -> AudioStream: return _cached("shock_beam", _build_shock_beam_sound)
static func create_shock_ball_sound() -> AudioStream: return _cached("shock_ball", _build_shock_ball_sound)
static func create_combo_sound() -> AudioStream: return _cached("combo", _build_combo_sound)
static func create_weapon_pickup_sound() -> AudioStream: return _cached("weapon_pickup", _build_pickup_sound)
static func create_quad_pickup_sound() -> AudioStream: return _cached("quad_pickup", _build_pickup_sound)
static func create_mega_pickup_sound() -> AudioStream: return _cached("mega_pickup", _build_pickup_sound)
static func create_jump_sound() -> AudioStream: return _cached("jump", _build_double_jump_sound)
static func create_land_sound() -> AudioStream: return _cached("land", _build_bot_hurt_sound)
## Vier Varianten (1-4), damit Schritte nicht maschinell gleich klingen
static func create_footstep_sound(variant: int) -> AudioStream: return _cached("footstep_%d" % variant, _build_switch_sound)


## Musik-Loop (ohne prozeduralen Ersatz, fehlt die Datei: null)
static func load_music(name: String) -> AudioStream:
	var path := SOUND_DIR + "music/" + name + ".wav"
	return load(path) if ResourceLoader.exists(path) else null


## Ansager-Satz (z. B. "double_kill"), null wenn nicht vorhanden
static func load_announcer(name: String) -> AudioStream:
	var key := "announcer/" + name
	if not _cache.has(key):
		var path := SOUND_DIR + key + ".wav"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## Gibt alle zwischengespeicherten Sounds frei (beim Beenden, sonst meldet Godot Speicherlecks)
static func clear_cache() -> void:
	_cache.clear()


static func _cached(key: String, builder: Callable) -> AudioStream:
	if not _cache.has(key):
		var path := SOUND_DIR + key + ".wav"
		_cache[key] = load(path) if ResourceLoader.exists(path) else builder.call()
	return _cache[key]


## Wandelt einen Sample-Wert (-128..127) in ein vorzeichenbehaftetes 8-Bit-Byte um.
## AudioStreamWAV.FORMAT_8_BITS erwartet signed PCM, Stille liegt bei 0 (nicht bei 128).
static func _to_s8(val: float) -> int:
	return clampi(int(val), -128, 127) & 0xFF

## Maschinengewehr: Schneller, knackiger Schuss-Sound
static func _build_machinegun_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.09) # 90ms Laenge
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = (1.0 - t) * (1.0 - t) # Exponentieller Abfall
		# Mischung aus weissem Rauschen und tiefem Impuls
		var noise: float = randf_range(-1.0, 1.0)
		var punch: float = sin(t * 80.0) * 0.6
		var val: float = (noise * 0.7 + punch * 0.5) * env
		data[i] = _to_s8(val * 120.0)
	
	stream.data = data
	return stream


## Raketenwerfer-Abschuss: Tiefes Zischen und Druckwelle
static func _build_rocket_fire_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.22) # 220ms Laenge
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = 1.0 - t
		# Frequenz faellt von 220 Hz auf 70 Hz ab (Whoosh-Effekt)
		var freq: float = lerpf(220.0, 70.0, t)
		phase += freq * (TAU / stream.mix_rate)
		var wave: float = sin(phase) * 0.6 + randf_range(-0.4, 0.4)
		var val: float = wave * env
		data[i] = _to_s8(val * 115.0)
	
	stream.data = data
	return stream


## Explosion: Kraftvoller Bass-Schlag und abklingendes Truemmer-Rauschen
static func _build_explosion_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.55) # 550ms Laenge
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, 1.8)
		# Tiefe Bass-Sinuswelle (60 Hz nach 30 Hz) + dichtes Rauschen
		var freq: float = lerpf(65.0, 25.0, t)
		phase += freq * (TAU / stream.mix_rate)
		var rumble: float = sin(phase) * 0.8
		var debris: float = randf_range(-0.8, 0.8)
		var val: float = (rumble * 0.6 + debris * 0.6) * env
		data[i] = _to_s8(val * 125.0)
	
	stream.data = data
	return stream


## Railgun: Elektrischer Hochspannungs-Laser-Impuls (Chirp)
static func _build_railgun_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.4) # 400ms Laenge
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, 1.4)
		# Hochfrequenter Chirp faellt von 1600 Hz auf 200 Hz
		var freq: float = lerpf(1600.0, 200.0, pow(t, 0.4))
		phase += freq * (TAU / stream.mix_rate)
		var tone: float = sin(phase) + sin(phase * 1.5) * 0.4
		var crackle: float = randf_range(-0.3, 0.3) if t < 0.15 else 0.0
		var val: float = (tone * 0.8 + crackle) * env
		data[i] = _to_s8(val * 120.0)
	
	stream.data = data
	return stream


## Waffenwechsel: Schnelles mechanisches Klicken
static func _build_switch_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.05)
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = 1.0 - t
		var click: float = sin(t * 300.0) * randf_range(-0.8, 0.8)
		data[i] = _to_s8(click * env * 110.0)
	
	stream.data = data
	return stream


## Bot-Treffer: Knackiger Aufprall-/Schmerz-Ton
static func _build_bot_hurt_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.12)
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = (1.0 - t) * (1.0 - t)
		var freq: float = lerpf(350.0, 120.0, t)
		phase += freq * (TAU / stream.mix_rate)
		var val: float = (sin(phase) * 0.7 + randf_range(-0.3, 0.3)) * env
		data[i] = _to_s8(val * 115.0)
	
	stream.data = data
	return stream


## Bot-Tod: Ausfall-/Power-Down-Geräusch
static func _build_bot_death_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.45)
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = 1.0 - t
		var freq: float = lerpf(400.0, 40.0, pow(t, 0.7))
		phase += freq * (TAU / stream.mix_rate)
		var tone: float = sin(phase) * 0.7 + (randf_range(-0.5, 0.5) if t < 0.2 else 0.0)
		var val: float = tone * env
		data[i] = _to_s8(val * 120.0)
	
	stream.data = data
	return stream


## Item-Pickup: Befriedigender zweitoeniger Aufhebe-Klang (Chime)
static func _build_pickup_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.18)
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = 1.0 - t
		var freq: float = 520.0 if t < 0.45 else 880.0
		phase += freq * (TAU / stream.mix_rate)
		var val: float = sin(phase) * 0.75 * env
		data[i] = _to_s8(val * 120.0)
	
	stream.data = data
	return stream


## Leeres Magazin: Trockenes Klick-Geraeusch
static func _build_empty_click_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.04)
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = 1.0 - t
		var click: float = sin(t * 800.0) * randf_range(-0.6, 0.6)
		data[i] = _to_s8(click * env * 110.0)
	
	stream.data = data
	return stream


## Quake-Trefferton: Heller, knackiger Ding-/Beep-Klang bei erfolgreichem Treffer
static func _build_hitsound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.1) # 100ms Laenge
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	var freq: float = 950.0 # Hohe Glockenfrequenz
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, 2.5) # Schneller Abfall
		phase += freq * (TAU / stream.mix_rate)
		var val: float = (sin(phase) * 0.85 + sin(phase * 2.0) * 0.2) * env
		data[i] = _to_s8(val * 120.0)
	
	stream.data = data
	return stream


## Doppelsprung: Aufwaerts gerichteter Luftstoss-/Whoosh-Klang
static func _build_double_jump_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var samples := int(stream.mix_rate * 0.16) # 160ms Laenge
	var data := PackedByteArray()
	data.resize(samples)
	
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = sin(t * PI)
		var freq: float = lerpf(240.0, 580.0, t)
		phase += freq * (TAU / stream.mix_rate)
		var whoosh: float = (sin(phase) * 0.7 + randf_range(-0.4, 0.4)) * env
		data[i] = _to_s8(whoosh * 115.0)
	
	stream.data = data
	return stream


## Jump-Pad: Kraeftiger, aufsteigender Druckluft-Stoss
static func _build_jump_pad_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false

	var samples := int(stream.mix_rate * 0.35) # 350ms Laenge
	var data := PackedByteArray()
	data.resize(samples)

	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, 1.5) * minf(t * 30.0, 1.0)
		# Tiefer Puls, der schnell nach oben zieht
		var freq: float = lerpf(90.0, 420.0, pow(t, 0.6))
		phase += freq * (TAU / stream.mix_rate)
		var val: float = (sin(phase) * 0.75 + randf_range(-0.3, 0.3)) * env
		data[i] = _to_s8(val * 120.0)

	stream.data = data
	return stream


## Shotgun: Lauter Knall mit tiefem Druck und viel Rauschen
static func _build_shotgun_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false

	var samples := int(stream.mix_rate * 0.32) # 320ms Laenge
	var data := PackedByteArray()
	data.resize(samples)

	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, 3.0)
		var freq: float = lerpf(120.0, 45.0, t)
		phase += freq * (TAU / stream.mix_rate)
		var boom: float = sin(phase) * 0.6
		var blast: float = randf_range(-1.0, 1.0) * (1.0 - t * 0.7)
		var val: float = (boom + blast * 0.7) * env
		data[i] = _to_s8(val * 125.0)

	stream.data = data
	return stream


## Gemeinsamer Baukasten fuer die Energiewaffen: Tonhoehe faellt von f0 auf f1,
## Lautstaerke klingt mit der Huellkurve ab, dazu etwas Rauschen und optional Rechteckanteil
static func _build_zap(length: float, f0: float, f1: float, decay: float, noise: float, square: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var samples := int(stream.mix_rate * length)
	var data := PackedByteArray()
	data.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var env: float = pow(1.0 - t, decay) * minf(t * 80.0, 1.0)
		phase += lerpf(f0, f1, t) * (TAU / stream.mix_rate)
		var tone: float = sin(phase)
		if square > 0.0:
			tone = lerpf(tone, signf(tone), square)
		var val: float = (tone * 0.7 + randf_range(-1.0, 1.0) * noise) * env
		data[i] = _to_s8(val * 115.0)
	stream.data = data
	return stream


## Plasma: kurzes, hohes "Pew"
static func _build_plasma_sound() -> AudioStreamWAV:
	return _build_zap(0.12, 1400.0, 500.0, 2.0, 0.15, 0.3)


## Lightning Gun: kurzes Knistern, wird bei Dauerfeuer schnell hintereinander gespielt
static func _build_lightning_sound() -> AudioStreamWAV:
	return _build_zap(0.07, 180.0, 140.0, 0.6, 0.6, 0.8)


## Shock Rifle Strahl: scharfer, metallischer Zap
static func _build_shock_beam_sound() -> AudioStreamWAV:
	return _build_zap(0.3, 2200.0, 300.0, 1.6, 0.2, 0.0)


## Shock-Kugel: tiefes, wabberndes Woosh
static func _build_shock_ball_sound() -> AudioStreamWAV:
	return _build_zap(0.35, 260.0, 120.0, 1.2, 0.25, 0.5)


## Shock-Combo: lange, tiefe Explosion mit Rauschen
static func _build_combo_sound() -> AudioStreamWAV:
	return _build_zap(0.9, 160.0, 25.0, 1.4, 0.8, 0.2)
