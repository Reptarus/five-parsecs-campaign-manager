# RulesReference.gd
extends Control

var rules_data = {}
var bookmarks = []
var search_results = []
var current_topic = ""

@onready var topic_list = $MarginContainer/VBoxContainer/HSplitContainer/TopicList/VBoxContainer
@onready var content_display = $MarginContainer/VBoxContainer/HSplitContainer/ContentDisplay/VBoxContainer
@onready var search_bar = $MarginContainer/VBoxContainer/TopBar/SearchBar

func _ready():
	load_rules_data()
	setup_topic_buttons()
	setup_signals()

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

func setup_topic_buttons():
	var categories = rules_data.keys()
	categories.sort()
	for category in categories:
		var button = Button.new()
		button.text = category
		button.name = category + "Button"
		button.connect("pressed", Callable(self, "_on_topic_button_pressed").bind(category))
		button.set_meta("default_font_size", button.get_theme_font_size("font_size"))
		topic_list.add_child(button)

func setup_signals():
	$MarginContainer/VBoxContainer/TopBar/BackButton.connect("pressed", Callable(self, "_on_back_pressed"))
	search_bar.connect("text_changed", Callable(self, "_on_search_text_changed"))
	$MarginContainer/VBoxContainer/TopBar/BookmarksButton.connect("pressed", Callable(self, "_on_bookmarks_button_pressed"))

func _on_topic_button_pressed(category: String):
	if category in rules_data:
		show_topic_content(category)

func show_topic_content(category: String):
	# Remove all children from content_display
	for child in content_display.get_children():
		child.queue_free()
	
	current_topic = category
	
	var title = Label.new()
	title.text = category
	title.add_theme_font_size_override("font_size", 24)
	content_display.add_child(title)
	
	if category in rules_data:
		var data = rules_data[category]
		var content_text = RichTextLabel.new()
		content_text.bbcode_enabled = true
		content_text.fit_content = true
		content_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_display.add_child(content_text)
		
		_format_content(data, content_text)
	else:
		var error_label = Label.new()
		error_label.text = "No data found for this category."
		content_display.add_child(error_label)

func _format_content(data: Dictionary, content_text: RichTextLabel):
	for key in data.keys():
		var section = data[key]
		content_text.append_text("[b]" + key + "[/b]\n\n")
		if typeof(section) == TYPE_DICTIONARY:
			_format_section(section, content_text)
		elif typeof(section) == TYPE_ARRAY:
			_format_array_section(section, content_text)
		content_text.append_text("\n")

func _format_section(section: Dictionary, content_text: RichTextLabel):
	for key in section.keys():
		var item = section[key]
		if typeof(item) == TYPE_DICTIONARY:
			content_text.append_text("[u]" + item.get("name", key) + "[/u]\n")
			content_text.append_text(item.get("description", "") + "\n\n")
			if "table" in item:
				_format_table(item["table"], content_text)
		elif typeof(item) == TYPE_ARRAY:
			_format_array_section(item, content_text)

func _format_array_section(items: Array, content_text: RichTextLabel):
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			content_text.append_text("[u]" + item.get("name", "") + "[/u]\n")
			content_text.append_text(item.get("description", "") + "\n\n")
			if "table" in item:
				_format_table(item["table"], content_text)

func _format_table(table: Array, content_text: RichTextLabel):
	content_text.append_text("[table=2]\n")
	content_text.append_text("[cell][b]Roll[/b][/cell][cell][b]Result[/b][/cell]\n")
	for row in table:
		content_text.append_text("[cell]" + row["roll"] + "[/cell][cell]" + row["enemy"] + "[/cell]\n")
	content_text.append_text("[/table]\n\n")

func _on_search_text_changed(new_text: String):
	search_results.clear()
	if new_text.length() >= 3:
		for category in rules_data.keys():
			if new_text.to_lower() in category.to_lower():
				search_results.append(category)
			_search_in_data(rules_data[category], new_text, category)
	update_search_results()

func _search_in_data(data, search_text: String, category: String):
	if typeof(data) == TYPE_DICTIONARY:
		for key in data.keys():
			if typeof(data[key]) == TYPE_DICTIONARY:
				if "name" in data[key] and search_text.to_lower() in data[key]["name"].to_lower():
					search_results.append(category + ": " + data[key]["name"])
				if "description" in data[key] and search_text.to_lower() in data[key]["description"].to_lower():
					search_results.append(category + ": " + data[key].get("name", key))
			elif typeof(data[key]) == TYPE_ARRAY:
				_search_in_data(data[key], search_text, category)
	elif typeof(data) == TYPE_ARRAY:
		for item in data:
			if typeof(item) == TYPE_DICTIONARY:
				if "name" in item and search_text.to_lower() in item["name"].to_lower():
					search_results.append(category + ": " + item["name"])
				if "description" in item and search_text.to_lower() in item["description"].to_lower():
					search_results.append(category + ": " + item.get("name", ""))

func update_search_results():
	for child in topic_list.get_children():
		child.visible = false
	
	for result in search_results:
		var category = result.split(": ")[0]
		var button = topic_list.get_node(category + "Button")
		if button:
			button.visible = true

func _on_bookmarks_button_pressed():
	# Implement bookmarks functionality
	pass

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

# Add these new functions for button hover and selection effects
func _process(delta):
	for button in topic_list.get_children():
		if button is Button:
			if button.is_hovered():
				button.add_theme_font_size_override("font_size", button.get_meta("default_font_size") * 1.1)
				button.modulate = Color(1.2, 1.2, 1.2)  # Soft glow effect
			elif button.text == current_topic:
				button.add_theme_font_size_override("font_size", button.get_meta("default_font_size") * 1.1)
				button.modulate = Color(1, 0.843, 0)  # Gold color for selected topic
			else:
				button.add_theme_font_size_override("font_size", button.get_meta("default_font_size"))
				button.modulate = Color(1, 1, 1)
