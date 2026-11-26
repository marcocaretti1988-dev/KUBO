shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"
uniform float S; uniform vec3 A; uniform vec3 B; uniform float sx; uniform float sy;
uniform bool grain; uniform bool layer; uniform bool facet; uniform bool stripe; uniform bool brushed; uniform bool vein; uniform bool holes; uniform bool gloss;
uniform vec3 CR; uniform bool has_crack;
void fragment() {
	float TW = 640., THh = 14.;
	float w = ceil(TW * S), h = ceil(THh * S);
	float x = floor(UV.x * w), y = floor(UV.y * h);
	float xx = x / S, yy = y / S;
	float v = fbm(0, xx * sx, yy * sy, 4, 0., 0.);
	if (grain) v = v * .6 + .4 * (sin(yy * 2.2 + fbm(1, xx * .04, yy * .3, 2, 0., 0.) * 8.) * .5 + .5);
	if (layer) v = v * .5 + .5 * (mod(floor(yy / 3.5 + fbm(1, xx * .05, 0., 2, 0., 0.) * 2.), 2.) == 1. ? .7 : .35);
	if (facet) v = floor(v * 6.) / 6.;
	if (stripe) v = mod(floor((xx + yy) / 7.), 2.) == 1. ? .92 : .25 + v * .2;
	if (brushed) v = .35 + fbm(0, xx * .008, yy * 2., 3, 0., 0.) * .5;
	float lt = clamp(v * .9 + .15 - (yy / THh) * .45 + (yy < 2. ? .35 : 0.), 0., 1.);
	vec3 C = mix(A, B, lt);
	if (vein) { float vv = abs(fbm(1, xx * .05, yy * .2, 4, 0., 0.) - .5); if (vv < .03) C = mix(C, vec3(120., 126., 140.), .7); }
	if (holes && fbm(1, xx * .25, yy * .4, 2, 0., 0.) > .66) C = mix(C, vec3(60., 10., 25.), .6);
	if (has_crack) { float vv = abs(fbm(1, xx * .06, yy * .25, 4, 0., 0.) - .5); if (vv < .025) C = mix(C, CR, .85); }
	if (gloss && yy < 4.) C = mix(C, vec3(255.), .12 * (4. - yy) / 4.);
	COLOR = vec4(floor(C) / 255., 1.);
}
