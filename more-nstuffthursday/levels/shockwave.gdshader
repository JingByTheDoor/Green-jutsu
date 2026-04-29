shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture;
uniform vec2 origin_uv = vec2(0.5, 0.5);			// where the wave starts (normalized)
uniform float progress : hint_range(0.0, 2.0) = 0.0;	// ring radius in UV space
uniform float thickness : hint_range(0.001, 0.5) = 0.08;
uniform float amplitude : hint_range(0.0, 0.2) = 0.02;	// displacement strength
uniform float brightness : hint_range(0.0, 1.0) = 0.25;	// ring highlight

void fragment() {
	vec2 uv = SCREEN_UV;
	float r = distance(uv, origin_uv);
	float half_t = max(thickness * 0.5, 1e-4);

	// 1. Ring mask (1.0 inside ring band, 0.0 elsewhere)
	float ring = smoothstep(progress - half_t, progress, r) * (1.0 - smoothstep(progress, progress + half_t, r));

	// 2. Push pixels outward along the ring
	float strength = clamp(1.0 - abs(r - progress) / half_t, 0.0, 1.0);
	vec2 dir = normalize(uv - origin_uv + vec2(1e-6, 0.0));
	vec2 disp_uv = uv + dir * amplitude * strength;

	vec3 col = texture(screen_tex, disp_uv).rgb;

	// 3. Brighten the ring slightly
	col = mix(col, col + vec3(brightness), ring);

	COLOR = vec4(col, 1.0);
}
