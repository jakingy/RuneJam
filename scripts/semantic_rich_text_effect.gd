@tool
extends RichTextEffect
class_name SemanticRichTextEffect

var bbcode := "impact"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var age := maxf(char_fx.elapsed_time, 0.0)
	var intro_duration := float(char_fx.env.get("duration", 0.9))

	var idx := float(char_fx.relative_index)
	var progress := clampf(age / intro_duration, 0.0, 1.0)
	var fade := pow(1.0 - progress, 0.8)
	var t := age
	var color := char_fx.color
	var offset := Vector2.ZERO
	var xform := char_fx.transform
	var flicker := 0.5 + 0.5 * sin(t * 10.0 + idx * 0.73)
	var flutter := 0.5 + 0.5 * sin(t * 17.0 + idx * 1.41 + 0.7)
	var flare := pow(1.0 - progress, 0.42)
	var ambient := 0.55 + 0.45 * flicker
	var sustain := 0.45 + ambient * 0.4
	var hotspot := pow(1.0 - progress, 0.18)
	var settle_glow := 0.62 + ambient * 0.38 + (1.0 - progress) * 0.24
	var glow_boost := 1.64 + fade * 2.08 + flare * 1.58 + sustain * 1.12 + hotspot * 1.06 + settle_glow * 0.3
	var text_len := maxf(float(char_fx.env.get("len", 1.0)), 1.0)

	match bbcode:
		"impact":
			var quake_x := sin(t * 42.0 + idx * 1.7) * (0.22 + fade * 1.05)
			quake_x += cos(t * 27.0 + idx * 0.9) * (0.08 + fade * 0.38)
			var quake_y := cos(t * 36.0 + idx * 2.2) * (0.05 + fade * 0.34)
			quake_y += sin(t * 53.0 + idx * 1.1) * (0.03 + fade * 0.22)
			color = Color(1.04 + glow_boost * 0.28, 0.74 + fade * 0.22 + ambient * 0.1 + settle_glow * 0.04, 0.48 + fade * 0.12 + settle_glow * 0.02, 1.0)
			offset = Vector2(quake_x, quake_y)
		"slice":
			var slash_length_factor := clampf((text_len - 4.0) / 8.0, 0.0, 1.0)
			var blade_slant := idx * (0.025 + slash_length_factor * 0.035)
			var slash_surge := 0.03 + fade * (0.08 + slash_length_factor * 0.08)
			var slash_rotation := -0.055 - slash_length_factor * 0.05 - fade * 0.025 + sin(t * 6.0 + idx * 0.3) * 0.008
			color = Color(1.16 + glow_boost * 0.36, 0.46 + fade * 0.26 + flutter * 0.08 + settle_glow * 0.06, 0.32 + fade * 0.13 + settle_glow * 0.04, 1.0)
			offset = Vector2(
				blade_slant + sin(t * 14.0 + idx * 0.9) * slash_surge,
				-(0.004 + fade * 0.012 + sin(t * 9.0 + idx * 0.5) * 0.004)
			)
			xform = xform.rotated(slash_rotation)
		"pierce":
			color = Color(1.06 + glow_boost * 0.28, 0.76 + fade * 0.18 + settle_glow * 0.03, 0.54 + fade * 0.1 + settle_glow * 0.02, 1.0)
			offset = Vector2(0.28 + (0.12 + fade * 1.26) * sin(t * 31.0 + idx * 2.3), -0.08 - fade * 0.14)
		"move":
			var sway := sin(t * 4.6 + idx * 0.34)
			var move_glow := glow_boost * 0.28 + settle_glow * 0.06
			color = Color(1.02 + move_glow, 0.92 + ambient * 0.1 + move_glow * 0.16, 0.84 + ambient * 0.08 + move_glow * 0.1, 1.0)
			offset = Vector2(sway * (0.28 + fade * 0.95), -0.01 - fade * 0.03)
		"cold":
			color = Color(0.76 + ambient * 0.1 + settle_glow * 0.02, 0.96 + ambient * 0.1 + settle_glow * 0.03, 1.1 + glow_boost * 0.26, 1.0)
			offset = Vector2.ZERO
		"lightning":
			color = Color(1.16 + glow_boost * 0.4, 1.0 + ambient * 0.12 + settle_glow * 0.03, 1.04 + glow_boost * 0.24, 1.0)
			offset = Vector2(sin(t * 58.0 + idx * 4.6) * (0.22 + fade * 1.06), cos(t * 41.0 + idx * 2.4) * (0.08 + fade * 0.38))
		"water":
			color = Color(0.64 + ambient * 0.11 + settle_glow * 0.02, 0.9 + ambient * 0.11 + settle_glow * 0.03, 1.08 + glow_boost * 0.26, 1.0)
			offset = Vector2(sin(t * 8.4 + idx * 0.7) * (0.16 + fade * 0.82), cos(t * 6.8 + idx * 0.6) * (0.09 + fade * 0.34))
		"plant":
			color = Color(0.16 + ambient * 0.02 + settle_glow * 0.008, 0.56 + glow_boost * 0.14, 0.1 + ambient * 0.025 + settle_glow * 0.008, 1.0)
			offset = Vector2.ZERO
		"ground":
			color = Color(0.42 + glow_boost * 0.14, 0.3 + ambient * 0.03 + settle_glow * 0.01, 0.22 + ambient * 0.03 + settle_glow * 0.01, 1.0)
			offset = Vector2(sin(t * 24.0 + idx) * (0.08 + fade * 0.45), sin(t * 18.0 + idx * 0.6) * (0.03 + fade * 0.22))
		"heal":
			var pulse := 0.5 + 0.5 * sin(t * 2.2 + idx * 0.18)
			var heal_glow := glow_boost * (0.4 + pulse * 0.28) + settle_glow * 0.14 + pulse * 0.28
			color = Color(
				0.94 + ambient * 0.1 + pulse * 0.08 + heal_glow * 0.08,
				1.22 + heal_glow,
				0.86 + ambient * 0.12 + pulse * 0.12 + heal_glow * 0.12,
				1.0
			)
			offset = Vector2.ZERO
		"shield":
			var sweep_center := fposmod(t * 1.1, 6.0) - 1.0
			var gleam_distance := absf(idx - sweep_center)
			var gleam_pass := maxf(0.0, 1.0 - gleam_distance * 0.7)
			var shield_glow := glow_boost * 0.34 + gleam_pass * 1.2 + settle_glow * 0.08
			color = Color(
				0.96 + ambient * 0.08 + gleam_pass * 0.32,
				1.06 + ambient * 0.08 + gleam_pass * 0.34 + settle_glow * 0.04,
				1.06 + shield_glow + settle_glow * 0.02,
				1.0
			)
			offset = Vector2.ZERO
		"light":
			color = Color(1.34 + glow_boost * 0.46, 1.16 + ambient * 0.16 + settle_glow * 0.05, 0.94 + ambient * 0.08 + settle_glow * 0.05, 1.0)
			offset = Vector2(sin(t * 5.2 + idx * 0.38) * (0.03 + fade * 0.1), -(0.14 + fade * 0.94))
		"dark":
			color = Color(0.48 + ambient * 0.03 + settle_glow * 0.01, 0.46 + ambient * 0.02 + settle_glow * 0.01, 0.72 + glow_boost * 0.18 + settle_glow * 0.04, 1.0)
			offset = Vector2(
				sin(t * 8.4 + idx * 1.05) * (0.08 + fade * 0.28),
				cos(t * 6.9 + idx * 0.88) * (0.03 + fade * 0.14) + 0.03 + fade * 0.14
			)
		"decisive":
			color = Color(1.16 * (glow_boost + 0.28), 1.0 + ambient * 0.1 + settle_glow * 0.03, 0.8 + ambient * 0.08 + settle_glow * 0.03, 1.0)
			offset = Vector2(sin(t * 4.2 + idx * 0.28) * (0.015 + fade * 0.06), -(0.16 + fade * 1.04))
		_:
			return true

	char_fx.color = color
	char_fx.offset = offset
	char_fx.transform = xform
	return true
