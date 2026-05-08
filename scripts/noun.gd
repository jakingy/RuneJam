extends Node

class Noun:
	var mex_health: float
	var physical_attack: float
	var physical_defence: float
	var magic_attack: float
	var magic_defence: float
	var speed: float # determines turn order

	func _init(mh: float, pa: float, pd: float, ma: float, md: float, s: float):
		mex_health = mh
		physical_attack = pa
		physical_defence = pd
		magic_attack = ma
		magic_defence = md
		speed = s
