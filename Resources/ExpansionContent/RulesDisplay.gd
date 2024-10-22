# RulesDisplay.gd
extends Control

# signal back_pressed

@onready var title_label = $VBoxContainer/TitleLabel
@onready var content_text = $VBoxContainer/ContentText
@onready var image_rect = $VBoxContainer/ImageRect
@onready var bookmark_button = $VBoxContainer/BookmarkButton
@onready var related_rules = $VBoxContainer/RelatedRules

var current_category = ""

func _ready():
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))
	bookmark_button.connect("pressed", Callable(self, "_on_bookmark_pressed"))

func display_category(category: String, data: Dictionary):
	current_category = category
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
	
	update_bookmark_button()
	display_related_rules(data)

func update_bookmark_button():
	bookmark_button.text = "Bookmark" if not is_bookmarked() else "Remove Bookmark"

func is_bookmarked() -> bool:
	var rules_reference = get_node("/root/RulesReference")
	return current_category in rules_reference.bookmarks

func _on_bookmark_pressed():
	var rules_reference = get_node("/root/RulesReference")
	if is_bookmarked():
		rules_reference.bookmarks.erase(current_category)
	else:
		rules_reference.bookmarks.append(current_category)
	update_bookmark_button()

func display_related_rules(data: Dictionary):
	related_rules.clear()
	if "related_rules" in data:
		for rule in data["related_rules"]:
			var button = Button.new()
			button.text = rule
			button.connect("pressed", Callable(self, "_on_related_rule_pressed").bind(rule))
			related_rules.add_child(button)

func _on_related_rule_pressed(rule: String):
	var rules_reference = get_node("/root/RulesReference")
	rules_reference.show_rules_display(rule)

func _on_back_pressed():
	queue_free()
