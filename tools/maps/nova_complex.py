"""Nova Complex: grosse Anlage fuer bis zu 16 Spieler, ca. 150 x 110 m, sechs Bereiche auf drei Ebenen.

Mitte: Platz mit Turmblock (y=8, Mega Health, zwei Jump-Pads). Westen: Halle mit Galerie (y=6, Raketenwerfer).
Osten: drei Plattformen (y=6 / y=11 / y=6, Railgun oben). Norden: Grube (y=-4) mit Energie-Strom, zwei Bruecken,
Quad und Shock Rifle. Sueden: Containerhof mit Laufsteg an der Aussenwand (y=5, Lightning Gun).
Zwei Teleporter verbinden die Ecken. Spawns blicken zur Mitte.
Aufruf aus dem Projektordner:  python tools/maps/nova_complex.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapkit import MapKit, FLOOR, WALL, WALK, METAL, ACCENT, CYAN, MAGENTA, YELLOW, ORANGE  # noqa: E402

kit = MapKit('nova_complex', 'NovaComplex', sky=((0.03, 0.09, 0.1), (0.2, 1, 0.7), (0.2, 0.75, 0.6)), fog=0.008)
AX, AZ = 75, 55               # halbe Aussenmasse
PX0, PX1, PZ0, PZ1 = -30, 30, -50, -30   # Grube im Norden
H_WALL = 20

# --- Boden (5 m dick, bildet die Grubenwaende), Grube mit Energie-Strom ---
kit.solid(-AX, -5, PZ1, AX, 0, AZ, FLOOR)
kit.solid(-AX, -5, -AZ, PX0, 0, PZ1, FLOOR)
kit.solid(PX1, -5, -AZ, AX, 0, PZ1, FLOOR)
kit.solid(PX0, -5, -AZ, PX1, 0, PZ0, FLOOR)
kit.solid(PX0, -6, PZ0, PX1, -4, PZ1, FLOOR)
kit.glow_edge(PX0, PZ0, PX1, PZ1, 0, YELLOW)
kit.damage_zone(-22, -4, -42, 22, -2.8, -38, 30.0)         # Strom quer durch die Grube, an den Enden begehbar
kit.stairs(PX0, PX0 + 6, -36, -32, -4, 4, '-x')
kit.stairs(PX1 - 6, PX1, -36, -32, -4, 4, '+x')
for x in (-15, 15):
    kit.platform(x - 1.5, PZ0, x + 1.5, PZ1, 0, WALK, glow=CYAN)
kit.light(0, -1, -40, (1, 0.8, 0.2), 4.0, 22)

# --- Aussenwaende mit Leuchtstreifen ---
kit.wall(-AX - 1, -AZ - 1, AX + 1, -AZ, -5, H_WALL)
kit.wall(-AX - 1, AZ, AX + 1, AZ + 1, -5, H_WALL)
kit.wall(-AX - 1, -AZ, -AX, AZ, -5, H_WALL)
kit.wall(AX, -AZ, AX + 1, AZ, -5, H_WALL)
for i, x in enumerate(range(-60, 61, 15)):
    tex = CYAN if i % 2 else MAGENTA
    kit.deco(x - 0.1, 0, -AZ, x + 0.1, H_WALL - 2, -AZ + 0.05, tex)
    kit.deco(x - 0.1, 0, AZ - 0.05, x + 0.1, H_WALL - 2, AZ, tex)

# --- Mitte: Platz mit Turmblock (y=8) ---
kit.solid(-6, 0, -6, 6, 8, 6, ACCENT)
kit.glow_edge(-6, -6, 6, 6, 8, MAGENTA)
kit.pad(0, 0, -11, 0, 8, -2.5, apex=2.0)
kit.pad(0, 0, 11, 0, 8, 2.5, apex=2.0)
kit.item('mega', 0, 8, 0)
kit.light(0, 12, 0, (1, 0.25, 0.8), 3.5, 18)
for x, z in ((-16, -12), (16, -12), (-16, 12), (16, 12)):
    kit.solid(x - 1.5, 0, z - 1.5, x + 1.5, 2.2, z + 1.5, METAL)
    kit.deco(x - 1.52, 2.1, z - 1.52, x + 1.52, 2.22, z + 1.52, ORANGE)
# Halbhohe Mauern zwischen Platz und Westgasse bzw. Ostbereich, Luecke in der Mitte
for x in (-32, 36):
    kit.wall(x - 0.25, -20, x + 0.25, -6, 0, 3, METAL)
    kit.wall(x - 0.25, 6, x + 0.25, 20, 0, 3, METAL)
    kit.deco(x - 0.27, 2.9, -20, x + 0.27, 3.02, -6, CYAN)
    kit.deco(x - 0.27, 2.9, 6, x + 0.27, 3.02, 20, CYAN)

# --- Westen: Halle mit Galerie (y=6) an der Westwand ---
kit.room(-AX, -24, -42, 24, 0, 14, doors=[('o', -4, 4), ('n', -60, -54), ('s', -60, -54)])
kit.platform(-AX, -24, -60, 24, 6, WALK, glow=CYAN)
kit.stairs(-60, -52, -22, -18, 0, 6, '-x')
kit.stairs(-60, -52, 18, 22, 0, 6, '-x')
kit.rail(-60, -18, -60, 18, 6)
for z in (-12, 0, 12):
    kit.pillar(-60.6, z, 0, 5.5, w=1.0)
kit.light(-58, 10, 0, (0.3, 0.9, 1), 3.0, 18)

# --- Osten: Plattformen A (Nord, y=6), B (hoch, y=11), C (Sued, y=6) ---
kit.platform(44, -32, 60, -14, 6, ACCENT, glow=YELLOW)
kit.platform(44, 14, 60, 32, 6, ACCENT, glow=YELLOW)
kit.platform(58, -8, 72, 8, 11, ACCENT, glow=MAGENTA, thick=1.0)
kit.stairs(50, 54, -14, -6, 0, 6, '-z')
kit.stairs(50, 54, 6, 14, 0, 6, '+z')
for x, z, top in ((45, -31, 5.5), (59, -31, 5.5), (45, -15, 5.5), (59, -15, 5.5),
                  (45, 15, 5.5), (59, 15, 5.5), (45, 31, 5.5), (59, 31, 5.5),
                  (59, -7, 10), (71, -7, 10), (59, 7, 10), (71, 7, 10)):
    kit.pillar(x, z, 0, top, w=1.0)
kit.pad(49, 0, 0, 64, 11, 0, apex=2.5)                     # Boden -> B
kit.pad(57, 6, -18, 63, 11, -5, apex=2.0)                  # A -> B
kit.pad(57, 6, 18, 63, 11, 5, apex=2.0)                    # C -> B
kit.light(65, 14, 0, (0.3, 1, 0.8), 3.0, 14)
kit.light(52, 9, -23, (1, 0.8, 0.2), 2.5, 12)
kit.light(52, 9, 23, (1, 0.8, 0.2), 2.5, 12)

# --- Sueden: Containerhof, Laufsteg y=5 an der Aussenwand ---
for x, z, along_x in ((-26, 39, True), (-12, 46, False), (2, 38, True), (16, 45, False), (30, 38, True),
                      (-20, 29, True), (24, 29, True)):
    hx, hz = (3, 1.25) if along_x else (1.25, 3)
    kit.solid(x - hx, 0, z - hz, x + hx, 3, z + hz, METAL)
    kit.deco(x - hx - 0.02, 2.9, z - hz - 0.02, x + hx + 0.02, 3.02, z + hz + 0.02, ORANGE)
kit.platform(-38, 50, 40, AZ, 5, WALK, glow=CYAN)
kit.stairs(-36, -32, 43, 50, 0, 5, '+z')
kit.stairs(34, 38, 43, 50, 0, 5, '+z')
kit.rail(-32, 50, 34, 50, 5)
kit.light(0, 7, 40, (1, 0.55, 0.15), 3.0, 20)

# --- Teleporter: Grube Nordwest -> Suedost, Nordost -> Suedwest ---
kit.tele(-26, -4, -46, 66, 0, 46, 90)
kit.tele(68, 0, -48, -66, 0, 42, -90)

# --- Waffen und Items ---
kit.weapon('rocket_launcher', 0, 0, 24)
kit.weapon('plasma', -37, 0, 0)
kit.weapon('plasma', 26, 0, -18)
kit.weapon('rocket_launcher', -68, 6, 0)
kit.weapon('railgun', 66, 11, 0)
kit.weapon('shock_rifle', -18, -4, -46)
kit.weapon('lightning', 0, 5, 52.5)
kit.item('quad', 0, -4, -46)
kit.item('armor', 52, 6, -23)
kit.item('armor', -68, 6, -18)
for x, y, z in ((-50, 0, -14), (-50, 0, 14), (47, 0, 0), (-24, 0, -26), (20, 0, -26), (0, 0, 34), (-30, 0, 46), (40, 0, 46)):
    kit.item('health', x, y, z)
for x, y, z in ((-58, 0, 0), (40, 0, -46), (-40, 0, -46), (10, -4, -34), (-8, 0, 48), (60, 0, 40)):
    kit.item('ammo', x, y, z)

# --- Spawns: ueber alle Bereiche verteilt, Blick zur Mitte (yaw 0 = Norden, 90 = Westen) ---
for x, y, z in ((-66, 6, -12), (-66, 6, 12), (-48, 0, -18), (-48, 0, 18),
                (52, 6, -27), (52, 6, 27), (69, 0, -40), (69, 0, 38),
                (-52, 0, -45), (52, 0, -45), (0, 0, -53),
                (-28, 0, 33), (28, 0, 33), (0, 5, 53), (-62, 0, 45), (62, 0, 34)):
    kit.spawn(x, y, z, math.degrees(math.atan2(x, z)))

# --- Hall, Nebel, zerstoerbare Objekte ---
kit.reverb(PX0, -6, PZ0, PX1, 4, PZ1, 'halle')
kit.fog_volume(PX0, -5, PZ0, PX1, -1.5, PZ1, (1, 0.7, 0.3), 0.06, 0.3)
kit.fog_volume(-38, 0, 26, 40, 1.2, 50, (0.3, 1, 0.7), 0.05)
for x, z in ((-9, -9), (9, 9)):
    kit.barrel(x, 0, z)
kit.barrel(-18, -4, -32)
for x, z, yaw in ((-8, 31, 0), (-6.8, 31.4, 25), (10, 50, -10), (36, 31, 15), (-36, 36, 0)):
    kit.crate(x, 0, z, yaw)
kit.glass(43.96, 7, -30, 44.04, 9, -16)
kit.glass(43.96, 7, 16, 44.04, 9, 30)

kit.write()
