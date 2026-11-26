class_name Ctx
extends RefCounted
## Piccolo clone del Canvas 2D dell'HTML: stesse funzioni (fillStyle, beginPath,
## arc, fill, stroke, save/restore...) così il disegno di Kubo Run è identico.
## Disegna tramite RenderingServer su una serie di "strati" (per il blend additivo).

class Grad:
	extends RefCounted
	var lin := true
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var r0 := 0.0
	var r1 := 0.0
	var stops: Array = []   # [[t, Color], ...]
	func addColorStop(t: float, c) -> void:
		stops.append([t, Ctx.css(c)])
	func at(t: float) -> Color:
		if stops.is_empty():
			return Color(0, 0, 0, 0)
		if t <= stops[0][0]:
			return stops[0][1]
		for i in range(1, stops.size()):
			if t <= stops[i][0]:
				var a = stops[i - 1]
				var b = stops[i]
				var d: float = b[0] - a[0]
				return (a[1] as Color).lerp(b[1], 0.0 if d <= 0.0 else (t - a[0]) / d)
		return stops[-1][1]
	func col_at(p: Vector2) -> Color:
		if lin:
			var d := p1 - p0
			var l2 := d.length_squared()
			return at(0.0 if l2 == 0.0 else (p - p0).dot(d) / l2)
		var dist := p.distance_to(p1)
		var span := r1 - r0
		return at(0.0 if span == 0.0 else (dist - r0) / span)

static var _cc := {}
static var _ff := {}

static func css(v) -> Color:
	if v is Color:
		return v
	if v == null:
		return Color(0, 0, 0, 0)
	var s := str(v)
	if _cc.has(s):
		return _cc[s]
	var c := Color(0, 0, 0, 1)
	var t := s.strip_edges().to_lower()
	if t.begins_with("#"):
		var h := t.substr(1)
		if h.length() == 3 or h.length() == 4:
			var e := ""
			for ch in h:
				e += ch + ch
			h = e
		c = Color.html("#" + h)
	elif t.begins_with("rgb"):
		var inner := t.substr(t.find("(") + 1).trim_suffix(")")
		var p := inner.split(",")
		c = Color(float(p[0]) / 255.0, float(p[1]) / 255.0, float(p[2]) / 255.0, float(p[3]) if p.size() > 3 else 1.0)
	elif t.begins_with("hsl"):
		var inner2 := t.substr(t.find("(") + 1).trim_suffix(")")
		var q := inner2.split(",")
		var hh := fposmod(float(q[0]), 360.0) / 360.0
		var ss := float(q[1].replace("%", "")) / 100.0
		var ll := float(q[2].replace("%", "")) / 100.0
		c = hsl(hh, ss, ll, float(q[3]) if q.size() > 3 else 1.0)
	elif t == "transparent":
		c = Color(0, 0, 0, 0)
	elif t == "white":
		c = Color.WHITE
	elif t == "black":
		c = Color.BLACK
	_cc[s] = c
	if _cc.size() > 6000:
		_cc.clear()
	return c

static func hsl(h: float, s: float, l: float, a := 1.0) -> Color:
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	return Color(_hue(p, q, h + 1.0 / 3.0), _hue(p, q, h), _hue(p, q, h - 1.0 / 3.0), a)

static func _hue(p: float, q: float, t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 0.5:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p

# ---------------- stato ----------------
var root: RID
var layers: Array[RID] = []
var li := 0
var cur: RID
var cur_add := false
var mat_add: RID
var xf := Transform2D.IDENTITY
var stack: Array = []
var fillStyle: Variant = "#000"
var strokeStyle: Variant = "#000"
var lineWidth := 1.0
var globalAlpha := 1.0
var font := "10px Bungee"
var textAlign := "left"
var textBaseline := "alphabetic"
var shadowColor: Variant = "#0000"
var shadowBlur := 0.0
var shadowOffsetX := 0.0
var shadowOffsetY := 0.0
var lineCap := "butt"
var globalCompositeOperation := "source-over"
var dash: Array = []
var clip_poly: PackedVector2Array = PackedVector2Array()
var paths: Array = []   # Array[PackedVector2Array]
var closed: Array = []
var pen := Vector2.ZERO
var has_pen := false
var sub0 := Vector2.ZERO
var quality := 1.0

func _init(parent: RID) -> void:
	root = parent
	mat_add = RenderingServer.material_create()
	var sh := RenderingServer.shader_create()
	RenderingServer.shader_set_code(sh, "shader_type canvas_item;\nrender_mode blend_add;\n")
	RenderingServer.material_set_shader(mat_add, sh)

func begin_frame() -> void:
	for r in layers:
		RenderingServer.canvas_item_clear(r)
	li = -1
	cur_add = false
	_next_layer()
	xf = Transform2D.IDENTITY
	stack.clear()
	globalAlpha = 1.0
	globalCompositeOperation = "source-over"
	shadowBlur = 0.0
	dash = []
	clip_poly = PackedVector2Array()

func free_all() -> void:
	for r in layers:
		RenderingServer.free_rid(r)
	layers.clear()

func _next_layer() -> void:
	li += 1
	if li >= layers.size():
		var r := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(r, root)
		RenderingServer.canvas_item_set_draw_index(r, li)
		layers.append(r)
	cur = layers[li]
	RenderingServer.canvas_item_set_material(cur, mat_add if cur_add else RID())

func _blend() -> void:
	var want := globalCompositeOperation == "lighter"
	if want != cur_add:
		cur_add = want
		_next_layer()

# ---------------- trasformazioni ----------------
func save() -> void:
	stack.append([xf, fillStyle, strokeStyle, lineWidth, globalAlpha, font, textAlign, textBaseline, shadowColor, shadowBlur, lineCap, globalCompositeOperation, dash, clip_poly, shadowOffsetX, shadowOffsetY])

func restore() -> void:
	if stack.is_empty():
		return
	var s: Array = stack.pop_back()
	xf = s[0]; fillStyle = s[1]; strokeStyle = s[2]; lineWidth = s[3]; globalAlpha = s[4]
	font = s[5]; textAlign = s[6]; textBaseline = s[7]; shadowColor = s[8]; shadowBlur = s[9]
	lineCap = s[10]; globalCompositeOperation = s[11]; dash = s[12]; clip_poly = s[13]
	shadowOffsetX = s[14]; shadowOffsetY = s[15]

func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(x, y))

func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)

func scale(x: float, y: float) -> void:
	xf = xf * Transform2D(Vector2(x, 0), Vector2(0, y), Vector2.ZERO)

func setTransform(a: float, b: float, c: float, d: float, e: float, f: float) -> void:
	xf = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(e, f))

func setLineDash(d: Array) -> void:
	dash = d

func _sc() -> float:
	return sqrt(absf(xf.determinant()))

# ---------------- percorsi ----------------
func beginPath() -> void:
	paths = []
	closed = []
	has_pen = false

func _pt(x: float, y: float) -> void:
	var p := xf * Vector2(x, y)
	if paths.is_empty():
		paths.append(PackedVector2Array())
		closed.append(false)
		sub0 = Vector2(x, y)
	paths[-1].append(p)
	pen = Vector2(x, y)
	has_pen = true

func moveTo(x: float, y: float) -> void:
	paths.append(PackedVector2Array([xf * Vector2(x, y)]))
	closed.append(false)
	pen = Vector2(x, y)
	sub0 = pen
	has_pen = true

func lineTo(x: float, y: float) -> void:
	if not has_pen:
		moveTo(x, y)
		return
	_pt(x, y)

func closePath() -> void:
	if not closed.is_empty():
		closed[-1] = true
		if paths[-1].size() > 0:
			var f: Vector2 = paths[-1][0]
			pen = sub0
			paths.append(PackedVector2Array([f]))
			closed.append(false)

func _segs(len_px: float) -> int:
	return clampi(int(len_px * _sc() * 0.35 * quality) + 4, 4, 64)

func quadraticCurveTo(cx: float, cy: float, x: float, y: float) -> void:
	if not has_pen:
		moveTo(cx, cy)
	var p0 := pen
	var n := _segs(p0.distance_to(Vector2(cx, cy)) + Vector2(cx, cy).distance_to(Vector2(x, y)))
	for i in range(1, n + 1):
		var t := float(i) / n
		var a := p0.lerp(Vector2(cx, cy), t)
		var b := Vector2(cx, cy).lerp(Vector2(x, y), t)
		var q := a.lerp(b, t)
		_pt(q.x, q.y)

func bezierCurveTo(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	if not has_pen:
		moveTo(c1x, c1y)
	var p0 := pen
	var c1 := Vector2(c1x, c1y)
	var c2 := Vector2(c2x, c2y)
	var p3 := Vector2(x, y)
	var n := _segs(p0.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(p3))
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := p0.bezier_interpolate(c1, c2, p3, t)
		_pt(q.x, q.y)

func arc(x: float, y: float, r: float, a0: float, a1: float, ccw := false) -> void:
	ellipse(x, y, r, r, 0.0, a0, a1, ccw)

func ellipse(x: float, y: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw := false) -> void:
	rx = absf(rx); ry = absf(ry)
	var sweep := a1 - a0
	if not ccw:
		if sweep >= TAU: sweep = TAU
		elif sweep < 0.0: sweep = fposmod(sweep, TAU)
	else:
		if -sweep >= TAU: sweep = -TAU
		elif sweep > 0.0: sweep = -fposmod(-sweep, TAU)
	var n := clampi(int(maxf(rx, ry) * _sc() * absf(sweep) * 0.25 * quality) + 6, 6, 72)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n + 1:
		var a := a0 + sweep * i / n
		var px := cos(a) * rx
		var py := sin(a) * ry
		_pt(x + px * cr - py * sr, y + px * sr + py * cr)

func rect(x: float, y: float, w: float, h: float) -> void:
	moveTo(x, y); lineTo(x + w, y); lineTo(x + w, y + h); lineTo(x, y + h); closePath()

func roundRect(x: float, y: float, w: float, h: float, r = 0.0) -> void:
	var rr: float = r[0] if r is Array else float(r)
	rr = minf(rr, minf(absf(w), absf(h)) / 2.0)
	if rr <= 0.0:
		rect(x, y, w, h)
		return
	moveTo(x + rr, y)
	arc(x + w - rr, y + rr, rr, -PI / 2, 0)
	arc(x + w - rr, y + h - rr, rr, 0, PI / 2)
	arc(x + rr, y + h - rr, rr, PI / 2, PI)
	arc(x + rr, y + rr, rr, PI, PI * 1.5)
	closePath()

func clip() -> void:
	for p in paths:
		if p.size() >= 3:
			var poly: PackedVector2Array = p
			if clip_poly.size() >= 3:
				var r := Geometry2D.intersect_polygons(clip_poly, poly)
				poly = r[0] if r.size() > 0 else PackedVector2Array()
			clip_poly = poly if poly.size() >= 3 else PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
			return

# ---------------- riempimento ----------------
func _col(v) -> Color:
	var c := css(v)
	c.a *= globalAlpha
	return c

func _poly_out(pts: PackedVector2Array, style, extra_alpha := 1.0) -> void:
	if pts.size() < 3:
		return
	var polys: Array = [pts]
	if clip_poly.size() >= 3:
		polys = Geometry2D.intersect_polygons(pts, clip_poly)
	var grad := style is Grad
	var inv := xf.affine_inverse() if grad else Transform2D.IDENTITY
	var sc := Color()
	if not grad:
		sc = _col(style)
		sc.a *= extra_alpha
		if sc.a <= 0.002:
			return
	for poly in polys:
		if poly.size() < 3:
			continue
		var idx := Geometry2D.triangulate_polygon(poly)
		if idx.is_empty():
			continue
		var cols := PackedColorArray()
		if grad:
			cols.resize(poly.size())
			for k in poly.size():
				var c: Color = style.col_at(inv * poly[k])
				c.a *= globalAlpha * extra_alpha
				cols[k] = c
		else:
			cols.resize(poly.size())
			cols.fill(sc)
		RenderingServer.canvas_item_add_triangle_array(cur, idx, poly, cols)

func _shadow_fill(pts: PackedVector2Array) -> void:
	if shadowBlur <= 0.0 and shadowOffsetX == 0.0 and shadowOffsetY == 0.0:
		return
	var sc := css(shadowColor)
	if sc.a <= 0.01:
		return
	var off := xf.basis_xform(Vector2(shadowOffsetX, shadowOffsetY))
	if shadowBlur > 0.0 and off == Vector2.ZERO:
		# bagliore morbido: due anelli più larghi e trasparenti
		var cen := Vector2.ZERO
		for p in pts:
			cen += p
		cen /= pts.size()
		for k in 2:
			var g := shadowBlur * _sc() * (0.35 + k * 0.4)
			var big := PackedVector2Array()
			for p in pts:
				var d := p - cen
				big.append(p + (d.normalized() * g if d.length() > 0.01 else Vector2.ZERO))
			var c := sc
			c.a *= globalAlpha * (0.28 - k * 0.1)
			_poly_out(big, c, 1.0)
		return
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + off)
	var c2 := sc
	c2.a *= globalAlpha
	_poly_out(moved, c2, 1.0)

func fill() -> void:
	if absf(xf.determinant()) < 1e-9:
		return
	_blend()
	for p in paths:
		if p.size() >= 3:
			_shadow_fill(p)
			_poly_out(p, fillStyle)

func fillRect(x: float, y: float, w: float, h: float) -> void:
	if absf(xf.determinant()) < 1e-9:
		return
	_blend()
	if w == 0.0 or h == 0.0 or globalAlpha <= 0.0:
		return
	if fillStyle is Grad:
		_grad_rect(x, y, w, h, fillStyle)
		return
	var pts := PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
	_shadow_fill(pts)
	if clip_poly.size() >= 3:
		_poly_out(pts, fillStyle)
		return
	var c := _col(fillStyle)
	if c.a <= 0.002:
		return
	if xf.x.y == 0.0 and xf.y.x == 0.0:
		var p0 := xf * Vector2(x, y)
		var p1 := xf * Vector2(x + w, y + h)
		RenderingServer.canvas_item_add_rect(cur, Rect2(minf(p0.x, p1.x), minf(p0.y, p1.y), absf(p1.x - p0.x), absf(p1.y - p0.y)), c)
	else:
		RenderingServer.canvas_item_add_polygon(cur, pts, PackedColorArray([c]))

func _gc(g: Grad, t: float) -> Color:
	var c := g.at(t)
	c.a *= globalAlpha
	return c

func _grad_rect(x: float, y: float, w: float, h: float, g: Grad) -> void:
	if clip_poly.size() >= 3:
		for j in 4:
			for i in 4:
				_quad_grad(x + w * i / 4.0, y + h * j / 4.0, w / 4.0, h / 4.0, g)
		return
	if g.lin:
		var d := g.p1 - g.p0
		if absf(d.x) < 0.001 or absf(d.y) < 0.001:
			var vert := absf(d.x) < 0.001
			var a0 := y if vert else x
			var a1 := (y + h) if vert else (x + w)
			var dd := d.y if vert else d.x
			var o := g.p0.y if vert else g.p0.x
			if absf(dd) < 0.001:
				return
			# confini: bordi del rettangolo + posizioni delle fermate
			var cuts: Array = [a0, a1]
			for st in g.stops:
				var pos: float = o + float(st[0]) * dd
				if pos > minf(a0, a1) and pos < maxf(a0, a1):
					cuts.append(pos)
			cuts.sort()
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			for k in cuts.size():
				var v: float = cuts[k]
				var tt := (v - o) / dd
				var c := _gc(g, tt)
				if vert:
					pts.append(xf * Vector2(x, v)); pts.append(xf * Vector2(x + w, v))
				else:
					pts.append(xf * Vector2(v, y)); pts.append(xf * Vector2(v, y + h))
				cols.append(c); cols.append(c)
				if k > 0:
					var b := (k - 1) * 2
					idx.append_array([b, b + 1, b + 3, b, b + 3, b + 2])
			RenderingServer.canvas_item_add_triangle_array(cur, idx, pts, cols)
			return
		for j in 4:
			for i in 4:
				_quad_grad(x + w * i / 4.0, y + h * j / 4.0, w / 4.0, h / 4.0, g)
		return
	if g.p0.distance_to(g.p1) > 0.01:
		for j in 6:
			for i in 6:
				_quad_grad(x + w * i / 6.0, y + h * j / 6.0, w / 6.0, h / 6.0, g)
		return
	# radiale concentrico: anelli (interpolazione lineare esatta tra le fermate)
	var cen := g.p1
	var radii: Array = []
	var rcols: Array = []
	if g.r0 > 0.0:
		radii.append(0.0); rcols.append(_gc(g, 0.0))
	for st in g.stops:
		radii.append(g.r0 + float(st[0]) * (g.r1 - g.r0)); rcols.append(_gc(g, float(st[0])))
	var last: Color = rcols[-1]
	if last.a > 0.002:
		var far := 0.0
		for cp in [Vector2(x, y), Vector2(x + w, y), Vector2(x, y + h), Vector2(x + w, y + h)]:
			far = maxf(far, cp.distance_to(cen))
		if far > radii[-1]:
			radii.append(far); rcols.append(last)
	var seg := clampi(int(g.r1 * _sc() * .25) + 16, 16, 40)
	var pts2 := PackedVector2Array()
	var cols2 := PackedColorArray()
	var idx2 := PackedInt32Array()
	pts2.append(xf * cen); cols2.append(rcols[0])
	var start := 0
	if radii[0] <= 0.0:
		start = 1
	var prev_base := -1
	for ri in range(start, radii.size()):
		var r: float = radii[ri]
		var base := pts2.size()
		for k in seg:
			var a := TAU * k / seg
			pts2.append(xf * (cen + Vector2(cos(a), sin(a)) * r)); cols2.append(rcols[ri])
		for k in seg:
			var k2 := (k + 1) % seg
			if prev_base < 0:
				idx2.append_array([0, base + k, base + k2])
			else:
				idx2.append_array([prev_base + k, base + k, base + k2, prev_base + k, base + k2, prev_base + k2])
		prev_base = base
	RenderingServer.canvas_item_add_triangle_array(cur, idx2, pts2, cols2)

func _quad_grad(x: float, y: float, w: float, h: float, g: Grad) -> void:
	var lp := [Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for p in lp:
		pts.append(xf * p)
		var c := g.col_at(p)
		c.a *= globalAlpha
		cols.append(c)
	if clip_poly.size() >= 3:
		_poly_out(pts, g)
		return
	RenderingServer.canvas_item_add_polygon(cur, pts, cols)

func clearRect(_x: float, _y: float, _w: float, _h: float) -> void:
	pass

func strokeRect(x: float, y: float, w: float, h: float) -> void:
	var sp := paths
	var sc := closed
	beginPath()
	rect(x, y, w, h)
	stroke()
	paths = sp
	closed = sc

# ---------------- contorni ----------------
func _dashed(p: PackedVector2Array) -> Array:
	if dash.is_empty():
		return [p]
	var out: Array = []
	var sc := _sc()
	var di := 0
	var left: float = float(dash[0]) * sc
	var on := true
	var curp := PackedVector2Array([p[0]])
	for i in range(1, p.size()):
		var a: Vector2 = p[i - 1]
		var b: Vector2 = p[i]
		var seg := a.distance_to(b)
		var pos := 0.0
		while seg - pos > left:
			pos += left
			var q := a.lerp(b, pos / seg)
			if on:
				curp.append(q)
				out.append(curp)
			curp = PackedVector2Array([q])
			on = not on
			di = (di + 1) % dash.size()
			left = maxf(0.5, float(dash[di]) * sc)
		left -= seg - pos
		if on:
			curp.append(b)
		else:
			curp = PackedVector2Array([b])
	if on and curp.size() > 1:
		out.append(curp)
	return out

func _line_out(p: PackedVector2Array, col: Color, w: float) -> void:
	var lines: Array = [p]
	if clip_poly.size() >= 3:
		lines = Geometry2D.intersect_polyline_with_polygon(p, clip_poly)
	for l in lines:
		if l.size() < 2:
			continue
		RenderingServer.canvas_item_add_polyline(cur, l, PackedColorArray([col]), w, true)
		if lineCap == "round" and w > 2.5:
			RenderingServer.canvas_item_add_circle(cur, l[0], w / 2.0, col)
			RenderingServer.canvas_item_add_circle(cur, l[-1], w / 2.0, col)

func stroke() -> void:
	if absf(xf.determinant()) < 1e-9:
		return
	_blend()
	var w := maxf(0.6, lineWidth * _sc())
	var col: Color
	if strokeStyle is Grad:
		col = (strokeStyle as Grad).at(0.5)
		col.a *= globalAlpha
	else:
		col = _col(strokeStyle)
	for i in paths.size():
		var p: PackedVector2Array = paths[i]
		if p.size() < 2:
			continue
		if closed[i]:
			p = p.duplicate()
			p.append(p[0])
		var parts := _dashed(p)
		if shadowBlur > 0.0:
			var sc := css(shadowColor)
			sc.a *= globalAlpha * 0.3
			if sc.a > 0.01:
				for q in parts:
					_line_out(q, sc, w + shadowBlur * _sc() * 0.9)
		for q in parts:
			_line_out(q, col, w)

# ---------------- testo ----------------
func _font() -> Array:
	if _ff.has(font):
		return _ff[font]
	var sz := 12
	var re := RegEx.new()
	re.compile("([0-9.]+)px")
	var m := re.search(font)
	if m:
		sz = int(round(float(m.get_string(1))))
	var f: Font = D.font_title if font.find("Bungee") >= 0 else (D.font_bold if font.begins_with("700") else D.font_body)
	var r := [f, maxi(1, sz)]
	_ff[font] = r
	return r

func measureText(t: String) -> Dictionary:
	var fi := _font()
	return {"width": (fi[0] as Font).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fi[1]).x}

func _text(t: String, x: float, y: float, outline: bool) -> void:
	if absf(xf.determinant()) < 1e-9:
		return
	_blend()
	var fi := _font()
	var f: Font = fi[0]
	var sz: int = fi[1]
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var ox := 0.0
	if textAlign == "center": ox = -tw / 2.0
	elif textAlign == "right" or textAlign == "end": ox = -tw
	var oy := 0.0
	var asc := f.get_ascent(sz)
	var des := f.get_descent(sz)
	if textBaseline == "middle": oy = (asc - des) / 2.0
	elif textBaseline == "top": oy = asc
	elif textBaseline == "bottom": oy = -des
	if clip_poly.size() >= 3:
		var bb := Rect2(clip_poly[0], Vector2.ZERO)
		for cp in clip_poly:
			bb = bb.expand(cp)
		var cpos := xf * Vector2(x + ox + tw / 2.0, y + oy - asc * .35)
		if not bb.grow(2).has_point(cpos):
			return
	# testo disegnato con la trasformazione corrente
	RenderingServer.canvas_item_add_set_transform(cur, xf)
	if outline:
		var oc := _col(strokeStyle)
		f.draw_string_outline(cur, Vector2(x + ox, y + oy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, int(maxf(1.0, lineWidth)), oc)
	else:
		if shadowBlur > 0.0:
			var sc := css(shadowColor)
			sc.a *= globalAlpha * 0.5
			if sc.a > 0.01:
				f.draw_string_outline(cur, Vector2(x + ox, y + oy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, int(maxf(2.0, shadowBlur * 0.6)), sc)
		var fc: Color = (fillStyle as Grad).at(0.5) if fillStyle is Grad else css(fillStyle)
		if font.find("serif") >= 0 and font.find("sans") < 0:
			fc = Color(1, 1, 1, fc.a)
		fc.a *= globalAlpha
		f.draw_string(cur, Vector2(x + ox, y + oy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, fc)
	RenderingServer.canvas_item_add_set_transform(cur, Transform2D.IDENTITY)

func fillText(t, x: float, y: float) -> void:
	_text(str(t), x, y, false)

func strokeText(t, x: float, y: float) -> void:
	_text(str(t), x, y, true)

# ---------------- sfumature e immagini ----------------
func createLinearGradient(x0: float, y0: float, x1: float, y1: float) -> Grad:
	var g := Grad.new()
	g.lin = true
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	return g

func createRadialGradient(x0: float, y0: float, r0: float, x1: float, y1: float, r1: float) -> Grad:
	var g := Grad.new()
	g.lin = false
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	g.r0 = r0
	g.r1 = r1
	return g

## drawImage(tex, x, y, w, h) oppure con ritaglio sorgente (sx, sy, sw, sh in pixel).
func drawImage(tex: Texture2D, x: float, y: float, w := -1.0, h := -1.0, src := Rect2()) -> void:
	if absf(xf.determinant()) < 1e-9:
		return
	_blend()
	if tex == null:
		return
	if w < 0.0:
		w = tex.get_width()
		h = tex.get_height()
	var ts := Vector2(tex.get_width(), tex.get_height())
	var sr := src if src.size != Vector2.ZERO else Rect2(Vector2.ZERO, ts)
	var mod := Color(1, 1, 1, globalAlpha)
	if clip_poly.size() < 3:
		RenderingServer.canvas_item_add_set_transform(cur, xf)
		RenderingServer.canvas_item_add_texture_rect_region(cur, Rect2(x, y, w, h), tex.get_rid(), sr, mod)
		RenderingServer.canvas_item_add_set_transform(cur, Transform2D.IDENTITY)
		return
	var pts := PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)])
	var inv := xf.affine_inverse()
	for poly in Geometry2D.intersect_polygons(pts, clip_poly):
		if poly.size() < 3:
			continue
		var idx := Geometry2D.triangulate_polygon(poly)
		var tp := PackedVector2Array()
		var uv := PackedVector2Array()
		var tc := PackedColorArray()
		for k in idx:
			var lp: Vector2 = inv * poly[k]
			tp.append(poly[k])
			var u := (lp.x - x) / w
			var v := (lp.y - y) / h
			uv.append(Vector2((sr.position.x + u * sr.size.x) / ts.x, (sr.position.y + v * sr.size.y) / ts.y))
			tc.append(mod)
		RenderingServer.canvas_item_add_triangle_array(cur, PackedInt32Array(), tp, tc, uv, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())

## riempie il percorso corrente con una texture mappata sul rettangolo (x, y, w, h)
func fillTex(tex: Texture2D, x: float, y: float, w: float, h: float, src: Rect2) -> void:
	if absf(xf.determinant()) < 1e-9 or tex == null:
		return
	_blend()
	var ts := Vector2(tex.get_width(), tex.get_height())
	var mod := Color(1, 1, 1, globalAlpha)
	var inv := xf.affine_inverse()
	for poly in paths:
		if poly.size() < 3:
			continue
		var idx := Geometry2D.triangulate_polygon(poly)
		if idx.is_empty():
			continue
		var uv := PackedVector2Array()
		uv.resize(poly.size())
		for k in poly.size():
			var lp: Vector2 = inv * poly[k]
			uv[k] = Vector2((src.position.x + (lp.x - x) / w * src.size.x) / ts.x, (src.position.y + (lp.y - y) / h * src.size.y) / ts.y)
		var cols := PackedColorArray()
		cols.resize(poly.size())
		cols.fill(mod)
		RenderingServer.canvas_item_add_triangle_array(cur, idx, poly, cols, uv, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())

