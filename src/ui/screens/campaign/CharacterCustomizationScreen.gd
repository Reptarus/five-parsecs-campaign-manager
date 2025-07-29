@tool
extends Window
class_name CharacterCustomizationScreen

## Character Customization Screen
## Multi-step character editing interface for Five Parsecs Campaign Manager

const Character = preload("res://src/core/character/Character.gd")
# GlobalEnums available as autoload singleton
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")

signal character_customization_complete(character: Character)
signal character_customization_cancelled()

# Customization steps
enum CustomizationStep {
	BASIC_INFO, # Name, portrait, background, motivation
	ATTRIBUTES, # Stats adjustment and rerolling
	RELATIONSHIPS, # Patron/rival generation (future)
	EQUIPMENT, # Starting gear selection (future)
	REVIEW # Final confirmation
}

# UI Components
var step_container: Control
var step_title_label: Label
var step_description_label: Label
var step_content_container: Control
var navigation_container: HBoxContainer
var back_button: Button
var next_button: Button
var cancel_button: Button
var finish_button: Button
var progress_bar: ProgressBar

# State management
var editing_character: Character
var character_backup: Dictionary
var current_step: int = CustomizationStep.BASIC_INFO
var step_data: Dictionary = {}
var is_initialized: bool = false

# Step panels
var basic_info_panel: Control
var attributes_panel: Control
var review_panel: Control

func _ready() -> void:
	print("CharacterCustomizationScreen: Initializing...")
	call_deferred("_initialize_ui")

func _initialize_ui() -> void:
	"""Initialize the UI components"""
	_create_ui_structure()
	_connect_signals()
	is_initialized = true
	print("CharacterCustomizationScreen: UI initialized")

func _create_ui_structure() -> void:
	"""Create the main UI structure"""
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Header section
	var header_container = VBoxContainer.new()
	main_vbox.add_child(header_container)
	
	# Title
	step_title_label = Label.new()
	step_title_label.text = "Character Customization"
	step_title_label.add_theme_font_size_override("font_size", 24)
	step_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(step_title_label)
	
	# Description
	step_description_label = Label.new()
	step_description_label.text = "Customize your character's details"
	step_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(step_description_label)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.max_value = CustomizationStep.size() - 1
	progress_bar.value = 0
	header_container.add_child(progress_bar)
	
	# Content area
	step_content_container = Control.new()
	step_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(step_content_container)
	
	# Navigation
	navigation_container = HBoxContainer.new()
	navigation_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(navigation_container)
	
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	navigation_container.add_child(cancel_button)
	
	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_container.add_child(spacer1)
	
	back_button = Button.new()
	back_button.text = "Back"
	back_button.disabled = true
	navigation_container.add_child(back_button)
	
	next_button = Button.new()
	next_button.text = "Next"
	navigation_container.add_child(next_button)
	
	finish_button = Button.new()
	finish_button.text = "Finish"
	finish_button.visible = false
	navigation_container.add_child(finish_button)

func _connect_signals() -> void:
	"""Connect button signals"""
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if finish_button:
		finish_button.pressed.connect(_on_finish_pressed)

## Public API

func start_customization(character: Character) -> void:
	"""Start the customization process for a character"""
	if not character or not is_instance_valid(character):
		push_error("CharacterCustomizationScreen: Invalid character provided")
		return
	
	editing_character = character
	character_backup = _serialize_character(character)
	current_step = CustomizationStep.BASIC_INFO
	step_data.clear()
	
	_update_ui_for_step(current_step)
	_update_navigation()
	
	# Show as popup window
	popup_centered_clamped(Vector2i(800, 600), 0.8)
	
	print("CharacterCustomizationScreen: Started customization for: ", character.character_name)

## Step Management

func _update_ui_for_step(step: CustomizationStep) -> void:
	"""Update UI to show the specified step"""
	_clear_step_content()
	
	match step:
		CustomizationStep.BASIC_INFO:
			_show_basic_info_step()
		CustomizationStep.ATTRIBUTES:
			_show_attributes_step()
		CustomizationStep.RELATIONSHIPS:
			_show_relationships_step()
		CustomizationStep.EQUIPMENT:
			_show_equipment_step()
		CustomizationStep.REVIEW:
			_show_review_step()
		_:
			push_warning("CharacterCustomizationScreen: Unknown step: ", step)
	
	# Update progress
	if progress_bar:
		progress_bar.value = step
	
	print("CharacterCustomizationScreen: Showing step: ", CustomizationStep.keys()[step])

func _clear_step_content() -> void:
	"""Clear the current step content"""
	if not step_content_container:
		return
	
	for child in step_content_container.get_children():
		child.queue_free()

func _show_basic_info_step() -> void:
	"""Show the basic info customization step"""
	step_title_label.text = "Basic Information"
	step_description_label.text = "Set your character's name, background, and motivation"
	
	basic_info_panel = _create_basic_info_panel()
	step_content_container.add_child(basic_info_panel)

func _create_basic_info_panel() -> Control:
	"""Create the basic info editing panel"""
	var panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Character Name
	var name_container = HBoxContainer.new()
	panel.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Character Name:"
	name_label.custom_minimum_size.x = 120
	name_container.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.text = editing_character.character_name if editing_character.character_name else ""
	name_input.placeholder_text = "Enter character name"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_input)
	name_input.text_changed.connect(_on_name_changed)
	
	# Background selection
	var bg_container = HBoxContainer.new()
	panel.add_child(bg_container)
	
	var bg_label = Label.new()
	bg_label.text = "Background:"
	bg_label.custom_minimum_size.x = 120
	bg_container.add_child(bg_label)
	
	var bg_option = OptionButton.new()
	bg_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_container.add_child(bg_option)
	
	# Populate background options
	for bg_key in GlobalEnums.Background.keys():
		if bg_key != "NONE" and bg_key != "UNKNOWN":
			bg_option.add_item(bg_key.capitalize())
	
	# Set current selection
	var current_bg_index = editing_character.background
	if current_bg_index > 0 and current_bg_index < bg_option.get_item_count():
		bg_option.select(current_bg_index - 1) # Adjust for NONE
	
	bg_option.item_selected.connect(_on_background_changed)
	
	# Motivation selection
	var mot_container = HBoxContainer.new()
	panel.add_child(mot_container)
	
	var mot_label = Label.new()
	mot_label.text = "Motivation:"
	mot_label.custom_minimum_size.x = 120
	mot_container.add_child(mot_label)
	
	var mot_option = OptionButton.new()
	mot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mot_container.add_child(mot_option)
	
	# Populate motivation options
	for mot_key in GlobalEnums.Motivation.keys():
		if mot_key != "NONE" and mot_key != "UNKNOWN":
			mot_option.add_item(mot_key.capitalize())
	
	# Set current selection
	var current_mot_index = editing_character.motivation
	if current_mot_index > 0 and current_mot_index < mot_option.get_item_count():
		mot_option.select(current_mot_index - 1) # Adjust for NONE
	
	mot_option.item_selected.connect(_on_motivation_changed)
	
	return panel

func _show_attributes_step() -> void:
	"""Show the attributes customization step"""
	step_title_label.text = "Character Attributes"
	step_description_label.text = "Adjust your character's stats or reroll for new values"
	
	attributes_panel = _create_attributes_panel()
	step_content_container.add_child(attributes_panel)

func _create_attributes_panel() -> Control:
	"""Create the attributes editing panel"""
	var panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Reroll button
	var reroll_container = HBoxContainer.new()
	panel.add_child(reroll_container)
	
	var reroll_button = Button.new()
	reroll_button.text = "Reroll All Attributes"
	reroll_button.pressed.connect(_on_reroll_attributes)
	reroll_container.add_child(reroll_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll_container.add_child(spacer)
	
	# Attributes display and editing
	var attrs_grid = GridContainer.new()
	attrs_grid.columns = 3
	panel.add_child(attrs_grid)
	
	# Headers
	var header_stat = Label.new()
	header_stat.text = "Attribute"
	attrs_grid.add_child(header_stat)
	
	var header_value = Label.new()
	header_value.text = "Value"
	attrs_grid.add_child(header_value)
	
	var header_range = Label.new()
	header_range.text = "Range"
	attrs_grid.add_child(header_range)
	
	# Attribute rows
	_add_attribute_row(attrs_grid, "Combat", editing_character.combat, 0, 3)
	_add_attribute_row(attrs_grid, "Reaction", editing_character.reaction, 1, 6)
	_add_attribute_row(attrs_grid, "Toughness", editing_character.toughness, 3, 6)
	_add_attribute_row(attrs_grid, "Savvy", editing_character.savvy, 0, 3)
	_add_attribute_row(attrs_grid, "Speed", editing_character.speed, 4, 8)
	
	# Health display (calculated)
	var health_container = HBoxContainer.new()
	panel.add_child(health_container)
	
	var health_label = Label.new()
	health_label.text = "Health: %d (Toughness + 2)" % (editing_character.toughness + 2)
	health_container.add_child(health_label)
	
	return panel

func _add_attribute_row(grid: GridContainer, name: String, value: int, min_val: int, max_val: int) -> void:
	"""Add an attribute row to the grid"""
	var name_label = Label.new()
	name_label.text = name
	grid.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = str(value)
	value_label.name = name + "_value"
	grid.add_child(value_label)
	
	var range_label = Label.new()
	range_label.text = "%d-%d" % [min_val, max_val]
	grid.add_child(range_label)

func _show_relationships_step() -> void:
	"""Show the relationships customization step"""
	step_title_label.text = "Character Relationships"
	step_description_label.text = "Generate patrons, rivals, and connections for your character"
	
	var relationships_panel = _create_relationships_panel()
	step_content_container.add_child(relationships_panel)

func _create_relationships_panel() -> Control:
	"""Create the relationships editing panel"""
	var panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Generate relationships button
	var generate_container = HBoxContainer.new()
	panel.add_child(generate_container)
	
	var generate_button = Button.new()
	generate_button.text = "Generate Relationships"
	generate_button.pressed.connect(_on_generate_relationships)
	generate_container.add_child(generate_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_container.add_child(spacer)
	
	# Relationships display
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	var relationships_display = VBoxContainer.new()
	relationships_display.name = "RelationshipsDisplay"
	scroll.add_child(relationships_display)
	
	_update_relationships_display()
	
	return panel

func _update_relationships_display() -> void:
	"""Update the relationships display"""
	var display = step_content_container.find_child("RelationshipsDisplay", true, false)
	if not display:
		return
	
	# Clear existing display
	for child in display.get_children():
		child.queue_free()
	
	# Show patrons
	if editing_character.patrons.size() > 0:
		var patrons_label = Label.new()
		patrons_label.text = "Patrons (%d):" % editing_character.patrons.size()
		patrons_label.add_theme_font_size_override("font_size", 16)
		display.add_child(patrons_label)
		
		for patron in editing_character.patrons:
			var patron_info = RichTextLabel.new()
			patron_info.custom_minimum_size.y = 60
			patron_info.bbcode_enabled = true
			patron_info.text = "[b]%s[/b] - %s\n%s" % [
				patron.get("name", "Unknown"),
				patron.get("type", "Contact"),
				patron.get("description", "No description")
			]
			display.add_child(patron_info)
	
	# Show rivals
	if editing_character.rivals.size() > 0:
		var rivals_label = Label.new()
		rivals_label.text = "Rivals (%d):" % editing_character.rivals.size()
		rivals_label.add_theme_font_size_override("font_size", 16)
		display.add_child(rivals_label)
		
		for rival in editing_character.rivals:
			var rival_info = RichTextLabel.new()
			rival_info.custom_minimum_size.y = 60
			rival_info.bbcode_enabled = true
			rival_info.text = "[b]%s[/b] - %s\n%s" % [
				rival.get("name", "Unknown"),
				rival.get("type", "Enemy"),
				rival.get("description", "No description")
			]
			display.add_child(rival_info)
	
	# Character traits are handled through background and motivation effects
	# rather than as a separate traits attribute to align with Five Parsecs rules

func _show_equipment_step() -> void:
	"""Show the equipment customization step"""
	step_title_label.text = "Starting Equipment"
	step_description_label.text = "Review and customize your character's starting equipment"
	
	var equipment_panel = _create_equipment_panel()
	step_content_container.add_child(equipment_panel)

func _create_equipment_panel() -> Control:
	"""Create the equipment editing panel"""
	var panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Generate equipment button
	var generate_container = HBoxContainer.new()
	panel.add_child(generate_container)
	
	var generate_button = Button.new()
	generate_button.text = "Generate Equipment"
	generate_button.pressed.connect(_on_generate_equipment)
	generate_container.add_child(generate_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_container.add_child(spacer)
	
	# Credits display
	var credits_container = HBoxContainer.new()
	panel.add_child(credits_container)
	
	var credits_label = Label.new()
	credits_label.text = "Starting Credits:"
	credits_container.add_child(credits_label)
	
	var credits_spinbox = SpinBox.new()
	credits_spinbox.min_value = 0
	credits_spinbox.max_value = 5000
	credits_spinbox.step = 100
	credits_spinbox.value = editing_character.credits_earned
	credits_spinbox.value_changed.connect(_on_credits_changed)
	credits_container.add_child(credits_spinbox)
	
	# Equipment display
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	var equipment_display = VBoxContainer.new()
	equipment_display.name = "EquipmentDisplay"
	scroll.add_child(equipment_display)
	
	_update_equipment_display()
	
	return panel

func _update_equipment_display() -> void:
	"""Update the equipment display"""
	var display = step_content_container.find_child("EquipmentDisplay", true, false)
	if not display:
		return
	
	# Clear existing display
	for child in display.get_children():
		child.queue_free()
	
	var equipment = editing_character.personal_equipment
	
	# Show weapons
	if equipment.has("weapons") and equipment.weapons.size() > 0:
		var weapons_label = Label.new()
		weapons_label.text = "Weapons:"
		weapons_label.add_theme_font_size_override("font_size", 16)
		display.add_child(weapons_label)
		
		for weapon in equipment.weapons:
			var weapon_info = Label.new()
			weapon_info.text = "• %s (%s condition) - %d credits" % [
				weapon.get("name", "Unknown"),
				weapon.get("condition", "Standard"),
				weapon.get("value", 0)
			]
			display.add_child(weapon_info)
	
	# Show armor
	if equipment.has("armor") and equipment.armor.size() > 0:
		var armor_label = Label.new()
		armor_label.text = "Armor:"
		armor_label.add_theme_font_size_override("font_size", 16)
		display.add_child(armor_label)
		
		for armor in equipment.armor:
			var armor_info = Label.new()
			armor_info.text = "• %s (%s condition) - %d credits" % [
				armor.get("name", "Unknown"),
				armor.get("condition", "Standard"),
				armor.get("value", 0)
			]
			display.add_child(armor_info)
	
	# Show items
	if equipment.has("items") and equipment.items.size() > 0:
		var items_label = Label.new()
		items_label.text = "Items:"
		items_label.add_theme_font_size_override("font_size", 16)
		display.add_child(items_label)
		
		for item in equipment.items:
			var item_info = Label.new()
			item_info.text = "• %s (%s condition) - %d credits" % [
				item.get("name", "Unknown"),
				item.get("condition", "Standard"),
				item.get("value", 0)
			]
			display.add_child(item_info)

func _show_review_step() -> void:
	"""Show the final review step"""
	step_title_label.text = "Review Character"
	step_description_label.text = "Review your character's details before finishing"
	
	review_panel = _create_review_panel()
	step_content_container.add_child(review_panel)

func _create_review_panel() -> Control:
	"""Create the review panel"""
	var panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Character summary
	var summary_label = RichTextLabel.new()
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label.bbcode_enabled = true
	summary_label.text = _generate_character_summary()
	panel.add_child(summary_label)
	
	return panel

func _generate_character_summary() -> String:
	"""Generate a summary of the character for review"""
	var summary = "[center][b]%s[/b][/center]\n\n" % editing_character.character_name
	
	# Basic info
	summary += "[b]Background:[/b] %s\n" % GlobalEnums.Background.keys()[editing_character.background].capitalize()
	summary += "[b]Motivation:[/b] %s\n" % GlobalEnums.Motivation.keys()[editing_character.motivation].capitalize()
	summary += "[b]Class:[/b] %s\n\n" % GlobalEnums.CharacterClass.keys()[editing_character.character_class].capitalize()
	
	# Attributes
	summary += "[b]Attributes:[/b]\n"
	summary += "• Combat: %d\n" % editing_character.combat
	summary += "• Reaction: %d\n" % editing_character.reaction
	summary += "• Toughness: %d\n" % editing_character.toughness
	summary += "• Savvy: %d\n" % editing_character.savvy
	summary += "• Speed: %d\n" % editing_character.speed
	summary += "• Health: %d\n\n" % editing_character.max_health
	
	# Relationships
	if editing_character.patrons.size() > 0 or editing_character.rivals.size() > 0:
		summary += "[b]Relationships:[/b]\n"
		summary += "• Patrons: %d\n" % editing_character.patrons.size()
		summary += "• Rivals: %d\n" % editing_character.rivals.size()
		summary += "\n"
	
	# Equipment and wealth
	if editing_character.personal_equipment.size() > 0 or editing_character.credits_earned > 0:
		summary += "[b]Equipment & Wealth:[/b]\n"
		if editing_character.credits_earned > 0:
			summary += "• Starting Credits: %d\n" % editing_character.credits_earned
		
		var equipment = editing_character.personal_equipment
		if equipment.has("weapons"):
			summary += "• Weapons: %d\n" % equipment.weapons.size()
		if equipment.has("armor"):
			summary += "• Armor: %d\n" % equipment.armor.size()
		if equipment.has("items"):
			summary += "• Items: %d\n" % equipment.items.size()
		summary += "\n"
	
	# Character traits are handled through background and motivation effects
	# rather than as a separate traits attribute to align with Five Parsecs rules
	
	# Status
	if editing_character.is_captain:
		summary += "[b]Status:[/b] Captain\n\n"
	
	# Completion level
	var completeness = editing_character.get_customization_completeness()
	summary += "[b]Customization Level:[/b] %.0f%% Complete\n" % (completeness * 100)
	
	return summary

## Navigation

func _update_navigation() -> void:
	"""Update navigation button states"""
	if not is_initialized:
		return
	
	back_button.disabled = (current_step == CustomizationStep.BASIC_INFO)
	
	if current_step == CustomizationStep.REVIEW:
		next_button.visible = false
		finish_button.visible = true
	else:
		next_button.visible = true
		finish_button.visible = false

## Signal Handlers

func _on_cancel_pressed() -> void:
	"""Handle cancel button press"""
	_restore_character_from_backup(editing_character, character_backup)
	character_customization_cancelled.emit()
	queue_free()

func _on_back_pressed() -> void:
	"""Handle back button press"""
	if current_step > CustomizationStep.BASIC_INFO:
		current_step -= 1
		_update_ui_for_step(current_step)
		_update_navigation()

func _on_next_pressed() -> void:
	"""Handle next button press"""
	if _validate_current_step():
		current_step += 1
		_update_ui_for_step(current_step)
		_update_navigation()

func _on_finish_pressed() -> void:
	"""Handle finish button press"""
	if _validate_current_step():
		_finalize_customization()

func _on_name_changed(new_name: String) -> void:
	"""Handle character name change"""
	editing_character.character_name = new_name.strip_edges()

func _on_background_changed(index: int) -> void:
	"""Handle background selection change"""
	# Add 1 to account for NONE being 0
	editing_character.background = index + 1

func _on_motivation_changed(index: int) -> void:
	"""Handle motivation selection change"""
	# Add 1 to account for NONE being 0
	editing_character.motivation = index + 1

func _on_reroll_attributes() -> void:
	"""Handle attribute reroll"""
	FiveParsecsCharacterGeneration.generate_character_attributes(editing_character)
	editing_character.max_health = editing_character.toughness + 2
	editing_character.health = editing_character.max_health
	
	# Update the display
	_update_attributes_display()

func _update_attributes_display() -> void:
	"""Update the attributes display after reroll"""
	if not attributes_panel:
		return
	
	# Find and update value labels
	_update_attribute_value("Combat", editing_character.combat)
	_update_attribute_value("Reaction", editing_character.reaction)
	_update_attribute_value("Toughness", editing_character.toughness)
	_update_attribute_value("Savvy", editing_character.savvy)
	_update_attribute_value("Speed", editing_character.speed)
	
	# Update health display
	for child in attributes_panel.get_children():
		if child is HBoxContainer:
			for subchild in child.get_children():
				if subchild is Label and "Health:" in subchild.text:
					subchild.text = "Health: %d (Toughness + 2)" % (editing_character.toughness + 2)

func _update_attribute_value(attr_name: String, value: int) -> void:
	"""Update a specific attribute value display"""
	var value_label = attributes_panel.find_child(attr_name + "_value", true, false)
	if value_label and value_label is Label:
		value_label.text = str(value)

## Validation

func _on_generate_relationships() -> void:
	"""Handle relationship generation"""
	# Generate patrons and rivals using the enhanced character generation
	editing_character.patrons = FiveParsecsCharacterGeneration._generate_patrons(editing_character)
	editing_character.rivals = FiveParsecsCharacterGeneration._generate_rivals(editing_character)
	
	# Apply background and motivation effects
	FiveParsecsCharacterGeneration._apply_background_effects(editing_character)
	FiveParsecsCharacterGeneration._apply_motivation_effects(editing_character)
	
	# Update the display
	_update_relationships_display()

func _on_generate_equipment() -> void:
	"""Handle equipment generation"""
	# Generate equipment using the enhanced system
	editing_character.personal_equipment = FiveParsecsCharacterGeneration._generate_starting_equipment_enhanced(editing_character)
	
	# Update the display
	_update_equipment_display()

func _on_credits_changed(value: float) -> void:
	"""Handle credits change"""
	editing_character.credits_earned = int(value)

func _validate_current_step() -> bool:
	"""Validate the current step data"""
	match current_step:
		CustomizationStep.BASIC_INFO:
			return _validate_basic_info()
		CustomizationStep.ATTRIBUTES:
			return _validate_attributes()
		CustomizationStep.RELATIONSHIPS:
			return _validate_relationships()
		CustomizationStep.EQUIPMENT:
			return _validate_equipment()
		CustomizationStep.REVIEW:
			return true
		_:
			return true

func _validate_basic_info() -> bool:
	"""Validate basic info step"""
	if not editing_character.character_name or editing_character.character_name.is_empty():
		_show_validation_error("Character name is required")
		return false
	
	if editing_character.background <= 0:
		_show_validation_error("Please select a background")
		return false
	
	if editing_character.motivation <= 0:
		_show_validation_error("Please select a motivation")
		return false
	
	return true

func _validate_attributes() -> bool:
	"""Validate attributes step"""
	return true # Attributes are automatically valid from generation

func _validate_relationships() -> bool:
	"""Validate relationships step"""
	# Relationships are optional, so always valid
	return true

func _validate_equipment() -> bool:
	"""Validate equipment step"""
	# Equipment is optional, so always valid
	return true

func _show_validation_error(message: String) -> void:
	"""Show a validation error dialog"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Validation Error"
	get_viewport().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

## Data Management

func _serialize_character(character: Character) -> Dictionary:
	"""Create a backup of character data"""
	return {
		"character_name": character.character_name,
		"background": character.background,
		"motivation": character.motivation,
		"combat": character.combat,
		"reaction": character.reaction,
		"toughness": character.toughness,
		"savvy": character.savvy,
		"speed": character.speed,
		"max_health": character.max_health,
		"health": character.health,
		"patrons": character.patrons.duplicate(),
		"rivals": character.rivals.duplicate(),
		"personal_equipment": character.personal_equipment.duplicate(),
		"credits_earned": character.credits_earned,
		"is_captain": character.is_captain
	}

func _restore_character_from_backup(character: Character, backup: Dictionary) -> void:
	"""Restore character from backup data"""
	character.character_name = backup.get("character_name", "")
	character.background = backup.get("background", 0)
	character.motivation = backup.get("motivation", 0)
	character.combat = backup.get("combat", 0)
	character.reaction = backup.get("reaction", 0)
	character.toughness = backup.get("toughness", 3)
	character.savvy = backup.get("savvy", 0)
	character.speed = backup.get("speed", 4)
	character.max_health = backup.get("max_health", 5)
	character.health = backup.get("health", 5)
	character.patrons = backup.get("patrons", [])
	character.rivals = backup.get("rivals", [])
	character.personal_equipment = backup.get("personal_equipment", {})
	character.credits_earned = backup.get("credits_earned", 0)
	character.is_captain = backup.get("is_captain", false)

func _finalize_customization() -> void:
	"""Finalize the customization process"""
	print("CharacterCustomizationScreen: Finalizing customization for: ", editing_character.character_name)
	character_customization_complete.emit(editing_character)
	queue_free()
