extends Area3D
class_name ReverbZone

## Hall-Zone: 3D-Sounds aus diesem Bereich hallen wie in einem Raum oder einer grossen Halle.
## Godot schickt sie anteilig an den Hall-Bus (reine Hall-Fahne, legt der GameManager an), der
## Direktschall bleibt auf SFX. Raeume haben Vorrang vor Hallen, in denen sie liegen.
## Die Maps aus dem Baukasten bekommen Raum-Zonen automatisch (MapKit.room), Hallen per MapKit.reverb.

enum Kind { ROOM, HALL }

## Bus und Anteil, der in den Hall geht (Raum: kurz und dicht, Halle: lang mit Vorverzoegerung)
const BUSES := { Kind.ROOM: &"Hall Raum", Kind.HALL: &"Hall Halle" }
const AMOUNTS := { Kind.ROOM: 0.45, Kind.HALL: 0.65 }

@export var kind: Kind = Kind.ROOM


func _ready() -> void:
	collision_layer = Layers.AUDIO_ZONES
	collision_mask = 0
	monitoring = false
	audio_bus_override = true
	audio_bus_name = &"SFX"
	reverb_bus_enabled = true
	reverb_bus_name = BUSES[kind]
	reverb_bus_amount = AMOUNTS[kind]
	reverb_bus_uniformity = 0.4
	priority = 2 if kind == Kind.ROOM else 1


## Hall-Busse anlegen (einmal beim Start, vom GameManager): reiner Nachhall, weiter an SFX
static func create_buses() -> void:
	for kind in BUSES:
		if AudioServer.get_bus_index(BUSES[kind]) >= 0:
			continue
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUSES[kind])
		AudioServer.set_bus_send(bus, &"SFX")
		var reverb := AudioEffectReverb.new()
		reverb.dry = 0.0
		reverb.wet = 1.0
		reverb.room_size = 0.45 if kind == Kind.ROOM else 0.9
		reverb.damping = 0.6 if kind == Kind.ROOM else 0.35
		reverb.predelay_msec = 15.0 if kind == Kind.ROOM else 55.0
		reverb.spread = 0.9
		reverb.hipass = 0.15
		AudioServer.add_bus_effect(bus, reverb)
