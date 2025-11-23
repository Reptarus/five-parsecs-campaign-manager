extends Tooltip
class_name KeywordTooltip

## KeywordTooltip - Enhanced tooltip for keyword system
## Extends existing Tooltip.gd with keyword-specific features

## Keyword-specific UI elements
@onready var keyword_header = $Background/Header
@onready var bookmark_button = $Background/Header/BookmarkButton
@onready var related_keywords_container = $Background/RelatedKeywords
@onready var see_rules_button = $Background/Actions/SeeRulesButton

## Current keyword data
var current_keyword: Dictionary = {}

func _ready() -> void:
	super._ready()
	_setup_keyword_ui()

func _setup_keyword_ui() -> void:
	"""Setup keyword-specific UI elements"""
	# Bookmark button
	if bookmark_button:
		bookmark_button.pressed.connect(_on_bookmark_pressed)
	
	# See full rules button
	if see_rules_button:
		see_rules_button.pressed.connect(_on_see_rules_pressed)

## ===== PUBLIC API =====

func show_for_keyword(keyword_term: String, target: Control) -> void:
	"""Show tooltip for a specific keyword"""
	current_keyword = KeywordDB.get_keyword(keyword_term)
	
	if current_keyword.is_empty():
		hide_tooltip()
		return
	
	_update_keyword_content()
	show_immediately(_format_keyword_text(), target, Position.AUTO)

func _update_keyword_content() -> void:
	"""Update tooltip content with keyword data"""
	# Update bookmark button state
	if bookmark_button:
		var is_bookmarked = KeywordDB.is_bookmarked(current_keyword.term)
		bookmark_button.text = "★" if is_bookmarked else "☆"
	
	# Update related keywords
	_update_related_keywords()

func _format_keyword_text() -> String:
	"""Format keyword data as BBCode text"""
	var text = "[b]%s[/b]\n\n" % current_keyword.get("term", "").to_upper()
	text += current_keyword.get("definition", "")
	
	if current_keyword.has("extended"):
		text += "\n\n" + current_keyword.extended
	
	# Add examples if available
	if current_keyword.has("examples") and not current_keyword.examples.is_empty():
		text += "\n\n[i]Example: " + current_keyword.examples[0] + "[/i]"
	
	return text

func _update_related_keywords() -> void:
	"""Update related keywords section"""
	if not related_keywords_container:
		return
	
	# Clear existing
	for child in related_keywords_container.get_children():
		child.queue_free()
	
	var related = current_keyword.get("related", [])
	if related.is_empty():
		related_keywords_container.visible = false
		return
	
	related_keywords_container.visible = true
	
	# Create clickable links for related keywords
	for related_term in related:
		var button = Button.new()
		button.text = related_term
		button.flat = true
		button.pressed.connect(func(): show_for_keyword(related_term, target_control))
		related_keywords_container.add_child(button)

## ===== SIGNALS =====

func _on_bookmark_pressed() -> void:
	"""Toggle bookmark status"""
	if current_keyword.is_empty():
		return
	
	KeywordDB.toggle_bookmark(current_keyword.term)
	_update_keyword_content()

func _on_see_rules_pressed() -> void:
	"""Open full rules reference"""
	# TODO: Navigate to RulesReference screen
	if current_keyword.has("rule_page"):
		print("Opening rules: ", current_keyword.rule_page)
	hide_tooltip()

## ===== STATIC HELPERS =====

static func attach_to_rich_text_label(label: RichTextLabel) -> void:
	"""Attach keyword tooltip to a RichTextLabel with parsed keywords"""
	# Create tooltip instance
	var tooltip = KeywordTooltip.new()
	label.get_tree().current_scene.add_child(tooltip)
	
	# Connect meta_clicked signal
	label.meta_clicked.connect(func(meta):
		if meta.begins_with("keyword:"):
			var term = meta.substr(8)  # Remove "keyword:" prefix
			tooltip.show_for_keyword(term, label)
	)
