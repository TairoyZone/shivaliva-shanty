// STARDUST SKY — a procedural twinkling-starfield backdrop (canvas_item, GLES3 Compatibility-safe: no
// textures/derivatives/compute). A twilight gradient with two parallax-ish layers of small twinkling
// stars; a fraction take a JEWEL hue (blue→violet→pink) to rhyme with the Loft's Stardust gems. Drives
// SkyBackdrop (components/sky_backdrop.gd). Placeholder-first; all look is in the uniforms — tune freely.
shader_type canvas_item;

uniform vec3 sky_top : source_color = vec3(0.07, 0.08, 0.18);     // deep twilight at the top
uniform vec3 sky_bottom : source_color = vec3(0.16, 0.18, 0.34);  // lighter haze toward the horizon
uniform float density = 46.0;          // stars per screen-ish
uniform float twinkle_speed = 2.2;
uniform float drift = 0.004;           // slow horizontal sky-creep
uniform float brightness = 1.0;
uniform float jewel_chance = 0.22;     // fraction of stars tinted a gem hue

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 col = mix(sky_top, sky_bottom, UV.y);
	// Two star layers at different scales/drift for a touch of depth.
	for (int l = 0; l < 2; l++) {
		float fl = float(l);
		float dens = density * (1.0 + fl * 0.7);
		float dr = drift * (1.0 + fl * 1.5);
		vec2 g = vec2(UV.x * dens + TIME * dr, UV.y * dens - TIME * dr * 0.4);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float present = step(0.85, hash(cell + fl * 11.3));
		vec2 ctr = vec2(hash(cell + vec2(1.7, 9.2)), hash(cell + vec2(4.4, 2.1)));
		float d = length(f - ctr);
		float core = smoothstep(0.09, 0.0, d) + smoothstep(0.22, 0.0, d) * 0.18;   // sharp point + faint halo
		float rid = hash(cell + vec2(5.5, 7.7));
		float tw = 0.45 + 0.55 * sin(TIME * twinkle_speed * (0.5 + rid) + rid * 6.2831);
		vec3 white = vec3(0.86, 0.92, 1.0);
		vec3 jewel = hsv2rgb(vec3(mix(0.55, 0.95, hash(cell + vec2(8.1, 3.3))), 0.55, 1.0));
		vec3 sc = (hash(cell + vec2(2.9, 6.6)) < jewel_chance) ? jewel : white;
		col += core * tw * present * sc * brightness * (1.0 - fl * 0.35);
	}
	COLOR = vec4(col, 1.0);
}
