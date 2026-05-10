extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Offensive Biases (Physical)
	write_adj("Savage", 1, -0.2, 0.6, -0.3, -0.5, -0.4, 0.3)
	write_adj("Brutal", 2, 0.1, 0.8, -0.2, -0.6, -0.5, -0.1)
	write_adj("Heavy", 1, 0.3, 0.5, 0.2, -0.4, -0.2, -0.7)
	write_adj("Frenetic", 2, -0.4, 0.5, -0.5, -0.2, -0.2, 0.9)
	write_adj("Sharpened", 1, -0.1, 0.4, -0.1, 0.0, -0.1, 0.2)

	# Offensive Biases (Magic)
	write_adj("Mystic", 1, -0.2, -0.5, -0.2, 0.7, 0.4, 0.0)
	write_adj("Arcane", 2, -0.1, -0.6, -0.3, 0.9, 0.5, -0.1)
	write_adj("Ethereal", 3, -0.5, -0.8, -0.5, 1.0, 0.8, 0.4)
	write_adj("Unstable", 2, -0.4, 0.4, -0.4, 0.8, -0.4, 0.3)
	write_adj("Wise", 1, 0.1, -0.4, 0.0, 0.5, 0.5, -0.2)

	# Defensive Biases
	write_adj("Sturdy", 1, 0.4, -0.1, 0.5, -0.3, 0.1, -0.4)
	write_adj("Reinforced", 2, 0.5, -0.2, 0.8, -0.5, 0.2, -0.6)
	write_adj("Warded", 2, 0.2, -0.4, 0.2, -0.2, 0.9, -0.3)
	write_adj("Sluggish", 1, 0.8, 0.2, 0.6, -0.4, -0.2, -0.9)
	write_adj("Impenetrable", 4, 0.6, -0.5, 1.0, -0.8, 0.6, -0.8)

	# Speed & Agility Biases
	write_adj("Quick", 1, -0.2, 0.1, -0.2, 0.0, -0.1, 0.6)
	write_adj("Fleet", 2, -0.3, 0.2, -0.4, 0.1, -0.2, 0.9)
	write_adj("Blurring", 3, -0.5, 0.0, -0.6, 0.3, -0.4, 1.0)
	write_adj("Fragile", 1, -0.7, 0.4, -0.6, 0.4, -0.4, 0.8)
	write_adj("Nimble", 1, -0.1, 0.2, -0.2, -0.1, 0.1, 0.5)

	# Health & Endurance Biases
	write_adj("Ancient", 3, 0.9, -0.2, 0.4, 0.4, 0.5, -0.7)
	write_adj("Healthy", 1, 0.6, -0.1, 0.1, -0.1, 0.1, -0.2)
	write_adj("Bloated", 1, 0.7, -0.3, 0.2, -0.5, -0.4, -0.6)
	write_adj("Vast", 4, 1.0, 0.0, 0.5, 0.0, 0.4, -0.8)
	write_adj("Tired", 1, 0.3, -0.4, -0.2, -0.2, -0.1, -0.5)

	# Cursed & High-Risk Biases
	write_adj("Glass", 5, -1.0, 0.9, -1.0, 0.9, -1.0, 0.7)
	write_adj("Cursed", 2, -0.5, 0.6, -0.3, 0.6, -0.3, -0.2)
	write_adj("Hollow", 1, -0.6, -0.2, -0.5, 0.5, 0.5, 0.3)
	write_adj("Raging", 2, -0.4, 0.7, -0.6, -0.4, -0.6, 0.6)
	write_adj("Blighted", 3, -0.3, 0.5, -0.4, 0.5, -0.4, -0.2)

	# Utility & Balanced Biases
	write_adj("Polished", 1, 0.1, 0.1, 0.1, 0.1, 0.1, -0.1)
	write_adj("Jagged", 1, -0.2, 0.4, -0.2, 0.1, -0.1, 0.2)
	write_adj("Dull", 1, 0.2, -0.4, 0.3, -0.4, 0.2, -0.1)
	write_adj("Elite", 5, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4) # Rare pure buff
	write_adj("Common", 1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1)

	# Elemental-Themed (Stat focus)
	write_adj("Volcanic", 3, 0.3, 0.7, -0.2, 0.5, -0.4, -0.3)
	write_adj("Glacial", 3, 0.5, -0.2, 0.7, -0.3, 0.6, -0.8)
	write_adj("Static", 2, -0.3, 0.3, -0.3, 0.6, -0.1, 0.8)
	write_adj("Lush", 2, 0.6, -0.3, 0.4, 0.2, 0.5, -0.5)
	write_adj("Grounded", 2, 0.4, 0.3, 0.7, -0.6, 0.2, -0.7)

	# Personality/Style Biases
	write_adj("Cowardly", 1, -0.2, -0.5, -0.3, -0.2, -0.2, 0.9)
	write_adj("Heroic", 4, 0.6, 0.6, 0.5, 0.2, 0.3, 0.2)
	write_adj("Vengeful", 3, -0.3, 0.8, -0.4, 0.6, -0.4, 0.3)
	write_adj("Lazy", 1, 0.5, -0.3, 0.2, -0.5, 0.1, -0.8)
	write_adj("Manic", 2, -0.5, 0.4, -0.5, 0.4, -0.5, 1.0)

	# Mythic Biases
	write_adj("Divine", 5, 0.8, 0.5, 0.5, 0.8, 0.8, 0.2)
	write_adj("Demonic", 5, 0.5, 0.9, 0.2, 0.9, 0.2, 0.6)
	write_adj("Ghostly", 3, -0.8, -0.5, -0.8, 0.9, 0.7, 0.9)
	write_adj("Titanic", 5, 1.0, 0.8, 0.8, -0.5, 0.4, -0.9)
	write_adj("Faded", 1, -0.4, -0.4, -0.4, -0.4, -0.4, -0.2)

	print("done")
	

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
