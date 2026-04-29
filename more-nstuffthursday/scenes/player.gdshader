shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 aura_color : source_color = vec4(0.16, 0.95, 0.36, 1.0);	// green
uniform float aura_thickness_px : hint_range(0.0, 6.0, 0.1) = 2.5;
uniform float aura_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float aura_pulse_amp_px : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float aura_pulse_speed : hint_range(0.0, 12.0, 0.01) = 4.0;
uniform float edge_softness : hint_range(0.0, 1.0, 0.001) = 0.05;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float base = tex.a;

	float thickness = max(0.5, aura_thickness_px + sin(TIME * aura_pulse_speed) * aura_pulse_amp_px);
	vec2 px = TEXTURE_PIXEL_SIZE * thickness;

	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(px.x, px.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	float edge = clamp(n - base, 0.0, 1.0);
	float outline = smoothstep(0.0, edge_softness, edge);
	float aura = outline * (1.0 - base);

	float aura_a = clamp(aura * aura_intensity, 0.0, 1.0);

	vec3 out_rgb = tex.rgb + aura_color.rgb * aura_a;
	float out_a = max(base, aura_a);

	COLOR = vec4(out_rgb, out_a);
}
