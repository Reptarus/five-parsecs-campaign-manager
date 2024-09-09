# RulesDisplay.gd
extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var content_text = $VBoxContainer/ContentText
@onready var image_rect = $VBoxContainer/ImageRect

func _ready():
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))

func display_category(category: String, data: Dictionary):
	title_label.text = category
	
	var content = ""
	if "text" in data:
		content += data["text"] + "\n\n"
	
	if "content" in data:
		for item in data["content"]:
			content += "## " + item["title"] + "\n"
			content += item["description"] + "\n\n"
			
			if "table" in item:
				content += "| Roll | Result |\n|------|--------|\n"
				for row in item["table"]:
					content += "| " + row["roll"] + " | " + row["enemy"] + " |\n"
				content += "\n"
			
			if "steps" in item:
				for step in item["steps"]:
					content += "- " + step + "\n"
				content += "\n"
	
	content_text.text = content
	
	if "image" in data:
		var image = load(data["image"])
		if image:
			image_rect.texture = image
			image_rect.visible = true
	else:
		image_rect.visible = false

func _on_back_pressed():
	queue_free()
	var rules_reference = load("res://Scenes/Utils/RulesReference.tscn").instantiate()
	get_tree().root.add_child(rules_reference)
