@tool
extends RichTextEffect
class_name FireballRichTextEffect

var bbcode := "fire"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var pulse_speed := float(char_fx.env.get("pulse", 9.0))
	var rise := float(char_fx.env.get("rise", 2.3))
	var sway := float(char_fx.env.get("sway", 0.85))
	var idx := float(char_fx.relative_index)
	var t := char_fx.elapsed_time * pulse_speed
	var flame := 0.5 + 0.5 * sin(t * 1.07 + idx * 0.61)
	var ember := 0.5 + 0.5 * sin(t * 0.58 + idx * 1.17 + 0.9)
	var lick := 0.5 + 0.5 * sin(t * 1.93 + idx * 0.33 + 0.35)
	var spit := 0.5 + 0.5 * sin(t * 3.24 + idx * 1.83 + 1.4)
	var churn := 0.5 + 0.5 * sin(t * 0.81 + idx * 0.93 + sin(t * 0.37 + idx) * 0.7)
	var hot: float = clampf(flame * 0.42 + ember * 0.18 + lick * 0.22 + spit * 0.1 + churn * 0.08, 0.0, 1.0)
	var ember_mix: float = clampf(ember * 0.45 + lick * 0.25 + spit * 0.18 + churn * 0.12, 0.0, 1.0)
	var fire_mix: float = clampf(hot * 0.82 + spit * 0.1 + flame * 0.08, 0.0, 1.0)
	var glow_mix: float = clampf(fire_mix * 0.85 + lick * 0.1 + spit * 0.05, 0.0, 1.0)
	var flare: float = pow(glow_mix, 0.55)
	var glow_boost: float = 1.0 + glow_mix * 2.85 + flare * 0.9
	char_fx.color = Color(
		lerpf(0.9, 1.0, fire_mix) * glow_boost,
		lerpf(0.08, 0.8, ember_mix) * (1.0 + glow_mix * 0.8 + flare * 0.2),
		lerpf(0.0, 0.2, clampf(fire_mix * 0.78 + ember_mix * 0.1, 0.0, 1.0)),
		1.0
	)
	var drift_x: float = sin(t * 0.73 + idx * 0.41) * sway
	drift_x += sin(t * 1.87 + idx * 1.11) * sway * 0.35
	var drift_y: float = -(hot * rise + lick * 0.95 + spit * 0.55 + churn * 0.4)
	char_fx.offset = Vector2(drift_x, drift_y)
	return true
