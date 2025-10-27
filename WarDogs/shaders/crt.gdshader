shader_type canvas_item;

uniform float curvature = 0.06;
uniform float vignette = 0.32;
uniform float scanline_intensity = 0.10;
uniform float aberration = 0.0018;
uniform float noise_strength = 0.018;
uniform float time_scale = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 cc = uv - 0.5;
	float dist = dot(cc, cc);
	uv += cc * dist * curvature;

	vec4 base = texture(TEXTURE, uv);
	vec4 r = texture(TEXTURE, uv + vec2(aberration, 0.0));
	vec4 g = base;
	vec4 b = texture(TEXTURE, uv - vec2(aberration, 0.0));
	vec3 col = vec3(r.r, g.g, b.b);

	float scan = sin((UV.y + TIME * time_scale) * 3.14159 * 480.0) * 0.5 + 0.5;
	col *= (1.0 - scanline_intensity * scan);

	float vig = smoothstep(0.95, vignette, dist);
	col *= (1.0 - vig * 0.85);

	float n = fract(sin(dot(uv * (TIME * time_scale + 13.0), vec2(12.9898,78.233))) * 43758.5453);
	col += (n - 0.5) * noise_strength;

	COLOR = vec4(col, texture(TEXTURE, uv).a);
}