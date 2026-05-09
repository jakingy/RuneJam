class_name GeneratedImageCacheUtils
extends Node


static func shared_character_art_cache_seed(noun_text: String, adjectives: Array[String]) -> String:
	var adjective_parts: Array[String] = []
	for adjective in adjectives:
		adjective_parts.append(str(adjective).to_lower().strip_edges())

	adjective_parts.sort()

	return "nouns:%s\nadjectives:%s" % [
		noun_text.to_lower().strip_edges(),
		", ".join(adjective_parts),
	]


static func generated_image_cache_path(cache_dir: String, cache_seed: String, width: int, height: int) -> String:
	var digest := cache_seed.sha256_text()
	return "%s/%s_%dx%d.png" % [
		cache_dir,
		digest,
		_cache_dimension(width),
		_cache_dimension(height),
	]


static func ensure_user_directory(user_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_dir))


static func load_texture_from_user_image(user_path: String) -> Texture2D:
	if not FileAccess.file_exists(user_path):
		return null

	var image := Image.new()
	var load_err := image.load(ProjectSettings.globalize_path(user_path))
	if load_err != OK:
		return null

	return ImageTexture.create_from_image(image)


static func save_texture_to_user_png(texture: Texture2D, user_path: String) -> bool:
	if texture == null:
		return false

	var image := texture.get_image()
	if image == null or image.is_empty():
		return false

	ensure_user_directory(user_path.get_base_dir())
	return image.save_png(ProjectSettings.globalize_path(user_path)) == OK


static func _cache_dimension(value: int) -> int:
	return maxi(value, 256)