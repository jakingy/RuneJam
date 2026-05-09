@tool
extends RichTextEffect
class_name WritingRichTextEffect

var bbcode := "writing"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var settle := float(char_fx.env.get("settle", 0.75))
	var lift := float(char_fx.env.get("lift", 1.4))
	var glow := float(char_fx.env.get("glow", 0.0))
	var drop := float(char_fx.env.get("drop", 0.0))
	var tail_decay := float(char_fx.env.get("tail_decay", 1.55))
	var tail_strength := float(char_fx.env.get("tail_strength", 0.9))
	var age := maxf(char_fx.elapsed_time, 0.0)
	if age >= settle:
		return true

	var progress := clampf(age / settle, 0.0, 1.0)
	var _hotspot := pow(1.0 - progress, 0.07)
	var hotspot_falloff := pow(1.0 - progress, 2.7)
	var tail := pow(1.0 - progress, tail_decay)
	var warm_strength := clampf(tail * tail_strength + hotspot_falloff * 0.7, 0.0, 1.0)
	var flare := pow(1.0 - progress, 6.5)
	var glow_color := Color(
		1.0 + glow * 1.35 + hotspot_falloff * 1.15 + flare * 2.2,
		0.9 + glow * 0.78 + hotspot_falloff * 0.55 + flare * 1.3,
		0.58 + glow * 0.14 + hotspot_falloff * 0.1 + flare * 0.18,
		1.0
	)
	char_fx.color = char_fx.color.lerp(glow_color, warm_strength)
	var drop_from_above := drop * (hotspot_falloff * 0.85 + flare * 0.9)
	char_fx.offset = Vector2(0.0, -(lift * tail + hotspot_falloff * 0.9 + flare * 0.55 + drop_from_above))
	return true
