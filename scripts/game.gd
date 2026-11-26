class_name Game
extends Node2D
## Gioco: generazione dei livelli, fisica, rampino, nemici, boss e disegno.
## Port fedele di build()/update()/render() della versione HTML.

const W := 360.0
const WALL := 20.0
const PPM := 10.0
const GRAV := 1500.0
const JUMP := 610.0
const SPEED := 160.0
const RANGE := 270.0
const N := 22
const TH := 760.0
const WT := 240.0
const PWI := {"wings": "⏫", "shield": "🛡️", "rocket": "🚀", "magnet": "🧲"}
const PWN := {"wings": "DOPPIO SALTO!", "shield": "SCUDO!", "rocket": "RAZZO!", "magnet": "MAGNETE!"}
const CHASE := [4, 9, 14, 19]
const FALLC := {"lava": ["#ff6b1a", "#ffd43b"], "water": ["#4dabf7", "#e7f5ff"], "choco": ["#5c2e12", "#a0522d"]}
const VINEC := {3: "#40c057", 7: "#2f9e44", 11: "#fd7e14", 14: "#5c940d"}

var main: Node
var c: Ctx
var G = null
var VH = 640.0
var art_cache = {}

func _ready() -> void:
	c = Ctx.new(get_canvas_item())
	c.quality = .8

# =====================================================================
#                          GENERAZIONE LIVELLO
# =====================================================================
func _plat(d: Dictionary) -> Dictionary:
	var p = {"x": 0.0, "w": 0.0, "y": 0.0, "vx": 0.0, "k": "n", "ph": 0.0, "st": 0.0, "gone": 0.0, "boing": 0.0, "min": 0.0, "max": 0.0, "floor": false, "top": false, "sd": .5}
	p.merge(d, true)
	return p

func _en(d: Dictionary) -> Dictionary:
	var e = {"t": "", "p": null, "x": 0.0, "y": 0.0, "dir": 1.0, "sp": 0.0, "w": 0.0, "h": 0.0, "alive": true, "dead": 0.0, "dvy": 0.0, "rot": 0.0, "al": 0, "alt": 0.0,
		"hy": 0.0, "vy": 0.0, "st": 0, "sh": 0.0, "by": 0.0, "ph": 0.0, "sw": 0.0}
	e.merge(d, true)
	return e

func build(i: int) -> Dictionary:
	var r = Rng.new(i * 977 + 13)
	var goal = float(D.goal_of(i)) * PPM
	var th: Array = D.THEMES[i]
	var dif = i / float(N - 1)
	var P: Array = [_plat({"x": WALL, "w": W - 2 * WALL, "y": 0.0, "floor": true})]
	var E: Array = []
	var A: Array = []
	var CP: Array = []
	var GM: Array = []
	var U: Array = []
	var SP: Array = []
	var y = 90.0
	var cx = W / 2
	var nextRing = 200.0
	var side = 1.0
	var nextPU = 360 + r.next() * 200
	var lastY = 0.0
	var gx = func(x: float) -> float: return maxf(WALL + 10, minf(W - WALL - 10, x))
	while y < goal - 80:
		var k = "n"
		if y >= 200:
			var q = r.next()
			if q < .07: k = "tramp"
			elif i >= 1 and q < .12 + dif * .12: k = "crumble"
		var w = 46.0 if k == "tramp" else maxf(56, 82 + r.next() * 60 - i * 1.5)
		cx = maxf(WALL + w / 2 + 4, minf(W - WALL - w / 2 - 4, cx + (r.next() * 2 - 1) * 150))
		var p = _plat({"x": cx - w / 2, "w": w, "y": y, "k": k, "ph": r.next() * 3})
		if k == "n" and i >= 3 and r.next() < .06 + dif * .25:
			p.vx = (-1.0 if r.next() < .5 else 1.0) * (35 + dif * 45); p.min = WALL + 4; p.max = W - WALL - 4
		P.append(p); lastY = y
		var plain: bool = k == "n" and not p.vx
		if plain and y > 300 and r.next() < .1 + dif * .28:
			var dr = -1.0 if r.next() < .5 else 1.0
			E.append(_en({"t": "crawl", "p": p, "x": p.x + p.w / 2, "dir": dr, "sp": 35 + dif * 50, "w": 22.0, "h": 16.0, "y": p.y}))
		if i >= 1 and r.next() < .04 + dif * .18:
			E.append(_en({"t": "drop", "x": p.x + 8 + r.next() * (p.w - 16), "y": p.y - 10, "hy": p.y - 10, "w": 12.0, "h": 20.0}))
		if plain and r.next() < .3:
			for g in range(-1, 2):
				GM.append({"x": gx.call(p.x + p.w / 2 + g * 16), "y": p.y + 22, "got": false})
		if r.next() < .25:
			var w2 = 50 + r.next() * 40
			var ox = (W - WALL - w2 - 10 - r.next() * 40) if cx < W / 2 else (WALL + 10 + r.next() * 40)
			var y2 = y + 20 + r.next() * 20
			if absf(ox + w2 / 2 - cx) > w / 2 + w2 / 2 + 10:
				var kk = "cloud" if (i >= 2 and r.next() < .55) else "n"
				P.append(_plat({"x": ox, "w": w2, "y": y2, "k": kk, "ph": r.next() * 3}))
		if i >= 3 and y > 450 and r.next() < .04 + dif * .12:
			E.append(_en({"t": "bat", "x": W / 2, "y": y + 45, "by": y + 45, "ph": r.next() * 6, "sp": 1 + dif * 1.5, "w": 22.0, "h": 14.0}))
		if y > 150 and r.next() < .12:
			SP.append({"side": -1.0 if r.next() < .5 else 1.0, "y": y + 30, "boing": 0.0})
		var gap = minf(98, 64 + r.next() * 24 + mini(i, 12) * 1.1)
		if y + gap / 2 > nextRing:
			side *= -1
			var ax = W / 2 + side * (45 + r.next() * 75)
			var ay = y + gap / 2 + 10
			A.append({"x": ax, "y": ay, "pulse": 0.0})
			for g in range(-2, 3):
				var an = g * .33
				GM.append({"x": gx.call(ax + sin(an) * 125), "y": ay - cos(an) * 125, "got": false})
			nextRing = ay + 140 + r.next() * 70
		if y > nextPU:
			var ut: String = ["wings", "shield", "rocket", "magnet"][int(floor(r.next() * 4))]
			if ut == "rocket" and y > goal * .42: ut = "wings"
			U.append({"x": WALL + 40 + r.next() * (W - 2 * WALL - 80), "y": y + gap / 2, "t": ut, "ph": r.next() * 6, "got": false})
			nextPU = y + 420 + r.next() * 260
		y += gap
	while goal - lastY > 88:
		lastY += minf(80, (goal - lastY) / 2 + 10)
		var w = 92.0
		cx = maxf(WALL + w / 2 + 4, minf(W - WALL - w / 2 - 4, cx + (r.next() * 2 - 1) * 110))
		P.append(_plat({"x": cx - w / 2, "w": w, "y": lastY}))
	A.append({"x": W / 2 - side * (70 + r.next() * 40), "y": goal - 35, "pulse": 0.0})
	if i == N - 1:
		P.append(_plat({"x": W / 2 - 150, "w": 300.0, "y": goal, "top": true}))
	else:
		P.append(_plat({"x": W / 2 - 100, "w": 200.0, "y": goal, "top": true}))
	for q in P:
		q.sd = r.next()
	var cand = P.filter(func(q): return not q.floor and not q.top and q.k == "n" and not q.vx and q.y > goal * .35 and q.y < goal * .85 and (q.x < WALL + 60 or q.x + q.w > W - WALL - 60))
	var spp: Dictionary = cand[int(floor(r.next() * cand.size()))] if cand.size() else P[int(floor(P.size() / 2.0))]
	var secret = {"x": maxf(WALL + 14, spp.x + 8) if spp.x < W / 2 else minf(W - WALL - 14, spp.x + spp.w - 8), "y": spp.y + 78, "got": false}
	var plainP = P.filter(func(q): return not q.floor and not q.top and q.k == "n" and not q.vx)
	var pickAt = func(lo: float, hi: float) -> Dictionary:
		var cs = plainP.filter(func(q): return q.y > goal * lo and q.y < goal * hi)
		return cs[int(floor(r.next() * cs.size()))] if cs.size() else plainP[int(floor(r.next() * plainP.size()))]
	var key = null
	var cage = null
	var minion = null
	var boss = null
	if i in CHASE:
		minion = {"x": W / 2, "y": goal * .22, "st": 0, "ph": 0.0, "caught": false}
	else:
		var kp: Dictionary = pickAt.call(.48, .66)
		key = {"x": kp.x + kp.w / 2, "y": kp.y + 26, "got": false}
		var cp: Dictionary = pickAt.call(.8, .94)
		cage = {"x": cp.x + cp.w / 2, "y": cp.y, "open": false}
		for e in E:
			if e.p == cp:
				e.alive = false
	if i == N - 1:
		boss = {"x": W / 2, "y": goal + 200, "hp": 3, "st": "idle", "t": 0.0, "t2": 0.0, "cd": 1.5, "shots": 0, "inv": 0.0, "on": false, "dead": false, "dir": 1.0}
	var kids: Array = []
	var fk = [.22, .5, .76]
	for k in 3:
		var q: Dictionary = pickAt.call(fk[k] - .08, fk[k] + .08)
		var kx = maxf(WALL + 10, q.x + 10) if q.x < W / 2 else minf(W - WALL - 10, q.x + q.w - 10)
		var col = K.hsl(floor(r.next() * 360), 75, 60)
		kids.append({"x": kx, "y": q.y + 14, "got": bool(S.d.kids[i] & (1 << k)), "bit": 1 << k, "col": col})
	for f in [1.0 / 3, 2.0 / 3]:
		for p in P:
			if not p.floor and not p.vx and p.k == "n" and p.y > goal * f and not E.any(func(e): return e.p == p):
				CP.append({"x": p.x + p.w / 2, "y": p.y, "p": p, "on": false})
				break
	for k in 60:
		r.next(); r.next(); r.next(); r.next()   # decorazioni (non usate) ma consumano il seme
	var beams: Array = []
	for k in 5:
		beams.append({"x": r.next() * W, "w": 30 + r.next() * 60, "a": .03 + r.next() * .04})
	var sty: Dictionary = D.STY[i]
	var Gd = {"i": i, "th": th, "goal": goal, "P": P, "E": E, "A": A, "CP": CP, "GM": GM, "U": U, "SP": SP, "beams": beams, "portal": {"x": W / 2, "y": goal + 60}, "parts": [], "fx": [], "trail": [],
		"pl": {"x": W / 2, "y": 0.0, "vx": 0.0, "vy": 0.0, "py": 0.0, "gr": null, "hook": null, "inv": 0.0, "coy": 0.0, "buf": 0.0, "wall": 0, "rot": 0.0, "face": 1.0, "dj": true, "perfect": false, "mood": "n", "moodT": 0.0,
			"land": 0.0, "idle": 0.0, "rocketY0": 0.0, "pw": {"wings": 0.0, "shield": false, "rocket": 0.0, "magnet": 0.0}},
		"hearts": 3, "cam": 0.0, "maxY": 0.0, "cpY": 0.0, "cpX": W / 2, "t": 0.0, "toast": 0.0, "toastTxt": "", "toastCol": "#ff5a7a", "done": false,
		"scen": [], "lights": [], "secret": secret, "key": key, "cage": cage, "minion": minion, "boss": boss, "kids": kids, "orbs": [], "follow": [], "hist": [], "freed": false, "perk": null,
		"amb": [], "flash": 0.0, "st": sty, "ch": D.ch_of(i), "c2": false, "c3": false, "objTxt": "", "lava": -260.0, "lspeed": 18 + i * 1.3, "lavaStart": 3.0 if i else 4.5, "lavaPause": 0.0,
		"combo": 0, "bestCombo": 0, "comboPop": 0.0, "runGems": 0, "shake": 0.0, "slow": 0.0, "lastRing": null, "lastRingT": -9.0, "tg": null, "stompChain": 0, "warp": null, "eat": null, "keyWarn": false,
		"lockMsg": -9.0, "lockMsg2": -9.0, "px": 0.0, "pxT": null, "lt": null, "lc": null, "shoot": null, "boltX": 0.0, "art": null, "hintA": 0.0, "toastA": 0.0, "msgs": []}
	Gd.scen = build_scenery(i, goal, r)
	Gd.amb = init_amb(sty.amb)
	return Gd

func build_scenery(i: int, goal: float, r: Rng) -> Array:
	var out: Array = []
	var F: Array = D.J.SFEAT.get(str(i), [])
	var top = goal + 300
	for f in F:
		if f == "lava" or f == "water" or f == "choco":
			var side = -1.0 if r.next() < .5 else 1.0
			var y = 260.0
			while y < top:
				side *= -1
				out.append({"t": "fall", "k": f, "side": side, "y": y, "L": 110 + r.next() * 160, "ph": r.next() * 9, "bg": false})
				y += 320 + r.next() * 160
		if f == "vine":
			var y = 140.0
			while y < top:
				var sd = -1.0 if r.next() < .5 else 1.0
				out.append({"t": "vine", "side": sd, "y": y, "L": 50 + r.next() * 80, "ph": r.next() * 9, "bg": false})
				y += 170 + r.next() * 90
		if f == "torch":
			var side = 1.0
			var y = 180.0
			while y < top:
				side *= -1
				out.append({"t": "torch", "side": side, "y": y, "ph": r.next() * 9, "bg": false})
				y += 240 + r.next() * 80
		if f == "gcry" or f == "mush" or f == "lantern":
			var y: float = {"gcry": 160.0, "mush": 170.0, "lantern": 200.0}[f]
			while y < top:
				var sd = -1.0 if r.next() < .5 else 1.0
				out.append({"t": f, "side": sd, "y": y, "ph": r.next() * 9, "bg": false})
				y += {"gcry": 200 + r.next() * 80, "mush": 210 + r.next() * 90, "lantern": 260 + r.next() * 100}[f]
		var by = goal * .4 + 1200
		if f == "fish":
			var y = 200.0
			while y < by:
				var ph = r.next() * 9
				out.append({"t": "fish", "bg": true, "y": y, "ph": ph, "dir": -1.0 if r.next() < .5 else 1.0})
				y += 300 + r.next() * 200
		if f == "jelly":
			var y = 300.0
			while y < by:
				var x = 60 + r.next() * 240
				out.append({"t": "jelly", "bg": true, "y": y, "x": x, "ph": r.next() * 9})
				y += 380 + r.next() * 200
		if f == "cloudbig":
			var y = 100.0
			while y < by:
				var ph = r.next() * 9; var s = 50 + r.next() * 50
				out.append({"t": "cloud", "bg": true, "y": y, "ph": ph, "s": s, "sp": 6 + r.next() * 10})
				y += 220 + r.next() * 160
		if f == "gear":
			var y = 150.0
			while y < by:
				var x = 40 + r.next() * 280; var s = 30 + r.next() * 40
				out.append({"t": "gear", "bg": true, "y": y, "x": x, "s": s, "dir": -1.0 if r.next() < .5 else 1.0})
				y += 260 + r.next() * 140
		if f == "sign":
			var y = 120.0
			while y < by:
				var x = 50 + r.next() * 260; var w = 30 + r.next() * 40; var h = 10 + r.next() * 14; var ph = r.next() * 9
				out.append({"t": "sign", "bg": true, "y": y, "x": x, "w": w, "h": h, "ph": ph, "hue": [190, 300, 50, 120][int(floor(r.next() * 4))]})
				y += 200 + r.next() * 120
		if f == "flock":
			var y = 200.0
			while y < by:
				var ph = r.next() * 9
				out.append({"t": "flock", "bg": true, "y": y, "ph": ph, "dir": -1.0 if r.next() < .5 else 1.0})
				y += 420 + r.next() * 200
		if f == "eyes":
			var y = 100.0
			while y < by:
				var x = 40 + r.next() * 280
				out.append({"t": "eyes", "bg": true, "y": y, "x": x, "ph": r.next() * 9})
				y += 160 + r.next() * 120
	return out

func init_amb(type: String) -> Array:
	var A: Array = []
	var n = 9 if (type == "puff" or type == "mist") else (50 if type == "rain" else 34)
	for k in n:
		A.append({"x": randf() * W, "y": randf() * VH, "v": 20 + randf() * 40, "d": .15 + randf() * .45, "s": 1 + randf() * 3, "ph": randf() * 7, "vx": (randf() - .5) * 40, "h": randf() * 360})
	return A

# =====================================================================
#                          AIUTI
# =====================================================================
func sy(y: float) -> float:
	return VH - (y - G.cam)

func burst(x: float, y: float, col, n := 10, sp := 160.0) -> void:
	for k in n:
		var a = randf() * 7
		var s = randf() * sp
		G.parts.append({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "l": .5 + randf() * .4, "col": Ctx.css(col)})

func fx_text(x: float, y: float, txt: String, col, size := 14) -> void:
	G.fx.append({"x": x, "y": y, "txt": txt, "col": col, "size": size, "l": 1.0})

func toast(txt: String, d := 1.6, col = "#ff5a7a") -> void:
	G.toastTxt = txt
	G.toastCol = col
	G.toast = d

func later(t: float, f: Callable) -> void:
	G.msgs.append({"t": G.t + t, "f": f})

func cloud_on(q) -> bool:
	return fmod(G.t + q.ph, 3.4) < 2.3

func solid(q) -> bool:
	return not (q.gone > 0) and not (q.k == "cloud" and not cloud_on(q))

func portal_open() -> bool:
	return G.freed and (G.boss == null or G.boss.dead)

func target():
	var p = G.pl
	var best = null
	var bs = -1e9
	for a in G.A:
		if a.y < p.y + 30:
			continue
		if a == G.lastRing and G.t - G.lastRingT < .6:
			continue
		var d = Vector2(a.x - p.x, a.y - (p.y + 12)).length()
		if d > RANGE + (90 if G.perk == "rope" else 0):
			continue
		var s: float = (a.y - p.y) - absf(d - 170) * .5
		if s > bs:
			bs = s
			best = a
	return best

func attach(a) -> void:
	var p = G.pl
	var d = Vector2(a.x - p.x, a.y - (p.y + 12)).length()
	p.hook = {"a": a, "len": maxf(80, d)}
	p.gr = null
	G.combo += 1; G.bestCombo = maxi(G.bestCombo, G.combo); G.comboPop = .3; a.pulse = .4
	A.sfx("hook", G.combo)
	burst(a.x, a.y, "#2ee6c5", 8, 120)

func release(jump: bool) -> void:
	var p = G.pl
	if p.hook == null:
		return
	G.lastRing = p.hook.a; G.lastRingT = G.t; p.hook = null
	if p.perfect:
		p.vx *= 1.15; p.vy = p.vy * 1.1 + 300; G.combo += 1; G.bestCombo = maxi(G.bestCombo, G.combo); G.comboPop = .3
		fx_text(p.x, p.y + 44, "PERFETTO!", "#ffd43b", 20); G.slow = .18; G.shake = 6; A.sfx("perfect"); burst(p.x, p.y + 12, "#ffd43b", 18, 220)
		p.mood = "star"; p.moodT = .8
	else:
		p.vy = maxf(p.vy, 0) + 120
	if jump:
		p.vy += 200
	p.dj = true; p.perfect = false

func hurt(dirx: float, vy := 380.0) -> void:
	var p = G.pl
	if G.done or p.pw.rocket > 0 or p.inv > 0:
		return
	p.hook = null; p.vx = dirx * 260; p.vy = vy; G.shake = 8
	if p.pw.shield:
		p.pw.shield = false; p.inv = 1.0; fx_text(p.x, p.y + 40, "SCUDO!", "#74c0fc", 16); A.sfx("shield"); burst(p.x, p.y + 12, "#74c0fc", 16)
		return
	G.hearts -= 1; p.inv = 1.6; G.combo = 0; A.sfx("hurt"); burst(p.x, p.y + 12, "#ff5a1f", 16); p.mood = "hurt"; p.moodT = 1.0
	Input.vibrate_handheld(60)
	if G.hearts <= 0:
		G.done = true
		main.end_run()
		A.mus_stop()
		later(.5, main.show_lose)

func stomp(e, ex: float, ey: float) -> void:
	var p = G.pl
	p.mood = "smug"; p.moodT = .45; e.alive = false; e.dead = .55; e.dvy = 260.0
	G.stompChain += 1
	var ch: int = G.stompChain
	var v: int = [1, 2, 3, 5, 8][mini(ch - 1, 4)]
	if not (p.pw.rocket > 0):
		p.y = maxf(p.y, ey + e.h); p.vy = 760.0 if p.buf > 0 else 540.0; p.buf = 0.0; p.hook = null
	G.combo += 1; G.comboPop = .3; G.bestCombo = maxi(G.bestCombo, G.combo); G.runGems += v; S.d.gems += v; G.shake = maxf(G.shake, 3 + ch)
	A.snd(320 + ch * 90, .12, "square", .07, 600); A.snd(640 + ch * 90, .08, "triangle", .06, 0, .06)
	burst(ex, ey + e.h / 2, G.th[6], 16, 200); burst(ex, ey + e.h, "#ffffff", 8, 120)
	fx_text(ex, ey + 34, ("PAF x%d! +%d◆" % [ch, v]) if ch > 1 else ("PAF! +%d◆" % v), "#ffd43b" if ch > 2 else "#ffffff", 16 if ch > 2 else 14)

func landed() -> void:
	G.stompChain = 0
	if G.combo >= 3:
		fx_text(G.pl.x, G.pl.y + 44, "COMBO x%d!" % G.combo, "#2ee6c5", 15)
	G.combo = 0

func free_friend(x: float, y: float) -> void:
	G.freed = true; G.pl.mood = "love"; G.pl.moodT = 1.2
	var f: Dictionary = D.FR[G.i]
	fx_text(x, y + 44, "%s È LIBERO!" % f.n.to_upper(), f.c, 16)
	for k in 5:
		burst(x, y, K.hsl(k * 72, 90, 65), 8, 220)
	A.sfx("power")
	G.follow.append(G.i)
	later(.7, _portal_msg)

func _portal_msg() -> void:
	if main.state == "play":
		toast("IL PORTALE È APERTO!", 2, "#2ee6c5")

# =====================================================================
#                          AGGIORNAMENTO
# =====================================================================
func step_msgs() -> void:
	if G.msgs.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for m in G.msgs:
		if G.t >= m.t: due.append(m)
		else: keep.append(m)
	G.msgs = keep
	for m in due:
		m.f.call()

func step_fx_common(dt: float) -> void:
	for q in G.parts:
		q.x += q.vx * dt; q.y += q.vy * dt; q.l -= dt
	G.parts = G.parts.filter(func(q): return q.l > 0)
	for f in G.fx:
		f.l -= dt * .9; f.y += 40 * dt
	G.fx = G.fx.filter(func(f): return f.l > 0)

func eat_step(dt: float) -> void:
	var E = G.eat
	var p = G.pl
	E.t += dt; G.t += dt
	step_fx_common(dt)
	G.shake = maxf(0, G.shake - dt * 20); G.toast -= dt
	if E.t > .5 and not E.ch:
		E.ch = true; G.shake = 14.0; A.snd(150, .2, "square", .12, -110); A.snd(60, .4, "sawtooth", .1, -20); fx_text(p.x, p.y + 50, "GNAM!", "#ff5a7a", 22)
		Input.vibrate_handheld(150)
	if E.t > 1.7:
		G.eat = null
		var k = G.key
		p.inv = 0.0; p.pw.rocket = 0.0; p.hook = null
		hurt(0, 0)
		if G.done:
			return
		p.x = k.x + (24 if k.x < W / 2 else -24); p.y = k.y - 26; p.vx = 0.0; p.vy = 0.0; p.gr = null; p.inv = 1.8
		G.cam = p.y - VH * .42; G.lava = minf(G.lava, p.y - 420); G.lavaPause = 1.5; G.keyWarn = false
		toast("🔑 PRIMA PRENDI LA CHIAVE!", 2.4, "#ffd43b"); burst(p.x, p.y + 12, "#9775fa", 20, 200)

func warp_step(dt: float) -> void:
	var w = G.warp
	var po = G.portal
	w.t += dt; G.t += dt
	for k in 4:
		var a = randf() * 7
		var r = 90 + randf() * 90
		G.parts.append({"x": po.x + cos(a) * r, "y": po.y + sin(a) * r, "vx": -cos(a) * r * 2.2, "vy": -sin(a) * r * 2.2, "l": .4, "col": Color.WHITE if randf() < .5 else Ctx.css(G.th[5])})
	step_fx_common(dt)
	G.cam += (po.y - VH * .5 - G.cam) * minf(1, dt * 4); G.shake = maxf(G.shake, w.t * 5)
	G.toast -= dt
	if w.t > 1.25 and not w.fired:
		w.fired = true; G.shake = 0.0; burst(po.x, po.y, "#ffffff", 40, 500); main.win()

func boss_step(dt: float, p) -> void:
	var b = G.boss
	if b.dead:
		return
	if not b.on:
		if p.y > G.goal - 280:
			b.on = true; toast("IL RE OMBRA!", 2.5, "#ff2b4a"); A.sfx("hurt"); G.shake = 8.0
		return
	G.lavaPause = 999.0; b.t += dt; b.inv = maxf(0, b.inv - dt)
	if b.st == "idle":
		b.x = W / 2 + sin(b.t * 1.2) * 110; b.y += (G.goal + 200 - b.y) * minf(1, dt * 3); b.cd -= dt
		if b.cd <= 0:
			b.shots += 1
			var dx: float = p.x - b.x
			var dy: float = (p.y + 12) - b.y
			var d = Vector2(dx, dy).length()
			if d == 0: d = 1
			G.orbs.append({"x": b.x, "y": b.y, "vx": dx / d * 165, "vy": dy / d * 165, "l": 4.0})
			A.snd(240, .25, "sawtooth", .05, -160); b.cd = .95
			if b.shots >= 3:
				b.shots = 0; b.st = "swoop"; b.t2 = 0.0; b.dir = 1.0 if p.x < W / 2 else -1.0; toast("ORA! SALTAGLI IN TESTA!", 1.6, "#ffd43b")
	else:
		b.t2 += dt; b.y += (G.goal + 36 - b.y) * minf(1, dt * 5); b.x += b.dir * 115 * dt
		if b.x < WALL + 40 or b.x > W - WALL - 40:
			b.dir *= -1; b.x = maxf(WALL + 40, minf(W - WALL - 40, b.x))
		if b.t2 > 3.4:
			b.st = "idle"; b.cd = 1.0
	for o in G.orbs:
		o.x += o.vx * dt; o.y += o.vy * dt; o.l -= dt
		if o.l > 0 and Vector2(p.x - o.x, p.y + 12 - o.y).length() < 15:
			o.l = 0.0; hurt(_sgn1(p.x - o.x))
	G.orbs = G.orbs.filter(func(o): return o.l > 0)
	var SS = 44.0
	if b.inv <= 0 and absf(p.x - b.x) < 12 + SS / 2 and p.y < b.y + SS / 2 and p.y + 24 > b.y - SS / 2:
		if (p.vy < 0 and p.y > b.y) or p.pw.rocket > 0:
			b.hp -= 1; b.inv = 1.3; p.vy = 640.0; G.shake = 12.0; A.sfx("stomp"); burst(b.x, b.y, "#9775fa", 24, 260)
			fx_text(b.x, b.y + 44, "COLPITO!" if b.hp > 0 else "SCONFITTO!", "#ffd43b", 18); b.st = "idle"; b.cd = 1.4
			if b.hp <= 0:
				b.dead = true; G.orbs = []; G.slow = .7; G.lavaPause = 0.0; G.lava -= 400; burst(b.x, b.y, "#ffffff", 40, 400)
				for k in 6:
					burst(b.x, b.y, K.hsl(k * 60, 90, 60), 10, 300)
				toast("IL PORTALE DI CASA SI APRE!", 3, "#ffd43b"); A.sfx("win")
		else:
			hurt(_sgn1(p.x - b.x))

func _sgn1(v: float) -> float:
	return 1.0 if v == 0 else signf(v)

func update(rdt: float) -> void:
	var p = G.pl
	var pw = p.pw
	step_msgs()
	if G.warp != null:
		warp_step(rdt); return
	if G.eat != null:
		eat_step(rdt); return
	if G.key != null and not G.key.got and not G.done and not (pw.rocket > 0):
		var over: float = p.y - G.key.y
		if over > 70 and not G.keyWarn:
			G.keyWarn = true; toast("🔑 HAI DIMENTICATO LA CHIAVE!", 2.2, "#ffd43b"); A.snd(70, .7, "sawtooth", .08, -25)
		if over < 20:
			G.keyWarn = false
		if over > 220:
			G.eat = {"t": 0.0, "dir": 1.0 if p.x < W / 2 else -1.0, "y": p.y, "ch": false}
			A.snd(55, 1, "sawtooth", .1, -15); G.shake = 6.0
			return
	p.py = p.y
	p.land = maxf(0, p.land - rdt)
	p.idle = (p.idle + rdt) if (p.gr != null and absf(p.vx) < 8 and p.hook == null) else 0.0
	G.slow = maxf(0, G.slow - rdt)
	var dt = rdt * (.4 if G.slow > 0 else 1.0)
	G.t += dt
	main.poll_hold()
	var kx = (1.0 if main.key_right() else 0.0) - (1.0 if main.key_left() else 0.0)
	var ix = clampf(main.inp.x + kx, -1, 1)
	if ix:
		p.face = signf(ix)
	var hold: bool = main.holding()
	for q in G.P:
		if q.vx:
			q.x += q.vx * dt
			if q.x < q.min or q.x + q.w > q.max:
				q.vx *= -1; q.x = maxf(q.min, minf(q.max - q.w, q.x))
		if q.st > 0:
			q.st -= dt
			if q.st <= 0:
				q.st = 0.0; q.gone = 3.0; burst(q.x + q.w / 2, q.y, G.th[4], 12)
		if q.gone > 0:
			q.gone = maxf(0, q.gone - dt)
		if q.boing > 0:
			q.boing -= dt
	G.lavaPause -= dt
	if G.t > G.lavaStart and not G.done and G.lavaPause <= 0:
		var gp: float = p.y - G.lava
		G.lava += (G.lspeed + maxf(0, gp - 650) * .6) * dt
	A.fast = 1.18 if p.y - G.lava < 260 else 1.0
	if main.inp.jumpQ:
		p.buf = .14; main.inp.jumpQ = false
	p.buf -= dt; p.coy -= dt; p.inv -= dt; p.moodT -= dt
	pw.wings = maxf(0, pw.wings - dt); pw.magnet = maxf(0, pw.magnet - dt)
	if p.hook == null and hold and not (pw.rocket > 0):
		var a0 = target()
		if a0 != null:
			attach(a0)
	if pw.rocket > 0:
		pw.rocket -= dt; p.hook = null; p.gr = null; p.vy = minf(p.vy + 2600 * dt, 480)
		var lim = minf(p.rocketY0 + 300, minf(G.key.y - 10 if (G.key != null and not G.key.got) else 1e9, minf(G.cage.y - 20 if (G.cage != null and not G.cage.open) else 1e9, G.minion.y + 60 if (G.minion != null and not G.minion.caught) else 1e9)))
		if p.y >= lim:
			pw.rocket = 0.0; p.vy = minf(p.vy, 200)
		p.vx += (ix * 240 - p.vx) * minf(1, dt * 6)
		p.x += p.vx * dt; p.y += p.vy * dt; p.rot *= .8
		G.parts.append({"x": p.x + (randf() - .5) * 10, "y": p.y - 2, "vx": (randf() - .5) * 60, "vy": -220.0, "l": .4, "col": Ctx.css("#ffd43b" if randf() < .5 else "#ff6b1a")})
	elif p.hook != null:
		var a = p.hook.a
		if p.hook.len > 140:
			p.hook.len = maxf(140, p.hook.len - 240 * dt)
		p.vy -= GRAV * dt; p.vx += ix * 650 * dt
		var dx: float = p.x - a.x
		var dy: float = (p.y + 12) - a.y
		var d = Vector2(dx, dy).length()
		if d == 0: d = 1
		if dy < 0:
			var tx = -dy / d
			var ty = dx / d
			var vt: float = p.vx * tx + p.vy * ty
			var s = signf(vt) if absf(vt) > 20 else float(p.face)
			p.vx += tx * s * 380 * dt; p.vy += ty * s * 380 * dt
		p.x += p.vx * dt; p.y += p.vy * dt
		dx = p.x - a.x; dy = (p.y + 12) - a.y; d = Vector2(dx, dy).length()
		if d == 0: d = 1
		if d > p.hook.len:
			var nx = dx / d
			var ny = dy / d
			p.x = a.x + nx * p.hook.len; p.y = a.y + ny * p.hook.len - 12
			var vr: float = p.vx * nx + p.vy * ny
			if vr > 0:
				p.vx -= nx * vr; p.vy -= ny * vr
		var sp = Vector2(p.vx, p.vy).length()
		if sp > 950:
			p.vx *= 950 / sp; p.vy *= 950 / sp
		p.rot = atan2(dx, -dy) * .7
		if G.perk == "perfect":
			p.perfect = p.vy > 60 and dy > -p.hook.len * .9
		else:
			p.perfect = p.vy > 140 and dy > -p.hook.len * .8
		if not hold or p.buf > 0:
			var j: bool = p.buf > 0
			p.buf = 0.0
			release(j)
	else:
		var tx = ix * SPEED
		var acc = 2200.0 if p.gr != null else 1300.0
		p.vx += clampf(tx - p.vx, -acc * dt, acc * dt)
		p.vy -= GRAV * dt
		if p.wall and p.vy < -140 and ix == p.wall:
			p.vy = -140.0
		p.vy = maxf(p.vy, -1100)
		if p.buf > 0:
			if p.gr != null or p.coy > 0:
				p.vy = JUMP; p.gr = null; p.coy = 0.0; p.buf = 0.0; A.sfx("jump"); burst(p.x, p.y, "#ffffff88", 6, 80)
			elif p.wall:
				p.vy = JUMP * .92; p.vx = -p.wall * 220.0; p.buf = 0.0; A.sfx("jump"); burst(p.x - p.wall * 10, p.y + 12, "#ffffff88", 6, 80)
			elif (pw.wings > 0 or G.perk == "dj") and p.dj:
				p.dj = false; p.mood = "wink"; p.moodT = .4; p.vy = JUMP * .9; p.buf = 0.0; A.sfx("jump"); burst(p.x, p.y, "#ffffff", 12, 140)
		if p.gr != null and p.gr.vx:
			p.x += p.gr.vx * dt
		var py0: float = p.y
		p.x += p.vx * dt; p.y += p.vy * dt
		var was = p.gr
		p.gr = null
		if p.vy <= 0:
			for q in G.P:
				if not solid(q):
					continue
				if p.x + 10 > q.x and p.x - 10 < q.x + q.w and py0 >= q.y - .5 and p.y <= q.y:
					var iv: float = -p.vy
					p.y = q.y
					if q.k == "tramp":
						p.mood = "swing"; p.moodT = .5; p.vy = 980.0; q.boing = .3; A.sfx("boing"); burst(p.x, p.y, "#ffffff", 8, 100); fx_text(p.x, p.y + 30, "BOING!", "#ffffff", 13)
						break
					p.vy = 0.0; p.gr = q
					if q.k == "crumble" and not q.st and not q.gone:
						q.st = .5
					if was == null:
						if py0 - q.y > 2:
							burst(p.x, p.y, "#ffffff66", 5, 60)
						if iv > 320:
							p.land = minf(.2, iv / 3800)
						landed()
					break
		if was != null and p.gr == null:
			p.coy = .1
		if p.gr != null:
			p.dj = true
		p.rot *= .8
		if p.gr == null:
			p.rot += p.vx * .00012
	p.wall = 0
	if p.x - 12 < WALL:
		p.x = WALL + 12
		if p.vx < 0: p.vx = 0.0
		if p.gr == null: p.wall = -1
	if p.x + 12 > W - WALL:
		p.x = W - WALL - 12
		if p.vx > 0: p.vx = 0.0
		if p.gr == null: p.wall = 1
	if p.hook == null:
		for s in G.SP:
			if p.wall == s.side and absf(p.y + 12 - s.y) < 24:
				p.vx = -s.side * 430; p.vy = 820.0; s.boing = .3; p.mood = "swing"; p.moodT = .5; A.sfx("boing"); burst(p.x, p.y + 12, "#ffd43b", 10, 140)
	for s in G.SP:
		if s.boing > 0:
			s.boing -= dt
	if p.y < 0:
		p.y = 0.0; p.vy = 0.0; p.gr = G.P[0]
	G.maxY = maxf(G.maxY, p.y)
	# pericolo
	if not G.done and p.y < G.lava - 4:
		if p.inv > 0 or pw.rocket > 0:
			p.vy = maxf(p.vy, 900)
		else:
			hurt(1.0 if p.x < W / 2 else -1.0, 1000); G.lava -= 260; G.lavaPause = 1.6
	# nemici
	for e in G.E:
		if not e.alive:
			if e.dead > 0:
				e.dead -= dt
				if e.t != "crawl":
					e.dvy -= GRAV * dt; e.y += e.dvy * dt; e.rot += dt * 10
			continue
		if e.t == "crawl":
			var onMe: bool = p.gr == e.p
			if onMe and not e.al:
				e.al = 1; e.alt = .7; A.snd(520, .08, "square", .04, 200)
			if not onMe: e.al = 0
			if e.alt > 0: e.alt -= dt
			if onMe and absf(p.x - e.x) > 6: e.dir = signf(p.x - e.x)
			e.x += e.dir * e.sp * (1.7 if onMe else 1.0) * dt
			if e.x < e.p.x + 10 or e.x > e.p.x + e.p.w - 10:
				e.dir *= -1; e.x = maxf(e.p.x + 10, minf(e.p.x + e.p.w - 10, e.x))
			e.y = e.p.y
		if e.t == "bat":
			e.ph += dt * e.sp; e.x = W / 2 + sin(e.ph) * (W / 2 - WALL - 30)
			var dy2: float = (p.y + 12) - e.by
			if absf(p.x - e.x) < 110 and absf(dy2) < 150:
				e.sw += (clampf(dy2, -55, 55) - e.sw) * minf(1, dt * 1.6); e.al = 1
			else:
				e.sw *= 1 - minf(1, dt * 1.2); e.al = 0
			e.y = e.by + e.sw + sin(e.ph * 2.3) * 14
		if e.t == "drop":
			if e.st == 0 and absf(p.x - e.x) < 34 and p.y < e.hy and e.hy - p.y < 260:
				e.st = 1; e.sh = .35
			if e.st == 1:
				e.sh -= dt
				if e.sh <= 0: e.st = 2
			if e.st == 2:
				e.vy -= GRAV * .8 * dt; e.y += e.vy * dt
				if e.y < G.cam - 200:
					e.st = 0; e.y = e.hy; e.vy = 0.0
		var ex: float = e.x
		var ey: float = e.y - e.h if e.t == "drop" else (e.y - e.h / 2 if e.t == "bat" else e.y)
		var canStomp: bool = e.t != "drop"
		if canStomp and p.vy < 0 and absf(p.x - ex) < 14 + e.w / 2 and p.y <= ey + e.h + 6 and p.y + 24 > ey and (p.py >= ey + e.h * .45 or p.y > ey + e.h * .3):
			stomp(e, ex, ey)
		elif absf(p.x - ex) < 8 + e.w / 2 and p.y < ey + e.h - 3 and p.y + 21 > ey:
			if canStomp and pw.rocket > 0:
				stomp(e, ex, ey)
			else:
				hurt(_sgn1(p.x - ex))
				if e.t == "drop":
					e.st = 0; e.y = e.hy; e.vy = 0.0
	# gemme
	for g in G.GM:
		if g.got:
			continue
		var dx: float = p.x - g.x
		var dy: float = p.y + 12 - g.y
		var d = Vector2(dx, dy).length()
		if (pw.magnet > 0 and d < 160) or (G.perk == "magnet" and d < 95):
			g.x += dx / d * 520 * dt; g.y += dy / d * 520 * dt
		if d < 18:
			g.got = true
			var v: int = maxi(1, G.combo) + (1 if G.perk == "gem2" else 0)
			G.runGems += v; S.d.gems += v; A.sfx("gem", G.combo)
			if not (p.moodT > 0):
				p.mood = "yum"; p.moodT = .22
			burst(g.x, g.y, "#5ff2ff", 5, 90)
			if v > 1:
				fx_text(g.x, g.y + 14, "+" + str(v), "#5ff2ff", 12)
	# power-up
	for u in G.U:
		if u.got:
			continue
		if Vector2(p.x - u.x, p.y + 12 - u.y).length() < 24:
			u.got = true; A.sfx("power"); burst(u.x, u.y, "#fff", 16, 180); fx_text(u.x, u.y + 20, PWN[u.t], "#fff", 15)
			match u.t:
				"wings": pw.wings = 12.0
				"shield": pw.shield = true
				"magnet": pw.magnet = 10.0
				"rocket": pw.rocket = .85; p.rocketY0 = p.y; p.hook = null
	for k in G.CP:
		if not k.on and absf(p.x - k.x) < 30 and absf(p.y - k.y) < 30:
			k.on = true; G.cpY = k.y; G.cpX = k.x; toast("CHECKPOINT"); A.sfx("cp"); burst(k.x, k.y + 20, "#ff5a7a", 18)
	var po = G.portal
	var nearP = Vector2(p.x - po.x, p.y + 12 - po.y).length() < 40
	if nearP and not portal_open() and G.t - G.lockMsg2 > 2.2:
		G.lockMsg2 = G.t
		fx_text(po.x, po.y + 56, "SCONFIGGI IL RE OMBRA!" if G.freed else "PRIMA LIBERA " + str(D.FR[G.i].n).to_upper() + "!", "#ffd43b", 13)
	if not G.done and nearP and portal_open():
		G.done = true
		var dx: float = p.x - po.x
		var dy: float = p.y + 12 - po.y
		G.warp = {"t": 0.0, "r0": Vector2(dx, dy).length(), "a0": atan2(dy, dx), "fired": false}
		A.mus_stop(); p.hook = null; A.sfx("warp"); G.shake = 4.0
	if G.key != null and not G.key.got and Vector2(p.x - G.key.x, p.y + 12 - G.key.y).length() < 22:
		G.key.got = true; A.sfx("power"); fx_text(G.key.x, G.key.y + 20, "CHIAVE!", "#ffd43b", 15); burst(G.key.x, G.key.y, "#ffd43b", 16)
	var cg = G.cage
	if cg != null and not cg.open and absf(p.x - cg.x) < 26 and p.y > cg.y - 6 and p.y < cg.y + 34:
		if G.key.got:
			cg.open = true; free_friend(cg.x, cg.y + 16)
		elif G.t - G.lockMsg > 2:
			G.lockMsg = G.t; fx_text(cg.x, cg.y + 56, "SERVE LA CHIAVE!", "#ffd43b", 13)
	var mn = G.minion
	if mn != null and not mn.caught:
		if mn.st == 0 and p.y > mn.y - 260:
			mn.st = 1; toast("PRENDI L'OMBRETTO!", 2, "#b197fc"); A.sfx("hurt")
		if mn.st == 1:
			mn.ph += dt
			var lead: float = mn.y - p.y
			var spd = 0.0 if lead > 320 else (95.0 if lead < 120 else 66.0)
			mn.y = minf(G.goal + 40, mn.y + spd * dt); mn.x = W / 2 + sin(mn.ph * 1.25) * (W / 2 - WALL - 40)
		if Vector2(p.x - mn.x, p.y + 12 - mn.y).length() < 28:
			mn.caught = true; burst(mn.x, mn.y, "#5f3dc4", 24, 240); fx_text(mn.x, mn.y + 26, "PRESO!", "#b197fc", 16); free_friend(mn.x, mn.y)
	for k in G.kids:
		if not k.got and Vector2(p.x - k.x, p.y + 12 - k.y).length() < 20:
			k.got = true; S.d.kids[G.i] = int(S.d.kids[G.i]) | k.bit; S.store(); fx_text(k.x, k.y + 20, "CUBETTO SALVATO!", "#8ce99a", 13); A.sfx("gem", 8); burst(k.x, k.y, k.col, 12)
	if G.boss != null:
		boss_step(dt, p)
	G.hist.append(Vector2(p.x, p.y))
	if G.hist.size() > 90:
		G.hist.pop_front()
	var ch = G.ch
	if not G.c2 and G.runGems >= ch.gems:
		G.c2 = true
		if not S.d.st[G.i][1]:
			S.d.st[G.i][1] = true; S.store(); toast("★ SFIDA: %d GEMME!" % ch.gems, 2, "#ffd43b"); A.sfx("cp")
	if not G.c3 and G.bestCombo >= ch.combo:
		G.c3 = true
		if not S.d.st[G.i][2]:
			S.d.st[G.i][2] = true; S.store(); toast("★ SFIDA: COMBO x%d!" % ch.combo, 2, "#ffd43b"); A.sfx("cp")
	var sg = G.secret
	if sg != null and not sg.got and Vector2(p.x - sg.x, p.y + 12 - sg.y).length() < 24:
		sg.got = true; G.runGems += 25; S.d.gems += 25; S.d.sec[G.i] = true; S.store(); fx_text(sg.x, sg.y + 24, "GEMMA SEGRETA! +25", "#ff8cf0", 15); A.sfx("power")
		for k in 4:
			burst(sg.x, sg.y, K.hsl(k * 90, 90, 65), 8, 220)
	# effetti
	for q in G.parts:
		q.vx *= .96; q.vy -= 300 * dt; q.x += q.vx * dt; q.y += q.vy * dt; q.l -= dt
	G.parts = G.parts.filter(func(q): return q.l > 0)
	if portal_open():
		var nr = maxf(0, 1 - Vector2(p.x - po.x, (p.y + 12) - po.y).length() / 260)
		if randf() < .5 + nr * .5:
			var a = randf() * 7
			var r = 95 + randf() * 60
			G.parts.append({"x": po.x + cos(a) * r, "y": po.y + sin(a) * r, "vx": -cos(a) * r * (1.5 + nr), "vy": -sin(a) * r * (1.5 + nr) + 120, "l": .55, "col": Color.WHITE if randf() < .5 else Ctx.css(G.th[5])})
	for f in G.fx:
		f.l -= dt * .9; f.y += 40 * dt
	G.fx = G.fx.filter(func(f): return f.l > 0)
	var spd2 = Vector2(p.vx, p.vy).length()
	if G.combo >= 2 or spd2 > 650 or pw.rocket > 0:
		G.trail.append({"x": p.x, "y": p.y + 12, "l": .35, "r": p.rot})
	for q in G.trail:
		q.l -= dt
	G.trail = G.trail.filter(func(q): return q.l > 0)
	for a in G.A:
		if a.pulse > 0:
			a.pulse -= dt
	G.shake = maxf(0, G.shake - dt * 22); G.comboPop = maxf(0, G.comboPop - dt)
	var look = clampf(p.vy * .12, -60, 120)
	var tc = maxf(-VH * .28, p.y - VH * .42 + look)
	G.cam += (tc - G.cam) * minf(1, dt * 5)
	G.toast -= rdt
	G.tg = null if p.hook != null else target()

# =====================================================================
#                          DISEGNO
# =====================================================================
func render() -> void:
	c.begin_frame()
	if G == null or G.art == null:
		return
	var th: Array = G.th
	var p = G.pl
	var pw = p.pw
	var sk = D.cur_skin(G.t)
	if G.shake > 0:
		c.translate((randf() - .5) * G.shake, (randf() - .5) * G.shake)
	var art: Dictionary = G.art
	var stl: Dictionary = G.st
	var adt = clampf(G.t - (G.lt if G.lt != null else G.t), 0, .05)
	G.lt = G.t
	var dc: float = G.cam - (G.lc if G.lc != null else G.cam)
	G.lc = G.cam
	if stl.sc == "storm":
		if main.state == "play" and randf() < adt * .22:
			G.flash = 1.0; A.snd(70, .6, "sawtooth", .04, -30)
		G.flash = maxf(0, G.flash - adt * 2.5)
	draw_backdrop(th, stl, art)
	draw_scenery_bg(th)
	var spd = Vector2(p.vx, p.vy).length()
	if spd > 650:
		c.strokeStyle = "#ffffff22"; c.lineWidth = 2
		for k in 8:
			var x = fmod(k * 53 + G.t * 900, W)
			var y = fmod(k * 97 + G.t * 1400, VH)
			c.beginPath(); c.moveTo(x, y); c.lineTo(x - p.vx * .04, y + p.vy * .04); c.stroke()
	draw_walls(art); draw_scenery_wall(th); draw_dark()
	for s in G.SP:
		var y = sy(s.y)
		if y < -30 or y > VH + 30:
			continue
		var bx = WALL if s.side < 0 else W - WALL
		var o: float = (4.0 if s.boing > 0 else 12.0) * -s.side
		c.strokeStyle = "#ffd43b"; c.lineWidth = 2.5; c.beginPath()
		for k in 7:
			c.lineTo(bx + o * k / 6.0, y + (-5 if k % 2 else 5))
		c.stroke()
		c.fillStyle = "#ff5a1f"; c.fillRect(bx + o - (0 if s.side < 0 else 4), y - 9, 4, 18)
	# anelli
	for a in G.A:
		var y = sy(a.y)
		if y < -30 or y > VH + 30:
			continue
		var on: bool = p.hook != null and p.hook.a == a
		var tg: bool = a == G.tg
		var pl: float = a.pulse * 20 if a.pulse > 0 else 0.0
		c.save(); c.translate(a.x, y); c.shadowColor = "#22d3ee"; c.shadowBlur = 18 if (tg or on) else 8
		c.strokeStyle = "#ffffff" if on else "#22d3ee"; c.lineWidth = 4; c.beginPath(); c.arc(0, 0, 10 + pl, 0, 7); c.stroke()
		c.rotate(G.t * (4 if tg else 1.2)); c.setLineDash([5, 6]); c.lineWidth = 2; c.strokeStyle = "#ffffff" if tg else "#22d3ee88"
		c.beginPath(); c.arc(0, 0, 17 + (sin(G.t * 10) * 2 if tg else 0.0), 0, 7); c.stroke(); c.setLineDash([]); c.restore(); c.shadowBlur = 0
	# piattaforme
	for q in G.P:
		var y = sy(q.y)
		if y < -30 or y > VH + 30:
			continue
		if q.gone > 0:
			continue
		var x: float = q.x
		if q.st > 0:
			x += (randf() - .5) * 3
		if q.k == "cloud":
			var on = cloud_on(q)
			var al = 1.0 if on else .15
			if on and fmod(G.t + q.ph, 3.4) > 1.8:
				al = .35 if int(floor(G.t * 14)) % 2 else 1.0
			c.globalAlpha = al; c.fillStyle = "#f1f3f5"
			var k = 0.0
			while k < q.w:
				c.beginPath(); c.arc(x + 7 + k, y + 2 + sin(k + G.t * 2) * 1.5, 9, 0, 7); c.fill()
				k += 14
			c.globalAlpha = 1
			continue
		if q.k == "tramp":
			var comp = 3.0 if q.boing > 0 else 9.0
			c.fillStyle = "#495057"; c.fillRect(x + 4, y + 4, q.w - 8, 6); c.strokeStyle = "#ced4da"; c.lineWidth = 2; c.beginPath()
			for k in 5:
				c.lineTo(x + q.w / 2 + (-8 if k % 2 else 8), y + 4 - k * comp / 4)
			c.stroke(); c.fillStyle = "#fa5252"; c.fillRect(x, y - comp - 3, q.w, 5); c.fillStyle = "#fff"; c.fillRect(x + 6, y - comp - 3, 8, 2)
			continue
		if q.k == "crumble":
			c.fillStyle = "#00000055"; c.fillRect(x + 3, y + 5, q.w, 9); c.fillStyle = "#6d4c41"; c.fillRect(x, y, q.w, 10); c.fillStyle = "#a1887f"; c.fillRect(x, y - 1, q.w, 3)
			c.strokeStyle = "#3e2723"; c.lineWidth = 1.5
			var k = 12.0
			while k < q.w - 6:
				c.beginPath(); c.moveTo(x + k, y); c.lineTo(x + k + 4, y + 5); c.lineTo(x + k - 2, y + 10); c.stroke()
				k += 16
			if q.st > 0:
				c.fillStyle = "#a1887f"
				for kk in 3:
					c.fillRect(x + randf() * q.w, y + 10 + randf() * 8, 2, 2)
			continue
		draw_plat(q, x, y, th, stl.pl, G.t)
	draw_lights(th)
	# checkpoint
	for k in G.CP:
		var y = sy(k.y)
		c.fillStyle = "#ddd"; c.fillRect(k.x - 1, y - 34, 2, 34); c.fillStyle = "#ff5a7a" if k.on else "#666"
		c.beginPath(); c.moveTo(k.x + 1, y - 34); c.lineTo(k.x + 20, y - 28); c.lineTo(k.x + 1, y - 22); c.fill()
	# gemme
	for gm in G.GM:
		if gm.got:
			continue
		var y = sy(gm.y)
		if y < -20 or y > VH + 20:
			continue
		var sx = absf(sin(G.t * 3 + gm.x))
		c.save(); c.translate(gm.x, y); c.scale(.4 + sx * .6, 1); c.fillStyle = "#5ff2ff"; c.shadowColor = "#5ff2ff"; c.shadowBlur = 8
		c.beginPath(); c.moveTo(0, -7); c.lineTo(6, 0); c.lineTo(0, 7); c.lineTo(-6, 0); c.fill(); c.shadowBlur = 0; c.fillStyle = "#ffffffcc"; c.fillRect(-2, -4, 2, 4); c.restore()
	if G.key != null and not G.key.got:
		var y = sy(G.key.y)
		if y > -30 and y < VH + 30:
			K.drawKey(c, G.key.x, y, G.t)
	if G.cage != null and not G.cage.open:
		var y = sy(G.cage.y)
		if y > -60 and y < VH + 40:
			K.drawCage(c, G.cage.x, y, G.t, G.i, stl.pl)
	for k in G.kids:
		if k.got:
			continue
		var y = sy(k.y)
		if y < -20 or y > VH + 20:
			continue
		K.drawCube(c, k.x, y - 6 - absf(sin(G.t * 5 + k.x)) * 3, 11, "wow", G.t, 0, {"b": k.col, "t": k.col, "d": k.col, "hat": ""})
		if sin(G.t * 4 + k.x) > 0:
			c.font = "9px Bungee"; c.fillStyle = "#fff"; c.textAlign = "center"; c.fillText("!", k.x, y - 19)
	var mn = G.minion
	if mn != null and not mn.caught:
		var y = sy(mn.y)
		if y > -70 and y < VH + 60:
			K.drawMinion(c, mn.x, y, G.t, G.i)
	var sgm = G.secret
	if sgm != null and not sgm.got:
		var y = sy(sgm.y)
		if y > -30 and y < VH + 30:
			var h = fmod(G.t * 120, 360.0)
			var hc = K.hsl(h, 90, 65)
			c.save(); c.translate(sgm.x, y + sin(G.t * 3) * 3); c.shadowColor = hc; c.shadowBlur = 18; c.fillStyle = hc
			c.beginPath(); c.moveTo(0, -12); c.lineTo(9, -2); c.lineTo(0, 12); c.lineTo(-9, -2); c.fill(); c.shadowBlur = 0
			c.fillStyle = "#ffffffcc"; c.beginPath(); c.moveTo(0, -12); c.lineTo(4, -2); c.lineTo(0, 2); c.lineTo(-4, -2); c.fill()
			for k in 3:
				var a = G.t * 3 + k * 2.1
				c.fillStyle = "#fff"; c.fillRect(cos(a) * 16 - 1, sin(a) * 16 - 1, 2, 2)
			c.restore()
	# power-up
	c.textAlign = "center"; c.textBaseline = "middle"
	for u in G.U:
		if u.got:
			continue
		var y = sy(u.y) + sin(G.t * 3 + u.ph) * 4
		if y < -30 or y > VH + 30:
			continue
		c.fillStyle = "#ffffff22"; c.strokeStyle = "#fff"; c.lineWidth = 2; c.beginPath(); c.arc(u.x, y, 15, 0, 7); c.fill(); c.stroke()
		c.font = "16px serif"; c.fillText(PWI[u.t], u.x, y + 1)
	c.textBaseline = "alphabetic"
	draw_portal(th, p, sk)
	# nemici
	for e in G.E:
		if not e.alive and not (e.dead > 0):
			continue
		var y = sy(e.y)
		if y < -40 or y > VH + 60:
			continue
		if not e.alive:
			c.save(); c.globalAlpha = minf(1, e.dead * 3)
			if e.t == "crawl":
				c.translate(e.x, y); c.scale(1.4, .3); c.translate(-e.x, -y)
			else:
				c.translate(e.x, y); c.rotate(e.rot); c.scale(1, -1); c.translate(-e.x, -y)
			draw_enemy(e, y, G.t, th, stl); c.restore()
			continue
		draw_enemy(e, y, G.t, th, stl)
	var bs = G.boss
	if bs != null and not bs.dead:
		var y = sy(bs.y)
		if y > -80 and y < VH + 80:
			K.drawOmbra(c, bs.x, y, 44, G.t, "flash" if (bs.inv > 0 and int(floor(G.t * 12)) % 2) else ("hurt" if bs.hp < 3 else "n"))
			for k in 3:
				K.circ(c, bs.x - 12 + k * 12, y - 46, 3.5, "#ff2b4a" if k < bs.hp else "#3a3a44")
	if bs != null:
		for o in G.orbs:
			var y = sy(o.y)
			K.circ(c, o.x, y, 9, "rgba(42,16,64,.9)"); K.circ(c, o.x, y, 4, "#ff2b4a")
	# scia
	for q in G.trail:
		c.globalAlpha = q.l / .35 * .5; c.fillStyle = "#ffd43b" if pw.rocket > 0 else sk.tr
		var s: float = 20 * q.l / .35 + 4
		c.fillRect(q.x - s / 2, sy(q.y) - s / 2, s, s)
	c.globalAlpha = 1
	# corda
	var py = sy(p.y)
	if p.hook != null:
		var a = p.hook.a
		c.strokeStyle = "#ffd43b" if p.perfect else "#2ee6c5"; c.lineWidth = 4 if p.perfect else 3; c.shadowColor = c.strokeStyle; c.shadowBlur = 14 if p.perfect else 6
		c.beginPath(); c.moveTo(p.x, py - 12); c.lineTo(a.x, sy(a.y)); c.stroke(); c.shadowBlur = 0
	elif G.tg != null:
		c.strokeStyle = "#2ee6c555"; c.lineWidth = 1.5; c.setLineDash([3, 6]); c.beginPath(); c.moveTo(p.x, py - 12); c.lineTo(G.tg.x, sy(G.tg.y)); c.stroke(); c.setLineDash([])
	# kubo
	if pw.magnet > 0:
		c.strokeStyle = "#ff6b6b55"; c.lineWidth = 2; c.beginPath(); c.arc(p.x, py - 12, 30 + fmod(G.t * 60, 30.0), 0, 7); c.stroke()
	if pw.wings > 0:
		var f = sin(G.t * 20) * .5
		c.fillStyle = "#ffffffdd"
		for s in [-1, 1]:
			c.save(); c.translate(p.x + s * 13, py - 16); c.rotate(s * (.4 + f)); c.beginPath(); c.ellipse(s * 7, 0, 9, 4, 0, 0, 7); c.fill(); c.restore()
	if G.warp == null:
		var j = 0
		for k in G.follow:
			var hi: int = maxi(0, G.hist.size() - 1 - 14 * (j + 1))
			if G.hist.size() > 0:
				var h: Vector2 = G.hist[hi]
				K.drawCube(c, h.x, sy(h.y) - 8 - absf(sin(G.t * 6 + j)) * 3, 16, "happy", G.t + j, 0, D.friend_skin(k))
			j += 1
		c.globalCompositeOperation = "lighter"
		var kg = c.createRadialGradient(p.x, py - 12, 4, p.x, py - 12, 80); kg.addColorStop(0, "rgba(255,190,120,.26)"); kg.addColorStop(1, "rgba(255,190,120,0)")
		c.fillStyle = kg; c.fillRect(p.x - 80, py - 92, 160, 160); c.globalCompositeOperation = "source-over"
	if G.warp == null and not (G.eat != null and G.eat.t > .5) and not (p.inv > 0 and int(floor(G.t * 12)) % 2):
		var mood = "n"
		if p.moodT > 0: mood = p.mood
		elif p.inv > 1: mood = "hurt"
		elif pw.rocket > 0: mood = "scream"
		elif p.hook != null: mood = "star" if p.perfect else "swing"
		elif p.land > 0: mood = "squash"
		elif p.wall and p.vy < 0: mood = "wall"
		elif p.y - G.lava < 170: mood = "scream"
		elif p.gr == null: mood = "jump" if p.vy > 90 else ("scream" if p.vy < -650 else ("fall" if p.vy < -130 else "n"))
		elif absf(p.vx) > 30: mood = "run"
		elif p.idle > 7: mood = "sleep"
		elif p.idle > 2.5: mood = "bored"
		var lx: float = -p.wall if p.wall else p.face * (1.0 if (absf(p.vx) > 20 or p.gr == null) else .4)
		var ly = clampf(-p.vy / 500, -1, 1)
		var sx = 1.0
		var sy2 = 1.0
		if p.land > 0:
			var k: float = p.land / .2
			sy2 = 1 - .38 * k; sx = 1 + .32 * k
		elif p.gr == null and p.hook == null:
			var k = minf(.2, absf(p.vy) / 3600)
			sy2 = 1 + k; sx = 1 - k * .7
		elif p.gr != null and absf(p.vx) > 30:
			sy2 = 1 + sin(G.t * 22) * .05; sx = 2 - sy2
		c.save(); c.translate(p.x, py - 12 + 12 * (1 - sy2)); c.scale(sx, sy2)
		K.drawCube(c, 0, 0, 24, mood, G.t, p.rot, sk, lx, ly, G.combo >= 5 and mood != "hurt" and mood != "sleep"); c.restore()
		if mood == "sleep":
			c.font = "12px Bungee"; c.fillStyle = "#ffffffcc"; c.textAlign = "center"
			for k in 2:
				var z = fmod(G.t * .5 + k * .5, 1.0)
				c.globalAlpha = 1 - z; c.fillText("z", p.x + 12 + z * 10, py - 30 - z * 22)
			c.globalAlpha = 1
		if mood == "run" and randf() < .25:
			G.parts.append({"x": p.x - p.face * 10, "y": p.y + 1, "vx": -p.face * 40, "vy": 30.0, "l": .3, "col": Ctx.css("#ffffff55")})
		if (mood == "scream" or mood == "fall") and randf() < .12:
			G.parts.append({"x": p.x + (-12 if randf() < .5 else 12), "y": p.y + 26, "vx": (randf() - .5) * 60, "vy": 80.0, "l": .4, "col": Ctx.css("#74c0fc")})
		if mood == "wall" and randf() < .4:
			G.parts.append({"x": p.x - p.wall * 12, "y": p.y + 4, "vx": p.wall * -20.0, "vy": 40.0, "l": .25, "col": Ctx.css("#ffd43b")})
	if G.warp != null:
		var f = maxf(0, 1 - absf(G.warp.t - 1.3) * 3.2)
		if f > 0:
			c.fillStyle = Color(1, 1, 1, f); c.fillRect(-20, -20, W + 40, VH + 40)
	if G.warp == null and pw.shield:
		c.strokeStyle = "#74c0fc"; c.lineWidth = 2; c.globalAlpha = .6 + sin(G.t * 6) * .2; c.beginPath(); c.arc(p.x, py - 12, 22, 0, 7); c.stroke(); c.globalAlpha = 1
	for q in G.parts:
		c.globalAlpha = maxf(0, q.l); c.fillStyle = q.col; c.fillRect(q.x - 2, sy(q.y) - 2, 4, 4)
	c.globalAlpha = 1
	draw_hazard(th, p)
	draw_amb(th, stl.amb, adt, dc)
	var vg2 = c.createRadialGradient(W / 2, VH * .45, VH * .3, W / 2, VH * .45, VH * .85); vg2.addColorStop(0, "rgba(0,0,0,0)"); vg2.addColorStop(1, "rgba(0,0,0,.45)")
	_vignette(vg2)
	if G.eat != null:
		var E = G.eat
		var py2 = sy(E.y) - 12
		var st = -90.0 if E.dir > 0 else W + 90
		var tg: float = p.x - E.dir * 30
		var mx: float
		var op: float
		if E.t < .45:
			var k = 1 - pow(1 - E.t / .45, 3)
			mx = st + (tg - st) * k; op = 1
		elif E.t < .6:
			mx = tg; op = maxf(0, 1 - (E.t - .45) / .1)
		else:
			var k = minf(1, (E.t - .75) / .8)
			mx = tg + (st - tg) * maxf(0, k); op = 0
		K.drawEater(c, mx, py2, E.dir, op, G.t, E.t > .5)
		if E.t > .5 and E.t < .75:
			for k in 2:
				G.parts.append({"x": p.x, "y": E.y + 12, "vx": (randf() - .5) * 200, "vy": randf() * 150, "l": .5, "col": Ctx.css("#9775fa")})
	# testi
	c.textAlign = "center"; c.textBaseline = "middle"
	for f in G.fx:
		c.globalAlpha = minf(1, f.l * 2); c.font = "%dpx Bungee" % f.size; c.lineWidth = 4; c.strokeStyle = "#000"
		var y = sy(f.y)
		c.strokeText(f.txt, f.x, y); c.fillStyle = f.col; c.fillText(f.txt, f.x, y)
	c.globalAlpha = 1
	if G.combo >= 2:
		var s: float = 1 + G.comboPop * 1.5
		c.save(); c.translate(W / 2, 118); c.scale(s, s); c.font = "30px Bungee"; c.lineWidth = 6; c.strokeStyle = "#000"; c.strokeText("x%d" % G.combo, 0, 0)
		c.fillStyle = "#ffd43b" if G.combo >= 5 else "#2ee6c5"; c.fillText("x%d" % G.combo, 0, 0); c.font = "10px Bungee"; c.fillStyle = "#fff"; c.fillText("COMBO", 0, 22); c.restore()
	c.textBaseline = "alphabetic"
	# feedback del dito
	for o in main.T.values():
		if o.m == "move":
			c.strokeStyle = "#ffffff44"; c.lineWidth = 2; c.beginPath(); c.arc(o.ax, o.y, 32, 0, 7); c.stroke()
			c.fillStyle = "#2ee6c599"; c.beginPath(); c.arc(o.ax + clampf(o.x - o.ax, -30, 30), o.y, 14, 0, 7); c.fill()
		elif o.m == "?" or o.m == "hold":
			var k = minf(1, (Time.get_ticks_msec() - o.t0) / 150.0)
			c.strokeStyle = ("#2ee6c5" if p.hook != null else "#ffffff66") if o.m == "hold" else "#ffffff55"; c.lineWidth = 3
			c.beginPath(); c.arc(o.x, o.y, 24, -PI / 2, -PI / 2 + k * PI * 2); c.stroke()

func _vignette(g) -> void:
	# vignetta radiale: anelli concentrici (economico)
	c.fillStyle = g
	c.fillRect(-10, -10, W + 20, VH + 20)

func draw_portal(th: Array, p, sk) -> void:
	var po = G.portal
	var pyy = sy(po.y)
	var pOpen = portal_open()
	if not pOpen and pyy > -80 and pyy < VH + 80:
		c.save(); c.translate(po.x, pyy); c.rotate(G.t * .3); c.strokeStyle = "#5c5f66"; c.lineWidth = 5; c.setLineDash([10, 8]); c.beginPath(); c.arc(0, 0, 40, 0, 7); c.stroke(); c.setLineDash([]); c.restore()
		K.circ(c, po.x, pyy, 30, "rgba(20,16,30,.88)"); c.fillStyle = "#fcc419"; c.fillRect(po.x - 9, pyy - 3, 18, 14)
		c.strokeStyle = "#fcc419"; c.lineWidth = 3; c.beginPath(); c.arc(po.x, pyy - 3, 6, PI, 0); c.stroke()
	if pOpen and pyy > -260 and pyy < VH + 200:
		var near = maxf(0, 1 - Vector2(p.x - po.x, (p.y + 12) - po.y).length() / 260)
		var T: float = G.t
		c.save(); c.globalCompositeOperation = "lighter"
		var bw = 34 + near * 24
		var bg = c.createLinearGradient(0, pyy, 0, pyy - VH); bg.addColorStop(0, K.rgba(th[5], .22 + near * .2)); bg.addColorStop(1, K.rgba(th[5], 0))
		c.fillStyle = bg; c.fillRect(po.x - bw / 2, pyy - VH, bw, VH)
		var R1 = 78 + sin(T * 2.2) * 7 + near * 34
		var hg = c.createRadialGradient(po.x, pyy, 8, po.x, pyy, R1); hg.addColorStop(0, K.rgba(th[5], .5 + near * .3)); hg.addColorStop(.5, K.rgba(th[4], .22 + near * .15)); hg.addColorStop(1, K.rgba(th[4], 0))
		c.fillStyle = hg; c.fillRect(po.x - R1, pyy - R1, R1 * 2, R1 * 2)
		for a in 5:
			c.strokeStyle = K.rgba(th[5] if a % 2 else "#ffffff", .22 + near * .25); c.lineWidth = 2.5; c.beginPath()
			var s2 = 0.0
			while s2 < 1:
				var an = T * (2.2 + near * 4) + a * PI * 2 / 5 + s2 * 5.2
				var r = 12 + s2 * (62 + near * 20)
				c.lineTo(po.x + cos(an) * r, pyy + sin(an) * r * .92)
				s2 += .04
			c.stroke()
		for k in 12:
			var an = -T * (1.3 + near * 2) + k * .5236
			var r = 52 + sin(T * 3 + k) * 6 + near * 10
			K.circ(c, po.x + cos(an) * r, pyy + sin(an) * r, 1.6 + (0.0 if (k % 3) else 1.0), "#ffffff")
		var gyy = sy(G.goal)
		var gg = c.createRadialGradient(po.x, gyy, 0, po.x, gyy, 110); gg.addColorStop(0, K.rgba(th[5], .35)); gg.addColorStop(1, K.rgba(th[5], 0))
		c.fillStyle = gg; c.fillRect(po.x - 110, gyy - 60, 220, 80)
		c.restore()
	if pOpen and pyy > -80 and pyy < VH + 80:
		c.save(); c.translate(po.x, pyy)
		for k in 3:
			c.rotate(G.t * (-1 if k % 2 else 1) * .8); c.strokeStyle = th[5] if k else "#fff"; c.lineWidth = 3 if k else 5; c.shadowColor = th[4]; c.shadowBlur = 20; c.setLineDash([22, 10])
			c.beginPath(); c.arc(0, 0, 44 - k * 8, 0, 7); c.stroke()
		c.setLineDash([])
		var rg = c.createRadialGradient(0, 0, 2, 0, 0, 32); rg.addColorStop(0, "#fff"); rg.addColorStop(.4, th[4]); rg.addColorStop(1, "#000")
		c.fillStyle = rg; c.beginPath(); c.arc(0, 0, 30, 0, 7); c.fill(); c.restore(); c.shadowBlur = 0
	if G.warp != null:
		var w = G.warp
		var k = minf(1, w.t / 1.2)
		var px: float = po.x
		var ppy = sy(po.y)
		c.save(); c.translate(px, ppy); c.rotate(G.t * 2)
		for j in 14:
			c.rotate(PI * 2 / 14)
			var L = 60 + k * 420
			var lg = c.createLinearGradient(0, 0, L, 0); lg.addColorStop(0, "#ffffffcc"); lg.addColorStop(1, "#fff0")
			c.fillStyle = lg; c.beginPath(); c.moveTo(0, 0); c.lineTo(L, -6 - k * 10); c.lineTo(L, 6 + k * 10); c.fill()
		c.restore()
		for j in 3:
			var rr = fmod(w.t * 320 + j * 90, 360.0)
			c.strokeStyle = G.th[5]; c.globalAlpha = maxf(0, 1 - rr / 360); c.lineWidth = 4; c.beginPath(); c.arc(px, ppy, 40 + rr, 0, 7); c.stroke()
		c.globalAlpha = 1
		var gl = c.createRadialGradient(px, ppy, 0, px, ppy, 60 + k * 160); gl.addColorStop(0, "#ffffffee"); gl.addColorStop(.4, K.ha(G.th[4], "aa")); gl.addColorStop(1, "#0000")
		c.fillStyle = gl; c.beginPath(); c.arc(px, ppy, 60 + k * 160, 0, 7); c.fill()
		if k < 1:
			var e = pow(1 - k, 1.5)
			var a: float = w.a0 + k * 14
			K.drawCube(c, px + cos(a) * w.r0 * e, ppy - sin(a) * w.r0 * e, 24 * maxf(.08, 1 - k * .92), "love", G.t, k * 22, sk)

func draw_hazard(th: Array, p) -> void:
	var ly = sy(G.lava)
	if ly < VH + 40:
		var lg = c.createLinearGradient(0, ly, 0, ly + 120); lg.addColorStop(0, th[4]); lg.addColorStop(1, th[3])
		c.fillStyle = lg; c.beginPath(); c.moveTo(-10, VH + 20)
		var x = -10.0
		while x <= W + 10:
			c.lineTo(x, ly + sin(x * .05 + G.t * 3) * 5 + sin(x * .13 - G.t * 2) * 3)
			x += 10
		c.lineTo(W + 10, VH + 20); c.fill()
		c.strokeStyle = th[5]; c.lineWidth = 3; c.shadowColor = th[4]; c.shadowBlur = 16; c.beginPath()
		x = -10.0
		while x <= W + 10:
			c.lineTo(x, ly + sin(x * .05 + G.t * 3) * 5 + sin(x * .13 - G.t * 2) * 3)
			x += 10
		c.stroke(); c.shadowBlur = 0
		for k in 6:
			var bx = fmod(k * 67 + G.t * 20, W)
			var by = ly + 20 + fmod(G.t * 30 + k * 40, 90.0)
			c.fillStyle = K.ha(th[5], "66"); c.beginPath(); c.arc(bx, by, 3 + k % 3, 0, 7); c.fill()
		if ly > 20 and ly < VH:
			c.font = "10px Bungee"; c.fillStyle = th[5]; c.textAlign = "left"; c.fillText("▲ " + str(D.J.HAZ[G.i]), WALL + 6, ly + 18)
	if ly < VH + 240:
		c.globalCompositeOperation = "lighter"
		var hl = c.createLinearGradient(0, ly - 240, 0, ly); hl.addColorStop(0, K.rgba(th[4], 0)); hl.addColorStop(1, K.rgba(th[4], .3))
		c.fillStyle = hl; c.fillRect(0, ly - 240, W, 240); c.globalCompositeOperation = "source-over"
	var gp: float = p.y - G.lava
	if gp < 260:
		var a = minf(.55, (260 - gp) / 260 * .55)
		var vg = c.createLinearGradient(0, VH * .55, 0, VH); vg.addColorStop(0, "#0000"); vg.addColorStop(1, Color(1, 40 / 255.0, 40 / 255.0, a))
		c.fillStyle = vg; c.fillRect(0, VH * .55, W, VH * .45)

# ------------------ sfondo ------------------
func draw_backdrop(th: Array, st: Dictionary, art: Dictionary) -> void:
	var R: Dictionary = D.RW[G.i]
	var adt = minf(.05, maxf(0, G.t - (G.pxT if G.pxT != null else G.t)))
	G.pxT = G.t
	G.px += ((G.pl.x - W / 2) - G.px) * minf(1, adt * 2.5)
	var px: float = G.px
	var meta: Dictionary = art.meta
	var BH: float = meta.BH
	var y0 = VH - BH + G.cam * .15
	var ox = -W * .05 - px * .07
	c.drawImage(art.far, ox, y0, W * 1.1, BH)
	var CL: Texture2D = art.clouds
	var cy: float = y0 + art.clouds_y0
	var cx = -fmod(G.t * 7, W) - px * .09
	if cy < VH and cy + CL.get_height() > 0:
		var xx = cx - W
		while xx < W + W:
			c.drawImage(CL, xx, cy, W, CL.get_height())
			xx += W
	draw_far_anim(art, y0, ox)
	if R.has("aurora"):
		c.globalCompositeOperation = "lighter"
		for j in 3:
			c.strokeStyle = K.rgba("#69db7c" if j % 2 else "#22d3ee", .07); c.lineWidth = 46 - j * 10; c.beginPath()
			var x = -20.0
			while x <= W + 20:
				c.lineTo(x, VH * (.14 + j * .1) + sin(x * .012 + G.t * .6 + j) * 30)
				x += 20
			c.stroke()
		c.globalCompositeOperation = "source-over"
	draw_fog(art, .2, .2, 4)
	c.save(); c.translate(-px * .12, 0); _tile(art.mid, .32); c.restore()
	draw_fog(art, .45, .16, 9)
	c.save(); c.translate(-px * .22, 0); _tile(art.near, .58); c.restore()
	c.globalCompositeOperation = "lighter"
	for b in G.beams:
		c.fillStyle = Color(1, 1, 1, b.a * .5); c.beginPath(); c.moveTo(b.x, 0); c.lineTo(b.x + b.w, 0); c.lineTo(b.x + b.w - 160, VH); c.lineTo(b.x - 160, VH); c.fill()
	c.globalCompositeOperation = "source-over"
	if G.flash > 0:
		c.fillStyle = Color(220 / 255.0, 235 / 255.0, 1, G.flash * .35); c.fillRect(-10, -10, W + 20, VH + 20)

func _tile(L: Texture2D, f: float) -> void:
	var o = fposmod(G.cam * f, TH)
	var yy = o - TH
	while yy < VH:
		c.drawImage(L, 0, yy, W, TH)
		yy += TH

func draw_fog(art: Dictionary, f: float, a: float, sp: float) -> void:
	var F: Texture2D = art.fog
	var fh = 420.0
	var oy = fposmod(G.cam * f, fh)
	var ox = -fmod(G.t * sp, W)
	c.globalAlpha = a
	var yy = oy - fh
	while yy < VH:
		var xx = ox
		while xx < W:
			c.drawImage(F, xx, yy, W, fh)
			xx += W
		yy += fh
	c.globalAlpha = 1

func draw_far_anim(art: Dictionary, y0: float, ox: float) -> void:
	var R: Dictionary = D.RW[G.i]
	var F: Dictionary = art.meta
	var t: float = G.t
	var X = func(x: float) -> float: return ox + x * 1.1
	if R.has("night"):
		for s in F.tw:
			var y: float = y0 + s.y
			if y < -4 or y > VH:
				continue
			var a = maxf(0, sin(t * s.f + s.ph))
			if a < .3:
				continue
			c.fillStyle = Color(1, 1, 1, a * .9); c.fillRect(X.call(s.x), y, s.s, s.s)
			if a > .9 and s.s > 1.5:
				c.fillRect(X.call(s.x) - 3, y + .5, 7, .6); c.fillRect(X.call(s.x) + .5, y - 3, .6, 7)
	if not R.has("night") and R.land != "seabed":
		var sx: float = X.call(F.sun.x)
		var syy: float = y0 + F.sun.y
		if syy > -600 and syy < VH + 600:
			c.save(); c.globalCompositeOperation = "lighter"; c.translate(sx, syy); c.rotate(t * .035)
			for k in 9:
				c.rotate(PI * 2 / 9); c.fillStyle = K.rgba(R.sun, .03 + .015 * sin(t * .7 + k)); c.beginPath(); c.moveTo(0, 0); c.lineTo(900, -34 - k * 4); c.lineTo(900, 34 + k * 4); c.fill()
			c.restore()
	for v in F.vents:
		var vx: float = X.call(v.x)
		var vy: float = y0 + v.y
		if vy < -260 or vy > VH + 120:
			continue
		c.save(); c.globalCompositeOperation = "lighter"
		var pu = 1 + sin(t * 2.3) * .18
		var g = c.createRadialGradient(vx, vy, 0, vx, vy, 70 * pu); g.addColorStop(0, K.rgba(R.glow, .45)); g.addColorStop(1, K.rgba(R.glow, 0))
		c.fillStyle = g; c.fillRect(vx - 80, vy - 80, 160, 160); c.restore()
		for k in 9:
			var a = fmod(t * .09 + k / 9.0, 1.0)
			K.circ(c, vx + sin(k * 1.7 + t * .4) * 10 * a + a * 40, vy - 6 - a * 190, 8 + a * 42, K.rgba(K.mix(R.fog, "#2a2a2a", .4), (1 - a) * .32))
		if sin(t * 1.3 + v.x) > .97:
			for k in 3:
				K.circ(c, vx + (randf() - .5) * 20, vy - randf() * 30, 2, R.glow)
	for l in F.lights:
		var y: float = y0 + l.y
		if y < -4 or y > VH:
			continue
		if sin(t * l.f + l.ph) > -.2:
			c.fillStyle = l.col; c.shadowColor = l.col; c.shadowBlur = 4; c.fillRect(X.call(l.x), y, 2.2, 3); c.shadowBlur = 0
	var ly: float = y0 + F.LY
	if R.land == "seabed" and ly < VH + 400:
		c.save(); c.globalCompositeOperation = "lighter"; c.lineWidth = 1.4
		for k in 14:
			c.strokeStyle = Color(158 / 255.0, 231 / 255.0, 1, .05 + .04 * sin(t * 1.5 + k)); c.beginPath()
			var yy = ly + 40 + k * 30
			var x = -10.0
			while x <= W + 10:
				c.lineTo(x, yy + sin(x * .05 + t * 1.6 + k * 1.3) * 6)
				x += 12
			c.stroke()
		c.restore()
	if R.land == "cloudsea" and ly < VH + 300:
		for k in 7:
			var x = fmod(k * 97 + t * (9 + k * 2), W + 260) - 130
			c.globalAlpha = .55
			K.cloud(c, x, ly + 250 + (k % 3) * 40 + sin(t * .5 + k) * 6, 46 + (k % 3) * 14, {"cloud": "#ffffff"})
			c.globalAlpha = 1
	if (R.land == "dunes" or R.land == "mesa") and ly < VH + 300:
		c.strokeStyle = "rgba(255,230,180,.12)"; c.lineWidth = 1.2
		for k in 16:
			var x = fmod(k * 53 + t * (70 + k * 9), W + 200) - 100
			var yy = ly + 180 + (k * 37) % 260
			c.beginPath(); c.moveTo(x, yy); c.quadraticCurveTo(x + 30, yy - 4, x + 70, yy + 2); c.stroke()
	if R.land == "spires" and ly < VH + 300:
		for k in 5:
			var a = maxf(0, sin(t * 1.7 + k * 1.3))
			if a > .5:
				c.save(); c.globalCompositeOperation = "lighter"
				var x: float = X.call(30 + k * 75)
				var yy = ly + 90 + (k % 2) * 40
				var g = c.createRadialGradient(x, yy, 0, x, yy, 40); g.addColorStop(0, Color(1, 43 / 255.0, 43 / 255.0, (a - .5) * .7)); g.addColorStop(1, "rgba(255,43,43,0)")
				c.fillStyle = g; c.fillRect(x - 40, yy - 40, 80, 80); c.restore()

func draw_walls(art: Dictionary) -> void:
	var o = fposmod(G.cam, WT)
	var yy = o - WT
	while yy < VH:
		c.drawImage(art.wall, 0, yy, WALL, WT)
		c.save(); c.translate(W, 0); c.scale(-1, 1); c.drawImage(art.wall, 0, yy, WALL, WT); c.restore()
		yy += WT

func draw_amb(th: Array, type: String, dt: float, dc: float) -> void:
	c.save()
	for a in G.amb:
		a.y += dc * a.d
		match type:
			"ember": a.y -= a.v * dt; a.x += sin(G.t * 2 + a.ph) * 10 * dt
			"snow", "ash": a.y += a.v * .6 * dt; a.x += sin(G.t + a.ph) * 15 * dt
			"firefly", "dust", "spore": a.x += sin(G.t * .7 + a.ph) * 12 * dt; a.y += cos(G.t * .5 + a.ph * 2) * 10 * dt - (8 * dt if type == "spore" else 0.0)
			"sand": a.x += a.v * 2.2 * dt; a.y += sin(G.t + a.ph) * 6 * dt
			"bubble": a.y -= a.v * .8 * dt; a.x += sin(G.t * 3 + a.ph) * 12 * dt
			"puff", "mist": a.x += a.v * .3 * dt
			"sprinkle", "leaf", "petal": a.y += a.v * .7 * dt; a.x += sin(G.t * 1.5 + a.ph) * 30 * dt
			"spark": a.y += a.v * 3 * dt; a.x += a.vx * dt
			"rain": a.y += a.v * 12 * dt; a.x -= a.v * 3 * dt
			"glitch":
				if randf() < dt * 2:
					a.x = randf() * W; a.y = randf() * VH
		if a.y < -30:
			a.y = VH + 30; a.x = randf() * W
		elif a.y > VH + 30:
			a.y = -30.0; a.x = randf() * W
		if a.x < -40: a.x = W + 40
		elif a.x > W + 40: a.x = -40.0
		var tw = .4 + .6 * absf(sin(G.t * 2 + a.ph))
		match type:
			"sparkle":
				c.globalAlpha = tw * .8; c.fillStyle = th[5]; c.fillRect(a.x - a.s * 1.5, a.y - .5, a.s * 3, 1); c.fillRect(a.x - .5, a.y - a.s * 1.5, 1, a.s * 3)
			"star":
				c.globalAlpha = tw; c.fillStyle = "#ffffff"; c.fillRect(a.x, a.y, 1.4, 1.4)
			"ember":
				c.globalCompositeOperation = "lighter"; c.globalAlpha = tw; K.circ(c, a.x, a.y, a.s * .8, "#ffd43b" if a.ph > 3.5 else "#ff6b1a"); c.globalCompositeOperation = "source-over"
			"snow":
				c.globalAlpha = .75; K.circ(c, a.x, a.y, a.s * .8, "#ffffff")
			"ash":
				c.globalAlpha = .5; c.fillStyle = "#868e96"; c.fillRect(a.x, a.y, a.s, a.s)
			"firefly":
				c.globalCompositeOperation = "lighter"
				var b = maxf(0, sin(G.t * 2.5 + a.ph))
				var g = c.createRadialGradient(a.x, a.y, 0, a.x, a.y, 7); g.addColorStop(0, Color(220 / 255.0, 1, 120 / 255.0, b)); g.addColorStop(1, "rgba(220,255,120,0)")
				c.fillStyle = g; c.fillRect(a.x - 7, a.y - 7, 14, 14); c.globalCompositeOperation = "source-over"
			"dust":
				c.globalAlpha = .45 * tw; K.circ(c, a.x, a.y, a.s * .6, "#ffe8a3")
			"spore":
				c.globalCompositeOperation = "lighter"; c.globalAlpha = .6 * tw; K.circ(c, a.x, a.y, a.s * .7, th[6]); c.globalCompositeOperation = "source-over"
			"sand":
				c.globalAlpha = .45; c.fillStyle = "#f5d08a"; c.fillRect(a.x, a.y, a.s * 3, 1)
			"bubble":
				c.globalAlpha = .4; c.strokeStyle = "#d0ebff"; c.lineWidth = 1; c.beginPath(); c.arc(a.x, a.y, a.s * 1.4, 0, 7); c.stroke(); c.fillStyle = "#ffffff"; c.fillRect(a.x - a.s * .6, a.y - a.s * .6, 1.2, 1.2)
			"puff":
				c.globalAlpha = .06; K.circ(c, a.x, a.y, 30 + a.s * 12, "#ffffff")
			"mist":
				c.globalAlpha = .07; c.fillStyle = "#ced4da"; c.beginPath(); c.ellipse(a.x, a.y, 70 + a.s * 15, 16 + a.s * 3, 0, 0, 7); c.fill()
			"sprinkle":
				c.globalAlpha = .85; c.save(); c.translate(a.x, a.y); c.rotate(a.ph + G.t); c.fillStyle = K.hsl(a.h, 85, 65); c.fillRect(-2.5, -1, 5, 2); c.restore()
			"leaf", "petal":
				c.globalAlpha = .85; c.save(); c.translate(a.x, a.y); c.rotate(G.t * 2 + a.ph)
				c.fillStyle = ("#fd7e14" if a.h < 120 else ("#fa5252" if a.h < 240 else "#fcc419")) if type == "leaf" else "#fcc2d7"
				c.beginPath(); c.ellipse(0, 0, a.s + 2, a.s * .6 + 1, 0, 0, 7); c.fill(); c.restore()
			"spark":
				c.globalAlpha = .9; c.strokeStyle = "#ffd43b"; c.lineWidth = 1.2; c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(a.x - a.vx * .05, a.y - 6); c.stroke()
			"rain":
				c.globalAlpha = .3; c.strokeStyle = "#a5d8ff"; c.lineWidth = 1; c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(a.x + 4, a.y - 14); c.stroke()
			"glitch":
				if randf() < .5:
					c.globalAlpha = .5; c.fillStyle = "#22d3ee" if a.ph > 3.5 else "#ff3df5"; c.fillRect(a.x, a.y, 4 + a.s * 4, 2)
	c.restore(); c.globalAlpha = 1; c.globalCompositeOperation = "source-over"

# ------------------ scenari animati ------------------
func bgY(o) -> float:
	return VH - (o.y - G.cam * .4)

func add_light(x: float, y: float, rad: float, col: Color, a: float) -> void:
	G.lights.append({"x": x, "y": y, "r": rad, "col": col, "a": a})

func draw_scenery_bg(th: Array) -> void:
	var t: float = G.t
	for o in G.scen:
		if not o.bg:
			continue
		var y = bgY(o)
		if y < -90 or y > VH + 90:
			continue
		match o.t:
			"fish":
				for k in 6:
					var x = fposmod(o.ph * 80 + t * 28 * o.dir + k * 16, W + 160) - 80
					var yy = y + sin(t * 2 + k) * 6 + (k % 2) * 10
					c.save(); c.translate(x, yy); c.scale(o.dir, 1); c.fillStyle = K.rgba(th[6], .55); c.beginPath(); c.ellipse(0, 0, 6, 3, 0, 0, 7); c.fill(); K.poly(c, [-5, 0, -10, -3, -10, 3], K.rgba(th[6], .55)); c.restore()
			"jelly":
				var yy = y + sin(t * .8 + o.ph) * 14
				var x: float = o.x + sin(t * .4 + o.ph) * 10
				var p = 1 + sin(t * 3 + o.ph) * .08
				c.save(); c.globalCompositeOperation = "lighter"
				var g = c.createRadialGradient(x, yy, 0, x, yy, 26); g.addColorStop(0, "rgba(255,140,240,.35)"); g.addColorStop(1, "rgba(255,140,240,0)")
				c.fillStyle = g; c.fillRect(x - 26, yy - 26, 52, 52); c.restore()
				c.fillStyle = "rgba(255,170,240,.55)"; c.beginPath(); c.ellipse(x, yy, 10 * p, 7 / p, 0, PI, 0); c.fill()
				c.strokeStyle = "rgba(255,170,240,.45)"; c.lineWidth = 1.2
				for k in range(-2, 3):
					c.beginPath(); c.moveTo(x + k * 3.5, yy); c.quadraticCurveTo(x + k * 3.5 + sin(t * 3 + k) * 4, yy + 10, x + k * 3, yy + 20); c.stroke()
			"cloud":
				var x = fmod(o.ph * 60 + t * o.sp, W + 200) - 100
				c.globalAlpha = .45; K.cloud(c, x, y, o.s, {"cloud": K.mix(th[3], "#ffffff", .55)}); c.globalAlpha = 1
			"gear":
				c.save(); c.translate(o.x, y); c.rotate(t * .5 * o.dir)
				var gc = K.rgba(K.mix(th[3], th[4], .5), .7)
				c.fillStyle = gc
				for k in 10:
					c.rotate(PI / 5); c.fillRect(-o.s * .07, -o.s * .52, o.s * .14, o.s * .16)
				K.circ(c, 0, 0, o.s * .4, gc); K.circ(c, 0, 0, o.s * .14, K.rgba(th[3], .9)); c.restore()
			"sign":
				var on = sin(t * 7 + o.ph) > -.85 or randf() < .5
				var col = K.hsl(o.hue, 100, 62)
				if on:
					c.save(); c.shadowColor = col; c.shadowBlur = 10; c.strokeStyle = col; c.lineWidth = 1.5; c.strokeRect(o.x, y, o.w, o.h); c.fillStyle = col
					var k = 4.0
					while k < o.w - 4:
						c.fillRect(o.x + k, y + o.h / 2 - 1, 3, 2)
						k += 6
					c.restore()
			"flock":
				for k in 5:
					var x = fposmod(o.ph * 70 + t * 22 * o.dir, W + 200) - 100 + (8 if k % 2 else 0) * o.dir - (k * 9) * o.dir
					var yy = y + absi(k - 2) * 7
					var f = sin(t * 9 + k) * 3
					c.strokeStyle = K.rgba(K.mix(th[3], "#000000", .5), .7); c.lineWidth = 1.5; c.beginPath(); c.moveTo(x - 5, yy - f); c.lineTo(x, yy); c.lineTo(x + 5, yy - f); c.stroke()
			"eyes":
				var bl = sin(t * .7 + o.ph)
				if bl > -.2:
					var h = .6 if bl > .9 else 2.2
					c.fillStyle = "#ffd43b" if o.ph > 4.5 else "#ff3b3b"; c.shadowColor = c.fillStyle; c.shadowBlur = 6
					c.beginPath(); c.ellipse(o.x - 5, y, 2.6, h, 0, 0, 7); c.ellipse(o.x + 5, y, 2.6, h, 0, 0, 7); c.fill(); c.shadowBlur = 0
	var F: Array = D.J.SFEAT.get(str(G.i), [])
	if "shoot" in F:
		if G.shoot == null or G.shoot.l <= 0:
			if randf() < .008:
				G.shoot = {"x": 40 + randf() * 280, "y": 20 + randf() * VH * .4, "l": 1.0}
		else:
			var s = G.shoot
			s.l -= .03; s.x += 6; s.y += 3
			c.strokeStyle = Color(1, 1, 1, maxf(0, s.l)); c.lineWidth = 1.6; c.beginPath(); c.moveTo(s.x, s.y); c.lineTo(s.x - 40, s.y - 20); c.stroke()
	if "bolt" in F and G.flash > .55:
		if not G.boltX or G.flash > .95:
			G.boltX = 40 + randf() * 280
		c.strokeStyle = Color(220 / 255.0, 235 / 255.0, 1, G.flash); c.lineWidth = 2.5; c.shadowColor = "#a5d8ff"; c.shadowBlur = 14; c.beginPath()
		var x: float = G.boltX
		var y = 0.0
		c.moveTo(x, y)
		while y < VH * .6:
			x += (randf() - .5) * 36; y += 20 + randf() * 24
			c.lineTo(x, y)
		c.stroke(); c.shadowBlur = 0

func draw_scenery_wall(th: Array) -> void:
	var t: float = G.t
	for o in G.scen:
		if o.bg:
			continue
		var y = sy(o.y)
		if y < -260 or y > VH + 60:
			continue
		var wx = WALL if o.side < 0 else W - WALL
		var s = 1.0 if o.side < 0 else -1.0
		match o.t:
			"fall":
				var C: Array = FALLC[o.k]
				var w = 9.0
				var x0 = wx if o.side < 0 else wx - w
				var L: float = o.L
				var g = c.createLinearGradient(x0, 0, x0 + w, 0); g.addColorStop(0, C[0]); g.addColorStop(.5, C[1]); g.addColorStop(1, C[0])
				c.fillStyle = g; c.fillRect(x0, y, w, L)
				c.fillStyle = K.rgba(C[1], .8)
				for k in 6:
					var dy = fmod(t * 130 + k * L / 6 + o.ph * 20, L)
					c.fillRect(x0 + 2 + (k % 3) * 2, y + dy, 1.6, 10)
				for k in 4:
					var a = fmod(t * 2 + k / 4.0 + o.ph, 1.0)
					K.circ(c, x0 + w / 2 + s * a * 12 * (1.0 if k % 2 else .5), y + L - sin(a * PI) * 8, 2 * (1 - a), C[1])
				c.fillStyle = K.rgba(C[0], .5); c.beginPath(); c.ellipse(x0 + w / 2 + s * 4, y + L, 10, 3, 0, 0, 7); c.fill()
				if o.k == "lava": add_light(x0 + w / 2, y + L * .5, 90, Color8(255, 120, 40), .35)
				if o.k == "water": add_light(x0 + w / 2, y + L * .6, 50, Color8(160, 210, 255), .12)
			"vine":
				var sw = sin(t * 1.4 + o.ph) * 10
				var ex = wx + s * (12 + sw)
				var ey: float = y + o.L
				var col = VINEC.get(G.i, "#40c057")
				c.strokeStyle = K.mix(col, "#000000", .35); c.lineWidth = 2; c.beginPath(); c.moveTo(wx, y); c.quadraticCurveTo(wx + s * 24, y + o.L * .5, ex, ey); c.stroke()
				for k in range(1, 6):
					var q = k / 5.5
					var lx = (1 - q) * (1 - q) * wx + 2 * (1 - q) * q * (wx + s * 24) + q * q * ex
					var ly = (1 - q) * (1 - q) * y + 2 * (1 - q) * q * (y + o.L * .5) + q * q * ey
					c.fillStyle = col if k % 2 else K.mix(col, "#ffffff", .25); c.beginPath(); c.ellipse(lx + s * 3, ly, 4, 2.2, s * .6 + sin(t * 2 + k) * .2, 0, 7); c.fill()
			"torch":
				var x = wx + s * 7
				var fl = 1 + sin(t * 18 + o.ph) * .12 + randf() * .08
				var red: bool = G.i == 21
				c.fillStyle = "#3d3d44"; c.fillRect(wx if o.side < 0 else wx - 8, y + 4, 8, 3); c.fillStyle = "#6b4423"; c.fillRect(x - 2, y - 2, 4, 10)
				c.save(); c.translate(x, y - 3); c.scale(fl, fl)
				var g = c.createRadialGradient(0, -3, 0, 0, -3, 8); g.addColorStop(0, "#fff7d6"); g.addColorStop(.4, "#ff6b6b" if red else "#ffd43b"); g.addColorStop(1, "rgba(200,20,40,0)" if red else "rgba(255,120,20,0)")
				c.fillStyle = g; c.beginPath(); c.moveTo(0, -12); c.quadraticCurveTo(6, -3, 0, 3); c.quadraticCurveTo(-6, -3, 0, -12); c.fill(); c.restore()
				add_light(x, y - 4, 110 * fl, Color8(255, 60, 60) if red else Color8(255, 170, 70), .42)
			"gcry":
				var pu = .6 + .4 * sin(t * 2 + o.ph)
				var col = th[6]
				for k in 3:
					c.save(); c.translate(wx, y + k * 7); c.rotate(s * (.5 + k * .35)); c.fillStyle = K.mix(col, "#ffffff", .4) if k == 1 else col; c.globalAlpha = .75 + pu * .25
					c.beginPath(); c.moveTo(0, -3); c.lineTo(s * (12 + k * 4), -1); c.lineTo(0, 3); c.fill(); c.restore()
				c.globalAlpha = 1
				add_light(wx + s * 8, y + 7, 70, Ctx.css(col), .3 * pu)
			"mush":
				var pu = .6 + .4 * sin(t * 1.6 + o.ph)
				var col = th[6]
				for k in 2:
					var yy = y + k * 12
					c.fillStyle = K.mix(col, "#ffffff", .15 * k); c.beginPath(); c.ellipse(wx + s * 8, yy, 9 - k * 2, 3.5, 0, PI, 0); c.fill()
					K.circ(c, wx + s * (6 + k * 3), yy - 2, 1, "#ffffffcc")
				add_light(wx + s * 8, y + 4, 65, Ctx.css(col), .32 * pu)
			"lantern":
				var sw = sin(t * 1.3 + o.ph) * .15
				var ax = wx + s * 4
				var lx = ax + s * 26 + sin(sw) * 20
				var ly = y + 22
				c.strokeStyle = "#5c3d2e"; c.lineWidth = 1.2; c.beginPath(); c.moveTo(ax, y); c.lineTo(lx, ly - 9); c.stroke()
				c.fillStyle = "#e03131"; c.beginPath(); c.ellipse(lx, ly, 7, 9, 0, 0, 7); c.fill(); c.fillStyle = "#ffd43b"; c.fillRect(lx - 4, ly - 10, 8, 2); c.fillRect(lx - 4, ly + 8, 8, 2)
				c.fillStyle = "#ffa8a8"; c.fillRect(lx - 1, ly - 7, 2, 14)
				add_light(lx, ly, 80, Color8(255, 90, 70), .32)

func draw_dark() -> void:
	c.fillStyle = Color(5 / 255.0, 3 / 255.0, 14 / 255.0, float(D.J.SDARK[G.i])); c.fillRect(-10, -10, W + 20, VH + 20)

func draw_lights(th: Array) -> void:
	var p = G.pl
	var py = sy(p.y) - 12
	c.save(); c.globalCompositeOperation = "lighter"
	var L: Array = G.lights
	L.append({"x": p.x, "y": py, "r": 130.0, "col": Color8(255, 205, 150), "a": .3})
	var po = G.portal
	var ppy = sy(po.y)
	if ppy > -120 and ppy < VH + 120:
		L.append({"x": po.x, "y": ppy, "r": 150.0, "col": Ctx.css(th[5]), "a": .35 if portal_open() else .08})
	for a in G.A:
		var y = sy(a.y)
		if y > -40 and y < VH + 40:
			L.append({"x": a.x, "y": y, "r": 42.0, "col": Color8(34, 211, 238), "a": .18})
	for l in L:
		if l.y < -l.r or l.y > VH + l.r:
			continue
		var c0: Color = l.col
		var g = c.createRadialGradient(l.x, l.y, 0, l.x, l.y, l.r); g.addColorStop(0, Color(c0.r, c0.g, c0.b, l.a)); g.addColorStop(1, Color(c0.r, c0.g, c0.b, 0))
		c.fillStyle = g; c.fillRect(l.x - l.r, l.y - l.r, l.r * 2, l.r * 2)
	c.restore()
	G.lights = []

# ------------------ piattaforme ------------------
func draw_plat(q, x: float, y: float, th: Array, m: String, t: float) -> void:
	var R: Dictionary = D.RW[G.i]
	if q.floor or R.pt == "neon" or R.pt == "rainbow" or R.pt == "mush":
		draw_plat_old(q, x, y, th, m, t)
		return
	var w: float = q.w
	var sd: float = q.sd
	var T: Texture2D = G.art.ptex
	var S2: float = T.get_width() / 640.0
	c.save(); c.shadowColor = "rgba(0,0,0,.55)"; c.shadowBlur = 12; c.shadowOffsetX = 6; c.shadowOffsetY = 10; c.fillStyle = "rgba(0,0,0,.35)"
	c.beginPath(); c.roundRect(x, y - 1, w, 14, 4); c.fill(); c.restore()
	c.beginPath(); c.roundRect(x, y - 1, w, 14, 4)
	c.fillTex(T, x, y - 1, w, 14, Rect2(floor(sd * (640 - w - 2)) * S2, 0, w * S2, T.get_height()))
	var fg = c.createLinearGradient(0, y - 1, 0, y + 13); fg.addColorStop(0, "rgba(255,255,255,.25)"); fg.addColorStop(.22, "rgba(255,255,255,0)"); fg.addColorStop(1, "rgba(0,0,0,.42)")
	c.fillStyle = fg; c.fill()
	c.strokeStyle = "rgba(0,0,0,.5)"; c.lineWidth = 1; c.beginPath(); c.roundRect(x + .5, y - .5, w - 1, 13, 4); c.stroke()
	if R.get("top") != null:
		var TC: Array = Bake.TOPC[R.top]
		c.fillStyle = TC[1]; c.beginPath(); c.moveTo(x + 1, y + 2)
		var k = 0.0
		while k <= w:
			c.lineTo(x + minf(k, w - 1), y - 1 - ((sin(k * 1.7 + sd * 20) * .5 + .5) * (3.0 if R.top == "grass" else 2.0)))
			k += 4
		c.lineTo(x + w - 1, y + 2); c.closePath(); c.fill(); c.fillStyle = TC[0]; c.fillRect(x + 2, y + 1.5, w - 4, 1.4)
		if R.top == "grass" or R.top == "moss":
			k = 3.0
			while k < w - 2:
				c.strokeStyle = TC[1] if int(k) % 8 else TC[0]; c.lineWidth = 1; c.beginPath(); c.moveTo(x + k, y); c.lineTo(x + k + sin(k + t * 2) * 1.2, y - 4 - fmod(k * sd * 7, 3.0)); c.stroke()
				k += 4
		if R.top == "snow":
			k = 6.0
			while k < w - 4:
				K.poly(c, [x + k - 2, y + 13, x + k + 2, y + 13, x + k, y + 17 + fmod(k * sd * 7, 6.0)], "#e9f3ff")
				k += 11
		if R.top == "moss":
			k = 5.0
			while k < w - 4:
				c.fillStyle = TC[0]; c.fillRect(x + k, y + 12, 1.6, 3 + fmod(k * sd * 5, 6.0))
				k += 9
	if R.pt == "ice":
		var k = 5.0
		while k < w - 4:
			K.poly(c, [x + k - 2.5, y + 13, x + k + 2.5, y + 13, x + k, y + 18 + fmod(k * sd * 7, 8.0)], "rgba(210,235,255,.9)")
			k += 9
	if R.pt == "basalt":
		var dp = fmod(t * .8 + sd * 3, 1.0)
		K.circ(c, x + w * sd, y + 13 + dp * 14, 2 * (1 - dp), R.glow); c.shadowColor = R.glow; c.shadowBlur = 8; c.fillStyle = K.rgba(R.glow, .8); c.fillRect(x + 3, y - 1, w - 6, 1.5); c.shadowBlur = 0
	if R.pt in ["crystal", "ice", "marble", "obsidian"]:
		var gx = x + fmod(sd * 997 + floor(t * .7 + sd * 5) * w * .37, w)
		var ga = maxf(0, sin(t * 2.2 + sd * 9))
		if ga > .2:
			c.fillStyle = Color(1, 1, 1, ga); c.fillRect(gx - 3, y - .5, 6, 1); c.fillRect(gx - .5, y - 3.5, 1, 6)
	if R.pt == "crystal":
		var k = 10.0
		while k < w - 6:
			K.poly(c, [x + k - 3, y, x + k, y - 6 - fmod(k * sd * 13, 5.0), x + k + 3, y], "#d9c2ff")
			k += 19
	if q.vx:
		for s2 in [-1, 1]:
			var ex = x - 6 if s2 < 0 else x + w + 6
			K.poly(c, [ex, y + 6, ex - s2 * 5, y + 2, ex - s2 * 5, y + 10], th[6])
	if q.top:
		c.fillStyle = "#fcc419"; c.fillRect(x + w / 2 - 1, y - 26, 2, 26); K.poly(c, [x + w / 2 + 1, y - 26, x + w / 2 + 22, y - 21, x + w / 2 + 1, y - 16], "#ffd43b")

func _R(a: float, b: float, cw: float, ch: float, f) -> void:
	c.fillStyle = f
	c.fillRect(a, b, cw, ch)

func _log(x: float, y: float, w: float, sd: float, body, leaf, n: int) -> void:
	_R(x, y, w, 10, body); K.circ(c, x, y + 5, 5, body); K.circ(c, x + w, y + 5, 5, body); K.circ(c, x + w, y + 5, 3, K.mix(body, "#000000", .3))
	var k = 6.0
	while k < w:
		_R(x + k, y + 2 + fmod(k * sd, 5.0), 5, 1.2, "#00000044")
		k += 9
	_R(x, y, w, 1.5, K.mix(body, "#ffffff", .25))
	if leaf != null:
		for kk in n:
			var lx: float = x + ((kk + .5) / n) * w + fmod(sd * 97 * kk, 10.0) - 5
			K.circ(c, lx, y - 1, 4, leaf[kk % leaf.size()]); K.circ(c, lx + 4, y + 1, 3, leaf[(kk + 1) % leaf.size()])

func draw_plat_old(q, x: float, y: float, th: Array, m: String, t: float) -> void:
	var w: float = q.w
	var sd: float = q.sd
	var H = VH if q.floor else 12.0
	c.save(); c.shadowColor = "rgba(0,0,0,.55)"; c.shadowBlur = 12; c.shadowOffsetX = 6; c.shadowOffsetY = 10; c.fillStyle = "rgba(0,0,0,.3)"; c.fillRect(x, y, w, 22 if q.floor else 12); c.restore()
	match m:
		"crystal":
			var g = c.createLinearGradient(0, y, 0, y + 12); g.addColorStop(0, th[5]); g.addColorStop(1, K.mix(th[4], "#000000", .45))
			c.fillStyle = g; c.beginPath(); c.moveTo(x, y); c.lineTo(x + w, y); c.lineTo(x + w - 6, y + 12); c.lineTo(x + 6, y + 12); c.fill()
			var k = 8.0
			while k < w - 8:
				K.poly(c, [x + k, y, x + k + 6, y, x + k + 2, y + 11], "#ffffff22"); k += 16
			k = 10.0
			while k < w - 6:
				K.poly(c, [x + k - 3, y, x + k, y - 6 - fmod(k * sd * 13, 5.0), x + k + 3, y], th[6]); k += 20
			_R(x, y, w, 1.5, "#ffffffbb")
		"lavarock":
			_R(x, y, w, H, "#2b1712"); c.strokeStyle = th[6]; c.lineWidth = 1.5; c.shadowColor = th[6]; c.shadowBlur = 6; c.beginPath()
			var k = 8.0
			while k < w - 6:
				c.moveTo(x + k, y + 1); c.lineTo(x + k + 3, y + 5); c.lineTo(x + k - 1, y + 10); k += 14
			c.stroke(); c.shadowBlur = 10; _R(x, y - 1, w, 3, K.mix(th[6], "#ffd43b", .3)); c.shadowBlur = 0
			var dp = fmod(t * .8 + sd * 3, 1.0)
			K.circ(c, x + w * sd, y + 12 + dp * 14, 2.2 * (1 - dp), th[6])
		"ice":
			var g = c.createLinearGradient(0, y, 0, y + 10); g.addColorStop(0, "#e7f5ff"); g.addColorStop(1, "#74c0fc"); c.fillStyle = g; c.fillRect(x, y, w, 10); _R(x, y, w, 2, "#ffffff")
			var k = 5.0
			while k < w - 4:
				K.poly(c, [x + k - 3, y + 10, x + k + 3, y + 10, x + k, y + 15 + fmod(k * sd * 7, 8.0)], "#d0ebff"); k += 9
			_R(x + 4, y + 3, w * .3, 1.5, "#ffffffaa")
		"branch": _log(x, y, w, sd, "#6b4423", ["#51cf66", "#2f9e44", "#8ce99a"], maxi(2, int(round(w / 22))))
		"branchA": _log(x, y, w, sd, "#6b4423", ["#fd7e14", "#fa5252", "#fcc419"], maxi(2, int(round(w / 22))))
		"sakura": _log(x, y, w, sd, "#5c3d2e", ["#f783ac", "#fcc2d7", "#ffdeeb"], maxi(2, int(round(w / 20))))
		"mossy":
			_log(x, y, w, sd, "#3d3320", null, 0)
			var k = 4.0
			while k < w:
				_R(x + k, y - 1, 7, 3, "#74b816"); _R(x + k + 2, y + 10, 2, 3 + fmod(k * sd * 5, 6.0), "#5c940d"); k += 11
		"sandstone":
			_R(x, y, w, H, "#d9a35a"); _R(x, y, w, 2, "#f5d08a")
			var k = 0.0
			while k < w:
				_R(x + k, y + 2, 1, 10, "#00000033"); k += 18
			_R(x, y + 6, w, 1, "#00000022")
		"coral":
			c.fillStyle = K.mix("#e64980", th[4], .3); c.beginPath(); c.roundRect(x, y, w, 11, 5); c.fill()
			var k = 6.0
			while k < w - 4:
				K.circ(c, x + k, y + 5 + fmod(k * sd, 3.0), 1.6, "#00000044"); k += 8
			k = 4.0
			while k < w:
				K.circ(c, x + k, y, 2.5, "#faa2c1"); k += 12
		"marble":
			_R(x, y, w, H, "#e9ecef"); c.strokeStyle = "#adb5bd"; c.lineWidth = .8; c.beginPath(); c.moveTo(x + w * sd, y + 2); c.lineTo(x + w * sd + 8, y + 7); c.lineTo(x + w * sd + 3, y + 11); c.stroke()
			_R(x, y, w, 2.5, "#fcc419"); _R(x, y + 10, w, 2, "#e6b84a")
		"mushroom":
			_R(x + w / 2 - 6, y + 8, 12, 12, "#f1e7d0"); c.fillStyle = K.mix("#e03131", th[4], .25); c.beginPath(); c.roundRect(x, y - 2, w, 12, 6); c.fill()
			var k = 7.0
			while k < w - 4:
				K.circ(c, x + k, y + 3 + fmod(k * sd, 3.0) - 1, 2.4, "#ffffffdd"); k += 13
		"gravestone":
			_R(x, y, w, H, "#6c757d"); _R(x, y + H - 3, w, 3, "#495057"); c.strokeStyle = "#343a40"; c.lineWidth = 1; c.beginPath(); c.moveTo(x + w * sd, y); c.lineTo(x + w * sd + 4, y + 6); c.stroke()
			var k = 3.0
			while k < w:
				K.circ(c, x + k, y, 2.4 + fmod(k * sd, 2.0), "#82c91e"); k += 10
		"candy":
			c.save(); c.beginPath(); c.roundRect(x, y, w, 11, 5); c.clip(); _R(x, y, w, 11, "#f783ac")
			var k = -10.0
			while k < w + 10:
				K.poly(c, [x + k, y + 11, x + k + 5, y + 11, x + k + 10, y, x + k + 5, y], "#ffffff"); k += 10
			c.restore(); _R(x, y - 1, w, 3, "#fff5f7")
			k = 6.0
			while k < w:
				K.circ(c, x + k, y + 2 + fmod(k * sd * 3, 4.0), 2, "#fff5f7"); k += 14
		"metal":
			var g = c.createLinearGradient(0, y, 0, y + 11); g.addColorStop(0, "#ced4da"); g.addColorStop(1, "#495057"); c.fillStyle = g; c.fillRect(x, y, w, 11)
			var k = 6.0
			while k < w:
				K.circ(c, x + k, y + 5, 1.4, "#343a40"); k += 14
			for ex in [x, x + w - 12]:
				for kk in [0, 6]:
					K.poly(c, [ex + kk, y + 11, ex + kk + 3, y + 11, ex + kk + 6, y, ex + kk + 3, y], "#fcc419")
		"asteroid":
			c.fillStyle = "#5c5f66"; c.beginPath(); c.moveTo(x, y); c.lineTo(x + w, y); c.lineTo(x + w - 4, y + 9); c.lineTo(x + w * .6, y + 13); c.lineTo(x + w * .3, y + 11); c.lineTo(x + 4, y + 8); c.fill()
			var k = 8.0
			while k < w - 6:
				K.circ(c, x + k, y + 5 + fmod(k * sd, 3.0), 2.4, "#3d4046"); k += 15
			_R(x, y, w, 1.5, "#adb5bd")
		"temple":
			_R(x, y, w, H, "#c9a36a"); _R(x, y, w, 2.5, "#fcc419")
			var k = 6.0
			while k < w - 6:
				_R(x + k, y + 5, 6, 3, "#8d6e3f"); k += 12
			_R(x, y + 10, w, 1.5, "#8d6e3f")
		"neon":
			_R(x, y, w, H, "#0b0b24"); c.shadowColor = th[5]; c.shadowBlur = 8; c.strokeStyle = th[5]; c.lineWidth = 1.5; c.strokeRect(x + .5, y + .5, w - 1, 10); c.shadowBlur = 0; _R(x + 4, y + 5, w - 8, 1, th[6])
		"rainbow":
			var cols = ["#ff6b6b", "#ffa94d", "#ffe066", "#69db7c", "#4dabf7", "#9775fa"]
			for k in 6:
				_R(x, y + k * 2, w, 2, cols[k])
			_R(x, y, w, 1, "#ffffffaa")
		"storm":
			_R(x, y, w, H, "#343a40"); _R(x, y + H - 2, w, 2, "#212529")
			var fl = .5 + .5 * sin(t * 20 + sd * 9)
			c.shadowColor = "#74c0fc"; c.shadowBlur = 8 * fl; _R(x, y - 1, w, 2, K.rgba("#74c0fc", .4 + fl * .6)); c.shadowBlur = 0
		"obsidian":
			_R(x, y, w, H, "#121218"); c.shadowColor = "#fa5252"; c.shadowBlur = 8; _R(x, y - 1, w, 2, "#fa5252"); c.shadowBlur = 0
			K.poly(c, [x + w * sd, y + 2, x + w * sd + 10, y + 2, x + w * sd + 4, y + 9], "#2a2a36")
		_:
			_R(x, y, w, H, th[4])
	if not q.floor:
		var fg = c.createLinearGradient(0, y + 2, 0, y + 13); fg.addColorStop(0, "rgba(0,0,0,0)"); fg.addColorStop(1, "rgba(0,0,0,.4)"); c.fillStyle = fg; c.fillRect(x, y + 2, w, 11)
		c.fillStyle = "rgba(255,255,255,.38)"; c.fillRect(x + 2, y - 1, w - 4, 1.2); c.fillStyle = "rgba(255,255,255,.12)"; c.fillRect(x, y, 3, 12); c.fillStyle = "rgba(0,0,0,.25)"; c.fillRect(x + w - 3, y, 3, 12)
	if m in ["crystal", "ice", "rainbow", "marble", "neon"]:
		var gx = x + fmod(sd * 997 + floor(t * .7 + sd * 5) * w * .37, w)
		var ga = maxf(0, sin(t * 2.2 + sd * 9))
		if ga > .2:
			c.fillStyle = Color(1, 1, 1, ga); c.fillRect(gx - 3, y - .5, 6, 1); c.fillRect(gx - .5, y - 3.5, 1, 6)
	if m == "ice":
		var dp = fmod(t * .9 + sd * 4, 1.0)
		K.circ(c, x + w * (.2 + sd * .6), y + 14 + dp * 30, 1.6, Color(200 / 255.0, 230 / 255.0, 1, 1 - dp))
	if q.vx:
		c.fillStyle = th[6]
		for s in [-1, 1]:
			var ex = x - 6 if s < 0 else x + w + 6
			K.poly(c, [ex, y + 5, ex - s * 5, y + 1, ex - s * 5, y + 9], th[6])
	if q.top:
		c.fillStyle = "#fcc419"; c.fillRect(x + w / 2 - 1, y - 26, 2, 26); K.poly(c, [x + w / 2 + 1, y - 26, x + w / 2 + 22, y - 21, x + w / 2 + 1, y - 16], "#ffd43b")

# ------------------ nemici ------------------
var _lx = 0.0
var _ly = 0.0
var _ex0 = 0.0
const EINK := "#160a12"

func _rg(x0: float, y0: float, r: float, a, b) -> Ctx.Grad:
	var g = c.createRadialGradient(x0 - r * .35, y0 - r * .45, r * .1, x0, y0, r * 1.1)
	g.addColorStop(0, a); g.addColorStop(1, b)
	return g

func _eye(ex: float, ey: float, r: float, angry: bool, glow = null) -> void:
	K.circ(c, ex, ey, r, glow if glow != null else "#ffffff")
	if glow == null:
		K.circ(c, ex + _lx * r * .35, ey - _ly * r * .3, r * .52, EINK)
		K.circ(c, ex + _lx * r * .35 - r * .18, ey - _ly * r * .3 - r * .2, r * .18, "#ffffff")
	if angry:
		c.strokeStyle = EINK; c.lineWidth = 1.6; c.beginPath(); c.moveTo(ex - r * 1.1, ey - r * 1.3); c.lineTo(ex + r * 1.1, ey - r * (.8 if ex < _ex0 else 1.6)); c.stroke()

func _ol(w := 1.3) -> void:
	c.strokeStyle = EINK; c.lineWidth = w; c.stroke()

func draw_enemy(e, y: float, t: float, th: Array, st: Dictionary) -> void:
	var x: float = e.x
	var p = G.pl
	_ex0 = x
	_lx = clampf((p.x - x) / 50, -1, 1)
	_ly = clampf((y - (sy(p.y) - 12)) / 60, -1, 1) * -1
	var al: bool = e.al > 0
	var INK = EINK
	if e.t == "drop":
		var shk = sin(t * 70) * 1.6 if e.st == 1 else 0.0
		c.save(); c.translate(x + shk, y)
		if e.st == 2:
			c.fillStyle = K.rgba(th[6], .25); c.fillRect(-3, -22, 6, 20)
		var g = c.createLinearGradient(-6, 0, 6, 0); g.addColorStop(0, K.mix(th[6], "#000000", .25)); g.addColorStop(.45, "#ffffff"); g.addColorStop(1, th[6])
		c.fillStyle = g; c.beginPath(); c.moveTo(-6.5, 0); c.lineTo(6.5, 0); c.lineTo(1.5, 13); c.lineTo(0, 22); c.lineTo(-1.5, 13); c.closePath(); c.fill(); _ol(1)
		c.fillStyle = "#ffffffaa"; c.fillRect(-3, 2, 1.4, 9)
		if e.st == 1:
			K.circ(c, 0, 24 + randf() * 3, 1.4, K.rgba(th[6], .8))
		c.restore()
		return
	c.save(); c.translate(x, y)
	if e.t == "crawl":
		var d: float = e.dir
		var wp = t * (20 if al else 12)
		c.fillStyle = "rgba(0,0,0,.35)"; c.beginPath(); c.ellipse(0, 1, 13, 2.6, 0, 0, 7); c.fill()
		match st.cr:
			"crab":
				for s in [-1, 1]:
					for k in 3:
						var ph = sin(wp + k * 1.6 + (1 if s > 0 else 0)) * 2.2
						c.strokeStyle = "#a61e1e"; c.lineWidth = 2; c.beginPath(); c.moveTo(s * (4 + k * 3), -5); c.lineTo(s * (9 + k * 3), -8 + ph); c.lineTo(s * (11 + k * 3), 0); c.stroke()
				c.fillStyle = _rg(0, -8, 12, "#ff9a8a", "#b02020"); c.beginPath(); c.ellipse(0, -8, 12, 7.5, 0, 0, 7); c.fill(); _ol(); K.circ(c, -4, -10, 1.2, "#ffd0c8"); K.circ(c, 3, -12, 1, "#ffd0c8")
				for s in [-1, 1]:
					var op = absf(sin(t * (10 if al else 4) + s)) * .6
					var ay = -20.0 if al else -15.0
					c.strokeStyle = "#b02020"; c.lineWidth = 2.4; c.beginPath(); c.moveTo(s * 9, -9); c.lineTo(s * 14, ay + 4); c.stroke()
					c.save(); c.translate(s * 15, ay); c.rotate(-s * .5); c.fillStyle = _rg(0, 0, 5, "#ff9a8a", "#c02a2a")
					c.beginPath(); c.ellipse(0, -2.4 - op * 2.5, 5.2, 2.8, 0, 0, 7); c.fill(); _ol(1); c.beginPath(); c.ellipse(-s * .5, 2.2 + op * 2.5, 4.4, 2.4, 0, 0, 7); c.fill(); _ol(1); c.restore()
				for s in [-1, 1]:
					c.strokeStyle = INK; c.lineWidth = 1.4; c.beginPath(); c.moveTo(s * 3, -13); c.lineTo(s * 4, -18); c.stroke(); _eye(s * 4, -19.5, 2.8, al)
				c.strokeStyle = INK; c.lineWidth = 1.2; c.beginPath(); c.arc(0, -6, 2.5, .2, PI - .2); c.stroke()
			"scorpion":
				for s in [-1, 1]:
					for k in 3:
						var ph = sin(wp + k * 1.4 + s) * 1.8
						c.strokeStyle = "#7a4a1a"; c.lineWidth = 1.6; c.beginPath(); c.moveTo(s * (k * 4 - 3), -4); c.lineTo(s * (k * 4 + 2), -6 + ph); c.lineTo(s * (k * 4 + 4), 0); c.stroke()
				for k in 3:
					c.fillStyle = _rg(-d * k * 6, -6, 6, "#f0c890", "#8a5a2a"); c.beginPath(); c.ellipse(-d * k * 6, -6, 6.5 - k, 4.5 - k * .6, 0, 0, 7); c.fill(); _ol(1)
				var tl = [[-d * 14, -8], [-d * 18, -15], [-d * 17, -22], [-d * 12, -27], [-d * 6, -28 + sin(t * (9 if al else 4)) * 2]]
				for k in tl.size():
					var tx: float = tl[k][0]
					var ty: float = tl[k][1]
					var gg = _rg(tx, ty, 4, "#f0c890", "#8a5a2a")
					K.circ(c, tx, ty, 3.6 - k * .35, gg); c.beginPath(); c.arc(tx, ty, 3.6 - k * .35, 0, 7); _ol(1)
				K.poly(c, [-d * 2, -29, -d * 6, -24, -d * 8, -31], "#ff4040" if al else "#5a2a0a")
				if al:
					c.shadowColor = "#ff4040"; c.shadowBlur = 8; K.circ(c, -d * 4, -29, 1.5, "#ffb0b0"); c.shadowBlur = 0
				for s in [-1, 1]:
					c.fillStyle = _rg(d * 14, -6 + s * 4, 4, "#f0c890", "#8a5a2a"); c.beginPath(); c.ellipse(d * 14, -6 + s * 4, 4.5, 3, s * .4, 0, 7); c.fill(); _ol(1)
				_eye(d * 5, -9, 2, al)
			"slime":
				var b = absf(sin(t * (9 if al else 5)))
				var wv = b * 3
				c.fillStyle = _rg(0, -8, 13, K.mix(th[6], "#ffffff", .45), K.mix(th[6], "#000000", .35)); c.beginPath(); c.moveTo(-13 - wv * .6, 0); c.quadraticCurveTo(-13, -17 + wv, 0, -18 + wv * 1.4)
				c.quadraticCurveTo(13, -17 + wv, 13 + wv * .6, 0); c.closePath(); c.fill(); _ol(1.4)
				c.fillStyle = "rgba(255,255,255,.55)"; c.beginPath(); c.ellipse(-5, -12 + wv, 3.5, 2, -.5, 0, 7); c.fill(); K.circ(c, 4, -5, 1.4, "rgba(255,255,255,.35)"); K.circ(c, -2, -4, 1, "rgba(255,255,255,.35)")
				_eye(-4, -9 + wv, 3.2, al); _eye(5, -9 + wv, 3.2, al); c.strokeStyle = INK; c.lineWidth = 1.3; c.beginPath()
				if al:
					c.moveTo(-3, -3 + wv); c.lineTo(3, -3 + wv)
				else:
					c.arc(0, -5 + wv, 2.5, .3, PI - .3)
				c.stroke()
				c.fillStyle = K.rgba(th[6], .7); c.beginPath(); c.ellipse(-10, 1, 2, 3 + b * 2, 0, 0, 7); c.fill()
			"beetle":
				for s in [-1, 1]:
					for k in 3:
						c.strokeStyle = INK; c.lineWidth = 1.5; c.beginPath(); c.moveTo(s * (k * 4 - 3), -4); c.lineTo(s * (k * 4 + 1), -2 + sin(wp + k + s) * 1.6); c.lineTo(s * (k * 4 + 3), 0); c.stroke()
				var hg = _rg(d * 10, -6, 5, "#3a3a4a", "#0a0a12")
				K.circ(c, d * 11, -6, 4.5, hg); c.beginPath(); c.arc(d * 11, -6, 4.5, 0, 7); _ol(1)
				c.strokeStyle = INK; c.lineWidth = 1; c.beginPath(); c.moveTo(d * 13, -9); c.quadraticCurveTo(d * 17, -15, d * 20, -13); c.moveTo(d * 12, -10); c.quadraticCurveTo(d * 14, -16, d * 17, -17); c.stroke()
				var g = c.createLinearGradient(-11, -14, 11, 0); g.addColorStop(0, K.mix(th[4], "#ffffff", .25)); g.addColorStop(.5, th[4]); g.addColorStop(1, "#0a0a18")
				c.fillStyle = g; c.beginPath(); c.ellipse(0, -6, 11.5, 8, 0, PI, 0); c.lineTo(11.5, -3); c.lineTo(-11.5, -3); c.closePath(); c.fill(); _ol()
				c.strokeStyle = INK; c.lineWidth = 1; c.beginPath(); c.moveTo(0, -14); c.lineTo(0, -3); c.stroke(); c.fillStyle = "rgba(255,255,255,.4)"; c.beginPath(); c.ellipse(-5, -10, 4, 1.4, -.4, 0, 7); c.fill()
				K.circ(c, d * 13, -7, 1.3, "#ff3b3b" if al else "#ffffff")
			"frog":
				var h = maxf(0, sin(t * (7 if al else 4))) * 7
				var lg = h > 2
				c.translate(0, -h)
				c.fillStyle = "#2f8a3a"
				for s in [-1, 1]:
					c.beginPath(); c.ellipse(s * 8, 2 if lg else -2, 4, 6 if lg else 2.5, s * .4, 0, 7); c.fill()
				c.fillStyle = _rg(0, -7, 12, "#8ce99a", "#2b8a3e"); c.beginPath(); c.ellipse(0, -7, 12, 8, 0, 0, 7); c.fill(); _ol(); c.fillStyle = "#d8f5a2"; c.beginPath(); c.ellipse(0, -4, 7, 4, 0, 0, PI); c.fill()
				for s in [-1, 1]:
					c.fillStyle = _rg(s * 5, -14, 5, "#8ce99a", "#2b8a3e"); c.beginPath(); c.arc(s * 5, -14, 5, 0, 7); c.fill(); _ol(1); _eye(s * 5, -14.5, 3, false)
				K.circ(c, -8, -6, 1.8, "#ff8fab"); K.circ(c, 8, -6, 1.8, "#ff8fab"); c.strokeStyle = INK; c.lineWidth = 1.2; c.beginPath(); c.arc(0, -7, 6, .25, PI - .25); c.stroke()
				if al and sin(t * 3) > .7:
					c.strokeStyle = "#ff6b8a"; c.lineWidth = 2; c.beginPath(); c.moveTo(0, -4); c.lineTo(_lx * 22, -6); c.stroke(); K.circ(c, _lx * 22, -6, 2.4, "#ff6b8a")
			"snail":
				c.strokeStyle = K.rgba("#c0d0e0", .45); c.lineWidth = 2; c.beginPath(); c.moveTo(-d * 12, 0); c.lineTo(-d * 26, 0); c.stroke()
				c.fillStyle = _rg(0, -3, 13, "#f4ecd8", "#a89878"); c.beginPath(); c.ellipse(0, -3, 14, 4.5, 0, 0, 7); c.fill(); _ol(1)
				c.strokeStyle = "#a89878"; c.lineWidth = 1.8
				for s in [0, 1]:
					c.strokeStyle = "#a89878"; c.lineWidth = 1.8
					c.beginPath(); c.moveTo(d * (10 + s * 2), -5); c.lineTo(d * (12 + s * 3), -14 + sin(t * 3 + s) * 1.5); c.stroke(); _eye(d * (12 + s * 3), -15 + sin(t * 3 + s) * 1.5, 2, al)
				c.fillStyle = _rg(-d * 2, -11, 9, K.mix(th[6], "#ffffff", .4), K.mix(th[6], "#000000", .35)); c.beginPath(); c.arc(-d * 2, -11, 9, 0, 7); c.fill(); _ol()
				c.strokeStyle = K.rgba(INK, .55); c.lineWidth = 1.4; c.beginPath()
				var a = 0.0
				while a < 11:
					c.lineTo(-d * 2 + cos(a * d) * a * .75, -11 + sin(a * d) * a * .75); a += .35
				c.stroke()
			"skull":
				var hop = absf(sin(t * (8 if al else 5))) * 5
				c.translate(0, -hop); c.fillStyle = _rg(0, -11, 10, "#ffffff", "#b8b0a0"); c.beginPath(); c.arc(0, -11, 9.5, PI * .85, PI * .15); c.lineTo(5, -3); c.lineTo(-5, -3); c.closePath(); c.fill(); _ol()
				var jaw = absf(sin(t * (14 if al else 6))) * 2.5
				c.fillStyle = "#e8e0d0"; c.beginPath(); c.roundRect(-5, -3 + jaw, 10, 4, 1.5); c.fill(); _ol(1); c.fillStyle = INK
				var k = -3
				while k <= 3:
					c.fillRect(k - .5, -3 + jaw, 1, 3); k += 2
				for s in [-1, 1]:
					c.fillStyle = INK; c.beginPath(); c.ellipse(s * 3.8, -11, 3, 3.4, 0, 0, 7); c.fill(); c.save(); c.shadowColor = th[6]; c.shadowBlur = 8; K.circ(c, s * 3.8 + _lx, -11, 1.6 if al else 1.1, th[6]); c.restore()
				K.poly(c, [0, -8, -1.3, -5.5, 1.3, -5.5], INK); c.strokeStyle = "#8a8070"; c.lineWidth = .8; c.beginPath(); c.moveTo(4, -19); c.lineTo(2, -15); c.lineTo(3.5, -13); c.stroke()
			"gummy":
				var j = sin(t * (14 if al else 7)) * .08
				c.scale(1 + j, 1 - j)
				var col = K.hsl(fmod(t * 40 + x, 360.0), 85, 62)
				c.globalAlpha = .9
				for bb in [[0, -7, 7.5], [0, -16, 6], [-4.5, -20.5, 2.4], [4.5, -20.5, 2.4], [-7, -9, 2.6], [7, -9, 2.6], [-4, -1, 2.8], [4, -1, 2.8]]:
					c.fillStyle = _rg(bb[0], bb[1], bb[2], "#ffffff", col); c.beginPath(); c.arc(bb[0], bb[1], bb[2], 0, 7); c.fill()
				c.globalAlpha = 1; c.beginPath(); c.arc(0, -7, 7.5, 0, 7); _ol(.8); _eye(-2.3, -16.5, 1.7, al); _eye(2.3, -16.5, 1.7, al)
				c.strokeStyle = INK; c.lineWidth = 1; c.beginPath(); c.arc(0, -14, 1.6, .2, PI - .2); c.stroke()
			"robot":
				c.fillStyle = "#343a40"; c.beginPath(); c.roundRect(-11, -5, 22, 5, 2.5); c.fill(); c.strokeStyle = "#868e96"; c.lineWidth = 1
				for k in 5:
					var tx = -9 + fposmod(fmod(k * 5 + t * (30 if al else 15) * d, 20.0) + 20, 20.0)
					c.beginPath(); c.moveTo(tx, -5); c.lineTo(tx, 0); c.stroke()
				var g = c.createLinearGradient(-9, -19, 9, -5); g.addColorStop(0, "#e9ecef"); g.addColorStop(1, "#6c757d"); c.fillStyle = g; c.beginPath(); c.roundRect(-9, -19, 18, 14, 3); c.fill(); _ol()
				c.fillStyle = "#111418"; c.beginPath(); c.roundRect(-6.5, -16, 13, 6, 2); c.fill()
				var sc = sin(t * (6 if al else 2.5)) * 4
				c.save(); c.shadowColor = "#ff3b3b" if al else th[6]; c.shadowBlur = 8; c.fillStyle = "#ff3b3b" if al else th[6]; c.fillRect(-1.6 + sc + _lx * .8, -14.5, 3.2, 3); c.restore()
				c.fillStyle = "#868e96"; c.fillRect(-.8, -25, 1.6, 6); K.circ(c, 0, -26, 2.2, "#ff6b6b" if sin(t * 8) > 0 else "#5a2020"); c.fillStyle = "#adb5bd"; c.fillRect(-12, -14, 3, 6); c.fillRect(9, -14, 3, 6)
		if e.alt > 0:
			c.font = "12px Bungee"; c.fillStyle = "#ffd43b"; c.strokeStyle = INK; c.lineWidth = 3; c.textAlign = "center"; c.strokeText("!", 0, -32); c.fillText("!", 0, -32)
	else:
		var f = sin(t * 18)
		match st.fl:
			"bat":
				for s in [-1, 1]:
					c.fillStyle = _rg(s * 9, -2, 12, "#9775fa", "#3b1f6e"); c.beginPath(); c.moveTo(s * 3, -2); c.quadraticCurveTo(s * 10, -10 - f * 7, s * 17, -4 - f * 8); c.lineTo(s * 14, 1 - f * 3); c.lineTo(s * 11, -1 - f * 2); c.lineTo(s * 8, 2 - f); c.closePath(); c.fill(); _ol(1)
					c.strokeStyle = "#2a1650"; c.lineWidth = .8; c.beginPath(); c.moveTo(s * 3, -2); c.lineTo(s * 14, 1 - f * 3); c.moveTo(s * 4, -3); c.lineTo(s * 11, -1 - f * 2); c.stroke()
				c.fillStyle = _rg(0, 0, 6, "#7a5ab0", "#2a1650"); c.beginPath(); c.ellipse(0, 0, 5, 6, 0, 0, 7); c.fill(); _ol(1); K.poly(c, [-4, -4, -3, -9, -1, -5], "#3b1f6e"); K.poly(c, [4, -4, 3, -9, 1, -5], "#3b1f6e")
				c.save(); c.shadowColor = "#ff3b3b"; c.shadowBlur = 5; K.circ(c, -2, -1, 1.3, "#ff5a5a"); K.circ(c, 2, -1, 1.3, "#ff5a5a"); c.restore()
				K.poly(c, [-1.6, 2.5, -.8, 2.5, -1.2, 4.2], "#fff"); K.poly(c, [1.6, 2.5, .8, 2.5, 1.2, 4.2], "#fff")
			"spark":
				for k in range(1, 4):
					K.circ(c, -cos(e.ph) * k * 5, k * 3, 6 - k * 1.4, K.rgba("#ff6b1a", .35 - k * .08))
				c.save(); c.globalCompositeOperation = "lighter"
				var g = c.createRadialGradient(0, 0, 1, 0, 0, 15); g.addColorStop(0, "#ffffff"); g.addColorStop(.35, "#ffd43b"); g.addColorStop(.7, "rgba(255,107,26,.6)"); g.addColorStop(1, "rgba(255,60,0,0)")
				c.fillStyle = g; c.beginPath()
				for k in 12:
					var a = k / 12.0 * PI * 2
					var r = (10.0 if k % 2 else 15.0) + sin(t * 25 + k) * 2
					c.lineTo(cos(a) * r, sin(a) * r - 2)
				c.fill(); c.restore()
				_eye(-3, -1, 2.2, true); _eye(3, -1, 2.2, true)
			"bird":
				c.fillStyle = _rg(0, 0, 7, "#4a4a58", "#121218")
				for s in [-1, 1]:
					c.beginPath(); c.moveTo(s * 2, -1); c.quadraticCurveTo(s * 9, -8 - f * 7, s * 17, -2 - f * 9); c.lineTo(s * 12, 0 - f * 3); c.lineTo(s * 14, 2 - f * 4); c.lineTo(s * 8, 2 - f); c.closePath(); c.fill(); _ol(1)
				c.beginPath(); c.ellipse(0, 1, 6, 4.5, 0, 0, 7); c.fill(); _ol(1); K.circ(c, _lx * 4, -3, 3.4, "#2a2a34")
				var sg = 1.0 if _lx >= 0 else -1.0
				K.poly(c, [_lx * 4 + sg * 3, -3.5, _lx * 4 + sg * 8, -2, _lx * 4 + sg * 3, -1.5], "#ffa94d"); _eye(_lx * 4 + sg * 1.2, -4, 1.3, true)
			"bee":
				c.fillStyle = "rgba(230,245,255,.6)"
				for s in [-1, 1]:
					c.fillStyle = "rgba(230,245,255,.6)"; c.beginPath(); c.ellipse(s * 4, -7, 6, 3.2 + f * 2, s * .5, 0, 7); c.fill(); c.strokeStyle = "rgba(120,140,160,.6)"; c.lineWidth = .6; c.stroke()
				c.save(); c.beginPath(); c.ellipse(0, 0, 9.5, 6.5, 0, 0, 7); c.clip(); c.fillStyle = _rg(0, 0, 9, "#ffe066", "#e67700"); c.fillRect(-10, -7, 20, 14); c.fillStyle = INK; c.fillRect(-4, -7, 2.6, 14); c.fillRect(1.5, -7, 2.6, 14); c.restore()
				c.beginPath(); c.ellipse(0, 0, 9.5, 6.5, 0, 0, 7); _ol(1.1)
				K.poly(c, [-9, 0, -13, -1, -9, 2], INK); K.circ(c, 7, -1, 3.6, "#2a2a2a"); _eye(8, -1.6, 1.5, al); c.strokeStyle = INK; c.lineWidth = .9; c.beginPath(); c.moveTo(8, -4); c.quadraticCurveTo(9, -9, 12, -9); c.stroke()
			"fish":
				var dd = 1.0 if cos(e.ph) > 0 else -1.0
				c.scale(dd, 1)
				var sw = sin(t * 10) * 3
				c.fillStyle = K.mix(th[6], "#000000", .2); c.beginPath(); c.moveTo(-8, 0); c.lineTo(-17, -6 + sw); c.lineTo(-15, 0); c.lineTo(-17, 6 + sw); c.closePath(); c.fill(); _ol(1)
				K.poly(c, [-4, -6, 2, -12, 5, -6], K.mix(th[6], "#000000", .25)); c.fillStyle = _rg(0, 0, 10, K.mix(th[6], "#ffffff", .4), K.mix(th[6], "#000000", .3)); c.beginPath(); c.ellipse(0, 0, 11, 7, 0, 0, 7); c.fill(); _ol()
				c.strokeStyle = K.rgba("#ffffff", .3); c.lineWidth = .8
				var k = -4
				while k < 4:
					c.beginPath(); c.arc(k, 0, 3, -.8, .8); c.stroke(); k += 3
				_eye(5, -2, 2.6, true); c.fillStyle = INK; c.beginPath(); c.moveTo(11, 1); c.lineTo(6, 1.5); c.lineTo(10, 4); c.fill()
				K.poly(c, [7, 1.5, 8, 1.5, 7.5, 3], "#fff"); K.poly(c, [9, 1.4, 10, 1.2, 9.6, 2.8], "#fff")
			"ghost":
				c.save(); c.globalCompositeOperation = "lighter"
				var ag = c.createRadialGradient(0, 0, 2, 0, 0, 20); ag.addColorStop(0, "rgba(200,220,255,.25)"); ag.addColorStop(1, "rgba(200,220,255,0)"); c.fillStyle = ag; c.fillRect(-20, -20, 40, 40); c.restore()
				var g = c.createLinearGradient(0, -12, 0, 10); g.addColorStop(0, "rgba(255,255,255,.95)"); g.addColorStop(1, "rgba(220,228,255,.35)")
				c.fillStyle = g; c.beginPath(); c.arc(0, -3, 9.5, PI, 0); c.lineTo(9.5, 8)
				for k in 4:
					c.lineTo(9.5 - (k + .5) * 4.75, 8 + (-3 if k % 2 else 1) + sin(t * 8 + k) * 1.6)
				c.lineTo(-9.5, 8); c.closePath(); c.fill()
				c.fillStyle = INK; c.beginPath(); c.ellipse(-3.2 + _lx, -3, 2, 2.8, 0, 0, 7); c.ellipse(3.2 + _lx, -3, 2, 2.8, 0, 0, 7); c.fill()
				c.save(); c.shadowColor = th[6]; c.shadowBlur = 6; K.circ(c, -3.2 + _lx, -3.5, .9, th[6]); K.circ(c, 3.2 + _lx, -3.5, .9, th[6]); c.restore()
				c.beginPath(); c.ellipse(0, 2.5, 1.6, 2 + absf(f), 0, 0, 7); c.fillStyle = INK; c.fill()
			"drone":
				var g = c.createLinearGradient(0, -4, 0, 4); g.addColorStop(0, "#adb5bd"); g.addColorStop(1, "#343a40"); c.fillStyle = g; c.beginPath(); c.roundRect(-9, -4, 18, 8, 3); c.fill(); _ol(1)
				for s in [-1, 1]:
					c.strokeStyle = "#495057"; c.lineWidth = 2; c.beginPath(); c.moveTo(s * 7, -3); c.lineTo(s * 11, -8); c.stroke(); c.fillStyle = "rgba(200,210,220,.45)"; c.beginPath(); c.ellipse(s * 11, -9, 7, 1.6, 0, 0, 7); c.fill()
					var ps = absf(sin(t * 50))
					c.fillStyle = "#dee2e6"; c.fillRect(s * 11 - 7 * ps, -9.5, 14 * ps, 1)
				K.circ(c, _lx * 2, 1, 3, "#111"); c.save(); c.shadowColor = "#ff3b3b" if al else th[6]; c.shadowBlur = 8; K.circ(c, _lx * 2, 1, 1.5, "#ff3b3b" if al else th[6]); c.restore()
				if sin(t * 6) > .5:
					K.circ(c, 7, -2, 1, "#ff3b3b")
			"ufo":
				c.save(); c.globalCompositeOperation = "lighter"
				var bg = c.createLinearGradient(0, 0, 0, 30); bg.addColorStop(0, "rgba(140,255,170,.25)"); bg.addColorStop(1, "rgba(140,255,170,0)")
				c.fillStyle = bg; c.beginPath(); c.moveTo(-5, 2); c.lineTo(5, 2); c.lineTo(12, 30); c.lineTo(-12, 30); c.fill(); c.restore()
				c.fillStyle = "rgba(170,230,255,.55)"; c.beginPath(); c.arc(0, -3, 6.5, PI, 0); c.fill(); K.circ(c, 0, -4, 3, "#69db7c"); K.circ(c, -1, -4.5, .9, INK); K.circ(c, 1.2, -4.5, .9, INK)
				var g = c.createLinearGradient(0, -3, 0, 4); g.addColorStop(0, "#e9ecef"); g.addColorStop(1, "#495057"); c.fillStyle = g; c.beginPath(); c.ellipse(0, 0, 15, 4.6, 0, 0, 7); c.fill(); _ol(1)
				for k in 5:
					var a = t * 3 + k * 1.26
					var xx = cos(a) * 11
					if sin(a) > 0:
						K.circ(c, xx, 1.2, 1.5, "#ffd43b" if k % 2 else "#ff6b6b")
		if e.sw and absf(e.sw) > 20:
			c.font = "11px Bungee"; c.fillStyle = "#ff6b6b"; c.textAlign = "center"; c.fillText("!", 0, -16)
	c.restore()
