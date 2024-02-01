shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest; //filter_linear_mipmap;

uniform sampler2D color_ramp;
uniform sampler2D color_rampb;

uniform float effect_amount : hint_range(-2.5, 2.5) = 1.0;

uniform int pixel_size;

void vertex() {
	// Called for every vertex the material is visible on.
}

vec2 uv_to_tfragcoord(vec2 uv, vec2 resolution) {
	return resolution * uv;
}

vec2 tfragcoord_to_uv(vec2 tfragcoord, vec2 resolution) {
	return tfragcoord / resolution;
}

vec2 fisheye(vec4 fragCoord, vec2 screen_size) {
	// glsl -> godot shader
	vec2 iResolution = 1.0 / screen_size;
	//vec4 fragCoord = FRAGCOORD;
	//normalized coords 
	vec2 p = fragCoord.xy / iResolution.x;
	//screen proroption
	float prop = iResolution.x / iResolution.y;
	//center coords
	vec2 m = vec2(0.5, 0.5 / prop);
	//vector from center to current fragment
	vec2 d = p - m;
	// distance of pixel from center
	float r = sqrt(dot(d, d)); 
	float power = effect_amount;
	//radius of 1:1 effect
	float bind;
	//stick to borders
	if (power > 0.0) 
		bind = sqrt(dot(m, m));
	else {
		if (prop < 1.0) 
    		bind = m.x; 
    	else 
        	bind = m.y;
	}

	vec2 uv;
	//fisheye
	if (power > 0.0)
		uv = m + normalize(d) * tan(r * power) * bind / tan( bind * power);
	//antifisheye
	else if (power < 0.0)
		uv = m + normalize(d) * atan(r * -power * 10.0) * bind / atan(-power * bind * 10.0);
	//no effect for power = 1.0
	else
		uv = p;
    uv.y *= prop;
	
	//return uv;
	return uv_to_tfragcoord(uv, iResolution);
}

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

vec4 pixelate(vec2 fragCoord, vec2 uv_pixel_size, int _pixel_size) {
	float x = float(int(fragCoord.x) % _pixel_size);
	float y = float(int(fragCoord.y) % _pixel_size);

	x = fragCoord.x + floor(float(_pixel_size) / 2.0) - x;
	y = fragCoord.y + floor(float(_pixel_size) / 2.0) - y;

	vec2 VIEWPORT_SIZE = 1.0 / uv_pixel_size;

	return texture(SCREEN_TEXTURE, vec2(x, y) / VIEWPORT_SIZE);
}

vec3 ramp_color(vec3 color) {
	vec3 ramped_color = texture(color_ramp, vec2(color.r,0)).rgb;
	if (color.g > color.r && color.g > color.b) {
		ramped_color = texture(color_rampb, vec2(color.g,0)).rgb;
	}
	return ramped_color;
}

void fragment() {
	vec2 tfragcoord = fisheye(FRAGCOORD, SCREEN_PIXEL_SIZE);
	//vec2 tfragcoord = FRAGCOORD.xy;
	vec2 uv = tfragcoord_to_uv(tfragcoord, 1.0/SCREEN_PIXEL_SIZE);
	vec3 screen_color = ramp_color(texture(SCREEN_TEXTURE, uv).rgb);
	vec3 screen_colorb = ramp_color(texture(SCREEN_TEXTURE, uv-vec2(SCREEN_PIXEL_SIZE.x*2.0,0)).rgb);
	vec3 pcolor = ramp_color(pixelate(tfragcoord, SCREEN_PIXEL_SIZE, pixel_size).rgb);
	vec3 pyuv = simple_RGB_to_yuv(pcolor);
	vec3 yuv = simple_RGB_to_yuv(screen_color);
	vec3 yuvb = simple_RGB_to_yuv(screen_colorb);
	yuv.x = pyuv.x;
	yuv.y = pyuv.y;
	yuv.z = (yuv.z * 0.8) + (yuvb.z * 0.2);
	COLOR = vec4(simple_yuv_to_RGB(yuv), 1.0);
	//COLOR = vec4(yuv.x, yuv.x, yuv.x, 1.0);
	//COLOR = pixelate(FRAGCOORD, SCREEN_PIXEL_SIZE, 4);
	//COLOR = vec4(uv.x, uv.y, 0.0, 1.0);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}


/* 
This shader is under MIT license. Feel free to use, improve and 
change this shader according to your needs and consider sharing 
the modified result to godotshaders.com.


shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D u_dither_tex;
uniform sampler2D u_color_tex;

uniform int u_bit_depth;
uniform float u_contrast;
uniform float u_offset;
uniform int u_dither_size;

void fragment() 
{
	// sample the screen texture at the desired output resolution (according to u_dither_size)
	// this will effectively pixelate the resulting output
	//vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0)) / float(u_dither_size);
	//vec2 screen_sample_uv = floor(UV * screen_size) / screen_size;
	//vec3 screen_col = texture(SCREEN_TEXTURE, screen_sample_uv).rgb;
	vec2 screen_size = vec2(640.0,480.0) / float(u_dither_size);
	vec3 screen_col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	
	// calculate pixel luminosity (https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color)
	float lum = (screen_col.r * 0.299) + (screen_col.g * 0.587) + (screen_col.b * 0.114);
	
	// adjust with contrast and offset parameters
	float contrast = u_contrast;
	lum = (lum - 0.5 + u_offset) * contrast + 0.5;
	lum = clamp(lum, 0.0, 1.0);
	
	// reduce luminosity bit depth to give a more banded visual if desired	
	float bits = float(u_bit_depth);
	lum = floor(lum * bits) / bits;
	
	// to support multicolour palettes, we want to dither between the two colours on the palette
	// which are adjacent to the current pixel luminosity.
	// to do this, we need to determine which 'band' lum falls into, calculate the upper and lower
	// bound of that band, then later we will use the dither texture to pick either the upper or 
	// lower colour.
	
	// get the palette texture size mapped so it is 1px high (so the x value however many colour bands there are)
	ivec2 col_size = textureSize(u_color_tex, 0);
	col_size /= col_size.y;
	
	float col_x = float(col_size.x) - 1.0; // colour boundaries is 1 less than the number of colour bands
	float col_texel_size = 1.0 / col_x; // the size of one colour boundary
	
	lum = max(lum - 0.00001, 0.0); // makes sure our floor calculation below behaves when lum == 1.0
	float lum_lower = floor(lum * col_x) * col_texel_size;
	float lum_upper = (floor(lum * col_x) + 1.0) * col_texel_size;
	float lum_scaled = lum * col_x - floor(lum * col_x); // calculates where lum lies between the upper and lower bound
	
	// map the dither texture onto the screen. there are better ways of doing this that makes the dither pattern 'stick'
	// with objects in the 3D world, instead of being mapped onto the screen. see lucas pope's details posts on how he 
	// achieved this in Obra Dinn: https://forums.tigsource.com/index.php?topic=40832.msg1363742#msg1363742
	ivec2 noise_size = textureSize(u_dither_tex, 0);
	vec2 inv_noise_size = vec2(1.0 / float(noise_size.x), 1.0 / float(noise_size.y));
	vec2 noise_uv = SCREEN_UV * inv_noise_size * vec2(float(screen_size.x), float(screen_size.y));
	float threshold = texture(u_dither_tex, noise_uv).r;
	COLOR = vec4(1,1,1,1);
	COLOR.r = SCREEN_UV.x;
	COLOR.g = SCREEN_UV.y;
	
	// adjust the dither slightly so min and max aren't quite at 0.0 and 1.0
	// otherwise we wouldn't get fullly dark and fully light dither patterns at lum 0.0 and 1.0
	threshold = threshold * 0.99 + 0.005;
	
	// the lower lum_scaled is, the fewer pixels will be below the dither threshold, and thus will use the lower bound colour,
	// and vice-versa
	float ramp_val = lum_scaled < threshold ? 0.0f : 1.0f;
	// sample at the lower bound colour if ramp_val is 0.0, upper bound colour if 1.0
	float col_sample = mix(lum_lower, lum_upper, ramp_val);
	vec3 final_col = texture(u_color_tex, vec2(col_sample, 0.5)).rgb;
	
	// return the final colour!
	//COLOR.rgb = final_col;
	//COLOR.a = 1.0;
}*/