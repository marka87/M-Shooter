"""Erzeugt die Neon-Materialien fuer func_godot-Maps und passende Vorschaubilder fuer TrenchBroom.

Aufruf aus dem Projektordner:  python tools/make_map_materials.py

- assets/map_materials/neon/<name>.tres  -> Materialien, die Godot beim Map-Build verwendet
- assets/map_textures/neon/<name>.png    -> einfarbige Vorschaubilder, damit TrenchBroom die Texturen anzeigt
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAT_DIR = os.path.join(ROOT, 'assets', 'map_materials', 'neon')
TEX_DIR = os.path.join(ROOT, 'assets', 'map_textures', 'neon')

# Raster-Materialien (arena_grid.gdshader): Grundfarbe, Linienfarbe, Zellgroesse, Leuchtkraft
GRID = {
    'floor':   ((0.05, 0.11, 0.13), (0.1, 0.7, 0.9), 4.0, 0.45, 0.012),
    'wall':    ((0.06, 0.12, 0.10), (0.2, 1.0, 0.55), 4.0, 0.35, 0.012),
    'walkway': ((0.30, 0.10, 0.03), (1.0, 0.45, 0.08), 2.0, 0.35, 0.02),
    'metal':   ((0.05, 0.13, 0.15), (0.2, 0.75, 1.0), 1.0, 0.30, 0.012),
    'accent':  ((0.18, 0.04, 0.16), (1.0, 0.2, 0.8), 2.0, 0.40, 0.015),
}
# Leuchtstreifen (unbeleuchtet, stark emissiv)
GLOW = {
    'glow_cyan':    (0.2, 0.85, 1.0),
    'glow_magenta': (1.0, 0.2, 0.8),
    'glow_yellow':  (1.0, 0.85, 0.15),
    'glow_orange':  (1.0, 0.45, 0.05),
}


def col(c):
    return f'Color({c[0]}, {c[1]}, {c[2]}, 1)'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def preview(name, base, line=None):
    img = Image.new('RGB', (64, 64), tuple(int(v * 255) for v in base))
    if line:
        d = ImageDraw.Draw(img)
        lc = tuple(int(v * 255) for v in line)
        d.rectangle([0, 0, 63, 63], outline=lc)
    os.makedirs(TEX_DIR, exist_ok=True)
    img.save(os.path.join(TEX_DIR, name + '.png'))


for name, (base, line, cell, emission, width) in GRID.items():
    write(os.path.join(MAT_DIR, name + '.tres'), f'''[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://assets/shaders/arena_grid.gdshader" id="1_grid"]

[resource]
render_priority = 0
shader = ExtResource("1_grid")
shader_parameter/base_color = {col(base)}
shader_parameter/line_color = {col(line)}
shader_parameter/cell_size = {cell}
shader_parameter/line_width = {width}
shader_parameter/line_emission = {emission}
shader_parameter/major_every = 5
shader_parameter/roughness_value = 0.5
shader_parameter/metallic_value = 0.3
''')
    preview(name, base, line)

for name, c in GLOW.items():
    write(os.path.join(MAT_DIR, name + '.tres'), f'''[gd_resource type="StandardMaterial3D" format=3]

[resource]
shading_mode = 0
albedo_color = {col(c)}
emission_enabled = true
emission = {col(c)}
emission_energy_multiplier = 4.0
''')
    preview(name, c)

# Clip-Flaechen: nur Vorschaubild (Godot entfernt sie aus der Optik, behaelt die Kollision)
img = Image.new('RGBA', (64, 64), (255, 80, 80, 90))
ImageDraw.Draw(img).line([0, 0, 63, 63], fill=(255, 255, 255, 200), width=2)
img.save(os.path.join(TEX_DIR, '..', 'clip.png'))
print('Materialien und Vorschaubilder erzeugt.')
