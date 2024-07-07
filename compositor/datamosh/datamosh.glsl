#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rg16, set = 1, binding = 0) uniform image2D velocity_image;
layout(rgba16f, set = 2, binding = 0) uniform image2D previous_image;

// Our push PushConstant
layout(push_constant, std430) uniform Params {
	ivec2 size;
	int time;
} params;

float nrand(float x, float y) {
    return fract(sin(dot(vec2(x, y), vec2(12.9898, 78.233))) * 43758.5453);
}

// The code we want to execute in each invocation
void main() {
	float time = params.time;
	ivec2 size = params.size;

	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

	ivec2 uvr=ivec2(vec2(uv)/10.0)*10;

	float n = nrand(time,uvr.x*uvr.y);

	vec4 color_vel = imageLoad(velocity_image, uvr);
	color_vel=max(abs(color_vel)-round(n/1.4),0)*sign(color_vel);

	ivec2 uv2 = ivec2(gl_GlobalInvocationID.xy + (color_vel.rg*size));
	uv2 = min(uv2, size-10);
	uv2 = max(uv2, 0);

	if (n > 0.3) {
		if (n < 0.95) {
			vec4 color = imageLoad(previous_image, uv2) * 1.0;
			color += imageLoad(color_image, uv) * 0.0;
			imageStore(color_image, uv, color);
		}
	} else if (n > 0.15) {
		vec4 color = imageLoad(previous_image, uv);
		imageStore(color_image, uv, color);
	}

	//imageStore(color_image, uv, color_vel * -10.0);

	//imageStore(color_image, uv, vec4(vec2(uv2)*0.001, 0.0, 1.0));
}