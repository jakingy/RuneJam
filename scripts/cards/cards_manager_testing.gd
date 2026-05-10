extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	CardsManager.init_deck()
	var noun: Noun = CardsManager.draw_nouns(1)[0]
	
	var adjs: Array[Adjective] = CardsManager.draw_adjectives(3)
	var card: Card = Card.new(noun, adjs)
	
	print(card.get_name_str())
	print(card.get_total_tier())
	print(card.get_max_health())
	print(card.get_physical_attack())
	print(card.get_physical_defence())
	print(card.get_magic_attack())
	print(card.get_magic_defence())
	print(card.get_speed())
	
	

func write_adj(w: String, t: float, mh: float, pa: 
	float, pd: float, ma: float, md: float, s: float) -> void:
	var adj: Adjective = Adjective.new(
		w,
		t,
		mh,
		pa,
		pd,
		ma,
		md,
		s    
	)
	
	ResourceSaver.save(adj, "res://words/adjectives/%s.tres" % w);

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
