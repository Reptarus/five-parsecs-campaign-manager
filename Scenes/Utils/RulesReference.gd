# RulesReference.gd
extends Control

var rules_data = {}
var bookmarks = []
var search_results = []
var history = []
var current_page = ""

func _ready():
	load_rules_data()
	setup_buttons()
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))
	$SearchBar.connect("text_changed", Callable(self, "_on_search_text_changed"))
	$BookmarksButton.connect("pressed", Callable(self, "_on_bookmarks_button_pressed"))

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
		show_rules_display(category)

func show_rules_display(category: String):
	var rules_display = preload("res://Scenes/Utils/RulesDisplay.tscn").instantiate()
	rules_display.display_category(category, rules_data[category][category])
	rules_display.connect("back_pressed", Callable(self, "_on_rules_display_back_pressed"))
	get_tree().root.add_child(rules_display)
	history.append(current_page)
	current_page = category
	if history.size() > 2:
		history.pop_front()
	hide()

func _on_rules_display_back_pressed():
	if history.size() > 0:
		var previous_page = history.pop_back()
		if previous_page in rules_data:
			show_rules_display(previous_page)
		else:
			show()
	else:
		show()

func _on_search_text_changed(new_text: String):
	search_results.clear()
	if new_text.length() >= 3:
		for category in rules_data.keys():
			if new_text.to_lower() in category.to_lower():
				search_results.append(category)
			for content in rules_data[category][category]["content"]:
				if new_text.to_lower() in content["title"].to_lower() or new_text.to_lower() in content["description"].to_lower():
					search_results.append(category + ": " + content["title"])
	update_search_results()

func update_search_results():
	# Clear existing buttons
	for child in $VBoxContainer/LibraryRows.get_children():
		child.queue_free()
	
	# Create new buttons for search results
	var row = HBoxContainer.new()
	$VBoxContainer/LibraryRows.add_child(row)
	for result in search_results:
		var button = Button.new()
		button.text = result
		button.connect("pressed", Callable(self, "_on_search_result_pressed").bind(result))
		row.add_child(button)

func _on_search_result_pressed(result: String):
	var category = result.split(": ")[0]
	show_rules_display(category)

func _on_bookmarks_button_pressed():
	# Implement bookmarks functionality
	pass

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
