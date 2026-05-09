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

static func spawn_http_request() -> HTTPRequest:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null:
		return null
	var tree := main_loop as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	var http := HTTPRequest.new()
	if root.is_node_ready():
		root.add_child(http)
	else:
		root.call_deferred("add_child", http)
	var tries: int = 0
	while is_instance_valid(http) and not http.is_inside_tree() and tries < 8:
		await tree.process_frame
		tries += 1
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return null
	return http

static func load_png_texture(texture_path: String) -> Texture2D:
	if not FileAccess.file_exists(texture_path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(texture_path)
	if bytes.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)
