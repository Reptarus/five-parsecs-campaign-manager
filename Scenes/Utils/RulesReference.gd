# RulesReference.gd
extends Control

var rules_data = {}

func _ready():
	load_rules_data()
	setup_buttons()
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))

func load_rules_data():
	var file = FileAccess.open("res://data/rules.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			rules_data = json.get_data()
		file.close()

func setup_buttons():
	var library_rows = $MarginContainer/PanelContainer/VBoxContainer/LibraryRows
	for row in library_rows.get_children():
		for button_container in row.get_children():
			var button = button_container.get_node("Button")
			button.connect("pressed", Callable(self, "_on_category_button_pressed").bind(button.text))
			button.custom_minimum_size = Vector2(200, 100)
			button.add_theme_constant_override("icon_max_width", 50)
		row.add_theme_constant_override("separation", 10)

func _on_category_button_pressed(category: String):
	if category in rules_data:
		display_rules(category)
	else:
		print("Category not found in rules data: ", category)

func display_rules(category: String):
	# Assuming you have a TextEdit or RichTextLabel node named $RulesContent
	$RulesContent.text = rules_data[category]

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
