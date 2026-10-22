"""Camp Ground: klassische Duell-/FFA-Map (Vorbild Q3DM6 The Campgrounds), ca. 80 x 80 m.

Innenhof mit Mittelsaeule, Laufstege im Norden und Osten (y=5) mit Mega Health auf dem Eckbalkon,
geschlossener Raketen-Raum im Suedwesten, Ruestungs-Raum im Suedosten mit Teleporter auf den Laufsteg,
Korridor mit Deckung im Westen. Treppe und Jump-Pad hinauf.
Aufruf aus dem Projektordner:  python tools/maps/camp_ground.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapkit import MapKit, FLOOR, WALL, WALK, METAL, ACCENT, CYAN, MAGENTA, YELLOW, ORANGE  # noqa: E402

kit = MapKit('camp_ground', 'CampGround', sky=((0.1, 0.08, 0.16), (0.9, 0.4, 0.8), (0.4, 0.3, 0.9)), fog=0.014)
A, H_WALK = 40, 5

# --- Boden und Aussenwaende ---
kit.solid(-A, -1, -A, A, 0, A, FLOOR)
kit.wall(-A - 1, -A - 1, A + 1, -A, -1, 14)
kit.wall(-A - 1, A, A + 1, A + 1, -1, 14)
kit.wall(-A - 1, -A, -A, A, -1, 14)
kit.wall(A, -A, A + 1, A, -1, 14)
for i, p in enumerate(range(-32, 33, 8)):
    tex = MAGENTA if i % 2 else CYAN
    kit.deco(p - 0.08, 0, A - 0.05, p + 0.08, 12, A, tex)
    kit.deco(-A, 0, p - 0.08, -A + 0.05, 12, p + 0.08, tex)

# --- Laufsteg Nord (y=5) und Ost, Eckbalkon mit Mega Health ---
kit.platform(-A, -A, A, -30, H_WALK, WALK)
kit.platform(30, -30, A, A, H_WALK, WALK)
kit.rail(-A, -30, -3, -30, H_WALK)
kit.rail(3, -30, 30, -30, H_WALK)
kit.rail(30, -30, 30, 6, H_WALK)
kit.rail(30, 14, 30, A, H_WALK)
kit.deco(-A, H_WALK - 0.6, -30.05, 30, H_WALK - 0.5, -29.95, YELLOW)
kit.deco(29.95, H_WALK - 0.6, -30, 30.05, H_WALK - 0.5, A, YELLOW)
for x in (-30, -15, 15):
    kit.pillar(x, -30.6, 0, H_WALK - 0.5)
for z in (-15, 0, 15, 30):
    kit.pillar(30.6, z, 0, H_WALK - 0.5)
kit.platform(32, -38, 38, -32, H_WALK + 0.01, ACCENT, glow=MAGENTA, thick=0.01)
kit.item('mega', 35, H_WALK, -35)
kit.light(35, H_WALK + 3, -35, (1, 0.25, 0.8), 3.0, 10)
kit.stairs(-3, 3, -30, -16, 0, H_WALK, '-z')                    # Innenhof -> Laufsteg Nord
kit.pad(14, 0, 10, 35, H_WALK, 10, apex=2.0)                     # Innenhof -> Laufsteg Ost

# --- Innenhof mit Mittelsaeule ---
kit.solid(-2.5, 0, -2.5, 2.5, 3.5, 2.5, ACCENT)
kit.glow_edge(-2.5, -2.5, 2.5, 2.5, 3.5, CYAN)
kit.glow_edge(-16, -16, 16, 16, 0.02, CYAN)
kit.light(0, 6, 0, (0.2, 0.85, 1), 3.0, 16)
kit.item('health', 0, 0, 5)
kit.item('health', 0, 0, -5)

# --- Raketen-Raum Suedwest (Tueren nach Norden und Osten) ---
kit.room(-A, 20, -20, A, 0, H_WALK, doors=[('n', -32, -28), ('o', 28, 32)])
kit.solid(-A, H_WALK - 0.5, 20, -20, H_WALK, A, METAL)          # Decke
kit.weapon('rocket_launcher', -30, 0, 30)
kit.light(-30, 3.5, 30, (1, 0.45, 0.1), 2.5, 10)

# --- Ruestungs-Raum Suedost unter dem Laufsteg (Tueren nach Norden und Westen), Teleporter ---
kit.room(20, 20, 30, A, 0, H_WALK - 0.5, doors=[('n', 23, 27), ('w', 28, 32)])
kit.item('armor', 25, 0, 35)
kit.tele(25, 0, 30, -35, H_WALK, -35, -90)
kit.light(25, 3, 30, (0.2, 0.85, 1), 2.5, 8)

# --- West-Korridor mit Deckung ---
for x, z in ((-33, -20), (-27, -8), (-33, 6)):
    kit.solid(x - 1.5, 0, z - 1.5, x + 1.5, 2.0, z + 1.5, METAL)
    kit.deco(x - 1.52, 1.9, z - 1.52, x + 1.52, 2.02, z + 1.52, ORANGE)
kit.weapon('shotgun', -33, 0, -8)

# --- Weitere Waffen und Items ---
kit.weapon('railgun', 0, H_WALK, -35)
kit.weapon('plasma', -34, H_WALK, -35)
kit.weapon('lightning', 35, H_WALK, 30)
kit.weapon('shock_rifle', 10, 0, -10)
kit.item('ammo', 20, H_WALK, -35)
kit.item('ammo', 35, H_WALK, 0)
kit.item('ammo', -20, 0, 0)
kit.item('health', -34, 0, 15)
kit.item('health', 10, 0, 30)

# --- Spawns (Raketen-Raum und Laufsteg Ost liegen am weitesten auseinander = CTF-Basen) ---
for x, y, z, yaw in ((-34, 0, 34, 0), (35, H_WALK, -26, 90), (-12, 0, -12, 135), (12, 0, 12, -45),
                     (-12, 0, 12, 45), (12, 0, -12, -135), (-20, H_WALK, -35, 180), (15, H_WALK, -35, 180),
                     (35, H_WALK, 20, 90), (-34, 0, -28, 180), (-26, 0, 14, 0), (-8, H_WALK, -36, 180)):
    kit.spawn(x, y, z, yaw)

# --- Zerstoerbare Objekte, leichter Bodennebel im Innenhof ---
kit.glass(-25, H_WALK + 1, -30.04, -15, H_WALK + 2.6, -29.96)    # Glasschilde auf dem Gelaender Nord
kit.glass(12, H_WALK + 1, -30.04, 22, H_WALK + 2.6, -29.96)
kit.crate(-18.5, 0, 18)
kit.crate(-18.5, 0, 16.8, 25)
kit.crate(18.5, 0, 17.5, -10)
kit.barrel(28.5, 0, 17.5)
kit.barrel(-37, 0, -37)
kit.fog_volume(-30, 0, -30, 30, 1.2, 30, (0.6, 0.4, 0.9), 0.04)

kit.write()
