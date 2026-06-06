// THE STARDUST SPARKLE — a slow twinkling glitter over the abyss below the Loft's rise line.
// A cheap, GL-Compatibility-safe canvas_item shader: renders ONLY below `surface_y` (the rise line in
// UV, 0 = board top, 1 = board bottom), drifts faint motes upward, and tints calm -> danger. Drawn on a
// ColorRect sized to the board, riding over the flat Stardust fill (see LoftBoard.paint_overlay).
shader_type canvas_item;

uniform float surface_y = 0.7;     // the rise line in UV — sparkle only appears BELOW this
uniform float danger = 0.0;        // 0 = calm (cool violet), 1 = the Stardust's bite (warm red)
uniform vec3 calm_spark : source_color = vec3(0.80, 0.74, 1.0);
uniform vec3 danger_spark : source_color = vec3(1.0, 0.62, 0.62);
uniform float density = 22.0;      // vertical sparkle-cell count (aspect-corrected horizontally)
uniform float twinkle_speed = 1.7;
uniform float brightness = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Mask: nothing above the rise line — the abyss is only below it.
	float below = step(surface_y, UV.y);
	// Aspect-correct cell grid that drifts slowly UP (the dust rises out of the deep).
	vec2 g = vec2(UV.x * density * 0.5, UV.y * density - TIME * 0.08);
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float r = hash(cell);
	float r2 = hash(cell + 19.7);
	float present = step(0.6, r);   // ~40% of cells hold a star
	// Each star twinkles at its own rate + phase.
	float tw = 0.5 + 0.5 * sin(TIME * twinkle_speed * (0.5 + r) + r2 * 6.2831);
	// A tight soft point, offset randomly within its cell.
	vec2 off = (vec2(r2, hash(cell + 4.1)) - 0.5) * 0.55;
	float d = length(f - off);
	float spark = present * smoothstep(0.22, 0.0, d) * tw;
	// Deeper below the surface reads a touch fuller (the abyss thickens with depth).
	float depth = clamp((UV.y - surface_y) / max(0.02, 1.0 - surface_y), 0.0, 1.0);
	spark *= (0.55 + 0.45 * depth) * brightness * below;
	vec3 col = mix(calm_spark, danger_spark, danger);
	COLOR = vec4(col, spark);
}
