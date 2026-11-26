class_name Bake
extends RefCounted
## Genera (una volta per mondo) le immagini degli sfondi come faceva l'HTML:
## cielo lontano, nuvole, scogliere medie/vicine, nebbia, pareti, texture piattaforme.

const LANDS := {"mountains": 0, "spires": 1, "volcano": 2, "dunes": 3, "mesa": 4, "forest": 5, "swamp": 6, "hills": 7, "cloudsea": 8, "seabed": 9, "city": 10}
const TOPC := {"snow": ["#e9f3ff", "#ffffff"], "grass": ["#3f8f3a", "#7cc85a"], "moss": ["#4a6a2a", "#8cb04a"], "sand": ["#c98f4a", "#f2c98a"], "ash": ["#3a3436", "#6a6064"], "frost": ["#ffe6f0", "#ffffff"], "leaves": ["#c2501a", "#f2a03a"], "petals": ["#e98ab0", "#ffd0e2"]}
const PMAT := {"rock": {"a": null, "b": null, "sx": .12, "sy": .4}, "crystal": {"a": "#4a2f8a", "b": "#c9a8ff", "sx": .05, "sy": .05, "facet": 1}, "basalt": {"a": "#1a1210", "b": "#5a4640", "sx": .15, "sy": .4, "crack": "#ff7a2a"}, "ice": {"a": "#6fa8dc", "b": "#f2f9ff", "sx": .03, "sy": .2, "crack": "#ffffff"},
	"wood": {"a": "#4a2c16", "b": "#a8743e", "sx": .02, "sy": .9, "grain": 1}, "sand": {"a": "#a8692e", "b": "#f0c27a", "sx": .06, "sy": .6, "layer": 1}, "coral": {"a": "#a8324e", "b": "#ff9ab0", "sx": .15, "sy": .3, "holes": 1}, "marble": {"a": "#b8bec8", "b": "#ffffff", "sx": .04, "sy": .12, "vein": 1},
	"candy": {"a": "#ff6fa8", "b": "#ffe0ef", "sx": .05, "sy": .05, "stripe": 1}, "metal": {"a": "#4a5058", "b": "#c8ced6", "sx": .01, "sy": 1.2, "brushed": 1}, "obsidian": {"a": "#060608", "b": "#3a3440", "sx": .05, "sy": .1, "crack": "#ff2b2b", "gloss": 1}}

# ---------- rumore su CPU (per i pochi valori servono anche al gioco) ----------
class NoiseT:
	extends RefCounted
	var p = PackedInt32Array()
	var v = PackedFloat32Array()
	func _init(seed: int) -> void:
		var r = Rng.new(seed)
		var a = PackedInt32Array()
		for i in 256:
			a.append(i)
		for i in range(255, 0, -1):
			var j = int(floor(r.next() * (i + 1)))
			var t = a[i]; a[i] = a[j]; a[j] = t
		p = a
		for i in 256:
			v.append(r.next())
	func h(X: int, Y: int) -> float:
		return v[p[(p[X & 255] + (Y & 255)) & 255]]
	func n(x: float, y: float, px := 0.0, py := 0.0) -> float:
		var xi = floorf(x); var yi = floorf(y)
		var xf = x - xi; var yf = y - yi
		var x1 = xi + 1; var y1 = yi + 1
		if px > 0: xi = fposmod(xi, px); x1 = fposmod(x1, px)
		if py > 0: yi = fposmod(yi, py); y1 = fposmod(y1, py)
		var u = xf * xf * (3 - 2 * xf); var w = yf * yf * (3 - 2 * yf)
		var a0 = h(int(xi), int(yi)) + (h(int(x1), int(yi)) - h(int(xi), int(yi))) * u
		var a1 = h(int(xi), int(y1)) + (h(int(x1), int(y1)) - h(int(xi), int(y1))) * u
		return a0 + (a1 - a0) * w
	func fbm(x: float, y: float, o := 4, px := 0.0, py := 0.0) -> float:
		var s = 0.0; var a = .5; var f = 1.0; var m = 0.0
		for k in o:
			s += a * n(x * f, y * f, px * f, py * f); m += a; a *= .5; f *= 2
		return s / m

static func noise_tex(s1: int, s2: int) -> ImageTexture:
	var img = Image.create(256, 2, false, Image.FORMAT_RGF)
	var ns = [NoiseT.new(s1), NoiseT.new(s2)]
	for row in 2:
		var nz: NoiseT = ns[row]
		for i in 256:
			img.set_pixel(i, row, Color(float(nz.p[i]), nz.v[i], 0))
	return ImageTexture.create_from_image(img)

static func v3(h) -> Vector3:
	var c = Ctx.css(h)
	return Vector3(round(c.r * 255), round(c.g * 255), round(c.b * 255))

static func _mat(path: String, nt: Texture2D, u: Dictionary) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("noise_tex", nt)
	for k in u.keys():
		m.set_shader_parameter(k, u[k])
	return m

static func _rect(parent: Node, mat: ShaderMaterial, pos: Vector2, size: Vector2) -> void:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.material = mat
	parent.add_child(r)

static func _vp(host: Node, w: int, h: int) -> SubViewport:
	var vp = SubViewport.new()
	vp.size = Vector2i(maxi(1, w), maxi(1, h))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	host.add_child(vp)
	return vp

static func _ctxnode(vp: Node) -> Array:
	var n = Node2D.new()
	vp.add_child(n)
	var c = Ctx.new(n.get_canvas_item())
	c.quality = 1.5
	c.begin_frame()
	return [n, c]

## Restituisce un Dictionary con tutte le immagini del mondo i.
static func bake(host: Node, i: int, S: float, SW: float) -> Dictionary:
	var R: Dictionary = D.RW[i]
	var th: Array = D.THEMES[i]
	var W = D.W
	var goal = D.goal_of(i) * D.PPM
	var BH = int(ceil(goal * .15 + 1250))
	var LY = BH - 560
	var land: String = R.land
	var night = R.has("night")
	var ctxs: Array = []
	var vps = {}
	# ---------------- cielo lontano ----------------
	var vf = _vp(host, int(W), BH)
	vps["far"] = vf
	var A = _ctxnode(vf); var c: Ctx = A[1]; ctxs.append(c)
	var g = c.createLinearGradient(0, 0, 0, BH)
	g.addColorStop(0, K.mix(R.sky[0], "#000000", .6 if night else .35)); g.addColorStop(.5, R.sky[0]); g.addColorStop(.86, K.mix(R.sky[0], R.sky[1], .6)); g.addColorStop(1, R.sky[1])
	c.fillStyle = g
	# a strisce sottili per una sfumatura fedele
	for k in 40:
		c.fillRect(0, BH * k / 40.0, W, BH / 40.0 + 1)
	var rr = Rng.new(i + 5)
	for k in (700 if night else 260):
		var y = pow(rr.next(), 1.8) * BH * (.8 if night else .45)
		var a = (1 - y / (BH * .8)) * (.35 + rr.next() * .65)
		c.fillStyle = Color(1, 1, 1, clampf(a, 0, 1))
		var s = 1.6 if rr.next() < .08 else .9
		c.fillRect(rr.next() * W, y, s, s)
	var nt_far = noise_tex(i * 97 + 11, i * 31 + 7)
	if land == "space":
		_rect(vf, _mat("res://shaders/nebula.gdshader", nt_far, {"H": float(BH), "A": v3(th[4]), "B": v3(th[6])}), Vector2.ZERO, Vector2(W, BH))
	var B = _ctxnode(vf); var c2: Ctx = B[1]; ctxs.append(c2)
	var sx = W * .7
	var sy = float(BH - 760)
	var sr = 16.0 if (R.has("moon") or night) else 26.0
	var sg = c2.createRadialGradient(sx, sy, 0, sx, sy, sr * 9); sg.addColorStop(0, K.rgba(R.sun, .55)); sg.addColorStop(.25, K.rgba(R.sun, .18)); sg.addColorStop(1, K.rgba(R.sun, 0))
	c2.fillStyle = sg; c2.fillRect(0, sy - sr * 9, W, sr * 18)
	K.circ(c2, sx, sy, sr, R.sun)
	if R.has("moon"):
		K.circ(c2, sx - 4, sy - 3, sr * .3, K.rgba("#000000", .12)); K.circ(c2, sx + 5, sy + 4, sr * .22, K.rgba("#000000", .1))
	var meta = {"vents": [], "lights": [], "tw": [], "sun": Vector2(sx, sy), "BH": BH, "LY": LY}
	_rect(vf, _mat("res://shaders/land.gdshader", nt_far, {"land": LANDS.get(land, 11), "LY": float(LY), "H": 560.0, "FOG": v3(R.fog), "RK0": v3(R.rk[0]), "RK1": v3(R.rk[1]),
		"SN": v3(R.get("snow", "#ffffff")), "GL": v3(R.get("glow", "#000000")), "FOGW": v3(K.mix(R.fog, "#ffffff", .3)), "has_glow": R.has("glow"), "has_snow": R.has("snow"), "neon": R.has("neon")}), Vector2(0, LY), Vector2(W, 560))
	var Cn = _ctxnode(vf); var c3: Ctx = Cn[1]; ctxs.append(c3)
	var nz = NoiseT.new(i * 97 + 11)
	var nz2 = NoiseT.new(i * 31 + 7)
	var r2 = Rng.new(i * 3 + 1)
	if land == "city":
		for k in 14:
			var x = r2.next() * W; var w = 14 + r2.next() * 26; var h = 60 + r2.next() * 170; var y = float(BH - 60)
			c3.fillStyle = K.mix(R.rk[0], R.fog, .3); c3.fillRect(x, y - h, w, h + 60)
			var wy = y - h + 5
			while wy < y:
				var wx = x + 3
				while wx < x + w - 3:
					if r2.next() < .06:
						var f = .5 + r2.next() * 2
						var ph = r2.next() * 7
						var lc = ("#ff3df5" if r2.next() < .5 else "#22d3ee") if R.has("neon") else "#ffe8a0"
						meta.lights.append({"x": wx, "y": wy, "f": f, "ph": ph, "col": lc})
					elif r2.next() < .35:
						c3.fillStyle = ("#ff3df5" if r2.next() < .5 else "#22d3ee") if R.has("neon") else "#ffd678"; c3.fillRect(wx, wy, 2, 3)
					wx += 5
				wy += 7
	if land == "volcano":
		for kf in [[0, .3], [1, .72]]:
			meta.vents.append({"x": kf[1] * W, "y": LY + _height(nz, nz2, R, kf[0], kf[1] * W)})
		var cx = .72 * W
		var cy = LY + _height(nz, nz2, R, 1, cx)
		var vg = c3.createRadialGradient(cx, cy, 0, cx, cy, 120); vg.addColorStop(0, K.rgba(R.glow, .8)); vg.addColorStop(1, K.rgba(R.glow, 0))
		c3.fillStyle = vg; c3.fillRect(cx - 120, cy - 120, 240, 240)
	if land == "swamp":
		c3.fillStyle = K.rgba(K.mix(R.fog, "#000000", .2), .9); c3.fillRect(0, BH - 130, W, 130)
		for k in 7:
			var x = r2.next() * W; var h = 80 + r2.next() * 90
			c3.strokeStyle = K.mix(R.rk[0], R.fog, .3); c3.lineWidth = 3; c3.beginPath(); c3.moveTo(x, BH - 120); c3.lineTo(x + (r2.next() - .5) * 10, BH - 120 - h); c3.stroke()
			for b in 3:
				c3.lineWidth = 1.5; c3.beginPath()
				var by = BH - 120 - h * (.5 + b * .15)
				c3.moveTo(x, by); c3.lineTo(x + (r2.next() - .5) * 50, by - 20 - r2.next() * 20); c3.stroke()
	if land == "seabed":
		c3.save(); c3.globalCompositeOperation = "lighter"
		for k in 6:
			var x = r2.next() * W
			var lg = c3.createLinearGradient(0, 0, 0, BH); lg.addColorStop(0, "rgba(160,230,255,.12)"); lg.addColorStop(1, "rgba(160,230,255,0)")
			c3.fillStyle = lg; c3.beginPath(); c3.moveTo(x, 0); c3.lineTo(x + 30, 0); c3.lineTo(x - 80, BH); c3.lineTo(x - 140, BH); c3.fill()
		c3.restore()
		for k in 10:
			var x = r2.next() * W; var h = 60 + r2.next() * 120
			c3.strokeStyle = K.rgba("#2f9e44", .6); c3.lineWidth = 3; c3.beginPath(); c3.moveTo(x, BH)
			for j in range(1, 10):
				c3.lineTo(x + sin(j * .9 + k) * 8, BH - h * j / 9.0)
			c3.stroke()
	if land == "space":
		var px = W * .3; var py = BH - 120.0; var pr = 150.0
		var pg = c3.createRadialGradient(px - 50, py - 60, 10, px, py, pr); pg.addColorStop(0, K.mix(th[6], "#ffffff", .3)); pg.addColorStop(.7, K.mix(th[4], "#000000", .3)); pg.addColorStop(1, "#05050c")
		c3.fillStyle = pg; c3.beginPath(); c3.arc(px, py, pr, 0, 7); c3.fill()
	var rt = Rng.new(i * 9 + 4)
	for k in 70:
		var x = rt.next() * W; var y = pow(rt.next(), 1.6) * BH * .7; var s = 2.0 if rt.next() < .3 else 1.3
		var ph = rt.next() * 7; var f = 1 + rt.next() * 3
		meta.tw.append({"x": x, "y": y, "s": s, "ph": ph, "f": f})
	# ---------------- nuvole ----------------
	var cy0 = maxi(0, BH - 1150)
	var chh = BH - 380 - cy0
	var vcl = _vp(host, int(W), chh)
	vps["clouds"] = vcl
	var dens = .42 if land == "cloudsea" else (.6 if night else .52)
	_rect(vcl, _mat("res://shaders/clouds.gdshader", nt_far, {"hh": float(chh), "y0": float(cy0), "dens": dens, "night": night, "lit": v3(K.mix(R.sun, "#ffffff", .4)), "sh": v3(K.mix(R.fog, "#000000", .5 if night else .15))}), Vector2.ZERO, Vector2(W, chh))
	# ---------------- scogliere ----------------
	var TC = TOPC.get(R.get("top", ""), null) if R.get("top") != null else null
	for near in [false, true]:
		var w = int(ceil(W * S)); var h = int(ceil(D.TH * S))
		var vc = _vp(host, w, h)
		vps["near" if near else "mid"] = vc
		var nt = noise_tex(i * 53 + (9 if near else 3), i * 17 + (5 if near else 2))
		_rect(vc, _mat("res://shaders/cliff.gdshader", nt, {"S": S, "near": near, "FOG": v3(R.fog), "R0": v3(R.rk[0]), "R1": v3(R.rk[1]), "TC0": v3(TC[0] if TC else "#000"), "TC1": v3(TC[1] if TC else "#000"), "has_top": TC != null,
			"GL": v3(R.get("glow", "#000")), "has_glow": R.has("glow"), "neon": R.has("neon"), "city": land == "city"}), Vector2.ZERO, Vector2(w, h))
	# ---------------- nebbia ----------------
	var vfg = _vp(host, 360, 420)
	vps["fog"] = vfg
	_rect(vfg, _mat("res://shaders/fog.gdshader", noise_tex(i * 7 + 99, 1), {"F": v3(K.mix(R.fog, "#ffffff", .15 if night else .35))}), Vector2.ZERO, Vector2(360, 420))
	# ---------------- pareti ----------------
	var ww = int(ceil(D.WALL * SW)); var wh = int(ceil(D.WT * SW))
	var vw = _vp(host, ww, wh)
	vps["wall"] = vw
	_rect(vw, _mat("res://shaders/wall.gdshader", noise_tex(i * 41 + 3, 1), {"S": SW, "R0": v3(K.mix(R.rk[0], "#000000", .1)), "R1": v3(R.rk[1]), "GL": v3(R.get("glow", "#000")), "has_glow": R.has("glow"), "neon": R.has("neon")}), Vector2.ZERO, Vector2(ww, wh))
	# ---------------- piattaforme ----------------
	var m: Dictionary = PMAT.get(R.pt, PMAT.rock)
	var PS = 2.0
	var pw = int(ceil(640 * PS)); var ph2 = int(ceil(14 * PS))
	var vpl = _vp(host, pw, ph2)
	vps["ptex"] = vpl
	var ca = m.a if m.a != null else K.mix(R.rk[1], "#000000", .25)
	var cb = m.b if m.b != null else K.mix(R.rk[1], "#ffffff", .25)
	_rect(vpl, _mat("res://shaders/plat.gdshader", noise_tex(i * 19 + 77, i * 5 + 3), {"S": PS, "A": v3(ca), "B": v3(cb), "sx": float(m.sx), "sy": float(m.sy), "grain": m.has("grain"), "layer": m.has("layer"), "facet": m.has("facet"), "stripe": m.has("stripe"),
		"brushed": m.has("brushed"), "vein": m.has("vein"), "holes": m.has("holes"), "gloss": m.has("gloss"), "CR": v3(m.get("crack", "#000")), "has_crack": m.has("crack")}), Vector2.ZERO, Vector2(pw, ph2))
	# rendering e copia delle immagini
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out = {"meta": meta}
	for k in vps.keys():
		var img: Image = vps[k].get_texture().get_image()
		out[k] = ImageTexture.create_from_image(img)
	for cx2 in ctxs:
		cx2.free_all()
	for k in vps.keys():
		vps[k].queue_free()
	out["clouds_y0"] = cy0
	out["TW"] = 640
	return out

static func _height(n: NoiseT, n2: NoiseT, R: Dictionary, k: int, x: float) -> float:
	var s = k * 13.7
	var base: float = [150, 230, 320][k]
	match str(R.land):
		"volcano":
			var cx: float = [.3, .72, .15][k] * D.W
			var cone = maxf(0, 1 - absf(x - cx) / [170, 140, 120][k])
			return base + 30 - n.fbm(x * .01 + s, s, 4) * 60 - minf(.86, cone) * [260, 220, 170][k]
	return base
