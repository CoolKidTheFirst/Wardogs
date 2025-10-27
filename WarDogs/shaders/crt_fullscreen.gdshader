
shader_type canvas_item;
render_mode unshaded;

uniform float curvature = 0.06;        // barrel distortion intensity
uniform float vignette = 0.33;         // 0..1, higher = stronger dark corners
uniform float scanline_intensity = 0.12;
uniform float aberration = 0.002;      // chromatic aberration offset
uniform float noise_strength = 0.02;   // film grain strength
uniform float time_scale = 1.0;

void fragment() {
    // Start from screen UV so we can post-process the whole scene
    vec2 uv = SCREEN_UV;
    // Barrel distortion around screen center
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc);
    uv += cc * dist * curvature;

    // Sample screen texture with slight RGB channel offsets
    vec3 col;
    vec2 off = vec2(aberration, 0.0);
    float a = 1.0;
    vec3 r = texture(SCREEN_TEXTURE, uv + off).rgb;
    vec3 g = texture(SCREEN_TEXTURE, uv).rgb;
    vec3 b = texture(SCREEN_TEXTURE, uv - off).rgb;
    col = vec3(r.r, g.g, b.b);

    // Scanlines (vertical resolution factor ~480 lines look)
    float scan = sin((SCREEN_UV.y + TIME * time_scale) * 3.14159 * 480.0) * 0.5 + 0.5;
    col *= (1.0 - scanline_intensity * scan);

    // Vignette
    float vig = smoothstep(0.95, vignette, dist);
    col *= (1.0 - vig * 0.85);

    // Grain
    float n = fract(sin(dot(uv * (TIME * time_scale + 13.0), vec2(12.9898,78.233))) * 43758.5453);
    col += (n - 0.5) * noise_strength;

    COLOR = vec4(col, a);
}
