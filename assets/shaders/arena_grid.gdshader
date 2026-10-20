shader_type spatial;

// Arena-Oberflaeche mit leuchtendem Raster (Sci-Fi-Look, hilft beim Einschaetzen von Abstaenden).
// Das Raster liegt in Weltkoordinaten (triplanar), dadurch passt es ueber alle Bloecke hinweg.

uniform vec3 base_color : source_color = vec3(0.12, 0.14, 0.18);
uniform vec3 line_color : source_color = vec3(0.1, 0.65, 1.0);
// Abstand der Rasterlinien in Metern
uniform float cell_size = 2.0;
// Linienbreite als Anteil einer Zelle
uniform float line_width : hint_range(0.0, 0.2) = 0.03;
// Leuchtkraft der Linien (ueber 1.0 erzeugt Bloom)
uniform float line_emission = 2.5;
// Jede n-te Linie heller (Hauptraster)
uniform int major_every = 5;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.6;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.2;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1.0 auf einer Linie, 0.0 dazwischen (mit weicher Kante gegen Flimmern)
float grid_lines(vec2 p, float scale, float width) {
	vec2 cell = p / scale;
	vec2 dist = abs(fract(cell - 0.5) - 0.5);
	vec2 aa = fwidth(cell) * 1.5;
	vec2 lines = 1.0 - smoothstep(vec2(width) - aa, vec2(width) + aa, dist);
	return max(lines.x, lines.y);
}

void fragment() {
	// Triplanar: Projektion je nach Flaechenausrichtung waehlen
	vec3 n = abs(world_normal);
	vec2 p;
	if (n.y >= n.x && n.y >= n.z) {
		p = world_pos.xz;
	} else if (n.x >= n.z) {
		p = world_pos.zy;
	} else {
		p = world_pos.xy;
	}

	float minor = grid_lines(p, cell_size, line_width);
	// Hauptlinien nur etwas breiter als die normalen (Breite in Metern statt pro Zelle)
	float major = grid_lines(p, cell_size * float(major_every), line_width * 1.6 / float(major_every));
	float line = max(minor * 0.35, major);

	ALBEDO = mix(base_color, line_color * 0.4, line * 0.5);
	EMISSION = line_color * line * line_emission;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
