extends RefCounted
class_name Layers

## Bitmasken der Kollisions-Layer (Namen siehe Projekteinstellungen > Layer Names > 3D Physics)

const WORLD: int = 1 << 0  # Layer 1: Waende, Boeden, Plattformen
const PLAYER: int = 1 << 1  # Layer 2: Spieler
const BOT: int = 1 << 2  # Layer 3: Bots
const PICKUP: int = 1 << 3  # Layer 4: Items (Area3D)
const PROPS: int = 1 << 4  # Layer 5: Dynamische Physik-Objekte (Kisten, Faesser)
const AUDIO_ZONES: int = 1 << 6  # Layer 7: Hall-Zonen (Area3D, nur fuer 3D-Sounds)

## Alles, was Schuesse und Projektile aufhalten kann
const HITTABLE: int = WORLD | PLAYER | BOT | PROPS
## Alles, was Explosionsschaden bekommen kann
const CHARACTERS: int = PLAYER | BOT
const BLASTABLE: int = PLAYER | BOT | PROPS
