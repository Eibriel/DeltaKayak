shader_type spatial;

uniform sampler2D heightmap;

varying vec3 world_pos;
varying vec2 global_uv;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	global_uv = (world_pos.xz / (1.0 * 4096.0) + vec2(0.5, 0.5));
	
	VERTEX.y += (texture(heightmap, global_uv).r * 2.0) - 0.8;
}

void fragment() {
	// Called for every pixel the material is visible on.
	float val = (texture(heightmap, global_uv).r * 2.0) - 0.8;
	val = clamp(val,0,1)*0.5;
	ALBEDO = vec3(val);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
