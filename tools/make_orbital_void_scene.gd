extends SceneTree

## Erzeugt levels/orbital_void.tscn
## Aufruf: Godot_console.exe --headless -s tools/make_orbital_void_scene.gd

func _initialize() -> void:
	var out_path := "res://levels/orbital_void.tscn"
	var root_node := Node3D.new()
	root_node.name = "OrbitalVoid"
	root_node.set_script(load("res://scripts/levels/arena.gd"))

	# Speichern testen ueber PackedScene oder Text
	# Wir bauen die Datei als saubere .tscn Textdatei
	var lines: Array[String] = []
	lines.append('[gd_scene load_steps=38 format=3 uid="uid://orbital_void_001"]')
	lines.append('')
	lines.append('[ext_resource type="Script" path="res://scripts/levels/arena.gd" id="1_arena"]')
	lines.append('[ext_resource type="PackedScene" uid="uid://bplayer_character_001" path="res://scenes/player.tscn" id="2_player"]')
	lines.append('[ext_resource type="PackedScene" uid="uid://ammo_pickup_001" path="res://scenes/items/ammo_pickup.tscn" id="4_ammo"]')
	lines.append('[ext_resource type="PackedScene" uid="uid://health_pickup_001" path="res://scenes/items/health_pickup.tscn" id="5_health"]')
	lines.append('[ext_resource type="PackedScene" uid="uid://armor_pickup_001" path="res://scenes/items/armor_pickup.tscn" id="6_armor"]')
	lines.append('[ext_resource type="Shader" path="res://assets/shaders/arena_grid.gdshader" id="7_grid"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/items/jump_pad.tscn" id="8_pad"]')
	lines.append('[ext_resource type="Shader" path="res://assets/shaders/space_sky.gdshader" id="9_sky"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/items/quad_damage_pickup.tscn" id="10_quad"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/items/mega_health_pickup.tscn" id="11_mega"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/items/weapon_pickup.tscn" id="12_wpick"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/weapons/railgun.tscn" id="13_rail"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/weapons/rocket_launcher.tscn" id="14_rpg"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/weapons/plasma_gun.tscn" id="15_plasma"]')
	lines.append('[ext_resource type="PackedScene" path="res://scenes/weapons/lightning_gun.tscn" id="16_lg"]')
	lines.append('[ext_resource type="Script" path="res://scripts/levels/void_kill_zone.gd" id="17_void"]')
	lines.append('[ext_resource type="PackedScene" uid="uid://physics_barrel_001" path="res://scenes/props/physics_barrel.tscn" id="18_barrel"]')
	lines.append('[ext_resource type="PackedScene" uid="uid://physics_crate_001" path="res://scenes/props/physics_crate.tscn" id="19_crate"]')
	lines.append('')

	# Sky Material & Environment
	lines.append('[sub_resource type="ShaderMaterial" id="ShaderMaterial_Sky"]')
	lines.append('shader = ExtResource("9_sky")')
	lines.append('shader_parameter/zenith_color = Color(0.01, 0.012, 0.035, 1)')
	lines.append('shader_parameter/horizon_color = Color(0.12, 0.05, 0.22, 1)')
	lines.append('shader_parameter/horizon_glow = Color(0.85, 0.2, 1, 1)')
	lines.append('shader_parameter/nebula_color = Color(0.25, 0.65, 1, 1)')
	lines.append('shader_parameter/star_density = 0.65')
	lines.append('shader_parameter/star_brightness = 7.0')
	lines.append('shader_parameter/nebula_strength = 0.55')
	lines.append('')
	lines.append('[sub_resource type="Sky" id="Sky_1"]')
	lines.append('sky_material = SubResource("ShaderMaterial_Sky")')
	lines.append('')
	lines.append('[sub_resource type="Environment" id="Environment_1"]')
	lines.append('background_mode = 2')
	lines.append('sky = SubResource("Sky_1")')
	lines.append('ambient_light_source = 2')
	lines.append('ambient_light_color = Color(0.25, 0.26, 0.38, 1)')
	lines.append('ambient_light_energy = 0.9')
	lines.append('tonemap_mode = 4')
	lines.append('tonemap_exposure = 1.15')
	lines.append('ssao_enabled = true')
	lines.append('ssao_radius = 1.8')
	lines.append('ssao_intensity = 1.5')
	lines.append('glow_enabled = true')
	lines.append('glow_intensity = 0.8')
	lines.append('glow_strength = 1.1')
	lines.append('glow_bloom = 0.08')
	lines.append('glow_hdr_threshold = 0.85')
	lines.append('volumetric_fog_enabled = true')
	lines.append('volumetric_fog_density = 0.008')
	lines.append('volumetric_fog_albedo = Color(0.4, 0.3, 0.7, 1)')
	lines.append('adjustment_enabled = true')
	lines.append('adjustment_contrast = 1.1')
	lines.append('adjustment_saturation = 1.15')
	lines.append('')

	# NavigationMesh
	lines.append('[sub_resource type="NavigationMesh" id="NavigationMesh_1"]')
	lines.append('geometry_parsed_geometry_type = 1')
	lines.append('agent_height = 1.75')
	lines.append('agent_radius = 0.5')
	lines.append('agent_max_climb = 0.5')
	lines.append('agent_max_slope = 45.0')
	lines.append('')

	# Materials for Platforms
	lines.append('[sub_resource type="ShaderMaterial" id="Mat_MainBase"]')
	lines.append('render_priority = 0')
	lines.append('shader = ExtResource("7_grid")')
	lines.append('shader_parameter/base_color = Color(0.04, 0.06, 0.1, 1)')
	lines.append('shader_parameter/line_color = Color(0.15, 0.75, 1, 1)')
	lines.append('shader_parameter/cell_size = 3.0')
	lines.append('shader_parameter/line_width = 0.015')
	lines.append('shader_parameter/line_emission = 0.5')
	lines.append('shader_parameter/major_every = 4')
	lines.append('shader_parameter/roughness_value = 0.5')
	lines.append('shader_parameter/metallic_value = 0.35')
	lines.append('')

	lines.append('[sub_resource type="ShaderMaterial" id="Mat_MainUpper"]')
	lines.append('render_priority = 0')
	lines.append('shader = ExtResource("7_grid")')
	lines.append('shader_parameter/base_color = Color(0.08, 0.05, 0.12, 1)')
	lines.append('shader_parameter/line_color = Color(0.95, 0.35, 0.9, 1)')
	lines.append('shader_parameter/cell_size = 2.5')
	lines.append('shader_parameter/line_width = 0.015')
	lines.append('shader_parameter/line_emission = 0.5')
	lines.append('shader_parameter/major_every = 4')
	lines.append('shader_parameter/roughness_value = 0.45')
	lines.append('shader_parameter/metallic_value = 0.4')
	lines.append('')

	lines.append('[sub_resource type="ShaderMaterial" id="Mat_Spire"]')
	lines.append('render_priority = 0')
	lines.append('shader = ExtResource("7_grid")')
	lines.append('shader_parameter/base_color = Color(0.12, 0.04, 0.06, 1)')
	lines.append('shader_parameter/line_color = Color(1, 0.35, 0.2, 1)')
	lines.append('shader_parameter/cell_size = 2.0')
	lines.append('shader_parameter/line_width = 0.02')
	lines.append('shader_parameter/line_emission = 0.65')
	lines.append('shader_parameter/major_every = 4')
	lines.append('shader_parameter/roughness_value = 0.4')
	lines.append('shader_parameter/metallic_value = 0.5')
	lines.append('')

	lines.append('[sub_resource type="ShaderMaterial" id="Mat_Flank"]')
	lines.append('render_priority = 0')
	lines.append('shader = ExtResource("7_grid")')
	lines.append('shader_parameter/base_color = Color(0.05, 0.08, 0.07, 1)')
	lines.append('shader_parameter/line_color = Color(0.2, 1, 0.6, 1)')
	lines.append('shader_parameter/cell_size = 2.5')
	lines.append('shader_parameter/line_width = 0.015')
	lines.append('shader_parameter/line_emission = 0.5')
	lines.append('shader_parameter/major_every = 4')
	lines.append('shader_parameter/roughness_value = 0.5')
	lines.append('shader_parameter/metallic_value = 0.35')
	lines.append('')

	lines.append('[sub_resource type="ShaderMaterial" id="Mat_Pillar"]')
	lines.append('render_priority = 0')
	lines.append('shader = ExtResource("7_grid")')
	lines.append('shader_parameter/base_color = Color(0.03, 0.07, 0.1, 1)')
	lines.append('shader_parameter/line_color = Color(0.1, 0.85, 0.8, 1)')
	lines.append('shader_parameter/cell_size = 1.0')
	lines.append('shader_parameter/line_width = 0.015')
	lines.append('shader_parameter/line_emission = 0.35')
	lines.append('shader_parameter/major_every = 6')
	lines.append('shader_parameter/roughness_value = 0.5')
	lines.append('shader_parameter/metallic_value = 0.4')
	lines.append('')

	lines.append('[sub_resource type="StandardMaterial3D" id="Mat_SupportCone"]')
	lines.append('albedo_color = Color(0.05, 0.06, 0.08, 1)')
	lines.append('metallic = 0.7')
	lines.append('roughness = 0.4')
	lines.append('')

	lines.append('[sub_resource type="StandardMaterial3D" id="Mat_NeonCyan"]')
	lines.append('shading_mode = 0')
	lines.append('albedo_color = Color(0.15, 0.75, 1, 1)')
	lines.append('emission_enabled = true')
	lines.append('emission = Color(0.15, 0.75, 1, 1)')
	lines.append('emission_energy_multiplier = 4.0')
	lines.append('')

	# Meshes & Shapes
	lines.append('[sub_resource type="BoxMesh" id="Mesh_MainBase"]')
	lines.append('material = SubResource("Mat_MainBase")')
	lines.append('size = Vector3(26, 1, 26)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_MainBase"]')
	lines.append('size = Vector3(26, 1, 26)')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_MainUpper"]')
	lines.append('material = SubResource("Mat_MainUpper")')
	lines.append('size = Vector3(14, 1.6, 14)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_MainUpper"]')
	lines.append('size = Vector3(14, 1.6, 14)')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_RampFB"]')
	lines.append('material = SubResource("Mat_MainUpper")')
	lines.append('size = Vector3(4, 0.25, 4.8)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_RampFB"]')
	lines.append('size = Vector3(4, 0.25, 4.8)')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_RampLR"]')
	lines.append('material = SubResource("Mat_MainUpper")')
	lines.append('size = Vector3(4.8, 0.25, 4)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_RampLR"]')
	lines.append('size = Vector3(4.8, 0.25, 4)')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_Pillar"]')
	lines.append('material = SubResource("Mat_Pillar")')
	lines.append('size = Vector3(2.2, 6, 2.2)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_Pillar"]')
	lines.append('size = Vector3(2.2, 6, 2.2)')
	lines.append('')

	lines.append('[sub_resource type="TorusMesh" id="Mesh_PillarRing"]')
	lines.append('material = SubResource("Mat_NeonCyan")')
	lines.append('inner_radius = 1.35')
	lines.append('outer_radius = 1.48')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_SpirePlatform"]')
	lines.append('material = SubResource("Mat_Spire")')
	lines.append('size = Vector3(8, 1, 8)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_SpirePlatform"]')
	lines.append('size = Vector3(8, 1, 8)')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_SpirePedestal"]')
	lines.append('material = SubResource("Mat_Spire")')
	lines.append('size = Vector3(2.4, 0.5, 2.4)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_SpirePedestal"]')
	lines.append('size = Vector3(2.4, 0.5, 2.4)')
	lines.append('')

	lines.append('[sub_resource type="CylinderMesh" id="Mesh_SpireColumn"]')
	lines.append('material = SubResource("Mat_SupportCone")')
	lines.append('top_radius = 3.6')
	lines.append('bottom_radius = 1.2')
	lines.append('height = 19')
	lines.append('')
	lines.append('[sub_resource type="CylinderShape3D" id="Shape_SpireColumn"]')
	lines.append('height = 19')
	lines.append('radius = 3.6')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_FlankPlatform"]')
	lines.append('material = SubResource("Mat_Flank")')
	lines.append('size = Vector3(10, 1, 12)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_FlankPlatform"]')
	lines.append('size = Vector3(10, 1, 12)')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_FlankCover"]')
	lines.append('material = SubResource("Mat_Pillar")')
	lines.append('size = Vector3(1.2, 1.6, 2.4)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_FlankCover"]')
	lines.append('size = Vector3(1.2, 1.6, 2.4)')
	lines.append('')

	lines.append('[sub_resource type="CylinderMesh" id="Mesh_FlankColumn"]')
	lines.append('material = SubResource("Mat_SupportCone")')
	lines.append('top_radius = 3.2')
	lines.append('bottom_radius = 1.0')
	lines.append('height = 12')
	lines.append('')
	lines.append('[sub_resource type="CylinderShape3D" id="Shape_FlankColumn"]')
	lines.append('height = 12')
	lines.append('radius = 3.2')
	lines.append('')

	lines.append('[sub_resource type="BoxMesh" id="Mesh_SouthPlatform"]')
	lines.append('material = SubResource("Mat_MainBase")')
	lines.append('size = Vector3(12, 1, 10)')
	lines.append('')
	lines.append('[sub_resource type="BoxShape3D" id="Shape_SouthPlatform"]')
	lines.append('size = Vector3(12, 1, 10)')
	lines.append('')

	lines.append('[sub_resource type="CylinderMesh" id="Mesh_BaseColumn"]')
	lines.append('material = SubResource("Mat_SupportCone")')
	lines.append('top_radius = 11')
	lines.append('bottom_radius = 3')
	lines.append('height = 12')
	lines.append('')
	lines.append('[sub_resource type="CylinderShape3D" id="Shape_BaseColumn"]')
	lines.append('height = 12')
	lines.append('radius = 11')
	lines.append('')

	lines.append('[sub_resource type="BoxShape3D" id="Shape_Void"]')
	lines.append('size = Vector3(400, 4, 400)')
	lines.append('')

	# Scene Root
	lines.append('[node name="OrbitalVoid" type="Node3D"]')
	lines.append('script = ExtResource("1_arena")')
	lines.append('')

	# WorldEnvironment & Lighting
	lines.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]')
	lines.append('environment = SubResource("Environment_1")')
	lines.append('')
	lines.append('[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]')
	lines.append('transform = Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 35, 0)')
	lines.append('light_color = Color(0.9, 0.92, 1, 1)')
	lines.append('light_energy = 1.15')
	lines.append('shadow_enabled = true')
	lines.append('')

	# Accent Lights
	lines.append('[node name="AccentSpire" type="OmniLight3D" parent="."]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 17, -34)')
	lines.append('light_color = Color(1, 0.35, 0.2, 1)')
	lines.append('light_energy = 3.5')
	lines.append('omni_range = 16.0')
	lines.append('')
	lines.append('[node name="AccentWest" type="OmniLight3D" parent="."]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -28, 6, 0)')
	lines.append('light_color = Color(0.2, 1, 0.6, 1)')
	lines.append('light_energy = 2.8')
	lines.append('omni_range = 14.0')
	lines.append('')
	lines.append('[node name="AccentEast" type="OmniLight3D" parent="."]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 28, 6, 0)')
	lines.append('light_color = Color(0.2, 0.8, 1, 1)')
	lines.append('light_energy = 2.8')
	lines.append('omni_range = 14.0')
	lines.append('')
	lines.append('[node name="AccentSouth" type="OmniLight3D" parent="."]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -1, 28)')
	lines.append('light_color = Color(0.95, 0.35, 0.9, 1)')
	lines.append('light_energy = 3.0')
	lines.append('omni_range = 14.0')
	lines.append('')

	# NavigationRegion3D and Geometry
	lines.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]')
	lines.append('navigation_mesh = SubResource("NavigationMesh_1")')
	lines.append('')
	lines.append('[node name="Geometry" type="Node3D" parent="NavigationRegion3D"]')
	lines.append('')

	# Main Platform Base
	lines.append('[node name="MainPlatformBase" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/MainPlatformBase"]')
	lines.append('mesh = SubResource("Mesh_MainBase")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/MainPlatformBase"]')
	lines.append('shape = SubResource("Shape_MainBase")')
	lines.append('')

	# Main Base Column (underneath)
	lines.append('[node name="MainBaseColumn" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -7.0, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/MainBaseColumn"]')
	lines.append('mesh = SubResource("Mesh_BaseColumn")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/MainBaseColumn"]')
	lines.append('shape = SubResource("Shape_BaseColumn")')
	lines.append('')

	# Main Platform Upper Terrace
	lines.append('[node name="MainPlatformUpper" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/MainPlatformUpper"]')
	lines.append('mesh = SubResource("Mesh_MainUpper")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/MainPlatformUpper"]')
	lines.append('shape = SubResource("Shape_MainUpper")')
	lines.append('')

	# Ramps: Hoehenunterschied 1.6m ueber 4.5m horizontale Distanz (von 11.5 bis 7.0)
	var ramp_sin: float = 1.6 / 4.78
	var ramp_cos: float = sqrt(1.0 - ramp_sin * ramp_sin)
	lines.append('[node name="RampNorth" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, %.6f, %.6f, 0, -%.6f, %.6f, 0, 0.8, -9.25)' % [ramp_cos, ramp_sin, ramp_sin, ramp_cos])
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/RampNorth"]')
	lines.append('mesh = SubResource("Mesh_RampFB")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/RampNorth"]')
	lines.append('shape = SubResource("Shape_RampFB")')
	lines.append('')

	lines.append('[node name="RampSouth" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, %.6f, -%.6f, 0, %.6f, %.6f, 0, 0.8, 9.25)' % [ramp_cos, ramp_sin, ramp_sin, ramp_cos])
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/RampSouth"]')
	lines.append('mesh = SubResource("Mesh_RampFB")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/RampSouth"]')
	lines.append('shape = SubResource("Shape_RampFB")')
	lines.append('')

	lines.append('[node name="RampEast" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(%.6f, %.6f, 0, -%.6f, %.6f, 0, 0, 0, 1, 9.25, 0.8, 0)' % [ramp_cos, ramp_sin, ramp_sin, ramp_cos])
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/RampEast"]')
	lines.append('mesh = SubResource("Mesh_RampLR")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/RampEast"]')
	lines.append('shape = SubResource("Shape_RampLR")')
	lines.append('')

	lines.append('[node name="RampWest" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(%.6f, -%.6f, 0, %.6f, %.6f, 0, 0, 0, 1, -9.25, 0.8, 0)' % [ramp_cos, ramp_sin, ramp_sin, ramp_cos])
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/RampWest"]')
	lines.append('mesh = SubResource("Mesh_RampLR")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/RampWest"]')
	lines.append('shape = SubResource("Shape_RampLR")')
	lines.append('')

	# 4 Pillars
	var pillars := [
		["PillarSW", -9.5, 3.0, 9.5],
		["PillarSE", 9.5, 3.0, 9.5],
		["PillarNW", -9.5, 3.0, -9.5],
		["PillarNE", 9.5, 3.0, -9.5],
	]
	for p in pillars:
		var pname: String = p[0]
		var px: float = p[1]
		var py: float = p[2]
		var pz: float = p[3]
		lines.append('[node name="%s" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]' % pname)
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)' % [px, py, pz])
		lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/%s"]' % pname)
		lines.append('mesh = SubResource("Mesh_Pillar")')
		lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/%s"]' % pname)
		lines.append('shape = SubResource("Shape_Pillar")')
		lines.append('[node name="RingLow" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/%s"]' % pname)
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -1.8, 0)')
		lines.append('mesh = SubResource("Mesh_PillarRing")')
		lines.append('[node name="RingHigh" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/%s"]' % pname)
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.8, 0)')
		lines.append('mesh = SubResource("Mesh_PillarRing")')
		lines.append('')

	# Spire Platform
	lines.append('[node name="SpirePlatform" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 13.5, -34)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/SpirePlatform"]')
	lines.append('mesh = SubResource("Mesh_SpirePlatform")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/SpirePlatform"]')
	lines.append('shape = SubResource("Shape_SpirePlatform")')
	lines.append('')

	lines.append('[node name="SpirePedestal" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 14.25, -34)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/SpirePedestal"]')
	lines.append('mesh = SubResource("Mesh_SpirePedestal")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/SpirePedestal"]')
	lines.append('shape = SubResource("Shape_SpirePedestal")')
	lines.append('')

	lines.append('[node name="SpireColumn" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3.5, -34)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/SpireColumn"]')
	lines.append('mesh = SubResource("Mesh_SpireColumn")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/SpireColumn"]')
	lines.append('shape = SubResource("Shape_SpireColumn")')
	lines.append('')

	# West Flank Platform
	lines.append('[node name="WestFlankPlatform" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -28, 3, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/WestFlankPlatform"]')
	lines.append('mesh = SubResource("Mesh_FlankPlatform")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/WestFlankPlatform"]')
	lines.append('shape = SubResource("Shape_FlankPlatform")')
	lines.append('')

	lines.append('[node name="WestCoverNorth" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -29, 4.3, -3.5)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/WestCoverNorth"]')
	lines.append('mesh = SubResource("Mesh_FlankCover")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/WestCoverNorth"]')
	lines.append('shape = SubResource("Shape_FlankCover")')
	lines.append('')

	lines.append('[node name="WestCoverSouth" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -29, 4.3, 3.5)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/WestCoverSouth"]')
	lines.append('mesh = SubResource("Mesh_FlankCover")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/WestCoverSouth"]')
	lines.append('shape = SubResource("Shape_FlankCover")')
	lines.append('')

	lines.append('[node name="WestColumn" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -28, -3.5, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/WestColumn"]')
	lines.append('mesh = SubResource("Mesh_FlankColumn")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/WestColumn"]')
	lines.append('shape = SubResource("Shape_FlankColumn")')
	lines.append('')

	# East Flank Platform
	lines.append('[node name="EastFlankPlatform" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 28, 3, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/EastFlankPlatform"]')
	lines.append('mesh = SubResource("Mesh_FlankPlatform")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/EastFlankPlatform"]')
	lines.append('shape = SubResource("Shape_FlankPlatform")')
	lines.append('')

	lines.append('[node name="EastCoverNorth" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 29, 4.3, -3.5)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/EastCoverNorth"]')
	lines.append('mesh = SubResource("Mesh_FlankCover")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/EastCoverNorth"]')
	lines.append('shape = SubResource("Shape_FlankCover")')
	lines.append('')

	lines.append('[node name="EastCoverSouth" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 29, 4.3, 3.5)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/EastCoverSouth"]')
	lines.append('mesh = SubResource("Mesh_FlankCover")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/EastCoverSouth"]')
	lines.append('shape = SubResource("Shape_FlankCover")')
	lines.append('')

	lines.append('[node name="EastColumn" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 28, -3.5, 0)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/EastColumn"]')
	lines.append('mesh = SubResource("Mesh_FlankColumn")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/EastColumn"]')
	lines.append('shape = SubResource("Shape_FlankColumn")')
	lines.append('')

	# South Island Platform (Quad Island)
	lines.append('[node name="SouthPlatform" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -3.5, 28)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/SouthPlatform"]')
	lines.append('mesh = SubResource("Mesh_SouthPlatform")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/SouthPlatform"]')
	lines.append('shape = SubResource("Shape_SouthPlatform")')
	lines.append('')

	lines.append('[node name="SouthColumn" type="StaticBody3D" parent="NavigationRegion3D/Geometry"]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -9.5, 28)')
	lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Geometry/SouthColumn"]')
	lines.append('mesh = SubResource("Mesh_FlankColumn")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Geometry/SouthColumn"]')
	lines.append('shape = SubResource("Shape_FlankColumn")')
	lines.append('')

	# Jump-Pads
	lines.append('[node name="JumpPads" type="Node3D" parent="."]')
	lines.append('')

	var targets := [
		["SpireTarget", 0.0, 14.2, -34.5],
		["CenterTarget", 0.0, 1.8, 2.0],
		["WestTarget", -28.0, 3.7, 3.0],
		["CenterWestTarget", -7.5, 1.8, 0.0],
		["EastTarget", 28.0, 3.7, 3.0],
		["CenterEastTarget", 7.5, 1.8, 0.0],
		["CenterSouthTarget", 0.0, 1.8, 7.5],
	]
	for t in targets:
		lines.append('[node name="%s" type="Marker3D" parent="JumpPads"]' % t[0])
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)' % [t[1], t[2], t[3]])
		lines.append('')

	var pads := [
		["PadToSpire", 0.0, 1.6, -5.5, "SpireTarget", 5.0],
		["PadSpireDown", 0.0, 14.0, -31.0, "CenterTarget", 3.5],
		["PadToWest", -11.5, 0.0, 0.0, "WestTarget", 4.0],
		["PadFromWest", -25.0, 3.5, -3.0, "CenterWestTarget", 3.5],
		["PadToEast", 11.5, 0.0, 0.0, "EastTarget", 4.0],
		["PadFromEast", 25.0, 3.5, -3.0, "CenterEastTarget", 3.5],
		["PadFromSouth", 0.0, -3.0, 24.5, "CenterSouthTarget", 4.5],
	]
	for p in pads:
		lines.append('[node name="%s" parent="JumpPads" node_paths=PackedStringArray("target") instance=ExtResource("8_pad")]' % p[0])
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)' % [p[1], p[2], p[3]])
		lines.append('target = NodePath("../%s")' % p[4])
		lines.append('apex_height = %.1f' % p[5])
		lines.append('')

	# Void Kill Zone
	lines.append('[node name="VoidKillZone" type="Area3D" parent="."]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -22, 0)')
	lines.append('script = ExtResource("17_void")')
	lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="VoidKillZone"]')
	lines.append('shape = SubResource("Shape_Void")')
	lines.append('')

	# Spawn Points
	lines.append('[node name="SpawnPoints" type="Node3D" parent="."]')
	lines.append('')
	var spawns := [
		["SpawnPoint1", 0.0, 2.0, 5.0, 0.0],
		["SpawnPoint2", 0.0, 2.0, -2.0, 180.0],
		["SpawnPoint3", -8.0, 0.8, 8.0, 45.0],
		["SpawnPoint4", 8.0, 0.8, 8.0, -45.0],
		["SpawnPoint5", -8.0, 0.8, -8.0, 135.0],
		["SpawnPoint6", 8.0, 0.8, -8.0, -135.0],
		["SpawnPoint7", -28.0, 4.3, -2.0, 90.0],
		["SpawnPoint8", 28.0, 4.3, -2.0, -90.0],
	]
	for s in spawns:
		var syaw: float = s[4]
		var cy: float = cos(deg_to_rad(syaw))
		var sy: float = sin(deg_to_rad(syaw))
		lines.append('[node name="%s" type="Marker3D" parent="SpawnPoints"]' % s[0])
		lines.append('transform = Transform3D(%.6f, 0, %.6f, 0, 1, 0, %.6f, 0, %.6f, %.2f, %.2f, %.2f)' % [cy, sy, -sy, cy, s[1], s[2], s[3]])
		lines.append('')

	# Player
	lines.append('[node name="Player" parent="." instance=ExtResource("2_player")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.0, 5.0)')
	lines.append('')

	# Items
	lines.append('[node name="Items" type="Node3D" parent="."]')
	lines.append('')

	# Weapons
	lines.append('[node name="RailgunSpire" parent="Items" instance=ExtResource("12_wpick")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 14.8, -34)')
	lines.append('weapon_id = &"railgun"')
	lines.append('weapon_scene = ExtResource("13_rail")')
	lines.append('display_name = "Railgun"')
	lines.append('[node name="OmniLight3D" parent="Items/RailgunSpire" index="4"]')
	lines.append('light_color = Color(0.3, 0.8, 1, 1)')
	lines.append('')

	lines.append('[node name="RocketWest" parent="Items" instance=ExtResource("12_wpick")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -28, 4.3, 0)')
	lines.append('weapon_id = &"rocket_launcher"')
	lines.append('weapon_scene = ExtResource("14_rpg")')
	lines.append('display_name = "Rocket Launcher"')
	lines.append('[node name="OmniLight3D" parent="Items/RocketWest" index="4"]')
	lines.append('light_color = Color(1, 0.45, 0.1, 1)')
	lines.append('')

	lines.append('[node name="PlasmaEast" parent="Items" instance=ExtResource("12_wpick")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 28, 4.3, 0)')
	lines.append('weapon_id = &"plasma"')
	lines.append('weapon_scene = ExtResource("15_plasma")')
	lines.append('display_name = "Plasma"')
	lines.append('[node name="OmniLight3D" parent="Items/PlasmaEast" index="4"]')
	lines.append('light_color = Color(0.25, 0.75, 1, 1)')
	lines.append('')

	lines.append('[node name="LightningCenter" parent="Items" instance=ExtResource("12_wpick")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.4, 0)')
	lines.append('weapon_id = &"lightning"')
	lines.append('weapon_scene = ExtResource("16_lg")')
	lines.append('display_name = "Lightning Gun"')
	lines.append('[node name="OmniLight3D" parent="Items/LightningCenter" index="4"]')
	lines.append('light_color = Color(0.7, 0.9, 1, 1)')
	lines.append('')

	# Powerups
	lines.append('[node name="MegaSpire" parent="Items" instance=ExtResource("11_mega")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 14.8, -36.5)')
	lines.append('')
	lines.append('[node name="QuadSouth" parent="Items" instance=ExtResource("10_quad")]')
	lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -2.2, 28)')
	lines.append('')

	# Health & Armor
	var ha := [
		["ArmorWest", "6_armor", -28.0, 4.3, 3.5],
		["ArmorEast", "6_armor", 28.0, 4.3, 3.5],
		["ArmorCenter", "6_armor", 0.0, 0.8, -11.0],
		["HealthCenter", "5_health", 0.0, 0.8, 11.0],
		["HealthWestFlank", "5_health", -10.0, 0.8, 0.0],
		["HealthEastFlank", "5_health", 10.0, 0.8, 0.0],
		["HealthSouth1", "5_health", -3.0, -2.2, 28.0],
		["HealthSouth2", "5_health", 3.0, -2.2, 28.0],
	]
	for item in ha:
		lines.append('[node name="%s" parent="Items" instance=ExtResource("%s")]' % [item[0], item[1]])
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)' % [item[2], item[3], item[4]])
		lines.append('')

	# Ammo
	var ammos := [
		["AmmoSW", -9.5, 0.8, 6.0],
		["AmmoSE", 9.5, 0.8, 6.0],
		["AmmoNW", -9.5, 0.8, -6.0],
		["AmmoNE", 9.5, 0.8, -6.0],
		["AmmoWest", -28.0, 4.3, -3.5],
		["AmmoEast", 28.0, 4.3, -3.5],
	]
	for a in ammos:
		lines.append('[node name="%s" parent="Items" instance=ExtResource("4_ammo")]' % a[0])
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)' % [a[1], a[2], a[3]])
		lines.append('')

	# Props
	lines.append('[node name="Props" type="Node3D" parent="."]')
	lines.append('')
	var props := [
		["BarrelSW", "18_barrel", -7.5, 0.8, 7.5],
		["BarrelSE", "18_barrel", 7.5, 0.8, 7.5],
		["CrateNW", "19_crate", -7.5, 0.8, -7.5],
		["CrateNE", "19_crate", 7.5, 0.8, -7.5],
		["BarrelWest", "18_barrel", -26.0, 4.3, 4.0],
		["BarrelEast", "18_barrel", 28.0, 4.3, -4.0],
		["BarrelSouth", "18_barrel", 0.0, -2.2, 31.0],
	]
	for p in props:
		lines.append('[node name="%s" parent="Props" instance=ExtResource("%s")]' % [p[0], p[1]])
		lines.append('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)' % [p[2], p[3], p[4]])
		lines.append('')

	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines) + "\n")
		file.close()
		print("Erfolgreich gespeichert: ", out_path)
		quit(0)
	else:
		push_error("Fehler beim Oeffnen von " + out_path)
		quit(1)
