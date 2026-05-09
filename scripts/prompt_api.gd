class_name PromptAPI
extends Node

static func fuse_adjectives(adjectives: Array[String]) -> String:
	"""
	Takes list of adjectives, returns string which is resulting adjective. 
	Resulting adjective can have spaces e.g. "void bound" or "void-bound"

	If API or HTTP fails in anyway, returns empty string
	"""
	var prompt_text := DataUtils.load_prompt_text("res://prompts/adjective-fusion.txt")
	var result: Dictionary = await OpenaiClient.call_text(
		{},
		JSON.stringify(adjectives),
		prompt_text,
		"",
		"none"
	)
	return result["text"] if result.has("text") else ""

static func fuse_nouns(nouns: Array[String]) -> String:
	"""
	Takes list of nouns, returns string which is resulting noun. 
	Resulting nouns can have spaces e.g. "goblin engineer"

	If API or HTTP fails in anyway, returns empty string
	"""
	var prompt_text := DataUtils.load_prompt_text("res://prompts/noun-fusion.txt")
	var result: Dictionary = await OpenaiClient.call_text(
		{},
		JSON.stringify(nouns),
		prompt_text,
		"",
		"none"
	)
	return result["text"] if result.has("text") else ""

static func get_image_from_prompt(image_prompt: String, width=256, height=256) -> ImageTexture:
	var runware_resp = await RunwareClient.generate_image(image_prompt, width, height)
	var url := str(runware_resp.get("url", "")).strip_edges()
	if url.is_empty():
		return null
	var download_resp = await RunwareClient.download_image(url)
	return download_resp.get("texture", null)

static func make_character_image_gen_prompt(noun: String, adjectives: Array[String]) -> String:
	# For adjecitve cards, use noun = "magical sigil" and add the adjective to the adjectives list
	var adjective_text := ", ".join(adjectives)
	var prompt_input := "Noun: %s\nAdjectives: %s" % [noun, adjective_text]
	var prompt_text := DataUtils.load_prompt_text("res://prompts/character-image-prompt-generator.txt")
	var result: Dictionary = await OpenaiClient.call_text(
		{},
		prompt_input,
		prompt_text,
		"gpt-5.4-nano",
		"low"
	)
	return result["text"] if result.has("text") else ""

static func make_character_image(noun: String, adjectives: Array[String]) -> ImageTexture:
	"""
	Returns an ImageTexture for a given noun and adjective combo character.
	If API or HTTP fails in anyway, returns null
	"""
	var image_prompt := await make_character_image_gen_prompt(noun, adjectives)
	return await get_image_from_prompt(image_prompt)

static func make_map_image_gen_prompt(state: Dictionary) -> String:
	var prompt_text := DataUtils.load_prompt_text("res://prompts/map-image-prompt-generator.txt")
	var result: Dictionary = await OpenaiClient.call_text(
		{},
		JSON.stringify(state),
		prompt_text,
		"gpt-5.4-mini",
		"low"
	)
	return result["text"] if result.has("text") else ""
	
static func make_map_image(initial_state: Dictionary) -> ImageTexture:
	var image_prompt := await make_map_image_gen_prompt(initial_state)
	return await get_image_from_prompt(image_prompt, 1024, 1024)
