"""Erzeugt maps/neon_foundry.map (Quake-Format fuer func_godot / TrenchBroom).

Aufruf aus dem Projektordner:  python tools/generate_neon_foundry.py

Alle Masse hier in Godot-Metern (x rechts, y oben, z nach Sueden). Umrechnung nach Quake:
Quake (x, y, z) = Godot (z, x, y) * 32.

Aufbau der Arena (64 x 64 m, drei Ebenen):
- Boden (y=0) mit Deckungsbloecken, zwei Durchgangswaenden (x=+-18) mit Tueren
- Ring-Steg (y=4) entlang aller Waende, 6 m breit, mit Gelaender
- Mittelplattform (y=4) auf vier Saeulen, ueber zwei Bruecken mit dem Ring verbunden
- Zwei Tuerme (y=8) in den Ecken Nordost und Suedwest, ueber Treppen vom Ring erreichbar
- Vier Treppen Boden -> Ring, zwei Treppen Ring -> Turm
Treppen: sichtbare Stufen ohne Kollision (func_detail_illusionary) plus unsichtbare Rampe (clip),
weil Spieler und Bots keine Stufen steigen koennen.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'maps', 'neon_foundry.map')
S = 32  # Quake-Einheiten pro Meter

FLOOR, WALL, WALK, METAL, ACCENT = 'neon/floor', 'neon/wall', 'neon/walkway', 'neon/metal', 'neon/accent'
CYAN, MAGENTA, YELLOW, ORANGE = 'neon/glow_cyan', 'neon/glow_magenta', 'neon/glow_yellow', 'neon/glow_orange'
CLIP = 'clip'


def q(v):
    """Godot-Punkt (x, y, z) in Meter -> Quake-Punkt in Einheiten."""
    x, y, z = v
    return (round(z * S, 3), round(x * S, 3), round(y * S, 3))


def fmt(n):
    return str(int(n)) if float(n).is_integer() else f'{n:.3f}'


def face(p1, p2, p3, tex):
    return '( {} ) ( {} ) ( {} ) {} 0 0 0 1 1'.format(
        ' '.join(fmt(c) for c in p1), ' '.join(fmt(c) for c in p2), ' '.join(fmt(c) for c in p3), tex)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def convex_brush(vertices, faces, tex):
    """Brush aus Eckpunkten (Godot-Meter) und Flaechen (Listen von Eckpunkt-Indizes).
    Die Punktreihenfolge wird so gedreht, dass die Normale nach aussen zeigt
    (Quake/TrenchBroom: Normale = (p3 - p1) x (p2 - p1))."""
    qv = [q(v) for v in vertices]
    centroid = tuple(sum(c[i] for c in qv) / len(qv) for i in range(3))
    lines = []
    for f in faces:
        p1, p2, p3 = qv[f[0]], qv[f[1]], qv[f[2]]
        n = cross(sub(p3, p1), sub(p2, p1))
        if dot(n, sub(p1, centroid)) < 0:
            p2, p3 = p3, p2
        lines.append(face(p1, p2, p3, tex))
    return '{\n' + '\n'.join(lines) + '\n}\n'


def box(x0, y0, z0, x1, y1, z1, tex):
    """Achsenparalleler Quader in Godot-Metern."""
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    z0, z1 = min(z0, z1), max(z0, z1)
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
         (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]
    f = [[0, 1, 2], [4, 7, 6], [0, 4, 5], [3, 2, 6], [0, 3, 7], [1, 5, 6]]
    return convex_brush(v, f, tex)


def wedge(x0, x1, z0, z1, y_low, y_high, rise_dir, tex):
    """Keil (Rampe) ueber dem Rechteck x0..x1 / z0..z1, steigt von y_low auf y_high
    in Richtung rise_dir ('+x', '-x', '+z', '-z'). Unterseite liegt auf y_low."""
    # Eckpunkte unten: a=(x0,z0) b=(x1,z0) c=(x1,z1) d=(x0,z1)
    corners = {'a': (x0, z0), 'b': (x1, z0), 'c': (x1, z1), 'd': (x0, z1)}
    high = {'+x': ('b', 'c'), '-x': ('a', 'd'), '+z': ('c', 'd'), '-z': ('a', 'b')}[rise_dir]
    names = ['a', 'b', 'c', 'd']
    v = [(corners[n][0], y_low, corners[n][1]) for n in names]
    top = [(corners[n][0], y_high, corners[n][1]) for n in high]
    v += top
    i_top0, i_top1 = 4, 5
    i_h0, i_h1 = names.index(high[0]), names.index(high[1])
    low = [n for n in names if n not in high]
    i_l0, i_l1 = names.index(low[0]), names.index(low[1])
    faces = [
        [0, 1, 2],                  # Boden
        [i_h0, i_h1, i_top0],       # hohe senkrechte Seite
        [i_l0, i_l1, i_top0],       # Schraege (laeuft durch beide niedrigen Ecken und die Oberkante)
        [i_l0, i_h0, i_top0] if _adjacent(names, low[0], high[0]) else [i_l0, i_h1, i_top1],
        [i_l1, i_h1, i_top1] if _adjacent(names, low[1], high[1]) else [i_l1, i_h0, i_top0],
    ]
    return convex_brush(v, faces, tex)


def _adjacent(names, n1, n2):
    i, j = names.index(n1), names.index(n2)
    return abs(i - j) in (1, 3)


def stairs(x0, x1, z0, z1, y_base, rise, rise_dir, steps, world, details, tex=METAL):
    """Treppe: sichtbare Stufen (ohne Kollision) + unsichtbare Rampe (clip) + Podest oben.
    Die Rampe laeuft durch die Mitten der Trittflaechen, damit die Fuesse auf den Stufen stehen."""
    horizontal = rise_dir in ('+x', '-x')
    length = (x1 - x0) if horizontal else (z1 - z0)
    run = length / steps
    h = rise / steps
    sign = 1 if rise_dir[0] == '+' else -1
    start = (x0 if sign > 0 else x1) if horizontal else (z0 if sign > 0 else z1)
    for i in range(steps):
        a = start + sign * i * run
        b = start + sign * (i + 1) * run
        if horizontal:
            details.append(box(a, y_base, z0, b, y_base + (i + 1) * h, z1, tex))
        else:
            details.append(box(x0, y_base, a, x1, y_base + (i + 1) * h, b, tex))
    # Rampe von einer halben Stufe vor der Treppe bis eine halbe Stufe vor das Ende, danach Podest
    r0 = start - sign * run / 2
    r1 = start + sign * (length - run / 2)
    end = start + sign * length
    if horizontal:
        world.append(wedge(min(r0, r1), max(r0, r1), z0, z1, y_base, y_base + rise, rise_dir, CLIP))
        world.append(box(r1, y_base, z0, end, y_base + rise, z1, CLIP))
    else:
        world.append(wedge(x0, x1, min(r0, r1), max(r0, r1), y_base, y_base + rise, rise_dir, CLIP))
        world.append(box(x0, y_base, r1, x1, y_base + rise, end, CLIP))


def build():
    world = []    # worldspawn: Kollision + Optik
    details = []  # func_detail_illusionary: nur Optik (Stufen, Leuchtstreifen)

    A = 32       # halbe Arenabreite
    H_RING = 4.0
    H_TOWER = 8.0
    T = 0.5      # Dicke der Stege

    # --- Boden und Aussenwaende ---
    world.append(box(-A, -1, -A, A, 0, A, FLOOR))
    world.append(box(-A - 1, -1, -A - 1, A + 1, 16, -A, WALL))   # Nord
    world.append(box(-A - 1, -1, A, A + 1, 16, A + 1, WALL))     # Sued
    world.append(box(-A - 1, -1, -A, -A, 16, A, WALL))           # West
    world.append(box(A, -1, -A, A + 1, 16, A, WALL))             # Ost

    # --- Ring-Steg auf y=4 (Nord, Sued volle Breite, Ost/West dazwischen) ---
    R = A - 7  # Innenkante des Rings (25)
    world.append(box(-A, H_RING - T, -A, A, H_RING, -R, WALK))
    world.append(box(-A, H_RING - T, R, A, H_RING, A, WALK))
    world.append(box(R, H_RING - T, -R, A, H_RING, R, WALK))
    world.append(box(-A, H_RING - T, -R, -R, H_RING, R, WALK))

    # Gelaender (1 m hoch) an der Innenkante, mit Luecken fuer Treppen und Bruecken
    rail_h = H_RING + 1.0
    def rail_x(z_edge, x_from, x_to, gaps, inward):
        xs = [x_from] + [v for g in gaps for v in g] + [x_to]
        for i in range(0, len(xs), 2):
            if xs[i + 1] - xs[i] > 0.3:
                world.append(box(xs[i], H_RING, z_edge, xs[i + 1], rail_h, z_edge + inward * 0.3, METAL))
                details.append(box(xs[i], rail_h, z_edge, xs[i + 1], rail_h + 0.06, z_edge + inward * 0.3, CYAN))

    def rail_z(x_edge, z_from, z_to, gaps, inward):
        zs = [z_from] + [v for g in gaps for v in g] + [z_to]
        for i in range(0, len(zs), 2):
            if zs[i + 1] - zs[i] > 0.3:
                world.append(box(x_edge, H_RING, zs[i], x_edge + inward * 0.3, rail_h, zs[i + 1], METAL))
                details.append(box(x_edge, rail_h, zs[i], x_edge + inward * 0.3, rail_h + 0.06, zs[i + 1], CYAN))

    rail_x(-R, -R, R, [(-14, -11)], -1)          # Nordkante (Treppe S1)
    rail_x(R, -R, R, [(11, 14)], 1)              # Suedkante (Treppe S2)
    rail_z(R, -R, R, [(-1.5, 1.5), (11, 14)], 1)     # Ostkante (Bruecke, Treppe S3)
    rail_z(-R, -R, R, [(-14, -11), (-1.5, 1.5)], -1)  # Westkante (Treppe S4, Bruecke)

    # Leuchtstreifen unter der Ringkante (gelb), gut sichtbar vom Boden aus
    details.append(box(-R, H_RING - T - 0.08, -R - 0.05, R, H_RING - T, -R + 0.05, YELLOW))
    details.append(box(-R, H_RING - T - 0.08, R - 0.05, R, H_RING - T, R + 0.05, YELLOW))
    details.append(box(R - 0.05, H_RING - T - 0.08, -R, R + 0.05, H_RING - T, R, YELLOW))
    details.append(box(-R - 0.05, H_RING - T - 0.08, -R, -R + 0.05, H_RING - T, R, YELLOW))

    # Stuetzen unter den Ring-Ecken
    for sx in (-1, 1):
        for sz in (-1, 1):
            world.append(box(sx * R - 0.5, 0, sz * R - 0.5, sx * R + 0.5, H_RING - T, sz * R + 0.5, METAL))

    # --- Mittelplattform auf Saeulen + Bruecken nach Ost/West ---
    world.append(box(-5, H_RING - T, -5, 5, H_RING, 5, ACCENT))
    for sx in (-1, 1):
        for sz in (-1, 1):
            world.append(box(sx * 4.5 - 0.5, 0, sz * 4.5 - 0.5, sx * 4.5 + 0.5, H_RING - T, sz * 4.5 + 0.5, METAL))
    details.append(box(-5.05, H_RING - 0.1, -5.05, 5.05, H_RING + 0.02, -4.95, MAGENTA))
    details.append(box(-5.05, H_RING - 0.1, 4.95, 5.05, H_RING + 0.02, 5.05, MAGENTA))
    world.append(box(5, H_RING - T, -1.5, R, H_RING, 1.5, WALK))
    world.append(box(-R, H_RING - T, -1.5, -5, H_RING, 1.5, WALK))
    for sx in (-1, 1):
        x_a, x_b = (5, R) if sx > 0 else (-R, -5)
        details.append(box(x_a, H_RING - 0.04, -1.55, x_b, H_RING + 0.02, -1.45, ORANGE))
        details.append(box(x_a, H_RING - 0.04, 1.45, x_b, H_RING + 0.02, 1.55, ORANGE))

    # --- Tuerme (y=8) Nordost und Suedwest ---
    for sx, sz in ((1, -1), (-1, 1)):
        x_lo, x_hi = sorted((sx * 19, sx * A))
        z_lo, z_hi = sorted((sz * 19, sz * A))
        world.append(box(x_lo, H_TOWER - T, z_lo, x_hi, H_TOWER, z_hi, ACCENT))
        # Saeule unter der inneren Ecke bis zum Boden
        world.append(box(sx * 19.5 - 0.6, 0, sz * 19.5 - 0.6, sx * 19.5 + 0.6, H_TOWER - T, sz * 19.5 + 0.6, METAL))
        # Leuchtkante (magenta) um die Turmplattform
        details.append(box(x_lo - 0.05, H_TOWER - 0.12, z_lo - 0.05, x_hi + 0.05, H_TOWER - T + 0.05, z_lo + 0.05, MAGENTA))
        details.append(box(x_lo - 0.05, H_TOWER - 0.12, z_hi - 0.05, x_hi + 0.05, H_TOWER - T + 0.05, z_hi + 0.05, MAGENTA))

    # --- Treppen Boden -> Ring (16 Stufen, 0,25 m hoch) ---
    stairs(-14, -11, -25, -15, 0, H_RING, '-z', 16, world, details)  # S1 nach Norden
    stairs(11, 14, 15, 25, 0, H_RING, '+z', 16, world, details)      # S2 nach Sueden
    stairs(15, 25, 11, 14, 0, H_RING, '+x', 16, world, details)      # S3 nach Osten
    stairs(-25, -15, -14, -11, 0, H_RING, '-x', 16, world, details)  # S4 nach Westen

    # --- Treppen Ring -> Turm (auf dem Ring, an der Aussenwand entlang) ---
    stairs(9, 19, -A, -28.5, H_RING, H_TOWER - H_RING, '+x', 16, world, details)   # Nordost
    stairs(-19, -9, 28.5, A, H_RING, H_TOWER - H_RING, '-x', 16, world, details)   # Suedwest

    # --- Durchgangswaende am Boden (x=+-18) mit Tuer in der Mitte ---
    for sx in (-1, 1):
        x_lo, x_hi = sorted((sx * 17.75, sx * 18.25))
        world.append(box(x_lo, 0, -9, x_hi, 3.5, -2, WALL))
        world.append(box(x_lo, 0, 2, x_hi, 3.5, 9, WALL))
        world.append(box(x_lo, 2.8, -2, x_hi, 3.5, 2, WALL))  # Sturz ueber der Tuer
        details.append(box(x_lo - 0.05, 2.7, -2, x_hi + 0.05, 2.8, 2, CYAN))

    # --- Deckungsbloecke am Boden ---
    for cx, cz in ((-8, -18), (8, 18), (-8, 18), (8, -18)):
        world.append(box(cx - 1, 0, cz - 1, cx + 1, 2, cz + 1, METAL))
        details.append(box(cx - 1.02, 1.9, cz - 1.02, cx + 1.02, 2.02, cz + 1.02, ORANGE))

    # --- Senkrechte Leuchtstreifen an den Aussenwaenden (magenta/cyan im Wechsel) ---
    for i, p in enumerate(range(-24, 25, 8)):
        tex = MAGENTA if i % 2 == 0 else CYAN
        details.append(box(p - 0.08, 0, -A, p + 0.08, 14, -A + 0.05, tex))
        details.append(box(p - 0.08, 0, A - 0.05, p + 0.08, 14, A, tex))
        details.append(box(-A, 0, p - 0.08, -A + 0.05, 14, p + 0.08, tex))
        details.append(box(A - 0.05, 0, p - 0.08, A, 14, p + 0.08, tex))

    text = '// Game: Generic\n// Format: Standard\n// Erzeugt von tools/generate_neon_foundry.py\n'
    text += '{\n"classname" "worldspawn"\n' + ''.join(world) + '}\n'
    text += '{\n"classname" "func_detail_illusionary"\n' + ''.join(details) + '}\n'
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print(f'{OUT}: {len(world)} Brushes Welt, {len(details)} Brushes Deko')


if __name__ == '__main__':
    build()
