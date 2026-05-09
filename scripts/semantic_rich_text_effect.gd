@tool
extends RichTextEffect
class_name SemanticRichTextEffect

const SEMANTIC_EFFECTS: Array[String] = [
	# elements
	"fire",
	"ice",
	"lightning",
	"water",
	"plant",
	"earth",
	"light",
	"dark",
	"air",

	# actions
	"hit",
	"move",
]


var bbcode := "hit"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var effect_key: String = str(bbcode).strip_edges().to_lower()
	if not SEMANTIC_EFFECTS.has(effect_key):
		return true

	var age: float = maxf(char_fx.elapsed_time, 0.0)
	var intro_duration: float = maxf(float(char_fx.env.get("duration", 0.9)), 0.001)
	var idx: float = float(char_fx.relative_index)
	var progress: float = clampf(age / intro_duration, 0.0, 1.0)
	var fade: float = pow(1.0 - progress, 0.8)
	var t: float = age
	var color: Color = char_fx.color
	var offset: Vector2 = Vector2.ZERO
	var xform: Transform2D = char_fx.transform
	var text_len: float = maxf(float(char_fx.env.get("len", 1.0)), 1.0)

	var flicker: float = 0.5 + 0.5 * sin(t * 10.0 + idx * 0.73)
	var flutter: float = 0.5 + 0.5 * sin(t * 17.0 + idx * 1.41 + 0.7)
	var flare: float = pow(1.0 - progress, 0.42)
	var ambient: float = 0.55 + 0.45 * flicker
	var sustain: float = 0.45 + ambient * 0.4
	var hotspot: float = pow(1.0 - progress, 0.18)
	var settle_glow: float = 0.62 + ambient * 0.38 + (1.0 - progress) * 0.24
	var glow_boost: float = 1.64 + fade * 2.08 + flare * 1.58 + sustain * 1.12 + hotspot * 1.06 + settle_glow * 0.3

	match effect_key:
		"ice":
			var shimmer: float = sin(t * 13.0 + idx * 0.9)
			color = Color(
				0.72 + ambient * 0.12 + settle_glow * 0.02,
				0.96 + ambient * 0.12 + shimmer * 0.03,
				1.12 + glow_boost * 0.28,
				1.0
			)
			offset = Vector2(shimmer * (0.025 + fade * 0.11), -fade * 0.06)

		"lightning":
			color = Color(
				1.16 + glow_boost * 0.4,
				1.0 + ambient * 0.12 + settle_glow * 0.03,
				1.04 + glow_boost * 0.24,
				1.0
			)
			offset = Vector2(
				sin(t * 58.0 + idx * 4.6) * (0.22 + fade * 1.06),
				cos(t * 41.0 + idx * 2.4) * (0.08 + fade * 0.38)
			)

		"water":
			color = Color(
				0.64 + ambient * 0.11 + settle_glow * 0.02,
				0.9 + ambient * 0.11 + settle_glow * 0.03,
				1.08 + glow_boost * 0.26,
				1.0
			)
			offset = Vector2(
				sin(t * 8.4 + idx * 0.7) * (0.16 + fade * 0.82),
				cos(t * 6.8 + idx * 0.6) * (0.09 + fade * 0.34)
			)

		"plant":
			var grow: float = sin(t * 3.6 + idx * 0.24) * (0.02 + fade * 0.08)
			color = Color(
				0.16 + ambient * 0.02 + settle_glow * 0.008,
				0.56 + glow_boost * 0.14,
				0.1 + ambient * 0.025 + settle_glow * 0.008,
				1.0
			)
			offset = Vector2(grow, -absf(grow) * 0.7)

		"earth":
			color = Color(
				0.42 + glow_boost * 0.14,
				0.3 + ambient * 0.03 + settle_glow * 0.01,
				0.22 + ambient * 0.03 + settle_glow * 0.01,
				1.0
			)
			offset = Vector2(
				sin(t * 24.0 + idx) * (0.08 + fade * 0.45),
				sin(t * 18.0 + idx * 0.6) * (0.03 + fade * 0.22)
			)

		"light":
			color = Color(
				1.34 + glow_boost * 0.46,
				1.16 + ambient * 0.16 + settle_glow * 0.05,
				0.94 + ambient * 0.08 + settle_glow * 0.05,
				1.0
			)
			offset = Vector2(
				sin(t * 5.2 + idx * 0.38) * (0.03 + fade * 0.1),
				-(0.14 + fade * 0.94)
			)

		"dark":
			color = Color(
				0.48 + ambient * 0.03 + settle_glow * 0.01,
				0.46 + ambient * 0.02 + settle_glow * 0.01,
				0.72 + glow_boost * 0.18 + settle_glow * 0.04,
				1.0
			)
			offset = Vector2(
				sin(t * 8.4 + idx * 1.05) * (0.08 + fade * 0.28),
				cos(t * 6.9 + idx * 0.88) * (0.03 + fade * 0.14) + 0.03 + fade * 0.14
			)

		"air":
			var drift: float = sin(t * 4.8 + idx * 0.46)
			var gust: float = cos(t * 7.2 + idx * 0.31)
			color = Color(
				0.86 + ambient * 0.1 + glow_boost * 0.13,
				0.96 + ambient * 0.1 + glow_boost * 0.11,
				1.05 + ambient * 0.08 + glow_boost * 0.16,
				1.0
			)
			offset = Vector2(drift * (0.18 + fade * 0.72), gust * (0.04 + fade * 0.18) - fade * 0.08)

		"hit":
			var quake_x: float = sin(t * 42.0 + idx * 1.7) * (0.22 + fade * 1.05)
			quake_x += cos(t * 27.0 + idx * 0.9) * (0.08 + fade * 0.38)
			var quake_y: float = cos(t * 36.0 + idx * 2.2) * (0.05 + fade * 0.34)
			quake_y += sin(t * 53.0 + idx * 1.1) * (0.03 + fade * 0.22)
			color = Color(
				1.04 + glow_boost * 0.28,
				0.74 + fade * 0.22 + ambient * 0.1 + settle_glow * 0.04,
				0.48 + fade * 0.12 + settle_glow * 0.02,
				1.0
			)
			offset = Vector2(quake_x, quake_y)

		"move":
			var sway: float = sin(t * 4.6 + idx * 0.34)
			var length_factor: float = clampf((text_len - 4.0) / 8.0, 0.0, 1.0)
			var move_glow: float = glow_boost * 0.28 + settle_glow * 0.06
			color = Color(
				1.02 + move_glow,
				0.92 + ambient * 0.1 + move_glow * 0.16,
				0.84 + ambient * 0.08 + move_glow * 0.1,
				1.0
			)
			offset = Vector2(sway * (0.28 + fade * (0.95 + length_factor * 0.25)), -0.01 - fade * 0.03)
			xform = xform.rotated(sin(t * 3.2 + idx * 0.2) * (0.006 + fade * 0.012))
		_:
			return true

	char_fx.color = color
	char_fx.offset = offset
	char_fx.transform = xform
	return true
