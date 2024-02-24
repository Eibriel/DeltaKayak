shader_type spatial;
render_mode cull_disabled;

uniform sampler2D texture_1: filter_nearest;

void vertex() {
}

void fragment() {
	vec2 time1 = (TIME * vec2(0, -1)) * 0.2;
	vec4 color1 = texture(texture_1, UV+time1);
	ALBEDO = color1.rgb;
	if (color1.a < 0.5) {
		discard;
	};
}
