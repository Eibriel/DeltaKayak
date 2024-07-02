shader_type spatial;

uniform vec3 albedo : source_color;
uniform sampler2D texture_1: filter_nearest;
uniform sampler2D texture_2: filter_nearest;

uniform float ssr_resolution   : hint_range(0.01, 10.0, 0.1)	= 2.0;
uniform float ssr_max_travel   : hint_range(0.0, 200.0, 0.1) 	= 30.0;
uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) 	= 4.0;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) 	= 0.7;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// SSR code from https://github.com/marcelb/GodotSSRWater
vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

bool is_within_screen_boundaries(vec2 position) {
	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

vec3 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
{
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = view_view_space * -1.0;
	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));

	vec2 current_screen_position = vec2(0.0);

	vec3 resulting_color = vec3(-1.0);
	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
	{
		current_position_view_space += reflect_vector_view_space * ssr_resolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

		float depth_texture_probe_raw = texture(DEPTH_TEXTURE, current_screen_position).x;
		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);

		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;

		resulting_color = (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) ? texture(SCREEN_TEXTURE, current_screen_position.xy).rgb : vec3(-1.0);
	}
	return resulting_color;
}
// End SSR code

void fragment() {
	vec2 global_uv = round(world_pos.xz * 50.0) / 50.0;
	vec2 time1 = (TIME * vec2(1, 0)) * 0.08;
	vec2 time2 = (TIME * vec2(0, 1)) * 0.06;
	vec3 color1 = texture(texture_1, (global_uv*0.1)+time1).rgb;
	vec3 color2 = texture(texture_2, (global_uv*0.1)+time2).rgb;

	//vec2 refraction_uv = refraction_intensity > 0.0 ? get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, NORMAL, PROJECTION_MATRIX, INV_PROJECTION_MATRIX) : SCREEN_UV;
	vec2 refraction_uv = SCREEN_UV;
	float surface_depth = FRAGCOORD.z;
	vec3 surface_view_position 	= get_view_position_from_uv(refraction_uv, surface_depth, INV_PROJECTION_MATRIX);
	vec3 ssr_color = get_ssr_color(surface_view_position, NORMAL, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	//if (ssr_color.r < 0.0){ssr_color.r = 0.0;}
	//if (ssr_color.g < 0.0){ssr_color.g = 0.0;}
	//if (ssr_color.b < 0.0){ssr_color.b = 0.0;}
	if (ssr_color.x < 0.0) {
		ALBEDO = (((color1 * color2) * 0.5) + 0.5) * albedo;
	} else {
		ALBEDO = (((color1 * color2) * 0.5) + 0.5) * albedo * mix(ssr_color, vec3(1.0), 0.5);
	}
	//ALBEDO = (((color1 * color2) * 0.5) + 0.5) * albedo;

	//ALBEDO = ssr_color + vec3(0.0);
	//ALPHA = 0.65; //0.85;
}
