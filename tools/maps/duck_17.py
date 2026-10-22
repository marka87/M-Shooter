"""Duck 17: Industriehalle mit Schlammgrube (Vorbild UT99 DM-Deck16][), ca. 100 x 70 m, vier Ebenen.

Boden (y=0) mit Grube voller Energie-Schlamm (Schaden) und Steg darueber, Laufstege an den Laengswaenden
(y=6, Treppen und Jump-Pads), Sniper-Balkone an den Stirnwaenden (y=12) und eine Hochbruecke (y=16)
mit Mega Health quer durch die Halle. Statt Aufzuegen Jump-Pads.
Aufruf aus dem Projektordner:  python tools/maps/duck_17.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapkit import MapKit, FLOOR, WALL, WALK, METAL, ACCENT, CYAN, MAGENTA, YELLOW, ORANGE  # noqa: E402

kit = MapKit('duck_17', 'Duck17', sky=((0.12, 0.1, 0.05), (1, 0.6, 0.2), (0.9, 0.5, 0.2)), fog=0.016)
AX, AZ = 50, 35          # halbe Hallenmasse
PX, PZ = 14, 9           # halbe Grubenmasse
H_WALL, H_WALK, H_BALC, H_BRIDGE = 26, 6, 12, 16

# --- Boden um die Grube, Grube mit Schlamm ---
kit.solid(-AX, -1, -AZ, AX, 0, -PZ, FLOOR)
kit.solid(-AX, -1, PZ, AX, 0, AZ, FLOOR)
kit.solid(-AX, -1, -PZ, -PX, 0, PZ, FLOOR)
kit.solid(PX, -1, -PZ, AX, 0, PZ, FLOOR)
kit.solid(-PX, -5, -PZ, PX, -4, PZ, FLOOR)                 # Grubenboden
kit.damage_zone(-PX, -4, -PZ, PX, -2.6, PZ, 25.0)          # Schlamm bis 1,4 m hoch
kit.glow_edge(-PX, -PZ, PX, PZ, 0, YELLOW)
kit.light(0, -1, 0, (1, 0.85, 0.2), 4.0, 18)
# Steg ueber die Grube (Nord-Sued) und Treppen aus der Grube an beiden Enden
kit.platform(-1.5, -PZ, 1.5, PZ, 0, WALK, glow=CYAN)
kit.stairs(-PX, -PX + 6, -2, 2, -4, 4, '-x')
kit.stairs(PX - 6, PX, -2, 2, -4, 4, '+x')

# --- Aussenwaende mit Leuchtstreifen ---
kit.wall(-AX - 1, -AZ - 1, AX + 1, -AZ, -1, H_WALL)
kit.wall(-AX - 1, AZ, AX + 1, AZ + 1, -1, H_WALL)
kit.wall(-AX - 1, -AZ, -AX, AZ, -1, H_WALL)
kit.wall(AX, -AZ, AX + 1, AZ, -1, H_WALL)
for i, x in enumerate(range(-40, 41, 10)):
    tex = ORANGE if i % 2 else CYAN
    kit.deco(x - 0.1, 0, -AZ, x + 0.1, H_WALL - 2, -AZ + 0.05, tex)
    kit.deco(x - 0.1, 0, AZ - 0.05, x + 0.1, H_WALL - 2, AZ, tex)

# --- Laufstege y=6 an den Laengswaenden, Treppe hinauf, Stuetzen ---
for sz in (-1, 1):
    z_wall, z_edge = sz * AZ, sz * (AZ - 6)
    kit.platform(-AX, min(z_wall, z_edge), AX, max(z_wall, z_edge), H_WALK, WALK)
    kit.rail(-AX + 14, z_edge, AX - 14, z_edge, H_WALK)
    kit.deco(-AX, H_WALK - 0.6, z_edge - 0.05, AX, H_WALK - 0.5, z_edge + 0.05, YELLOW)
    for x in range(-40, 41, 16):
        kit.pillar(x, z_edge - sz * 0.6, 0, H_WALK - 0.5, w=1.0)
    # Treppe vom Boden, an der Kante entlang nach Westen bzw. Osten
    zs = sorted((z_edge, z_edge - sz * 3))
    if sz < 0:
        kit.stairs(-AX + 2, -AX + 14, zs[0], zs[1], 0, H_WALK, '-x')
    else:
        kit.stairs(AX - 14, AX - 2, zs[0], zs[1], 0, H_WALK, '+x')
    kit.pad(sz * 20, 0, sz * 22, sz * 20, H_WALK, sz * 31, apex=2.0)   # Boden -> Laufsteg
    kit.light(0, H_WALK + 3, sz * 32, (1, 0.6, 0.2), 2.5, 16)

# --- Sniper-Balkone y=12 an den Stirnwaenden ---
for sx in (-1, 1):
    x_wall, x_edge = sx * AX, sx * (AX - 8)
    kit.platform(min(x_wall, x_edge), -20, max(x_wall, x_edge), 20, H_BALC, ACCENT, glow=MAGENTA, thick=1.0)
    kit.rail(x_edge, -20, x_edge, -3, H_BALC)
    kit.rail(x_edge, 3, x_edge, 20, H_BALC)
    kit.pillar(x_edge - sx * 0.6, -18, 0, H_BALC - 1, w=1.4)
    kit.pillar(x_edge - sx * 0.6, 18, 0, H_BALC - 1, w=1.4)
    kit.pad(sx * 38, 0, 0, sx * 46, H_BALC, 0, apex=2.5)                      # Boden -> Balkon
    kit.pad(sx * 40, H_WALK, -32, sx * 46, H_BALC, -15, apex=2.0)             # Laufsteg Nord -> Balkon
    kit.pad(sx * 46, H_BALC, 12, sx * 36, H_BRIDGE, 0, apex=2.0)              # Balkon -> Hochbruecke
    kit.light(sx * 46, H_BALC + 3, 0, (1, 0.25, 0.8), 3.0, 14)

# --- Hochbruecke y=16 quer durch die Halle, Mitte mit Mega Health ---
kit.platform(-(AX - 8), -1.5, AX - 8, 1.5, H_BRIDGE, WALK, glow=CYAN)
kit.platform(-4, -4, 4, 4, H_BRIDGE, ACCENT, glow=MAGENTA)
for x in (-24, 24):
    kit.pillar(x, 0, 0, H_BRIDGE - 0.5, w=2.0, glow=CYAN)
kit.item('mega', 0, H_BRIDGE, 0)
kit.light(0, H_BRIDGE + 3, 0, (1, 0.25, 0.8), 3.0, 12)

# --- Deckung am Boden ---
for x, z in ((-28, -14), (28, 14), (-28, 14), (28, -14), (-20, 0), (20, 0)):
    kit.solid(x - 1.5, 0, z - 1.5, x + 1.5, 2.2, z + 1.5, METAL)
    kit.deco(x - 1.52, 2.1, z - 1.52, x + 1.52, 2.22, z + 1.52, ORANGE)

# --- Teleporter: Boden-Ecken -> gegenueberliegender Balkon ---
kit.tele(-44, 0, 26, 46, H_BALC, -8, 90)
kit.tele(44, 0, -26, -46, H_BALC, 8, -90)

# --- Waffen und Items ---
kit.weapon('railgun', -47, H_BALC, -10)
kit.weapon('shock_rifle', 47, H_BALC, 10)
kit.weapon('rocket_launcher', -32, 0, 0)
kit.weapon('lightning', 32, 0, 0)
kit.weapon('plasma', 0, H_WALK, -32)
kit.weapon('shotgun', 0, H_WALK, 32)
kit.weapon('machine_gun', 0, 0, 0)            # mitten auf dem Steg ueber dem Schlamm
for sx in (-1, 1):
    kit.item('armor', sx * 47, H_BALC, sx * -14)
    kit.item('ammo', sx * 30, H_WALK, -32)
    kit.item('ammo', sx * 30, H_WALK, 32)
    for sz in (-1, 1):
        kit.item('health', sx * 40, 0, sz * 24)

# --- Spawns (Diagonal-Ecken am Boden = CTF-Basen) ---
# Ecken nicht bei z=+-28: dort stehen die Treppen zu den Laufstegen
for x, y, z, yaw in ((-45, 0, -21, -122), (45, 0, 21, 58), (-45, 0, 21, -58), (45, 0, -21, 122),
                     (-10, H_WALK, -32, 180), (10, H_WALK, 32, 0), (25, H_WALK, -32, 180), (-25, H_WALK, 32, 0),
                     (-46, H_BALC, 5, -90), (46, H_BALC, -5, 90), (0, 0, -20, 0), (0, 0, 20, 180),
                     (-20, H_WALK, -32, 180), (20, H_WALK, 32, 0), (-36, 0, -12, -90), (36, 0, 12, 90)):
    kit.spawn(x, y, z, yaw)

kit.write()
