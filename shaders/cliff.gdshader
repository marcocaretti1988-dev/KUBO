shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"
uniform float W = 360.0; uniform float TH = 760.0; uniform float S; uniform bool near;
uniform vec3 FOG; uniform vec3 R0; uniform vec3 R1; uniform vec3 TC0; uniform vec3 TC1; uniform bool has_top;
uniform vec3 GL; uniform bool has_glow; uniform bool neon; uniform bool city;
const float P = 8.0;
float edge(float side, float y) { float v = fbm(0, side * 5.3, y / TH * P, 5, 0., P); return near ? max(0., (v - .5) * 260.) : 24. + v * 95.; }
float eA(float side, float yi) { float yy = mod((yi - 3.) / S + TH, TH); return edge(side, yy) * S; }
void fragment() {
	float w = ceil(W * S), h = ceil(TH * S);
	float x = floor(UV.x * w), y = floor(UV.y * h);
	float yy = y / S;
	float el = eA(1., y + 3.), er = eA(2., y + 3.);
	float dIn = -1., side = 0.;
	if (x < el) { dIn = el - x; side = 1.; } else if (x > w - er) { dIn = x - (w - er); side = -1.; }
	if (dIn < 0.) { COLOR = vec4(0.); }
	else {
		float xx = x / S;
		float gr = fbm(1, xx * .07, yy / TH * P * 10., 4, 0., P * 10.);
		float str = sin(yy * .35 + fbm(0, xx * .05, yy / TH * P * 3., 2, 0., P * 3.) * 9.) * .5 + .5;
		float lt = .38 + (gr - .5) * .6 - min(.4, dIn / (70. * S)) + (side > 0. ? .12 : -.05) + (str > .92 ? -.18 : 0.);
		if (dIn < 2.2 * S) lt += .38;
		lt = clamp(lt, 0., 1.);
		vec3 C = mix(R0, R1, lt);
		if (has_top) {
			float yb = max(0., y + 3. - round(4. * S));
			float ebl = eA(1., yb), ebr = eA(2., yb);
			bool surf = side > 0. ? (x >= ebl) : (x <= w - ebr);
			if (surf && dIn < 18. * S) C = mix(TC0, TC1, clamp(gr * 1.2 - .1, 0., 1.));
		}
		if (has_glow && gr > .66 && str > .5) C = mix(C, GL, (gr - .66) * 2.4);
		if (neon && !near && mod(floor(xx), 9.) < 3. && mod(floor(yy / 7.), 2.) == 1. && gr > .56) C = gr > .62 ? vec3(255., 61., 245.) : vec3(34., 211., 238.);
		if (city && !neon && !near && mod(floor(xx), 9.) < 3. && mod(floor(yy / 7.), 2.) == 1. && gr > .6) C = vec3(255., 200., 120.);
		C = mix(C, FOG, near ? .04 : .36);
		C *= near ? .55 : 1.;
		COLOR = vec4(floor(C) / 255., 1.);
	}
}
