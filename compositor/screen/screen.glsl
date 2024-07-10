#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Our push PushConstant
layout(push_constant, std430) uniform Params {
	ivec2 size;
	int time;
} params;

// YPbPr tools
const mat3 mat_rgb709_to_ycbcr = mat3(
     vec3(0.2215,  0.7154,  0.0721),
     vec3(-0.1145, -0.3855,  0.5000),
     vec3(0.5016, -0.4556, -0.0459)
);

float rgb709_unlinear(float s) {
    return mix(4.5*s, 1.099*pow(s, 1.0/2.2) - 0.099, step(0.018, s));
}

vec3 unlinearize_rgb709_from_rgb(vec3 color) {
    return vec3(
        rgb709_unlinear(color.r),
        rgb709_unlinear(color.g),
        rgb709_unlinear(color.b));
}

vec3 ycbcr_from_rgbp(vec3 color) {
    vec3 yuv = transpose(mat_rgb709_to_ycbcr)*color;
    vec3 quantized = vec3(
        (219.0*yuv.x + 16.0)/256.0,
        (224.0*yuv.y + 128.0)/256.0,
        (224.0*yuv.z + 128.0)/256.0);
    return quantized;
}

vec3 sRGB_to_yuv(vec3 color) {
    return ycbcr_from_rgbp(unlinearize_rgb709_from_rgb(color));
}

//  YPbPr SDTV

const mat3 mat_rgb_to_ypbpr = mat3(
     vec3(0.299,  0.587,  0.114),
     vec3(-0.169, -0.331,  0.5000),
     vec3(0.5, -0.419, -0.081)
);

const mat3 mat_ypbpr_to_rgb = mat3(
     vec3(1.0,  0.0,  1.402),
     vec3(1.0, -0.344,  -0.714),
     vec3(1.0, 1.772, 0.0)
);

vec3 simple_RGB_to_yuv(vec3 color) {
	return mat_rgb_to_ypbpr * color;
}

vec3 simple_yuv_to_RGB(vec3 color) {
	return mat_ypbpr_to_rgb * color;
}

// The code we want to execute in each invocation
void main() {
	float time = params.time;
	ivec2 size = params.size;

	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 uvp = ivec2(gl_GlobalInvocationID.xy / 2.0) * 2;

	vec4 color = imageLoad(color_image, uv);
	vec4 colorb = imageLoad(color_image, uvp+ivec2(2,2));


	vec3 color_yuv = simple_RGB_to_yuv(color.rgb);
	vec3 colorb_yuv = simple_RGB_to_yuv(colorb.rgb);

	vec3 mix_yuv = vec3(color_yuv.x, color_yuv.y, colorb_yuv.z);

	color = vec4(simple_yuv_to_RGB(mix_yuv), color.a);

	//color = vec4(color_yuv.r, color_yuv.g, color_yuv.b, color.a);

	// Dither
	//vec4 color = texture(TEXTURE, UV);
	
        float colors = 100;
        float dither = 0.5;
	vec4 color_dithered = vec4(1.0);

	//float a = floor(mod(UV.x / TEXTURE_PIXEL_SIZE.x, 2.0));
	//float b = floor(mod(UV.y / TEXTURE_PIXEL_SIZE.y, 2.0));
        float a = floor(mod(uvp.x, 2.0));	
        float b = floor(mod(uvp.y, 2.0));
	float c = mod(a + b, 2.0);

	color_dithered.r = (round(color.r * colors + dither) / colors) * c;
	color_dithered.g = (round(color.g * colors + dither) / colors) * c;
	color_dithered.b = (round(color.b * colors + dither) / colors) * c;
	c = 1.0 - c;
	color_dithered.r += (round(color.r * colors - dither) / colors) * c;
	color_dithered.g += (round(color.g * colors - dither) / colors) * c;
	color_dithered.b += (round(color.b * colors - dither) / colors) * c;

	//imageStore(color_image, uv, color);
        imageStore(color_image, uv, color_dithered);
}