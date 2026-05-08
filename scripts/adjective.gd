extends Node

class Adjective:
	var mex_health_multiplier: float
	var physical_attack_multiplier: float
	var physical_defence_multiplier: float
	var magic_attack_multiplier: float
	var magic_defence_multiplier: float
	var speed_multiplier: float

	func _init(mhm: float, pam: float, pdm: float, mam: float, mdm: float, sm: float):
		mex_health_multiplier = mhm
		physical_attack_multiplier = pam
		physical_defence_multiplier = pdm
		magic_attack_multiplier = mam
		magic_defence_multiplier = mdm
		speed_multiplier = sm
