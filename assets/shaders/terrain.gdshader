shader_type spatial;
render_mode cull_back, specular_disabled;

// Трипланар в мировых координатах: меш террейна стоит в (0,0,0) без поворота,
// поэтому локальные VERTEX/NORMAL == мировые, MODEL_MATRIX не нужен (compat-safe).
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.085;
uniform float mud_darken = 0.6;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = VERTEX;
	w_nrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	float slope = clamp(1.0 - n.y, 0.0, 1.0);
	vec2 uv_top = w_pos.xz * tex_scale;
	vec2 uv_side = vec2((w_pos.x + w_pos.z) * 0.5, w_pos.y) * tex_scale;
	vec2 uv_t = mix(uv_top, uv_side, clamp(slope * 2.4, 0.0, 1.0));
	vec3 g = texture(grass_tex, uv_t).rgb;
	vec3 s = texture(soil_tex, uv_t).rgb;
	vec3 v = texture(gravel_tex, uv_t * 0.85).rgb;
	float macro = texture(macro_tex, w_pos.xz * 0.012).r;
	vec3 col = mix(g, s, smoothstep(0.035, 0.16, slope));
	col = mix(col, v, smoothstep(0.22, 0.5, slope));
	col *= mix(0.76, 1.12, macro);
	col = mix(col, col * mud_darken, 1.0 - smoothstep(0.8, 2.8, w_pos.y));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
