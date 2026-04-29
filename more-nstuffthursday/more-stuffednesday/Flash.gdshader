shader_type canvas_item;

/* Driven by code: 0..1 (we'll feed a fade curve) */
uniform float t : hint_range(0.0, 1.0) = 0.0;

/* Target color/alpha of the blackout */
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.75);

/* Optional, soft edge darkening (set to 0 to disable) */
uniform float vignette_softness = 0.45;

void fragment(){
	// base alpha = t scaled by overlay target alpha
	float a = t * overlay_color.a;

	// subtle vignette (optional)
	if (vignette_softness > 0.0) {
		vec2 p = UV - vec2(0.5);
		float d = length(p) * 2.0;
		float vig = smoothstep(1.0 - vignette_softness, 1.0, d); // 0 center .. 1 edges
		a *= mix(1.0, 0.85, vig); // slightly stronger at edges
	}

	COLOR = vec4(overlay_color.rgb, a);
}
