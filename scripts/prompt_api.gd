class_name PromptAPI
extends Node

static func fuse_adjectives(adjectives: Array[String]) -> String:
	"""
	Takes list of adjectives, returns string which is resulting adjective. 
	Resulting adjective can have spaces e.g. "void bound" or "void-bound"

	If API or HTTP fails in anyway, explodes
	"""
	var prompt_text := DataUtils.load_prompt_text("res://prompts/adjective-fusion.txt")
	var result: Dictionary = await OpenaiClient.call_text(
		{},
		JSON.stringify(adjectives),
		prompt_text,
		"",
		"none"
	)
	return result["text"] # this may not exist and explode if there was an error

static func fuse_nouns(nouns: Array[String]) -> String:
	"""
	Takes list of nouns, returns string which is resulting noun. 
	Resulting nouns can have spaces e.g. "goblin engineer"

	If API or HTTP fails in anyway, explodes
	"""
	var prompt_text := DataUtils.load_prompt_text("res://prompts/noun-fusion.txt")
	var result: Dictionary = await OpenaiClient.call_text(
		{},
		JSON.stringify(nouns),
		prompt_text,
		"",
		"none"
	)
	return result["text"]
