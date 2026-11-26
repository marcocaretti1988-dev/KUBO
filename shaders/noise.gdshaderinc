// Rumore identico a mkNoise()/fbm() della versione HTML.
// noise_tex: 256x2, riga 0 = rumore n, riga 1 = rumore n2. R = permutazione, G = valore.
uniform sampler2D noise_tex : filter_nearest;

float hv(int row, int X, int Y) {
	int a = int(texelFetch(noise_tex, ivec2(X & 255, row), 0).r + 0.5);
	int b = (a + (Y & 255)) & 255;
	int c = int(texelFetch(noise_tex, ivec2(b, row), 0).r + 0.5);
	return texelFetch(noise_tex, ivec2(c, row), 0).g;
}

float pmod(float a, float m) { return a - m * floor(a / m); }

float vnoise(int row, float x, float y, float px, float py) {
	float fx = floor(x), fy = floor(y);
	float xf = x - fx, yf = y - fy;
	float x1 = fx + 1.0, y1 = fy + 1.0;
	if (px > 0.0) { fx = pmod(fx, px); x1 = pmod(x1, px); }
	if (py > 0.0) { fy = pmod(fy, py); y1 = pmod(y1, py); }
	int xi = int(fx), yi = int(fy), xj = int(x1), yj = int(y1);
	float u = xf * xf * (3.0 - 2.0 * xf), w = yf * yf * (3.0 - 2.0 * yf);
	float h00 = hv(row, xi, yi), h10 = hv(row, xj, yi), h01 = hv(row, xi, yj), h11 = hv(row, xj, yj);
	float a0 = h00 + (h10 - h00) * u, a1 = h01 + (h11 - h01) * u;
	return a0 + (a1 - a0) * w;
}

float fbm(int row, float x, float y, int o, float px, float py) {
	float s = 0.0, a = 0.5, f = 1.0, m = 0.0;
	for (int k = 0; k < 6; k++) {
		if (k >= o) break;
		s += a * vnoise(row, x * f, y * f, px * f, py * f);
		m += a; a *= 0.5; f *= 2.0;
	}
	return s / m;
}

float sst(float a, float b, float x) { float t = clamp((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
