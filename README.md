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
| **1, 2, 3, 4** oder **Mausrad** | Waffe wechseln (1: MG, 2: Shotgun, 3: Raketenwerfer, 4: Railgun) |
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
| **Raketenwerfer** (3) | Projektil | 50 (Direkt) + bis zu 100 (Fläche) | 0.8s Abklingzeit | Sichtbare Rakete, Schockwelle, Flächenschaden & Rocket-Jumping |
| **Railgun** (4) | Hitscan-Strahl | 100 | 1.25s Abklingzeit | Sofortiger Einschlag über 300m, nachleuchtender Cyan-Energiestrahl |

---

## 🤖 Gegner-Bots (KI)

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
  - Alle Items rotieren schwebend und respawnen nach dem Einsammeln automatisch.

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

## 🧪 Automatischer Test

Ein Rauchtest lädt die Arena und prüft Treffer, Feuerrate, Rocket-Jump, Pickups, Tod, Respawn, Pause und Einstellungen:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test.gd
```

Exit-Code 0 bedeutet: alles bestanden.

---

## 🔮 Nächste mögliche Schritte

1. **Weitere Gegnertypen**: Schnelle Nahkampf-Bots oder schwere Raketen-Bots.
2. **Audio-Erweiterung**: Hintergrund-Synthesizer-/Industrial-Musik für noch mehr UT-Atmosphäre.
3. **Erweiterte Arenen**: Teleporter und Lava-/Säure-Fallen.
4. **Mehr Waffen**: Plasmagewehr, Lightning Gun, Shock Rifle.

Der ausführliche Plan steht in `ROADMAP.md`.
