shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

uniform float desaturate        : hint_range(0.0, 1.0) = 0.8;
uniform float red_amount        : hint_range(0.0, 1.0) = 0.65;
uniform float pulse_amp         : hint_range(0.0, 1.0) = 0.35;
uniform float pulse_speed_hz    : hint_range(0.1, 6.0) = 1.8;
uniform float vignette          : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius   : hint_range(0.0, 1.0) = 0.65;
uniform float vignette_softness : hint_range(0.001, 1.0) = 0.35;
uniform float intensity         : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec3 src = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

    // Desaturate
    float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));
    vec3 desat = mix(src, vec3(luma), desaturate);

    // Heartbeat pulse on red tint
    float pulse = (sin(TIME * 6.2831853 * pulse_speed_hz) * 0.5 + 0.5) * pulse_amp;
    float tint_strength = clamp(red_amount + pulse, 0.0, 1.0) * intensity;
    vec3 tinted = mix(desat, vec3(1.0, 0.0, 0.0), tint_strength);

    // Vignette (darken edges)
    float r0 = max(0.0, vignette_radius - vignette_softness);
    float d  = distance(SCREEN_UV, vec2(0.5));
    float v  = 1.0 - smoothstep(r0, vignette_radius, d); // 1 in center, 0 at edges
    float edge_dark = mix(1.0 - vignette * intensity, 1.0, v);
    vec3 col = tinted * edge_dark;

    COLOR = vec4(col, 1.0);
}
