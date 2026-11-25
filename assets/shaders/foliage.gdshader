shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Крона/трава: INSTANCE_CUSTOM = (фаза ветра, амплитуда), COLOR = оттенок инстанса.
// sway_axis 0 — изгиб по локальному y (трава 0..1), 1 — жёсткое качание всего меша (кроны).
uniform vec4 base_col : source_color = vec4(0.2, 0.3, 0.12, 1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform float sway_axis = 0.0;
uniform vec3 amb_col = vec3(0.62, 0.5, 0.38);

varying float v_phase;
varying float v_amp;

void vertex() {
	v_phase = INSTANCE_CUSTOM.x;
	v_amp = INSTANCE_CUSTOM.y;
	float sway = sin(TIME * wind_speed + v_phase) * 0.6 + sin(TIME * wind_speed * 1.7 + v_phase * 1.3) * 0.4;
	if (sway_axis > 0.5) {
		VERTEX.x += sway * wind_strength * v_amp;
		VERTEX.z += sway * wind_strength * v_amp * 0.6;
	} else {
		float t = clamp(VERTEX.y, 0.0, 1.0);
		VERTEX.x += sway * wind_strength * t * t * v_amp;
		VERTEX.z += sway * wind_strength * t * t * v_amp * 0.7;
	}
}

void fragment() {
	ALBEDO = base_col.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

// Lambert wrap: мягкий подсвет теневой стороны (полу-lambert 0.5)
void light() {
	float nl = dot(NORMAL, LIGHT);
	float wrapped = clamp(nl * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * wrapped;
	DIFFUSE_LIGHT += ALBEDO * amb_col;
}
