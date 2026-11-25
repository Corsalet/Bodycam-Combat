shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

// Вода: прозрачность по глубине через DEPTH_TEXTURE (compat 4.3+) + две встречные
// шумовые нормали для ряби. UV в масштабе плоскости, поток времени разный по осям.
uniform sampler2D norm_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D norm_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 shallow_col : source_color = vec4(0.14, 0.27, 0.25, 1.0);
uniform vec4 deep_col : source_color = vec4(0.035, 0.085, 0.085, 1.0);
uniform float wave_scale = 0.35;

varying float v_view_z;

void vertex() {
	v_view_z = (VIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec2 uv1 = UV * wave_scale + vec2(TIME * 0.032, TIME * 0.021);
	vec2 uv2 = UV * wave_scale * 1.7 - vec2(TIME * 0.021, -TIME * 0.027);
	vec3 na = texture(norm_a, uv1).rgb * 2.0 - 1.0;
	vec3 nb = texture(norm_b, uv2).rgb * 2.0 - 1.0;
	NORMAL_MAP = normalize(vec3(na.xy + nb.xy, na.z * nb.z * 4.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.55;

	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float bottom = -view.z;
	float thick = clamp((bottom + v_view_z) * 0.24, 0.0, 1.0);

	ALBEDO = mix(shallow_col.rgb, deep_col.rgb, thick);
	ALPHA = mix(0.45, 0.88, thick);
	ROUGHNESS = 0.07;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
