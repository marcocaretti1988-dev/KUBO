class_name K
extends RefCounted
## Funzioni di disegno condivise (identiche alla versione HTML).

const INK := "#0a0505"

static func col(h) -> Color:
	return Ctx.css(h)

static func mix(a, b, t: float) -> Color:
	var A := Ctx.css(a)
	var B := Ctx.css(b)
	var c := A.lerp(B, t)
	c.a = 1.0
	# l'HTML arrotonda ogni canale a 0..255
	return Color8(int(round(c.r * 255)), int(round(c.g * 255)), int(round(c.b * 255)))

static func rgba(h, a: float) -> Color:
	var c := Ctx.css(h)
	c.a = a
	return c

## colore + alpha esadecimale come in "th[5]+'66'"
static func ha(h, hex: String) -> Color:
	var c := Ctx.css(h)
	c.a = float(hex.hex_to_int()) / 255.0
	return c

static func hsl(h: float, s: float, l: float, a := 1.0) -> Color:
	return Ctx.hsl(fposmod(h, 360.0) / 360.0, s / 100.0, l / 100.0, a)

static func circ(c: Ctx, x: float, y: float, r: float, f) -> void:
	c.fillStyle = f
	c.beginPath()
	c.arc(x, y, maxf(0.1, r), 0, 7)
	c.fill()

static func poly(c: Ctx, p: Array, f) -> void:
	c.fillStyle = f
	c.beginPath()
	c.moveTo(p[0], p[1])
	var k := 2
	while k < p.size():
		c.lineTo(p[k], p[k + 1])
		k += 2
	c.closePath()
	c.fill()

static func sst(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func heart(c: Ctx, x: float, y: float, s: float) -> void:
	c.beginPath()
	c.arc(x - s * .25, y, s * .27, PI, 0)
	c.arc(x + s * .25, y, s * .27, PI, 0)
	c.lineTo(x, y + s * .58)
	c.closePath()

static func starP(c: Ctx, x: float, y: float, r: float) -> void:
	c.beginPath()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		var rr := r * .45 if k % 2 else r
		c.lineTo(x + cos(a) * rr, y + sin(a) * rr)
	c.closePath()

static func sweat(c: Ctx, x: float, y: float, r: float) -> void:
	c.fillStyle = "#74c0fc"
	c.beginPath()
	c.moveTo(x, y - r * 1.6)
	c.quadraticCurveTo(x + r, y, x, y + r * .9)
	c.quadraticCurveTo(x - r, y, x, y - r * 1.6)
	c.fill()
	c.fillStyle = "#ffffffaa"
	c.fillRect(x - r * .3, y - r * .3, r * .3, r * .5)

static func cloud(c: Ctx, x: float, y: float, s: float, C: Dictionary) -> void:
	for a in [[-.5, 0, .35], [0, -.15, .45], [.5, 0, .35], [.2, .06, .3], [-.2, .06, .3]]:
		circ(c, x + a[0] * s, y + a[1] * s, a[2] * s, C.cloud)

static func wrap(c: Ctx, txt: String, mw: float) -> Array:
	var words := txt.split(" ")
	var lines: Array = []
	var l := ""
	for w in words:
		var tt := l + " " + w if l != "" else w
		if c.measureText(tt).width > mw and l != "":
			lines.append(l)
			l = w
		else:
			l = tt
	lines.append(l)
	return lines

# ---------------- cappelli ----------------
static func drawHat(c: Ctx, sk: Dictionary, S: float, t: float) -> void:
	var top := -S / 2
	var u := S / 24
	c.save()
	match str(sk.get("hat", "")):
		"cap":
			c.fillStyle = sk.hc; c.beginPath(); c.arc(0, top, S * .32, PI, 0); c.fill(); c.fillRect(0, top - u * 2, S * .56, u * 2.4)
			c.fillStyle = "#fff"; c.beginPath(); c.arc(0, top - S * .32, u * 1.5, 0, 7); c.fill()
		"beanie":
			c.fillStyle = sk.hc; c.beginPath(); c.arc(0, top + u, S * .4, PI, 0); c.fill()
			c.fillStyle = "#e03131"; c.fillRect(-S * .42, top - u, S * .84, u * 3)
			c.fillStyle = sk.hc; c.beginPath(); c.arc(0, top - S * .42, u * 3, 0, 7); c.fill()
		"horns":
			c.fillStyle = sk.hc
			for s in [-1, 1]:
				c.beginPath(); c.moveTo(s * S * .4, top + u); c.lineTo(s * S * .5, top - S * .34); c.lineTo(s * S * .18, top + u); c.fill()
		"tophat":
			c.fillStyle = sk.hc; c.fillRect(-S * .42, top - u * 2, S * .84, u * 2.5); c.fillRect(-S * .27, top - S * .55, S * .54, S * .55)
			c.fillStyle = "#e64980"; c.fillRect(-S * .27, top - u * 5, S * .54, u * 2.4)
		"crown":
			c.fillStyle = sk.hc; c.strokeStyle = "#e67700"; c.lineWidth = maxf(1, u)
			c.beginPath(); c.moveTo(-S * .36, top + u); c.lineTo(-S * .36, top - S * .28); c.lineTo(-S * .18, top - S * .12); c.lineTo(0, top - S * .36)
			c.lineTo(S * .18, top - S * .12); c.lineTo(S * .36, top - S * .28); c.lineTo(S * .36, top + u); c.closePath(); c.fill(); c.stroke()
			c.fillStyle = "#e03131"; c.beginPath(); c.arc(0, top - S * .1, u * 1.6, 0, 7); c.fill()
		"bow":
			var bx := S * .22
			var byy := top + u
			poly(c, [bx, byy, bx - S * .2, byy - S * .14, bx - S * .2, byy + S * .12], sk.hc)
			poly(c, [bx, byy, bx + S * .2, byy - S * .14, bx + S * .2, byy + S * .12], sk.hc)
			c.fillStyle = sk.hc; c.beginPath(); c.arc(bx, byy, u * 2, 0, 7); c.fill()
		"wizard":
			c.fillStyle = sk.hc; c.beginPath(); c.moveTo(-S * .34, top + u); c.lineTo(S * .04, top - S * .72); c.lineTo(S * .34, top + u); c.fill()
			c.fillStyle = "#ffd43b"; c.fillRect(-S * .4, top - u * .5, S * .8, u * 2); c.beginPath(); c.arc(S * .04, top - S * .3, u * 1.6, 0, 7); c.fill()
		"beard":
			c.fillStyle = sk.hc; c.beginPath(); c.moveTo(-S * .36, S * .16); c.quadraticCurveTo(-S * .3, S * .5, 0, S * .56); c.quadraticCurveTo(S * .3, S * .5, S * .36, S * .16)
			c.quadraticCurveTo(0, S * .32, -S * .36, S * .16); c.fill()
			c.beginPath(); c.ellipse(-S * .1, S * .2, S * .12, S * .045, .25, 0, 7); c.ellipse(S * .1, S * .2, S * .12, S * .045, -.25, 0, 7); c.fill()
			c.fillRect(-S * .36, -S * .32, S * .26, S * .06); c.fillRect(S * .1, -S * .32, S * .26, S * .06)
		"halo":
			c.strokeStyle = sk.hc; c.lineWidth = u * 1.8; c.shadowColor = sk.hc; c.shadowBlur = u * 4
			c.beginPath(); c.ellipse(0, top - S * .28 + sin(t * 3) * u, S * .3, S * .09, 0, 0, 7); c.stroke()
	c.restore()

# ---------------- facce ----------------
static func _brow(c: Ctx, x: float, y: float, rot: float, w: float, h: float) -> void:
	c.save(); c.translate(x, y); c.rotate(rot); c.fillRect(-w / 2, -h / 2, w, h); c.restore()

static func face(c: Ctx, mood: String, s: float, ex: float, ey: float, ink, t: float, lx: float, ly: float) -> bool:
	match mood:
		"jump":
			for k in [-1, 1]:
				c.fillStyle = "#fff"; c.fillRect(k * ex - s * .11, ey - s * .12, s * .22, s * .24)
				c.fillStyle = ink; c.fillRect(k * ex - s * .045 + lx * s * .04, ey - s * .11, s * .09, s * .1)
			for k in [-1, 1]:
				_brow(c, k * ex, ey - s * .24, k * .15, s * .24, s * .06)
			c.beginPath(); c.arc(0, s * .12, s * .12, 0, PI); c.fill()
			c.fillStyle = "#ff6b6b"; c.beginPath(); c.arc(0, s * .2, s * .05, PI, 0); c.fill()
		"fall":
			for k in [-1, 1]:
				circ(c, k * ex, ey, s * .13, "#fff"); circ(c, k * ex + lx * s * .03, ey - s * .02, s * .05, ink)
				c.fillStyle = ink; _brow(c, k * ex, ey - s * .24, k * .35, s * .24, s * .06)
			c.fillStyle = ink; c.beginPath(); c.ellipse(0, s * .24, s * .07, s * .1, 0, 0, 7); c.fill()
			sweat(c, s * .4, -s * .32 + sin(t * 12) * s * .03, s * .07)
		"scream":
			var j := sin(t * 40) * s * .01
			for k in [-1, 1]:
				circ(c, k * ex + j, ey - s * .02, s * .14, "#fff"); circ(c, k * ex + j, ey - s * .02, s * .03, ink)
				c.fillStyle = ink; _brow(c, k * ex, ey - s * .3, k * .5, s * .24, s * .06)
			c.fillStyle = ink; c.beginPath(); c.ellipse(0, s * .25, s * .14, s * .13 + absf(sin(t * 20)) * s * .02, 0, 0, 7); c.fill()
			c.fillStyle = "#ff6b6b"; c.beginPath(); c.ellipse(0, s * .32, s * .08, s * .04, 0, 0, 7); c.fill()
			sweat(c, s * .44, -s * .3, s * .07); sweat(c, -s * .46, -s * .2, s * .06)
		"run":
			for k in [-1, 1]:
				c.fillStyle = "#fff"; c.fillRect(k * ex - s * .11, ey - s * .1, s * .22, s * .2)
				c.fillStyle = ink; c.fillRect(k * ex - s * .045 + lx * s * .05, ey - s * .06, s * .09, s * .11)
				_brow(c, k * ex, ey - s * .2, -k * .2, s * .26, s * .06)
			c.strokeStyle = ink; c.lineWidth = s * .06; c.lineCap = "round"; c.beginPath(); c.arc(lx * s * .04, s * .1, s * .12, .2 * PI, .8 * PI); c.stroke()
		"squash":
			c.strokeStyle = ink; c.lineWidth = s * .07; c.lineCap = "round"
			for k in [-1, 1]:
				c.beginPath(); c.moveTo(k * ex - k * s * .09, ey - s * .08); c.lineTo(k * ex + k * s * .06, ey); c.lineTo(k * ex - k * s * .09, ey + s * .08); c.stroke()
			c.lineWidth = s * .05; c.beginPath(); c.moveTo(-s * .14, s * .2)
			for jj in range(1, 5):
				c.lineTo(-s * .14 + jj * s * .07, s * .2 + (-s * .04 if jj % 2 else 0.0))
			c.stroke()
		"wall":
			for k in [-1, 1]:
				c.fillStyle = "#fff"; c.fillRect(k * ex - s * .11, ey - s * .03, s * .22, s * .07)
				c.fillStyle = ink; c.fillRect(k * ex - s * .04 + lx * s * .04, ey - s * .03, s * .08, s * .07)
				_brow(c, k * ex, ey - s * .14, -k * .4, s * .28, s * .07)
			c.fillStyle = "#fff"; c.fillRect(-s * .17, s * .13, s * .34, s * .11)
			c.strokeStyle = ink; c.lineWidth = s * .035; c.strokeRect(-s * .17, s * .13, s * .34, s * .11)
			for jj in range(-1, 2):
				c.beginPath(); c.moveTo(jj * s * .08, s * .13); c.lineTo(jj * s * .08, s * .24); c.stroke()
			c.beginPath(); c.moveTo(-s * .17, s * .185); c.lineTo(s * .17, s * .185); c.stroke()
		"swing":
			for k in [-1, 1]:
				circ(c, k * ex, ey, s * .12, "#fff"); circ(c, k * ex + lx * s * .04, ey + ly * s * .04, s * .055, ink)
			c.fillStyle = ink; c.beginPath(); c.arc(0, s * .1, s * .17, 0, PI); c.fill()
			c.fillStyle = "#fff"; c.fillRect(-s * .13, s * .1, s * .26, s * .05)
			c.fillStyle = "#ff6b6b"; c.beginPath(); c.arc(0, s * .24, s * .07, PI, 0); c.fill()
		"star":
			for k in [-1, 1]:
				c.save(); c.translate(k * ex, ey); c.rotate(t * 3 * k); c.fillStyle = "#ffd43b"; starP(c, 0, 0, s * .15); c.fill()
				c.strokeStyle = "#e67700"; c.lineWidth = s * .025; c.stroke(); c.restore()
			c.fillStyle = ink; c.beginPath(); c.arc(0, s * .1, s * .17, 0, PI); c.fill()
			c.fillStyle = "#fff"; c.fillRect(-s * .13, s * .1, s * .26, s * .05)
		"wink":
			c.fillStyle = "#fff"; c.fillRect(-ex - s * .11, ey - s * .11, s * .22, s * .22)
			c.fillStyle = ink; c.fillRect(-ex - s * .04, ey - s * .05, s * .09, s * .1)
			c.strokeStyle = ink; c.lineWidth = s * .07; c.lineCap = "round"; c.beginPath(); c.arc(ex, ey + s * .04, s * .09, PI * 1.1, PI * 1.9); c.stroke()
			c.lineWidth = s * .05; c.beginPath(); c.arc(0, s * .08, s * .13, .15 * PI, .85 * PI); c.stroke()
			c.fillStyle = "#ff6b6b"; c.beginPath(); c.ellipse(s * .05, s * .23, s * .06, s * .07, 0, 0, PI); c.fill()
		"smug":
			for k in [-1, 1]:
				c.fillStyle = "#fff"; c.fillRect(k * ex - s * .11, ey - s * .02, s * .22, s * .1)
				c.fillStyle = ink; c.fillRect(k * ex - s * .11, ey - s * .04, s * .22, s * .04); c.fillRect(k * ex - s * .02 + lx * s * .04, ey, s * .08, s * .08)
			c.strokeStyle = ink; c.lineWidth = s * .055; c.lineCap = "round"; c.beginPath(); c.moveTo(-s * .12, s * .2); c.quadraticCurveTo(s * .04, s * .24, s * .16, s * .13); c.stroke()
		"yum":
			c.strokeStyle = ink; c.lineWidth = s * .07; c.lineCap = "round"
			for k in [-1, 1]:
				c.beginPath(); c.arc(k * ex, ey + s * .05, s * .09, PI * 1.1, PI * 1.9); c.stroke()
			c.lineWidth = s * .05; c.beginPath(); c.arc(0, s * .08, s * .13, .15 * PI, .85 * PI); c.stroke()
			c.fillStyle = "#ff6b6b"; c.beginPath(); c.ellipse(s * .12, s * .17, s * .06, s * .05, .6, 0, 7); c.fill()
		"bored":
			var lk := sin(t * .9)
			for k in [-1, 1]:
				c.fillStyle = "#fff"; c.fillRect(k * ex - s * .11, ey - s * .02, s * .22, s * .12)
				c.fillStyle = ink; c.fillRect(k * ex - s * .04 + lk * s * .05, ey + s * .01, s * .08, s * .08); c.fillRect(k * ex - s * .11, ey - s * .04, s * .22, s * .035)
			c.fillRect(-s * .1, s * .2, s * .2, s * .045)
		_:
			return false
	return true

static func shades(c: Ctx, s: float, t: float) -> void:
	c.fillStyle = "#111"
	for k in [-1, 1]:
		c.beginPath(); c.roundRect(k * s * .22 - s * .15, -s * .17, s * .3, s * .17, s * .05); c.fill()
	c.fillRect(-s * .08, -s * .13, s * .16, s * .04)
	c.fillStyle = "rgba(255,255,255,.55)"
	var sh := fmod(t * .6, 1.0)
	for k in [-1, 1]:
		c.fillRect(k * s * .22 - s * .12 + sh * s * .2, -s * .15, s * .03, s * .12)

static func drawCube(c: Ctx, x: float, y: float, s: float, mood: String, t: float, rot := 0.0, sk = null, lx := 0.0, ly := 0.0, cool := false) -> void:
	if sk == null:
		sk = D.cur_skin(t)
	c.save(); c.translate(x, y); c.rotate(rot)
	c.fillStyle = "#00000044"; c.fillRect(-s / 2 + s * .1, -s / 2 + s * .14, s, s)
	c.fillStyle = sk.b; c.fillRect(-s / 2, -s / 2, s, s)
	c.fillStyle = sk.t; c.fillRect(-s / 2, -s / 2, s, s * .16)
	c.fillStyle = sk.d; c.fillRect(-s / 2, s / 2 - s * .13, s, s * .13)
	c.strokeStyle = "#0a0505"; c.lineWidth = maxf(1.2, s * .05); c.strokeRect(-s / 2, -s / 2, s, s)
	var ink := "#0a0505"
	var ex := s * .22
	var ey := -s * .08
	var blink := sin(t * 1.3) > .985
	c.fillStyle = ink
	if mood == "hurt":
		c.strokeStyle = ink; c.lineWidth = s * .07
		for k in [-1, 1]:
			c.beginPath(); c.moveTo(k * ex - s * .09, ey - s * .09); c.lineTo(k * ex + s * .09, ey + s * .09)
			c.moveTo(k * ex + s * .09, ey - s * .09); c.lineTo(k * ex - s * .09, ey + s * .09); c.stroke()
		c.beginPath(); c.ellipse(0, s * .22, s * .08, s * .1, 0, 0, 7); c.fill()
	elif mood == "love":
		c.fillStyle = "#ffd43b"
		for k in [-1, 1]:
			heart(c, k * ex, ey - s * .03, s * .3); c.fill()
		c.fillStyle = ink; c.beginPath(); c.arc(0, s * .13, s * .13, 0, PI); c.fill()
	elif face(c, mood, s, ex, ey, ink, t, lx, ly):
		pass
	elif mood == "happy":
		c.strokeStyle = ink; c.lineWidth = s * .08; c.lineCap = "round"
		for k in [-1, 1]:
			c.beginPath(); c.arc(k * ex, ey + s * .05, s * .09, PI * 1.1, PI * 1.9); c.stroke()
		c.beginPath(); c.arc(0, s * .12, s * .15, 0, PI); c.fill()
	else:
		for k in [-1, 1]:
			var eh := s * .04 if (mood == "sleep" or (blink and mood == "n")) else (s * .12 if mood == "angry" else s * .22)
			c.fillStyle = "#fff"; c.fillRect(k * ex - s * .11, ey - eh / 2, s * .22, eh)
			c.fillStyle = ink
			var ph := minf(eh, s * .1)
			c.fillRect(k * ex - s * .04 + lx * s * .05, ey - ph / 2 + ly * s * .05, s * .09, ph)
		var by := ey - s * .2
		if mood == "angry":
			for k in [-1, 1]:
				_brow(c, k * ex, by + s * .04, -k * .4, s * .28, s * .07)
			c.lineWidth = s * .05; c.strokeStyle = ink; c.beginPath(); c.moveTo(-s * .12, s * .22)
			for jj in range(1, 5):
				c.lineTo(-s * .12 + jj * s * .06, s * .22 + (-s * .05 if jj % 2 else 0.0))
			c.stroke()
		else:
			c.fillRect(-ex - s * .13, by, s * .26, s * .06); c.fillRect(ex - s * .13, by, s * .26, s * .06)
			if mood == "wow":
				c.beginPath(); c.ellipse(0, s * .22, s * .08, s * .11, 0, 0, 7); c.fill()
			else:
				c.fillRect(-s * .12, s * .18, s * .24, s * .06)
	if cool:
		shades(c, s, t)
	drawHat(c, sk, s, t)
	c.restore()

# ---------------- Re Ombra e compagnia ----------------
static func drawOmbra(c: Ctx, x: float, y: float, s: float, t: float, mood: String, small := false) -> void:
	c.save(); c.translate(x, y)
	var g := c.createRadialGradient(0, 0, s * .3, 0, 0, s * 1.1); g.addColorStop(0, "rgba(130,50,210,.45)"); g.addColorStop(1, "rgba(130,50,210,0)")
	c.fillStyle = g; c.fillRect(-s * 1.1, -s * 1.1, s * 2.2, s * 2.2)
	for k in 5:
		var a := t * 1.5 + k * 1.26
		circ(c, cos(a) * s * .66, sin(a) * s * .66 + s * .1, s * .09, "rgba(30,16,48,.7)")
	c.fillStyle = "#ffffff" if mood == "flash" else "#17121f"; c.strokeStyle = "#000"; c.lineWidth = maxf(1.5, s * .05)
	c.beginPath(); c.roundRect(-s / 2, -s / 2, s, s, s * .08); c.fill(); c.stroke()
	c.fillStyle = "#2a2038"; c.fillRect(-s / 2 + 2, -s / 2 + 2, s - 4, s * .13)
	c.shadowColor = "#ff2b4a"; c.shadowBlur = s * .25; c.fillStyle = "#ff2b4a"
	for k in [-1, 1]:
		c.beginPath(); c.moveTo(k * s * .32, -s * .1); c.lineTo(k * s * .08, -s * .02); c.lineTo(k * s * .3, s * .05); c.closePath(); c.fill()
	c.shadowBlur = 0
	c.fillStyle = "#000"
	for k in [-1, 1]:
		_brow(c, k * s * .2, -s * .2, k * .45, s * .32, s * .07)
	c.strokeStyle = "#ff2b4a"; c.lineWidth = maxf(1, s * .04); c.beginPath()
	if mood == "hurt":
		c.arc(0, s * .32, s * .13, PI, 0)
	else:
		c.moveTo(-s * .2, s * .18)
		for k in range(1, 7):
			c.lineTo(-s * .2 + k * s * .0667, s * .18 + (s * .06 if k % 2 else 0.0))
	c.stroke()
	if not small:
		poly(c, [-s * .4, -s * .5, -s * .44, -s * .88, -s * .22, -s * .68, 0, -s * .98, s * .22, -s * .68, s * .44, -s * .88, s * .4, -s * .5], "#3b1f5c")
		circ(c, 0, -s * .68, s * .07, "#ff2b4a"); circ(c, -s * .44, -s * .88, s * .04, "#ff2b4a"); circ(c, s * .44, -s * .88, s * .04, "#ff2b4a")
	c.restore()

static func drawMinion(c: Ctx, x: float, y: float, t: float, k: int) -> void:
	c.save(); c.translate(x, y); c.strokeStyle = "#cfc6e0"; c.lineWidth = 1.2; c.beginPath(); c.moveTo(0, 8); c.lineTo(0, 26); c.stroke()
	drawCube(c, 0, 32 + sin(t * 6) * 2, 15, "hurt", t, sin(t * 3) * .2, D.friend_skin(k)); c.restore()
	for s in [-1, 1]:
		c.fillStyle = "#2a2038"; c.beginPath(); c.ellipse(x + s * 15, y - 4 + sin(t * 20) * 3, 9, 4, s * .4, 0, 7); c.fill()
	drawOmbra(c, x, y, 22, t, "n", true)

static func drawKey(c: Ctx, x: float, y: float, t: float) -> void:
	c.save(); c.translate(x, y + sin(t * 3) * 3); c.rotate(sin(t * 2) * .2); c.shadowColor = "#ffd43b"; c.shadowBlur = 14
	c.strokeStyle = "#ffd43b"; c.lineWidth = 3; c.beginPath(); c.arc(-6, 0, 5, 0, 7); c.stroke()
	c.fillStyle = "#ffd43b"; c.fillRect(-1, -1.5, 13, 3); c.fillRect(7, 1, 2.5, 4); c.fillRect(11, 1, 2.5, 3); c.shadowBlur = 0; c.restore()

static func drawCage(c: Ctx, x: float, y: float, t: float, k: int, mat: String) -> void:
	drawCube(c, x, y - 14 + sin(t * 4) * 1, 20, "wow" if sin(t * 1.3) > .7 else "hurt", t, 0, D.friend_skin(k))
	var ice := mat == "ice"
	var cl := "#a5d8ffcc" if ice else "#adb5bd"
	c.fillStyle = "#495057"; c.fillRect(x - 17, y - 2, 34, 4); c.fillRect(x - 17, y - 34, 34, 4)
	if ice:
		c.fillStyle = "rgba(165,216,255,.35)"; c.fillRect(x - 17, y - 34, 34, 34)
	c.strokeStyle = cl; c.lineWidth = 2.2
	var k2 := -14
	while k2 <= 14:
		c.beginPath(); c.moveTo(x + k2, y - 32); c.lineTo(x + k2, y); c.stroke()
		k2 += 7
	circ(c, x, y - 38, 4, "#868e96"); c.fillStyle = "#fcc419"; c.fillRect(x - 4, y - 20, 8, 7)
	c.strokeStyle = "#fcc419"; c.lineWidth = 1.5; c.beginPath(); c.arc(x, y - 20, 3, PI, 0); c.stroke()
	if sin(t * 3) > 0:
		c.font = "10px Bungee"; c.fillStyle = "#fff"; c.textAlign = "center"; c.fillText("AIUTO!", x, y - 48)

static func drawEater(c: Ctx, x: float, y: float, dir: float, open: float, t: float, full: bool) -> void:
	c.save(); c.translate(x, y); c.scale(dir, 1)
	var INK2 := "#12060e"
	c.fillStyle = "#1d0f2a"; c.beginPath(); c.ellipse(-70, 0, 78, 52, 0, 0, 7); c.fill()
	for k in 6:
		var a := t * 2 + k
		circ(c, -90 + cos(a) * 50, sin(a * 1.3) * 38, 10, "rgba(40,16,60,.7)")
	var ja := .15 + open * .55
	if open > .05:
		c.fillStyle = "#7a0f2a"; c.beginPath(); c.ellipse(-6, 0, 30, 26 * open, 0, 0, 7); c.fill()
		c.fillStyle = "#d6336c"; c.beginPath(); c.ellipse(-12, 8 * open, 18, 7 * open, 0, 0, 7); c.fill()
	for sgn in [1, -1]:
		c.save(); c.rotate(sgn * ja)
		var g := c.createLinearGradient(0, -sgn * 30, 0, 0); g.addColorStop(0, "#3b1f5c"); g.addColorStop(1, "#1d0f2a")
		c.fillStyle = g; c.beginPath(); c.moveTo(-40, 0); c.quadraticCurveTo(-20, -sgn * 42, 30, -sgn * 8); c.lineTo(36, 0); c.closePath(); c.fill()
		c.strokeStyle = INK2; c.lineWidth = 2; c.stroke()
		c.fillStyle = "#f8f9fa"
		for k in 6:
			var tx := -30 + k * 11
			c.beginPath(); c.moveTo(tx, -sgn * 1); c.lineTo(tx + 5, sgn * 10); c.lineTo(tx + 10, -sgn * 1); c.fill()
		c.restore()
	c.save(); c.shadowColor = "#ff2b4a"; c.shadowBlur = 14
	for ey in [-30, -22]:
		c.fillStyle = "#ff2b4a"; c.beginPath(); c.ellipse(-28 + (ey + 30) * 1.6, ey - 16 * ja, 6, 4, -.3, 0, 7); c.fill()
	c.restore()
	if open > .3:
		c.fillStyle = "rgba(200,230,255,.7)"; c.beginPath(); c.ellipse(18, 14 + sin(t * 6) * 3, 2, 5, 0, 0, 7); c.fill()
	if full:
		c.fillStyle = "#1d0f2a"; c.beginPath(); c.ellipse(-40, 6, 26, 22 + sin(t * 12) * 3, 0, 0, 7); c.fill()
		c.strokeStyle = "rgba(255,90,31,.5)"; c.lineWidth = 2; c.strokeRect(-48, -2, 14, 14)
	c.restore()
