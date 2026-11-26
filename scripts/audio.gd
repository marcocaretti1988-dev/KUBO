extends Node
## Audio: sintetizzatore chiptune (come Web Audio nella versione HTML).
## Tutti i suoni (effetti + musica) sono voci generate al volo.

const SR := 22050.0
const SQ := 0
const TRI := 1
const SAW := 2
const SINE := 3
const NOISE_BP := 4
const NOISE_HP := 5
const KICK := 6

var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var clock := 0          # campioni generati finora
var voices: Array = []
var mus_on := false
var mus_gain := 0.5
var mus_target := 0.5
var P: Dictionary = {}
var mnext := 0.0        # in campioni
var mstep := 0
var fast := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SR
	gen.buffer_length = 0.12
	player.stream = gen
	add_child(player)
	player.play()
	pb = player.get_stream_playback()

func now() -> float:
	return clock / SR

func _type(t: String) -> int:
	match t:
		"square": return SQ
		"triangle": return TRI
		"sawtooth": return SAW
		_: return SINE

func _voice(type: int, f: float, f1: float, slide_d: float, start: float, d: float, v: float, vend: float, stop: float, music: bool) -> void:
	var n := int(stop * SR)
	voices.append({"ty": type, "s": int(start * SR), "n": n, "f": f, "kf": pow(f1 / f, 1.0 / maxf(1.0, slide_d * SR)) if f1 > 0.0 and f > 0.0 else 1.0, "fs": int(slide_d * SR),
		"g": v, "kg": pow(vend / v, 1.0 / maxf(1.0, d * SR)), "gd": int(d * SR), "ph": 0.0, "mu": music, "x1": 0.0, "x2": 0.0, "y1": 0.0, "y2": 0.0})

## snd(f, d, type, v, slide) dell'HTML; delay in secondi = setTimeout
func snd(f: float, d := 0.1, type := "square", v := 0.06, slide := 0.0, delay := 0.0) -> void:
	if not S.d.sound:
		return
	var f1 := maxf(30.0, f + slide) if slide != 0.0 else f
	_voice(_type(type), f, f1, d, now() + 0.01 + delay, d, v, 0.001, d, false)

func sfx(name: String, k := 0) -> void:
	match name:
		"perfect": snd(880, .1, "square", .05, 600); snd(1320, .15, "triangle", .07, 0, .07)
		"boing": snd(180, .25, "sine", .1, 500)
		"gem": snd(1200 + mini(k, 10) * 70, .06, "sine", .05, 400)
		"power":
			for i in 3: snd([523, 784, 1046][i], .1, "square", .05, 0, i * .06)
		"shield": snd(500, .2, "triangle", .07, -300)
		"warp": snd(180, 1.2, "sawtooth", .05, 1500); snd(360, 1.2, "triangle", .06, 2200); snd(1500, .5, "sine", .08, -1200, 1.2)
		"jump": snd(420, .12, "square", .05, 300)
		"hook": snd(600 + mini(maxi(k, 1), 8) * 80, .09, "triangle", .07, -300)
		"hurt": snd(200, .3, "sawtooth", .07, -150)
		"stomp": snd(300, .15, "square", .06, 500)
		"cp": snd(660, .1, "triangle", .07); snd(990, .15, "triangle", .07, 0, .09)
		"win":
			for i in 4: snd([523, 659, 784, 1046][i], .18, "triangle", .08, 0, i * .11)

# ---------------- musica ----------------
func mk_song(i: int) -> Dictionary:
	var r := Rng.new(i * 919 + 7)
	var md: Array = D.J.MUSD[i]
	var sc: Array = D.J.SCALES[md[0]]
	var root := 45 + int(floor(r.next() * 7))
	var progs := [[0, 5, 3, 4], [0, 3, 4, 0], [0, 5, 6, 4], [0, 4, 5, 3], [0, 2, 5, 4], [0, 6, 5, 4]]
	var prog: Array = progs[int(floor(r.next() * progs.size()))]
	var lead: Array = []
	for s in 32:
		if s % 2 == 0 and r.next() < .6:
			lead.append([0, 2, 4, 7, 4, 2, 5, 6][int(floor(r.next() * 8))])
		else:
			lead.append(null)
	var arpO: Array = [[0, 2, 4, 2], [0, 4, 2, 4], [0, 2, 4, 7], [4, 2, 0, 2]][int(floor(r.next() * 4))]
	var bassP: Array = [[0, 3, 6, 8, 11, 14], [0, 4, 8, 12], [0, 6, 8, 14], [0, 2, 4, 6, 8, 10, 12, 14]][int(floor(r.next() * 4))]
	var arp16 := r.next() < .5
	return {"tempo": float(md[1]), "prog": prog, "sc": sc, "root": root, "lead": lead, "arpO": arpO, "bassP": bassP, "arp16": arp16}

func note(d: int) -> int:
	var sc: Array = P.sc
	return P.root + int(sc[posmod(d, 7)]) + 12 * int(floor(d / 7.0))

func mf(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func tone(type: int, m: float, t: float, d: float, v: float) -> void:
	_voice(type, mf(m), 0.0, 0.0, t, d, v, 0.0008, d + .02, true)

func nz(t: float, d: float, v: float, hp: bool) -> void:
	_voice(NOISE_HP if hp else NOISE_BP, 0.0, 0.0, 0.0, t, d, v, 0.0008, d + .02, true)

func kick(t: float) -> void:
	voices.append({"ty": KICK, "s": int(t * SR), "n": int(.16 * SR), "f": 150.0, "kf": pow(40.0 / 150.0, 1.0 / (.12 * SR)), "fs": int(.12 * SR),
		"g": .32, "kg": pow(.001 / .32, 1.0 / (.15 * SR)), "gd": int(.15 * SR), "ph": 0.0, "mu": true, "x1": 0.0, "x2": 0.0, "y1": 0.0, "y2": 0.0})

func mus_start(i: int) -> void:
	if not S.d.sound:
		return
	P = mk_song(i)
	mstep = 0
	fast = 1.0
	mnext = (now() + .08) * SR
	mus_on = true
	mus_gain = .5
	mus_target = .5
	# rimuove le note programmate della canzone precedente
	voices = voices.filter(func(v): return not v.mu or v.s <= clock)

func mus_stop() -> void:
	if not mus_on:
		return
	mus_on = false
	mus_target = 0.0
	voices = voices.filter(func(v): return not v.mu or v.s <= clock)

func _mus_tick() -> void:
	if not mus_on:
		return
	var spb: float = 60.0 / (P.tempo * fast) / 4.0
	while mnext < (now() + .12) * SR:
		var s := mstep
		var t := mnext / SR
		var bar := int(floor(s / 16.0)) % 4
		var b := s % 16
		var ch: int = P.prog[bar]
		if b in P.bassP:
			tone(TRI, note(ch) - 12, t, spb * 1.8, .22)
		if P.arp16 or b % 2 == 0:
			tone(SQ, note(ch + P.arpO[(b if P.arp16 else b >> 1) % 4]) + 12, t, spb * .9, .022)
		var ld = P.lead[s % 32]
		if ld != null and s >= 16:
			tone(SQ, note(ch + int(ld)) + 12, t, spb * 1.8, .035)
		if b % 8 == 0: kick(t)
		if b % 8 == 4: nz(t, .12, .11, false)
		if b % 2 == 1: nz(t, .03, .045, true)
		mnext += spb * SR
		mstep = (s + 1) % 64

# ---------------- generazione ----------------
# coefficienti biquad (come BiquadFilter di Web Audio, Q=1)
var _bp := _biquad(1800.0, false)
var _hp := _biquad(7000.0, true)

func _biquad(f0: float, hp: bool) -> PackedFloat32Array:
	var w0 := TAU * f0 / SR
	var q := 1.0
	var al := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var b0: float; var b1: float; var b2: float
	if hp:
		b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2
	else:
		b0 = al; b1 = 0; b2 = -al
	var a0 := 1 + al
	var a1 := -2 * cw
	var a2 := 1 - al
	return PackedFloat32Array([b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0])

func _process(_dt: float) -> void:
	if pb == null:
		return
	_mus_tick()
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var buf := PackedFloat32Array()
	buf.resize(n)
	var c0 := clock
	var c1 := clock + n
	var keep: Array = []
	var mg := mus_gain
	for v in voices:
		var s0: int = v.s
		var end: int = s0 + v.n
		if end <= c0:
			continue
		keep.append(v)
		if s0 >= c1:
			continue
		var a := maxi(s0, c0)
		var bnd := mini(end, c1)
		var ty: int = v.ty
		var ph: float = v.ph
		var f: float = v.f
		var kf: float = v.kf
		var g: float = v.g
		var kg: float = v.kg
		var mul := mg if v.mu else 1.0
		var age := a - s0
		var fs: int = v.fs
		var gd: int = v.gd
		var co := _hp if ty == NOISE_HP else _bp
		var x1: float = v.x1; var x2: float = v.x2; var y1: float = v.y1; var y2: float = v.y2
		for i in range(a, bnd):
			var o := 0.0
			if ty <= SINE or ty == KICK:
				ph += f / SR
				ph -= floorf(ph)
				match ty:
					SQ: o = 1.0 if ph < .5 else -1.0
					TRI: o = 4.0 * absf(ph - .5) - 1.0
					SAW: o = 2.0 * ph - 1.0
					_: o = sin(ph * TAU)
				if age < fs:
					f *= kf
			else:
				var x := randf() * 2.0 - 1.0
				o = co[0] * x + co[1] * x1 + co[2] * x2 - co[3] * y1 - co[4] * y2
				x2 = x1; x1 = x; y2 = y1; y1 = o
			buf[i - c0] += o * g * mul
			if age < gd:
				g *= kg
			age += 1
		v.ph = ph; v.f = f; v.g = g; v.x1 = x1; v.x2 = x2; v.y1 = y1; v.y2 = y2
	voices = keep
	# volume della musica che sfuma (setTargetAtTime)
	mus_gain += (mus_target - mus_gain) * minf(1.0, n / (SR * .08))
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in n:
		var s := clampf(buf[i], -1.0, 1.0)
		frames[i] = Vector2(s, s)
	pb.push_buffer(frames)
	clock = c1
