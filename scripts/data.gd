extends Node
## Dati del gioco (estratti identici dalla versione HTML) e costanti.

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

var J: Dictionary = {}
var THEMES: Array = []
var STY: Array = []
var RW: Array = []
var FR: Array = []
var SKINS: Array = []
var font_title: Font
var font_body: Font
var font_bold: Font

func _ready() -> void:
	var f := FileAccess.open("res://data/data.json", FileAccess.READ)
	J = JSON.parse_string(f.get_as_text())
	THEMES = J.THEMES
	STY = J.STY
	RW = J.RW
	FR = J.FR
	SKINS = J.SKINS.duplicate(true)
	# skin degli amici (si sbloccano salvandoli)
	for k in FR.size():
		var s := friend_skin(k)
		s["p"] = 0
		s["fr"] = k
		SKINS.append(s)
	# emoji e simboli: font di sistema (Noto Color Emoji su Android)
	var emo := SystemFont.new()
	emo.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Noto Sans Symbols 2", "Noto Sans Symbols", "DejaVu Sans", "sans-serif"])
	var ft: FontFile = load("res://fonts/Bungee-Regular.ttf")
	ft.fallbacks = [emo]
	font_title = ft
	var base: FontFile = load("res://fonts/Fredoka.ttf")
	base.fallbacks = [emo]
	var ts := TextServerManager.get_primary_interface()
	for wgt in [600, 700]:
		var fb := FontVariation.new()
		fb.base_font = base
		fb.variation_opentype = {ts.name_to_tag("wght"): wgt}
		fb.fallbacks = [emo]
		if wgt == 600:
			font_body = fb
		else:
			font_bold = fb

func goal_of(i: int) -> int:
	return 220 + i * 15

func ch_of(i: int) -> Dictionary:
	return {"gems": 20 + i * 4, "combo": 4 if i < 3 else (5 if i < 10 else 6)}

func col(h) -> Color:
	if h is Color:
		return h
	return Color.html(str(h))

func mix(a, b, t: float) -> Color:
	return col(a).lerp(col(b), t)

func rgba(h, a: float) -> Color:
	var c := col(h)
	c.a = a
	return c

func is_chase(i: int) -> bool:
	return i in [4, 9, 14, 19]

func friend_skin(k: int) -> Dictionary:
	var f: Dictionary = FR[k]
	var c := col(f.c)
	return {"n": f.n, "b": c, "t": c.lerp(Color.WHITE, .3), "d": c.lerp(Color.BLACK, .3), "hat": f.hat, "hc": col(J.HATC.get(f.hat, "#ffffff")), "tr": c}

func nonno_skin() -> Dictionary:
	var n: Dictionary = J.NONNO
	return {"n": n.n, "b": col(n.b), "t": col(n.t), "d": col(n.d), "hat": n.hat, "hc": col(n.hc), "tr": col(n.tr)}

func skin_col(sk: Dictionary, t: float) -> Dictionary:
	if str(sk.get("b", "")) != "rgb":
		var o := {}
		for k in sk.keys():
			o[k] = sk[k]
		for k in ["b", "t", "d", "tr", "hc"]:
			if o.has(k):
				o[k] = col(o[k])
		return o
	var h := fmod(t * 90.0, 360.0) / 360.0
	return {"n": sk.n, "b": Color.from_hsv(h, .7, .98), "t": Color.from_hsv(h, .45, 1.0), "d": Color.from_hsv(h, .8, .7), "tr": Color.from_hsv(fmod(h + .5, 1.0), .6, 1.0), "hat": sk.hat, "hc": col(sk.get("hc", "#ffffff"))}

func cur_skin(t: float) -> Dictionary:
	var i: int = S.d.skin
	if i < 0 or i >= SKINS.size():
		i = 0
	return skin_col(SKINS[i], t)

func skin_owned(i: int) -> bool:
	var s: Dictionary = SKINS[i]
	if s.has("fr"):
		return S.d.fr[s.fr]
	return i in S.d.owned
