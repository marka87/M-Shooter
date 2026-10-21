"""Erzeugt die Waffenmodelle scenes/weapons/models/<waffe>.tscn im Neon-Low-Poly-Stil.

Jedes Modell besteht aus einfachen Grundformen mit wenigen Seiten (Sechs- und Achtecke), damit
der Kanten-Shader (neon_edges.gdshader) klare Facetten zeichnet. Drei Materialien pro Waffe:
dunkler Grafit-Koerper, metallische Zierteile (leicht in der Waffenfarbe getoent) und
Leuchtteile in der Waffenfarbe (wie in resources/weapons/*.tres).

Konvention: Blick nach -Z, Ursprung am oberen Griffende. Die Laufspitze endet kurz vor dem
Muzzle-Knoten der jeweiligen Waffenszene.

Aufruf aus dem Projektordner:  python tools/make_weapon_models.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'scenes', 'weapons', 'models')

# Teile: (Name, Form, Material, Position, Masse, Drehung in Grad um X/Y/Z)
# Formen: box (Breite, Hoehe, Laenge), cyl (Radius, Laenge, Seiten) entlang -Z,
#         ring (Innenradius, Aussenradius, Seiten) um die Z-Achse, wedge (Breite, Hoehe, Laenge)
G, T, L = 'graphite', 'trim', 'glow'
GRIP = ('Grip', 'box', G, (0, -0.11, 0.0), (0.06, 0.15, 0.075), (15, 0, 0))
GUARD = ('Guard', 'box', T, (0, -0.075, -0.07), (0.02, 0.012, 0.09), (0, 0, 0))

WEAPONS = {
    'machine_gun': ((1, 0.75, 0.25), [
        ('Receiver', 'box', G, (0, 0, -0.12), (0.1, 0.12, 0.34), (0, 0, 0)),
        ('TopRail', 'box', T, (0, 0.072, -0.12), (0.04, 0.025, 0.3), (0, 0, 0)),
        ('StripL', 'box', L, (-0.052, 0.01, -0.12), (0.006, 0.02, 0.24), (0, 0, 0)),
        ('StripR', 'box', L, (0.052, 0.01, -0.12), (0.006, 0.02, 0.24), (0, 0, 0)),
        ('Shroud', 'cyl', T, (0, 0.02, -0.38), (0.036, 0.2, 6), (0, 0, 0)),
        ('Barrel', 'cyl', G, (0, 0.02, -0.53), (0.017, 0.14, 8), (0, 0, 0)),
        ('GlowRing', 'ring', L, (0, 0.02, -0.47), (0.03, 0.04, 8), (0, 0, 0)),
        ('Magazine', 'box', G, (0, -0.12, -0.2), (0.06, 0.16, 0.08), (-10, 0, 0)),
        ('MagGlow', 'box', L, (0, -0.1, -0.2), (0.064, 0.018, 0.084), (-10, 0, 0)),
        ('Stock', 'wedge', G, (0, -0.02, 0.1), (0.06, 0.1, 0.14), (0, 0, 0)),
        GRIP, GUARD,
    ]),
    'shotgun': ((1, 0.55, 0.15), [
        ('Body', 'box', G, (0, 0, -0.08), (0.13, 0.12, 0.3), (0, 0, 0)),
        ('BarrelL', 'cyl', G, (-0.034, 0.03, -0.42), (0.03, 0.42, 8), (0, 0, 0)),
        ('BarrelR', 'cyl', G, (0.034, 0.03, -0.42), (0.03, 0.42, 8), (0, 0, 0)),
        ('Band', 'box', T, (0, 0.03, -0.56), (0.15, 0.08, 0.04), (0, 0, 0)),
        ('RingL', 'ring', L, (-0.034, 0.03, -0.61), (0.03, 0.038, 8), (0, 0, 0)),
        ('RingR', 'ring', L, (0.034, 0.03, -0.61), (0.03, 0.038, 8), (0, 0, 0)),
        ('Pump', 'box', T, (0, -0.035, -0.36), (0.11, 0.07, 0.18), (0, 0, 0)),
        ('PumpGlow', 'box', L, (0, -0.072, -0.36), (0.03, 0.008, 0.16), (0, 0, 0)),
        ('StripL', 'box', L, (-0.067, 0.0, -0.08), (0.006, 0.03, 0.2), (0, 0, 0)),
        ('StripR', 'box', L, (0.067, 0.0, -0.08), (0.006, 0.03, 0.2), (0, 0, 0)),
        ('Stock', 'wedge', G, (0, -0.03, 0.12), (0.08, 0.12, 0.16), (0, 0, 0)),
        GRIP, GUARD,
    ]),
    'plasma_gun': ((0.25, 0.75, 1), [
        ('Body', 'box', G, (0, 0, -0.08), (0.12, 0.13, 0.3), (0, 0, 0)),
        ('Hump', 'cyl', T, (0, 0.06, -0.1), (0.055, 0.22, 6), (0, 0, 0)),
        ('Barrel', 'cyl', G, (0, 0.02, -0.42), (0.03, 0.34, 8), (0, 0, 0)),
        ('Coil1', 'ring', L, (0, 0.02, -0.34), (0.034, 0.055, 8), (0, 0, 0)),
        ('Coil2', 'ring', L, (0, 0.02, -0.44), (0.034, 0.055, 8), (0, 0, 0)),
        ('Coil3', 'ring', L, (0, 0.02, -0.54), (0.034, 0.055, 8), (0, 0, 0)),
        ('Cell', 'cyl', L, (0.075, 0.0, -0.08), (0.03, 0.16, 6), (0, 0, 0)),
        ('CellCapF', 'cyl', T, (0.075, 0.0, -0.17), (0.036, 0.03, 6), (0, 0, 0)),
        ('CellCapB', 'cyl', T, (0.075, 0.0, 0.01), (0.036, 0.03, 6), (0, 0, 0)),
        GRIP, GUARD,
    ]),
    'rocket_launcher': ((1, 0.4, 0.1), [
        ('Tube', 'cyl', G, (0, 0, -0.33), (0.075, 0.6, 6), (0, 0, 30)),
        ('FrontRing', 'cyl', T, (0, 0, -0.6), (0.09, 0.06, 6), (0, 0, 30)),
        ('GlowRing', 'ring', L, (0, 0, -0.54), (0.072, 0.086, 6), (0, 0, 30)),
        ('RearRing', 'cyl', T, (0, 0, -0.04), (0.085, 0.05, 6), (0, 0, 30)),
        ('AmmoBox', 'box', T, (0.095, -0.02, -0.22), (0.04, 0.1, 0.18), (0, 0, 0)),
        ('Rocket1', 'cyl', L, (0.118, 0.01, -0.22), (0.012, 0.14, 6), (0, 0, 0)),
        ('Rocket2', 'cyl', L, (0.118, -0.05, -0.22), (0.012, 0.14, 6), (0, 0, 0)),
        ('Sight', 'box', T, (0, 0.1, -0.22), (0.03, 0.05, 0.08), (0, 0, 0)),
        ('SightLens', 'box', L, (0, 0.105, -0.262), (0.022, 0.03, 0.006), (0, 0, 0)),
        ('Grip', 'box', G, (0, -0.13, 0.0), (0.06, 0.15, 0.075), (15, 0, 0)),
        ('ForeGrip', 'box', G, (0, -0.12, -0.32), (0.05, 0.12, 0.06), (-10, 0, 0)),
    ]),
    'lightning_gun': ((0.7, 0.9, 1), [
        ('Body', 'box', G, (0, 0, -0.1), (0.11, 0.12, 0.28), (0, 0, 0)),
        ('Core', 'cyl', L, (0, 0.02, -0.32), (0.03, 0.26, 6), (0, 0, 0)),
        ('Coil1', 'ring', T, (0, 0.02, -0.28), (0.032, 0.05, 6), (0, 0, 0)),
        ('Coil2', 'ring', T, (0, 0.02, -0.38), (0.032, 0.05, 6), (0, 0, 0)),
        ('ProngL', 'box', G, (-0.055, 0.0, -0.42), (0.02, 0.03, 0.26), (0, -6, 0)),
        ('ProngR', 'box', G, (0.055, 0.0, -0.42), (0.02, 0.03, 0.26), (0, 6, 0)),
        ('ProngTop', 'box', G, (0, 0.075, -0.42), (0.03, 0.02, 0.26), (6, 0, 0)),
        ('TipL', 'box', L, (-0.042, 0.0, -0.555), (0.026, 0.036, 0.04), (0, -6, 0)),
        ('TipR', 'box', L, (0.042, 0.0, -0.555), (0.026, 0.036, 0.04), (0, 6, 0)),
        ('TipTop', 'box', L, (0, 0.06, -0.555), (0.036, 0.026, 0.04), (6, 0, 0)),
        ('Tank', 'cyl', T, (0, -0.06, -0.12), (0.04, 0.18, 6), (0, 0, 0)),
        GRIP, GUARD,
    ]),
    'railgun': ((0.3, 1, 0.9), [
        ('Receiver', 'box', G, (0, 0, -0.12), (0.09, 0.12, 0.42), (0, 0, 0)),
        ('RailL', 'box', G, (-0.045, 0.02, -0.52), (0.022, 0.05, 0.62), (0, 0, 0)),
        ('RailR', 'box', G, (0.045, 0.02, -0.52), (0.022, 0.05, 0.62), (0, 0, 0)),
        ('Core', 'box', L, (0, 0.02, -0.5), (0.03, 0.03, 0.56), (0, 0, 0)),
        ('Ring1', 'ring', T, (0, 0.02, -0.4), (0.062, 0.075, 6), (0, 0, 0)),
        ('Ring2', 'ring', L, (0, 0.02, -0.58), (0.062, 0.072, 6), (0, 0, 0)),
        ('Ring3', 'ring', T, (0, 0.02, -0.76), (0.062, 0.075, 6), (0, 0, 0)),
        ('Scope', 'cyl', T, (0, 0.1, -0.12), (0.025, 0.18, 8), (0, 0, 0)),
        ('ScopeLens', 'cyl', L, (0, 0.1, -0.215), (0.02, 0.01, 8), (0, 0, 0)),
        ('Stock', 'wedge', G, (0, -0.02, 0.15), (0.05, 0.11, 0.18), (0, 0, 0)),
        GRIP, GUARD,
    ]),
    'shock_rifle': ((0.6, 0.35, 1), [
        ('Body', 'box', G, (0, 0, -0.08), (0.14, 0.1, 0.36), (0, 0, 0)),
        ('Barrel', 'cyl', T, (0, 0.03, -0.52), (0.035, 0.5, 8), (0, 0, 0)),
        ('Ring1', 'ring', L, (0, 0.03, -0.42), (0.04, 0.056, 8), (0, 0, 0)),
        ('Ring2', 'ring', L, (0, 0.03, -0.57), (0.04, 0.056, 8), (0, 0, 0)),
        ('Ring3', 'ring', L, (0, 0.03, -0.72), (0.04, 0.056, 8), (0, 0, 0)),
        ('CellFrame', 'box', T, (0, 0.07, -0.1), (0.08, 0.04, 0.18), (0, 0, 0)),
        ('Cell', 'box', L, (0, 0.092, -0.1), (0.06, 0.012, 0.15), (0, 0, 0)),
        ('FinL', 'box', T, (-0.08, 0.02, -0.3), (0.01, 0.06, 0.18), (0, 0, -20)),
        ('FinR', 'box', T, (0.08, 0.02, -0.3), (0.01, 0.06, 0.18), (0, 0, 20)),
        ('Stock', 'wedge', G, (0, -0.03, 0.18), (0.08, 0.1, 0.18), (0, 0, 0)),
        GRIP, GUARD,
    ]),
}


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def basis(rx, ry, rz):
    """Rotationsmatrix fuer Drehung in Grad, Reihenfolge wie Godot (YXZ)."""
    def rot(axis, deg):
        c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        if axis == 'x':
            return [[1, 0, 0], [0, c, -s], [0, s, c]]
        if axis == 'y':
            return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
        return [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    return mul(mul(rot('y', ry), rot('x', rx)), rot('z', rz))


def transform(pos, rot_deg, along_z):
    m = basis(*rot_deg)
    if along_z:
        # Zylinder und Ringe liegen in Godot entlang Y; um X kippen, damit sie entlang Z zeigen
        m = mul(m, basis(90, 0, 0))
    # Godot schreibt die Basis zeilenweise
    vals = [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], *pos]
    return 'Transform3D(' + ', '.join(f'{v:.6g}' if abs(v) > 1e-9 else '0' for v in vals) + ')'


def mesh_resource(rid, kind, mat, dims):
    if kind == 'box':
        return f'[sub_resource type="BoxMesh" id="{rid}"]\nmaterial = SubResource("{mat}")\nsize = Vector3({dims[0]}, {dims[1]}, {dims[2]})\n'
    if kind == 'cyl':
        r, length, sides = dims
        return (f'[sub_resource type="CylinderMesh" id="{rid}"]\nmaterial = SubResource("{mat}")\n'
                f'top_radius = {r}\nbottom_radius = {r}\nheight = {length}\nradial_segments = {sides}\nrings = 1\n')
    if kind == 'ring':
        inner, outer, sides = dims
        return (f'[sub_resource type="TorusMesh" id="{rid}"]\nmaterial = SubResource("{mat}")\n'
                f'inner_radius = {inner}\nouter_radius = {outer}\nrings = {sides}\nring_segments = 4\n')
    w, h, length = dims  # wedge: Keil als Schulterstuetze, hinten hoch, nach vorn abfallend
    return (f'[sub_resource type="PrismMesh" id="{rid}"]\nmaterial = SubResource("{mat}")\n'
            f'left_to_right = 0.0\nsize = Vector3({length}, {h}, {w})\n')


def build(name, color, parts):
    r, g, b = color
    trim = tuple(round(0.34 + (c - 0.34) * 0.15, 3) for c in color)
    out = ['[gd_scene format=3]\n',
           '[sub_resource type="StandardMaterial3D" id="graphite"]\nalbedo_color = Color(0.1, 0.11, 0.14, 1)\nmetallic = 0.5\nroughness = 0.35\n',
           f'[sub_resource type="StandardMaterial3D" id="trim"]\nalbedo_color = Color({trim[0]}, {trim[1]}, {trim[2]}, 1)\nmetallic = 0.7\nroughness = 0.25\n',
           f'[sub_resource type="StandardMaterial3D" id="glow"]\nalbedo_color = Color({r}, {g}, {b}, 1)\nemission_enabled = true\n'
           f'emission = Color({r}, {g}, {b}, 1)\nemission_energy_multiplier = 4.0\n']
    nodes = [f'[node name="{"".join(w.capitalize() for w in name.split("_"))}Model" type="Node3D"]\n']
    for i, (pname, kind, mat, pos, dims, rot) in enumerate(parts):
        rid = f'mesh_{i}'
        out.append(mesh_resource(rid, kind, mat, dims))
        if kind == 'wedge':
            # PrismMesh: Spitze oben links (-X); um Y drehen, damit -X nach hinten (+Z) zeigt
            rot = (rot[0], rot[1] + 90, rot[2])
        nodes.append(f'[node name="{pname}" type="MeshInstance3D" parent="."]\n'
                     f'transform = {transform(pos, rot, kind in ("cyl", "ring"))}\nmesh = SubResource("{rid}")\n')
    return '\n'.join(out + nodes)


def selftest():
    # Ein entlang Z gekippter Zylinder: lokale Y-Achse (Spalte 2 der Basis) zeigt nach +-Z
    t = transform((0, 0, 0), (0, 0, 0), True)
    vals = [float(v) for v in t[len('Transform3D('):-1].split(', ')]
    assert abs(abs(vals[7]) - 1.0) < 1e-6, t  # Zeile z, Spalte y


if __name__ == '__main__':
    selftest()
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (color, parts) in WEAPONS.items():
        path = os.path.join(OUT_DIR, name + '.tscn')
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(build(name, color, parts))
        print('geschrieben:', os.path.relpath(path, ROOT), f'({len(parts)} Teile)')
