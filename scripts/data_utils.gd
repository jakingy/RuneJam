class_name DataUtils
extends Node

static func read_file_text(path: String = "user://api_key.txt") -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

static func load_api_key(path: String = "user://api_key.txt") -> String:
	return read_file_text(path).strip_edges()

static var prompt_cache := {}
static func load_prompt_text(path: String) -> String:
	if prompt_cache.has(path):
		return str(prompt_cache[path])
	var text = read_file_text(path)
	prompt_cache[path] = text
	return text
