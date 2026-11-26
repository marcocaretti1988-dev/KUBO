class_name Rng
extends RefCounted
## Stesso generatore (mulberry32) della versione HTML: i livelli escono identici.

var s: int = 0

func _init(seed: int) -> void:
	s = _i32(seed)

static func _i32(x: int) -> int:
	x &= 0xFFFFFFFF
	return x - 0x100000000 if x >= 0x80000000 else x

static func _u32(x: int) -> int:
	return x & 0xFFFFFFFF

static func _imul(a: int, b: int) -> int:
	var ua := _u32(a)
	var ub := _u32(b)
	var lo := (ua & 0xFFFF) * ub
	var hi := (((ua >> 16) * ub) & 0xFFFF) << 16
	return _i32(lo + hi)

func next() -> float:
	s = _i32(s + 0x6D2B79F5)
	var t := _imul(s ^ (_u32(s) >> 15), 1 | s)
	t = _i32(_i32(t + _imul(t ^ (_u32(t) >> 7), 61 | t)) ^ t)
	return float(_u32(t ^ (_u32(t) >> 14))) / 4294967296.0
