extends Node2D

const OpenAIClientScript = preload("res://scripts/openai_client.gd")
const DataUtilsScript = preload("res://scripts/data_utils.gd")
var openai: RefCounted

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var key := DataUtilsScript.load_api_key()
	print(key)
	openai = OpenAIClientScript.new(key)
	var resp = await openai.call_text(null, "test", "Make the following word upper case. Only write the uppercase word.")
	print(resp)
	print(resp["text"])
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
