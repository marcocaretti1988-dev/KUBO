shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"
uniform float W = 360.0; uniform float H; uniform vec3 A; uniform vec3 B;
void fragment() {
	float x = floor(UV.x * W), y = floor(UV.y * H);
	float v = fbm(0, x * .006, y * .004, 5, 0., 0.), m = sst(.5, .85, v) * .55;
	vec3 C = mix(A, B, fbm(1, x * .01, y * .01, 3, 0., 0.));
	COLOR = vec4(C / 255., m);
}
