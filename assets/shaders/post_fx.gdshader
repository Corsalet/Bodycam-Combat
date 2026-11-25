shader_type canvas_item;

// Пост-обработка «линзы бодикама»: лёгкая бочка, капли с преломлением,
// виньетка и зерно. Вешается на fullscreen ColorRect в CanvasLayer(-1).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float fisheye = 0.03;
uniform float vig = 0.5;
uniform float grain = 0.045;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	uv = 0.5 + c * (1.0 + fisheye * r * r);
	// капли с преломлением вырезаны: на этом GL-драйвере ветка с smoothstep+shift
	// даёт структурные артефакты (диагностировано бисекцией), фича отключена.
	vec3 col = texture(screen_tex, uv).rgb;
	float v = 1.0 - smoothstep(0.3, 0.95, r);
	col *= mix(1.0 - vig * 0.5, 1.0, v);
	vec2 gp = mod(uv * vec2(1287.0, 911.0) + vec2(TIME * 61.0, TIME * 47.0), vec2(97.0, 89.0));
	col += (hash12(gp) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
