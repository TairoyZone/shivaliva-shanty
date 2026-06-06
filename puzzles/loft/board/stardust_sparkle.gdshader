// THE STARDUST SPARKLE — drifting DIAMOND gems that twinkle, slowly ROTATE (each its own way), and some
// GLOW, scattered across jewel hues (blue / purple / pink / red). Renders only below `surface_y` (the
// rise line in UV, 0 = board top, 1 = bottom); `danger` pulls the gems warmer (toward red) as the
// Stardust's bite climbs. Cheap + GL-Compatibility-safe (hash/sin only — no textures/derivatives).
shader_type canvas_item;

uniform float surface_y = 0.7;     // the rise line in UV — gems only appear BELOW this
uniform float danger = 0.0;        // 0 = calm jewel scatter, 1 = the Stardust's bite (warm red)
uniform float density = 22.0;      // vertical gem-cell count (aspect-corrected horizontally)
uniform float twinkle_speed = 1.7;
uniform float rot_speed = 1.1;     // gem spin rate
uniform float brightness = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	float below = step(surface_y, UV.y);
	// Aspect-correct (~square) cell grid drifting slowly UP (the dust rises out of the deep).
	vec2 g = vec2(UV.x * density * 0.5, UV.y * density - TIME * 0.08);
	vec2 cell = floor(g);
	vec2 f = fract(g);

	float rPresent = hash(cell);
	float rTw      = hash(cell + vec2(19.7, 4.1));
	vec2  rCenter  = vec2(hash(cell + vec2(7.3, 41.7)), hash(cell + vec2(53.1, 11.9)));
	float rHue     = hash(cell + vec2(31.3, 67.9));
	float rRot     = hash(cell + vec2(91.1, 23.5));
	float rGlow    = hash(cell + vec2(2.7, 88.2));

	float present = step(0.58, rPresent);   // ~42% of cells hold a gem

	// Local coords about the gem centre (kept off the cell edge), then SPIN it.
	vec2 p = f - mix(vec2(0.25), vec2(0.75), rCenter);
	float a = rRot * 6.2831 + TIME * (rTw - 0.5) * 2.0 * rot_speed;
	float cs = cos(a);
	float sn = sin(a);
	vec2 pr = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);

	// DIAMOND core (rotated square SDF: |x|+|y|) + a soft round GLOW on a third of them.
	float dia = abs(pr.x) + abs(pr.y);
	float core = smoothstep(0.18, 0.06, dia);
	float glows = step(0.66, rGlow);
	float halo = glows * smoothstep(0.42, 0.0, length(p)) * 0.5;

	float tw = 0.55 + 0.45 * sin(TIME * twinkle_speed * (0.5 + rPresent) + rTw * 6.2831);
	float depth = clamp((UV.y - surface_y) / max(0.02, 1.0 - surface_y), 0.0, 1.0);
	float spark = (core + halo) * present * tw * (0.55 + 0.45 * depth) * brightness * below;

	// Per-gem hue across blue -> purple -> pink -> red; danger pulls them all warmer + more saturated.
	float hue = fract(mix(0.55 + rHue * 0.5, 0.99, danger));
	float sat = mix(0.72, 0.92, danger);
	vec3 col = hsv2rgb(vec3(hue, sat, 1.0));
	COLOR = vec4(col, clamp(spark, 0.0, 1.0));
}
