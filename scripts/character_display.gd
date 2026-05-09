extends PanelContainer

@onready var image: TextureRect = $Image
@onready var placeholder_label: RichTextLabel = $PlaceholderLabel


func create_placeholder_text(noun: String, adjs: Array[String]):
	return noun[0].to_upper()
	var placeholder_text: String = ""
	
	placeholder_text += [
		"Finding", 
		"Summoning",
		"Searching for",
		"Hailing",
		"Seeking",
		"Awakening",
		"Calling on",
		"Befriending"
		].pick_random()
	
	var vowels = ["a", "e", "i", "o", "u"]
	if adjs[0].left(1).to_lower() in vowels:
		placeholder_text += " an "
	else:
		placeholder_text += " a "
		
	for i in range(len(adjs)):
		placeholder_text += adjs[i]
		if i != len(adjs) - 1:
			placeholder_text += ","
		placeholder_text += " "
			
	placeholder_text += noun + "..."
	
	return placeholder_text


func display_character(noun: String, adjs: Array[String]):
	image.hide()
	placeholder_label.show()
	placeholder_label.text = create_placeholder_text(noun, adjs)

	var new_texture = await PromptAPI.make_character_image(noun, adjs)

	load_texture(new_texture)

func load_texture(tex: Texture2D):
	image.texture = tex
	image.show()
	placeholder_label.hide()
