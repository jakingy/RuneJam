extends Node

var api_key: String
const DEFAULT_NEGATIVE_PROMPT := "text, letters, words, title, name, watermark, logo, signature, caption, subtitle, ui, interface"
const IMAGE_MODEL_KLIEN_4B := "runware:400@4"
const IMAGE_MODEL_KLIEN_9B := "runware:400@6"
const DEFAULT_IMAGE_MODEL := IMAGE_MODEL_KLIEN_9B


func _ready() -> void:
	api_key = DataUtils.load_api_key("user://runware_api_key.txt")


func generate_image(prompt: String, width: int = 256, height: int = 256, negative_prompt: String = DEFAULT_NEGATIVE_PROMPT, model: String = DEFAULT_IMAGE_MODEL) -> Dictionary:
	var http: HTTPRequest = await DataUtils.spawn_http_request()
	if http == null:
		return {"error": "HTTP request setup failed: request node was not added to the scene tree"}

	var headers := [
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
	]

	var task_uuid := _generate_uuid()
	var task := {
		"taskType": "imageInference",
		"model": model,
		"positivePrompt": prompt,
		"width": width,
		"height": height,
		"numberResults": 1,
		"outputType": ["URL"],
		"CFGScale": 4,
		"steps": 4,
		"includeCost": true,
		"acceleration": "high",
		"skipResponse": false,
		"deliveryMethod": "sync",
		"outputQuality": 85,
		"taskUUID": task_uuid,
	}
	var trimmed_negative_prompt := negative_prompt.strip_edges()
	if not trimmed_negative_prompt.is_empty():
		task["negativePrompt"] = trimmed_negative_prompt
	var payload := [task]

	var body := JSON.stringify(payload)
	var err := http.request("https://api.runware.ai/v1", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"error": "HTTP request failed: %d" % err}

	var result: Array = await http.request_completed
	http.queue_free()

	var http_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]

	if http_result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "HTTP error (result %d)" % http_result}

	if response_code != 200:
		var err_body := response_body.get_string_from_utf8()
		return {"error": "HTTP %d: %s" % [response_code, err_body.substr(0, 300)]}

	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		return {"error": "JSON parse error"}

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var images: Array = data.get("data", [])
	if images.size() > 0 and images[0] is Dictionary:
		var url: String = images[0].get("imageURL", "")
		if not url.is_empty():
			return {"url": url}

	return {"error": "No image URL in response"}


func download_image(url: String) -> Dictionary:
	var http: HTTPRequest = await DataUtils.spawn_http_request()
	if http == null:
		return {"error": "HTTP request setup failed: request node was not added to the scene tree"}

	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return {"error": "Download request failed: %d" % err}

	var result: Array = await http.request_completed
	http.queue_free()

	var http_result: int = result[0]
	var response_code: int = result[1]
	var response_headers: Array = result[2]
	var response_body: PackedByteArray = result[3]

	if http_result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Download error (result %d)" % http_result}

	if response_code != 200:
		return {"error": "Download HTTP %d" % response_code}

	var img := Image.new()
	var image_format := _detect_image_format(response_body, response_headers)
	var load_err := ERR_PARSE_ERROR
	match image_format:
		"png":
			load_err = img.load_png_from_buffer(response_body)
		"jpg":
			load_err = img.load_jpg_from_buffer(response_body)
		"webp":
			load_err = img.load_webp_from_buffer(response_body)
		_:
			return {"error": "Unknown image format"}
	if load_err != OK:
		return {"error": "Failed to decode image"}

	var texture := ImageTexture.create_from_image(img)
	return {"texture": texture}


func _detect_image_format(bytes: PackedByteArray, headers: Array) -> String:
	var content_type := _get_header_value(headers, "content-type").to_lower()
	if content_type.contains("png"):
		return "png"
	if content_type.contains("jpeg") or content_type.contains("jpg"):
		return "jpg"
	if content_type.contains("webp"):
		return "webp"

	if bytes.size() >= 12:
		if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
			return "png"
		if bytes[0] == 0xFF and bytes[1] == 0xD8:
			return "jpg"
		if bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
			return "webp"

	return ""


func _get_header_value(headers: Array, header_name: String) -> String:
	var prefix := header_name.to_lower() + ":"
	for header in headers:
		var header_text := str(header)
		if header_text.to_lower().begins_with(prefix):
			return header_text.substr(prefix.length()).strip_edges()
	return ""


func _generate_uuid() -> String:
	var chars := "0123456789abcdef"
	var uuid := ""
	for i in 32:
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		uuid += chars[randi() % 16]
	return uuid
