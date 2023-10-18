shader_type spatial;

uniform vec3 albedo : source_color;
uniform sampler2D texture_1: filter_nearest;
uniform sampler2D texture_2: filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 global_uv = round(world_pos.xz * 50.0) / 50.0;
	vec2 time1 = (TIME * vec2(1, 0)) * 0.08;
	vec2 time2 = (TIME * vec2(0, 1)) * 0.06;
	vec3 color1 = texture(texture_1, (global_uv*0.1)+time1).rgb;
	vec3 color2 = texture(texture_2, (global_uv*0.1)+time2).rgb;
	ALBEDO = color1 * color2 * albedo;
	ALPHA = 0.85;
}
