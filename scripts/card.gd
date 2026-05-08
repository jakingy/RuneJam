class_name Card
extends Resource

@export var noun: Noun
@export var adjectives: Array[Adjective]

func _init(p_noun: Noun = null, p_adjectives: Array[Adjective] = []):
	noun = p_noun
	adjectives = p_adjectives
