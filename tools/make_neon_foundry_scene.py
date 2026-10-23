"""Erzeugt die Vorlage levels/neon_foundry_template.tscn (Umgebung, Navmesh, Spawns, Items, Jump-Pads,
FuncGodotMap). Danach baut tools/build_level.gd die Map-Geometrie ein und speichert levels/neon_foundry.tscn.

Aufruf aus dem Projektordner:  python tools/make_neon_foundry_scene.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'levels', 'neon_foundry_template.tscn')


def tf(x, y, z, yaw_deg=0.0):
    c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    return f'Transform3D({c:.6f}, 0, {s:.6f}, 0, 1, 0, {-s:.6f}, 0, {c:.6f}, {x}, {y}, {z})'


# Spawnpunkte (Fusshoehe + 1 m), Blickrichtung zur Mitte
SPAWNS = [
    (0, 1.0, 28, 0), (0, 1.0, -28, 180), (28, 1.0, 10, 90), (-28, 1.0, -10, -90),
    (0, 5.0, -28.5, 180), (0, 5.0, 28.5, 0), (23, 9.0, -23, 135), (-23, 9.0, 23, -45),
]
# Items: (Name, Szene, x, y, z)  y = Oberflaeche + 0.8
ITEMS = [
    ('QuadCenter', 'quad', 0, 4.9, 0),
    ('HealthUnder', 'health', 0, 0.8, 0),
    ('AmmoTowerNE', 'ammo', 27, 8.8, -27),
    ('MegaTowerSW', 'mega', -27, 8.9, 27),
    ('ArmorTowerNE', 'armor', 27, 8.8, -22),
    ('HealthRingN', 'health', -20, 4.8, -28.5),
    ('AmmoRingS', 'ammo', 20, 4.8, 28.5),
    ('HealthPassageE', 'health', 21.5, 0.8, 0),
    ('HealthPassageW', 'health', -21.5, 0.8, 0),
    ('AmmoGroundN', 'ammo', 0, 0.8, -20),
    ('AmmoGroundS', 'ammo', 0, 0.8, 20),
]
# Waffen-Pickups: (Name, Waffen-ID, Waffenszene, Anzeigename, Farbe, x, y, z)
WEAPONS = [
    ('PlasmaRingN', 'plasma', 'plasma_gun', 'Plasma', (0.25, 0.75, 1), -5, 4.9, -28.5),
    ('LightningGroundE', 'lightning', 'lightning_gun', 'Lightning Gun', (0.7, 0.9, 1), 28, 0.9, -6),
    ('ShockRingS', 'shock_rifle', 'shock_rifle', 'Shock Rifle', (0.6, 0.35, 1), -4, 4.9, 28.5),
    ('RailRingW', 'railgun', 'railgun', 'Railgun', (0.3, 1, 0.9), -28.5, 4.9, -16),
    ('RocketGroundW', 'rocket_launcher', 'rocket_launcher', 'Raketenwerfer', (1, 0.4, 0.1), -28, 0.9, 6),
]
# Teleporter: (Name, Position, Ziel, Blickrichtung am Ziel in Grad um die Hochachse)
# 0 Grad = Blick nach -Z (Norden), 90 = Westen, -90 = Osten, 180 = Sueden
TELEPORTERS = [
    ('TeleNW', (-28, 0, -24), (28, 4.05, 8), 90),    # Boden Nordwest -> Ost-Ring, Blick nach Westen
    ('TeleSE', (28, 0, 24), (-28, 4.05, -8), -90),   # Boden Suedost -> West-Ring, Blick nach Osten
]
# Jump-Pads: (Name, Pad-Position, Ziel, Scheitelhoehe)
PADS = [
    ('PadTowerNE', (22, 0, -12), (25.5, 8.1, -25.5), 3.0),
    ('PadTowerSW', (-22, 0, 12), (-25.5, 8.1, 25.5), 3.0),
    ('PadCenter', (0, 0, 10), (0, 4.1, 1.5), 2.5),
]
# Akzentlichter: (Name, Position, Farbe, Energie, Reichweite)
LIGHTS = [
    ('LightCenter', (0, 7, 0), (1, 0.25, 0.8), 3.0, 14),
    ('LightTowerNE', (25.5, 11, -25.5), (1, 0.25, 0.8), 3.0, 12),
    ('LightTowerSW', (-25.5, 11, 25.5), (1, 0.25, 0.8), 3.0, 12),
    ('LightPassageE', (21.5, 2.5, 0), (0.2, 0.85, 1), 2.0, 9),
    ('LightPassageW', (-21.5, 2.5, 0), (0.2, 0.85, 1), 2.0, 9),
]

head = '''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/levels/arena.gd" id="1_arena"]
[ext_resource type="PackedScene" uid="uid://bplayer_character_001" path="res://scenes/player.tscn" id="2_player"]
[ext_resource type="PackedScene" uid="uid://ammo_pickup_001" path="res://scenes/items/ammo_pickup.tscn" id="4_ammo"]
[ext_resource type="PackedScene" uid="uid://health_pickup_001" path="res://scenes/items/health_pickup.tscn" id="5_health"]
[ext_resource type="PackedScene" uid="uid://armor_pickup_001" path="res://scenes/items/armor_pickup.tscn" id="6_armor"]
[ext_resource type="PackedScene" path="res://scenes/items/jump_pad.tscn" id="8_pad"]
[ext_resource type="PackedScene" path="res://scenes/items/quad_damage_pickup.tscn" id="12_quad"]
[ext_resource type="PackedScene" path="res://scenes/items/mega_health_pickup.tscn" id="13_mega"]
[ext_resource type="PackedScene" path="res://scenes/items/weapon_pickup.tscn" id="14_wpick"]
[ext_resource type="PackedScene" path="res://scenes/items/teleporter.tscn" id="18_tele"]
[ext_resource type="PackedScene" path="res://scenes/weapons/plasma_gun.tscn" id="15_plasma"]
[ext_resource type="PackedScene" path="res://scenes/weapons/lightning_gun.tscn" id="16_lightning_gun"]
[ext_resource type="PackedScene" path="res://scenes/weapons/shock_rifle.tscn" id="17_shock_rifle"]
[ext_resource type="PackedScene" path="res://scenes/weapons/railgun.tscn" id="19_railgun"]
[ext_resource type="PackedScene" path="res://scenes/weapons/rocket_launcher.tscn" id="20_rocket"]
[ext_resource type="Shader" path="res://assets/shaders/space_sky.gdshader" id="9_sky"]
[ext_resource type="Script" path="res://addons/func_godot/src/map/func_godot_map.gd" id="10_map"]
[ext_resource type="Resource" path="res://resources/map/neon_map_settings.tres" id="11_settings"]

[sub_resource type="ShaderMaterial" id="SkyMat"]
shader = ExtResource("9_sky")
shader_parameter/zenith_color = Color(0.01, 0.015, 0.04, 1)
shader_parameter/horizon_color = Color(0.14, 0.06, 0.18, 1)
shader_parameter/horizon_glow = Color(1, 0.25, 0.6, 1)
shader_parameter/nebula_color = Color(0.5, 0.25, 0.9, 1)
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
volumetric_fog_density = 0.014
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

[node name="NeonFoundry" type="Node3D"]
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
script = ExtResource("10_map")
local_map_file = "res://maps/neon_foundry.map"
map_settings = ExtResource("11_settings")

[node name="SpawnPoints" type="Node3D" parent="."]

'''
body = ''
for i, (x, y, z, yaw) in enumerate(SPAWNS, start=1):
    body += f'[node name="SpawnPoint{i}" type="Marker3D" parent="SpawnPoints"]\ntransform = {tf(x, y, z, yaw)}\n\n'
x, y, z, yaw = SPAWNS[0]
body += f'[node name="Player" parent="." instance=ExtResource("2_player")]\ntransform = {tf(x, y, z, yaw)}\n\n'

body += '[node name="Items" type="Node3D" parent="."]\n\n'
res = {'ammo': '4_ammo', 'health': '5_health', 'armor': '6_armor', 'quad': '12_quad', 'mega': '13_mega'}
for name, kind, x, y, z in ITEMS:
    body += f'[node name="{name}" parent="Items" instance=ExtResource("{res[kind]}")]\ntransform = {tf(x, y, z)}\n\n'

wscene = {'plasma_gun': '15_plasma', 'lightning_gun': '16_lightning_gun', 'shock_rifle': '17_shock_rifle',
          'railgun': '19_railgun', 'rocket_launcher': '20_rocket'}
for name, wid, scene, label, c, x, y, z in WEAPONS:
    body += (f'[node name="{name}" parent="Items" instance=ExtResource("14_wpick")]\ntransform = {tf(x, y, z)}\n'
             f'weapon_id = &"{wid}"\nweapon_scene = ExtResource("{wscene[scene]}")\ndisplay_name = "{label}"\n\n'
             f'[node name="OmniLight3D" parent="Items/{name}" index="4"]\nlight_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\n\n')

body += '[node name="JumpPads" type="Node3D" parent="."]\n\n'
for name, pos, target, apex in PADS:
    body += f'[node name="{name}Target" type="Marker3D" parent="JumpPads"]\ntransform = {tf(*target)}\n\n'
for name, pos, target, apex in PADS:
    body += (f'[node name="{name}" parent="JumpPads" node_paths=PackedStringArray("target") instance=ExtResource("8_pad")]\n'
             f'transform = {tf(*pos)}\ntarget = NodePath("../{name}Target")\napex_height = {apex}\n\n')

body += '[node name="Teleporters" type="Node3D" parent="."]\n\n'
for name, pos, target, yaw in TELEPORTERS:
    body += f'[node name="{name}Exit" type="Marker3D" parent="Teleporters"]\ntransform = {tf(*target, yaw)}\n\n'
for name, pos, target, yaw in TELEPORTERS:
    body += (f'[node name="{name}" parent="Teleporters" node_paths=PackedStringArray("target") instance=ExtResource("18_tele")]\n'
             f'transform = {tf(*pos)}\ntarget = NodePath("../{name}Exit")\n\n')

body += '[node name="Lights" type="Node3D" parent="."]\n\n'
for name, pos, c, energy, rng in LIGHTS:
    body += (f'[node name="{name}" type="OmniLight3D" parent="Lights"]\ntransform = {tf(*pos)}\n'
             f'light_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nlight_energy = {energy}\n'
             f'light_volumetric_fog_energy = 2.0\nomni_range = {rng}\n\n')

with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write(head + body.rstrip() + '\n')
print('Vorlage geschrieben:', OUT)
