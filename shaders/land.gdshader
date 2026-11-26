shader_type canvas_item;
// Paesaggio lontano (tre catene) di paintFar(): disegnato in un rettangolo W x 560 a partire da LY.
#include "res://shaders/noise.gdshaderinc"
uniform int land = 0; // 0 mountains 1 spires 2 volcano 3 dunes 4 mesa 5 forest 6 swamp 7 hills 8 cloudsea 9 seabed 10 city 11 default
uniform float LY;
uniform float H;
uniform vec3 FOG; uniform vec3 RK0; uniform vec3 RK1; uniform vec3 SN; uniform vec3 GL; uniform vec3 FOGW;
uniform bool has_glow; uniform bool has_snow; uniform bool neon;
uniform float W = 360.0;

float heightAt(int k, float x) {
	float s = float(k) * 13.7;
	float base = k == 0 ? 150.0 : (k == 1 ? 230.0 : 320.0);
	float h;
	if (land == 0) { float v = fbm(0, x * .007 + s, s, 4, 0., 0.), rd = 1. - abs(2. * v - 1.); h = base - pow(rd, 1.3) * (k == 0 ? 300. : (k == 1 ? 250. : 190.)) + 40.; }
	else if (land == 1) { float v = fbm(0, x * .03 + s, s, 4, 0., 0.), rd = 1. - abs(2. * v - 1.); h = base - pow(rd, 3.) * (k == 0 ? 340. : (k == 1 ? 300. : 240.)) + 60.; }
	else if (land == 2) { float cx = (k == 0 ? .3 : (k == 1 ? .72 : .15)) * W; float cone = max(0., 1. - abs(x - cx) / (k == 0 ? 170. : (k == 1 ? 140. : 120.))); h = base + 30. - fbm(0, x * .01 + s, s, 4, 0., 0.) * 60. - min(.86, cone) * (k == 0 ? 260. : (k == 1 ? 220. : 170.)); }
	else if (land == 3) { h = base + 40. - (sin(x * .018 + s) * .5 + .5) * (k == 0 ? 60. : (k == 1 ? 70. : 80.)) - fbm(0, x * .008 + s, s, 3, 0., 0.) * 60.; }
	else if (land == 4) { float v = fbm(0, x * .01 + s, s, 4, 0., 0.), q = sst(.45, .52, v) * .6 + sst(.62, .68, v) * .4; h = base + 60. - q * (k == 0 ? 180. : (k == 1 ? 160. : 130.)); }
	else if (land == 5 || land == 6) { float hill = fbm(0, x * .008 + s, s, 3, 0., 0.) * (land == 6 ? 30. : 90.); float can = abs(sin(x * (.22 - float(k) * .04) + s)) * (k == 0 ? 10. : (k == 1 ? 14. : 20.)) + fbm(1, x * .08 + s, s, 2, 0., 0.) * 16.; h = base + 40. - hill - can - (land == 6 ? 0. : 20.); }
	else if (land == 7) { h = base + 30. - fbm(0, x * .009 + s, s, 4, 0., 0.) * (k == 0 ? 130. : (k == 1 ? 110. : 90.)); }
	else if (land == 8) { h = base + 60. - fbm(0, x * .02 + s, s, 4, 0., 0.) * (k == 0 ? 50. : (k == 1 ? 60. : 70.)); }
	else if (land == 9) { float v = fbm(0, x * .015 + s, s, 5, 0., 0.); h = base + 20. - pow(v, 1.5) * (k == 0 ? 260. : (k == 1 ? 220. : 180.)); }
	else if (land == 10) { h = base + 60. - fbm(0, x * .01 + s, s, 2, 0., 0.) * 30.; }
	else { h = base + 80. - fbm(0, x * .01 + s, s, 3, 0., 0.) * 50.; }
	return h;
}

void fragment() {
	float x = floor(UV.x * W);
	float y = floor(UV.y * H);
	vec4 outc = vec4(0.);
	for (int kk = 2; kk >= 0; kk--) {
		float hk = heightAt(kk, x);
		float top = max(0., floor(hk));
		if (y < top) continue;
		float slope = clamp((heightAt(kk, x + 3.) - heightAt(kk, x - 3.)) / 6., -2., 2.);
		float fogK = kk == 0 ? .55 : (kk == 1 ? .32 : .12);
		float dep = y - hk;
		float gr = fbm(1, x * .06 + float(kk) * 7., (y + LY) * .06, 4, 0., 0.);
		float nd = fbm(1, x * .02 + float(kk) * 3., (y + LY) * .012, 3, 0., 0.);
		float lt = .5 - slope * .16 * exp(-dep / ((land == 5 || land == 6) ? 10. : 45.)) + (gr - .5) * .38 + (nd - .5) * .3 - min(.32, dep / 300.);
		lt = clamp(lt, 0., 1.);
		vec3 C = mix(RK0, RK1, lt);
		if (land == 8) { C = mix(FOGW, vec3(255.), max(0., 1. - dep / 90.) * (.6 + gr * .4)); }
		else if (has_snow && land == 0) { float snowL = (kk == 0 ? 120. : (kk == 1 ? 175. : 250.)) + (nd - .5) * 60.; if (y < snowL && dep < (snowL - y) * .9 + 8.) C = mix(mix(SN, vec3(110., 128., 155.), .45), SN, clamp(.55 - slope * .3 * exp(-dep / 45.) + (gr - .5) * .5, 0., 1.)); }
		else if (land == 3) { C = mix(vec3(138., 84., 40.), vec3(246., 201., 126.), clamp(.55 - slope * .5 + (gr - .5) * .15 - dep / 500., 0., 1.)); }
		if (has_glow && land == 2 && dep < 40. && gr > .62) C = mix(C, GL, (gr - .62) * 2.5 * (1. - dep / 40.));
		if (land == 10 && kk == 2 && dep > 4. && mod(x, 7.) < 3. && mod(floor(dep / 6.), 2.) == 1. && gr > .55) C = neon ? mix(vec3(255., 61., 245.), vec3(34., 211., 238.), mod(x * 13., 10.) / 10.) : vec3(255., 214., 120.);
		C = mix(C, FOG, fogK * (1. - dep / H * .3) + min(.35, dep / H * .6) * (kk < 2 ? 1. : .5));
		outc = vec4(floor(C) / 255., 1.);
		break;
	}
	COLOR = outc;
}
