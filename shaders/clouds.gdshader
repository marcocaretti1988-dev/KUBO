shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"
uniform float W = 360.0; uniform float hh; uniform float y0; uniform float dens; uniform bool night; uniform vec3 lit; uniform vec3 sh;
void fragment() {
	float x = floor(UV.x * W), y = floor(UV.y * hh);
	float env = sin(3.14159265 * y / hh);
	float v = fbm(0, x / W * 7., (y + y0) * .016, 5, 7., 0.);
	float m = sst(dens, dens + .18, v) * env * (night ? .55 : .85);
	float s2 = fbm(1, x / W * 14., (y + y0) * .03, 3, 14., 0.);
	vec3 C = mix(sh, lit, sst(.3, .75, s2 + (1. - y / hh) * .25));
	COLOR = m > 0. ? vec4(floor(C) / 255., floor(m * 255.) / 255.) : vec4(0.);
}
