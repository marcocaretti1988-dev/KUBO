shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"
uniform float S; uniform vec3 R0; uniform vec3 R1; uniform vec3 GL; uniform bool has_glow; uniform bool neon;
void fragment() {
	float WALL = 20., WT = 240.;
	float w = ceil(WALL * S), h = ceil(WT * S);
	float x = floor(UV.x * w), y = floor(UV.y * h);
	float xx = x / S, yy = y / S;
	float gr = fbm(0, xx * .12, yy / WT * 24., 4, 0., 24.);
	float bl = sin(yy * .42 + gr * 5.) > .9 ? -.2 : 0.;
	float lt = clamp(.3 + (gr - .5) * .7 + bl + (xx > WALL - 3. ? .25 : 0.) - (xx < 4. ? .15 : 0.), 0., 1.);
	vec3 C = mix(R0, R1, lt);
	if (has_glow && gr > .68) C = mix(C, GL, (gr - .68) * 2.6);
	if (neon && xx > WALL - 5. && xx < WALL - 3.) C = vec3(34., 211., 238.);
	COLOR = vec4(floor(C) / 255., 1.);
}
