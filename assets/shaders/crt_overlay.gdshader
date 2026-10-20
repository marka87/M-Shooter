shader_type canvas_item;

// Dezenter Retro-Bildschirm-Look ueber dem 3D-Bild (unter dem HUD):
// Farbsaum an den Raendern (chromatische Aberration), Vignette, feine Scanlines, leichtes Rauschen.
// Bei Treffern kann damage_pulse kurz hochgesetzt werden (roter Rand + staerkerer Farbsaum).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float aberration : hint_range(0.0, 0.02) = 0.0025;
uniform float vignette : hint_range(0.0, 2.0) = 0.55;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.06;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.02;
uniform float damage_pulse : hint_range(0.0, 1.0) = 0.0;
// Violetter Bildrand, solange Quad Damage aktiv ist
uniform float quad_glow : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;
	float dist = length(center);

	// Farbsaum: Rot nach aussen, Blau nach innen, staerker zum Rand hin
	float ab = (aberration + damage_pulse * 0.01) * dist * 2.0;
	vec3 col;
	col.r = texture(screen_texture, uv + center * ab).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - center * ab).b;

	// Scanlines (an die Bildschirmhoehe gekoppelt, damit sie nicht flimmern)
	float line = sin(uv.y / SCREEN_PIXEL_SIZE.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * line;

	// Rauschen
	col += (rand(uv + fract(TIME)) - 0.5) * noise_strength;

	// Vignette und roter Trefferrand
	float vig = smoothstep(0.85, 0.25, dist * (1.0 + vignette * 0.5));
	col *= mix(1.0, vig, clamp(vignette, 0.0, 1.0));
	col = mix(col, vec3(0.8, 0.05, 0.05), damage_pulse * smoothstep(0.3, 0.75, dist) * 0.6);
	col += vec3(0.55, 0.2, 1.0) * quad_glow * smoothstep(0.35, 0.8, dist) * 0.9;

	COLOR = vec4(col, 1.0);
}
