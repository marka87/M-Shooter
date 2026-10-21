shader_type spatial;
// Teleporter-Feld auf einem offenen Zylinder: aufsteigende Lichtstreifen, kreisende Baender,
// heller Rand im Fresnel und weiches Ausblenden oben.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 portal_color : source_color = vec4(0.3, 1.0, 0.85, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.2;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	// UV.x = rundherum, UV.y = Hoehe (0 oben, 1 unten)
	float height = 1.0 - UV.y;
	float column = floor(UV.x * 48.0);
	float speed = 0.4 + hash(column) * 0.8;
	float streak = smoothstep(0.75, 1.0, fract(height * 1.5 - TIME * speed + hash(column + 7.0)));
	streak *= step(0.55, hash(column + 3.0));
	float bands = 0.5 + 0.5 * sin((UV.x * 6.2832 * 3.0) + height * 9.0 - TIME * 4.0);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float fade = (1.0 - smoothstep(0.55, 1.0, height)) * smoothstep(0.0, 0.08, height);
	ALBEDO = portal_color.rgb;
	ALPHA = clamp((streak * 0.9 + bands * 0.12 + rim * 0.35) * fade * intensity, 0.0, 1.0);
}
