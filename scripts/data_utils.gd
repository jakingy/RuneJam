class_name DataUtils
extends Node

static func load_api_key(path: String = "user://api_key.txt") -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var key := file.get_as_text().strip_edges()
	file.close()
	return key
