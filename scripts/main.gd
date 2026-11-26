extends Node2D
## Scena principale: stati del gioco, menu, villaggio, storia, video, negozio, HUD e input.
## Riproduce l'interfaccia HTML di Kubo Run (stessi testi, colori e animazioni).

const W := 360.0
const N := 22
const MOODS := ["sleep", "love", "angry", "happy", "wow", "wink"]

var game: Game
var ui: Node2D
var u: Ctx
var VH = 640.0
var top_in = 10.0
var bot_in = 0.0
var state = "menu"
var ov = ""            # "", win, lose, shop, how
var hud_on = false
var t = 0.0
var btns: Array = []

# input del gioco (un pollice)
var inp = {"x": 0.0, "jumpQ": false, "keyHook": false}
var T = {}
var keys = {}
# tocchi nelle schermate
var touch = {}

# menu
var wsel = 0
var mood = 0
var moodT = 0.0
var hopT = -9.0
var nextMood = 0.0
var intro_t0 = -99.0
var intro_on = false
var intro_fx: Array = []
var intro_snd: Array = []
var ms = 0.0          # scroll del menu
var msv = 0.0
var menu_h = 0.0
var swapT = -9.0
var swapD = 1
var tapN = 0
var tapT = 0.0
var cheat_txt = ""
var cheat_t = -9.0
var layout = {}

# villaggio
var VIL = {"x": 0.0, "v": 0.0, "down": null, "drag": false, "bub": null, "w": 328.0, "h": 210.0, "target": null}
var VW = 200.0 + N * 100

# storia
var SY = {"on": false, "i": 0, "pages": [], "pg": 0, "typed": 0, "t0": 0.0, "after": null, "btn": "", "objs": [], "comp": false, "fade": 0.0}
# video
var CINE = {"on": false, "t0": 0.0, "done": null, "ev": {}, "capI": -1, "capT": 0.0, "flash": 0.0, "people": []}
const CW := 900.0
const CEND := 28.6
# overlay vittoria / sconfitta
var winfo = {}
var shop_shake = -9.0
var shop_scroll = 0.0
var comp_scroll = 0.0

func _ready() -> void:
	Engine.max_fps = 60
	game = Game.new()
	game.main = self
	add_child(game)
	ui = Node2D.new()
	add_child(ui)
	u = Ctx.new(ui.get_canvas_item())
	wsel = mini(S.d.unlocked - 1, N - 1)
	get_tree().root.size_changed.connect(_resize)
	_resize()
	intro()

func _resize() -> void:
	var vs = get_viewport_rect().size
	VH = vs.y * (W / vs.x)
	game.VH = VH
	var win = DisplayServer.window_get_size()
	var sc = float(win.x) / W
	var safe = DisplayServer.get_display_safe_area()
	top_in = maxf(10.0, safe.position.y / sc) if sc > 0 else 10.0
	bot_in = maxf(0.0, (win.y - safe.end.y) / sc) if sc > 0 else 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ov == "shop" or ov == "how":
			ov = ""
		elif state == "cine":
			end_cine()
		elif state != "menu":
			to_menu()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		S.store()

# =====================================================================
#                           CICLO PRINCIPALE
# =====================================================================
func _process(delta: float) -> void:
	var dt = minf(.033, delta)
	t = Time.get_ticks_msec() / 1000.0
	btns = []
	u.begin_frame()
	if state == "cine":
		game.c.begin_frame()
		draw_cine()
		return
	if state == "menu":
		game.c.begin_frame()
		draw_menu(dt)
	else:
		if state == "play" and game.G != null and game.G.art != null:
			game.update(dt)
		if game.G != null:
			game.render()
		if hud_on and game.G != null:
			draw_hud(dt)
	if SY.on:
		draw_story()
	if ov != "":
		draw_overlay()
	if cheat_t > 0 and t - cheat_t < 2.8:
		draw_cheat()

# =====================================================================
#                           STATI DEL GIOCO
# =====================================================================
func art_for(i: int) -> void:
	if game.art_cache.has(i):
		game.G.art = game.art_cache[i]
		return
	var win = DisplayServer.window_get_size()
	var dsc = float(win.x) / W
	var Sc = minf(1.3, dsc * .7)
	var Sw = minf(2.0, dsc)
	var gi: int = game.G.i
	var a: Dictionary = await Bake.bake(self, gi, Sc, Sw)
	if game.art_cache.size() > 2:
		game.art_cache.clear()
	game.art_cache[gi] = a
	if game.G != null and game.G.i == gi:
		game.G.art = a

func start(i: int, fromCp := false, quick := false) -> void:
	if i == 0 and not S.d.seen and not fromCp and not quick:
		S.d.seen = true; S.store()
		play_cine(start.bind(0, false, false))
		return
	var keep = null
	if fromCp and game.G != null and game.G.i == i:
		keep = {"cpY": game.G.cpY, "cpX": game.G.cpX, "cps": game.G.CP.map(func(k): return k.on)}
	game.G = game.build(i)
	art_for(i)
	var G = game.G
	if keep != null:
		G.cpY = keep.cpY; G.cpX = keep.cpX
		for k in G.CP.size():
			G.CP[k].on = keep.cps[k]
		G.pl.x = G.cpX; G.pl.y = G.cpY; G.cam = G.cpY - VH * .42; G.maxY = G.cpY; G.lava = G.cpY - 480
	T.clear(); inp.x = 0.0
	ov = ""
	hud_on = true
	if quick or fromCp:
		begin_play()
		return
	state = "story"
	var pages: Array = []
	pages.append({"who": "kubo", "mood": D.J.INMOOD[i], "text": D.J.INTRO[i]})
	if i in Game.CHASE:
		pages.append({"who": "ombra", "mood": "n", "text": "Ah ah ah! Il mio Ombretto sta portando via %s! Prendilo, se ci riesci!" % D.FR[i].n})
	else:
		pages.append({"who": i, "mood": "hurt", "text": "Aiuto Kubo! Sono %s, %s! Il Re Ombra mi ha chiuso in gabbia lassù… la chiave è nascosta nel livello!" % [D.FR[i].n, D.FR[i].tr]})
	if i == N - 1:
		pages.append({"who": "ombra", "mood": "n", "text": "Sei arrivato fin qui, cubetto arancione? Ora assaggerai la mia OMBRA!"})
	story(i, pages, begin_play, "TOCCA PER INIZIARE", obj_rows(i), true)

func begin_play() -> void:
	state = "play"
	var G = game.G
	var p = G.pl
	G.perk = D.FR[S.d.comp].pw if (S.d.comp >= 0 and S.d.fr[S.d.comp] and S.d.comp != G.i) else null
	G.follow = [S.d.comp] if G.perk != null else []
	if G.perk == "shield": p.pw.shield = true
	if G.perk == "heart": G.hearts = 4
	if G.perk == "slow": G.lspeed *= .7
	if G.perk != null:
		var cf: Dictionary = D.FR[S.d.comp]
		var msg = "%s: %s %s" % [cf.n, D.J.PWIC[G.perk], D.J.PWD[G.perk]]
		game.later(2.6, _perk_toast.bind(msg, cf.c))
	var hz: String = D.J.HAZ[G.i]
	game.toast("⚠ SALE %s %s!" % ["IL" if hz in ["BUIO", "FANGO", "SCIROPPO", "OLIO", "GELO", "COLORE"] else "LA", hz], 2.4, "#ffb347")
	A.mus_start(G.i)

func _perk_toast(msg: String, col) -> void:
	if state == "play":
		game.toast(msg, 2, col)

func end_run() -> void:
	var G = game.G
	if G == null:
		return
	var i: int = G.i
	S.d.best[i] = maxi(S.d.best[i], mini(D.goal_of(i), int(floor(G.maxY / Game.PPM))))
	S.store()

func to_menu() -> void:
	end_run()
	A.mus_stop()
	SY.on = false
	state = "menu"
	hud_on = false
	ov = ""
	var G = game.G
	if G != null:
		wsel = G.i
		if G.freed and S.d.fr[G.i]:
			VIL.target = maxf(0, house_x(G.i) - VIL.w / 2)
			VIL.bub = {"k": G.i, "t": t + 1.8}
	intro()

func show_lose() -> void:
	var G = game.G
	winfo = {"m": "Hai raggiunto %dm su %dm" % [int(floor(G.maxY / Game.PPM)), D.goal_of(G.i)], "x": "◆ %d gemme · combo max x%d" % [G.runGems, G.bestCombo], "cp": G.cpY > 0}
	ov = "lose"
	state = "over"

func win() -> void:
	A.sfx("win")
	end_run()
	var G = game.G
	var i: int = G.i
	S.d.st[i][0] = true; S.d.fr[i] = true; S.d.best[i] = D.goal_of(i)
	if i + 1 < N:
		S.d.unlocked = maxi(S.d.unlocked, i + 2)
	S.store()
	await get_tree().create_timer(.6).timeout
	if game.G != G:
		return
	state = "story"
	var pages: Array
	if i == N - 1:
		pages = [{"who": "ombra", "mood": "hurt", "text": "Noooo! I miei colori… la luce mi scioglie!"}, {"who": i, "mood": "love", "text": D.FR[i].line},
			{"who": "nonno", "mood": "love", "text": "Kubo, hai salvato Cubolandia! Guarda: i colori sono tornati!"}, {"narr": true, "who": "kubo", "mood": "love", "text": "E da quel giorno, a Cubolandia, nessuno ebbe più paura del buio. FINE… per ora!"}]
	else:
		pages = [{"who": i, "mood": "love", "text": D.FR[i].line}, {"who": "kubo", "mood": "happy", "text": "Torna al villaggio, %s! Io vado avanti: prossima fermata %s!" % [D.FR[i].n, D.THEMES[i + 1][0]]}]
	winfo = {"m": "%dm / %dm" % [D.goal_of(i), D.goal_of(i)], "x": "%s è salvo! · ◆ +%d · combo max x%d" % [D.FR[i].n, G.runGems, G.bestCombo], "i": i}
	story(i, pages, _show_win, "CONTINUA", obj_rows(i), false)

func _show_win() -> void:
	ov = "win"
	state = "win"

# =====================================================================
#                           INPUT
# =====================================================================
func key_left() -> bool:
	return keys.get(KEY_LEFT, false) or keys.get(KEY_A, false)

func key_right() -> bool:
	return keys.get(KEY_RIGHT, false) or keys.get(KEY_D, false)

func _upd_x() -> void:
	var v = 0.0
	for o in T.values():
		if o.m == "move":
			v = clampf((o.x - o.ax) / 30, -1, 1)
	inp.x = v

func poll_hold() -> void:
	var now = Time.get_ticks_msec()
	for o in T.values():
		if o.m == "?" and now - o.t0 > 150:
			o.m = "hold"

func holding() -> bool:
	if inp.keyHook:
		return true
	for o in T.values():
		if o.m == "hold":
			return true
	return false

func _input(e: InputEvent) -> void:
	if e is InputEventKey:
		if e.echo:
			return
		keys[e.keycode] = e.pressed
		if e.pressed and e.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
			if state == "play": inp.jumpQ = true
			elif SY.on: story_tap()
		if e.keycode in [KEY_X, KEY_SHIFT, KEY_K]:
			inp.keyHook = e.pressed
		if e.pressed and e.keycode == KEY_ESCAPE:
			_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		return
	if e is InputEventScreenTouch:
		var pos = _lp(e.position)
		if e.pressed:
			_down(e.index, pos)
		else:
			_up(e.index, pos, e.canceled)
	elif e is InputEventScreenDrag:
		_move(e.index, _lp(e.position))

func _lp(p: Vector2) -> Vector2:
	var vs = get_viewport_rect().size
	return p * (W / vs.x)

func _down(id: int, p: Vector2) -> void:
	touch[id] = {"x0": p.x, "y0": p.y, "x": p.x, "y": p.y, "t0": Time.get_ticks_msec(), "moved": false, "ms0": ms, "vil": false, "wcv": false, "lx": p.x, "ly": p.y, "shop0": shop_scroll, "comp0": comp_scroll, "inComp": false}
	if state == "menu" and ov == "" and intro_on:
		intro_on = false
		intro_snd.clear()
	if state == "play" and ov == "" and not SY.on:
		T[id] = {"x0": p.x, "y0": p.y, "x": p.x, "y": p.y, "ax": p.x, "t0": Time.get_ticks_msec(), "m": "?", "sw": false}
		return
	if SY.on and ov == "":
		var cr: Rect2 = layout.get("comp", Rect2())
		if cr.has_point(p):
			touch[id].inComp = true
			return
		story_tap()
		return
	if state == "menu" and ov == "":
		var vr: Rect2 = layout.get("vil", Rect2())
		if vr.has_point(p):
			touch[id].vil = true
			VIL.down = {"x": p.x, "y": p.y, "vx": VIL.x, "lx": p.x}
			VIL.drag = false; VIL.v = 0.0; VIL.target = null
		var wr: Rect2 = layout.get("wcv", Rect2())
		if wr.has_point(p):
			touch[id].wcv = true
		msv = 0.0

func _move(id: int, p: Vector2) -> void:
	if T.has(id):
		var o = T[id]
		o.x = p.x; o.y = p.y
		if (o.m == "?" or o.m == "move") and not o.sw and o.y0 - o.y > 34 and Time.get_ticks_msec() - o.t0 < 320:
			o.sw = true; inp.jumpQ = true
			if o.m == "?": o.m = "swipe"
		if o.m == "?" and absf(o.x - o.x0) > 12:
			o.m = "move"; o.ax = o.x0
		if o.m == "move":
			var d: float = o.x - o.ax
			if absf(d) > 38:
				o.ax = o.x - signf(d) * 38
		_upd_x()
		return
	if not touch.has(id):
		return
	var tc = touch[id]
	var dx: float = p.x - tc.x0
	var dy: float = p.y - tc.y0
	if absf(dx) > 8 or absf(dy) > 8:
		tc.moved = true
	if ov == "shop":
		shop_scroll = maxf(0, tc.shop0 - dy)
	elif SY.on and tc.inComp:
		comp_scroll = maxf(0, tc.comp0 - dx)
	elif state == "menu" and ov == "":
		if tc.vil and VIL.down != null:
			if not VIL.drag and absf(dx) > 8 and absf(dx) > absf(dy):
				VIL.drag = true
			if VIL.drag:
				VIL.x = VIL.down.vx - dx; VIL.v = -(p.x - VIL.down.lx); VIL.down.lx = p.x
				tc.lx = p.x; tc.ly = p.y
				return
		if not tc.wcv or absf(dy) > absf(dx):
			ms = clampf(tc.ms0 - dy, 0, maxf(0, menu_h - VH))
			msv = -(p.y - tc.ly)
	tc.lx = p.x; tc.ly = p.y

func _up(id: int, p: Vector2, cancel: bool) -> void:
	if T.has(id):
		var o = T[id]
		T.erase(id)
		if o.m == "?" and not cancel:
			inp.jumpQ = true
		_upd_x()
		# il pulsante "torna al menu" dell'HUD
		if o.m == "?" and _hit(p):
			inp.jumpQ = false
		return
	if not touch.has(id):
		return
	var tc = touch[id]
	touch.erase(id)
	if cancel:
		VIL.down = null; VIL.drag = false
		return
	if state == "menu" and ov == "":
		if tc.vil:
			var was_drag: bool = VIL.drag
			VIL.down = null; VIL.drag = false
			if not was_drag and not tc.moved:
				var vr: Rect2 = layout.vil
				vil_tap(p.x - vr.position.x + VIL.x, p.y - vr.position.y)
			return
		if tc.wcv:
			var d: float = p.x - tc.x0
			if absf(d) > 40 and absf(d) > absf(p.y - tc.y0):
				set_w(1 if d < 0 else -1)
				return
	if absf(p.x - tc.x0) > 12 or absf(p.y - tc.y0) > 12:
		return
	if not _hit(p) and state == "menu" and ov == "" and tc.wcv:
		_play_sel()

func _hit_name(p: Vector2, nm: String) -> bool:
	for b in btns:
		if b.get("n", "") == nm and (b.r as Rect2).has_point(p):
			return true
	return false

func _hit(p: Vector2) -> bool:
	for k in range(btns.size() - 1, -1, -1):
		var b = btns[k]
		if (b.r as Rect2).has_point(p):
			if b.has("f") and b.f != null:
				b.f.call()
			return true
	return false

func _btn(r: Rect2, f, nm := "") -> void:
	btns.append({"r": r, "f": f, "n": nm})

# =====================================================================
#                           AIUTI GRAFICI
# =====================================================================
func rr(x: float, y: float, w: float, h: float, r: float, fill, stroke = null, lw := 1.0) -> void:
	u.beginPath(); u.roundRect(x, y, w, h, r)
	if fill != null:
		u.fillStyle = fill; u.fill()
	if stroke != null:
		u.strokeStyle = stroke; u.lineWidth = lw; u.stroke()

func txt(s: String, x: float, y: float, font: String, col, align := "left", base := "alphabetic") -> void:
	u.font = font; u.fillStyle = col; u.textAlign = align; u.textBaseline = base
	u.fillText(s, x, y)

func tw(s: String, font: String) -> float:
	u.font = font
	return u.measureText(s).width

## easing cubic-bezier come CSS
func cb(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
	x = clampf(x, 0, 1)
	var lo = 0.0
	var hi = 1.0
	var s = x
	for k in 18:
		var bx = 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s
		if bx < x: lo = s
		else: hi = s
		s = (lo + hi) / 2
	return 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s

func ease_out(x: float) -> float: return cb(0, 0, .58, 1, x)
func ease_in(x: float) -> float: return cb(.42, 0, 1, 1, x)
func ease_css(x: float) -> float: return cb(.25, .1, .25, 1, x)
func ease_io(x: float) -> float: return cb(.42, 0, .58, 1, x)

## stato di un'animazione d'ingresso: [alpha, dx, dy, scale, rot]
func anim(kind: String, delay: float, dur: float) -> Array:
	if not intro_on:
		return [1.0, 0.0, 0.0, 1.0, 0.0]
	var k = clampf((t - intro_t0 - delay) / dur, 0, 1)
	match kind:
		"pop":
			var e = cb(.3, 1.7, .5, 1, k)
			return [clampf(e, 0, 1), 0.0, 0.0, e, deg_to_rad(-14) * (1 - e)]
		"inL":
			return [1.0, -1.1 * W * (1 - cb(.3, 1.35, .5, 1, k)), 0.0, 1.0, 0.0]
		"inR":
			return [1.0, 1.1 * W * (1 - cb(.3, 1.35, .5, 1, k)), 0.0, 1.0, 0.0]
		"up":
			var e2 = ease_out(k)
			return [e2, 0.0, 22 * (1 - e2), 1.0, 0.0]
		"spin":
			var e3 = cb(.2, .9, .3, 1.12, k)
			return [clampf(k / .55, 0, 1), 0.0, 0.0, e3, deg_to_rad(-540) * (1 - e3)]
		"drop":
			var e4 = cb(.3, 1.55, .5, 1, k)
			return [e4, 0.0, -140 * (1 - e4), .6 + .4 * e4, 0.0]
	return [1.0, 0.0, 0.0, 1.0, 0.0]

func push_anim(a: Array, cx: float, cy: float) -> void:
	u.save()
	u.globalAlpha = clampf(a[0], 0, 1)
	u.translate(cx + a[1], cy + a[2])
	u.rotate(a[4])
	u.scale(a[3], a[3])
	u.translate(-cx, -cy)

# salto delle lettere del titolo (keyframes "hy")
func hy(k: float) -> Vector3:
	# x = dy, y = sx, z = sy
	var keys2 = [[0.0, 0.0, 1.0, 1.0], [.17, -70.0, 1.0, 1.0], [.34, 0.0, 1.15, .85], [.52, -38.0, 1.0, 1.0], [.68, 0.0, 1.1, .9], [.82, -14.0, 1.0, 1.0], [.92, 0.0, 1.06, .94], [1.0, 0.0, 1.0, 1.0]]
	var fns = ["o", "i", "o", "i", "o", "i", "e"]
	if k <= 0: return Vector3(0, 1, 1)
	if k >= 1: return Vector3(0, 1, 1)
	for j in range(1, keys2.size()):
		if k <= keys2[j][0]:
			var a = keys2[j - 1]
			var b = keys2[j]
			var q: float = (k - a[0]) / (b[0] - a[0])
			match fns[j - 1]:
				"o": q = ease_out(q)
				"i": q = ease_in(q)
				_: q = ease_css(q)
			return Vector3(lerpf(a[1], b[1], q), lerpf(a[2], b[2], q), lerpf(a[3], b[3], q))
	return Vector3(0, 1, 1)

# =====================================================================
#                           MENU
# =====================================================================
func intro() -> void:
	intro_t0 = t
	intro_on = true
	intro_fx = []
	for n in 7:
		intro_fx.append((1 if n % 2 else -1) * (1.15 + randf() * .2) * W)
	mood = 1; moodT = t; hopT = -9.0; nextMood = t + 3.2
	ms = 0.0
	intro_snd = []
	for k in 6:
		intro_snd.append([1.9 + k * .1, [500 + k * 80, .07, "triangle", .05, 200]])
	intro_snd.append([4.95, [300, .18, "sawtooth", .03, 500]]); intro_snd.append([5.2, [300, .18, "sawtooth", .03, 500]])
	intro_snd.append([3.1, [200, .9, "triangle", .05, 900]]); intro_snd.append([4.65, [880, .12, "square", .05, -500]])
	intro_snd.append([5.0, [660, .12, "triangle", .07, 0]]); intro_snd.append([5.09, [880, .12, "triangle", .07, 0]])

func set_mood(i: int) -> void:
	mood = i; moodT = t; hopT = t; nextMood = t + 2.6 + randf() * 1.2

func set_w(d: int) -> void:
	wsel = posmod(wsel + d, N)
	A.snd(500 + wsel * 20, .06, "triangle", .05)
	swapT = t; swapD = d

func house_x(k: int) -> float:
	return 230.0 + k * 100

func n_friends() -> int:
	var n = 0
	for v in S.d.fr:
		if v: n += 1
	return n

func draw_menu(dt: float) -> void:
	if intro_on:
		var el = t - intro_t0
		var keep: Array = []
		for s in intro_snd:
			if el >= s[0]:
				var a: Array = s[1]
				A.snd(a[0], a[1], a[2], a[3], a[4])
			else:
				keep.append(s)
		intro_snd = keep
		if el > 6.4:
			intro_on = false
	if not touch.size():
		ms = clampf(ms + msv, 0, maxf(0, menu_h - VH)); msv *= .92
	# sfondo
	u.fillStyle = "#0b0714"; u.fillRect(0, 0, W, VH)
	u.save(); u.translate(W / 2, 0); u.scale(W * 1.2, VH * .7)
	var g = u.createRadialGradient(0, 0, 0, 0, 0, 1); g.addColorStop(0, "#1d1033"); g.addColorStop(.7, "#0b0714"); g.addColorStop(1, "#0b0714")
	u.fillStyle = g; u.fillRect(-W / 2 / (W * 1.2), 0, 1.0 / 1.2, 1.0 / .7); u.restore()
	u.save(); u.translate(0, -ms)
	var y = 24.0 + top_in - 10
	var cx = W / 2
	var cw = W - 32
	# ---- titolo ----
	var fs = 86.0
	var lh = fs * .95
	y += 4
	var lines = [["KUBO", "#ff5a1f", "#ff5a1f99"], ["RUN", "#ffffff", "#ff5a1f66"]]
	var n = 0
	for li in 2:
		var word: String = lines[li][0]
		var font = "%dpx Bungee" % int(fs)
		var total = tw(word, font)
		var x = cx - total / 2
		var by = y + lh * li + lh * .78
		for ch in word:
			var w = tw(ch, font)
			var d = n * .13
			var el2 = t - intro_t0 - d
			var dx = 0.0
			var hv = Vector3(0, 1, 1)
			var alpha = 1.0
			if intro_on:
				var kx = clampf(el2 / 1.0, 0, 1)
				dx = intro_fx[n] * (1 - cb(.25, .6, .35, 1, kx))
				alpha = 0.0 if el2 < 0 else 1.0
				hv = hy(clampf(el2, 0, 1))
			var wv = 0.0
			var el3 = t - intro_t0 - d - 1.6
			if el3 > 0 or not intro_on:
				var wk = fmod(maxf(0, el3) if intro_on else t - d, 2.8) / 2.8
				wv = -6 * ease_io(1 - absf(wk * 2 - 1))
			u.save(); u.globalAlpha = alpha
			u.translate(x + w / 2 + dx, by - fs * .35 + hv.x + wv); u.scale(hv.y, hv.z); u.translate(-(x + w / 2), -(by - fs * .35))
			u.shadowColor = lines[li][2]; u.shadowBlur = 24
			txt(ch, x, by, font, lines[li][1])
			u.shadowBlur = 0
			u.restore()
			x += w
			n += 1
	y += lh * 2
	# ---- cubo ----
	y += 8
	var cubeR = Rect2(cx - 104, y, 208, 180)
	layout["cube"] = Rect2(cubeR.position - Vector2(0, ms), cubeR.size)
	_btn(Rect2(cubeR.position - Vector2(0, ms), cubeR.size), tap_cube)
	var cel = t - intro_t0 - 1.15
	var cdx = 0.0
	var chv = Vector3(0, 1, 1)
	var calpha = 1.0
	if intro_on:
		cdx = 1.25 * W * (1 - cb(.25, .6, .35, 1, clampf(cel, 0, 1)))
		calpha = 0.0 if cel < 0 else 1.0
		chv = hy(clampf(cel, 0, 1))
	var cwv = 0.0
	if not intro_on or cel > 1.6:
		cwv = -6 * ease_io(1 - absf(fmod((cel - 1.6) if intro_on else t, 2.8) / 2.8 * 2 - 1))
	u.save(); u.globalAlpha = calpha
	u.translate(cubeR.position.x + cdx, cubeR.position.y + chv.x + cwv)
	u.translate(104, 90); u.scale(chv.y, chv.z); u.translate(-104, -90)
	u.scale(208.0 / 300, 180.0 / 260)
	draw_menu_cube()
	u.restore()
	y += 180 + 4
	# ---- motto ----
	var words = [["Corri,", "#ff7a3d"], ["salta,", "#38d8f0"], ["agganciati,", "#7ee07a"], ["entra", "#ffffff"], ["nel", "#ffffff"], ["portale", "#ff5aa8"]]
	var tf = "700 27px Fredoka"
	var space = tw(" ", tf)
	var rows: Array = [[]]
	var rw = 0.0
	for wd in words:
		var ww = tw(wd[0], tf)
		if rw > 0 and rw + space + ww > cw:
			rows.append([]); rw = 0
		rows[-1].append([wd[0], wd[1], ww])
		rw += (space if rw > 0 else 0.0) + ww
	var wi = 0
	for row in rows:
		var tot = 0.0
		for wd in row:
			tot += wd[2]
		tot += space * (row.size() - 1)
		var x = cx - tot / 2
		for wd in row:
			var a = anim("pop", 1.9 + wi * .1, .55)
			push_anim(a, x + wd[2] / 2, y + 16)
			u.shadowColor = "#0008"; u.shadowBlur = 10
			txt(wd[0], x, y + 25, tf, wd[1])
			u.shadowBlur = 0
			u.restore()
			x += wd[2] + space
			wi += 1
		y += 33
	y += 20
	# ---- villaggio ----
	var av = anim("up", 2.35, .6)
	push_anim(av, cx, y + 100)
	var nf = n_friends()
	var nk = 0
	for v in S.d.kids:
		nk += (int(v) & 1) + ((int(v) >> 1) & 1) + ((int(v) >> 2) & 1)
	txt("CUBOLANDIA", 16, y + 13, "13px Bungee", "#ffffff")
	txt("👥 %d/%d amici · 🧒 %d/%d cubetti" % [nf, N, nk, N * 3], W - 16, y + 13, "12px Fredoka", "#d6cdea", "right")
	y += 22
	var vr = Rect2(16, y, cw, 210)
	layout["vil"] = Rect2(vr.position - Vector2(0, ms), vr.size)
	VIL.w = cw; VIL.h = 210.0
	u.shadowColor = "#0006"; u.shadowOffsetY = 10; u.shadowBlur = 30
	rr(vr.position.x, vr.position.y, vr.size.x, vr.size.y, 18, "#000000")
	u.shadowBlur = 0; u.shadowOffsetY = 0
	u.save(); u.translate(vr.position.x, vr.position.y)
	u.beginPath(); u.roundRect(0, 0, cw, 210, 18); u.clip()
	draw_village()
	u.restore()
	rr(vr.position.x - 1, vr.position.y - 1, vr.size.x + 2, vr.size.y + 2, 19, null, "#ffffff14", 2)
	u.restore()
	y += 210 + 18
	# ---- selezione mondo ----
	var a1 = anim("inL", 3.0, .6)
	push_anim(a1, 60, y)
	txt("SELEZIONA MONDO", 16, y + 13, "13px Bungee", "#ffffff"); u.restore()
	var a2 = anim("inR", 3.0, .6)
	push_anim(a2, W - 40, y)
	txt("%d/%d" % [wsel + 1, N], W - 16, y + 13, "700 13px Fredoka", "#f5c518", "right"); u.restore()
	y += 16 + 8
	# ---- cerchio del mondo ----
	var bs = minf(W * .86, 340)
	var br = Rect2(cx - bs / 2, y, bs, bs)
	layout["wcv"] = Rect2(br.position - Vector2(0, ms), br.size)
	var aw = anim("spin", 3.1, 1.2)
	var sw = clampf((t - swapT) / .45, 0, 1)
	if sw < 1:
		var e = cb(.3, 1.4, .5, 1, sw)
		aw = [aw[0] * lerpf(.2, 1, e), aw[1] + (-50 if swapD < 0 else 50) * (1 - e), aw[2], aw[3] * lerpf(.8, 1, e), aw[4] + deg_to_rad(-35 if swapD < 0 else 35) * (1 - e)]
	push_anim(aw, cx, y + bs / 2)
	u.save(); u.translate(br.position.x, br.position.y); u.scale(bs / 600, bs / 600)
	draw_world()
	u.restore()
	draw_world_inside(br)
	u.restore()
	# frecce
	for s in [-1, 1]:
		var ax = 16 - 4 + 22.0 if s < 0 else W - 16 + 4 - 22.0
		var ay = y + bs / 2
		var aa = anim("inL" if s < 0 else "inR", 3.9, .6)
		push_anim(aa, ax, ay)
		u.fillStyle = "#0b0714aa"; u.beginPath(); u.arc(ax, ay, 22, 0, 7); u.fill(); u.strokeStyle = "#ffffff33"; u.lineWidth = 1; u.stroke()
		txt("‹" if s < 0 else "›", ax, ay + 1, "700 22px Fredoka", "#ffffff", "center", "middle")
		u.restore()
		_btn(Rect2(ax - 22, ay - 22 - ms, 44, 44), set_w.bind(s))
	y += bs
	# ---- puntini ----
	y += 14
	var dw = 0.0
	for i in N:
		dw += (22.0 if i == wsel else 8.0) + (4.0 if i < N - 1 else 0.0)
	var rowsd: Array = []
	if dw > 330:
		rowsd = [range(0, 11), range(11, 22)]
	else:
		rowsd = [range(0, N)]
	for rws in rowsd:
		var tot = 0.0
		for i in rws:
			tot += (22.0 if i == wsel else 8.0) + 4
		tot -= 4
		var x = cx - tot / 2
		for i in rws:
			var dw2 = 22.0 if i == wsel else 8.0
			var ad = anim("pop", 3.6 + i * .035, .4)
			push_anim(ad, x + dw2 / 2, y + 4)
			rr(x, y, dw2, 8, 4, "#2ee6c5" if i == wsel else ("#ffffff55" if i < S.d.unlocked else "#ffffff22"))
			u.restore()
			x += dw2 + 4
		y += 12
	y += 8
	# ---- pulsanti in basso ----
	var best = 0
	for b in S.d.best:
		best = maxi(best, int(b))
	var pills = [
		["🏆 BEST %dm · %d/%d" % [best, S.d.unlocked, N], "#f5c518", "#3a2600", "inL", 4.95, _best_btn],
		["🔊" if S.d.sound else "🔇", "#ff5a1f", "#ffffff", "pop", 5.1, toggle_sound],
		["? Come si gioca", "#2ee6c5", "#003333", "inR", 5.2, _set_ov.bind("how")],
		["🎬 STORIA", "#2b2142", "#ffffff", "pop", 5.45, play_cine.bind(null)],
		["◆ %d · SKIN" % S.d.gems, "#7c4dff", "#ffffff", "pop", 5.35, _set_ov.bind("shop")]]
	var pf = "700 14px Fredoka"
	var prow: Array = [[]]
	var pw = 0.0
	for pl in pills:
		var w = 44.0 if pl[1] == "#ff5a1f" else tw(pl[0], pf) + 32
		if pw > 0 and pw + 8 + w > cw:
			prow.append([]); pw = 0
		prow[-1].append([pl, w])
		pw += (8.0 if pw > 0 else 0.0) + w
	y += 10
	for row in prow:
		var tot = 0.0
		for it in row:
			tot += it[1]
		tot += 8 * (row.size() - 1)
		var x = cx - tot / 2
		for it in row:
			var pl: Array = it[0]
			var w: float = it[1]
			var ap = anim(pl[3], pl[4], .5 if pl[3] == "pop" else .75)
			push_anim(ap, x + w / 2, y + 22)
			if pl[1] == "#f5c518":
				rr(x - 3, y - 3, w + 6, 50, 25, "#f5c51844")
			if pl[1] == "#2ee6c5" or pl[1] == "#7c4dff":
				u.shadowColor = "#2ee6c555" if pl[1] == "#2ee6c5" else "#7c4dff66"; u.shadowBlur = 16
			rr(x, y, w, 44, 22, pl[1], "#ffffff33" if pl[1] == "#2b2142" else null)
			u.shadowBlur = 0
			txt(pl[0], x + w / 2, y + 23, pf, pl[2], "center", "middle")
			u.restore()
			_btn(Rect2(x, y - ms, w, 44), pl[5])
			x += w + 8
		y += 44 + 8
	y += 28 + bot_in
	menu_h = y
	u.restore()

func _best_btn() -> void:
	wsel = mini(S.d.unlocked - 1, N - 1)

func _set_ov(o: String) -> void:
	ov = o
	shop_scroll = 0.0

func _play_sel() -> void:
	if wsel < S.d.unlocked:
		start(wsel)

func _pick_comp(k: int) -> void:
	S.d.comp = k
	S.store()
	A.snd(700, .07, "triangle", .06)

func toggle_sound() -> void:
	S.d.sound = not S.d.sound
	if not S.d.sound:
		A.mus_stop()
	S.store()
	A.snd(700, .08)

func tap_cube() -> void:
	var now = t
	tapN = tapN + 1 if now - tapT < 1.5 else 1
	tapT = now
	if tapN >= 5:
		tapN = 0
		if S.d.unlocked < N:
			S.d.unlocked = N; S.store(); A.sfx("win"); cheat("🔓 TUTTI I 22 MONDI SBLOCCATI!")
		else:
			cheat("Sono già tutti sbloccati!")
	set_mood((mood + 1) % MOODS.size())
	A.snd(520 + mood * 90, .12, "triangle", .07, 200)

func cheat(s: String) -> void:
	cheat_txt = s
	cheat_t = t

func draw_cheat() -> void:
	var k = (t - cheat_t) / 2.8
	var a = 1.0
	var sc = 1.0
	if k < .12:
		a = k / .12; sc = lerpf(.6, 1.08, k / .12)
	elif k < .2:
		sc = lerpf(1.08, 1, (k - .12) / .08)
	elif k > .8:
		a = 1 - (k - .8) / .2
	var f = "16px Bungee"
	var w = minf(W * .9, tw(cheat_txt, f) + 36)
	var x = W / 2
	var y = VH * .32
	u.save(); u.globalAlpha = a; u.translate(x, y); u.scale(sc, sc)
	u.shadowColor = "#ffd43b55"; u.shadowBlur = 30
	rr(-w / 2, -24, w, 48, 16, "#1b1230f0", "#ffd43b", 2)
	u.shadowBlur = 0
	txt(cheat_txt, 0, 1, f, "#ffd43b", "center", "middle")
	u.restore()

func draw_world() -> void:
	var c = u
	var S2 = 600.0
	var th: Array = D.THEMES[wsel]
	var lock: bool = wsel >= S.d.unlocked
	c.save(); c.beginPath(); c.arc(300, 300, 280, 0, 7); c.clip()
	var g = c.createLinearGradient(0, 0, 0, S2); g.addColorStop(0, th[2]); g.addColorStop(1, th[3]); c.fillStyle = g; c.fillRect(0, 0, S2, S2)
	for i in 30:
		c.fillStyle = K.ha("#ffffff", "22" if i % 3 else "55"); c.fillRect((i * 137) % int(S2), (i * 89) % 320, 3, 3)
	c.fillStyle = "#fff"; c.beginPath(); c.arc(150, 150, 24, 0, 7); c.fill()
	c.fillStyle = th[6]; c.beginPath(); c.arc(450, 160, 15 + sin(t * 2) * 2, 0, 7); c.fill()
	for tr in [[150, 110, 330, th[4]], [470, 120, 380, th[4]], [300, 70, 220, th[6]], [220, 50, 160, K.ha(th[5], "aa")]]:
		c.fillStyle = tr[3]; c.beginPath(); c.moveTo(tr[0] - tr[1], S2); c.lineTo(tr[0], S2 - tr[2]); c.lineTo(tr[0] + tr[1], S2); c.fill()
	var sh = c.createLinearGradient(0, 200, 0, S2); sh.addColorStop(0, "#0000"); sh.addColorStop(.35, "#0008"); sh.addColorStop(1, "#000d"); c.fillStyle = sh; c.fillRect(0, 200, S2, 400)
	c.restore()
	c.lineWidth = 12; c.strokeStyle = th[4]; c.shadowColor = th[4]; c.shadowBlur = 30; c.beginPath(); c.arc(300, 300, 282, 0, 7); c.stroke(); c.shadowBlur = 0
	c.fillStyle = "#000"; c.strokeStyle = "#fff"; c.lineWidth = 5; c.beginPath(); c.arc(300, 118 + sin(t * 2) * 5, 56, 0, 7); c.fill(); c.stroke()
	c.font = "54px serif"; c.textAlign = "center"; c.textBaseline = "middle"; c.fillStyle = "#fff"; c.fillText("🔒" if lock else th[1], 300, 121 + sin(t * 2) * 5)
	c.textBaseline = "alphabetic"
	if lock:
		c.fillStyle = "#0008"; c.beginPath(); c.arc(300, 300, 276, 0, 7); c.fill()

func draw_world_inside(br: Rect2) -> void:
	var th: Array = D.THEMES[wsel]
	var lock: bool = wsel >= S.d.unlocked
	var x0 = br.position.x + br.size.x * .15
	var iw = br.size.x * .7
	var y = br.position.y + br.size.y * .35
	var ybot = br.position.y + br.size.y * (1 - .105)
	var cx = x0 + iw / 2
	var st: Array = S.d.st[wsel]
	var stars = ""
	for k in 3:
		stars += "★" if st[k] else "☆"
	var a = anim("pop", 4.25, .5)
	push_anim(a, cx, y + 10)
	u.shadowColor = "#000"; u.shadowBlur = 10
	txt(stars, cx, y + 18, "20px Fredoka", "#f5c518", "center"); u.shadowBlur = 0
	u.restore()
	y += 24
	var a2 = anim("up", 4.35, .5)
	push_anim(a2, cx, y)
	u.shadowColor = "#000"; u.shadowBlur = 8
	txt("%s · LIVELLO %d" % [str(th[0]).to_upper(), wsel + 1], cx, y + 14, "15px Bungee", th[5], "center"); u.shadowBlur = 0
	u.restore()
	y += 20
	var fr: Dictionary = D.FR[wsel]
	var desc: String
	if lock: desc = "🔒 Completa il mondo precedente per sbloccarlo."
	elif S.d.fr[wsel]: desc = "✔ %s è salvo! %s" % [fr.n, th[7]]
	elif wsel == N - 1: desc = "Il castello del Re Ombra: salva %s!" % fr.n
	elif wsel in Game.CHASE: desc = "Insegui l'Ombretto e salva %s!" % fr.n
	else: desc = "Salva %s, %s!" % [fr.n, fr.tr]
	u.font = "13px Fredoka"
	var dl = K.wrap(u, desc, iw)
	if dl.size() > 2:
		dl = [dl[0], str(dl[1]) + "…"]
	var a3 = anim("up", 4.45, .5)
	push_anim(a3, cx, y)
	u.shadowColor = "#000"; u.shadowBlur = 6
	for k in dl.size():
		txt(dl[k], cx, y + 13 + k * 17, "13px Fredoka", "#eee6ff", "center")
	u.shadowBlur = 0
	u.restore()
	y += 17 * dl.size() + 4
	var ch = D.ch_of(wsel)
	var f: Array = S.d.st[wsel]
	var obs = [["🚩%dm" % D.goal_of(wsel), f[0]], ["◆%d" % ch.gems, f[1]], ["x%d" % ch.combo, f[2]], ["💠", S.d.sec[wsel]]]
	var bf = "12px Fredoka"
	var tot = 0.0
	for o in obs:
		tot += tw(o[0], bf) + 6
	var x = cx - tot / 2
	var a4 = anim("up", 4.55, .5)
	push_anim(a4, cx, y)
	for o in obs:
		u.globalAlpha = (1.0 if o[1] else .55) * a4[0]
		txt(o[0], x + 3, y + 12, bf, "#ffd43b" if o[1] else "#ffc9a8")
		x += tw(o[0], bf) + 6
	u.restore()
	# pulsante gioca
	var pf = "18px Bungee"
	var label = "BLOCCATO" if lock else "GIOCA"
	var bw = tw(label, pf) + 60
	var bh = 48.0
	var bx = cx - bw / 2
	var by = ybot - bh
	var a5 = anim("drop", 4.65, .8)
	var gl = 0.0 if lock else (1 - absf(fmod(t, 1.8) / 1.8 * 2 - 1))
	gl = ease_io(gl)
	push_anim(a5, cx, by + bh / 2)
	u.save(); u.translate(cx, by + bh / 2); u.scale(1 + gl * .04, 1 + gl * .04); u.translate(-cx, -(by + bh / 2))
	if lock:
		rr(bx, by + 6, bw, bh, 16, "#2a1f38"); rr(bx, by, bw, bh, 16, "#4a3a5e")
		txt(label, cx, by + bh / 2 + 1, pf, "#a99bc2", "center", "middle")
	else:
		u.shadowColor = "#ff5a1f66" if gl < .5 else "#ff5a1fbb"; u.shadowBlur = 30 + gl * 14
		rr(bx, by + 6, bw, bh, 16, "#b33a0c")
		u.shadowBlur = 0
		rr(bx, by, bw, bh, 16, "#ff5a1f")
		txt(label, cx, by + bh / 2 + 1, pf, "#ffffff", "center", "middle")
	u.restore()
	u.restore()
	_btn(Rect2(bx, by - ms, bw, bh), _play_sel, "play")

func draw_menu_cube() -> void:
	var c = u
	var m: String = MOODS[mood]
	var SS = 140.0
	var lt = t - moodT
	var sk = D.cur_skin(t)
	if t > nextMood:
		set_mood((mood + 1) % MOODS.size())
	var hp = t - hopT
	var hop = -sin(hp / .4 * PI) * 22 if hp < .4 else 0.0
	var bob = sin(t * 1.4) * 3 if m == "sleep" else sin(t * 2.2) * 2
	var shake = sin(t * 40) * 1.4 if m == "angry" else 0.0
	c.save(); c.translate(150 + shake, 140 + bob + hop); c.rotate(-.05 if m == "angry" else (sin(t * 3) * .05 if m == "happy" else 0.0))
	var sq = 1.08 if (hp < .4 and hp > .32) else 1.0
	c.scale(sq, 1 / sq)
	c.fillStyle = "#00000055"; c.fillRect(-SS / 2 + 6, -SS / 2 + 8, SS, SS)
	c.lineWidth = 6; c.strokeStyle = "#0a0505"; c.fillStyle = sk.b; c.beginPath(); c.roundRect(-SS / 2, -SS / 2, SS, SS, 10); c.fill(); c.stroke()
	c.save(); c.clip(); c.fillStyle = sk.t; c.fillRect(-SS / 2, -SS / 2, SS, SS * .12); c.fillStyle = sk.d; c.fillRect(-SS / 2, SS / 2 - SS * .12, SS, SS * .12); c.restore()
	var ink = "#0a0505"
	var ex = SS * .22
	var ey = -SS * .08
	match m:
		"sleep":
			for s in [-1, 1]:
				_mbrow(c, s * ex, ey, s * .08, 4, 32, -SS * .22)
				_mbox(c, s * ex, ey, 30, 16)
				c.fillStyle = ink; c.beginPath(); c.arc(s * ex + 2, ey + 3, 4, 0, 7); c.fill()
			var br2 = 1 + sin(t * 1.4) * .15
			c.fillStyle = ink; c.beginPath(); c.ellipse(0, SS * .2, 10 * br2, 8 * br2, 0, 0, 7); c.fill()
			c.fillStyle = "#8b93a7"
			for k in 2:
				var z = fmod(t * .5 + k * .5, 1.0)
				c.globalAlpha = 1 - z; c.font = "%dpx Bungee" % (18 + k * 12); c.textAlign = "left"; c.fillText("z", SS * .42 + z * 18, -SS * .5 - z * 40)
			c.globalAlpha = 1
		"love":
			for s in [-1, 1]:
				_mbrow(c, s * ex, ey, 0, 8, 34, -SS * .26)
				var p = 1 + sin(t * 8) * .1
				c.fillStyle = "#ffd43b"; K.heart(c, s * ex, ey - 4, 36 * p); c.fill(); c.lineWidth = 2; c.strokeStyle = "#e6a800"; c.stroke()
			c.fillStyle = ink; c.beginPath(); c.moveTo(-18, SS * .15); c.lineTo(18, SS * .15); c.arc(0, SS * .15, 18, 0, PI); c.fill()
			for k in 3:
				var z = fmod(t * .6 + k / 3.0, 1.0)
				c.globalAlpha = 1 - z; c.fillStyle = "#ff5a7a"; K.heart(c, -SS * .5 + k * SS * .5, -SS * .55 - z * 50, 14); c.fill()
			c.globalAlpha = 1
		"angry":
			_mbrow(c, -ex, ey, .35, 9, 38, -SS * .2); _mbrow(c, ex, ey, -.35, 9, 38, -SS * .2)
			for s in [-1, 1]:
				_mbox(c, s * ex, ey, 30, 14)
				c.fillStyle = ink; c.fillRect(s * ex - 9, ey - 2, 18, 5)
			_mblush(c, SS)
			c.strokeStyle = ink; c.lineWidth = 3; c.beginPath(); c.moveTo(-14, SS * .2)
			for k in range(1, 5):
				c.lineTo(-14 + k * 7, SS * .2 + (-6 if k % 2 else 0))
			c.stroke()
			c.save(); c.translate(SS * .42, -SS * .5)
			var ps = 1 + sin(t * 10) * .08
			c.scale(ps, ps); c.strokeStyle = "#e03131"; c.lineWidth = 6; c.lineCap = "round"
			for k in 4:
				c.rotate(PI / 2); c.beginPath(); c.arc(9, 9, 8, PI, PI * 1.5); c.stroke()
			c.restore()
			for s in [-1, 1]:
				var z = fmod(t * 1.6, 1.0)
				c.globalAlpha = 1 - z; c.fillStyle = "#e9ecef"; c.beginPath(); c.arc(s * (SS / 2 + 8 + z * 22), -4, 6 + z * 6, 0, 7); c.fill()
			c.globalAlpha = 1
		"happy":
			c.strokeStyle = ink; c.lineWidth = 6; c.lineCap = "round"
			for s in [-1, 1]:
				c.beginPath(); c.arc(s * ex, ey + 6, 11, PI * 1.1, PI * 1.9); c.stroke()
			_mblush(c, SS); c.fillStyle = ink; c.beginPath(); c.moveTo(-24, SS * .08); c.lineTo(24, SS * .08); c.arc(0, SS * .08, 24, 0, PI); c.fill()
			c.fillStyle = "#ff6b6b"; c.beginPath(); c.arc(0, SS * .08 + 18, 10, PI, 0); c.fill()
		"wow":
			for s in [-1, 1]:
				_mbrow(c, s * ex, ey, s * -.15, 6, 30, -SS * .3)
				c.fillStyle = "#fff"; c.beginPath(); c.arc(s * ex, ey, 15, 0, 7); c.fill(); c.lineWidth = 4; c.strokeStyle = ink; c.stroke()
				c.fillStyle = ink; c.beginPath(); c.arc(s * ex + sin(t * 3) * 4, ey, 5, 0, 7); c.fill()
			c.fillStyle = ink; c.beginPath(); c.ellipse(0, SS * .22, 12, 15, 0, 0, 7); c.fill()
			c.fillStyle = "#74c0fc"; c.beginPath(); c.ellipse(SS * .4, -SS * .32 + fmod(t * .8, 1.0) * 20, 5, 8, 0, 0, 7); c.fill()
		_:
			_mbrow(c, -ex, ey, 0, 7, 32, -SS * .22); _mbrow(c, ex, ey, -.15, 7, 32, -SS * .22)
			_mbox(c, -ex, ey, 30, 18)
			c.fillStyle = ink; c.fillRect(-ex - 4, ey - 4, 9, 9)
			c.strokeStyle = ink; c.lineWidth = 6; c.lineCap = "round"; c.beginPath(); c.arc(ex, ey + 6, 11, PI * 1.1, PI * 1.9); c.stroke()
			_mblush(c, SS); c.lineWidth = 5; c.beginPath(); c.arc(0, SS * .1, 18, .2, PI - .2); c.stroke()
			if lt < .6:
				c.fillStyle = "#ffd43b"; c.font = "26px serif"; c.textAlign = "left"; c.fillText("✦", SS * .42, -SS * .42)
	c.lineCap = "butt"
	K.drawHat(c, sk, SS, t)
	c.restore()

func _mbox(c: Ctx, x: float, ey: float, w: float, h: float) -> void:
	c.fillStyle = "#fff"; c.fillRect(x - w / 2, ey - h / 2, w, h); c.lineWidth = 4; c.strokeStyle = "#0a0505"; c.strokeRect(x - w / 2, ey - h / 2, w, h)

func _mbrow(c: Ctx, x: float, ey: float, ang: float, th: float, ln: float, dy: float) -> void:
	c.save(); c.translate(x, ey + dy); c.rotate(ang); c.fillStyle = "#0a0505"; c.fillRect(-ln / 2, -th / 2, ln, th); c.restore()

func _mblush(c: Ctx, SS: float) -> void:
	c.fillStyle = "#ff6b9a99"
	for s in [-1, 1]:
		c.beginPath(); c.ellipse(s * SS * .33, SS * .14, 11, 7, 0, 0, 7); c.fill()

# =====================================================================
#                           VILLAGGIO
# =====================================================================
func vil_pos(k, tt: float) -> Vector2:
	if typeof(k) == TYPE_STRING and k == "nonno":
		return Vector2(95, VIL.h * .78)
	var hx = house_x(k)
	return Vector2(hx + sin(tt * .5 + k * 1.7) * 32, VIL.h * .83)

func vil_tap(x: float, y: float) -> void:
	var best = null
	var bd = 30.0
	var cand: Array = ["nonno"]
	for k in N:
		if S.d.fr[k]:
			cand.append(k)
	for k in cand:
		var p = vil_pos(k, t)
		var d = Vector2(p.x - x, p.y - 12 - y).length()
		if d < bd:
			bd = d; best = k
	if best == null:
		for k in N:
			if absf(house_x(k) - x) < 32 and y < VIL.h * .8:
				best = "h%d" % k
				break
	if best == null:
		return
	VIL.bub = {"k": best, "t": t}
	A.snd(660 + randf() * 200, .07, "triangle", .06)

func draw_village() -> void:
	var c = u
	var w: float = VIL.w
	var h: float = VIL.h
	if VIL.target != null:
		VIL.x += (VIL.target - VIL.x) * .06
		if absf(VIL.target - VIL.x) < 1:
			VIL.target = null
	if VIL.down == null:
		VIL.x += VIL.v; VIL.v *= .92
	VIL.x = clampf(VIL.x, 0, VW - w)
	var nf = n_friends()
	var col = nf / float(N)
	var g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, K.mix("#2b2b38", "#4dabf7", col)); g.addColorStop(1, K.mix("#3d3d48", "#ffd8a8", col)); c.fillStyle = g; c.fillRect(0, 0, w, h)
	K.circ(c, w * .82, 34, 20, K.rgba("#ffd43b", .15 + col * .85))
	if nf < N:
		c.globalAlpha = .25 + .65 * (1 - col)
		for k in 9:
			K.circ(c, fposmod(k * 137 - VIL.x * .15, w + 160) - 80, 18 + sin(k * 2) * 10, 34 + ((k * 31) % 22), "#1a1424")
		var ex = w * .35 + sin(t * .4) * 30
		c.fillStyle = "#ff2b4a"; c.beginPath(); c.ellipse(ex - 12, 26, 6, 2.6, .3, 0, 7); c.ellipse(ex + 12, 26, 6, 2.6, -.3, 0, 7); c.fill(); c.globalAlpha = 1
	c.fillStyle = K.mix("#44444f", "#69db7c", col * .8); c.beginPath(); c.moveTo(0, h)
	var x = 0.0
	while x <= w + 20:
		c.lineTo(x, h * .58 - sin((x + VIL.x * .3) * .02) * 14); x += 20
	c.lineTo(w, h); c.fill()
	c.fillStyle = K.mix("#4a4a54", "#8ce99a", col * .75); c.fillRect(0, h * .72, w, h * .28)
	c.fillStyle = K.mix("#5c5c66", "#f2d39b", col * .85); c.fillRect(0, h * .8, w, h * .1)
	c.save(); c.translate(-VIL.x, 0)
	var fx = 150.0
	var fy = h * .8
	c.fillStyle = K.mix("#6c757d", "#ced4da", col); c.beginPath(); c.ellipse(fx, fy, 34, 9, 0, 0, 7); c.fill(); c.fillRect(fx - 4, fy - 28, 8, 28); K.circ(c, fx, fy - 30, 10, K.mix("#6c757d", "#ced4da", col))
	if nf > 0:
		for k in 6:
			var a = fmod(t * 2 + k, 1.0)
			K.circ(c, fx + (k - 2.5) * 5 * a, fy - 34 + a * 30 - sin(a * PI) * 12, 2, K.rgba("#74c0fc", 1 - a))
	c.font = "10px Bungee"; c.textAlign = "center"; c.fillStyle = "#ffffffcc"; c.fillText("CUBOLANDIA", fx, h * .95)
	for k in N:
		var hx = house_x(k)
		if hx + 60 < VIL.x or hx - 60 > VIL.x + w:
			continue
		var ok: bool = S.d.fr[k]
		var fc = D.FR[k].c if ok else "#6c6c78"
		var by = h * .75
		c.fillStyle = K.mix(fc, "#000000", .15); c.fillRect(hx - 28, by - 40, 56, 40); K.poly(c, [hx - 34, by - 40, hx, by - 64, hx + 34, by - 40], K.mix(fc, "#000000", .35) if ok else "#4a4a55")
		c.fillStyle = "#2b2b33"; c.fillRect(hx - 7, by - 20, 14, 20); c.fillStyle = "#ffe066" if ok else "#3a3a44"; c.fillRect(hx - 22, by - 32, 10, 9); c.fillRect(hx + 12, by - 32, 10, 9)
		if not ok:
			c.strokeStyle = "#5a4a3a"; c.lineWidth = 2; c.beginPath(); c.moveTo(hx - 9, by - 18); c.lineTo(hx + 9, by - 4); c.moveTo(hx + 9, by - 18); c.lineTo(hx - 9, by - 4); c.stroke()
		c.font = "8px Bungee"; c.fillStyle = "#fff" if ok else "#9a9aa6"; c.textAlign = "center"; c.fillText(str(D.FR[k].n).to_upper() if ok else "?", hx, by - 44 - 26)
	var nk = 0
	for k in N:
		for b in 3:
			if int(S.d.kids[k]) & (1 << b):
				var kx = 40 + ((nk * 53) % 200)
				var ky = h * .86 - absf(sin(t * 4 + nk)) * 8
				var hh = float((nk * 67) % 360)
				K.drawCube(c, kx, ky, 10, "happy", t + nk, 0, {"b": K.hsl(hh, 75, 60), "t": K.hsl(hh, 80, 75), "d": K.hsl(hh, 70, 40), "hat": ""})
				nk += 1
	var pn = vil_pos("nonno", t)
	K.drawCube(c, pn.x, pn.y - 12, 24, "happy", t, 0, D.nonno_skin())
	for k in N:
		if S.d.fr[k]:
			var p = vil_pos(k, t)
			K.drawCube(c, p.x, p.y - 11 - absf(sin(t * 3 + k)) * 3, 20, "happy", t + k, 0, D.friend_skin(k))
	var B = VIL.bub
	if B != null and t - B.t < 4.2:
		var k = B.k
		var xx: float
		if typeof(k) == TYPE_STRING and k == "nonno": xx = 95
		elif typeof(k) == TYPE_STRING: xx = house_x(int(k.substr(1)))
		else: xx = vil_pos(k, t).x
		if xx > VIL.x - 10 and xx < VIL.x + w + 10:
			var bx: float
			var byy: float
			var y: float
			var name: String
			var text: String
			var colr = "#ffffff"
			if typeof(k) == TYPE_STRING and k == "nonno":
				var p = vil_pos("nonno", t)
				x = p.x; y = p.y - 32; name = "NONNO GRIGIO"; text = D.J.NONNO_L[int(floor(B.t)) % D.J.NONNO_L.size()]
			elif typeof(k) == TYPE_STRING:
				var kk = int(k.substr(1))
				x = house_x(kk); y = h * .75 - 70; name = "CASA DI " + str(D.FR[kk].n).to_upper(); text = "È prigioniero nel mondo %d: %s!" % [kk + 1, D.THEMES[kk][0]]
			else:
				var p = vil_pos(k, t)
				var f: Dictionary = D.FR[k]
				x = p.x; y = p.y - 30; name = str(f.n).to_upper() + " · " + f.tr; text = "%s (%s %s)" % [f.line, D.J.PWIC[f.pw], D.J.PWD[f.pw]]; colr = f.c
			c.font = "12px Fredoka"
			var lines = K.wrap(c, text, 170)
			var bw = 190.0
			var bh = 22.0 + lines.size() * 14
			bx = maxf(VIL.x + 6, minf(VIL.x + w - bw - 6, x - bw / 2))
			byy = maxf(4, y - bh - 8)
			c.fillStyle = "#ffffff"; c.beginPath(); c.roundRect(bx, byy, bw, bh, 10); c.fill(); K.poly(c, [x - 6, byy + bh - 1, x + 6, byy + bh - 1, x, byy + bh + 7], "#ffffff")
			c.textAlign = "left"; c.font = "9px Bungee"; c.fillStyle = "#5c5f66" if str(colr) == "#ffffff" else K.mix(colr, "#000000", .25); c.fillText(name, bx + 10, byy + 14)
			c.font = "12px Fredoka"; c.fillStyle = "#1b1230"
			for j in lines.size():
				c.fillText(lines[j], bx + 10, byy + 29 + j * 14)
			c.textAlign = "center"
	c.restore()
	if VIL.x < 10 and VIL.down == null:
		c.font = "11px Fredoka"; c.fillStyle = "#ffffffaa"; c.textAlign = "right"; c.fillText("trascina ⟶", w - 8, h - 6)
	c.textAlign = "left"

# =====================================================================
#                           HUD
# =====================================================================
func draw_hud(dt: float) -> void:
	var G = game.G
	var p = G.pl
	var pw = p.pw
	var top = top_in
	# barra
	var bx = 12.0
	var bw = W - 12 - 130
	rr(bx, top, bw, 7, 4.5, "#ffffff1a")
	var fw = bw * minf(1, G.maxY / G.goal)
	if fw > 1:
		u.shadowColor = "#2ee6c5"; u.shadowBlur = 10
		u.save(); u.beginPath(); u.roundRect(bx, top, bw, 7, 4.5); u.clip(); u.fillStyle = "#2ee6c5"; u.fillRect(bx, top, fw, 7); u.restore()
		u.shadowBlur = 0
	# torna al menu
	var bl = "🏠 TORNA AL MENU"
	var bf = "700 12px Fredoka"
	var bbw = tw(bl, bf) + 24
	var bby = maxf(6, top - 4)
	rr(W - 10 - bbw, bby, bbw, 34, 17, "#00000088", "#ffffff33")
	txt(bl, W - 10 - bbw / 2, bby + 18, bf, "#ffffff", "center", "middle")
	_btn(Rect2(W - 10 - bbw, bby, bbw, 34), to_menu)
	# metri
	var m = mini(int(floor(p.y / Game.PPM)), D.goal_of(G.i))
	var mt = "%dM / %dM · ♥ %d" % [m, D.goal_of(G.i), maxi(0, G.hearts)]
	var mf = "13px Bungee"
	var mw = tw(mt, mf) + 32
	rr(W / 2 - mw / 2, top + 26, mw, 30, 15, "#00000099")
	txt(mt, W / 2, top + 42, mf, "#ffffff", "center", "middle")
	# gemme
	var gt = "◆ %d" % G.runGems
	var gw = tw(gt, mf) + 24
	rr(12, top + 26, gw, 30, 15, "#00000099")
	txt(gt, 12 + gw / 2, top + 42, mf, "#5ff2ff", "center", "middle")
	# obiettivo
	var ch = G.ch
	var sg = G.secret
	var ot = "%s %s · ◆ %d/%d · x%d/%d%s" % ["✔" if G.freed else ("👾" if G.minion != null else ("🔑" if (G.key != null and G.key.got) else "🔒")), D.FR[G.i].n, G.runGems, ch.gems, G.bestCombo, ch.combo, " · 💠" if sg.got else ""]
	var of = "700 12px Fredoka"
	var ow = tw(ot, of) + 22
	rr(12, top + 62, ow, 26, 13, "#00000099")
	txt(ot, 23, top + 75, of, "#ffffff", "left", "middle")
	# power-up attivi
	var py = top + 96
	var items: Array = []
	if pw.wings > 0: items.append("%s %ds" % [Game.PWI.wings, ceili(pw.wings)])
	if pw.shield: items.append("%s scudo" % Game.PWI.shield)
	if pw.rocket > 0: items.append("%s %ds" % [Game.PWI.rocket, ceili(pw.rocket)])
	if pw.magnet > 0: items.append("%s %ds" % [Game.PWI.magnet, ceili(pw.magnet)])
	for it in items:
		var iw = tw(it, of) + 20
		rr(12, py, iw, 22, 11, "#00000099")
		txt(it, 22, py + 11, of, "#ffffff", "left", "middle")
		py += 26
	# messaggio
	G.toastA = move_toward(G.toastA, 1.0 if G.toast > 0 else 0.0, dt / .3)
	if G.toastA > 0:
		u.globalAlpha = G.toastA
		u.shadowColor = G.toastCol; u.shadowBlur = 12
		txt(G.toastTxt, W / 2, top + 110, "16px Bungee", G.toastCol, "center", "middle")
		u.shadowBlur = 0; u.globalAlpha = 1
	# suggerimento
	G.hintA = move_toward(G.hintA, 1.0 if (G.t < 4 and not G.done and state == "play") else 0.0, dt / .6)
	if G.hintA > 0:
		u.globalAlpha = G.hintA
		var l1 = [["Trascina", "#2ee6c5"], [" ↔ per muoverti · ", "#ffffff"], ["Tocca", "#2ee6c5"], [" per saltare", "#ffffff"]]
		var l2 = [["Tieni premuto", "#2ee6c5"], [" per agganciarti all'anello · rilascia quando la corda è ", "#ffffff"], ["dorata", "#ffd43b"], ["!", "#ffffff"]]
		var hf = "14px Fredoka"
		var hb = "700 14px Fredoka"
		var lines2 = [l1]
		# la seconda riga va spezzata su schermi stretti
		var w2 = 0.0
		for sgm in l2:
			w2 += tw(sgm[0], hb if sgm[1] != "#ffffff" else hf)
		var maxw = W * .92 - 32
		var segs2: Array = []
		if w2 > maxw:
			segs2 = [[["Tieni premuto", "#2ee6c5"], [" per agganciarti all'anello ·", "#ffffff"]], [[" rilascia quando la corda è ", "#ffffff"], ["dorata", "#ffd43b"], ["!", "#ffffff"]]]
		else:
			segs2 = [l2]
		lines2.append_array(segs2)
		var wmax = 0.0
		for ln in lines2:
			var ww = 0.0
			for sgm in ln:
				ww += tw(sgm[0], hb if sgm[1] != "#ffffff" else hf)
			wmax = maxf(wmax, ww)
		var hh = 20 + lines2.size() * 21.7
		var hy2 = VH - 28 - bot_in - hh
		rr(W / 2 - wmax / 2 - 16, hy2, wmax + 32, hh, 16, "#000000b0", "#ffffff22")
		for li in lines2.size():
			var ln: Array = lines2[li]
			var ww = 0.0
			for sgm in ln:
				ww += tw(sgm[0], hb if sgm[1] != "#ffffff" else hf)
			var x = W / 2 - ww / 2
			for sgm in ln:
				var f = hb if sgm[1] != "#ffffff" else hf
				txt(sgm[0], x, hy2 + 10 + li * 21.7 + 15, f, sgm[1])
				x += tw(sgm[0], f)
		u.globalAlpha = 1

# =====================================================================
#                           STORIA
# =====================================================================
func obj_rows(i: int) -> Array:
	var ch = D.ch_of(i)
	var s: Array = S.d.st[i]
	var fr: Dictionary = D.FR[i]
	var rows: Array = []
	var chase = i in Game.CHASE
	rows.append([S.d.fr[i], ("✔" if S.d.fr[i] else ("👾" if chase else "🔑")) + " " + ("Prendi l'Ombretto e salva " if chase else "Trova la chiave e libera ") + fr.n])
	if i == N - 1:
		rows.append([S.d.fr[i], ("✔" if S.d.fr[i] else "👑") + " Sconfiggi il Re Ombra"])
	rows.append([s[0], ("✔" if s[0] else "★") + " Raggiungi il portale a %dm" % D.goal_of(i)])
	rows.append([s[1], ("✔" if s[1] else "★") + " Raccogli %d ◆ in una partita" % ch.gems])
	rows.append([s[2], ("✔" if s[2] else "★") + " Fai una combo x%d" % ch.combo])
	rows.append([S.d.sec[i], ("✔" if S.d.sec[i] else "💠") + " Trova la gemma segreta"])
	return rows

func story(i: int, pages: Array, after: Callable, btn: String, objs: Array, comp: bool) -> void:
	SY.on = true; SY.i = i; SY.pages = pages; SY.pg = 0; SY.after = after; SY.btn = btn; SY.objs = objs; SY.comp = comp; SY.fade = t
	comp_scroll = 0.0
	if comp and S.d.comp >= 0 and (not S.d.fr[S.d.comp] or S.d.comp == i):
		S.d.comp = -1
	show_page()

func show_page() -> void:
	SY.typed = 0
	SY.t0 = t

func story_tap() -> void:
	var p: Dictionary = SY.pages[SY.pg]
	if SY.typed < p.text.length():
		SY.typed = p.text.length()
		return
	if SY.pg < SY.pages.size() - 1:
		SY.pg += 1; show_page(); A.snd(700, .06, "triangle", .05)
		return
	SY.on = false
	A.snd(880, .08, "triangle", .06)
	var f = SY.after
	SY.after = null
	if f != null:
		f.call()

func draw_story() -> void:
	var i: int = SY.i
	var th: Array = D.THEMES[i]
	var p: Dictionary = SY.pages[SY.pg]
	var n = mini(p.text.length(), int(floor((t - SY.t0) / .03)))
	if n > SY.typed:
		SY.typed = n
		if n % 4 == 0 and p.text[n - 1] != " ":
			A.snd(520 if p.get("narr", false) else 760 + randf() * 120, .025, "square", .018)
	var fa = clampf((t - SY.fade) / .35, 0, 1)
	u.save(); u.globalAlpha = fa
	# sfondo radiale
	var g = u.createRadialGradient(W / 2, VH * .28, 0, W / 2, VH * .28, sqrt(W * W + VH * VH) * .5)
	g.addColorStop(0, K.rgba(th[4], .55)); g.addColorStop(.72, K.rgba(th[3], .96)); g.addColorStop(1, K.rgba(th[3], .96))
	u.fillStyle = g; u.fillRect(0, 0, W, VH)
	# misura dei contenuti per centrarli
	var bw = minf(380, W - 36)
	var bx = W / 2 - bw / 2
	u.font = "18px Fredoka"
	var lines = K.wrap(u, p.text, bw - 36)
	var bubh = maxf(79.2, 28 + lines.size() * 24.3)
	var who = p.who
	var spk = ""
	var spkc = "#ffb38a"
	if not p.get("narr", false):
		if typeof(who) == TYPE_STRING and who == "ombra": spk = "RE OMBRA"; spkc = "#ff5a7a"
		elif typeof(who) == TYPE_STRING and who == "nonno": spk = "NONNO GRIGIO"; spkc = "#ced4da"
		elif typeof(who) != TYPE_STRING: spk = str(D.FR[who].n).to_upper(); spkc = D.FR[who].c
		else: spk = "KUBO"
	var objs: Array = SY.objs
	var avail: Array = []
	if SY.comp:
		for k in N:
			if S.d.fr[k] and k != i:
				avail.append(k)
	var hgt = 14 + 10 + 40 + 10 + 136 + 10 + (18 if spk != "" else 0) + bubh + 10 + objs.size() * 37 + (10 if objs.size() else 0) + (104 if avail.size() else 0) + 18
	var y = maxf(24 + top_in - 10, (VH - hgt) / 2)
	txt("MONDO %d · %dM" % [i + 1, D.goal_of(i)], W / 2, y + 11, "12px Bungee", K.rgba("#ffffff", .8), "center")
	y += 24
	u.shadowColor = "#0006"; u.shadowOffsetY = 4
	txt(str(th[0]).to_upper(), W / 2, y + 34, "36px Bungee", th[5], "center")
	u.shadowOffsetY = 0
	y += 46
	# ritratto
	u.save(); u.translate(W / 2 - 85, y); u.scale(170.0 / 300, 136.0 / 240)
	var talking: bool = SY.typed < p.text.length()
	u.fillStyle = "#0000004d"; u.beginPath(); u.ellipse(150, 222, 62, 10, 0, 0, 7); u.fill()
	var sby = 132 + sin(t * 2.4) * 6 - (absf(sin(t * 14)) * 4 if talking else 0.0)
	if typeof(who) == TYPE_STRING and who == "ombra":
		K.drawOmbra(u, 150, sby + 8, 100, t, p.mood)
	else:
		var sk
		if typeof(who) == TYPE_STRING and who == "nonno": sk = D.nonno_skin()
		elif typeof(who) != TYPE_STRING: sk = D.friend_skin(who)
		else: sk = D.cur_skin(t)
		K.drawCube(u, 150, sby, 118, p.mood, t, sin(t * 1.7) * .05, sk)
	if p.mood == "sleep":
		u.font = "28px Bungee"; u.fillStyle = "#cfd4e6"
		var z = fmod(t * .5, 1.0)
		u.globalAlpha = (1 - z) * fa; u.textAlign = "left"; u.fillText("z", 222 + z * 16, 52 - z * 30); u.globalAlpha = fa
	u.restore()
	y += 136 + 10
	if spk != "":
		txt(spk, bx + 8, y + 11, "13px Bungee", spkc)
		y += 18
	# fumetto
	var narr: bool = p.get("narr", false)
	if narr:
		rr(bx, y, bw, bubh, 20, "#120c22ee", "#ffffff33")
	else:
		u.shadowColor = "#0004"; u.shadowOffsetY = 6
		rr(bx, y, bw, bubh, 20, "#ffffff")
		u.shadowOffsetY = 0
		K.poly(u, [W / 2 - 12, y + 1, W / 2 + 12, y + 1, W / 2, y - 12], "#ffffff")
	var shown: String = p.text.substr(0, SY.typed)
	var tl = K.wrap(u, shown, bw - 36) if shown != "" else []
	# per non far "saltare" le parole: uso le righe del testo intero
	var acc = 0
	for li in lines.size():
		var full: String = lines[li]
		var take = clampi(SY.typed - acc, 0, full.length())
		var part = full.substr(0, take)
		acc += full.length() + 1
		if part != "":
			txt(part, bx + 18, y + 14 + 18 + li * 24.3, "18px Fredoka", "#e8e0f7" if narr else "#1b1230")
	y += bubh + 10
	# obiettivi
	for o in objs:
		rr(bx, y, bw, 33, 12, "#00000055", "#ffd43b55" if o[0] else "#ffffff1a")
		txt(o[1], bx + 12, y + 17, "15px Fredoka", "#ffd43b" if o[0] else "#e8e0f7", "left", "middle")
		y += 37
	if objs.size():
		y += 4
	# compagno
	layout["comp"] = Rect2()
	if avail.size():
		var cur = "Nessun compagno"
		if S.d.comp >= 0:
			var cf: Dictionary = D.FR[S.d.comp]
			cur = "%s: %s %s" % [cf.n, D.J.PWIC[cf.pw], D.J.PWD[cf.pw]]
		txt("SCEGLI UN COMPAGNO · ", bx, y + 11, "11px Bungee", "#ffffff")
		txt(cur, bx + tw("SCEGLI UN COMPAGNO · ", "11px Bungee"), y + 11, "13px Fredoka", "#ffd43b")
		y += 18
		var row: Array = [-1]
		row.append_array(avail)
		var total = row.size() * 70.0
		comp_scroll = clampf(comp_scroll, 0, maxf(0, total - bw))
		layout["comp"] = Rect2(bx, y, bw, 76)
		u.save(); u.beginPath(); u.rect(bx - 2, y - 2, bw + 4, 80); u.clip()
		var x = bx - comp_scroll
		for k in row:
			var on: bool = S.d.comp == k
			rr(x, y, 64, 70, 12, "#ffd43b22" if on else "#00000055", "#ffd43b" if on else "#ffffff22", 2)
			if k < 0:
				txt("✕", x + 32, y + 26, "20px Fredoka", "#ffffff", "center", "middle")
				txt("Nessuno", x + 32, y + 58, "11px Fredoka", "#ffffff", "center", "middle")
			else:
				u.save(); u.translate(x + 12, y + 4); u.scale(.5, .5); K.drawCube(u, 40, 44, 40, "happy", 1, 0, D.friend_skin(k)); u.restore()
				txt(str(D.FR[k].n), x + 32, y + 58, "11px Fredoka", "#ffffff", "center", "middle")
			if x + 64 > bx and x < bx + bw:
				btns.append({"r": Rect2(maxf(x, bx), y, 64, 70), "f": _pick_comp.bind(k), "n": "comp"})
			x += 70
		u.restore()
		y += 76 + 10
	# tocca
	var bl = 1.0 - .65 * (1 - absf(fmod(t, 1.2) / 1.2 * 2 - 1))
	u.globalAlpha = fa * bl
	txt("TOCCA ▸" if SY.pg < SY.pages.size() - 1 else SY.btn, W / 2, y + 18, "14px Bungee", "#ffffff", "center")
	u.globalAlpha = fa
	u.restore()

# =====================================================================
#                           OVERLAY (vittoria, sconfitta, negozio, guida)
# =====================================================================
func _card_begin(h: float) -> Array:
	u.fillStyle = "#0b0714cc"; u.fillRect(0, 0, W, VH)
	var cw = minf(340, W - 40)
	var x = W / 2 - cw / 2
	var y = maxf(20, (VH - h) / 2)
	rr(x, y, cw, h, 24, "#1b1230", "#ffffff22")
	return [x, y, cw]

func _b2(x: float, y: float, w: float, label: String, bg, fg, f: Callable) -> void:
	rr(x, y, w, 48, 14, bg)
	txt(label, x + w / 2, y + 25, "15px Bungee", fg, "center", "middle")
	_btn(Rect2(x, y, w, 48), f)

func draw_overlay() -> void:
	btns = btns.filter(func(b): return b.get("n", "") == "__none")
	match ov:
		"win": _ov_win()
		"lose": _ov_lose()
		"shop": _ov_shop()
		"how": _ov_how()

func _ov_win() -> void:
	var i: int = winfo.i
	var rows = obj_rows(i)
	var h = 24 + 16 + 12 + 26 + 12 + 22 + 12 + 22 + 12 + 40 + 12 + rows.size() * 39 + 12 + (48 + 12) * (3 if i + 1 < N else 2) + 12
	var cb2 = _card_begin(h)
	var x: float = cb2[0] + 22
	var y: float = cb2[1] + 24
	var w: float = cb2[2] - 44
	var cx: float = cb2[0] + cb2[2] / 2
	txt("KUBO RUN", cx, y + 11, "12px Bungee", "#ff5a1f", "center"); y += 16 + 12
	txt("🎉 LIVELLO COMPLETATO!", cx, y + 20, "21px Bungee", "#ffffff", "center"); y += 26 + 12
	txt(winfo.m, cx, y + 16, "16px Fredoka", "#d6cdea", "center"); y += 22 + 12
	u.font = "16px Fredoka"
	for ln in K.wrap(u, winfo.x, w):
		txt(ln, cx, y + 16, "16px Fredoka", "#d6cdea", "center"); y += 20
	y += 12
	var st = ""
	for k in 3:
		st += "★" if S.d.st[i][k] else "☆"
	txt(st, cx, y + 32, "34px Fredoka", "#f5c518", "center"); y += 40 + 12
	for o in rows:
		rr(x, y, w, 35, 12, "#00000055", "#ffd43b55" if o[0] else "#ffffff1a")
		txt(o[1], x + 12, y + 18, "15px Fredoka", "#ffd43b" if o[0] else "#e8e0f7", "left", "middle")
		y += 39
	y += 12
	_b2(x, y, w, "RIGIOCA", "#ff5a1f", "#ffffff", start.bind(i, false, true)); y += 60
	if i + 1 < N:
		_b2(x, y, w, "PROSSIMO LIVELLO →", "#2ee6c5", "#003333", start.bind(mini(i + 1, N - 1), false, false)); y += 60
	_b2(x, y, w, "MENU", "#2b2142", "#ffffff", to_menu)

func _ov_lose() -> void:
	var h = 24 + 28 + 38 + 34 + 34 + 12 + 60 * (3 if winfo.cp else 2) + 12
	var cb2 = _card_begin(h)
	var x: float = cb2[0] + 22
	var y: float = cb2[1] + 24
	var w: float = cb2[2] - 44
	var cx: float = cb2[0] + cb2[2] / 2
	var i: int = game.G.i
	txt("KUBO RUN", cx, y + 11, "12px Bungee", "#ff5a1f", "center"); y += 28
	txt("💥 KUBO È KO!", cx, y + 20, "21px Bungee", "#ffffff", "center"); y += 38
	txt(winfo.m, cx, y + 16, "16px Fredoka", "#d6cdea", "center"); y += 34
	txt(winfo.x, cx, y + 16, "16px Fredoka", "#d6cdea", "center"); y += 34 + 12
	if winfo.cp:
		_b2(x, y, w, "RIPRENDI DAL CHECKPOINT", "#ff5a1f", "#ffffff", start.bind(i, true, false)); y += 60
	_b2(x, y, w, "RICOMINCIA", "#2ee6c5", "#003333", start.bind(i, false, true)); y += 60
	_b2(x, y, w, "MENU", "#2b2142", "#ffffff", to_menu)

func _ov_shop() -> void:
	var gh = minf(VH * .5, 3 * 112.0 + 16)
	var h = 24 + 30 + 12 + 22 + 12 + gh + 12 + 48 + 24
	var cb2 = _card_begin(h)
	var x: float = cb2[0] + 22
	var y: float = cb2[1] + 24
	var w: float = cb2[2] - 44
	var cx: float = cb2[0] + cb2[2] / 2
	var sh = 0.0
	var k0 = (t - shop_shake) / .35
	if k0 < 1:
		sh = sin(k0 * PI * 2) * -8
	u.save(); u.translate(sh, 0)
	txt("NEGOZIO SKIN", cx, y + 22, "21px Bungee", "#ffffff", "center"); y += 30 + 12
	txt("◆ %d gemme" % S.d.gems, cx, y + 16, "16px Fredoka", "#d6cdea", "center"); y += 22 + 12
	var cols = 3
	var gap = 8.0
	var cwid = (w - gap * 2) / cols
	var chh = 104.0
	var rows = ceili(D.SKINS.size() / float(cols))
	var total = rows * (chh + gap)
	shop_scroll = clampf(shop_scroll, 0, maxf(0, total - gh))
	u.save(); u.beginPath(); u.rect(x - 2, y, w + 4, gh); u.clip()
	for i in D.SKINS.size():
		var k: Dictionary = D.SKINS[i]
		var own = D.skin_owned(i)
		var col = i % cols
		var row = i / cols
		var sx = x + col * (cwid + gap)
		var sy2 = y + row * (chh + gap) - shop_scroll
		var on: bool = S.d.skin == i
		rr(sx, sy2, cwid, chh, 14, "#1f3a44" if on else "#2b2142", "#2ee6c5" if on else null, 2)
		u.save(); u.translate(sx + cwid / 2 - 32, sy2 + 4); u.scale(.5, .5); K.drawCube(u, 64, 76, 58, "happy", 1, 0, D.skin_col(k, i * .5)); u.restore()
		txt(k.n, sx + cwid / 2, sy2 + 80, "12px Fredoka", "#ffffff", "center", "middle")
		var no: bool = not own and (k.has("fr") or S.d.gems < int(k.p))
		var pr: String = "✓ IN USO" if on else ("USA" if own else ("🔒 salvalo" if k.has("fr") else "◆ %d" % int(k.p)))
		txt(pr, sx + cwid / 2, sy2 + 95, "700 12px Fredoka", "#ff8787" if no else "#5ff2ff", "center", "middle")
		if sy2 + chh > y and sy2 < y + gh:
			btns.append({"r": Rect2(sx, maxf(sy2, y), cwid, minf(sy2 + chh, y + gh) - maxf(sy2, y)), "f": buy_skin.bind(i), "n": "skin"})
	u.restore()
	y += gh + 12
	_b2(x, y, w, "CHIUDI", "#2b2142", "#ffffff", _set_ov.bind(""))
	u.restore()

func buy_skin(i: int) -> void:
	var k: Dictionary = D.SKINS[i]
	if D.skin_owned(i):
		S.d.skin = i; A.snd(700, .08, "triangle", .06)
	elif not k.has("fr") and S.d.gems >= int(k.p):
		S.d.gems -= int(k.p); S.d.owned.append(i); S.d.skin = i; A.sfx("power")
	else:
		shop_shake = t; A.snd(160, .2, "sawtooth", .05)
		return
	S.store()

func _ov_how() -> void:
	var items = [
		[["Trascina", true], [" a destra o sinistra (ovunque sullo schermo): Kubo corre.", false]],
		[["Tocca", true], [" o fai uno swipe in su: salto. Contro un muro: salto a muro.", false]],
		[["Tieni premuto", true], [": il rampino si aggancia da solo all'anello migliore sopra di te e Kubo dondola. Rilascia quando la corda diventa ", false], ["dorata", "g"], [" per il lancio PERFETTO!", false]],
		[["Combo", true], [": anelli, PERFETTO e nemici schiacciati di fila senza toccare terra. Ogni gemma vale quanto la combo.", false]],
		[["Attento!", true], [" Dal basso sale la lava (o il buio, la marea…): non fermarti.", false]],
		[["Piattaforme", true], [": trampolini rossi, rocce che crollano, nuvole che spariscono, molle gialle sui muri.", false]],
		[["Power-up", true], [": ⏫ doppio salto · 🛡️ scudo · 🚀 razzo · 🧲 magnete.", false]],
		[["Gemme ◆", true], [": spendile nel negozio SKIN per vestire Kubo.", false]],
		[["Stelle ★", true], [": una per il portale, una per le gemme raccolte in una partita, una per la combo. In ogni mondo è nascosta anche una ", false], ["gemma segreta 💠", true], [" vicino ai muri.", false]],
		[["Tastiera", true], [": ← → muovi, Spazio salta, X o Shift rampino.", false]]]
	var cw = minf(340, W - 40)
	var w = cw - 44
	var lh = 21.0
	var fn = "16px Fredoka"
	var fb = "700 16px Fredoka"
	# impaginazione parola per parola
	var laid: Array = []
	var total = 0.0
	for it in items:
		var lines: Array = [[]]
		var lw = 0.0
		for seg in it:
			var bold = seg[1]
			var f = fb if bold else fn
			var col = "#ffd43b" if str(bold) == "g" else ("#2ee6c5" if bold else "#e8e0f7")
			var parts: PackedStringArray = str(seg[0]).split(" ")
			for pi in parts.size():
				var word: String = parts[pi] + (" " if pi < parts.size() - 1 else "")
				var ww = tw(word, f)
				if lw + ww > w and lw > 0:
					lines.append([]); lw = 0
				lines[-1].append([word, f, col, lw])
				lw += ww
		laid.append(lines)
		total += lines.size() * lh + 8
	var h = 24 + 30 + 12 + total + 12 + 48 + 24
	var cb2 = _card_begin(minf(h, VH - 40))
	var x: float = cb2[0] + 22
	var y: float = cb2[1] + 24
	txt("COME SI GIOCA", cb2[0] + cb2[2] / 2, y + 22, "21px Bungee", "#ffffff", "center"); y += 30 + 12
	var sc = minf(1.0, (VH - 40 - (h - total)) / total)
	u.save(); u.translate(x, y); u.scale(1, 1)
	var yy = 0.0
	for lines in laid:
		for ln in lines:
			for wd in ln:
				txt(wd[0], wd[3], yy + 16, wd[1], wd[2])
			yy += lh * sc
		yy += 8 * sc
	u.restore()
	y += total * sc + 12
	_b2(x, y, cb2[2] - 44, "HO CAPITO", "#2ee6c5", "#003333", _set_ov.bind(""))

# =====================================================================
#                           VIDEO DELLA STORIA
# =====================================================================
func play_cine(done) -> void:
	CINE.on = true; CINE.done = done; CINE.t0 = t; CINE.ev = {}; CINE.capI = -1; CINE.flash = 0.0
	state = "cine"
	ov = ""
	var r = Rng.new(4242)
	CINE.people = []
	for k in N:
		var x = 40 + r.next() * (CW - 80)
		var ph = r.next() * 7
		var sp = .5 + r.next() * .6
		CINE.people.append({"k": k, "x": x, "ph": ph, "sp": sp, "tx": CW / 2 - 170 + ((k * 37) % 22) * 15.5, "lt": 12.9 + k * .16})
	A.mus_start(6)

func end_cine() -> void:
	if not CINE.on:
		return
	CINE.on = false
	A.mus_stop()
	state = "menu"
	var f = CINE.done
	CINE.done = null
	if f != null:
		f.call()
	else:
		intro()

func _cine_house(c: Ctx, hx: float, gy: float, fc, lit) -> void:
	c.fillStyle = K.mix(fc, "#000000", .12); c.fillRect(hx - 26, gy - 38, 52, 38); K.poly(c, [hx - 32, gy - 38, hx, gy - 62, hx + 32, gy - 38], K.mix(fc, "#000000", .35))
	c.fillStyle = "#2b2b33"; c.fillRect(hx - 7, gy - 19, 14, 19); c.fillStyle = lit; c.fillRect(hx - 21, gy - 31, 10, 9); c.fillRect(hx + 11, gy - 31, 10, 9)

func _cine_bubble(c: Ctx, x: float, y: float, name: String, text: String, col) -> void:
	c.font = "13px Fredoka"
	var lines = K.wrap(c, text, 200)
	var bw = 220.0
	var bh = 26.0 + lines.size() * 16
	var bx = maxf(8, minf(W - bw - 8, x - bw / 2))
	var by = maxf(8, y - bh - 10)
	c.fillStyle = "#ffffff"; c.beginPath(); c.roundRect(bx, by, bw, bh, 12); c.fill(); K.poly(c, [x - 7, by + bh - 1, x + 7, by + bh - 1, x, by + bh + 9], "#ffffff")
	c.textAlign = "left"; c.font = "10px Bungee"; c.fillStyle = col; c.fillText(name, bx + 12, by + 16); c.font = "13px Fredoka"; c.fillStyle = "#1b1230"
	for j in lines.size():
		c.fillText(lines[j], bx + 12, by + 33 + j * 16)
	c.textAlign = "center"

func _thunder(f: float, d: float, v: float, sl: float, fl: float) -> void:
	A.snd(f, d, "sawtooth", v, sl)
	CINE.flash = fl

func _laugh() -> void:
	for k in 4:
		A.snd(230 - k * 28, .22, "sawtooth", .07, -70, k * .21)

func _ev(tt: float, at: float, k: String, f: Callable) -> void:
	if tt >= at and not CINE.ev.has(k):
		CINE.ev[k] = true
		f.call()

func draw_cine() -> void:
	var tt: float = t - CINE.t0
	if tt > CEND:
		end_cine()
		return
	var c = u
	var H = VH
	var gy = H * .6
	var ry = gy + H * .09
	_ev(tt, 7.4, "m2", A.mus_start.bind(21))
	_ev(tt, 8, "th", _thunder.bind(55.0, 1.4, .09, -15.0, 1.0))
	_ev(tt, 9.6, "th2", _thunder.bind(70.0, 1.0, .07, -20.0, .7))
	_ev(tt, 10.4, "laugh", _laugh)
	_ev(tt, 12.8, "suck", A.snd.bind(110, 3.6, "sawtooth", .035, 650))
	_ev(tt, 16.6, "port", A.snd.bind(320, 1, "triangle", .06, 900))
	_ev(tt, 19.4, "m3", A.mus_stop)
	_ev(tt, 23.4, "m4", A.mus_start.bind(0))
	_ev(tt, 23.7, "jump", A.sfx.bind("jump"))
	_ev(tt, 26.2, "title", A.sfx.bind("win"))
	var caps: Array = D.J.CAPS
	var ci = 0
	for k in caps.size():
		if tt >= caps[k][0]:
			ci = k
	if ci != CINE.capI:
		CINE.capI = ci; CINE.capT = tt
	var cl = func(x: float) -> float: return clampf(x, 0, 1)
	var dark: float = cl.call((tt - 7) / 3)
	var gray: float = cl.call((tt - 12.8) / 4)
	var dawn: float = cl.call((tt - 23.4) / 2.5) * .5
	var cam = minf(CW / 2 - W / 2, (tt / 7) * (CW / 2 - W / 2))
	c.save()
	var sh = 2.2 if ((tt > 10.4 and tt < 11.4) or (tt > 12.8 and tt < 16.6)) else 0.0
	if sh:
		c.translate((randf() - .5) * sh * 2, (randf() - .5) * sh * 2)
	var g = c.createLinearGradient(0, 0, 0, H)
	g.addColorStop(0, K.mix(K.mix(K.mix("#4dabf7", "#120c1e", dark), "#26262e", gray * .5), "#ff9f6b", dawn * .4))
	g.addColorStop(1, K.mix(K.mix(K.mix("#ffe8cc", "#2a1a3a", dark), "#3a3a44", gray * .5), "#ffd8a8", dawn * .5))
	c.fillStyle = g; c.fillRect(-10, -10, W + 20, H + 20)
	if dark < 1:
		K.circ(c, W * .8, H * .12, 26, K.rgba("#ffd43b", 1 - dark)); c.globalAlpha = 1 - dark
		for k in 4:
			var x = fmod(k * 120 + tt * 12, W + 120) - 60
			K.cloud(c, x, H * (.08 + (k % 2) * .07), 40, {"cloud": "#ffffff"})
		c.globalAlpha = 1
	if dark > 0:
		c.globalAlpha = dark * (1 - dawn)
		for k in 40:
			c.fillStyle = "#fff"; c.fillRect((k * 97) % int(W), fmod(k * 53, H * .45), 1.3, 1.3)
		K.circ(c, W * .18, H * .1, 13, K.mix("#f1f3f5", "#9a9aa6", gray)); c.globalAlpha = 1
	var ccx: float = W / 2 + (420.0 if tt < 7 else ((1 - (tt - 7) / 3) * 420 if tt < 10 else 0.0))
	var ca = 0.0 if tt < 7 else (1.0 if tt < 19 else maxf(0, 1 - (tt - 19) / 1.4))
	if ca > 0:
		c.globalAlpha = ca
		for k in 11:
			K.circ(c, ccx + (k - 5) * 27 + sin(tt + k) * 4, H * .15 + sin(k * 1.7) * 12, 30 + ((k * 13) % 18), "#140f1e")
		c.shadowColor = "#ff2b4a"; c.shadowBlur = 12; c.fillStyle = "#ff2b4a"; c.beginPath(); c.ellipse(ccx - 16, H * .15, 8, 3.4, .3, 0, 7); c.ellipse(ccx + 16, H * .15, 8, 3.4, -.3, 0, 7); c.fill(); c.shadowBlur = 0; c.globalAlpha = 1
	if CINE.flash > 0:
		c.fillStyle = Color(230 / 255.0, 240 / 255.0, 1, CINE.flash * .5); c.fillRect(-10, -10, W + 20, H + 20); CINE.flash = maxf(0, CINE.flash - .035)
	c.fillStyle = K.mix(K.mix("#69db7c", "#2f4a3a", dark * .6), "#55555f", gray); c.beginPath(); c.moveTo(0, H)
	var xx = 0.0
	while xx <= W + 20:
		c.lineTo(xx, gy - 28 - sin((xx + cam * .4) * .02) * 16); xx += 20
	c.lineTo(W, H); c.fill()
	c.save(); c.translate(-cam, 0)
	c.fillStyle = K.mix(K.mix("#8ce99a", "#3d5a45", dark * .6), "#4a4a54", gray); c.fillRect(-20, gy, CW + 40, H)
	c.fillStyle = K.mix(K.mix("#f2d39b", "#5a4a3a", dark * .5), "#5c5c66", gray); c.fillRect(-20, ry - 10, CW + 40, H * .06)
	for k in 11:
		var hx = 50 + k * 80.0
		var fc = K.mix(K.mix(D.FR[k].c, "#2a2238", dark * .45), "#6c6c78", gray)
		_cine_house(c, hx, gy, fc, "#3a3a44" if gray > .5 else ("#ffe066" if dark > .3 else K.mix("#a5d8ff", "#ffe066", dark)))
	var fx = CW / 2
	var fcol = K.mix("#ced4da", "#6c757d", gray)
	c.fillStyle = fcol; c.beginPath(); c.ellipse(fx, ry - 14, 30, 8, 0, 0, 7); c.fill(); c.fillRect(fx - 4, ry - 40, 8, 26); K.circ(c, fx, ry - 42, 9, fcol)
	if gray < 1:
		for k in 6:
			var a = fmod(tt * 2 + k / 6.0, 1.0)
			K.circ(c, fx + (k - 2.5) * 5 * a, ry - 46 + a * 30 - sin(a * PI) * 12, 2, K.rgba("#74c0fc", (1 - a) * (1 - gray)))
	var oyD: float
	if tt < 10.2: oyD = -80
	elif tt < 11.2: oyD = H * .15 + cl.call(tt - 10.2) * H * .13
	elif tt < 16.6: oyD = H * .28
	else: oyD = H * .28 - cl.call((tt - 16.6) / 2.4) * H * .26
	var os: float = 64.0 if tt < 16.6 else 64 * (1 - cl.call((tt - 16.6) / 2.4))
	var ox = CW / 2
	if tt > 12.8 and tt < 17.2:
		for k in 11:
			for j in 4:
				var q = fmod((tt - 12.8) * .7 + k * .09 + j * .25, 1.0)
				var sx = 50 + k * 80.0
				var sy0 = gy - 30
				var mx = (sx + ox) / 2
				var my = minf(sy0, oyD) - 60
				var x = (1 - q) * (1 - q) * sx + 2 * (1 - q) * q * mx + q * q * ox
				var y = (1 - q) * (1 - q) * sy0 + 2 * (1 - q) * q * my + q * q * oyD
				K.circ(c, x, y, 3.5 * (1 - q * .5), K.rgba(D.FR[k].c, 1 - gray * .3))
	for p in CINE.people:
		var run: float = cl.call((tt - 7.6) / 3.2)
		var x: float = p.x + (p.tx - p.x) * run + sin(tt * p.sp * (1 + run * 3) + p.ph) * (20 - run * 14)
		var y: float = ry - 8 - (absf(sin(tt * 3 + p.ph)) * 5 if tt < 7 else 0.0)
		if tt > p.lt:
			var q: float = cl.call((tt - p.lt) / 1.6)
			if q >= 1:
				continue
			x = x + (ox - x) * q * q; y = y + (oyD - y) * q
			c.strokeStyle = "rgba(60,20,90,.7)"; c.lineWidth = 3; c.beginPath(); c.moveTo(ox, oyD); c.quadraticCurveTo((ox + x) / 2 + sin(tt * 8 + p.k) * 14, (oyD + y) / 2, x, y); c.stroke()
		K.drawCube(c, x, y, 15, "happy" if tt < 7.5 else ("wow" if tt < p.lt else "hurt"), tt + p.k, sin(tt * 12 + p.k) * .4 if tt > p.lt else 0.0, D.friend_skin(p.k))
	K.drawCube(c, CW / 2 - 46, ry - 11, 22, "happy" if tt < 7.5 else ("wow" if tt < 20 else "n"), tt, 0, D.nonno_skin())
	var kx = CW / 2 + 44
	var jump = 0.0
	if tt > 23.6 and tt < 26: jump = absf(sin((tt - 23.6) * 5)) * 26
	elif tt < 4.2: jump = 0.0
	elif tt < 7: jump = absf(sin(tt * 6)) * 6
	var km = "happy" if tt < 7.5 else ("wow" if tt < 12.8 else ("hurt" if tt < 20.2 else ("n" if tt < 23.4 else "angry")))
	K.drawCube(c, kx, ry - 12 - jump, 24, km, tt, sin(tt * 8) * .15 if (tt > 4.2 and tt < 7) else (sin(tt * 30) * .08 if (tt > 12.8 and tt < 17) else 0.0))
	if tt > 10.2 and os > 1:
		var lp = 1 + absf(sin(tt * 9)) * .08 if (tt > 10.4 and tt < 13) else 1.0
		K.drawOmbra(c, ox, oyD, os * lp, tt, "n")
	c.restore()
	if tt > 16.4 and tt < 21:
		var op: float = cl.call((tt - 16.4) / .6) * (1 - cl.call((tt - 20) / 1))
		for k in 22:
			var px = 26 + (k % 11) * 31.0
			var py = H * (.05 + (0.0 if k < 11 else .07))
			var r = 10 * op
			c.save(); c.translate(px, py); c.rotate(tt * 4 + k); c.strokeStyle = D.FR[k].c; c.lineWidth = 2.5; c.setLineDash([5, 4]); c.beginPath(); c.arc(0, 0, maxf(.1, r), 0, 7); c.stroke(); c.setLineDash([]); c.restore()
			K.circ(c, px, py, r * .6, "rgba(20,12,30,.9)")
			var q: float = cl.call((tt - 16.8 - k * .08) / .7)
			if q > 0 and q < 1:
				var sx = W / 2
				var sy0 = H * .2
				K.circ(c, sx + (px - sx) * q, sy0 + (py - sy0) * q, 4, D.FR[k].c)
	if tt > 26:
		var a: float = cl.call((tt - 26) / .8)
		c.fillStyle = Color(11 / 255.0, 7 / 255.0, 20 / 255.0, a * .85); c.fillRect(-10, -10, W + 20, H + 20); c.globalAlpha = a; c.textAlign = "center"; c.textBaseline = "middle"
		c.font = "64px Bungee"; c.fillStyle = "#ff5a1f"; c.shadowColor = "#ff5a1f"; c.shadowBlur = 24; c.fillText("KUBO", W / 2, H * .38); c.fillStyle = "#ffffff"; c.shadowBlur = 0; c.fillText("RUN", W / 2, H * .38 + 62)
		c.font = "18px Fredoka"; c.fillStyle = "#ffd43b"; c.fillText("Salva Cubolandia dal Re Ombra!", W / 2, H * .38 + 120); c.globalAlpha = 1; c.textBaseline = "alphabetic"
	var vg = c.createRadialGradient(W / 2, H * .45, H * .3, W / 2, H * .45, H * .85); vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(0,0,0,.4)")
	c.fillStyle = vg; c.fillRect(-10, -10, W + 20, H + 20)
	c.restore()
	for b in D.J.CBUB:
		if tt >= b[0] and tt < b[1]:
			var sx: float = (ox - cam) if b[2] == "ombra" else ((CW / 2 - 46 - cam) if b[2] == "nonno" else (CW / 2 + 44 - cam))
			var syy: float = (oyD - 44) if b[2] == "ombra" else (ry - 36)
			_cine_bubble(c, sx, syy, b[3], str(b[4]).substr(0, int(floor((tt - b[0]) * 34))), "#e03131" if b[2] == "ombra" else ("#5c5f66" if b[2] == "nonno" else "#ff5a1f"))
	# didascalia
	var cap: String = caps[CINE.capI][1]
	if cap != "":
		var ca2 = clampf((tt - CINE.capT) / .7, 0, 1)
		c.globalAlpha = ca2
		c.font = "18px Fredoka"
		var lines = K.wrap(c, cap, W - 32 - 32)
		var bh = 24 + lines.size() * 24.3
		var by = VH - 28 - bot_in - bh
		rr(16, by, W - 32, bh, 16, "#000000b8", "#ffffff22")
		for j in lines.size():
			txt(lines[j], W / 2, by + 12 + 18 + j * 24.3, "18px Fredoka", "#ffffff", "center")
		c.globalAlpha = 1
	# salta
	var sl = "SALTA ▸"
	var sf = "12px Bungee"
	var sw = tw(sl, sf) + 28
	rr(W - 12 - sw, top_in + 2, sw, 40, 20, "#00000088", "#ffffff44")
	txt(sl, W - 12 - sw / 2, top_in + 23, sf, "#ffffff", "center", "middle")
	_btn(Rect2(W - 12 - sw, top_in + 2, sw, 40), end_cine)
