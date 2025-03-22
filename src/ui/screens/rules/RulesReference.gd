# RulesReference.gd
extends "res://src/ui/components/base/CampaignResponsiveLayout.gd"

const PORTRAIT_LIST_HEIGHT_RATIO := 0.4 # List takes 40% in portrait mode

var rules_data = {}
var bookmarks = []
var search_results = []
var current_topic = ""

@onready var topic_list = $MarginContainer/VBoxContainer/HSplitContainer/TopicList/VBoxContainer
@onready var content_display = $MarginContainer/VBoxContainer/HSplitContainer/ContentDisplay/VBoxContainer
@onready var search_bar = $MarginContainer/VBoxContainer/TopBar/SearchBar

func _ready():
	super._ready()
	_setup_rules_reference()
	_load_bookmarks()

func _setup_rules_reference() -> void:
	_populate_topics()
	_setup_search()
	_setup_bookmarks()

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	# Stack panels vertically
	$MarginContainer/VBoxContainer/HSplitContainer.set("vertical", true)
	
	# Adjust panel sizes for portrait mode
	var viewport_height = get_viewport_rect().size.y
	topic_list.custom_minimum_size.y = viewport_height * PORTRAIT_LIST_HEIGHT_RATIO
	content_display.custom_minimum_size.y = viewport_height * (1 - PORTRAIT_LIST_HEIGHT_RATIO)
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)
	
	# Adjust margins for mobile
	$MarginContainer.add_theme_constant_override("margin_left", 10)
	$MarginContainer.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	# Side by side layout
	$MarginContainer/VBoxContainer/HSplitContainer.set("vertical", false)
	
	# Reset panel sizes
	topic_list.custom_minimum_size = Vector2(300, 0)
	content_display.custom_minimum_size = Vector2(600, 0)
	
	# Reset control sizes
	_adjust_touch_sizes(false)
	
	# Reset margins
	$MarginContainer.add_theme_constant_override("margin_left", 20)
	$MarginContainer.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons and interactive elements
	for control in get_tree().get_nodes_in_group("touch_controls"):
		control.custom_minimum_size.y = button_height
	
	# Adjust search bar
	search_bar.custom_minimum_size.y = button_height

func _populate_topics() -> void:
	# Add your topic population logic here
	pass

func _setup_search() -> void:
	search_bar.text_changed.connect(_on_search_text_changed)
	search_bar.add_to_group("touch_controls")

func _setup_bookmarks() -> void:
	var bookmarks_button = $MarginContainer/VBoxContainer/TopBar/BookmarksButton
	bookmarks_button.add_to_group("touch_controls")
	bookmarks_button.pressed.connect(_on_bookmarks_pressed)

func _load_bookmarks() -> void:
	# Load bookmarks from save file
	pass

func _save_bookmarks() -> void:
	# Save bookmarks to file
	pass

func _on_search_text_changed(new_text: String) -> void:
	# Filter topics based on search text
	pass

func _on_bookmarks_pressed() -> void:
	# Show bookmarked topics
	pass

func _on_topic_selected(topic: String) -> void:
	current_topic = topic
	_show_topic_content(topic)

func _show_topic_content(topic: String) -> void:
	# Display topic content
	pass
