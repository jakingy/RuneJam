extends Node2D

var openai: RefCounted

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var resp = await OpenaiClient.call_text(
		null,
		"test",
		"Make the following word upper case. Only write the uppercase word."
	)
	print(resp)
	print(resp["text"])

	print(await PromptAPI.fuse_adjectives(["hot", "watery"]))
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
