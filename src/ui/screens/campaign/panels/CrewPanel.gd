extends Control

## Five Parsecs Campaign Creation Crew Panel
## Production-ready implementation with proper error handling

const Character = preload("res://src/core/character/Base/Character.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")

signal crew_updated(crew: Array)
signal crew_setup_complete(crew_data: Dictionary)

# UI Components using safe access pattern
var crew_size_option: OptionButton
var crew_list: ItemList
var character_creator: Node
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

var crew_members: Array[Character] = []
var selected_size: int = 4
var is_initialized: bool = false
var current_captain: Character = null

# Data-driven character creation tables
var _character_data: Dictionary = {}
var _backgrounds_data: Dictionary = {}
var _skills_data: Dictionary = {}

func _ready() -> void:
	print("CrewPanel: Initializing with production-ready patterns...")
	call_deferred("_initialize_components")

func _initialize_components() -> void:
	"""Initialize UI components with safe access patterns"""
	var success: bool = true

	# Load data first
	_load_character_data()

	# Safe component access with error handling
	crew_size_option = get_node_or_null("Content/CrewSize/OptionButton")
	crew_list = get_node_or_null("Content/CrewList/ItemList")
	character_creator = get_node_or_null("CharacterCreator")

	add_button = get_node_or_null("Content/Controls/AddButton")
	edit_button = get_node_or_null("Content/Controls/EditButton")
	remove_button = get_node_or_null("Content/Controls/RemoveButton")
	randomize_button = get_node_or_null("Content/Controls/RandomizeButton")

	# Validate critical components
	if not crew_size_option or not crew_list:
		push_error("CrewPanel: Critical UI components missing - panel cannot function")
		_show_error_state()
		return

	print("CrewPanel: UI components found successfully")
	print("  - crew_size_option: ", crew_size_option != null)
	print("  - crew_list: ", crew_list != null)
	print("  - add_button: ", add_button != null)
	print("  - edit_button: ", edit_button != null)
	print("  - remove_button: ", remove_button != null)
	print("  - randomize_button: ", randomize_button != null)
	print("  - character_creator: ", character_creator != null)

	# Initialize components that exist
	_setup_crew_size_options()
	_connect_signals()
	_generate_initial_crew()
	_update_crew_list()
	is_initialized = true
	print("CrewPanel: Initialization complete")

func _load_character_data() -> void:
	_character_data = UniversalResourceLoader.load_json_safe("res://data/character_creation_data.json", "Character Creation Data")
	_backgrounds_data = UniversalResourceLoader.load_json_safe("res://data/character_backgrounds.json", "Character Backgrounds")

func _show_error_state() -> void:
	"""Display error state when components are missing"""
	# Create a simple error label if the main components are missing
	var error_label: Label = Label.new()
	error_label.text = "Crew setup components not available. Please check scene configuration."
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(error_label)

func _setup_crew_size_options() -> void:
	"""Configure crew size options with Five Parsecs defaults"""
	if not crew_size_option:
		return

	crew_size_option.clear()
	crew_size_option.add_item("4 Members (Standard)", 4)
	crew_size_option.add_item("5 Members (Expanded)", 5)
	crew_size_option.add_item("6 Members (Large)", 6)

	crew_size_option.select(0) # Default to standard 4-member crew
	selected_size = 4

func _connect_signals() -> void:
	"""Establish signal connections with error handling"""
	print("CrewPanel: Connecting signals...")
	
	if crew_size_option:
		crew_size_option.item_selected.connect(_on_crew_size_selected)
		print("  - crew_size_option signals connected")

	if add_button:
		add_button.pressed.connect(_on_add_member_pressed)
		print("  - add_button signal connected")
	if edit_button:
		edit_button.pressed.connect(_on_edit_member_pressed)
		print("  - edit_button signal connected")
	if remove_button:
		remove_button.pressed.connect(_on_remove_member_pressed)
		print("  - remove_button signal connected")
	if randomize_button:
		randomize_button.pressed.connect(_on_randomize_pressed)
		print("  - randomize_button signal connected")

	if crew_list:
		crew_list.item_selected.connect(_on_crew_member_selected)
		print("  - crew_list signal connected")

	# Connect character creator if available and has expected signals
	if character_creator and character_creator.has_signal("character_created"):
		character_creator.character_created.connect(_on_character_created)
		print("  - character_creator signal connected")
	else:
		print("  - character_creator not available or missing signals")
	
	print("CrewPanel: Signal connections complete")

func _generate_initial_crew() -> void:
	"""Generate initial crew members based on Five Parsecs rules"""
	crew_members.clear()

	for i: int in range(selected_size):
		var character: Character = _create_random_character()
		if character:
			crew_members.append(character)

	_update_crew_list()
	crew_updated.emit(crew_members)

func _create_random_character() -> Character:
	"""Create random character with robust fallback system"""
	var character: Character = null
	
	# Primary method: Use FiveParsecsCharacterGeneration system with enhanced features
	if FiveParsecsCharacterGeneration:
		character = FiveParsecsCharacterGeneration.generate_complete_character()
		if character and is_instance_valid(character):
			print("CrewPanel: Generated character using FiveParsecsCharacterGeneration: ", character.character_name)
			return character
		else:
			print("CrewPanel: FiveParsecsCharacterGeneration returned invalid character, using fallback")
	
	# Fallback method: Create character manually
	character = Character.new()
	
	# Generate basic attributes manually (Five Parsecs rules: 2d6/3 rounded up)
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute() - 1 # Combat skill bonus format
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute() - 1 # Savvy bonus format
	character.speed = _generate_five_parsecs_attribute() + 2 # Speed in inches
	character.luck = 1 if character.origin == GlobalEnums.Origin.HUMAN else 0
	
	# Clamp to Five Parsecs ranges
	character.reaction = clampi(character.reaction, 1, 6)
	character.combat = clampi(character.combat, 0, 3)
	character.toughness = clampi(character.toughness, 3, 6)
	character.savvy = clampi(character.savvy, 0, 3)
	character.speed = clampi(character.speed, 4, 8)
	
	# Set health (Five Parsecs rule: Toughness + 2)
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Assign random background and motivation
	var backgrounds = [GlobalEnums.Background.SOLDIER, GlobalEnums.Background.MERCHANT, GlobalEnums.Background.COLONIST, GlobalEnums.Background.ACADEMIC]
	var motivations = [GlobalEnums.Motivation.SURVIVAL, GlobalEnums.Motivation.WEALTH, GlobalEnums.Motivation.GLORY, GlobalEnums.Motivation.FREEDOM]
	var classes = [GlobalEnums.CharacterClass.SOLDIER, GlobalEnums.CharacterClass.SCOUT, GlobalEnums.CharacterClass.MEDIC, GlobalEnums.CharacterClass.ENGINEER]
	
	character.background = backgrounds[randi() % backgrounds.size()]
	character.motivation = motivations[randi() % motivations.size()]
	character.character_class = classes[randi() % classes.size()]
	character.origin = GlobalEnums.Origin.HUMAN # Default to human
	
	# Generate name based on origin
	character.character_name = _generate_fallback_name()
	
	# Apply origin bonuses
	character.is_human = true
	
	print("CrewPanel: Generated fallback character: ", character.character_name)
	return character

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute using 2d6/3 rounded up"""
	var roll = randi_range(2, 12) # 2d6
	return ceili(float(roll) / 3.0)

func _generate_fallback_name() -> String:
	"""Generate a random character name for fallback creation"""
	var first_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake", "Cameron", "Jamie", "Sage", "Rowan", "Kai"]
	var last_names = ["Vega", "Cruz", "Stone", "Hunter", "Fox", "Storm", "Reeves", "Cross", "Vale", "Kane", "Steele", "Raven", "Wolf", "Shaw", "Grey"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

func _update_crew_list() -> void:
	"""Update the crew list display with enhanced visual polish and completeness tracking"""
	if not crew_list:
		return

	crew_list.clear()

	# Enhanced crew status with completion percentage
	var completion_percentage = _calculate_crew_completeness()
	var status_text = "Crew Status: %d/%d members (%.0f%% configured)" % [
		crew_members.size(), selected_size, completion_percentage
	]
	
	if has_captain():
		var captain = _get_captain()
		status_text += " ★ Captain: %s" % captain.character_name
	else:
		status_text += " ⚠ No Captain Assigned"
	
	crew_list.add_item(status_text)
	crew_list.set_item_disabled(0, true) # Make status non-selectable

	# Add crew statistics summary
	var summary = _get_crew_summary()
	var summary_text = "Patrons: %d | Rivals: %d | Credits: %d" % [
		summary.total_patrons, summary.total_rivals, summary.total_credits
	]
	crew_list.add_item(summary_text)
	crew_list.set_item_disabled(1, true)

	# Add separator
	crew_list.add_item("────────────────────")
	crew_list.set_item_disabled(2, true)

	for i: int in range(crew_members.size()):
		var character: Character = crew_members[i]
		var display_text = _create_enhanced_character_display(character, i)
		crew_list.add_item(display_text)

	# Update button states with enhanced logic
	var selected_items = crew_list.get_selected_items()
	var has_valid_selection = not selected_items.is_empty() and selected_items[0] > 1 # Skip status items

	if edit_button:
		edit_button.disabled = not has_valid_selection
	if remove_button:
		remove_button.disabled = not has_valid_selection or crew_members.size() <= 1
	if add_button:
		add_button.disabled = crew_members.size() >= 6

	# Update crew completion status
	_update_completion_status()

func _create_enhanced_character_display(character: Character, index: int) -> String:
	"""Create enhanced character display with customization status"""
	var name = character.character_name if character.character_name else "Unnamed"
	var captain_indicator = " ★" if character.is_captain else ""
	
	# Get customization completeness
	var customization_level = 0.0
	if character.has_method("get_customization_completeness"):
		customization_level = character.get_customization_completeness()
	else:
		customization_level = _estimate_character_completeness(character)
	
	# Status indicators
	var status_icon = "✅" if customization_level >= 0.8 else ("⚠️" if customization_level >= 0.5 else "❌")
	var completion_text = "%.0f%% configured" % (customization_level * 100)
	
	# Character stats
	var combat_stat = character.combat if character.combat > 0 else 0
	var toughness_stat = character.toughness if character.toughness > 0 else 3
	var health = character.max_health if character.max_health > 0 else toughness_stat + 2
	
	# Background and motivation display
	var background_display = _get_background_display_name(character.background)
	var motivation_display = _get_motivation_display_name(character.motivation)
	
	# Relationship and equipment summary
	var relationships = ""
	var patrons_count = safe_get_property(character, "patrons", []).size()
	var rivals_count = safe_get_property(character, "rivals", []).size()
	if patrons_count > 0 or rivals_count > 0:
		relationships = " | P:%d R:%d" % [patrons_count, rivals_count]
	
	var credits = safe_get_property(character, "credits_earned", 0)
	var credits_text = " | %d cr" % credits if credits > 0 else ""
	
	# Multi-line display with enhanced information
	return "%s %d. %s%s\n   Stats: C%d T%d H%d | %s\n   %s • %s%s%s" % [
		status_icon,
		index + 1,
		name,
		captain_indicator,
		combat_stat,
		toughness_stat,
		health,
		completion_text,
		background_display,
		motivation_display,
		relationships,
		credits_text
	]

func _estimate_character_completeness(character: Character) -> float:
	"""Estimate character completeness for characters without the method"""
	var completeness = 0.0
	var total_criteria = 8.0
	
	# Basic info (3 criteria)
	if character.character_name and not character.character_name.is_empty():
		completeness += 1.0
	if character.background > 0:
		completeness += 1.0
	if character.motivation > 0:
		completeness += 1.0
	
	# Attributes (2 criteria)
	if character.combat >= 0 and character.toughness >= 3:
		completeness += 1.0
	if character.max_health == character.toughness + 2:
		completeness += 1.0
	
	# Relationships (2 criteria)
	if safe_get_property(character, "patrons", []).size() > 0 or safe_get_property(character, "rivals", []).size() > 0:
		completeness += 1.0
	if safe_get_property(character, "traits", []).size() > 0:
		completeness += 1.0
	
	# Equipment (1 criterion)
	if safe_get_property(character, "personal_equipment", {}).size() > 0 or safe_get_property(character, "credits_earned", 0) > 0:
		completeness += 1.0
	
	return completeness / total_criteria

func _calculate_crew_completeness() -> float:
	"""Calculate overall crew completion percentage"""
	if crew_members.is_empty():
		return 0.0
	
	var total_completion = 0.0
	for character in crew_members:
		if character.has_method("get_customization_completeness"):
			total_completion += character.get_customization_completeness()
		else:
			total_completion += _estimate_character_completeness(character)
	
	return (total_completion / crew_members.size()) * 100.0

func _get_captain() -> Character:
	"""Get the current captain character"""
	for character in crew_members:
		if character.is_captain:
			return character
	return null

func _get_crew_summary() -> Dictionary:
	"""Get crew summary statistics"""
	var summary = {
		"total_patrons": 0,
		"total_rivals": 0,
		"total_credits": 0,
		"total_traits": 0
	}
	
	for character in crew_members:
		summary.total_patrons += safe_get_property(character, "patrons", []).size()
		summary.total_rivals += safe_get_property(character, "rivals", []).size()
		summary.total_credits += safe_get_property(character, "credits_earned", 0)
		summary.total_traits += safe_get_property(character, "traits", []).size()
	
	return summary

func _get_background_display_name(background_enum) -> String:
	"""Get display-friendly background name with proper mapping"""
	if background_enum >= 0 and background_enum < GlobalEnums.Background.size():
		var bg_name = GlobalEnums.Background.keys()[background_enum]
		# Map enum names to more user-friendly display names
		match bg_name:
			"MILITARY":
				return "Military"
			"MERCENARY":
				return "Mercenary"
			"CRIMINAL":
				return "Criminal"
			"COLONIST":
				return "Colonist"
			"ACADEMIC":
				return "Academic"
			"EXPLORER":
				return "Explorer"
			"TRADER":
				return "Trader"
			"NOBLE":
				return "Noble"
			"OUTCAST":
				return "Outcast"
			"SOLDIER":
				return "Soldier"
			"MERCHANT":
				return "Merchant"
			_:
				return bg_name.capitalize()
	return "Unknown"

func _get_motivation_display_name(motivation_enum) -> String:
	"""Get display-friendly motivation name"""
	if motivation_enum >= 0 and motivation_enum < GlobalEnums.Motivation.size():
		var mot_name = GlobalEnums.Motivation.keys()[motivation_enum]
		return mot_name.capitalize()
	return "Unknown"

func _update_completion_status():
	"""Update UI to show completion status"""
	var completion_text: String = ""
	if crew_members.size() < selected_size:
		completion_text = "Need %d more crew members" % (selected_size - crew_members.size())
	elif not has_captain():
		completion_text = "⚠ Select a captain to continue"
	else:
		completion_text = "✅ Crew ready for campaign"

	# Emit completion status (this could trigger UI updates elsewhere)
	var completion_data = {
		"is_complete": is_valid(),
		"status_message": completion_text,
		"crew_count": crew_members.size(),
		"required_count": selected_size,
		"has_captain": has_captain()
	}

	self.crew_updated.emit(crew_members)

# Signal handlers
func _on_crew_size_selected(index: int) -> void:
	if not crew_size_option:
		return

	selected_size = crew_size_option.get_item_id(index)
	_adjust_crew_size()
	_update_crew_list()
	crew_updated.emit(crew_members)

func _adjust_crew_size() -> void:
	"""Adjust crew to match selected size"""
	while crew_members.size() < selected_size:
		var character: Character = _create_random_character()
		if character:
			crew_members.append(character)

	while crew_members.size() > selected_size:
		crew_members.pop_back()

	_update_crew_list()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	if crew_members.size() >= 6: # Five Parsecs maximum
		_show_error_message("Maximum crew size reached (6 members)")
		return

	# Create a new character and open customization
	_create_new_character_for_customization()

func _create_new_character_for_customization() -> void:
	"""Create a new character and open the customization screen"""
	var character: Character = _create_random_character()
	if not character:
		push_error("CrewPanel: Failed to create new character")
		_show_error_message("Failed to create new character")
		return
	
	# Set a temporary name if none exists
	if not character.character_name or character.character_name.is_empty():
		character.character_name = "New Crew Member"
	
	# Add to crew temporarily (will be finalized when customization completes)
	crew_members.append(character)
	
	# Auto-assign as captain if this is the first character
	if crew_members.size() == 1 and not has_captain():
		_make_captain(character)
		print("CrewPanel: Auto-assigned first character as captain: ", character.character_name)
	
	# Update display first
	_update_crew_list()
	crew_updated.emit(crew_members)
	
	# Open customization screen
	_open_character_customization(character)

func _show_simple_character_creator():
	"""Show simple character creation dialog for MVP"""
	# Load our simple character creation dialog
	var dialog_scene = load("res://src/ui/screens/campaign/panels/CharacterCreationDialog.tscn")
	if not dialog_scene:
		print("CrewPanel: Could not load CharacterCreationDialog, falling back to random generation")
		_on_add_member_fallback()
		return

	var dialog = dialog_scene.instantiate()
	get_viewport().add_child(dialog)

	# Connect to character creation signal
	if dialog.has_signal("character_created"):
		dialog.character_created.connect(_on_simple_character_created)

	dialog.popup_centered()

func _on_simple_character_created(character_data: Dictionary):
	"""Handle character creation from simple dialog"""
	# Enhanced validation and error handling
	var character_name_str: String = character_data.get("name", "").strip_edges()

	# Prevent empty names
	if character_name_str.is_empty():
		_show_error_message("Character name cannot be empty")
		return

	# Prevent duplicate names
	if _is_duplicate_name(character_name_str):
		_show_error_message("A character with the name '%s' already exists" % character_name_str)
		return

	# Check crew size limits
	if crew_members.size() >= 6:
		_show_error_message("Maximum crew size reached (6 members)")
		return

	# Convert simple character data to Character object for compatibility
	var character: Character = Character.new()

	# Map basic data with enhanced validation
	character.character_name = character_name_str
	character.combat = max(1, character_data.get("combat", 3))
	character.reaction = max(1, character_data.get("reaction", 2))
	character.toughness = max(1, character_data.get("toughness", 3))
	character.savvy = max(1, character_data.get("savvy", 2))
	character.tech = max(1, character_data.get("tech", 2))
	character.move = max(1, character_data.get("move", 4))
	character.is_captain = character_data.get("is_captain", false)

	# Enhanced background/motivation mapping
	var bg_string = character_data.get("background", "soldier")
	var mot_string = character_data.get("motivation", "survival")

	character.background = _map_background_string(bg_string)
	character.motivation = _map_motivation_string(mot_string)
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.origin = GlobalEnums.Origin.HUMAN

	crew_members.append(character)

	# Auto-assign first character as captain for better UX
	if crew_members.size() == 1 and not has_captain():
		_make_captain(character)
		print("CrewPanel: Auto-assigned first character as captain: ", character.character_name)

	_update_crew_list()
	crew_updated.emit(crew_members)

	print("CrewPanel: Added character via enhanced dialog: ", character.character_name)

func _is_duplicate_name(name: String) -> bool:
	"""Check if character name already exists"""
	for character in crew_members:
		var typed_character: Character = character as Character
		if typed_character.character_name.to_lower() == name.to_lower():
			return true
	return false

func _map_background_string(bg_string: String) -> GlobalEnums.Background:
	"""Map background string to enum using available Background values"""
	match bg_string.to_lower():
		"soldier":
			return GlobalEnums.Background.SOLDIER
		"scavenger":
			return GlobalEnums.Background.EXPLORER # Map scavenger to explorer (closest match)
		"colonist":
			return GlobalEnums.Background.COLONIST
		"techie":
			return GlobalEnums.Background.ACADEMIC # Map techie to academic (closest match)
		"merchant":
			return GlobalEnums.Background.MERCHANT
		"pilot":
			return GlobalEnums.Background.SOLDIER # Pilot is a CharacterClass, default to soldier background
		"military":
			return GlobalEnums.Background.MILITARY
		"mercenary":
			return GlobalEnums.Background.MERCENARY
		"criminal":
			return GlobalEnums.Background.CRIMINAL
		"academic":
			return GlobalEnums.Background.ACADEMIC
		"explorer":
			return GlobalEnums.Background.EXPLORER
		"trader":
			return GlobalEnums.Background.TRADER
		"noble":
			return GlobalEnums.Background.NOBLE
		"outcast":
			return GlobalEnums.Background.OUTCAST
		_:
			return GlobalEnums.Background.SOLDIER

func _map_motivation_string(mot_string: String) -> GlobalEnums.Motivation:
	"""Map motivation string to enum"""
	match mot_string.to_lower():
		"revenge":
			return GlobalEnums.Motivation.REVENGE
		"glory":
			return GlobalEnums.Motivation.GLORY
		"survival":
			return GlobalEnums.Motivation.SURVIVAL
		"wealth":
			return GlobalEnums.Motivation.WEALTH
		"freedom":
			return GlobalEnums.Motivation.FREEDOM
		"justice":
			return GlobalEnums.Motivation.JUSTICE
		_:
			return GlobalEnums.Motivation.SURVIVAL

func _show_error_message(message: String):
	"""Show user-friendly error message"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Crew Management Error"
	get_viewport().add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

func _on_add_member_fallback() -> void:
	"""Fallback to random character generation if dialog fails"""
	var character: Character = _create_random_character()
	if character:
		crew_members.append(character)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_edit_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return

	var index = selected[0]
	# Account for status header and separator (first 2 items)
	var crew_index = index - 2
	if crew_index >= 0 and crew_index < crew_members.size():
		_show_character_editor(crew_members[crew_index])

func _on_remove_member_pressed() -> void:
	var selected = crew_list.get_selected_items()
	if selected.is_empty():
		return

	var index = selected[0]
	# Account for status header and separator (first 2 items)
	var crew_index = index - 2
	if crew_index >= 0 and crew_index < crew_members.size():
		crew_members.remove_at(crew_index)
		_update_crew_list()
		crew_updated.emit(crew_members)

func _on_randomize_pressed() -> void:
	_generate_initial_crew()

func _on_character_created(character: Character) -> void:
	crew_members.append(character)
	_update_crew_list()
	crew_updated.emit(crew_members)

func _show_character_editor(character: Character) -> void:
	"""Show character editor using the new CharacterCustomizationScreen"""
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Cannot edit invalid character")
		_show_error_message("Cannot edit character: Invalid character selected")
		return
	
	print("CrewPanel: Opening character editor for: ", character.character_name)
	_open_character_customization(character)

func _open_character_customization(character: Character) -> void:
	"""Open the character customization screen"""
	var customization_scene = preload("res://src/ui/screens/campaign/CharacterCustomizationScreen.tscn")
	if not customization_scene:
		push_error("CrewPanel: Could not load CharacterCustomizationScreen")
		_show_error_message("Character editor is not available")
		return
	
	var customization_screen = customization_scene.instantiate()
	if not customization_screen:
		push_error("CrewPanel: Could not instantiate CharacterCustomizationScreen")
		_show_error_message("Failed to open character editor")
		return
	
	# Connect signals for completion and cancellation
	customization_screen.character_customization_complete.connect(_on_character_customization_complete)
	customization_screen.character_customization_cancelled.connect(_on_character_customization_cancelled)
	
	# Add to scene tree and start customization
	get_viewport().add_child(customization_screen)
	customization_screen.start_customization(character)
	
	print("CrewPanel: Character customization screen opened for: ", character.character_name)

func _on_character_customization_complete(character: Character) -> void:
	"""Handle character customization completion"""
	print("CrewPanel: Character customization completed for: ", character.character_name)
	
	# Update the crew list display to reflect changes
	_update_crew_list()
	crew_updated.emit(crew_members)
	
	# Remove the customization screen (it will queue_free itself)

func _on_character_customization_cancelled() -> void:
	"""Handle character customization cancellation"""
	print("CrewPanel: Character customization cancelled")
	
	# Character was restored to original state, just update display
	_update_crew_list()
	crew_updated.emit(crew_members)
	
	# Remove the customization screen (it will queue_free itself)

func get_crew_data() -> Dictionary:
	"""Return crew data for campaign creation"""
	return {
		"size": selected_size,
		"members": crew_members.duplicate(),
		"captain": current_captain,
		"has_captain": has_captain(),
		"is_complete": crew_members.size() == selected_size and has_captain()
	}

	if crew_list:
		crew_list.item_selected.connect(_on_crew_member_selected)


func _on_crew_member_selected(index: int) -> void:
	if edit_button:
		edit_button.disabled = false
	if remove_button:
		remove_button.disabled = false

	# Show captain assignment option for selected character
	_show_captain_assignment_option(index)

func _show_captain_assignment_option(index: int) -> void:
	"""Show option to make selected character captain with enhanced validation"""
	# Account for status header and separator (first 2 items)
	var crew_index = index - 2
	if crew_index < 0 or crew_index >= crew_members.size():
		push_warning("CrewPanel: Invalid crew member selection for captain assignment")
		return

	var character: Character = crew_members[crew_index]
	
	# Validate character before showing dialog
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Invalid character selected for captain assignment")
		_show_error_message("Cannot assign captain: Invalid character selected")
		return
	
	if not character.character_name or character.character_name.is_empty():
		push_error("CrewPanel: Cannot assign unnamed character as captain")
		_show_error_message("Cannot assign captain: Character must have a name")
		return
	
	# Don't show dialog if character is already captain
	if character == current_captain:
		_show_error_message("%s is already the captain" % character.character_name)
		return

	# Create a simple popup for captain assignment
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Make %s the captain?" % character.character_name
	confirmation.title = "Assign Captain"
	get_viewport().add_child(confirmation)

	confirmation.confirmed.connect(func(): _make_captain(character))
	confirmation.tree_exited.connect(func(): confirmation.queue_free())

	confirmation.popup_centered()

func _make_captain(character: Character) -> void:
	"""Make the specified character the captain with enhanced validation"""
	# Enhanced validation first
	if not character or not is_instance_valid(character):
		push_error("CrewPanel: Cannot assign invalid character as captain")
		_show_error_message("Cannot assign captain: Invalid character")
		return
	
	if not character.character_name or character.character_name.is_empty():
		push_error("CrewPanel: Cannot assign unnamed character as captain")
		_show_error_message("Cannot assign captain: Character must have a name")
		return
	
	if character not in crew_members:
		push_error("CrewPanel: Character not found in crew roster")
		_show_error_message("Cannot assign captain: Character not in crew")
		return

	# Remove captain status from previous captain with validation
	if current_captain and is_instance_valid(current_captain):
		current_captain.is_captain = false
		print("CrewPanel: Removed captain status from: ", current_captain.character_name)

	# Assign new captain
	current_captain = character
	character.is_captain = true

	print("CrewPanel: Successfully assigned captain: ", character.character_name)

	# Update display and notify
	_update_crew_list()
	crew_updated.emit(crew_members)

func get_captain() -> Character:
	"""Get the current captain"""
	return current_captain

func has_captain() -> bool:
	"""Check if a captain has been assigned"""
	return current_captain != null


func is_valid() -> bool:
	"""Enhanced validation for crew completeness"""
	return crew_members.size() >= selected_size and has_captain()

func validate() -> Array[String]:
	"""Validate crew data and return error messages"""
	var errors: Array[String] = []
	
	if crew_members.size() < selected_size:
		errors.append("Need %d more crew members" % (selected_size - crew_members.size()))
	
	if not has_captain():
		errors.append("Captain is required")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return get_crew_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("size"):
		selected_size = data.size
		_update_crew_size_selector()
	if data.has("members"):
		crew_members = data.members.duplicate()
		_update_crew_list()
	if data.has("captain"):
		current_captain = data.captain
		_update_crew_list()

func get_crew_summary() -> Dictionary:
	"""Get comprehensive crew summary for campaign integration"""
	var summary = {
		"total_members": crew_members.size(),
		"required_members": selected_size,
		"captain": _get_captain_summary(),
		"crew_list": _get_crew_member_summaries(),
		"average_combat": _calculate_average_stat("combat"),
		"average_toughness": _calculate_average_stat("toughness"),
		"total_health": _calculate_total_health(),
		"crew_backgrounds": _get_background_distribution(),
		"crew_motivations": _get_motivation_distribution(),
		"is_complete": is_valid(),
		"completion_percentage": float(crew_members.size()) / float(selected_size) * 100.0
	}
	return summary

func _get_captain_summary() -> Dictionary:
	"""Get captain information summary"""
	if not current_captain:
		return {"exists": false}

	return {
		"exists": true,
		"name": current_captain.character_name,
		"background": _get_background_display_name(current_captain.background),
		"motivation": _get_motivation_display_name(current_captain.motivation),
		"combat": current_captain.combat,
		"toughness": current_captain.toughness,
		"health": current_captain.max_health
	}

func _get_crew_member_summaries() -> Array:
	"""Get summary of all crew members"""
	var summaries: Array = []
	for character in crew_members:
		summaries.append({
			"name": character.character_name,
			"background": _get_background_display_name(character.background),
			"motivation": _get_motivation_display_name(character.motivation),
			"combat": character.combat,
			"toughness": character.toughness,
			"health": character.max_health,
			"is_captain": character == current_captain
		})
	return summaries

func _calculate_average_stat(stat_name: String) -> float:
	"""Calculate average value for a specific stat"""
	if crew_members.is_empty():
		return 0.0

	var total: int = 0
	for character in crew_members:
		match stat_name:
			"combat":
				total += character.combat
			"toughness":
				total += character.toughness
			"reaction":
				total += character.reaction
			"savvy":
				total += character.savvy
			"tech":
				total += character.tech
			"move":
				total += character.move

	return float(total) / float(crew_members.size())

func _calculate_total_health() -> int:
	"""Calculate total crew health"""
	var total: int = 0
	for character in crew_members:
		total += character.max_health if character.max_health > 0 else (character.toughness + 2)
	return total

func _get_background_distribution() -> Dictionary:
	"""Get distribution of crew backgrounds"""
	var distribution: Dictionary = {}
	for character in crew_members:
		var bg_name = _get_background_display_name(character.background)
		distribution[bg_name] = distribution.get(bg_name, 0) + 1
	return distribution

func _get_motivation_distribution() -> Dictionary:
	"""Get distribution of crew motivations"""
	var distribution: Dictionary = {}
	for character in crew_members:
		var mot_name = _get_motivation_display_name(character.motivation)
		distribution[mot_name] = distribution.get(mot_name, 0) + 1
	return distribution

func debug_crew_status():
	"""Debug method to print crew status"""
	print("=== CREW PANEL DEBUG ===")
	print("Crew members: ", crew_members.size(), "/", selected_size)
	print("Has captain: ", has_captain())
	print("Is valid: ", is_valid())
	if current_captain:
		print("Captain: ", current_captain.character_name)
	else:
		print("Captain: None assigned")

	var summary = get_crew_summary()
	print("Average combat: ", summary.average_combat)
	print("Total health: ", summary.total_health)
	print("Completion: ", summary.completion_percentage, "%")
	print("========================")

func _create_five_parsecs_character() -> void:
	"""Create a character using official Five Parsecs generation system"""
	# Use the sophisticated FiveParsecsCharacterGeneration system
	var character: Character = FiveParsecsCharacterGeneration.generate_random_character()

	if character:
		crew_members.append(character)
		print("CrewPanel: Generated Five Parsecs character: ", character.character_name)
	else:
		# Fallback to manual creation if needed
		_create_manual_character()

func _create_manual_character() -> void:
	"""Fallback manual character creation following Five Parsecs crew generation rules"""
	var character: Character = FiveParsecsCharacterGeneration.generate_random_character()
	crew_members.append(character)
	_update_crew_list()
	self.crew_updated.emit(crew_members)

func _generate_name_for_origin(origin: GlobalEnums.Origin) -> String:
	"""Generate appropriate names for different character origins"""
	match origin:
		GlobalEnums.Origin.HUMAN:
			var human_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn", "Taylor", "Blake"]
			return human_names[randi() % human_names.size()]
		GlobalEnums.Origin.ENGINEER:
			var engineer_names = ["Zyx-7", "Klet-Prime", "Vel-9", "Nix-Alpha", "Qor-Beta"]
			return engineer_names[randi() % engineer_names.size()]
		GlobalEnums.Origin.KERIN:
			var kerin_names = ["Thrakk", "Gorvak", "Zarneth", "Kromax", "Balthon"]
			return kerin_names[randi() % kerin_names.size()]
		GlobalEnums.Origin.SOULLESS:
			var soulless_names = ["Unit-47", "Nexus-12", "Prime-3", "Node-89", "Link-156"]
			return soulless_names[randi() % soulless_names.size()]
		GlobalEnums.Origin.PRECURSOR:
			var precursor_names = ["Ethereal-One", "Ancient-Sage", "Star-Walker", "Void-Singer", "Time-Keeper"]
			return precursor_names[randi() % precursor_names.size()]
		GlobalEnums.Origin.SWIFT:
			var swift_names = ["Chirp-Quick", "Dash-Wing", "Fleet-Scale", "Rapid-Tail", "Quick-Dart"]
			return swift_names[randi() % swift_names.size()]
		GlobalEnums.Origin.BOT:
			var bot_names = ["Bot-" + str(randi_range(100, 999)), "Droid-" + str(randi_range(10, 99)), "Mech-" + str(randi_range(1, 50))]
			return bot_names[randi() % bot_names.size()]
		_:
			return "Crew"

func _get_class_for_origin(origin: GlobalEnums.Origin) -> int:
	"""Get appropriate class for character origin"""
	match origin:
		GlobalEnums.Origin.ENGINEER:
			return GlobalEnums.CharacterClass.ENGINEER
		GlobalEnums.Origin.KERIN:
			return GlobalEnums.CharacterClass.SOLDIER
		GlobalEnums.Origin.SOULLESS:
			return GlobalEnums.CharacterClass.SECURITY
		GlobalEnums.Origin.PRECURSOR:
			return GlobalEnums.CharacterClass.PILOT
		GlobalEnums.Origin.FERAL:
			return GlobalEnums.CharacterClass.SECURITY
		GlobalEnums.Origin.SWIFT:
			return GlobalEnums.CharacterClass.PILOT
		GlobalEnums.Origin.BOT:
			return GlobalEnums.CharacterClass.BOT_TECH
		_:
			return GlobalEnums.CharacterClass.SOLDIER

func _update_crew_size_selector() -> void:
	"""Update the crew size selector to reflect the current selected_size"""
	if not crew_size_option:
		return
	
	# Find and select the appropriate crew size option
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == selected_size:
			crew_size_option.select(i)
			break

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
