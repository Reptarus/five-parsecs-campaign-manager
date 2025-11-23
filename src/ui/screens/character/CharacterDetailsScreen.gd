# Character Details Screen - View and Edit Individual Character
# Allows editing character properties and equipment
class_name CharacterDetailsScreen
extends Control

# UI Node References - using %NodeName for maintainability
@onready var name_edit: LineEdit = %NameEdit
@onready var class_label: Label = %ClassLabel
@onready var character_info_container: VBoxContainer = %InfoContainer
@onready var stats_grid: GridContainer = %StatsGrid
@onready var equipment_list: ItemList = %EquipmentList
@onready var add_equipment_button: Button = %AddEquipmentButton
@onready var remove_equipment_button: Button = %RemoveEquipmentButton
@onready var notes_edit: TextEdit = %NotesEdit
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton

# State
var current_character = null
var original_data: Dictionary = {}

func _ready() -> void:
	print("CharacterDetailsScreen: Initializing...")

	# Connect button signals
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if add_equipment_button:
		add_equipment_button.pressed.connect(_on_add_equipment_pressed)
	if remove_equipment_button:
		remove_equipment_button.pressed.connect(_on_remove_equipment_pressed)

	# Load character data
	load_character_data()

	print("CharacterDetailsScreen: Ready")

func load_character_data() -> void:
	"""Load character from GameStateManager temp storage"""
	if not GameStateManager:
		push_error("CharacterDetailsScreen: GameStateManager not available")
		return

	# Get character from temp storage (set by CrewManagementScreen or CrewPanel)
	if GameStateManager.has_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		current_character = GameStateManager.get_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER)

	if not current_character:
		push_error("CharacterDetailsScreen: No character selected")
		return

	print("CharacterDetailsScreen: Loading character - ", current_character.name if "name" in current_character else "Unknown")

	# Store original data for cancel
	if current_character.has_method("to_dictionary"):
		original_data = current_character.to_dictionary()
	else:
		original_data = {}

	# Populate UI fields
	populate_ui()

func populate_ui() -> void:
	"""Fill UI elements with character data"""
	if not current_character:
		return

	# Name
	if name_edit and "name" in current_character:
		name_edit.text = current_character.name

	# Class
	if class_label:
		var char_class = current_character.character_class if "character_class" in current_character else "Baseline"
		class_label.text = "[%s]" % char_class

	# Character Info (Background, Motivation, Origin, XP, Story Points)
	if character_info_container:
		clear_character_info_display()

		# Add prominent character creation info (like Crew Management screen)
		var background = current_character.background if "background" in current_character else "Unknown"
		var motivation = current_character.motivation if "motivation" in current_character else "Unknown"
		var char_class = current_character.character_class if "character_class" in current_character else "Working Class"
		var origin = current_character.origin if "origin" in current_character else "HUMAN"

		var creation_summary = Label.new()
		creation_summary.text = "%s | %s / %s / %s" % [origin, background, motivation, char_class]
		creation_summary.add_theme_font_size_override("font_size", 14)
		creation_summary.modulate = Color(0.7, 0.9, 1.0)  # Light blue highlight
		character_info_container.add_child(creation_summary)

		# Add separator
		var separator = HSeparator.new()
		separator.custom_minimum_size = Vector2(0, 15)
		character_info_container.add_child(separator)

		# Add detailed info fields
		var info_fields = [
			["Experience", str(current_character.experience if "experience" in current_character else 0) + " XP"],
			["Story Points", str(current_character.story_points if "story_points" in current_character else 0)],
		]

		for field_data in info_fields:
			var info_row = HBoxContainer.new()
			info_row.set("theme_override_constants/separation", 10)

			var field_name = Label.new()
			field_name.text = field_data[0] + ":"
			field_name.custom_minimum_size = Vector2(120, 0)
			info_row.add_child(field_name)

			var field_value = Label.new()
			field_value.text = str(field_data[1])
			info_row.add_child(field_value)

			character_info_container.add_child(info_row)

	# Stats (read-only display using GridContainer)
	if stats_grid:
		# Update stat values directly in the static GridContainer labels
		stats_grid.get_node("CombatValue").text = str(current_character.combat if "combat" in current_character else 0)
		stats_grid.get_node("ReactionsValue").text = str(current_character.reactions if "reactions" in current_character else 0)
		stats_grid.get_node("ToughnessValue").text = str(current_character.toughness if "toughness" in current_character else 0)
		stats_grid.get_node("SavvyValue").text = str(current_character.savvy if "savvy" in current_character else 0)
		stats_grid.get_node("TechValue").text = str(current_character.tech if "tech" in current_character else 0)
		stats_grid.get_node("SpeedValue").text = str(current_character.speed if "speed" in current_character else 0)
		stats_grid.get_node("LuckValue").text = str(current_character.luck if "luck" in current_character else 0)

	# Equipment
	if equipment_list and "equipment" in current_character:
		equipment_list.clear()
		for item in current_character.equipment:
			equipment_list.add_item(str(item))

	# Notes (if we add a notes field to Character)
	if notes_edit:
		notes_edit.text = ""  # Placeholder for future notes system

func clear_character_info_display() -> void:
	"""Clear all character info labels"""
	if not character_info_container:
		return

	for child in character_info_container.get_children():
		child.queue_free()

func _on_save_pressed() -> void:
	"""Save character changes"""
	print("CharacterDetailsScreen: Saving changes...")

	if not current_character:
		return

	# Apply UI changes to character
	if name_edit:
		current_character.name = name_edit.text

	# Equipment changes
	if equipment_list and "equipment" in current_character:
		current_character.equipment.clear()
		for i in equipment_list.item_count:
			var item_text = equipment_list.get_item_text(i)
			current_character.equipment.append(item_text)

	# Mark campaign as modified (needs save)
	if GameStateManager:
		GameStateManager.mark_campaign_modified()

	print("CharacterDetailsScreen: Changes saved to character")

	# Return to crew management
	return_to_crew_management()

func _on_cancel_pressed() -> void:
	"""Cancel changes and return"""
	print("CharacterDetailsScreen: Canceling changes...")

	# Restore original data if possible
	if current_character and not original_data.is_empty():
		if current_character.has_method("from_dictionary"):
			current_character.from_dictionary(original_data)
			print("CharacterDetailsScreen: Restored original character data")

	# Return to crew management
	return_to_crew_management()

func return_to_crew_management() -> void:
	"""Navigate back to crew management screen"""
	# Clear temp data
	if GameStateManager and GameStateManager.has_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER):
		GameStateManager.clear_temp_data(GameStateManager.TEMP_KEY_SELECTED_CHARACTER)

	# Navigate back using standardized navigation
	GameStateManager.navigate_to_screen("crew_management")

func _on_add_equipment_pressed() -> void:
	"""Add equipment item via picker dialog"""
	print("CharacterDetailsScreen: Add equipment requested")

	# Create and show equipment picker dialog
	var dialog = preload("res://src/ui/components/dialogs/EquipmentPickerDialog.gd").new()
	add_child(dialog)

	# Connect to selection signal
	dialog.equipment_selected.connect(func(item_id: String):
		if equipment_list:
			var item_name = EquipmentPickerDialog.get_equipment_name(item_id)
			equipment_list.add_item(item_name)
			print("CharacterDetailsScreen: Added equipment - ", item_name)
	)

	# Show dialog centered
	dialog.popup_centered()

func _on_remove_equipment_pressed() -> void:
	"""Remove selected equipment item"""
	if not equipment_list:
		return

	var selected = equipment_list.get_selected_items()
	if selected.size() > 0:
		var item_index = selected[0]
		var item_name = equipment_list.get_item_text(item_index)
		equipment_list.remove_item(item_index)
		print("CharacterDetailsScreen: Removed equipment - ", item_name)
	else:
		print("CharacterDetailsScreen: No equipment selected to remove")
