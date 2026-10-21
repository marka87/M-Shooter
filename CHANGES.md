# Änderungen (Runde 22: Waffenwechsel, Sprung-Bewegung, GPU-Partikel, Pools, Interpolation)

- **Waffenwechsel-Animation:** Die neue Waffe schwenkt in 0,15 s von unten hoch (schnell wie in Quake 3) und feuert erst, wenn sie oben ist.
- **Waffe bei Sprung und Landung:** Beim Steigen hängt sie etwas nach unten, beim Fallen hebt sie sich, beim Aufkommen knickt sie ein (stärker nach hohem Fall) und federt zurück.
- **GPU-Partikel:** Explosion, Treffer-Funke und Energie-Einschlag nutzen jetzt `GPUParticles3D` (umgewandelt mit Godots `convert_from_particles`). Es gibt keine CPU-Partikel mehr.
- **Pools:** Treffer-Funken mit Einschussloch (`HitSpark.spawn()`, bisher an 7 Stellen kopierter Code) und Leuchtspuren (`Tracer.spawn()`) werden wiederverwendet statt bei jedem Schuss neu erzeugt.
- **Physik-Interpolation** eingeschaltet: Spieler, Bots, Ragdolls und Projektile bewegen sich zwischen den 120 Physik-Ticks flüssig. Kopf und Kamera folgen der interpolierten Position, die Mausdrehung wirkt sofort. Respawn, Teleporter und Projektilstart setzen die Interpolation zurück; kurzlebige Effekte sind davon ausgenommen. Abschalten: `physics/common/physics_interpolation` in `project.godot`.
- Tests: Bewegungstest um Waffe bei Fall/Landung, Interpolation und Waffenwechsel erweitert, Smoke-Test um beide Pools. Alle vier Tests grün.

---

# Änderungen (Runde 21: Kopftreffer)

- **Headshots** für Railgun und Shock-Strahl: Trifft der Strahl einen Spieler oder Bot ab 1,5 m über den Füßen, zählt das als Kopftreffer mit 1,5-fachem Schaden (Railgun 150 statt 100, Shock 67 statt 45). `DamageInfo` hat dafür `is_headshot` und `is_head_hit()`.
- Eigener heller **Kopftreffer-Ton** (`assets/sounds/headshot.wav`) statt des normalen Hitsounds.
- **Ansage „Headshot!“** und Einblendung HEADSHOT beim Kill durch einen Kopftreffer (First Blood und Combo haben Vorrang). Die Stimme ist wie die anderen Ansagen erzeugt (Windows-Sprachausgabe „Zira“ + Nachbearbeitung).
- `tools/make_sounds.py --announcer <Ordner>` verarbeitet nur Ansager-Rohaufnahmen, ohne Musik und Effekte neu zu rechnen.
- Match-Test: Körpertreffer 100, Kopftreffer 150, Ansage beim Kill. Alle vier Tests grün.

---

# Änderungen (Runde 20: Instagib)

- **Instagib-Modus** (Schalter im Match-Fenster, wird gespeichert): Alle starten nur mit der Railgun, die Munition ist unendlich, jeder Treffer macht 1000 Schaden (ein Treffer tötet, Bots zerplatzen). Alle Items sind ausgeblendet.
- Bots schießen im Instagib mit der Railgun: Railgun-Sound, dickere Leuchtspur, höchstens alle 1,25 s ein Schuss, Killfeed zeigt „Railgun“.
- `WeaponManager` startet und respawnt mit der ersten Waffe, die man besitzt (bisher fest das MG).
- Match-Test um 5 Instagib-Prüfungen erweitert. Alle vier Tests grün.
- ROADMAP: 6.4 erledigt, 3.4 abgehakt (Neon-Stil), 7.5 teilweise.

---

# Änderungen (Runde 19: Waffenmodelle)

- **Neue Waffenmodelle** für alle 7 Waffen im Neon-Low-Poly-Stil: dunkler Grafit-Körper, metallische Zierteile, Leuchtteile in der Waffenfarbe. Facettierte Formen (Sechs- und Achtecke), damit der Kanten-Shader klare Kanten zeichnet. Jede Waffe hat eine eigene Silhouette: MG mit Magazin und Laufmantel, Doppelflinte mit Pumpe, Plasma mit drei Spulen und Energiezelle, sechseckiges Raketenrohr mit Munitionsbox, Lightning Gun mit drei Zinken, Railgun mit Schienen, Zielfernrohr und Ringen, Shock Rifle mit Finnen und Zelle.
- Generator `tools/make_weapon_models.py` schreibt die Modelle nach `scenes/weapons/models/`. Die Waffenszenen binden sie als Instanz `Model` ein; Muzzle, Licht und Sound bleiben. Die Waffen-Pickups zeigen automatisch die neuen Modelle.
- **ROADMAP** um neue Punkte ergänzt: 2.7–2.9 (Waffenmodelle, Viewmodel-Bewegung, Effekte pro Waffe), 3.9–3.11 (Level von zu Hause mergen, Map-Baukasten, weitere Maps).
- Alle vier Tests grün. Laufspitzen headless gegen die Muzzle-Punkte geprüft.

---

# Änderungen (Runde 18: Animierte Bots mit Ragdoll)

- **Bots als animierte Figuren** statt Block-Roboter: Mannequin aus der **Quaternius Universal Animation Library** (CC0, `assets/characters/ual/`, Lizenzdatei liegt bei). Körper dunkel in der Bot-Farbe, Gelenke leuchten in der Bot-Farbe (die Neonkanten übernehmen sie). Waffe hängt an der rechten Hand (`BoneAttachment3D`), die Mündung sitzt an der Hand in Zielhaltung.
- **Animationen** über einen `AnimationTree` aus Code: Idle / Walk / Jog / Sprint je nach Tempo, Sprung-Pose in der Luft, Pistolen-Zielhaltung im Kampf (nur Oberkörper) und Treffer-Zucken (`Hit_Chest`).
- **Ragdoll beim Tod:** `PhysicalBoneSimulator3D` mit 11 Kapseln (Becken, Rumpf, Kopf, Arme, Beine) und Kegelgelenken, aus Code erzeugt. Der Körper fliegt in Schussrichtung bzw. von der Explosion weg. Die Kapseln kollidieren nur mit der Welt.
- **Gib** (Würfel-Burst) nur noch bei großen Treffern: ab 120 Schaden oder ab 50 Explosionsschaden.
- Smoke-Test um 4 Prüfungen erweitert (Ragdoll startet, liegt am Boden, Respawn beendet ihn, Gib bei großem Treffer). Alle vier Tests grün.

---

# Änderungen (Runde 17: Windows-Build, Version 0.9.0)

- **Versionsnummer** 0.9.0 in `project.godot` (`application/config/version`), unten rechts im Hauptmenü zusammen mit der Godot-Version.
- **Export-Preset „Windows“** (`export_presets.cfg`): eine einzelne `ArenaShooter.exe` (x86_64, Spieldaten eingebettet) nach `build/windows/`, ohne `tests/` und `tools/`. Datei-Infos: Produktname „Arena Shooter“, Version 0.9.0.0.
- Godot-Export-Vorlagen 4.7.2 installiert (nur Windows x86_64), Build erstellt: 113 MB, davon ca. 109 MB Engine.
- Geprüft: Die exe startet ins Hauptmenü mit Versionsanzeige. Ein Debug-Export mit denselben Spieldaten lief in der Neon Foundry mit Grafik, HUD, Countdown und Musik.
- README: Abschnitt „Windows-Build“ mit Export-Befehl.

---

# Änderungen (Runde 16: Movement – Dodge, Teleporter, Kamera)

- **UT-Dodge:** Richtungstaste zweimal innerhalb 0,25 s → Sprung mit 13 m/s in diese Richtung (5 m/s nach oben), danach noch ein Luftsprung möglich (Dodge-Jump). Abklingzeit 0,35 s. Eigener Sound.
- **Wall-Dodge:** In der Luft von einer Wand direkt hinter einem abstoßen (12 m/s weg, 6,5 m/s hoch), einmal pro Sprung.
- **Bots dodgen** im Kampf beim Richtungswechsel, je nach Schwierigkeit (Anfänger nie, Gott in 55 % der Fälle).
- **Teleporter** (`scenes/items/teleporter.tscn`): Ausgang mit fester Blickrichtung und 8 m/s Tempo, Lichtblitz und Sound an beiden Enden, **Telefrag** für jeden, der am Ausgang steht. NavigationLink3D, damit Bots sie als Abkürzung nutzen. In der Neon Foundry: Boden Nordwest → Ost-Ring, Boden Südost → West-Ring.
- **Kamera-Feedback** (`scripts/components/camera_feedback.gd`): Einknicken beim Landen (stärker bei hohem Fall), Rucken bei Treffern und Rückstoß, Wackeln bei Explosionen in der Nähe (Trauma-System), Neigung beim seitlichen Dodge, bis zu +10° Sichtfeld bei hohem Tempo. Schalter „Kamera-Effekte“ in den Einstellungen (gespeichert).
- `tools/make_sounds.py --only name1,name2` erzeugt einzelne Effekte, ohne Musik und Ansager neu zu rechnen.
- **Neuer Test** `tests/movement_test.gd` (13 Prüfungen): Dodge, zu langsames Tippen, Abklingzeit, Wall-Dodge (einmal pro Sprung, nicht ohne Wand), Landung, Tempo-Sichtfeld, Treffer-Ruck, Explosions-Wackeln, Abschalten. Neon-Foundry-Test um Teleporter, Blickrichtung, Telefrag und Bot-Weg über den Teleporter erweitert. Alle vier Tests grün.

---

# Änderungen (Runde 15: Sound)

- **Neuer Sound-Generator** `tools/make_sounds.py` (nur numpy): alle Waffen, Explosion, Combo, Treffer, Pickups, Sprung-Pad, Bot-Treffer/-Tod jetzt als 16-Bit-WAV mit 44,1 kHz in `assets/sounds/`. Geschichtete Synthese: Anschlag, Körper, Rauschen, Verzerrung, Faltungshall. Gleichspannungsanteil wird entfernt.
- **Musik:** Synthwave-Loop (120 BPM, 64 s, Am–F–C–G) mit Kick, Snare, Hi-Hats, pumpendem Bass (Sidechain), Flächen, Arpeggio mit Echo und Lead-Melodie im zweiten Teil. Läuft dauerhaft; im Menü, in der Pause und am Matchende über einen Tiefpass gedämpft.
- **Ansager-Stimme:** 21 Sätze, gesprochen von der Windows-Sprachausgabe und bearbeitet (tiefer, gedoppelt, Ringmodulation, Verzerrung, Hall). Ansagen für Countdown, First Blood (neu), Multi-Kills, Serien, Quad Damage, Mega Health, Combo, 5 Minuten / 1 Minute Restzeit, Sieg und Niederlage.
- **Schritte** für Spieler (je nach Tempo) und Bots (3D-Sound), Sprung- und Landegeräusch, eigene Pickup-Sounds für Waffen, Quad und Mega Health.
- **Audio-Busse** Music (mit Tiefpass) und Announcer (mit Kompressor); **Musik-Regler** in den Einstellungen (gespeichert).
- `SoundGenerator` lädt zuerst die WAV-Dateien, fehlende Sounds werden wie bisher prozedural erzeugt.
- **Fehler behoben:** Bots ließen auch hochwertige Items (Quad) in 30 % der Fälle aus und liefen stattdessen zu Zufallspunkten. Jetzt gilt der Zufall nur noch für mittelwertige Items. Der Quad-Test war deshalb gelegentlich rot.
- Im Headless-Testmodus meldet Godot beim Beenden eine nicht freigegebene Ansage; das liegt am Dummy-Audio-Treiber. Mit echtem Audio beendet sich das Spiel sauber.
- Tests: 38 / 31 / 18, alle grün (Neon Foundry fünfmal hintereinander).

---

# Änderungen (Runde 14: Match-Ablauf)

- **Frag- und Zeitlimit** im Match-Fenster (gespeichert). Erreicht jemand das Frag-Limit oder läuft die Uhr ab, endet das Match.
- **Countdown** „3 – 2 – 1 – FIGHT!“ vor jedem Match; währenddessen können weder Spieler noch Bots laufen oder schießen. Pause ist auch im Countdown möglich.
- **HUD:** Restzeit oben in der Mitte (letzte 30 s rot), Frags mit Limit („Frags: 3 / 15“), Tacho etwas kleiner darunter.
- **Ansagen** für den Spieler: Multi-Kills (2–5+ Kills in je 3 s) und Serien (5, 10, 15, 20, 25 Kills ohne Tod).
- **Siegerbildschirm** (`scenes/ui/match_end.tscn`): „SIEG!“ oder „NIEDERLAGE“, Grund, Rangliste mit Frags, Tode, Schaden und eigene Statistik (Treffsicherheit, K/D, Schaden verursacht/erhalten, beste Serie, Lieblingswaffe). „Nochmal“ startet dieselbe Arena neu, „Hauptmenü“ geht zurück.
- **Statistik** im GameManager: Schaden pro Teilnehmer (ohne Überschaden), Kills pro Waffe, Serien, Schüsse und direkte Treffer des Spielers.
- **Neuer Test** `tests/match_test.gd` (18 Prüfungen): Countdown friert ein, Ansagen, Fraglimit, Siegerbildschirm, Neustart, Zeitlimit, Rückkehr ins Menü. Die anderen Tests schalten Countdown und Limits ab. Alle grün (38 / 31 / 18).

---

# Änderungen (Runde 13: Neue Waffen)

- **Plasma** (Slot 3): Energie-Bolzen mit 10 Schuss/s, 20 Direktschaden plus kleiner Splash. Neues gemeinsames Projektil `EnergyProjectile` mit farbigem Einschlag (`scenes/effects/energy_impact.tscn`).
- **Lightning Gun** (Slot 5): Dauerstrahl bis 24 m, 20 Treffer-Ticks pro Sekunde zu je 8 Schaden. Zwei zuckende Blitzstränge plus weißer Kern.
- **Shock Rifle** (Slot 7): Strahl (45 Schaden) und per Rechtsklick eine langsame Shock-Kugel (55 + Splash). **Combo:** Trifft der Strahl eine Shock-Kugel, explodiert sie violett mit 150 Schaden im Radius 7 m; Killfeed zeigt „Shock-Combo“.
- **Waffenbesitz:** Die neuen Waffen muss man in der Map finden (`WeaponData.start_owned = false`). Beim Einsammeln wird automatisch gewechselt; beim Respawn sind sie wieder weg. Fehlende Waffen werden beim Wechseln (Tasten, Mausrad) übersprungen.
- **Alt-Feuer** auf der rechten Maustaste (`WeaponBase.try_fire_alt`, `WeaponData.alt_cooldown`). Slots 1–7 in Quake-Reihenfolge.
- **Waffen-Pickups** (`scenes/items/weapon_pickup.tscn`): Das echte Waffenmodell schwebt vergrößert über einem Leuchtsockel. Ansage mit dem Waffennamen in Waffenfarbe. In der Neon Foundry: Plasma auf dem Nord-Ring, Lightning Gun am Boden unter dem Ost-Ring, Shock Rifle auf dem Süd-Ring.
- **HUD:** Slots 1–7, aktive Waffe in ihrer Farbe, fehlende Waffen fast unsichtbar.
- Explosionen lassen sich einfärben (`tint`), Leuchtspuren haben eine einstellbare Dauer, neue Sounds für Plasma, Lightning, Shock-Strahl, Shock-Kugel und Combo.
- **Fehler behoben:** Bots galten 2 m vor einem Item als angekommen. Landeten sie per Jump-Pad knapp neben dem Quad, wählten sie es immer wieder, ohne es zu berühren. Jetzt müssen sie Items wirklich erreichen (0,5 m).
- Tests: Neon-Foundry-Test auf 31 Prüfungen erweitert (Besitz, Einsammeln, Treffer aller drei Waffen, Combo-Kill, Waffenverlust beim Respawn). Rauchtest 38/38.

---

# Änderungen (Runde 12: Power-ups)

- **Quad Damage** (`scenes/items/quad_damage_pickup.tscn`): dreifacher Schaden für 30 s, Respawn nach 60 s. Neue Komponente `PowerupComponent` an Spieler und Bots; `DamageInfo.create()` multipliziert mit dem Faktor des Angreifers. Bots mit Quad leuchten violett und pulsieren in den letzten 3 s schneller. Beim Tod ist das Quad weg.
- **Mega Health** (`scenes/items/mega_health_pickup.tscn`): +100 bis maximal 200 Leben, danach Abbau um 1 pro Sekunde (`HealthComponent.mega_heal`). Respawn nach 35 s. HP-Zahl wird bei Überheilung blau.
- **HUD:** große Ansage „QUAD DAMAGE!“ / „MEGA HEALTH“, Quad-Countdown über der Leiste (blinkt in den letzten 3 s), violetter Bildrand im CRT-Overlay.
- **Bots sammeln Items ein** (Leben, Rüstung, Power-ups; Munition nicht) und **steuern lohnende Items gezielt an**: Wert geteilt durch Entfernung, Power-ups vor Leben, Leben nur bei Bedarf.
- **Neon Foundry:** Quad Damage auf der Mittelplattform, Mega Health auf dem Südwest-Turm, Rüstung auf dem Nordost-Turm.
- Tests: Neon-Foundry-Test auf 21 Prüfungen erweitert (Quad einsammeln, Schaden ×3, Mega Health über 100 und Abbau, Bot holt sich das Quad). Rauchtest 38/38.

---

# Änderungen (Runde 11: Arena „Neon Foundry“)

- **Neue Arena „Neon Foundry“** (`levels/neon_foundry.tscn`), 64 × 64 m auf drei Ebenen:
  - Boden mit vier Deckungsblöcken und zwei Durchgangswänden mit Tür (x = ±18)
  - Ring-Steg auf 4 m entlang aller Wände mit Geländer und gelben Leuchtstreifen
  - Mittelplattform auf vier Säulen mit Brücken nach Ost und West
  - Türme auf 8 m in Nordost und Südwest mit pinken Leuchtkanten
  - Vier Treppen Boden → Ring, zwei Treppen Ring → Turm
  - Drei Jump-Pads (zu beiden Türmen und auf die Mittelplattform), 10 Items, 8 Spawnpunkte, Akzentlichter, lila Himmel
- **Map-Werkzeuge** in `tools/`: Generator für die `.map`-Datei, Generator für die Level-Vorlage, `build_level.gd` zum Einbacken der Geometrie mit func_godot, Generator für Map-Materialien und TrenchBroom-Vorschaubilder.
- **Treppen:** sichtbare Stufen ohne Kollision plus unsichtbare Rampe (`clip`), dadurch für Spieler und Bots begehbar.
- **Arena-Auswahl** im Match-Fenster (Neon Foundry als Standard, Testarena), wird gespeichert.
- **Neuer Test** `tests/neon_foundry_test.gd` (16 Prüfungen): alle Treppen, Brücke, Tür, beide Jump-Pad-Arten, Bot-Wege auf Ring, Mitte und beide Türme, ein Bot läuft tatsächlich auf einen Turm (er nimmt dabei selbst das Jump-Pad). Alle bestanden. Rauchtest weiterhin 38/38.

---

# Änderungen (Runde 10: Look „Neon-Brutalism“)

Mischung aus Low-Poly (Bild 2) und Wireframe (Bild 4): dunkle Körper mit Neonkanten.

- **Neon-Kanten** (`assets/shaders/neon_edges.gdshader`, `scenes/effects/neon_edges.tscn` an der Spielerkamera): Kanten werden aus Tiefen- und Normalensprüngen erkannt und leuchten im Farbton der Fläche. Wirkt automatisch auf Arena, Bots und Waffen.
- **Neue Palette:** Boden dunkles Petrol, Wände dunkler Schiefer mit grünem Stich, Plattformen dunkles Orange, Säulen Petrol. Die Raster sind nur noch dezent, die Kanten bestimmen das Bild.
- **Bots** sind dunkel in ihrer Farbe getönt, dadurch leuchten auch ihre Kanten in Bot-Farbe.
- **CRT-Look** (`assets/shaders/crt_overlay.gdshader`): Farbsaum zum Rand, Vignette, feine Scanlines, leichtes Rauschen. Bei Treffern pulsiert ein roter Rand, das Spielerbild im HUD zuckt rot.
- **Würfel-Explosion:** Bots zerplatzen beim Tod in 48 leuchtende Würfel ihrer Farbe, die über den Boden springen (`scenes/effects/voxel_burst.tscn`).
- **Leuchtspuren** für MG, Shotgun (pro Kugel) und Bot-Schüsse in Bot-Farbe (`scenes/effects/tracer.tscn`).
- **Neues HUD:** Panel-Leiste unten mit HP- und Rüstungsbalken, Spielerbild, Munitionsbalken (orange bei wenig Munition), Waffenname und Slots 1–4. Die Tastenhilfe blendet nach 8 s aus.
- **Fehler behoben:** Ein Bot, der nach einem Jump-Pad starb, blieb nach dem Respawn im Flugmodus hängen. Und: „material is null“ beim Szenenwechsel oder Beenden während eines Trefferblitzes. Ursache war das Blitz-Material der Bots. Dazu neu `GameManager.quit_game()` für sauberes Beenden.
- **Rauchtest stabiler:** Bots bleiben bis zum Bot-gegen-Bot-Test eingefroren (vorher töteten sie auf „Gott“ manchmal den Spieler mitten im Jump-Pad-Test). 3 × 38/38 bestanden.

---

# Änderungen (Runde 9: func_godot)

- **func_godot 2025.12** installiert (`addons/func_godot/`, MIT-Lizenz, Quelle: github.com/func-godot/func_godot_plugin) und in den Projekteinstellungen aktiviert. Nur GDScript, keine Binärdateien.
- Funktionstest: Eine selbst erzeugte `.map`-Datei mit zwei Blöcken wird zu Mesh und Kollisionsformen gebaut (8 m × 8 m Boden, korrekter Maßstab).
- Rauchtest weiterhin 38/38.

---

# Änderungen (Runde 8: Grafik ohne externe Assets)

Alles prozedural in Godot gebaut, keine Downloads.

- **Bots als Roboter** statt Kapseln: Kopf mit Visier, Rumpf mit Brustlicht, Schulterpanzer, Arme, Beine, Rucksack. Jeder Bot hat eine eigene **Leuchtfarbe** (Brightskins wie in Quake 3), damit man ihn auf Distanz erkennt. Der Trefferblitz färbt jetzt das ganze Modell weiß.
- **Waffen in der Hand richtig beleuchtet:** Sie liegen auf einem eigenen Render-Layer mit eigenem Licht, das nur sie aufhellt. Weniger Metallik, damit sie nicht nur schwarzen Himmel spiegeln. Das Rohr des Raketenwerfers ist kürzer und ragt nicht mehr hinter die Kamera.
- **Sternenhimmel-Shader** (`assets/shaders/space_sky.gdshader`): Farbverlauf, glühender Horizont, Nebelband, funkelnde Sterne in unterschiedlicher Größe und Farbe.
- **Arena:** Plattformen und Rampen mit orangem Raster, Säulen mit feinem cyanfarbenem Raster und Leuchtringen. Die hohe Plattform hat vier Stützen, der Turm eine Säule (vorher schwebten beide).
- **Einschusslöcher** (Decals) mit glühendem Rand, der abkühlt. Bleiben 6 s, maximal 60 gleichzeitig.
- Rauchtest: 38/38 bestanden. Dauerlauf mit 7 Bots und echtem Renderer: keine Fehler. Im Headless-Modus meldet der Dummy-Renderer gelegentlich „material is null“; das betrifft nur Tests ohne Grafik.

---

# Änderungen (Runde 7: Bot-Anzahl und Schwierigkeit)

- **Match-Fenster** nach „Spiel starten“: Anzahl Bots (1–7) und Schwierigkeit (Anfänger, Normal, Erfahren, Profi, Gott). Wird gespeichert.
- **Schwierigkeitsstufen** (`Bot.SKILL_PRESETS`): Streuung, Reaktionszeit, Feuerrate, Ausweichtempo, Sichtweite. Neu ist die **Reaktionszeit**: Bots schießen erst eine Weile, nachdem sie ein neues Ziel entdeckt haben.
- **Jeder gegen jeden:** Bots suchen sich den nächsten sichtbaren Gegner (Spieler oder Bot), behalten ein Ziel und rächen sich am Angreifer. Bot-Schüsse treffen jeden, der im Weg steht.
- **Arena erzeugt die Bots** selbst (`arena.gd`) mit Namen (Vex, Kortex, Rhea, Nyx, Talon, Orbit, Grimm). Vier zusätzliche Spawnpunkte (jetzt 8).
- **Bessere Spawns:** `GameManager.get_spawn_transform()` wählt einen der zwei Spawnpunkte, die am weitesten von allen lebenden Gegnern entfernt sind.
- **Speicherleck beim Beenden behoben:** Der Sound-Cache wird beim Beenden geleert.
- **Rauchtest** auf 38 Prüfungen erweitert (Bot-Anzahl, Schwierigkeit, Namen, Spawn-Abstand, Bots kämpfen gegeneinander). Der Test stellt die echten Einstellungen am Ende wieder her. Alle bestanden.
- Dauerlauf mit 7 Bots über 60 s: Anfänger ca. 4 Abschüsse, Gott ca. 32 Abschüsse. Keine Fehler.

---

# Änderungen (Runde 6: Quick Wins)

- **Neuer Look:** AgX-Tonemapping, SSAO, stärkerer Bloom, volumetrischer Nebel, dunklerer Nachthimmel, Schatten. Neuer Shader `assets/shaders/arena_grid.gdshader` legt ein leuchtendes Raster in Weltkoordinaten auf Boden (cyan) und Wände (orange). Dazu Neon-Leisten am Fuß der Wände und farbige Akzentlichter.
- **Jump-Pads** (`scenes/items/jump_pad.tscn`): Die Startgeschwindigkeit wird aus Ziel, Scheitelhöhe und Schwerkraft berechnet, man landet also immer am Ziel. Ein `NavigationLink3D` lässt Bots das Pad als Weg nutzen. Zwei Pads in der Arena: eins auf einen neuen Turm mit Rüstung, eins auf die hohe Plattform.
- **Killfeed** oben rechts (eigene Abschüsse grün, eigene Tode rot) und **Scoreboard** auf Tab. `GameManager.register_kill()` führt eine Punktetabelle für alle Teilnehmer; Selbstmord kostet wie in Quake einen Frag. Bots haben Namen (Vex, Kortex).
- **FOV-Regler** im Einstellungsmenü (75–120°, horizontal, Standard 100°), wird gespeichert.
- **Shotgun** als neue Waffe 2 (Quake-Reihenfolge: 1 MG, 2 Shotgun, 3 Raketenwerfer, 4 Railgun). 11 Kugeln mit 9 Schaden, gleichmäßige Streuung, Treffer werden pro Ziel zu einer Schadenszahl zusammengefasst. Eigener Sound.
- Tastenhilfe im HUD kleiner, damit sie die Munitionsanzeige nicht überdeckt.
- **Rauchtest** auf 35 Prüfungen erweitert (Shotgun, Killfeed, Scoreboard, FOV, Jump-Pad-Landung). Alle bestanden.

Nicht automatisch geprüft: ob Bots die Jump-Pads in der Praxis nutzen, und wie sich alles mit Maus und Tastatur anfühlt.

---

# Änderungen (Runde 5: Roadmap Phase 0, Teil 2)

- **Waffen als Daten (0.6):** Neue Resource `WeaponData` (`scripts/weapons/weapon_data.gd`), Werte in `resources/weapons/*.tres`. `WeaponBase` liest Name, Schaden, Cooldown, Munition und Rückstoß daraus. Eine neue Waffe braucht nur noch eine `.tres` und eine Szene.
- **Pickups ohne feste Indizes:** Typen sind jetzt `AMMO_BOX`, `WEAPON_AMMO` (mit `weapon_id`), `HEALTH`, `ARMOR`. Die Munitionskiste gibt jeder Waffe ihre `ammo_box_amount` und bleibt liegen, wenn alles voll ist.
- **HealthComponent (0.7):** Leben, Rüstung, Rüstungsabzug und Tod für Spieler und Bots in einer gemeinsamen Komponente (`scripts/components/health_component.gd`) mit den Signalen `changed`, `damaged`, `died`. Bots geben nur noch einen Frag, wenn der Spieler sie getötet hat.
- **HUD als eigene Szene (0.7):** `scenes/ui/hud.tscn` mit `scripts/ui/hud.gd`. Das HUD hängt sich an die Signale des Spielers. `player.gd` schrumpft von 527 auf ca. 350 Zeilen und enthält nur noch Bewegung, Schaden, Tod und Respawn.
- **Pause-Menü als Szene (0.9):** `scenes/ui/pause_menu.tscn` statt per Code gebaut, mit Tastaturfokus auf „Weiterspielen“.
- **Fehler behoben:** Wenn ein Treffer den Bot tötete, überschrieb der Treffer-Sound den Todes-Sound. Das Todes-Overlay erscheint jetzt sofort, auch wenn im selben Frame pausiert wird.
- **Rauchtest erweitert** auf 27 Prüfungen (Munitionskiste, HUD-Anzeige, Pause-Menü, Todes-Overlay). Alle bestanden.

---

# Änderungen (Runde 4: erster Test in Godot 4.7.2)

Erstmals mit echter Engine geprüft (headless, Godot 4.7.2).

- **Alle Skripte kompilieren**, die Arena läuft ohne Skriptfehler.
- **Neuer Rauchtest** `tests/smoke_test.gd` (20 Prüfungen, alle bestanden): MG-Feuerrate, Treffer, Railgun-Kill, Frags, Rocket-Jump mit Eigenschaden, Health-Pickup, Tod durch Bot, Bot-Frag, Respawn wartet in der Pause, Start-Rüstung, Einstellungen speichern, Sound-Cache.
- **Fehler behoben: Einstellungs-Menü war wirkungslos.** Die Pfade zu den Reglern in `main_menu.gd` fehlten den Knoten `HBox`. Mausempfindlichkeit und Lautstärke ließen sich deshalb nie ändern.
- **Navmesh-Warnungen behoben:** Das Navmesh wird aus Kollisionsformen statt aus sichtbaren Meshes gebacken (schneller, blockiert die GPU nicht). Agentengröße passt jetzt zum Zellraster (Radius 0,5, Höhe 1,75).

Noch nicht geprüft: wie es sich mit Maus und Tastatur anfühlt (120-Hz-Physik, Strafe-Jumping). Das geht nur im echten Spiel.

---

# Änderungen (Runde 3: Roadmap Phase 0, Teil 1)

Entscheidung: zuerst nur Bots, LAN eventuell später (siehe `ROADMAP.md`, Phase 8).

- **Physik:** 120 Physik-Ticks pro Sekunde und Jolt Physics als 3D-Engine (`project.godot`). Physik-Interpolation ist noch aus, weil die Mausdrehung am Körper sonst einen Tick verzögert wirken kann. Das muss in der Engine getestet werden.
- **Kollisions-Layer** heißen jetzt World, Player, Bot, Pickup. Neue Klasse `Layers` (`scripts/layers.gd`) mit Bitmasken. Alle Raycasts nutzen sie statt `0xFFFFFFFF`.
- **Explosionen:** Nur noch Wände blockieren den Flächenschaden, andere Figuren schirmen nicht mehr ab.
- **`DamageInfo`** (`scripts/damage_info.gd`): `take_damage(info)` bekommt jetzt ein Objekt mit Menge, Angreifer, Trefferpunkt, Richtung, Waffenname und `is_splash`. Grundlage für Killfeed, Ansager und LAN.

Nicht getestet: Es ist weiterhin keine Godot-Engine verfügbar.

---

# Änderungen (Verbesserungsrunde 2)

## Fehler behoben
- **Spieler-Skript ließ sich vermutlich nicht kompilieren:** `Input.is_key_just_pressed` gibt es in Godot 4 nicht. Alle festen Tastenabfragen (`is_key_pressed(KEY_W)` usw.) wurden entfernt, die Eingabe läuft nur noch über die InputMap (`player.gd`, `weapon_manager.gd`).
- **Verzerrte Sounds:** `FORMAT_8_BITS` erwartet vorzeichenbehaftete Samples. Der Generator schrieb `128 + Wert`, dadurch lag Stille bei -128. Jetzt wird korrekt umgerechnet (`sound_generator.gd`, `_to_s8`).
- **Pickups blockierten Schüsse und Raketen:** Raycasts trafen die `Area3D` der Items. Jetzt `collide_with_areas = false` bei MG, Railgun, Rakete und Explosion.
- **Respawn-Timer liefen in der Pause weiter:** Alle `create_timer` pausieren jetzt mit dem Spiel. Der Spieler-Respawn läuft über denselben Countdown wie die Anzeige.
- **Explosionen wirkten durch Wände:** Vor Schaden und Rückstoß gibt es jetzt einen Sichtlinien-Test. Körper mit mehreren Kollisionsformen bekommen nur einmal Schaden. Der Rückstoß wird nicht mehr doppelt angewendet.
- **Bot referenzierte `$HeadMesh`,** den es in `bot.tscn` nicht gibt. Referenz entfernt.
- **Ein Mausklick auf „Weiterspielen“ löste sofort einen Schuss aus.** Nach dem Fortsetzen wird erst wieder geschossen, wenn die Maustaste losgelassen wurde.

## Spiel-Design
- **Bot-Patrouille:** Ziele kommen jetzt per `NavigationServer3D.map_get_random_point` vom Navmesh (nicht mehr aus Säulen oder außerhalb der Arena). Die Distanz wird horizontal gemessen, nach 12 s ohne Ankunft wird ein neues Ziel gewählt.
- **Bot-Strafen:** Die Dauer bis zum Richtungswechsel wird einmal ausgewürfelt statt jeden Frame neu.
- **Feuerrate unabhängig von der Framerate:** Der Cooldown nimmt den Rest des letzten Frames mit. Das MG schießt jetzt wirklich 11 statt 10 Schuss/s.
- **Waffenwerte in den Szenen:** Schaden, Cooldown und Munition stehen in den `.tscn`-Dateien und lassen sich im Inspector ändern (vorher in `_ready()` überschrieben).
- **Spieler kollidiert mit Bots** (`collision_mask` 1 → 5).
- **Bot-Frags werden gezählt:** `take_damage` hat einen optionalen Parameter `attacker`. Stirbt der Spieler durch einen Bot, steigt `bot_frags`.
- **Respawn:** Der Blick zeigt wieder geradeaus. Die Start-Rüstung ist als `start_armor` einstellbar.
- **Tastatur:** InputMap nutzt physische Tasten (AZERTY-tauglich).

## Aufräumen
- `SoundGenerator` cached jeden Sound. Explosion und Leerklick berechneten die Wellenform vorher bei jedem Aufruf neu.
- Überflüssige `if GameManager:`-Prüfungen und AudioPlayer-Fallbacks entfernt.
- Einstellungen (Empfindlichkeit, Lautstärke) werden in `user://settings.cfg` gespeichert und beim Start geladen.
- `.gitignore` angelegt, README-Projektstruktur korrigiert.

## Noch offen
- Nicht getestet: Auch in dieser Runde war keine Godot-Engine verfügbar. Bitte starten und die Konsole auf Fehler prüfen.
- Raketen-Direkttreffer + Explosion ergeben weiterhin bis ca. 150 Schaden (Designfrage).

---

# Änderungen (Verbesserungsrunde 1)

## Fehler behoben
- **Tote Spieler konnten sich bewegen und schießen.** `is_dead` wurde nirgends geprüft. Jetzt gibt es in `player.gd` einen Todeszustand ohne Eingabe, und `weapon_manager.gd` verhindert das Schießen.
- **Bots liefen geradeaus in Wände.** Das Navigationsnetz in `test_arena.tscn` war nie gebacken. `arena.gd` backt es jetzt beim Start. Alternativ kannst du es im Editor einmal per "Bake NavigationMesh" am NavigationRegion3D erzeugen.
- **ESC hat nur die Maus freigegeben, das Spiel lief weiter.** Jetzt pausiert ESC das Spiel (`game_manager.gd`), ein Mausklick setzt es fort. Es gibt ein Pause-Overlay.
- **Funken bei Treffern auf dem Boden:** Die Normale zeigte nach oben, parallel zum Up-Vektor von `look_at`. Das führte zu einer Fehlermeldung. Jetzt wird bei Bodentreffern ein anderer Up-Vektor verwendet (`machine_gun.gd`, `railgun.gd`).

## Optimierung
- **Bots erzeugten bei jedem Schuss und jedem Treffer neue Sounds** (Wellenform wurde neu berechnet) und ein neues Material. Das passiert jetzt einmal beim Start des Bots (`bot.gd`).

## Noch offen (Ideen für die nächste Runde)
- Hauptmenü mit Start, Einstellungen und Beenden (im Prompt gefordert, noch nicht umgesetzt).
- Anzeige "Du bist tot, Respawn in 3 Sekunden" im HUD.
- Raketen-Direkttreffer und Explosion addieren sich (bis ca. 150 Schaden gegen Bots). Das ist eine Designfrage.
- `is_jump_just_pressed()` nutzt zusätzlich `is_key_pressed`, das ist "gehalten" statt "gerade gedrückt". Das macht Bunnyhop bewusst oder unbewusst leichter.
- Nicht getestet: Ich hatte in der Umgebung keine Godot-Engine. Bitte einmal starten und die Konsole auf Fehler prüfen.
