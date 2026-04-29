shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

uniform float intensity  : hint_range(0.0, 1.0) = 1.0;
uniform float sat_boost  : hint_range(0.0, 1.0) = 0.35;
uniform float warm_tint  : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_amt  : hint_range(0.0, 1.0) = 0.35;
uniform float contrast   : hint_range(0.8, 1.5) = 1.05;
uniform float brightness : hint_range(-0.2, 0.2) = 0.03;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment(){
    vec3 src = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

    // Oversaturate toward original color
    float l = dot(src, LUMA);
    vec3 sat = mix(vec3(l), src, 1.0 + sat_boost * intensity);

    // Gentle warm tint
    vec3 warm = mix(sat, sat * vec3(1.08, 1.03, 0.92), warm_tint * intensity);

    // Pseudo bloom from highlights
    float hi = pow(max(max(src.r, src.g), src.b), 6.0);
    vec3 col = warm + hi * bloom_amt * intensity;

    col = (col - 0.5) * contrast + 0.5 + brightness;
    COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
