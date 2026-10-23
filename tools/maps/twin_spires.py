"""Twin Spires: zwei Tuerme auf einem Asteroiden (Vorbild UT CTF-Face), ca. 170 x 60 m, fuer CTF gemacht.

Offenes Gelaende mit Felsen als Deckung und einem Grat in der Mitte, Sniper-Felsen mit Jump-Pad.
Jeder Turm: Tuer zur Mitte, Treppe zum Balkon (y=6), Jump-Pad durch eine Dachoeffnung aufs Dach (y=14).
Die Turm-Spawns sind die am weitesten entfernten Spawnpunkte, also die CTF-Basen.
Aufruf aus dem Projektordner:  python tools/maps/twin_spires.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapkit import MapKit, FLOOR, WALK, METAL, ACCENT, CYAN, MAGENTA, YELLOW, ORANGE  # noqa: E402

kit = MapKit('twin_spires', 'TwinSpires', sky=((0.05, 0.05, 0.15), (0.4, 0.3, 1), (0.3, 0.6, 1)), fog=0.006)
TX = 65            # Turmmitte; Flaggen ca. 140 m auseinander (bei 190 m kam kein Traeger heim)
L, W = TX + 20, 30
kit.void(-20)

# --- Asteroid: Boden mit Leuchtkante, Felsbrocken darunter ---
kit.platform(-L, -W, L, W, 0, FLOOR, glow=CYAN, thick=6.0)
for x, z, depth in ((-58, -15, 14), (-29, 18, 10), (0, -10, 16), (29, -18, 10), (58, 15, 14), (-14, 5, 8), (14, -5, 8)):
    kit.solid(x - 8, -6 - depth, z - 8, x + 8, -6, z + 8, METAL)

# --- Grat in der Mitte (y=3) mit Rampen von beiden Seiten ---
kit.solid(-6, 0, -18, 6, 3, 18, ACCENT)
kit.glow_edge(-6, -18, 6, 18, 3, MAGENTA)
kit.ramp(-12, -6, -18, 18, 0, 3, '+x')
kit.ramp(6, 12, -18, 18, 0, 3, '-x')
kit.item('armor', 0, 3, 0)
kit.weapon('rocket_launcher', 0, 3, -10)
kit.light(0, 7, 0, (1, 0.25, 0.8), 3.0, 16)

# --- Felsen als Deckung, Sniper-Felsen (y=6) mit Jump-Pad ---
for sx in (-1, 1):
    for x, z, h in ((18, 22, 2.5), (25, -10, 3.0), (37, 20, 2.0), (46, -18, 3.5), (50, 8, 2.5)):
        kit.solid(sx * x - 1.8, 0, z - 1.8, sx * x + 1.8, h, z + 1.8, METAL)
        kit.deco(sx * x - 1.82, h - 0.1, z - 1.82, sx * x + 1.82, h + 0.02, z + 1.82, ORANGE)
    kit.solid(sx * 33, 0, -3, sx * 39, 6, 3, ACCENT)
    kit.glow_edge(sx * 33, -3, sx * 39, 3, 6, YELLOW)
    kit.pad(sx * 28, 0, 0, sx * 36, 6, 0, apex=2.0)
    kit.item('health', sx * 36, 6, 0)
    kit.item('health', sx * 22, 0, 27)
    kit.item('health', sx * 22, 0, -27)
    kit.item('ammo', sx * 44, 0, 0)
    kit.weapon('plasma' if sx < 0 else 'lightning', sx * 12, 0, 24)
    kit.spawn(sx * 22, 0, 25, 90 * sx)
    kit.spawn(sx * 22, 0, -25, 90 * sx)
    kit.spawn(sx * 42, 0, -10, 90 * sx)
    kit.spawn(sx * 30, 0, 12, 90 * sx)


def tower(sx):
    """Turm bei x = sx * TX: Tuer zur Mitte, Treppe zum Balkon, Pad durch die Dachoeffnung aufs Dach."""
    inner, outer = sx * (TX - 8), sx * (TX + 8)
    x0, x1 = sorted((inner, outer))
    kit.room(x0, -8, x1, 8, 0, 14, doors=[('w' if sx > 0 else 'o', -2, 2)])
    for z in (-8, 8):
        kit.deco(inner - sx * 0.3, 0, z - 0.1, inner - sx * 0.2, 14, z + 0.1, CYAN if sx > 0 else MAGENTA)
    # Balkon y=6 im hinteren Teil, Treppe (8 m fuer 6 m Hoehe, 37 Grad) an der Nordwand hinauf
    # Treppe 1 m weg von der Tuerwand: sonst kein Platz am Fuss, Bots kaemen nur seitlich auf die Rampe
    b0, b1 = sorted((sx * (TX + 2), outer))
    kit.platform(b0, -7.75, b1, 7.75, 6, WALK, glow=YELLOW)
    s0, s1 = sorted((sx * (TX - 6), sx * (TX + 2)))
    kit.stairs(s0, s1, -7.5, -5, 0, 6, '+x' if sx > 0 else '-x')
    # Dach y=14 mit Oeffnung ueber dem Pad (hinteres Viertel Sued)
    h0, h1 = sorted((sx * TX, outer))
    kit.platform(x0, -8, x1, 0, 14, ACCENT, glow=MAGENTA)
    c0, c1 = sorted((inner, sx * TX))
    kit.platform(c0, 0, c1, 8, 14, ACCENT)
    kit.glow_edge(h0, 0, h1, 8, 14, YELLOW)
    kit.rail(outer, -8, outer, 8, 14)        # Rueckseite
    kit.rail(x0, -8, x1, -8, 14)             # Nordseite; Vorder- und Suedseite offen (Absprung)
    kit.pad(sx * (TX + 4), 6, 5, sx * (TX - 4), 14, -3, apex=2.0)
    # Spawns: Boden (Basis), Balkon, Dach
    # Boden-Spawns am weitesten aussen (diagonal ca. 142 m): dort stehen die CTF-Flaggen
    kit.spawn(sx * (TX + 6), 0, sx * -4, 90 * sx)
    kit.spawn(sx * (TX + 6), 0, sx * 4, 90 * sx)
    kit.spawn(sx * (TX + 5), 6, 0, 90 * sx)
    kit.spawn(sx * (TX - 4), 14, -4, 90 * sx)
    kit.item('armor', sx * (TX + 3), 0, 5)
    kit.item('ammo', sx * (TX + 6), 6, 2)
    kit.weapon('shock_rifle', sx * (TX + 3), 6, -3)
    kit.weapon('railgun', sx * (TX - 2), 14, -6)
    kit.light(sx * TX, 4, 0, (0.2, 0.85, 1) if sx > 0 else (1, 0.25, 0.8), 2.5, 12)
    kit.light(sx * TX, 17, 0, (0.2, 0.85, 1) if sx > 0 else (1, 0.25, 0.8), 3.0, 16)


tower(-1)
tower(1)

# --- Leuchtender Nebel unter dem Asteroiden, Kisten und Faesser vor den Tuermen ---
kit.fog_volume(-L - 30, -26, -W - 30, L + 30, -6, W + 30, (0.4, 0.3, 1.0), 0.04, 0.4)
for sx in (-1, 1):
    kit.crate(sx * (TX - 10), 0, 6)
    kit.crate(sx * (TX - 10), 0, 7.2, 30)
    kit.barrel(sx * (TX - 10), 0, -6)
kit.write()
