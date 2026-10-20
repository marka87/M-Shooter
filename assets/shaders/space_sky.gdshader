shader_type sky;

// Nachthimmel fuer die Arena: Farbverlauf, Sterne, schwacher Nebel und leuchtender Horizont.
// Komplett prozedural, keine Texturen noetig.

uniform vec3 zenith_color : source_color = vec3(0.01, 0.015, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.12, 0.08, 0.2);
uniform vec3 horizon_glow : source_color = vec3(1.0, 0.35, 0.15);
uniform vec3 nebula_color : source_color = vec3(0.2, 0.45, 0.9);
uniform float star_density : hint_range(0.0, 1.0) = 0.12;
uniform float star_brightness = 3.0;
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.35;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, 0.0, 1.0);

	// Grundverlauf vom Horizont zum Zenit
	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.45));

	// Warmes Leuchten knapp ueber dem Horizont
	col += horizon_glow * pow(1.0 - abs(dir.y), 18.0) * 0.35;

	// Nebelband quer ueber den Himmel
	float band = exp(-pow((dir.y - 0.35 + dir.x * 0.25) * 3.0, 2.0));
	float clouds = fbm(dir * 4.0) * fbm(dir * 9.0 + 3.7);
	col += nebula_color * band * clouds * nebula_strength * 2.0;

	// Sterne: Zellen auf der Himmelskugel, in wenigen davon ein kleiner Punkt
	// mit zufaelliger Position, Helligkeit und Farbe
	const float STAR_GRID = 500.0;
	vec3 cell = floor(dir * STAR_GRID);
	float h = hash(cell);
	if (h > 1.0 - star_density * 0.1 && dir.y > -0.05) {
		vec3 jitter = vec3(hash(cell + 11.0), hash(cell + 23.0), hash(cell + 37.0)) * 0.6 + 0.2;
		vec3 center = (cell + jitter) / STAR_GRID;
		float d = length(dir - normalize(center)) * STAR_GRID;
		float size = 0.12 + hash(cell + 51.0) * 0.18;
		float twinkle = 0.7 + 0.3 * sin(TIME * (1.0 + h * 4.0) + h * 40.0);
		float bright = pow(hash(cell + 73.0), 3.0) * 0.8 + 0.2;
		vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), hash(cell + 91.0));
		col += tint * smoothstep(size, 0.0, d) * star_brightness * bright * twinkle * smoothstep(0.0, 0.25, up);
	}

	// Unter dem Horizont dunkel
	if (dir.y < 0.0) {
		col = mix(col, zenith_color * 0.5, clamp(-dir.y * 4.0, 0.0, 1.0));
	}

	COLOR = col;
}
