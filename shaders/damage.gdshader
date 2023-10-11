shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float damage_level;
uniform float paddle_left;
uniform float paddle_right;

void fragment() {
	vec4 screenColor = texture(screen_texture, UV);
	vec4 textureColor = mix(vec4(1,1,1,1), texture(TEXTURE, UV), damage_level);

	vec4 screenu = vec4(SCREEN_UV.x, SCREEN_UV.x, SCREEN_UV.x, 1);
	vec4 screenv = vec4(SCREEN_UV.y, SCREEN_UV.y, SCREEN_UV.y, 1);
	vec4 vignete_right = (vec4(1,1,1,2)-(screenu * screenv));
	vec4 vignete_left = (vec4(1,1,1,2)-((vec4(1,1,1,2)-screenu) * screenv));
	
	vec4 mixed_right = mix(vec4(1,1,1,1), vignete_right, paddle_right);
	vec4 mixed_left = mix(vec4(1,1,1,1), vignete_left, paddle_left);
	
	COLOR = screenColor * textureColor * mixed_right * mixed_left;
}