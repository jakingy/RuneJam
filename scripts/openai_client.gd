extends Node

var api_key: String
const DEFAULT_MODEL: String = "gpt-5.4-mini"
const DEFAULT_REASONING: String = "medium"
const DEFAULT_VERBOSITY: String = "low"

func _ready() -> void:
	api_key = DataUtils.load_api_key()

func _serialize_if_json(input_obj: Variant) -> String:
	if input_obj is String:
		return input_obj
	return JSON.stringify(input_obj)

func _has_prompt(prompt: Variant) -> bool:
	return prompt is Dictionary and not (prompt as Dictionary).is_empty()

func _build_input_messages(
	input_obj: Variant,
	instructions: String = ""
) -> Array:
	var messages: Array = []
	if not instructions.strip_edges().is_empty():
		messages.append({"role": "developer", "content": instructions})
	messages.append({"role": "user", "content": _serialize_if_json(input_obj)})
	return messages


func _spawn_http_request() -> HTTPRequest:
	var main_loop := Engine.get_main_loop()
	if main_loop == null:
		return null

	var tree := main_loop as SceneTree
	if tree == null or tree.root == null:
		return null

	var http := HTTPRequest.new()
	if tree.root.is_node_ready():
		tree.root.add_child(http)
	else:
		tree.root.call_deferred("add_child", http)
	var tries: int = 0
	while is_instance_valid(http) and not http.is_inside_tree() and tries < 8:
		await tree.process_frame
		tries += 1
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return null
	return http

func _extract_output_text(data: Dictionary) -> String:
	var output: Array = data.get("output", [])
	for item in output:
		if item.get("type", "") == "message":
			var content: Array = item.get("content", [])
			for c in content:
				if c.get("type", "") == "output_text":
					return c.get("text", "")
	return ""
	
func call_structured(
	prompt: Variant,
	input_obj: Variant,
	schema_name: String,
	schema: Dictionary,
	instructions: String = "",
	model_override: String = "",
	effort_override: String = ""
) -> Dictionary:
	var http: HTTPRequest = await _spawn_http_request()
	if http == null:
		return {"error": "HTTP request setup failed: request node was not added to the scene tree"}

	var headers = PackedStringArray([
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
	])

	var body = {
		"model": model_override if not model_override.is_empty() else DEFAULT_MODEL,
		"reasoning": {"effort": effort_override if not effort_override.is_empty() else DEFAULT_REASONING},
		"input": _build_input_messages(input_obj, instructions),
		"text": {
			"format": {"type": "json_schema", "name": schema_name, "strict": true, "schema": schema},
			"verbosity": DEFAULT_VERBOSITY,
		},
	}
	if _has_prompt(prompt):
		body["prompt"] = prompt

	var t0 = Time.get_ticks_msec()
	var request_body = JSON.stringify(body, "", false)
	print_debug("DEBUG: Sending request, body length: ", request_body.length())
	var err = http.request("https://api.openai.com/v1/responses", headers, HTTPClient.METHOD_POST, request_body)
	if err != OK:
		print("DEBUG: Request failed with error: ", err)
		http.queue_free()
		return {"error": "HTTP request failed: %d" % err}

	print_debug("DEBUG: Waiting for response...")
	var result: Array = await http.request_completed
	http.queue_free()

	var http_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	print("DEBUG: Got response - http_result: ", http_result, " code: ", response_code, " body length: ", response_body.size())

	if http_result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "HTTP request error (result code %d). Check your API key and internet connection." % http_result}

	if response_code != 200:
		var err_body = response_body.get_string_from_utf8()
		print("DEBUG: Non-200 response: ", err_body.substr(0, 500))
		return {"error": "HTTP %d: %s" % [response_code, err_body.substr(0, 300)]}

	var json = JSON.new()
	var body_str = response_body.get_string_from_utf8()
	var parse_err = json.parse(body_str)
	if parse_err != OK:
		return {"error": "JSON parse error: %s" % body_str.substr(0, 200)}

	if json.data == null or not (json.data is Dictionary):
		return {"error": "Unexpected response format: %s" % body_str.substr(0, 200)}

	var data: Dictionary = json.data
	if data.has("error") and data["error"] != null:
		var err_val = data["error"]
		var err_msg = err_val.get("message", str(err_val)) if err_val is Dictionary else str(err_val)
		return {"error": err_msg}

	var output_text = _extract_output_text(data)
	if output_text.is_empty():
		return {"error": "No output text in response"}
	print("DEBUG: Raw structured output text before JSON parse:\n%s" % output_text)

	var elapsed = (Time.get_ticks_msec() - t0) / 1000.0

	var result_json = JSON.new()
	var p_err = result_json.parse(output_text)
	if p_err != OK:
		return {"error": "Failed to parse output JSON"}

	return {"result": result_json.data, "elapsed": "%.1f" % elapsed}


func call_structured_streaming(
	prompt: Variant,
	input_obj: Variant,
	schema_name: String,
	schema: Dictionary,
	stream_fields: Array,
	stream_array_item_fields: Array = [],
	on_field: Callable = Callable(),
	on_field_done: Callable = Callable(),
	instructions: String = "",
	model_override: String = "",
	effort_override: String = "",
) -> Dictionary:
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
	])

	var body := {
		"model": model_override if not model_override.is_empty() else DEFAULT_MODEL,
		"reasoning": {"effort": effort_override if not effort_override.is_empty() else DEFAULT_REASONING},
		"input": _build_input_messages(input_obj, instructions),
		"text": {
			"format": {"type": "json_schema", "name": schema_name, "strict": true, "schema": schema},
			"verbosity": DEFAULT_VERBOSITY,
		},
		"stream": true,
	}
	if _has_prompt(prompt):
		body["prompt"] = prompt

	var t0 := Time.get_ticks_msec()
	var http := HTTPClient.new()
	var err := http.connect_to_host("https://api.openai.com")
	if err != OK:
		return {"error": "HTTP stream connect failed: %d" % err}

	while http.get_status() == HTTPClient.STATUS_RESOLVING or http.get_status() == HTTPClient.STATUS_CONNECTING:
		http.poll()
		await Engine.get_main_loop().process_frame

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "HTTP stream connection failed (status %d)" % http.get_status()}

	var request_body := JSON.stringify(body, "", false)
	err = http.request(HTTPClient.METHOD_POST, "/v1/responses", headers, request_body)
	if err != OK:
		return {"error": "HTTP stream request failed: %d" % err}

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await Engine.get_main_loop().process_frame

	if not http.has_response():
		return {"error": "No streaming response received"}

	var response_code := http.get_response_code()
	var line_buffer := ""
	var stream_state := {
		"accumulated": "",
		"active_field": "",
		"printed_len": 0,
		"done_fields": {},
		"array_item_counts": {},
		"error": "",
	}

	var stream_process_interval_ms := 75
	var last_stream_process_ms := Time.get_ticks_msec()

	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			await Engine.get_main_loop().process_frame
			continue

		var chunk_text := chunk.get_string_from_utf8()
		if response_code == 200:
			var now := Time.get_ticks_msec()
			if now - last_stream_process_ms >= stream_process_interval_ms:
				line_buffer = _process_sse_chunk(
					line_buffer + chunk_text,
					stream_fields,
					stream_array_item_fields,
					stream_state,
					on_field,
					on_field_done
				)
				if not stream_state["error"].is_empty():
					return {"error": stream_state["error"]}
				
				last_stream_process_ms = now

	if response_code != 200:
		return {"error": "HTTP %d" % [response_code]}

	if not line_buffer.is_empty():
		_process_sse_chunk(
			line_buffer + "\n",
			stream_fields,
			stream_array_item_fields, 
			stream_state, 
			on_field, 
			on_field_done
		)

	var output_text: String = stream_state["accumulated"]
	if output_text.is_empty():
		return {"error": "No streamed output text in response"}
	print("DEBUG: Raw streamed structured output text before JSON parse:\n%s" % output_text)

	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var result_json := JSON.new()
	var p_err := result_json.parse(output_text)
	if p_err != OK:
		return {"error": "Failed to parse streamed output JSON"}
	print("DEBUG: Streaming response JSON parsed after %.2fs" % elapsed)

	return {"result": result_json.data, "elapsed": "%.1f" % elapsed}


func call_text(
	prompt: Variant,
	input_text: String,
	instructions: String = "",
	model_override: String = "",
	effort_override: String = ""
) -> Dictionary:
	var http: HTTPRequest = await _spawn_http_request()
	if http == null:
		return {"error": "HTTP request setup failed: request node was not added to the scene tree"}

	var headers = [
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
	]

	var body = {
		"model": model_override if not model_override.is_empty() else DEFAULT_MODEL,
		"reasoning": {"effort": effort_override if not effort_override.is_empty() else DEFAULT_REASONING},
		"input": _build_input_messages(input_text, instructions),
		"text": {"verbosity": DEFAULT_VERBOSITY},
	}
	if _has_prompt(prompt):
		body["prompt"] = prompt

	var request_body = JSON.stringify(body, "", false)
	var err = http.request("https://api.openai.com/v1/responses", headers, HTTPClient.METHOD_POST, request_body)
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
		var err_body = response_body.get_string_from_utf8()
		return {"error": "HTTP %d: %s" % [response_code, err_body.substr(0, 300)]}

	var json = JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		return {"error": "JSON parse error"}

	var data: Dictionary = json.data if json.data is Dictionary else {}
	if data.has("error") and data["error"] != null:
		var err_val = data["error"]
		var err_msg = err_val.get("message", str(err_val)) if err_val is Dictionary else str(err_val)
		return {"error": err_msg}

	var output_text = _extract_output_text(data)
	if output_text.is_empty():
		return {"error": "No output text in response"}

	return {"text": output_text}

# streaming JSON is hard :( Thanks GPT
func _process_sse_chunk(
	text: String,
	stream_fields: Array,
	stream_array_item_fields: Array,
	stream_state: Dictionary,
	on_field: Callable,
	on_field_done: Callable
) -> String:
	var lines := text.split("\n")
	var remainder: String = lines[lines.size() - 1]
	lines.remove_at(lines.size() - 1)

	for line in lines:
		if not line.begins_with("data: "):
			continue

		var payload := line.substr(6).strip_edges()
		if payload == "[DONE]" or payload.is_empty():
			continue

		var event_json := JSON.new()
		if event_json.parse(payload) != OK or not (event_json.data is Dictionary):
			continue

		var event: Dictionary = event_json.data
		if event.has("error") and event["error"] != null:
			var err_val = event["error"]
			stream_state["error"] = err_val.get("message", str(err_val)) if err_val is Dictionary else str(err_val)
			return remainder

		if event.get("type", "") != "response.output_text.delta":
			continue

		var delta: String = event.get("delta", "")
		if delta.is_empty():
			continue

		_process_output_delta(delta, stream_fields, stream_array_item_fields, stream_state, on_field, on_field_done)

	return remainder


func _process_output_delta(delta: String, stream_fields: Array, stream_array_item_fields: Array, stream_state: Dictionary, on_field: Callable, on_field_done: Callable) -> void:
	stream_state["accumulated"] = stream_state["accumulated"] + delta
	var accumulated: String = stream_state["accumulated"]
	var active_field: String = stream_state["active_field"]
	var done_fields: Dictionary = stream_state["done_fields"]

	if active_field.is_empty():
		for field_name in stream_fields:
			if done_fields.has(field_name):
				continue
			var field_marker := "\"%s\":" % field_name
			if accumulated.contains(field_marker):
				active_field = field_name
				stream_state["active_field"] = active_field
				stream_state["printed_len"] = 0
				break

	if active_field.is_empty():
		return

	var marker := "\"%s\":" % active_field
	var marker_pos := accumulated.find(marker)
	if marker_pos == -1:
		return

	var after := accumulated.substr(marker_pos + marker.length()).strip_edges(true, false)
	if after.is_empty():
		return

	if after.begins_with("\""):
		_process_streaming_string_field(after, stream_state, stream_fields, stream_array_item_fields, on_field, on_field_done)
	elif after.begins_with("["):
		if stream_array_item_fields.has(active_field):
			_process_streaming_array_items_field(after, stream_state, stream_fields, stream_array_item_fields, on_field, on_field_done)
		else:
			_process_streaming_container_field(after, stream_state, stream_fields, stream_array_item_fields, on_field, on_field_done, "[", "]")
	elif after.begins_with("{"):
		_process_streaming_container_field(after, stream_state, stream_fields, stream_array_item_fields, on_field, on_field_done, "{", "}")
	else:
		var end := _find_non_string_value_end(after)
		if end != -1:
			var value := after.substr(0, end)
			_emit_stream_field(stream_state["active_field"], value, on_field)
			_finish_stream_field(stream_state, stream_fields, on_field_done)
			_process_output_delta("", stream_fields, stream_array_item_fields, stream_state, on_field, on_field_done)


func _process_streaming_string_field(after: String, stream_state: Dictionary, stream_fields: Array, stream_array_item_fields: Array, on_field: Callable, on_field_done: Callable) -> void:
	var inner := after.substr(1)
	var close := _find_unescaped_quote(inner)
	if close == -1:
		var safe := _safe_unescape_json_prefix(inner)
		var printed_len: int = stream_state["printed_len"]
		if safe.length() > printed_len:
			_emit_stream_field(stream_state["active_field"], safe.substr(printed_len), on_field)
			stream_state["printed_len"] = safe.length()
		return

	var full := _unescape_json_string(inner.substr(0, close))
	var already_printed: int = stream_state["printed_len"]
	if full.length() > already_printed:
		_emit_stream_field(stream_state["active_field"], full.substr(already_printed), on_field)
		stream_state["printed_len"] = full.length()
	_finish_stream_field(stream_state, stream_fields, on_field_done)
	_process_output_delta("", stream_fields, stream_array_item_fields, stream_state, on_field, on_field_done)


func _process_streaming_container_field(after: String, stream_state: Dictionary, stream_fields: Array, stream_array_item_fields: Array, on_field: Callable, on_field_done: Callable, opener: String, closer: String) -> void:
	var end := _find_json_container_end(after, opener, closer)
	if end == -1:
		return

	var value := after.substr(0, end + 1)
	_emit_stream_field(stream_state["active_field"], value, on_field)
	_finish_stream_field(stream_state, stream_fields, on_field_done)
	_process_output_delta("", stream_fields, stream_array_item_fields, stream_state, on_field, on_field_done)


func _process_streaming_array_items_field(after: String, stream_state: Dictionary, stream_fields: Array, stream_array_item_fields: Array, on_field: Callable, on_field_done: Callable) -> void:
	var active_field := str(stream_state.get("active_field", ""))
	if active_field.is_empty():
		return
	var extraction := _extract_complete_json_array_items(after)
	var items_variant: Variant = extraction.get("items", [])
	var items: Array = items_variant if items_variant is Array else []
	var array_item_counts: Dictionary = stream_state.get("array_item_counts", {})
	var already_emitted := int(array_item_counts.get(active_field, 0))
	for idx in range(already_emitted, items.size()):
		var item_text := str(items[idx]).strip_edges()
		if item_text.is_empty():
			continue
		_emit_stream_field("%s_item" % active_field, item_text, on_field)
	array_item_counts[active_field] = items.size()
	stream_state["array_item_counts"] = array_item_counts

	var end := _find_json_container_end(after, "[", "]")
	if end == -1:
		return

	var value := after.substr(0, end + 1)
	_emit_stream_field(active_field, value, on_field)
	_finish_stream_field(stream_state, stream_fields, on_field_done)
	_process_output_delta("", stream_fields, stream_array_item_fields, stream_state, on_field, on_field_done)


func _finish_stream_field(stream_state: Dictionary, stream_fields: Array, on_field_done: Callable) -> void:
	var finished_field: String = stream_state["active_field"]
	if finished_field.is_empty():
		return

	var done_fields: Dictionary = stream_state["done_fields"]
	done_fields[finished_field] = true
	stream_state["active_field"] = ""
	stream_state["printed_len"] = 0
	emit_signal("field_done", finished_field)
	if on_field_done.is_valid():
		on_field_done.call(finished_field)

	var accumulated: String = stream_state["accumulated"]
	for field_name in stream_fields:
		if done_fields.has(field_name):
			continue
		var marker := "\"%s\":" % field_name
		var marker_pos := accumulated.find(marker)
		if marker_pos == -1:
			continue
		var after := accumulated.substr(marker_pos + marker.length()).strip_edges(true, false)
		if not after.is_empty():
			stream_state["active_field"] = field_name
			stream_state["printed_len"] = 0
			return


func _emit_stream_field(field_name: String, text: String, on_field: Callable) -> void:
	if text.is_empty():
		return
	emit_signal("field_streamed", field_name, text)
	if on_field.is_valid():
		on_field.call(field_name, text)


func _find_unescaped_quote(text: String) -> int:
	var i := 0
	while i < text.length():
		var ch := text.substr(i, 1)
		if ch == "\\":
			i += 2
			continue
		if ch == "\"":
			return i
		i += 1
	return -1


func _unescape_json_string(text: String) -> String:
	var json := JSON.new()
	if json.parse("\"%s\"" % text) == OK and json.data is String:
		return json.data
	return text.replace("\\n", "\n").replace("\\t", "\t").replace("\\\"", "\"").replace("\\\\", "\\")


func _safe_unescape_json_prefix(text: String) -> String:
	var safe_text := text
	if safe_text.ends_with("\\"):
		safe_text = safe_text.substr(0, safe_text.length() - 1)

	var unicode_escape_pos := safe_text.rfind("\\u")
	if unicode_escape_pos != -1 and safe_text.length() - unicode_escape_pos < 6:
		safe_text = safe_text.substr(0, unicode_escape_pos)

	return _unescape_json_string(safe_text)


func _find_non_string_value_end(text: String) -> int:
	for i in text.length():
		var ch := text.substr(i, 1)
		if ",}]\n".contains(ch):
			return i
	return -1


func _find_json_container_end(text: String, opener: String, closer: String) -> int:
	var depth := 0
	var in_string := false
	var escaped := false
	for i in text.length():
		var ch := text.substr(i, 1)
		if in_string:
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == "\"":
				in_string = false
			continue

		if ch == "\"":
			in_string = true
		elif ch == opener:
			depth += 1
		elif ch == closer:
			depth -= 1
			if depth == 0:
				return i
	return -1


func _extract_complete_json_array_items(text: String) -> Dictionary:
	var items: Array[String] = []
	if not text.begins_with("["):
		return {"items": items, "closed": false}

	var in_string := false
	var escaped := false
	var depth := 0
	var current_start := -1
	var closed := false

	for i in range(1, text.length()):
		var ch := text.substr(i, 1)
		if current_start == -1:
			if ch == "]":
				closed = true
				break
			if " \t\r\n,".contains(ch):
				continue
			current_start = i
			if ch == "\"":
				in_string = true
				escaped = false
				depth = 0
			elif ch == "{" or ch == "[":
				depth = 1
			else:
				depth = 0
			continue

		if in_string:
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == "\"":
				in_string = false
			continue

		if ch == "\"":
			in_string = true
			escaped = false
		elif ch == "{" or ch == "[":
			depth += 1
		elif ch == "}" or ch == "]":
			if depth > 0:
				depth -= 1

		if depth == 0 and (ch == "," or ch == "]"):
			var item_text := text.substr(current_start, i - current_start).strip_edges()
			if not item_text.is_empty():
				items.append(item_text)
			current_start = -1
			if ch == "]":
				closed = true
				break

	return {"items": items, "closed": closed}
