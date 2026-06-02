shader_type canvas_item;

void fragment() {
	vec2 red_green = COLOR.rg;
	// We mix the original red-green color with a flat color over time,
	// in a cycle. The `sin()` function takes a real-number and returns
	// value between `-1` and `1`.
	COLOR.rg = mix(red_green, vec2(0.3, 0.5), sin(6.0 * TIME));
}
