# Roadmap: Vom Prototyp zum Quake/UT-Arena-Shooter

Ziel: ein schneller, gut lesbarer Arena-Shooter im Geist von Quake 3 und Unreal Tournament. Bewegung mit hoher Skill-Decke, ein klar unterscheidbares Waffenarsenal, Item-Kontrolle als Taktik, Bots, die sich wie Spieler anfühlen, und ein moderner Look.

Der Prototyp hat schon viel davon: Strafe-Jumping, Doppelsprung, Rocket-Jump, drei Waffen, Bots mit Navmesh, Pickups und Menüs. Die Roadmap baut darauf auf, statt neu anzufangen.

Aufwand: **S** = bis 1 Tag, **M** = 2–5 Tage, **L** = 1–3 Wochen.

---

## Phase 0: Fundament (vor allem anderen)

Ohne diese Schritte wird jede spätere Phase teurer.

| # | Aufgabe | Warum | Aufwand |
|---|---|---|---|
| 0.1 | ✅ `git init`, erster Commit, danach kleine Commits pro Feature | Jede Änderung lässt sich zurückdrehen | S |
| 0.2 | ✅ Projekt einmal in Godot starten und Fehler aus Runde 1 und 2 beseitigen | Bisher ist nichts in der Engine getestet | S |
| 0.3 | ✅ teilweise: 120 Hz gesetzt, Interpolation folgt nach Test in der Engine. **Physik-Takt auf 120 Hz** (`physics/common/physics_ticks_per_second`) plus **Physik-Interpolation** einschalten | Quake-Bewegung fühlt sich erst bei hohem Takt präzise an. Strafe-Jumping hängt direkt davon ab | S |
| 0.4 | ✅ **Jolt Physics** als 3D-Physik-Engine wählen | Stabiler und schneller als GodotPhysics, vor allem bei CharacterBody3D an Kanten und Rampen | S |
| 0.5 | ✅ Kollisions-Layer in den Projekteinstellungen benennen (World, Player, Bot, Pickup, Projectile) und überall statt `0xFFFFFFFF` nutzen | Heute stehen Zahlen wie `collision_mask = 5` im Code, das ist schwer zu lesen | S |
| 0.6 | ✅ **Waffen als Daten:** `WeaponData`-Resource (`.tres`) mit Schaden, Feuerrate, Munition, Sounds, Modell | `add_all_ammo(mg, rkt, rail)` und Index 0/1/2 in Pickups brechen bei jeder neuen Waffe | M |
| 0.7 | ✅ teilweise: HealthComponent und HUD-Szene; Bewegung bleibt in `player.gd`. **`player.gd` aufteilen** (500 Zeilen): `MovementController`, `HealthComponent` (auch für Bots), HUD als eigene Szene mit eigenem Skript | Bewegung, Schaden und HUD hängen heute in einer Datei | M |
| 0.8 | ✅ `DamageInfo`-Klasse (Menge, Angreifer, Waffe, Position, Richtung, Headshot) statt vier loser Parameter | Killfeed, Ansager, Statistiken und Multiplayer brauchen das alle | S |
| 0.9 | ✅ Pause-Menü aus `game_manager.gd` in eine eigene `.tscn` verschieben | UI im Editor gestalten statt per Code | S |

---

## Phase 1: Movement und Spielgefühl

Das Herz eines Arena-Shooters. Hier entscheidet sich, ob es sich „wie Quake“ anfühlt.

| # | Aufgabe | Aufwand |
|---|---|---|
| 1.1 | Luftbewegung an Quake 3 / CPMA angleichen (getrennte Werte für Strafe- und Vorwärts-Beschleunigung, Werte im Inspector zum Feintuning) | M |
| 1.2 | **UT-Dodge**: Doppeltipp auf A/D/W/S für seitlichen Sprung, plus **Wall-Dodge** (Dodge von Wänden ab) | M |
| 1.3 | ✅ teilweise: Jump-Pads mit NavigationLink3D für Bots, Teleporter fehlen noch. **Jump-Pads** und **Teleporter** (Area3D mit Ziel-Marker, Bots brauchen dafür NavigationLink3D) | M |
| 1.4 | Rampen-Sliding und sauberes Treppensteigen (Step-Up), Landung ohne Geschwindigkeitsverlust beim Bunnyhop | M |
| 1.5 | Kamera-Feedback: Landungs-Dip, View-Punch bei Treffern, leichtes FOV-Weiten bei hoher Geschwindigkeit (abschaltbar) | S |
| 1.6 | Fallschaden ab großer Höhe, Schrittgeräusche abhängig vom Tempo | S |
| 1.7 | Speedometer/Debug-Overlay für Movement-Tuning (Geschwindigkeit, Wunschrichtung, Luftzeit) | S |

---

## Phase 2: Waffenarsenal

Quake und UT leben davon, dass jede Waffe eine klare Rolle hat. Neun Waffen sind klassisch; sechs bis sieben reichen für den Anfang.

| Waffe | Rolle | Vorbild | Alt-Feuer (UT-Stil) |
|---|---|---|---|
| Maschinengewehr | Start-Waffe, Dauerfeuer | Q3 MG / UT Enforcer | Höhere Feuerrate, mehr Streuung |
| ✅ **Shotgun** | Nahkampf, Burst | Q3 Shotgun / UT Flak | Granate mit Schrot (Flak-Kugel) |
| **Plasma-Gewehr** | Mittlere Distanz, Spam | Q3 Plasma / UT Link | Kurzer Strahl |
| Raketenwerfer | Allrounder, Rocket-Jump | Q3/UT | Mehrere Raketen laden |
| **Lightning Gun** | Strahl auf Mittel-Distanz, Tracking | Q3 LG | – |
| **Shock Rifle** | Hitscan + langsame Kugel, **Combo** bei Treffer der Kugel | UT | Schock-Kugel |
| Railgun | Fernkampf, Präzision | Q3 Rail / UT Sniper | Zoom |

Dazu:

| # | Aufgabe | Aufwand |
|---|---|---|
| 2.1 | Waffen als Pickups in der Map, nicht alle von Anfang an (Start nur MG + Nahkampf) | M |
| 2.2 | Alt-Feuer (rechte Maustaste) im `WeaponBase` vorsehen | S |
| 2.3 | Waffenwechsel mit Ab-/Aufzieh-Animation und schnellem „Weapon Switch“ wie in Q3 | S |
| 2.4 | Object-Pooling für Projektile, Funken, Einschläge | S |
| 2.5 | Headshots für Hitscan (Railgun/Shock) mit eigenem Hitsound | S |
| 2.6 | ✅ teilweise: glühende Einschusslöcher. Einschusslöcher als Decals, Rauchspuren hinter Raketen, Hülsen beim MG | M |

---

## Phase 3: Moderner Look

Der aktuelle Stand sind einfache Meshes und prozedurale Effekte. Für einen modernen Arena-Look:

| # | Aufgabe | Aufwand |
|---|---|---|
| 3.1 | ✅ Erste Map „Neon Foundry“ per Generator + func_godot. **Maps mit TrenchBroom + [func_godot](https://github.com/func-godot/func_godot_plugin)** bauen. Das ist der klassische Quake-Workflow: Brushes, Rampen, Jump-Pads als Entities, schnelle Iteration | M (Setup) |
| 3.2 | ✅ AgX, Bloom, SSAO, Volumetric Fog, Neon-Raster-Shader, Sternenhimmel-Shader (SSR bewusst weggelassen). `WorldEnvironment`: Tonemapping (AgX), Glow/Bloom, SSAO, SSR, leichter Volumetric Fog, eigener Skybox-Shader | S |
| 3.3 | Licht: **LightmapGI** backen (beste Qualität bei statischer Arena) oder SDFGI für schnelle Iteration | M |
| 3.4 | Stilrichtung festlegen. Empfehlung: **Sci-Fi-Industrial mit Neon-Akzenten** (UT99/UT4-Anmutung), das kaschiert einfache Geometrie und ist gut lesbar | – |
| 3.5 | Modelle: Waffen und Bots aus Blender oder CC0-Paketen (z. B. Kenney, Quaternius), Bots mit Lauf-/Schuss-/Todes-Animation und Ragdoll | L |
| 3.6 | Shader: leuchtende Pickups mit Fresnel-Rand, Schild-Effekt bei Rüstung, Teleporter-Portal, Hologramm-Respawn | M |
| 3.7 | GPUParticles statt CPUParticles für Explosionen, Funken, Rauch | S |
| 3.8 | ✅ **Lesbarkeit vor Schönheit**: Gegner in Team-/Hervorhebungsfarbe (Brightskins wie in Q3), optional abschaltbar | S |

---

## Phase 4: Audio

| # | Aufgabe | Aufwand |
|---|---|---|
| 4.1 | Prozedurale 8-Bit-Sounds durch echte Samples ersetzen (eigene Aufnahmen, sfxr/jsfxr, CC0 von freesound.org). `SoundGenerator` kann als Fallback bleiben | M |
| 4.2 | **Ansager**: „Double Kill“, „Killing Spree“, „Headshot“, „Flag taken“, Countdown „3, 2, 1, Fight!“ | M |
| 4.3 | Audio-Busse (SFX, Musik, Ansager, UI) mit eigenem Lautstärke-Regler und Hall in großen Räumen | S |
| 4.4 | Musik: treibender Industrial/Electro-Track pro Map, Menü-Musik | M |
| 4.5 | Positionelles Audio verbessern: Schritte von Gegnern hörbar (wichtig für Arena-Taktik) | S |

---

## Phase 5: Bots, die wie Spieler spielen

Heute können Bots nur patrouillieren, verfolgen und mit einer Waffe schießen.

| # | Aufgabe | Aufwand |
|---|---|---|
| 5.1 | ✅ Skill-Stufen (Zielgenauigkeit, Reaktionszeit, Bewegung) wie „Novice … Godlike“ | S |
| 5.2 | Bots nutzen alle Waffen, wählen die passende nach Distanz und **zielen bei Projektilen vor** (Vorhalt) | M |
| 5.3 | ✅ teilweise: Bots steuern lohnende Items an (ohne Respawn-Timing). **Item-Bewusstsein**: Bots holen Health/Armor bei wenig Leben und kennen die Respawn-Zeiten großer Items | M |
| 5.4 | Ausweichen: Dodge, Strafe-Jumping, Rocket-Jump auf hohe Plattformen | L |
| 5.5 | Entscheidungslogik als **Utility-AI** statt fester Zustandsmaschine (jede Aktion bekommt eine Punktzahl, der Bot wählt die beste) | M |
| 5.6 | Namen, Persönlichkeiten (aggressiv, vorsichtig, Camper), Sprüche im Chat | S |

---

## Phase 6: Spielmodi und Match-Ablauf

| # | Aufgabe | Aufwand |
|---|---|---|
| 6.1 | **Deathmatch** mit Frag-Limit und Zeitlimit, Warmup, Countdown, Endbildschirm mit Statistik | M |
| 6.2 | ✅ teilweise: Scoreboard und Killfeed, Multi-Kill/Spree fehlt. **Scoreboard** (Tab), **Killfeed** oben rechts, Multi-Kill-/Spree-System | M |
| 6.3 | ✅ teilweise: Quad Damage und Mega Health. **Power-ups**: Quad Damage / UDamage, Mega Health, Red Armor, Shield Belt, Invisibility. Große Items erzeugen die typische Map-Kontrolle | M |
| 6.4 | **Instagib** (nur Railgun, ein Treffer tötet), ideal als schneller Zusatzmodus | S |
| 6.5 | **Team Deathmatch**, danach **Capture the Flag** | L |
| 6.6 | Duel-Modus (1 gegen 1, Item-Timing entscheidet) | S |

---

## Phase 7: HUD, Menüs, Einstellungen

| # | Aufgabe | Aufwand |
|---|---|---|
| 7.1 | Modernes HUD: große Zahlen für HP/Rüstung unten links, Munition unten rechts, Waffenleiste, Power-up-Timer | M |
| 7.2 | **Trefferrichtungs-Anzeige** (rote Markierung, aus welcher Richtung der Schaden kam) | S |
| 7.3 | Fadenkreuz-Editor (Form, Farbe, Größe), Hitmarker-Optionen | S |
| 7.4 | ✅ teilweise: FOV-Regler. Einstellungen: **FOV**, Grafik-Presets, Auflösungsskalierung (FSR), V-Sync/FPS-Limit, **Tastenbelegung**, Gamepad | M |
| 7.5 | Hauptmenü mit 3D-Hintergrund (Kamerafahrt durch die Arena), Map- und Modusauswahl, Bot-Anzahl und -Stärke | M |

---

## Phase 8: LAN-Multiplayer (optional, später)

**Entscheidung (2026-10-20):** Zuerst nur Singleplayer gegen Bots. LAN kommt eventuell später, Online-Multiplayer ist kein Ziel.

Für LAN fallen Lag-Compensation und Server-Browser weitgehend weg (geringe Latenz), aber Bewegung, Waffen und Schaden müssen trotzdem vom Host bestimmt werden. Deshalb lohnt es sich, 8.1 schon früh zu berücksichtigen: Es kostet jetzt wenig und erspart später einen Umbau.

| # | Aufgabe | Aufwand |
|---|---|---|
| 8.1 | Architektur vorbereiten: Eingaben als „Kommandos“ sammeln und getrennt von der Bewegung verarbeiten, Spielzustand nur an einer Stelle ändern | M |
| 8.2 | LAN mit Godots High-Level-Multiplayer (ENet), **Host-autoritativ** (ein Spieler ist Server) | L |
| 8.3 | Interpolation für Gegner, einfache Vorhersage der eigenen Bewegung | M |
| 8.4 | Spiel im LAN finden (UDP-Broadcast) oder Direktverbindung per IP | S |
| 8.5 | Bots laufen nur auf dem Host und werden wie Spieler übertragen | M |

Bei reinem LAN entfallen Lag-Compensation und dedizierter Server.

---

## Phase 9: Performance, Release

| # | Aufgabe | Aufwand |
|---|---|---|
| 9.1 | Ziel 144+ FPS: Profiler nutzen, Occlusion Culling, LODs, Schatten sparsam | M |
| 9.2 | Exporte für Windows/Linux, Versionsnummer im Hauptmenü | S |
| 9.3 | Automatische Tests für Schadensberechnung und Movement (GUT oder gdUnit4) | M |
| 9.4 | Itch.io-Seite oder Steam-Playtest | M |

---

## Empfohlene Reihenfolge

1. **Phase 0 komplett** (ca. 1 Woche).
2. **Quick Wins für sofort sichtbaren Fortschritt** (2–3 Tage): 0.3 120 Hz, 3.2 WorldEnvironment, 1.3 Jump-Pads, 6.2 Killfeed + Scoreboard, 7.4 FOV-Regler, Shotgun aus Phase 2.
3. **Phase 1 + 2**: Movement und Waffen, bis das Spielen gegen Bots Spaß macht.
4. **Phase 3.1** TrenchBroom-Workflow und eine richtige erste Map (z. B. ein Q3DM17-artiges Weltraum-Plattform-Level, perfekt für Rocket-Jumps).
5. **Phase 6.1 + 6.3 + 5.x**: echtes Deathmatch mit Power-ups und besseren Bots.
6. Rest von Phase 3, 4 und 7 für Look und Klang.
7. **Phase 8** (LAN), falls es dann noch gewünscht ist.

Meilenstein-Ziel nach Schritt 5: *Ein vollständiges 10-Minuten-Deathmatch auf einer echten Map gegen 3–5 Bots mit 6 Waffen und Power-ups.*
