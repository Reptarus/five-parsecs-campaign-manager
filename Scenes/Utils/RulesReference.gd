# RulesReference.gd
extends Control

var rules_data = {}

func _ready():
	load_rules_data()
	setup_buttons()
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))

func load_rules_data():
	var dir = DirAccess.open("res://data/RulesReference/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open("res://data/RulesReference/" + file_name, FileAccess.READ)
				if file:
					var json = JSON.new()
					var parse_result = json.parse(file.get_as_text())
					if parse_result == OK:
						var data = json.get_data()
						var category = file_name.get_basename()
						rules_data[category] = data
					file.close()
			file_name = dir.get_next()

func setup_buttons():
	var library_rows = $VBoxContainer/LibraryRows
	var categories = rules_data.keys()
	categories.sort()  # Sort categories alphabetically
	
	var row_index = 0
	var button_index = 0
	for category in categories:
		if button_index % 5 == 0:  # 5 buttons per row
			row_index += 1
		
		var row_name = "Row" + str(row_index)
		var row = library_rows.get_node_or_null(row_name)
		if not row:
			row = HBoxContainer.new()
			row.name = row_name
			library_rows.add_child(row)
		
		var button = Button.new()
		button.text = category
		button.name = category + "Button"
		button.connect("pressed", Callable(self, "_on_category_button_pressed").bind(category))
		row.add_child(button)
		
		button_index += 1
	
	# Adjust button sizes and spacing
	for row in library_rows.get_children():
		row.add_theme_constant_override("separation", 10)
		for button in row.get_children():
			button.custom_minimum_size = Vector2(200, 100)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _on_category_button_pressed(category: String):
	if category in rules_data:
		var rules_display = preload("res://Scenes/Utils/RulesDisplay.tscn").instantiate()
		rules_display.display_category(category, rules_data[category][category])
		get_tree().root.add_child(rules_display)
		hide()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
