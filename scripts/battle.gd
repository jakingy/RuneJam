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
	print(await PromptAPI.make_character_image_gen_prompt("wolf", ["fast", "soggy"]))
	var texture := await PromptAPI.make_character_image("wolf", ["fast", "soggy"])
	texture.get_image().save_png("user://wolf_test.png")
	print("image done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
