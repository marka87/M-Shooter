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
