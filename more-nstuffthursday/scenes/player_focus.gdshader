shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture;
uniform vec2 focus_pos = vec2(0.5, 0.5);	// normalized screen coords (0..1)
uniform float radius : hint_range(0.0, 1.0) = 0.25;
uniform float softness : hint_range(0.0, 1.0) = 0.35;
uniform float darkness : hint_range(0.0, 1.0) = 0.65;	// how dark outside the focus
uniform float ca_amount : hint_range(0.0, 1.0) = 0.35;	// chromatic aberration blend
uniform float ca_strength : hint_range(0.0, 0.01) = 0.002;

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;

	float d = distance(SCREEN_UV, focus_pos);
	float vign = smoothstep(radius, radius + softness, d); // 0 near focus, 1 far

	vec3 dark = scene * (1.0 - darkness * vign);

	vec2 dir = normalize(SCREEN_UV - focus_pos + vec2(1e-6, 0.0));
	vec2 off = dir * ca_strength * vign;

	float r = texture(screen_tex, SCREEN_UV + off).r;
	float g = texture(screen_tex, SCREEN_UV).g;
	float b = texture(screen_tex, SCREEN_UV - off).b;
	vec3 ca = vec3(r, g, b);

	vec3 mixed = mix(dark, ca, ca_amount * vign);
	COLOR = vec4(mixed, 1.0);
}

