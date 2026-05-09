@tool
extends RichTextEffect
class_name GlowRichTextEffect

var bbcode := "glow"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var r := float(char_fx.env.get("r", 1.0))
	var g := float(char_fx.env.get("g", 1.0))
	var b := float(char_fx.env.get("b", 1.0))
	var glow_color := Color(r, g, b, 1.0)
	var settle := float(char_fx.env.get("settle", 1.45))
	var decay := float(char_fx.env.get("decay", 1.08))
	var age := maxf(char_fx.elapsed_time, 0.0)
	if age >= settle:
		return true
	var progress := clampf(age / settle, 0.0, 1.0)
	var strength := pow(1.0 - progress, decay)
	char_fx.color = char_fx.color.lerp(glow_color, strength)
	return true
