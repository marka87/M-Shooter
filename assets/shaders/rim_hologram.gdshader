shader_type spatial;
// Leuchtender Fresnel-Rand als Overlay (material_overlay) fuer Pickups und Figuren.
// hologram > 0: Scanlines und Flackern wie ein Hologramm (Respawn), klingt per Tween auf 0 ab.
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform float rim_energy : hint_range(0.0, 4.0) = 1.4;
uniform float hologram : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_energy;
	// Waagrechte Scanlines, die nach oben laufen, plus leichtes Flackern
	float lines = smoothstep(0.35, 0.5, fract(world_pos.y * 18.0 - TIME * 3.0));
	float flicker = 0.75 + 0.25 * sin(TIME * 47.0);
	float holo = hologram * (0.35 + 0.65 * lines) * flicker;
	ALBEDO = rim_color.rgb;
	ALPHA = clamp(rim + holo, 0.0, 1.0);
}
