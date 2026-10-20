shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// Nachbearbeitung "Neon-Kanten": findet Kanten im Bild ueber Tiefen- und Normalen-Spruenge
// und laesst sie in der Farbe der jeweiligen Flaeche leuchten (Wireframe-Look auf Low-Poly-Koerpern).
// Liegt als bildschirmfuellendes Quad vor der Kamera. Werte ueber 1.0 erzeugen Bloom.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// Linienbreite in Pixeln
uniform float line_width : hint_range(0.5, 4.0) = 1.4;
// Leuchtkraft der Kanten
uniform float edge_intensity : hint_range(0.0, 10.0) = 3.2;
// Ab welchem Normalen-Unterschied eine Kante entsteht (0 = jede Kruemmung, 1 = nur harte Kanten)
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.35;
// Ab welchem relativen Tiefensprung eine Kante entsteht
uniform float depth_threshold : hint_range(0.0, 1.0) = 0.06;
// Farbe fuer Kanten an grauen/unbunten Flaechen
uniform vec3 neutral_edge_color : source_color = vec3(0.35, 0.85, 1.0);
// Wie stark der Farbton der Flaeche fuer die Kante gesaettigt wird (1 = unveraendert)
uniform float hue_boost : hint_range(1.0, 4.0) = 2.2;
// Kanten werden mit der Entfernung schwaecher (m)
uniform float fade_start = 25.0;
uniform float fade_end = 90.0;

void vertex() {
	// Quad direkt in Bildschirmkoordinaten ausgeben
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_texture, uv).x;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_roughness_texture, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base = texture(screen_texture, uv).rgb;
	float raw_depth = texture(depth_texture, uv).x;

	// Himmel (keine Geometrie) unveraendert lassen
	if (raw_depth <= 0.0000001) {
		ALBEDO = base;
	} else {
		vec2 px = line_width / VIEWPORT_SIZE;
		float d = linear_depth(uv, INV_PROJECTION_MATRIX);
		vec3 n = normal_at(uv);

		float edge = 0.0;
		vec2 offsets[4] = { vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y) };
		for (int i = 0; i < 4; i++) {
			vec2 o = uv + offsets[i];
			float dn = linear_depth(o, INV_PROJECTION_MATRIX);
			vec3 nn = normal_at(o);
			// Tiefensprung relativ zur Entfernung (sonst flimmern ferne Flaechen)
			float depth_edge = step(depth_threshold, abs(dn - d) / max(d, 0.001));
			float normal_edge = step(normal_threshold, 1.0 - dot(n, nn));
			edge = max(edge, max(depth_edge, normal_edge));
		}

		// Kantenfarbe = Farbton der Flaeche (hell normiert), bei grauen Flaechen neutral_edge_color
		float peak = max(max(base.r, base.g), base.b);
		vec3 hue = base / max(peak, 0.0001);
		// Farbton verstaerken: dunkle, leicht getoente Flaechen bekommen kraeftige Neonkanten
		hue = pow(hue, vec3(hue_boost));
		float saturation = (peak - min(min(base.r, base.g), base.b)) / max(peak, 0.0001);
		vec3 edge_color = mix(neutral_edge_color, hue, smoothstep(0.15, 0.45, saturation));

		float fade = 1.0 - smoothstep(fade_start, fade_end, d);
		ALBEDO = base + edge_color * edge * edge_intensity * fade;
	}
}
