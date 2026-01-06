extends Control

const Character = preload("res://src/core/character/Character.gd")
const CrewRelationshipManager = preload("res://src/core/campaign/crew/CrewRelationshipManager.gd")
# GlobalEnums available as autoload singleton

# Design System Constants
const TOUCH_TARGET_MIN := 48
const SPACING_SM := 8
const COLOR_INPUT := Color("#1f2937")
const COLOR_BORDER := Color("#374151")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")

@onready var crew_characteristic_label := $VBoxContainer/CrewCharacteristicLabel
@onready var meeting_story_label := $VBoxContainer/MeetingStoryLabel
@onready var relationships_container := $VBoxContainer/RelationshipsContainer
@onready var add_relationship_button := $VBoxContainer/AddRelationshipButton
@onready var add_relationship_panel := $VBoxContainer/AddRelationshipPanel
@onready var character1_dropdown := $VBoxContainer/AddRelationshipPanel/VBoxContainer/Character1Dropdown
@onready var character2_dropdown := $VBoxContainer/AddRelationshipPanel/VBoxContainer/Character2Dropdown
@onready var relationship_type_dropdown := $VBoxContainer/AddRelationshipPanel/VBoxContainer/RelationshipTypeDropdown
@onready var confirm_button := $VBoxContainer/AddRelationshipPanel/VBoxContainer/ConfirmButton

# Use Node type as a fallback if CrewRelationshipManager doesn't have a class_name defined
var relationship_manager: Node
var crew_members: Array = []  # Can hold Character objects or Dictionaries

func _ready() -> void:
	relationship_manager = CrewRelationshipManager.new()
	add_child(relationship_manager)

	# Connect signals
	relationship_manager.relationship_added.connect(_on_relationship_added)
	relationship_manager.relationship_removed.connect(_on_relationship_removed)
	add_relationship_button.pressed.connect(_on_add_relationship_pressed)

	# Apply design system styling
	call_deferred("_apply_design_system_styling")

	# Hide add relationship panel initially
	add_relationship_panel.hide()

func _apply_design_system_styling() -> void:
	"""Apply design system styling to scene elements"""
	# Style OptionButtons
	if character1_dropdown:
		_style_option_button(character1_dropdown)
	if character2_dropdown:
		_style_option_button(character2_dropdown)
	if relationship_type_dropdown:
		_style_option_button(relationship_type_dropdown)

	# Style Buttons
	if add_relationship_button:
		_style_button(add_relationship_button)
	if confirm_button:
		_style_button(confirm_button)

	print("CrewRelationshipsPanel: Design system styling applied")

func _style_option_button(btn: OptionButton) -> void:
	"""Apply design system styling to OptionButton"""
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(COLOR_INPUT.r + 0.05, COLOR_INPUT.g + 0.05, COLOR_INPUT.b + 0.05)
	hover_style.border_color = COLOR_ACCENT
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("hover", hover_style)

func _style_button(btn: Button) -> void:
	"""Apply design system styling to Button"""
	btn.custom_minimum_size.y = TOUCH_TARGET_MIN

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(COLOR_INPUT.r + 0.05, COLOR_INPUT.g + 0.05, COLOR_INPUT.b + 0.05)
	hover_style.border_color = COLOR_ACCENT
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.3)
	pressed_style.border_color = COLOR_ACCENT
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(6)
	pressed_style.set_content_margin_all(SPACING_SM)
	btn.add_theme_stylebox_override("pressed", pressed_style)
func initialize(members: Array) -> void:
	crew_members = members
	relationship_manager.generate_initial_relationships(members)
	_update_display()
	_populate_dropdowns()
## Get character name from Character object or Dictionary
func _get_char_name(character) -> String:
	if character == null:
		return "Unknown"
	if character is Character:
		return character.character_name
	if character is Dictionary:
		if character.has("character_name"):
			return character["character_name"]
		if character.has("name"):
			return character["name"]
	return str(character)

func _update_display() -> void:
	# Update crew characteristic and meeting story
	crew_characteristic_label.text = "Crew Characteristic: " + relationship_manager.crew_characteristic
	meeting_story_label.text = "Meeting Story: " + relationship_manager.crew_meeting_story

	# Clear existing relationship displays
	for child in relationships_container.get_children():
		child.queue_free()

	# Track displayed relationships to avoid duplicates
	var displayed_pairs: Dictionary = {}

	# Add relationship displays
	for char1 in crew_members:
		var char1_name = _get_char_name(char1)
		var relationships_list = relationship_manager.get_all_relationships(char1)
		for rel in relationships_list:
			var char2_name = rel.get("character_name", "Unknown")
			var relationship = rel.get("relationship", "Neutral")

			# Create sorted key to avoid duplicate displays
			var pair_key = [char1_name, char2_name]
			pair_key.sort()
			var key_str = pair_key[0] + ":" + pair_key[1]

			if displayed_pairs.has(key_str):
				continue
			displayed_pairs[key_str] = true

			var rel_display := HBoxContainer.new()
			rel_display.add_theme_constant_override("separation", SPACING_SM)

			# Character names
			var names_label := Label.new()
			names_label.text = "%s ←→ %s" % [char1_name, char2_name]
			names_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
			rel_display.add_child(names_label)

			# Relationship type
			var type_label := Label.new()
			type_label.text = ": %s" % relationship
			type_label.add_theme_color_override("font_color", COLOR_ACCENT)
			rel_display.add_child(type_label)

			# Remove button
			var remove_button := Button.new()
			remove_button.text = "Remove"
			remove_button.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
			_style_button(remove_button)
			var c1 = char1
			remove_button.pressed.connect(func():
				relationship_manager.remove_relationship(c1, char2_name)
			)
			rel_display.add_child(remove_button)

			relationships_container.add_child(rel_display)
func _populate_dropdowns() -> void:
	# Clear existing items
	character1_dropdown.clear()
	character2_dropdown.clear()
	relationship_type_dropdown.clear()

	# Add characters to dropdowns
	for character in crew_members:
		var char_name = _get_char_name(character)
		character1_dropdown.add_item(char_name)
		character2_dropdown.add_item(char_name)

	# Add relationship types
	for rel_type in relationship_manager.RELATIONSHIP_TYPES.values():
		relationship_type_dropdown.add_item(rel_type)
func _on_add_relationship_pressed() -> void:
	$VBoxContainer/AddRelationshipPanel.visible = !$VBoxContainer/AddRelationshipPanel.visible

func _on_relationship_added(_char1, _char2, _relationship_type: String) -> void:
	_update_display()

func _on_relationship_removed(_char1, _char2) -> void:
	_update_display()
func _on_confirm_relationship_pressed() -> void:
	var char1 = crew_members[character1_dropdown.selected]
	var char2 = crew_members[character2_dropdown.selected]
	var rel_type = relationship_manager.RELATIONSHIP_TYPES.values()[relationship_type_dropdown.selected]

	if char1 != char2:
		relationship_manager.add_relationship(char1, char2, rel_type)
		$VBoxContainer/AddRelationshipPanel.hide()
func serialize() -> Dictionary:
	return relationship_manager.serialize()

func deserialize(data: Dictionary) -> void:
	relationship_manager.deserialize(data)
	_update_display()
