# RulesDisplay.gd
extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var content_text = $VBoxContainer/ContentText
@onready var image_rect = $VBoxContainer/ImageRect

func _ready():
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))

func display_category(category: String, data: Dictionary):
	title_label.text = category
	content_text.text = data["text"]
	
	if "image" in data:
		var image = load(data["image"])
		if image:
			image_rect.texture = image
			image_rect.visible = true
	else:
		image_rect.visible = false

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/RulesReference.tscn")
