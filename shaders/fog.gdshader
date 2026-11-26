shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"
uniform vec3 F;
void fragment() {
	float fw = 360., fh = 420.;
	float x = floor(UV.x * fw), y = floor(UV.y * fh);
	float v = fbm(0, x / fw * 6., y / fh * 5., 4, 6., 5.);
	COLOR = vec4(F / 255., floor(sst(.48, .8, v) * 255.) / 255.);
}
