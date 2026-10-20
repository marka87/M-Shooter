# Arena Shooter (Quake & Unreal Tournament Stil)

Ein rasanter 3D-Arena-Shooter entwickelt in **Godot 4** mit **GDScript**. Das Spiel kombiniert klassische Bewegungsmuster (Strafe-Jumping, Bunnyhopping, Doppelsprung und Rocket-Jumping), drei distinkte Waffen, fordernde KI-Bots mit Navigation und ein vollständiges Schadens-, Rüstungs- und Menüsystem.

---

## 🎮 Steuerung

| Taste / Eingabe | Aktion |
|---|---|
| **W, A, S, D** | Laufen (Vorwärts, Links, Rückwärts, Rechts) |
| **Shift (halten)** | Sprinten (Erhöht Bodentempo von 8 auf 12 m/s) |
| **Leertaste** | Sprung (am Boden halten für automatisches Bunnyhopping) |
| **Leertaste (in der Luft)** | **Doppelsprung** (Unreal Tournament Style mit Richtungs-Boost!) |
| **Maus** | Umschauen / Zielen |
| **Linke Maustaste** | Waffe abfeuern (Halten für Maschinengewehr-Dauerfeuer) |
| **1–7** oder **Mausrad** | Waffe wechseln (1 MG, 2 Shotgun, 3 Plasma, 4 Raketenwerfer, 5 Lightning Gun, 6 Railgun, 7 Shock Rifle) |
| **Rechte Maustaste** | Alt-Feuer (Shock Rifle: Shock-Kugel) |
| **Tab (halten)** | Scoreboard (Frags und Tode aller Teilnehmer) |
| **ESC** | Spiel pausieren & Pause-Menü aufrufen |

Alle Tasten laufen über die InputMap (Projekt → Projekteinstellungen → Eingabezuordnung) und sind dort frei belegbar. Die Belegung nutzt physische Tasten, WASD liegt also auch auf AZERTY-Tastaturen an derselben Stelle.

---

## 🚀 Bewegungs-Mechaniken

1. **Strafe-Jumping (Quake-Physik)**:
   - Laufe an, springe mit der Leertaste ab, lass `W` los, halte `A` (oder `D`) gedrückt und bewege die Maus synchron gleichmäßig nach links (bzw. rechts).
   - Die Geschwindigkeit erhöht sich durch die vektorielle Luftprojektion kontinuierlich (über 20+ m/s) und wird im Tacho oben im HUD grün hervorgehoben!
2. **Doppelsprung**:
   - Drücke in der Luft ein zweites Mal die Leertaste für einen zweiten Höhenschub und schnellen Richtungswechsel.
3. **Rocket-Jumping**:
   - Renne vorwärts, springe ab und feuere gleichzeitig eine Rakete direkt unter deine Füße. Die Wucht der Detonation katapultiert dich weit empor auf hohe Podeste.
4. **Bunnyhopping**:
   - Wenn du die Leertaste gedrückt hältst, springt dein Charakter bei Bodenkontakt sofort wieder ab, ohne dass die Bodenreibung deine horizontale Geschwindigkeit abbremst.

---

## 🔫 Waffenarsenal

| Waffe | Typ | Schaden | Feuerrate | Besonderheit |
|---|---|---|---|---|
| **Maschinengewehr** (1) | Hitscan | 12 | 11 Schuss/s | Geringer Rückstoß, leichte Streuung, Mündungsfeuer |
| **Shotgun** (2) | Hitscan, 11 Kugeln | 9 pro Kugel (bis 99) | 1.0s Abklingzeit | Stark auf kurze Distanz, Treffer werden pro Ziel zusammengefasst |
| **Raketenwerfer** (4) | Projektil | 50 (Direkt) + bis zu 100 (Fläche) | 0.8s Abklingzeit | Sichtbare Rakete, Schockwelle, Flächenschaden & Rocket-Jumping |
| **Plasma** (3) | Projektil, 10 Schuss/s | 20 + bis 15 Fläche | 0.1s | Schnelle Energie-Bolzen, kleiner Splash. **Muss eingesammelt werden** |
| **Lightning Gun** (5) | Dauerstrahl, 24 m | 8 pro Tick, 20 Ticks/s | – | Zuckender Doppel-Blitz, ideal für gutes Tracking. **Muss eingesammelt werden** |
| **Shock Rifle** (7) | Strahl / Kugel | 45 Strahl, 55 + 35 Fläche Kugel | 0.75s / 0.6s | Rechtsklick feuert eine langsame Shock-Kugel. Trifft der Strahl die Kugel: **Combo**, 150 Schaden im Radius 7 m. **Muss eingesammelt werden** |
| **Railgun** (6) | Hitscan-Strahl | 100 | 1.25s Abklingzeit | Sofortiger Einschlag über 300m, nachleuchtender Cyan-Energiestrahl |

---

## 🏁 Match-Ablauf

Im Match-Fenster wählst du neben Arena, Bots und Schwierigkeit auch **Frag-Limit** (5, 10, 15, 20, 30 oder keins) und **Zeit-Limit** (5, 10, 15, 20 Minuten oder keins).
- Start mit Countdown **3 – 2 – 1 – FIGHT!**, solange ist alles eingefroren.
- Oben in der Mitte läuft die Restzeit (letzte 30 s rot), oben rechts stehen die Frags mit Limit.
- Ansagen: **DOUBLE / MULTI / MEGA / MONSTER KILL** (Kills innerhalb von 3 s) und **KILLING SPREE / RAMPAGE / DOMINATING / UNSTOPPABLE / GODLIKE** (5/10/15/20/25 Kills ohne Tod).
- Erreicht jemand das Frag-Limit oder läuft die Zeit ab: **Siegerbildschirm** mit Rangliste (Frags, Tode, Schaden) und deiner Statistik (Treffsicherheit, K/D, Schaden verursacht/erhalten, beste Serie, Lieblingswaffe). Knöpfe „Nochmal“ und „Hauptmenü“.

---

## 🤖 Gegner-Bots (KI)

Nach „Spiel starten“ wählst du **Anzahl (1–7)** und **Schwierigkeit** der Bots: Anfänger, Normal, Erfahren, Profi, Gott. Die Stufe bestimmt Treffgenauigkeit, Reaktionszeit, Feuerrate, Ausweichtempo und Sichtweite. Es gilt **jeder gegen jeden**: Bots greifen den nächsten sichtbaren Gegner an, auch andere Bots, und rächen sich an dem, der sie beschießt. Gespawnt wird am Punkt mit dem größten Abstand zu allen anderen.

Die Bots besitzen eine 4-stufige Zustandsmaschine:
- **PATROL (Patrouille)**: Läuft Arena-Wegpunkte ab und sucht per Raycast nach freier Sichtlinie zum Spieler.
- **CHASE (Verfolgen)**: Nutzt `NavigationAgent3D` und die dynamisch gebackene `NavigationRegion3D`, um den Spieler anzulaufen.
- **ATTACK (Angriff)**: Fixiert den Spieler, strafet seitlich und feuert mit menschlicher Streuung (ca. 4°), um faire Ausweichmanöver zu ermöglichen.
- **DEAD (Tot)**: Schaltet Kollision ab, kippt um, schreibt dem Spieler einen Frag gut und respawnt nach 4 Sekunden an einem zufälligen Spawnpunkt.

Über den Köpfen der Bots schwebt ein 3D-Namensschild (`Label3D`) mit Live-Status und Lebenspunkten.

---

## 🛡️ Schadens- & Pickup-System

- **Einstellungen**: Mausempfindlichkeit und Lautstärke werden in `user://settings.cfg` gespeichert.
- **Lebenspunkte (HP)**: 100 Basis-HP. Sinkt HP auf 0, erscheint das Todes-Overlay mit 3-Sekunden-Respawn-Countdown.
- **Rüstung**: Startet bei 50 (bis max. 100). Fängt **66 %** allen Schadens ab, während nur 34 % die Lebenspunkte schwächen.
- **Treffer-Feedback**: 
  - Akustischer Quake-Ding-Sound (`hitsound`) bei Treffern.
  - Roter Hitmarker am Fadenkreuz.
  - Schwebende 3D-Schadenszahlen über getroffenen Gegnern (`-12`, `-50`, `-100`).
- **Pickups in der Arena**:
  - **Munition** (Gelb): Füllt alle Waffen auf (+60 MG, +6 Raketen, +5 Railgun).
  - **Gesundheit** (Grün): Heilt +35 HP.
  - **Rüstung** (Blau): Gibt +50 Rüstung.
  - **Quad Damage** (violett): dreifacher Schaden für 30 s, auch beim Rocket-Jump. Violetter Bildrand und Countdown im HUD; Bots mit Quad leuchten violett. Respawn nach 60 s.
  - **Mega Health** (blaue Kugel): +100 Leben bis maximal 200, sinkt danach um 1 pro Sekunde auf 100. Respawn nach 35 s.
  - Alle Items rotieren schwebend und respawnen nach dem Einsammeln automatisch.
  - Bots sammeln Leben, Rüstung und Power-ups ebenfalls ein und laufen gezielt zu lohnenden Items (Power-ups zuerst, Leben bei wenig HP).

---

## 📁 Projektstruktur

```
Booter/
├── levels/
│   └── test_arena.tscn     # 3D-Arena mit Rampen, Podesten, Säulen, Items & Bots
├── scenes/
│   ├── bot.tscn            # Gegner-Bot mit visueller Rüstung & NavAgent
│   ├── player.tscn         # Spieler mit First-Person-Kamera & HUD
│   ├── effects/
│   │   └── floating_number.tscn # Schwebende 3D-Schadenszahlen
│   ├── items/
│   │   ├── ammo_pickup.tscn     # Munitionskiste
│   │   ├── health_pickup.tscn   # Heilungs-Kreuz
│   │   └── armor_pickup.tscn    # Rüstungs-Schild
│   ├── menu/
│   │   └── main_menu.tscn       # Hauptmenü mit Einstellungen & Start
│   ├── ui/
│   │   ├── hud.tscn             # Spieler-HUD
│   │   └── pause_menu.tscn      # Pause-Menü
│   └── weapons/
│       ├── machine_gun.tscn     # Maschinengewehr 3D-Szene
│       ├── rocket_launcher.tscn # Raketenwerfer 3D-Szene
│       ├── rocket.tscn          # Raketen-Projektil
│       ├── explosion.tscn       # Detonation mit Partikeln & Schockwelle
│       ├── railgun.tscn         # Railgun 3D-Szene
│       ├── beam.tscn            # Leuchtender Railgun-Lichtstrahl
│       └── hit_spark.tscn       # Funken-Einschlagseffekt
├── resources/
│   └── weapons/            # WeaponData (.tres) je Waffe: Schaden, Feuerrate, Munition
├── scripts/
│   ├── components/
│   │   └── health_component.gd # Leben & Rüstung für Spieler und Bots
│   ├── ui/
│   │   ├── hud.gd
│   │   └── pause_menu.gd
│   ├── damage_info.gd      # Daten eines Treffers
│   ├── layers.gd           # Kollisions-Layer als Konstanten
│   ├── game_manager.gd     # Autoload-Singleton (Punkte, Respawns, Pause-Menü)
│   ├── player.gd           # Quake-Bewegung, Doppelsprung, HUD, Schaden
│   ├── bot.gd              # Bot-Zustandsmaschine & KI
│   ├── weapon_base.gd      # Basisklasse für Waffen
│   ├── weapon_manager.gd   # Waffenwechsel, Swaying, Bobbing
│   ├── sound_generator.gd  # Prozedurale Sound-Synthese im RAM
│   ├── effects/
│   │   └── floating_number.gd # Logik für schwebende Schadenszahlen
│   ├── items/
│   │   └── pickup.gd       # Item-Pickup-Drehung, Aufsammeln, Respawn
│   ├── levels/
│   │   └── arena.gd        # Dynamisches Navmesh-Bake & Spawnpunkt-Registrierung
│   └── weapons/
│       ├── machine_gun.gd
│       ├── rocket_launcher.gd
│       ├── rocket.gd
│       ├── explosion.gd
│       └── railgun.gd
├── tests/
│   └── smoke_test.gd       # Headless-Rauchtest
├── icon.svg
└── project.godot           # Projekteinstellungen (Startszene: main_menu.tscn)
```

---

## 🔊 Sound

Alle Sounds liegen als WAV in `assets/sounds/` und werden von `python tools/make_sounds.py <Ordner mit Ansager-Rohaufnahmen>` erzeugt (nur numpy nötig):
- **Waffen und Effekte** aus mehreren Schichten (Anschlag, Körper, Rauschen, Verzerrung, Hall), 44,1 kHz / 16 Bit
- **Musik:** Synthwave-Loop, 120 BPM, 64 s (Intro, Teil A mit Schlagzeug, Break, Teil B mit Lead), läuft im Menü und im Match; im Menü, in der Pause und am Matchende gedämpft
- **Schritte** (vier Varianten) für Spieler und Bots (Bots als 3D-Sound, damit man sie kommen hört), Sprung und Landung
- **Ansager:** „3, 2, 1, Fight!“, First Blood, Double/Multi/Mega/Monster Kill, Killing Spree … Godlike, Quad Damage, Mega Health, Combo, Zeitansagen, You have won/lost. Gesprochen von der Windows-Sprachausgabe (Stimme „Zira“), dann tiefer gestimmt, gedoppelt, verzerrt und mit Hall versehen.

Audio-Busse (`default_bus_layout.tres`): Master, Music (eigener Lautstärkeregler in den Einstellungen, Tiefpass für den gedämpften Zustand), Announcer (mit Kompressor). Fehlt eine WAV-Datei, erzeugt `SoundGenerator` wie früher einen prozeduralen Ersatz.

---

## 🎨 Look: „Neon-Brutalism“

Dunkle Low-Poly-Körper mit leuchtenden Wireframe-Kanten. Der Nachbearbeitungs-Shader `assets/shaders/neon_edges.gdshader` findet Kanten über Tiefen- und Normalensprünge und färbt sie im Farbton der jeweiligen Fläche: orange Plattformen bekommen orange Kanten, Bots die Kanten in ihrer eigenen Farbe. Dazu:
- CRT-Look (`crt_overlay.gdshader`): Farbsaum, Vignette, feine Scanlines, roter Puls bei Treffern
- Bots zerplatzen beim Tod in leuchtende Würfel (`scenes/effects/voxel_burst.tscn`)
- Leuchtspuren für MG, Shotgun und Bot-Schüsse (`scenes/effects/tracer.tscn`)
- HUD als Panel-Leiste unten: HP und Rüstung mit Balken, Spielerbild, Munition mit Balken, Waffe und Slots 1–4

Neue Flächen bekommen den Look automatisch: dunkle, leicht farbige Grundfarbe wählen, die Kanten erledigt der Shader.

---

## 🗺️ Arenen

Im Match-Fenster wählbar:
- **Neon Foundry** (Standard): 64 × 64 m, drei Ebenen. Boden mit Deckungsblöcken und zwei Durchgangswänden mit Tür, ein Ring-Steg auf 4 m entlang aller Wände, eine Mittelplattform auf Säulen mit zwei Brücken, zwei Türme auf 8 m (Nordost, Südwest). Sechs Treppen, drei Jump-Pads, 10 Items, 8 Spawnpunkte.
- **Testarena**: die ursprüngliche flache Arena (für Tests).

**So entsteht die Neon Foundry:**
1. `python tools/generate_neon_foundry.py` erzeugt `maps/neon_foundry.map` (Quake-Format).
2. `python tools/make_neon_foundry_scene.py` erzeugt die Vorlage `levels/neon_foundry_template.tscn` (Spawns, Items, Jump-Pads, Licht).
3. `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/build_level.gd -- res://levels/neon_foundry_template.tscn res://levels/neon_foundry.tscn` baut die Geometrie ein.

Die `.map` lässt sich auch in TrenchBroom öffnen und von Hand weiterbauen (Spiel „Generic“, Texturordner `assets/map_textures`). Danach nur Schritt 3 wiederholen. Treppen bestehen aus sichtbaren Stufen ohne Kollision (`func_detail_illusionary`) und einer unsichtbaren Rampe (Textur `clip`), weil Spieler und Bots keine Stufen steigen können.

Map-Texturen: `assets/map_materials/neon/*.tres` (Godot-Materialien) und `assets/map_textures/neon/*.png` (Vorschau für TrenchBroom), erzeugt von `python tools/make_map_materials.py`. Verfügbar: `floor`, `wall`, `walkway`, `metal`, `accent`, `glow_cyan`, `glow_magenta`, `glow_yellow`, `glow_orange`.

## 🗺️ Maps bauen (func_godot + TrenchBroom)

Das Addon **func_godot** (Version 2025.12, MIT-Lizenz, `addons/func_godot/`) wandelt Quake-`.map`-Dateien in Godot-Geometrie mit Kollision um. Maps baut man im kostenlosen Editor **TrenchBroom** (https://trenchbroom.github.io), den du selbst installierst. In Godot einen `FuncGodotMap`-Knoten anlegen, die `.map`-Datei eintragen und „Build Map“ drücken. 32 Quake-Einheiten entsprechen 1 m.

---

## 🧪 Automatischer Test

Ein Rauchtest lädt die Arena und prüft Treffer, Feuerrate, Rocket-Jump, Pickups, Tod, Respawn, Pause und Einstellungen:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test.gd
```

Exit-Code 0 bedeutet: alles bestanden.

Für den Match-Ablauf (Countdown, Fraglimit, Siegerbildschirm, Neustart, Zeitlimit): `-s res://tests/match_test.gd`

Für die Neon Foundry gibt es einen eigenen Begehbarkeitstest (Treppen, Brücke, Tür, Jump-Pads, Bot-Wege, Bot läuft auf einen Turm):

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/neon_foundry_test.gd
```

---

## 🔮 Nächste mögliche Schritte

1. **Weitere Gegnertypen**: Schnelle Nahkampf-Bots oder schwere Raketen-Bots.
2. **Audio-Erweiterung**: Hintergrund-Synthesizer-/Industrial-Musik für noch mehr UT-Atmosphäre.
3. **Erweiterte Arenen**: Teleporter und Lava-/Säure-Fallen.
4. **Mehr Waffen**: Plasmagewehr, Lightning Gun, Shock Rifle.

Der ausführliche Plan steht in `ROADMAP.md`.
