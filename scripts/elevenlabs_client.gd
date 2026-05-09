extends Node

const API_KEY_PATH: String = "user://elevenlabs_api_key.txt"
const DEFAULT_OUTPUT_FORMAT: String = "pcm_24000"
const DEFAULT_STREAMING_LATENCY: int = 3
const DEFAULT_MODEL_ID: String = "eleven_flash_v2_5"

var api_key: String = ""


func _ready() -> void:
	api_key = load_api_key()
	if api_key.is_empty():
		print_debug("ElevenLabsClient: no API key found at %s" % API_KEY_PATH)


func load_api_key(path: String = API_KEY_PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var key = file.get_as_text().strip_edges()
	file.close()
	return key


func reload_api_key() -> String:
	api_key = load_api_key()
	return api_key


func has_api_key() -> bool:
	return not api_key.strip_edges().is_empty()


func save_api_key(new_api_key: String, path: String = API_KEY_PATH) -> bool:
	var trimmed = new_api_key.strip_edges()
	if trimmed.is_empty():
		return false

	var absolute_path = ProjectSettings.globalize_path(path)
	var dir_path = absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_err = DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_err != OK:
			push_warning("ElevenLabsClient: failed to create key directory: %s" % dir_path)
			return false

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("ElevenLabsClient: failed to open API key file for writing: %s" % path)
		return false
	file.store_string(trimmed)
	file.close()
	api_key = trimmed
	return true


func clear_api_key(path: String = API_KEY_PATH) -> void:
	api_key = ""
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func synthesize_speech_to_file(
	text: String,
	voice_id: String,
	model_id: String = DEFAULT_MODEL_ID,
	output_path: String = "user://tts.mp3",
	output_format: String = DEFAULT_OUTPUT_FORMAT,
	voice_speed: float = 1.0
) -> Dictionary:
	var trimmed_text = text.strip_edges()
	var trimmed_voice_id = voice_id.strip_edges()
	var trimmed_model_id = model_id.strip_edges()
	var trimmed_output_format = output_format.strip_edges()

	if api_key.strip_edges().is_empty():
		return {"error": "Missing ElevenLabs API key. Create user://elevenlabs_api_key.txt or call ElevenLabsClient.save_api_key(...)."}
	if trimmed_text.is_empty():
		return {"error": "Cannot synthesize empty text"}
	if trimmed_voice_id.is_empty():
		return {"error": "Missing ElevenLabs voice id"}
	if trimmed_model_id.is_empty():
		trimmed_model_id = DEFAULT_MODEL_ID
	if trimmed_output_format.is_empty():
		trimmed_output_format = DEFAULT_OUTPUT_FORMAT

	var http: HTTPRequest = await _spawn_http_request()
	if http == null:
		return {"error": "HTTP request setup failed: request node was not added to the scene tree"}

	var headers = PackedStringArray([
		"xi-api-key: %s" % api_key,
		"Content-Type: application/json",
		"Accept: application/octet-stream",
	])
	var body = _build_tts_body(trimmed_text, trimmed_model_id, voice_speed)
	var request_url = "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=%s" % [
		trimmed_voice_id.uri_encode(),
		trimmed_output_format.uri_encode(),
	]

	var err = http.request(request_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body, "", false))
	if err != OK:
		http.queue_free()
		return {"error": "HTTP request failed: %d" % err}

	var result: Array = await http.request_completed
	http.queue_free()

	var http_result = int(result[0])
	var response_code = int(result[1])
	var response_body: PackedByteArray = result[3]

	if http_result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "HTTP error (result %d)" % http_result}
	if response_code != 200:
		var err_body = response_body.get_string_from_utf8()
		return {"error": "HTTP %d: %s" % [response_code, err_body.substr(0, 500)]}

	var save_result = _save_bytes_to_user_file(response_body, output_path)
	if save_result.has("error"):
		return save_result
	return {"path": output_path, "bytes": response_body}


func stream_speech_to_file(
	text: String,
	voice_id: String,
	model_id: String = DEFAULT_MODEL_ID,
	output_format: String = DEFAULT_OUTPUT_FORMAT,
	output_path: String = "user://tts.mp3",
	on_chunk: Callable = Callable(),
	voice_speed: float = 1.0,
	optimize_streaming_latency: int = DEFAULT_STREAMING_LATENCY
) -> Dictionary:
	var result: Dictionary = await stream_speech(
		text,
		voice_id,
		model_id,
		output_format,
		on_chunk,
		voice_speed,
		optimize_streaming_latency
	)
	if result.has("error"):
		return result

	var bytes: PackedByteArray = result.get("bytes", PackedByteArray())
	var save_result = _save_bytes_to_user_file(bytes, output_path)
	if save_result.has("error"):
		return save_result
	result["path"] = output_path
	return result


func stream_speech(
	text: String,
	voice_id: String,
	model_id: String = DEFAULT_MODEL_ID,
	output_format: String = DEFAULT_OUTPUT_FORMAT,
	on_chunk: Callable = Callable(),
	voice_speed: float = 1.0,
	optimize_streaming_latency: int = DEFAULT_STREAMING_LATENCY
) -> Dictionary:
	var trimmed_text = text.strip_edges()
	var trimmed_voice_id = voice_id.strip_edges()
	var trimmed_model_id = model_id.strip_edges()
	var trimmed_output_format = output_format.strip_edges()

	if api_key.strip_edges().is_empty():
		return {"error": "Missing ElevenLabs API key. Create user://elevenlabs_api_key.txt or call ElevenLabsClient.save_api_key(...)."}
	if trimmed_text.is_empty():
		return {"error": "Cannot synthesize empty text"}
	if trimmed_voice_id.is_empty():
		return {"error": "Missing ElevenLabs voice id"}
	if trimmed_model_id.is_empty():
		trimmed_model_id = DEFAULT_MODEL_ID
	if trimmed_output_format.is_empty():
		trimmed_output_format = DEFAULT_OUTPUT_FORMAT

	var http = HTTPClient.new()
	var connect_err = http.connect_to_host("https://api.elevenlabs.io")
	if connect_err != OK:
		return {"error": "HTTP stream connect failed: %d" % connect_err}

	while http.get_status() == HTTPClient.STATUS_RESOLVING or http.get_status() == HTTPClient.STATUS_CONNECTING:
		http.poll()
		await Engine.get_main_loop().process_frame

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "HTTP stream connection failed (status %d)" % http.get_status()}

	var latency = clampi(optimize_streaming_latency, 0, 4)
	var headers = PackedStringArray([
		"xi-api-key: %s" % api_key,
		"Content-Type: application/json",
		"Accept: application/octet-stream",
	])
	var body = _build_tts_body(trimmed_text, trimmed_model_id, voice_speed)
	var path = "/v1/text-to-speech/%s/stream?output_format=%s&optimize_streaming_latency=%d" % [
		trimmed_voice_id.uri_encode(),
		trimmed_output_format.uri_encode(),
		latency,
	]

	var request_err = http.request(HTTPClient.METHOD_POST, path, headers, JSON.stringify(body, "", false))
	if request_err != OK:
		return {"error": "HTTP stream request failed: %d" % request_err}

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await Engine.get_main_loop().process_frame

	if not http.has_response():
		return {"error": "No streaming response received"}

	var response_code = http.get_response_code()
	var response_bytes = PackedByteArray()
	var error_text = ""

	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk = http.read_response_body_chunk()
		if chunk.size() == 0:
			await Engine.get_main_loop().process_frame
			continue
		if response_code == 200:
			response_bytes.append_array(chunk)
			if on_chunk.is_valid():
				on_chunk.call(chunk)
		else:
			error_text += chunk.get_string_from_utf8()

	if response_code != 200:
		return {"error": "HTTP %d: %s" % [response_code, error_text.substr(0, 500)]}

	return {"bytes": response_bytes}


func load_audio_stream_from_file(user_path: String) -> AudioStream:
	if not FileAccess.file_exists(user_path):
		return null
	var lower_path = user_path.to_lower()
	if lower_path.ends_with(".mp3") and ClassDB.class_exists("AudioStreamMP3"):
		return AudioStreamMP3.load_from_file(user_path)
	if lower_path.ends_with(".ogg") and ClassDB.class_exists("AudioStreamOggVorbis"):
		return AudioStreamOggVorbis.load_from_file(user_path)
	if lower_path.ends_with(".wav") and ClassDB.class_exists("AudioStreamWAV"):
		return AudioStreamWAV.load_from_file(user_path)
	var loaded = load(user_path)
	return loaded as AudioStream


func play_user_audio_file(user_path: String, parent: Node = null, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream = load_audio_stream_from_file(user_path)
	if stream == null:
		push_warning("ElevenLabsClient: could not load audio stream: %s" % user_path)
		return null
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	var target_parent = parent if parent != null else self
	target_parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


func _spawn_http_request() -> HTTPRequest:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null:
		return null
	var tree = main_loop as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null

	var http = HTTPRequest.new()
	if root.is_node_ready():
		root.add_child(http)
	else:
		root.call_deferred("add_child", http)

	var tries = 0
	while is_instance_valid(http) and not http.is_inside_tree() and tries < 16:
		await tree.process_frame
		tries += 1
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return null
	return http


func _build_tts_body(text: String, model_id: String, voice_speed: float) -> Dictionary:
	return {
		"text": text,
		"model_id": model_id,
		"voice_settings": {
			"speed": voice_speed,
		},
	}


func _save_bytes_to_user_file(bytes: PackedByteArray, user_path: String) -> Dictionary:
	if bytes.is_empty():
		return {"error": "Cannot save empty audio response"}
	var absolute_output_path = ProjectSettings.globalize_path(user_path)
	var output_dir = absolute_output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir):
		var mkdir_err = DirAccess.make_dir_recursive_absolute(output_dir)
		if mkdir_err != OK:
			return {"error": "Failed to create ElevenLabs audio cache directory"}
	var file = FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		return {"error": "Failed to open ElevenLabs audio output file for writing"}
	file.store_buffer(bytes)
	file.close()
	return {"path": user_path}
