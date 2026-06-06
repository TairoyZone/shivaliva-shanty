// STARDUST FOG — drifting wispy cloud bands (canvas_item, GLES3 Compatibility-safe: procedural value-noise
// fbm, no textures/derivatives). A thin moving mist that sits behind the world (between the SkyBackdrop and
// the scene) for depth. All look is in the uniforms — tune freely. Drives DriftFog (components/drift_fog.gd).
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.78, 0.82, 0.95, 1.0);
uniform float drift = 0.018;       // horizontal creep speed
uniform float density = 0.55;      // overall opacity of the wisps
uniform float scale = 3.0;         // cloud size (smaller = bigger puffs)
uniform float floor_bias = 0.0;    // 0 = uniform, 1 = denser toward the bottom

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(scale * 2.0, scale);
	uv.x += TIME * drift * 10.0;
	float n = fbm(uv);
	float band = smoothstep(0.5, 0.92, n) * density;
	band *= mix(1.0, UV.y, floor_bias);   // optionally denser toward the bottom (ground/abyss fog)
	COLOR = vec4(fog_color.rgb, clamp(band, 0.0, 1.0) * fog_color.a);
}
