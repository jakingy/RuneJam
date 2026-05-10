extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print_tree_pretty()


func write_noun(w: String, t: int, e: String, mh: float, pa: 
	float, pd: float, ma: float, md: float, s: float) -> void:
	var noun: Noun = Noun.new(
		w,
		t,
		e,
		mh,
		pa,
		pd,
		ma,
		md,
		s	
	)
	
	ResourceSaver.save(noun, "res://words/nouns/%s.tres" % w);
