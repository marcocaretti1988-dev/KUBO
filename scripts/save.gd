extends Node
## Salvataggio locale (come il localStorage della versione HTML).

const PATH := "user://kubo_save.json"
var d: Dictionary = {}

func _ready() -> void:
	d = {"unlocked": 1, "st": [], "best": [], "sound": true, "gems": 0, "owned": [0], "skin": 0, "seen": false, "fr": [], "kids": [], "comp": -1, "sec": []}
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var x = JSON.parse_string(f.get_as_text())
		if x is Dictionary:
			for k in x.keys():
				d[k] = x[k]
	while d.st.size() < 22:
		d.st.append([false, false, false])
	while d.best.size() < 22:
		d.best.append(0)
	while d.fr.size() < 22:
		d.fr.append(false)
	while d.sec.size() < 22:
		d.sec.append(false)
	while d.kids.size() < 22:
		d.kids.append(0)
	# JSON restituisce numeri float: li riportiamo a int
	d.unlocked = int(d.unlocked)
	d.gems = int(d.gems)
	d.skin = int(d.skin)
	d.comp = int(d.comp)
	for i in 22:
		d.best[i] = int(d.best[i])
		d.kids[i] = int(d.kids[i])
	var ow: Array = []
	for v in d.owned:
		ow.append(int(v))
	d.owned = ow

func store() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))

func stars_of(i: int) -> int:
	var n := 0
	for v in d.st[i]:
		if v:
			n += 1
	return n
