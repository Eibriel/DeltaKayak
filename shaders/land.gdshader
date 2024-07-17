shader_type spatial;

uniform sampler2D texture_up: filter_nearest, source_color;
uniform sampler2D texture_side: filter_nearest, source_color;
uniform sampler2D texture_gradient;

varying vec3 vertex_normal;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_normal = NORMAL;
}

vec3 get_from_gradient(float value) {
	//return texture(texture_gradient, vec2(max(0, value), 0)).rgb;
	//return texture(texture_gradient, vec2(1.0, 0.0)).rgb;
	//return vec3(max(0, value));
	//return vec3(0.9);
	if (value > 0.5) {
		return vec3(1.0);
	} else {
		return vec3(0.0);
	}
}

void fragment() {
	// Called for every pixel the material is visible on.
	//float upness = (vertex_normal.x+1.0)/2.0;
	vec3 up_mask = get_from_gradient(-vertex_normal.z);//vec3(max(0, -vertex_normal.z));
	//ALBEDO = up_mask;
	vec3 left_mask = get_from_gradient(-vertex_normal.x);
	vec3 right_mask = get_from_gradient(vertex_normal.x);
	vec3 front_mask = get_from_gradient(-vertex_normal.y);
	vec3 back_mask = get_from_gradient(vertex_normal.y);
	vec3 up_color = texture(texture_up, world_pos.xz*0.1).rgb * up_mask;
	vec3 left_color = texture(texture_side, world_pos.yz*0.1).rgb * left_mask;
	vec3 right_color = texture(texture_side, world_pos.yz*0.1).rgb * right_mask;
	vec3 front_color = texture(texture_side, world_pos.xy*0.1).rgb * front_mask;
	vec3 back_color = texture(texture_side, world_pos.xy*0.1).rgb * back_mask;
	ALBEDO = up_color + left_color + right_color + front_color + back_color;

	float height = world_pos.y;

	if (height < 0.5 && height > -0.5) {
		float gg = abs(height);
		ALBEDO = mix(vec3(0.005, 0.001, 0.001), ALBEDO, gg / 0.5);
		//ALBEDO *= gg * 5.0;
	}

	//ALBEDO = front_color;
	//ALBEDO = up_mask;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
