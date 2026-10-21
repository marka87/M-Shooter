"""Erzeugt die Waffenmodelle scenes/weapons/models/<waffe>.tscn aus den Quaternius-Modellen (CC0).

Jede Szene instanziert ein GLB aus assets/weapons/quaternius/ und haengt scripts/weapons/weapon_model.gd an.
Das Skript dreht den Lauf nach -Z, skaliert auf die Laenge und setzt die Laufspitze kurz vor den
Muzzle-Knoten der Waffenszene. Das orange Akzent-Material leuchtet in der Waffenfarbe
(wie in resources/weapons/*.tres).

Aufruf aus dem Projektordner:  python tools/make_weapon_models.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'scenes', 'weapons', 'models')

# Waffe: (Modell, Waffenfarbe, Laufspitze z, Laenge, Mitte y). Laufspitze 3 cm vor dem Muzzle der Waffenszene,
# Laenge = Muzzle-Abstand + kurzer Schaft (laengere Schaefte ragen in der Ego-Sicht in die Kamera)
WEAPONS = {
    'machine_gun': ('scifi_smg', (1, 0.75, 0.25), -0.59, 0.65, -0.02),
    'shotgun': ('scifi_assault_b', (1, 0.55, 0.15), -0.62, 0.67, -0.01),
    'plasma_gun': ('scifi_ar', (0.25, 0.75, 1), -0.59, 0.65, -0.03),
    'rocket_launcher': ('scifi_grenade_launcher', (1, 0.4, 0.1), -0.62, 0.69, -0.02),
    'lightning_gun': ('scifi_assault_a', (0.7, 0.9, 1), -0.55, 0.61, -0.03),
    'railgun': ('scifi_sniper_b', (0.3, 1, 0.9), -0.82, 0.89, -0.01),
    'shock_rifle': ('scifi_sniper_a', (0.6, 0.35, 1), -0.75, 0.82, -0.02),
}


def build(name, model, color, front_z, length, center_y):
    r, g, b = color
    node = ''.join(w.capitalize() for w in name.split('_')) + 'Model'
    return (f'[gd_scene format=3]\n\n'
            f'[ext_resource type="Script" path="res://scripts/weapons/weapon_model.gd" id="1_model"]\n'
            f'[ext_resource type="PackedScene" path="res://assets/weapons/quaternius/{model}.glb" id="2_mesh"]\n\n'
            f'[node name="{node}" type="Node3D"]\nscript = ExtResource("1_model")\n'
            f'glow_color = Color({r}, {g}, {b}, 1)\nfront_z = {front_z}\nlength = {length}\ncenter_y = {center_y}\n\n'
            f'[node name="Mesh" parent="." instance=ExtResource("2_mesh")]\n')


if __name__ == '__main__':
    for name, args in WEAPONS.items():
        assert os.path.exists(os.path.join(ROOT, 'assets', 'weapons', 'quaternius', args[0] + '.glb')), args[0]
        with open(os.path.join(OUT_DIR, name + '.tscn'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(build(name, *args))
        print(name, '->', args[0])
