"""Map-Baukasten (Roadmap 3.10): Maps als kurzes Python-Layout statt Handarbeit.

Eine Map ist ein Skript unter tools/maps/, das eine MapKit-Instanz fuellt und write() aufruft:
    kit = MapKit('sky_yard', 'SkyYard')
    kit.platform(-8, -35, 8, 35, 0, glow=CYAN)      # Geometrie
    kit.spawn(0, 0, 20, 180); kit.item('quad', 0, 12, 0)  # Objekte
    kit.write()
write() erzeugt maps/<id>.map (Quake-Format fuer func_godot), levels/<id>_template.tscn (Umgebung, Spawns,
Items, Jump-Pads, Teleporter, Lichter, Zonen) und baut daraus mit Godot levels/<id>.tscn.

Masse in Godot-Metern (x rechts, y oben, z nach Sueden). Hoehenangaben bei Objekten sind die Oberflaeche,
auf der sie stehen. Treppen sind sichtbare Stufen ohne Kollision plus unsichtbare Rampe (clip), weil Bots
keine Stufen steigen koennen.
"""
import math
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, 'Godot_v4.7.2-stable_win64_console.exe')
S = 32  # Quake-Einheiten pro Meter

FLOOR, WALL, WALK, METAL, ACCENT = 'neon/floor', 'neon/wall', 'neon/walkway', 'neon/metal', 'neon/accent'
CYAN, MAGENTA, YELLOW, ORANGE = 'neon/glow_cyan', 'neon/glow_magenta', 'neon/glow_yellow', 'neon/glow_orange'
CLIP = 'clip'

# Waffen-Pickups: ID -> (Waffenszene, Anzeigename, Lichtfarbe)
WEAPONS = {
    'machine_gun': ('machine_gun', 'Maschinengewehr', (1, 0.75, 0.25)),
    'shotgun': ('shotgun', 'Shotgun', (1, 0.55, 0.15)),
    'plasma': ('plasma_gun', 'Plasma', (0.25, 0.75, 1)),
    'rocket_launcher': ('rocket_launcher', 'Raketenwerfer', (1, 0.4, 0.1)),
    'lightning': ('lightning_gun', 'Lightning Gun', (0.7, 0.9, 1)),
    'railgun': ('railgun', 'Railgun', (0.3, 1, 0.9)),
    'shock_rifle': ('shock_rifle', 'Shock Rifle', (0.6, 0.35, 1)),
}
ITEM_SCENES = {'ammo': 'ammo_pickup', 'health': 'health_pickup', 'armor': 'armor_pickup',
               'quad': 'quad_damage_pickup', 'mega': 'mega_health_pickup'}


# ----------------------------------------------------------------------------- Brush-Geometrie

def q(v):
    """Godot-Punkt (x, y, z) in Meter -> Quake-Punkt in Einheiten."""
    x, y, z = v
    return (round(z * S, 3), round(x * S, 3), round(y * S, 3))


def _fmt(n):
    return str(int(n)) if float(n).is_integer() else f'{n:.3f}'


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def convex_brush(vertices, faces, tex):
    """Brush aus Eckpunkten (Godot-Meter) und Flaechen (Eckpunkt-Indizes); Normalen zeigen nach aussen."""
    qv = [q(v) for v in vertices]
    centroid = tuple(sum(c[i] for c in qv) / len(qv) for i in range(3))
    lines = []
    for f in faces:
        p1, p2, p3 = qv[f[0]], qv[f[1]], qv[f[2]]
        if _dot(_cross(_sub(p3, p1), _sub(p2, p1)), _sub(p1, centroid)) < 0:
            p2, p3 = p3, p2
        lines.append('( {} ) ( {} ) ( {} ) {} 0 0 0 1 1'.format(*(' '.join(_fmt(c) for c in p) for p in (p1, p2, p3)), tex))
    return '{\n' + '\n'.join(lines) + '\n}\n'


def box(x0, y0, z0, x1, y1, z1, tex):
    """Achsenparalleler Quader."""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
         (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]
    return convex_brush(v, [[0, 1, 2], [4, 7, 6], [0, 4, 5], [3, 2, 6], [0, 3, 7], [1, 5, 6]], tex)


def wedge(x0, x1, z0, z1, y_low, y_high, rise_dir, tex):
    """Keil (Rampe) ueber x0..x1 / z0..z1, steigt von y_low auf y_high in Richtung rise_dir ('+x', '-x', '+z', '-z')."""
    x0, x1 = sorted((x0, x1))
    z0, z1 = sorted((z0, z1))
    corners = {'a': (x0, z0), 'b': (x1, z0), 'c': (x1, z1), 'd': (x0, z1)}
    high = {'+x': ('b', 'c'), '-x': ('a', 'd'), '+z': ('c', 'd'), '-z': ('a', 'b')}[rise_dir]
    names = ['a', 'b', 'c', 'd']
    v = [(corners[n][0], y_low, corners[n][1]) for n in names] + [(corners[n][0], y_high, corners[n][1]) for n in high]
    i_h0, i_h1 = names.index(high[0]), names.index(high[1])
    low = [n for n in names if n not in high]
    i_l0, i_l1 = names.index(low[0]), names.index(low[1])

    def adjacent(n1, n2):
        return abs(names.index(n1) - names.index(n2)) in (1, 3)
    faces = [
        [0, 1, 2], [i_h0, i_h1, 4], [i_l0, i_l1, 4],
        [i_l0, i_h0, 4] if adjacent(low[0], high[0]) else [i_l0, i_h1, 5],
        [i_l1, i_h1, 5] if adjacent(low[1], high[1]) else [i_l1, i_h0, 4],
    ]
    return convex_brush(v, faces, tex)


def _tf(x, y, z, yaw_deg=0.0):
    c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    return f'Transform3D({c:.6f}, 0, {s:.6f}, 0, 1, 0, {-s:.6f}, 0, {c:.6f}, {x}, {y}, {z})'


# ----------------------------------------------------------------------------- Baukasten

class MapKit:
    def __init__(self, map_id, node_name, sky=((0.14, 0.06, 0.18), (1, 0.25, 0.6), (0.5, 0.25, 0.9)), fog=0.012):
        self.map_id = map_id
        self.node_name = node_name
        self.sky = sky  # (Horizont, Horizont-Gluehen, Nebel)
        self.fog = fog
        self.world = []    # Kollision + Optik
        self.details = []  # nur Optik (Stufen, Leuchtstreifen)
        self.spawns, self.items, self.weapons, self.pads, self.teles, self.lights, self.zones = [], [], [], [], [], [], []
        self.reverbs, self.props, self.fogs = [], [], []  # Hall-Zonen, zerstoerbare Objekte, Nebel-Volumen

    # --- Grundformen ---
    def solid(self, x0, y0, z0, x1, y1, z1, tex=METAL):
        self.world.append(box(x0, y0, z0, x1, y1, z1, tex))

    def deco(self, x0, y0, z0, x1, y1, z1, tex=CYAN):
        self.details.append(box(x0, y0, z0, x1, y1, z1, tex))

    # --- Module ---
    def platform(self, x0, z0, x1, z1, y, tex=WALK, glow=None, thick=0.5):
        """Begehbare Platte mit Oberkante y, optional Leuchtkante ringsum."""
        self.solid(x0, y - thick, z0, x1, y, z1, tex)
        if glow:
            self.glow_edge(x0, z0, x1, z1, y, glow)

    def glow_edge(self, x0, z0, x1, z1, y, tex):
        """Duenner Leuchtstreifen an den vier Kanten knapp unter der Oberkante."""
        x0, x1 = sorted((x0, x1))
        z0, z1 = sorted((z0, z1))
        e = 0.06
        self.deco(x0 - e, y - 0.12, z0 - e, x1 + e, y + 0.02, z0 + e, tex)
        self.deco(x0 - e, y - 0.12, z1 - e, x1 + e, y + 0.02, z1 + e, tex)
        self.deco(x0 - e, y - 0.12, z0, x0 + e, y + 0.02, z1, tex)
        self.deco(x1 - e, y - 0.12, z0, x1 + e, y + 0.02, z1, tex)

    def pillar(self, x, z, y0, y1, w=1.0, tex=METAL, glow=None):
        """Saeule (quadratisch, Breite w), optional Leuchtring oben."""
        self.solid(x - w / 2, y0, z - w / 2, x + w / 2, y1, z + w / 2, tex)
        if glow:
            self.deco(x - w / 2 - 0.05, y1 - 0.3, z - w / 2 - 0.05, x + w / 2 + 0.05, y1 - 0.2, z + w / 2 + 0.05, glow)

    def wall(self, x0, z0, x1, z1, y0, y1, tex=WALL):
        self.solid(x0, y0, z0, x1, y1, z1, tex)

    def wall_with_door(self, axis, at, a0, a1, y0, y1, door_from, door_to, door_h=3.0, thick=0.5, glow=CYAN):
        """Wand entlang axis ('x' = Wand laeuft in x-Richtung bei z=at, 'z' = bei x=at) mit Tuer door_from..door_to."""
        def seg(b0, b1, lo, hi):
            if b1 - b0 > 0.05:
                if axis == 'x':
                    self.wall(b0, at - thick / 2, b1, at + thick / 2, lo, hi)
                else:
                    self.wall(at - thick / 2, b0, at + thick / 2, b1, lo, hi)
        seg(a0, door_from, y0, y1)
        seg(door_to, a1, y0, y1)
        seg(door_from, door_to, y0 + door_h, y1)
        if glow:
            if axis == 'x':
                self.deco(door_from, y0 + door_h - 0.1, at - thick / 2 - 0.05, door_to, y0 + door_h, at + thick / 2 + 0.05, glow)
            else:
                self.deco(at - thick / 2 - 0.05, y0 + door_h - 0.1, door_from, at + thick / 2 + 0.05, y0 + door_h, door_to, glow)

    def ramp(self, x0, x1, z0, z1, y_low, y_high, rise_dir, tex=WALK):
        """Sichtbare, begehbare Rampe (flach genug fuer Bots: hoechstens 45 Grad)."""
        self.world.append(wedge(x0, x1, z0, z1, y_low, y_high, rise_dir, tex))

    def stairs(self, x0, x1, z0, z1, y_base, rise, rise_dir, steps=None, tex=METAL):
        """Treppe: sichtbare Stufen (ohne Kollision) + unsichtbare Rampe (clip) + Podest oben."""
        steps = steps or max(4, int(round(rise / 0.25)))
        horizontal = rise_dir in ('+x', '-x')
        x0, x1 = sorted((x0, x1))
        z0, z1 = sorted((z0, z1))
        length = (x1 - x0) if horizontal else (z1 - z0)
        # Navmesh nimmt hoechstens 45 Grad; mit Abstand bleiben, sonst entscheidet die Rundung
        assert rise / length <= 0.84, f'Treppe zu steil: {rise} m auf {length} m'
        run, h = length / steps, rise / steps
        sign = 1 if rise_dir[0] == '+' else -1
        start = (x0 if sign > 0 else x1) if horizontal else (z0 if sign > 0 else z1)
        for i in range(steps):
            a, b = start + sign * i * run, start + sign * (i + 1) * run
            if horizontal:
                self.deco(a, y_base, z0, b, y_base + (i + 1) * h, z1, tex)
            else:
                self.deco(x0, y_base, a, x1, y_base + (i + 1) * h, b, tex)
        r0, r1, end = start - sign * run / 2, start + sign * (length - run / 2), start + sign * length
        if horizontal:
            self.world.append(wedge(min(r0, r1), max(r0, r1), z0, z1, y_base, y_base + rise, rise_dir, CLIP))
            self.world.append(box(r1, y_base, z0, end, y_base + rise, z1, CLIP))
        else:
            self.world.append(wedge(x0, x1, min(r0, r1), max(r0, r1), y_base, y_base + rise, rise_dir, CLIP))
            self.world.append(box(x0, y_base, r1, x1, y_base + rise, end, CLIP))

    def rail(self, x0, z0, x1, z1, y, h=1.0, tex=METAL, glow=CYAN):
        """Gelaender (0,3 m dick) von (x0, z0) nach (x1, z1) auf Hoehe y, achsenparallel."""
        if abs(x1 - x0) >= abs(z1 - z0):
            self.solid(x0, y, z0 - 0.15, x1, y + h, z0 + 0.15, tex)
            if glow:
                self.deco(x0, y + h, z0 - 0.15, x1, y + h + 0.06, z0 + 0.15, glow)
        else:
            self.solid(x0 - 0.15, y, z0, x0 + 0.15, y + h, z1, tex)
            if glow:
                self.deco(x0 - 0.15, y + h, z0, x0 + 0.15, y + h + 0.06, z1, glow)

    def room(self, x0, z0, x1, z1, y0, y1, doors=(), tex=WALL):
        """Vier Waende; doors = [(Seite 'n'/'s'/'w'/'o', von, bis)] (von/bis entlang der Wand)."""
        x0, x1 = sorted((x0, x1))
        z0, z1 = sorted((z0, z1))
        self.reverb(x0, y0, z0, x1, y1, z1, 'raum')
        sides = {'n': ('x', z0, x0, x1), 's': ('x', z1, x0, x1), 'w': ('z', x0, z0, z1), 'o': ('z', x1, z0, z1)}
        for side, (axis, at, a0, a1) in sides.items():
            door = [d for d in doors if d[0] == side]
            if door:
                self.wall_with_door(axis, at, a0, a1, y0, y1, door[0][1], door[0][2])
            elif axis == 'x':
                self.wall(a0, at - 0.25, a1, at + 0.25, y0, y1, tex)
            else:
                self.wall(at - 0.25, a0, at + 0.25, a1, y0, y1, tex)

    # --- Objekte ---
    def spawn(self, x, y, z, yaw=0.0):
        """Spawnpunkt auf Oberflaeche y; yaw 0 = Blick nach Norden (-Z), 90 = Westen, 180 = Sueden, -90 = Osten."""
        self.spawns.append((x, y + 1.0, z, yaw))

    def item(self, kind, x, y, z):
        self.items.append((kind, x, y + 0.8, z))

    def weapon(self, weapon_id, x, y, z):
        self.weapons.append((weapon_id, x, y + 0.9, z))

    def pad(self, x, y, z, tx, ty, tz, apex=3.0):
        """Jump-Pad auf (x, y, z) mit Landepunkt auf der Oberflaeche (tx, ty, tz)."""
        self.pads.append(((x, y, z), (tx, ty + 0.1, tz), apex))

    def tele(self, x, y, z, tx, ty, tz, yaw=0.0):
        self.teles.append(((x, y, z), (tx, ty + 0.05, tz), yaw))

    def light(self, x, y, z, color, energy=2.5, rng=12.0):
        self.lights.append(((x, y, z), color, energy, rng))

    def void(self, y, half=200.0):
        """Abgrund: alles unter y stirbt (VoidKillZone)."""
        self.zones.append(('void', (0, y - 5, 0), (half * 2, 10, half * 2), 0.0))

    def damage_zone(self, x0, y0, z0, x1, y1, z1, dps, glow=YELLOW):
        """Schadens-Zone (Schlamm, Lava) mit leuchtender Oberflaeche."""
        x0, x1 = sorted((x0, x1))
        y0, y1 = sorted((y0, y1))
        z0, z1 = sorted((z0, z1))
        self.zones.append(('damage', ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), dps))
        self.deco(x0, y1 - 0.15, z0, x1, y1 - 0.1, z1, glow)

    def reverb(self, x0, y0, z0, x1, y1, z1, kind='halle'):
        """Hall-Zone ('raum' = kurz und dicht, 'halle' = lang); Raeume gewinnen in einer Halle."""
        x0, x1 = sorted((x0, x1))
        y0, y1 = sorted((y0, y1))
        z0, z1 = sorted((z0, z1))
        self.reverbs.append((((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), 0 if kind == 'raum' else 1))

    def crate(self, x, y, z, yaw=0.0):
        """Zerstoerbare Kiste (1 m) auf Oberflaeche y. Nicht in Laufwege stellen (Bots kennen sie nicht)."""
        self.props.append(('crate', (x, y + 0.5, z), yaw, None))

    def barrel(self, x, y, z):
        """Explosives Fass auf Oberflaeche y."""
        self.props.append(('barrel', (x, y + 0.6, z), 0.0, None))

    def glass(self, x0, y0, z0, x1, y1, z1):
        """Zerbrechliche Glasscheibe als duenner Quader (eine Seite duenn, z. B. Fenster in einer Wand)."""
        x0, x1 = sorted((x0, x1))
        y0, y1 = sorted((y0, y1))
        z0, z1 = sorted((z0, z1))
        sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
        # Die Scheibe ist im Spiel in lokaler Z-Richtung duenn: duenn in X -> um 90 Grad drehen
        yaw, size = (90.0, (sz, sy, sx)) if sx < sz else (0.0, (sx, sy, sz))
        self.props.append(('glass', ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), yaw, size))

    def fog_volume(self, x0, y0, z0, x1, y1, z1, color=(0.5, 0.4, 0.9), density=0.08, glow=0.0):
        """Volumetrischer Nebel in einem Quader (Bodennebel, Dunst), optional selbstleuchtend."""
        x0, x1 = sorted((x0, x1))
        y0, y1 = sorted((y0, y1))
        z0, z1 = sorted((z0, z1))
        self.fogs.append((((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), color, density, glow))

    # --- Ausgabe ---
    def write(self, build=True):
        map_path = os.path.join(ROOT, 'maps', self.map_id + '.map')
        with open(map_path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(f'// Game: Generic\n// Format: Standard\n// Erzeugt von tools/maps/{self.map_id}.py (tools/mapkit.py)\n')
            f.write('{\n"classname" "worldspawn"\n' + ''.join(self.world) + '}\n')
            f.write('{\n"classname" "func_detail_illusionary"\n' + ''.join(self.details) + '}\n')
        template = os.path.join(ROOT, 'levels', self.map_id + '_template.tscn')
        with open(template, 'w', encoding='utf-8', newline='\n') as f:
            f.write(self._scene())
        print(f'{self.map_id}: {len(self.world)} Brushes Welt, {len(self.details)} Deko, {len(self.spawns)} Spawns, '
              f'{len(self.items) + len(self.weapons)} Items, {len(self.pads)} Jump-Pads, {len(self.teles)} Teleporter, '
              f'{len(self.props)} Objekte, {len(self.reverbs)} Hall-Zonen, {len(self.fogs)} Nebel')
        if build:
            subprocess.run([GODOT, '--headless', '--path', ROOT, '--import'], check=True, capture_output=True)
            res = subprocess.run([GODOT, '--headless', '--path', ROOT, '-s', 'res://tools/build_level.gd', '--',
                                  f'res://levels/{self.map_id}_template.tscn', f'res://levels/{self.map_id}.tscn'],
                                 capture_output=True, text=True)
            print('\n'.join(l for l in res.stdout.splitlines() if 'Gespeichert' in l or 'Map gebaut' in l))
            if res.returncode != 0:
                raise SystemExit(res.stdout + res.stderr)

    def _scene(self):
        horizon, glow, nebula = self.sky
        ext = [
            ('Script', 'res://scripts/levels/arena.gd', '1_arena'),
            ('PackedScene', 'res://scenes/player.tscn', '2_player'),
            ('PackedScene', 'res://scenes/items/jump_pad.tscn', '3_pad'),
            ('PackedScene', 'res://scenes/items/teleporter.tscn', '4_tele'),
            ('PackedScene', 'res://scenes/items/weapon_pickup.tscn', '5_wpick'),
            ('Shader', 'res://assets/shaders/space_sky.gdshader', '6_sky'),
            ('Script', 'res://addons/func_godot/src/map/func_godot_map.gd', '7_map'),
            ('Resource', 'res://resources/map/neon_map_settings.tres', '8_settings'),
            ('Script', 'res://scripts/levels/void_kill_zone.gd', '9_void'),
            ('Script', 'res://scripts/levels/damage_zone.gd', '10_damage'),
            ('Script', 'res://scripts/levels/reverb_zone.gd', '11_reverb'),
            ('PackedScene', 'res://scenes/props/physics_crate.tscn', '12_crate'),
            ('PackedScene', 'res://scenes/props/physics_barrel.tscn', '13_barrel'),
            ('Script', 'res://scripts/props/glass_pane.gd', '14_glass'),
        ]
        ext += [('PackedScene', f'res://scenes/items/{scene}.tscn', f'item_{kind}') for kind, scene in ITEM_SCENES.items()]
        ext += [('PackedScene', f'res://scenes/weapons/{scene}.tscn', f'w_{wid}') for wid, (scene, _, _) in WEAPONS.items()]
        out = ['[gd_scene format=3]\n']
        for kind, path, rid in ext:
            uid = ' uid="uid://bplayer_character_001"' if rid == '2_player' else ''
            out.append(f'[ext_resource type="{kind}"{uid} path="{path}" id="{rid}"]')
        out.append(f'''
[sub_resource type="ShaderMaterial" id="SkyMat"]
shader = ExtResource("6_sky")
shader_parameter/zenith_color = Color(0.01, 0.015, 0.04, 1)
shader_parameter/horizon_color = Color({horizon[0]}, {horizon[1]}, {horizon[2]}, 1)
shader_parameter/horizon_glow = Color({glow[0]}, {glow[1]}, {glow[2]}, 1)
shader_parameter/nebula_color = Color({nebula[0]}, {nebula[1]}, {nebula[2]}, 1)
shader_parameter/star_density = 0.5
shader_parameter/star_brightness = 6.0
shader_parameter/nebula_strength = 0.4

[sub_resource type="Sky" id="Sky_1"]
sky_material = SubResource("SkyMat")

[sub_resource type="Environment" id="Environment_1"]
background_mode = 2
sky = SubResource("Sky_1")
ambient_light_source = 2
ambient_light_color = Color(0.25, 0.28, 0.35, 1)
ambient_light_energy = 0.8
tonemap_mode = 4
tonemap_exposure = 1.1
ssao_enabled = true
ssao_radius = 1.5
ssao_intensity = 1.6
glow_enabled = true
glow_intensity = 0.7
glow_strength = 1.1
glow_bloom = 0.05
glow_hdr_threshold = 0.9
volumetric_fog_enabled = true
volumetric_fog_density = {self.fog}
volumetric_fog_albedo = Color(0.6, 0.55, 0.85, 1)
volumetric_fog_anisotropy = 0.4
adjustment_enabled = true
adjustment_contrast = 1.08
adjustment_saturation = 1.15

[sub_resource type="NavigationMesh" id="NavigationMesh_1"]
geometry_parsed_geometry_type = 1
agent_height = 1.75
agent_radius = 0.5
agent_max_climb = 0.5
agent_max_slope = 45.0
''')
        for i, (kind, _, size, _) in enumerate(self.zones):
            out.append(f'[sub_resource type="BoxShape3D" id="Zone{i}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\n')
        for i, (_, size, _) in enumerate(self.reverbs):
            out.append(f'[sub_resource type="BoxShape3D" id="Reverb{i}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\n')
        for i, (_, _, c, density, glow) in enumerate(self.fogs):
            out.append(f'[sub_resource type="FogMaterial" id="Fog{i}"]\ndensity = {density}\nalbedo = Color({c[0]}, {c[1]}, {c[2]}, 1)\n'
                       f'emission = Color({c[0] * glow}, {c[1] * glow}, {c[2] * glow}, 1)\nedge_fade = 0.4\n')
        out.append(f'''[node name="{self.node_name}" type="Node3D"]
script = ExtResource("1_arena")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_1")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 25, 0)
light_color = Color(0.85, 0.9, 1, 1)
light_energy = 0.8
shadow_enabled = true

[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("NavigationMesh_1")

[node name="Map" type="Node3D" parent="NavigationRegion3D"]
script = ExtResource("7_map")
local_map_file = "res://maps/{self.map_id}.map"
map_settings = ExtResource("8_settings")

[node name="SpawnPoints" type="Node3D" parent="."]
''')
        for i, (x, y, z, yaw) in enumerate(self.spawns, start=1):
            out.append(f'[node name="SpawnPoint{i}" type="Marker3D" parent="SpawnPoints"]\ntransform = {_tf(x, y, z, yaw)}\n')
        x, y, z, yaw = self.spawns[0]
        out.append(f'[node name="Player" parent="." instance=ExtResource("2_player")]\ntransform = {_tf(x, y, z, yaw)}\n')
        out.append('[node name="Items" type="Node3D" parent="."]\n')
        for i, (kind, x, y, z) in enumerate(self.items, start=1):
            out.append(f'[node name="{kind.capitalize()}{i}" parent="Items" instance=ExtResource("item_{kind}")]\ntransform = {_tf(x, y, z)}\n')
        for i, (wid, x, y, z) in enumerate(self.weapons, start=1):
            _, label, c = WEAPONS[wid]
            name = f'Weapon{i}'
            out.append(f'[node name="{name}" parent="Items" instance=ExtResource("5_wpick")]\ntransform = {_tf(x, y, z)}\n'
                       f'weapon_id = &"{wid}"\nweapon_scene = ExtResource("w_{wid}")\ndisplay_name = "{label}"\n')
            out.append(f'[node name="OmniLight3D" parent="Items/{name}" index="4"]\nlight_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\n')
        out.append('[node name="JumpPads" type="Node3D" parent="."]\n')
        for i, (pos, target, apex) in enumerate(self.pads, start=1):
            out.append(f'[node name="Pad{i}Target" type="Marker3D" parent="JumpPads"]\ntransform = {_tf(*target)}\n')
            out.append(f'[node name="Pad{i}" parent="JumpPads" node_paths=PackedStringArray("target") instance=ExtResource("3_pad")]\n'
                       f'transform = {_tf(*pos)}\ntarget = NodePath("../Pad{i}Target")\napex_height = {apex}\n')
        out.append('[node name="Teleporters" type="Node3D" parent="."]\n')
        for i, (pos, target, yaw) in enumerate(self.teles, start=1):
            out.append(f'[node name="Tele{i}Exit" type="Marker3D" parent="Teleporters"]\ntransform = {_tf(*target, yaw)}\n')
            out.append(f'[node name="Tele{i}" parent="Teleporters" node_paths=PackedStringArray("target") instance=ExtResource("4_tele")]\n'
                       f'transform = {_tf(*pos)}\ntarget = NodePath("../Tele{i}Exit")\n')
        out.append('[node name="Lights" type="Node3D" parent="."]\n')
        for i, (pos, c, energy, rng) in enumerate(self.lights, start=1):
            out.append(f'[node name="Light{i}" type="OmniLight3D" parent="Lights"]\ntransform = {_tf(*pos)}\n'
                       f'light_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nlight_energy = {energy}\n'
                       f'light_volumetric_fog_energy = 2.0\nomni_range = {rng}\n')
        for i, (kind, center, _, dps) in enumerate(self.zones):
            script = '9_void' if kind == 'void' else '10_damage'
            extra = f'damage_per_second = {dps}\n' if kind == 'damage' else ''
            out.append(f'[node name="Zone{i}" type="Area3D" parent="."]\ntransform = {_tf(*center)}\nscript = ExtResource("{script}")\n{extra}')
            out.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Zone{i}"]\nshape = SubResource("Zone{i}")\n')
        out.append('[node name="ReverbZones" type="Node3D" parent="."]\n')
        for i, (center, _, kind) in enumerate(self.reverbs):
            out.append(f'[node name="Reverb{i}" type="Area3D" parent="ReverbZones"]\ntransform = {_tf(*center)}\nscript = ExtResource("11_reverb")\nkind = {kind}\n')
            out.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="ReverbZones/Reverb{i}"]\nshape = SubResource("Reverb{i}")\n')
        out.append('[node name="Props" type="Node3D" parent="."]\n')
        for i, (kind, pos, yaw, size) in enumerate(self.props, start=1):
            if kind == 'glass':
                out.append(f'[node name="Glass{i}" type="StaticBody3D" parent="Props"]\ntransform = {_tf(*pos, yaw)}\nscript = ExtResource("14_glass")\n'
                           f'size = Vector3({size[0]}, {size[1]}, {size[2]})\n')
            else:
                rid = '12_crate' if kind == 'crate' else '13_barrel'
                out.append(f'[node name="{kind.capitalize()}{i}" parent="Props" instance=ExtResource("{rid}")]\ntransform = {_tf(*pos, yaw)}\n')
        out.append('[node name="FogVolumes" type="Node3D" parent="."]\n')
        for i, (center, size, _, _, _) in enumerate(self.fogs):
            out.append(f'[node name="Fog{i}" type="FogVolume" parent="FogVolumes"]\ntransform = {_tf(*center)}\n'
                       f'size = Vector3({size[0]}, {size[1]}, {size[2]})\nshape = 3\nmaterial = SubResource("Fog{i}")\n')
        return '\n'.join(out)
