class_name EquipmentGenerationScene
extends Control

## Isolated Equipment Generation Scene
## Fixes equipment generation crashes through proper error handling and validation
## Integrates with Campaign Creation State Bridge for modular architecture

# Safe imports with error boundaries
const Character = preload("res://src/core/character/Character.gd")
# GlobalEnums available as autoload singleton
const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")

# UI Components
@onready var crew_list: ItemList = get_node_or_null("MarginContainer/VBoxContainer/CrewSection/CrewList")
@onready var equipment_display: RichTextLabel = get_node_or_null("MarginContainer/VBoxContainer/EquipmentSection/EquipmentDisplay")
@onready var generate_button: Button = get_node_or_null("MarginContainer/VBoxContainer/ButtonSection/GenerateButton")
@onready var regenerate_button: Button = get_node_or_null("MarginContainer/VBoxContainer/ButtonSection/RegenerateButton")
@onready var finish_button: Button = get_node_or_null("MarginContainer/VBoxContainer/ButtonSection/FinishButton")
@onready var back_button: Button = get_node_or_null("MarginContainer/VBoxContainer/ButtonSection/BackButton")
@onready var progress_bar: ProgressBar = get_node_or_null("MarginContainer/VBoxContainer/HeaderSection/ProgressBar")
@onready var status_label: Label = get_node_or_null("MarginContainer/VBoxContainer/HeaderSection/StatusLabel")

# Equipment generation state
var crew_members: Array[Character] = []
var equipment_data: Dictionary = {}
var generation_in_progress: bool = false
var validation_errors: Array[String] = []

# System dependencies
var equipment_generator: Node = null
var dice_manager: Node = null
var state_bridge: Node = null

# Signals for campaign integration
signal equipment_generated(equipment_data: Dictionary)
signal equipment_generation_completed(equipment_data: Dictionary)
signal generation_cancelled()

func _ready() -> void:
	print("EquipmentGenerationScene: Initializing isolated equipment generation...")
	
	_setup_ui_components()
	_connect_signals()
	_initialize_dependencies()
	
	# Setup campaign integration
	call_deferred("setup_for_campaign_creation")

func _setup_ui_components() -> void:
	"""Setup UI components with safe defaults"""
	if status_label:
		status_label.text = "Equipment Generation Ready"
		status_label.modulate = Color.WHITE
	
	if progress_bar:
		progress_bar.value = 0
		progress_bar.visible = false
	
	if equipment_display:
		equipment_display.text = "Select crew members and generate equipment to begin."
	
	# Initially disable action buttons
	if generate_button:
		generate_button.disabled = true
	if regenerate_button:
		regenerate_button.disabled = true
	if finish_button:
		finish_button.disabled = true

func _connect_signals() -> void:
	"""Connect UI signals with error boundaries"""
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_pressed)
	if finish_button:
		finish_button.pressed.connect(_on_finish_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if crew_list:
		crew_list.item_selected.connect(_on_crew_member_selected)

func _initialize_dependencies() -> void:
	"""Initialize system dependencies with error handling"""
	# Get DiceManager
	dice_manager = get_node_or_null("/root/DiceManager")
	if not dice_manager:
		push_error("EquipmentGenerationScene: DiceManager not found - equipment generation will fail")
	
	# Try to get equipment generator from various possible locations
	equipment_generator = _find_equipment_generator()
	if not equipment_generator:
		push_warning("EquipmentGenerationScene: Equipment generator not found - will use fallback generation")

func _find_equipment_generator() -> Node:
	"""Find equipment generator from possible system locations"""
	var possible_paths = [
		"/root/SystemsAutoload",
		"/root/GameStateManagerAutoload",
		"/root/CoreSystemSetup"
	]
	
	for path in possible_paths:
		var system = get_node_or_null(path)
		if system and system.has_method("get_equipment_generator"):
			var generator = system.get_equipment_generator()
			if generator:
				print("EquipmentGenerationScene: Found equipment generator via ", path)
				return generator
		elif system and system.has_method("get_manager"):
			var generator = system.get_manager("EquipmentGenerator")
			if generator:
				print("EquipmentGenerationScene: Found equipment generator via manager system")
				return generator
	
	return null

## Campaign Creation State Bridge Integration

func setup_for_campaign_creation() -> void:
	"""Setup EquipmentGenerationScene for campaign creation workflow"""
	print("EquipmentGenerationScene: Setting up for campaign creation workflow")
	
	# Connect to campaign creation state bridge
	state_bridge = get_node_or_null("/root/CampaignCreationStateBridge")
	if state_bridge:
		print("EquipmentGenerationScene: Connected to CampaignCreationStateBridge")
		
		# Load crew data from campaign state
		_load_crew_from_campaign()
		
		# Connect our signals to the state bridge
		_connect_state_bridge_signals()
	else:
		push_warning("EquipmentGenerationScene: CampaignCreationStateBridge not found - operating in standalone mode")

func _connect_state_bridge_signals() -> void:
	"""Connect signals to state bridge"""
	if not state_bridge:
		return
	
	if not equipment_generation_completed.is_connected(_on_equipment_completed_for_campaign):
		equipment_generation_completed.connect(_on_equipment_completed_for_campaign)
	if not generation_cancelled.is_connected(_on_generation_cancelled_for_campaign):
		generation_cancelled.connect(_on_generation_cancelled_for_campaign)

func _load_crew_from_campaign() -> void:
	"""Load crew data from campaign creation state"""
	if not state_bridge or not state_bridge.has_method("get_campaign_data"):
		return
	
	var campaign_data = state_bridge.get_campaign_data()
	var crew_data = campaign_data.get("crew", {})
	var loaded_crew = crew_data.get("crew_members", [])
	
	if not loaded_crew.is_empty():
		print("EquipmentGenerationScene: Loading crew from campaign: %d members" % loaded_crew.size())
		
		crew_members.clear()
		for member in loaded_crew:
			if member is Character and _validate_character_for_equipment(member):
				crew_members.append(member)
			else:
				push_warning("EquipmentGenerationScene: Invalid crew member skipped during load")
		
		_update_crew_display()
		_update_generation_buttons()
		
		print("EquipmentGenerationScene: Successfully loaded %d valid crew members" % crew_members.size())
	else:
		print("EquipmentGenerationScene: No crew data found in campaign state")

## Equipment Generation Core Logic

func _validate_character_for_equipment(character: Character) -> bool:
	"""Validate character data before equipment generation"""
	if not character or not is_instance_valid(character):
		validation_errors.append("Invalid character object")
		return false
	
	# Check required character properties
	if not character.has_method("get") and not character.character_name:
		validation_errors.append("Character missing name")
		return false
	
	# Validate background enum (common source of crashes)
	var background = character.background if character.background != null else "MILITARY"
	if not _is_valid_background_enum(background):
		push_warning("EquipmentGenerationScene: Invalid background for %s, defaulting to MILITARY" % character.character_name)
		character.background = "MILITARY"
	
	# Validate character class enum
	var char_class = character.character_class if character.character_class != null else "SOLDIER"
	if not _is_valid_class_enum(char_class):
		push_warning("EquipmentGenerationScene: Invalid class for %s, defaulting to SOLDIER" % character.character_name)
		character.character_class = "SOLDIER"
	
	return true

func _is_valid_background_enum(background: Variant) -> bool:
	"""Validate background enum value"""
	if background is int:
		return background >= 0 and background < GlobalEnums.Background.size()
	return false

func _is_valid_class_enum(char_class: Variant) -> bool:
	"""Validate character class enum value"""
	if char_class is int:
		return char_class >= 0 and char_class < GlobalEnums.CharacterClass.size()
	return false

func generate_equipment_for_crew() -> Dictionary:
	"""Generate equipment for crew with comprehensive error handling"""
	if crew_members.is_empty():
		_show_error("No crew members available for equipment generation")
		return {}
	
	print("EquipmentGenerationScene: Starting equipment generation for %d crew members" % crew_members.size())
	
	generation_in_progress = true
	_update_generation_ui_state()
	validation_errors.clear()
	
	var generated_equipment = {}
	var successful_generations = 0
	
	for i in range(crew_members.size()):
		var character = crew_members[i]
		
		# Update progress
		if progress_bar:
			progress_bar.value = (float(i) / float(crew_members.size())) * 100.0
		
		# Validate character before generation
		if not _validate_character_for_equipment(character):
			push_warning("EquipmentGenerationScene: Skipping equipment generation for invalid character: %s" % character.character_name)
			continue
		
		# Generate equipment with error boundary
		var character_equipment = _generate_character_equipment_safe(character)
		if not character_equipment.is_empty():
			generated_equipment[character.character_name] = character_equipment
			successful_generations += 1
		else:
			validation_errors.append("Failed to generate equipment for " + character.character_name)
	
	# Update progress to complete
	if progress_bar:
		progress_bar.value = 100.0
	
	generation_in_progress = false
	equipment_data = generated_equipment
	
	print("EquipmentGenerationScene: Equipment generation completed - %d/%d successful" % [successful_generations, crew_members.size()])
	
	_update_generation_ui_state()
	_update_equipment_display()
	
	# Emit signal for integration
	equipment_generated.emit(equipment_data)
	
	return equipment_data

func _generate_character_equipment_safe(character: Character) -> Dictionary:
	"""Generate equipment for a single character with error handling"""
	var character_equipment = {}
	
	# Use equipment generator if available
	if equipment_generator and equipment_generator.has_method("generate_starting_equipment"):
		character_equipment = equipment_generator.generate_starting_equipment(character)
	else:
		# Fallback equipment generation
		character_equipment = _generate_fallback_equipment(character)
	
	print("EquipmentGenerationScene: Generated equipment for %s: %d items" % [character.character_name, character_equipment.size()])
	
	return character_equipment

func _generate_fallback_equipment(character: Character) -> Dictionary:
	"""Generate basic fallback equipment when main generation fails"""
	print("EquipmentGenerationScene: Using fallback equipment generation for %s" % character.character_name)
	
	var fallback_equipment = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"consumables": []
	}
	
	# Basic weapon based on character class - now using string comparison
	match character.character_class:
		"SOLDIER":
			fallback_equipment.weapons.append({"name": "Military Rifle", "type": "rifle", "damage": "1d6+1"})
		"SPECIALIST":
			fallback_equipment.weapons.append({"name": "Specialist Carbine", "type": "carbine", "damage": "1d6"})
		_:
			fallback_equipment.weapons.append({"name": "Basic Pistol", "type": "pistol", "damage": "1d6"})
	
	# Basic armor
	fallback_equipment.armor.append({"name": "Combat Armor", "protection": "+1", "weight": "light"})
	
	# Basic gear
	fallback_equipment.gear.append({"name": "Field Kit", "description": "Basic survival equipment"})
	
	return fallback_equipment

## UI Update Methods

func _update_crew_display() -> void:
	"""Update crew list display"""
	if not crew_list:
		return
	
	crew_list.clear()
	
	for character in crew_members:
		if character and is_instance_valid(character):
			var display_name = "%s (%s)" % [
				character.character_name,
				GlobalEnums.get_class_display_name(character.character_class)
			]
			crew_list.add_item(display_name)

func _update_equipment_display() -> void:
	"""Update equipment display with generated equipment"""
	if not equipment_display:
		return
	
	if equipment_data.is_empty():
		equipment_display.text = "No equipment generated yet."
		return
	
	var display_text = "[b]Generated Equipment:[/b]\n\n"
	
	for character_name in equipment_data:
		var char_equipment = equipment_data[character_name]
		display_text += "[b]%s:[/b]\n" % character_name
		
		# Display weapons
		if char_equipment.has("weapons") and not char_equipment.weapons.is_empty():
			display_text += "  [u]Weapons:[/u]\n"
			for weapon in char_equipment.weapons:
				display_text += "    - %s\n" % weapon.get("name", "Unknown Weapon")
		
		# Display armor
		if char_equipment.has("armor") and not char_equipment.armor.is_empty():
			display_text += "  [u]Armor:[/u]\n"
			for armor in char_equipment.armor:
				display_text += "    - %s\n" % armor.get("name", "Unknown Armor")
		
		# Display gear
		if char_equipment.has("gear") and not char_equipment.gear.is_empty():
			display_text += "  [u]Gear:[/u]\n"
			for gear in char_equipment.gear:
				display_text += "    - %s\n" % gear.get("name", "Unknown Gear")
		
		display_text += "\n"
	
	equipment_display.text = display_text

func _update_generation_buttons() -> void:
	"""Update button states based on current state"""
	if generate_button:
		generate_button.disabled = crew_members.is_empty() or generation_in_progress
	
	if regenerate_button:
		regenerate_button.disabled = equipment_data.is_empty() or generation_in_progress
	
	if finish_button:
		finish_button.disabled = equipment_data.is_empty() or generation_in_progress

func _update_generation_ui_state() -> void:
	"""Update UI state during generation"""
	if progress_bar:
		progress_bar.visible = generation_in_progress
	
	if status_label:
		if generation_in_progress:
			status_label.text = "Generating Equipment..."
			status_label.modulate = Color.YELLOW
		elif not equipment_data.is_empty():
			status_label.text = "Equipment Generation Complete"
			status_label.modulate = Color.GREEN
		else:
			status_label.text = "Equipment Generation Ready"
			status_label.modulate = Color.WHITE
	
	_update_generation_buttons()

func _show_error(message: String) -> void:
	"""Show error message to user"""
	push_error("EquipmentGenerationScene: " + message)
	
	if status_label:
		status_label.text = "Error: " + message
		status_label.modulate = Color.RED

## Signal Handlers

func _on_generate_pressed() -> void:
	"""Handle generate equipment button press"""
	print("EquipmentGenerationScene: Generate equipment requested")
	generate_equipment_for_crew()

func _on_regenerate_pressed() -> void:
	"""Handle regenerate equipment button press"""
	print("EquipmentGenerationScene: Regenerate equipment requested")
	equipment_data.clear()
	_update_equipment_display()
	generate_equipment_for_crew()

func _on_finish_pressed() -> void:
	"""Handle finish button press"""
	if equipment_data.is_empty():
		_show_error("No equipment generated - cannot finish")
		return
	
	print("EquipmentGenerationScene: Equipment generation completed with %d crew members" % equipment_data.size())
	equipment_generation_completed.emit(equipment_data)

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("EquipmentGenerationScene: Back button pressed")
	generation_cancelled.emit()

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		print("EquipmentGenerationScene: Selected crew member: %s" % character.character_name)

## Campaign Integration Handlers

func _on_equipment_completed_for_campaign(equipment_data: Dictionary) -> void:
	"""Handle equipment completion in campaign context"""
	print("EquipmentGenerationScene: Equipment completed for campaign")
	
	if state_bridge and state_bridge.has_method("handle_equipment_generation"):
		state_bridge.handle_equipment_generation(equipment_data)
		
		# Mark equipment generation as complete
		state_bridge.register_scene_completion("equipment_generation", true)
	
	# Navigate to next step in campaign creation
	_proceed_to_next_campaign_step()

func _on_generation_cancelled_for_campaign() -> void:
	"""Handle generation cancellation in campaign context"""
	print("EquipmentGenerationScene: Equipment generation cancelled for campaign")
	
	# Navigate back to previous step
	_return_to_previous_campaign_step()

func _proceed_to_next_campaign_step() -> void:
	"""Proceed to next step in campaign creation"""
	var scene_router = get_node_or_null("/root/SceneRouter")
	
	if state_bridge and scene_router:
		var next_scene = state_bridge.get_next_scene_in_flow("equipment_generation")
		
		if next_scene.is_empty():
			next_scene = "campaign_dashboard" # Default to dashboard
		
		print("EquipmentGenerationScene: Proceeding to next campaign step: ", next_scene)
		
		if scene_router.has_method("navigate_to"):
			scene_router.navigate_to(next_scene)
		else:
			state_bridge.transition_to_scene(next_scene)
	else:
		push_warning("EquipmentGenerationScene: Cannot proceed - state bridge or scene router not available")

func _return_to_previous_campaign_step() -> void:
	"""Return to previous step in campaign creation"""
	var scene_router = get_node_or_null("/root/SceneRouter")
	
	if state_bridge and scene_router:
		var previous_scene = state_bridge.get_previous_scene_in_flow("equipment_generation")
		
		if previous_scene.is_empty():
			previous_scene = "crew_creation" # Default back to crew creation
		
		print("EquipmentGenerationScene: Returning to previous campaign step: ", previous_scene)
		
		if scene_router.has_method("navigate_to"):
			scene_router.navigate_to(previous_scene)
		else:
			state_bridge.return_to_previous_scene()
	else:
		push_warning("EquipmentGenerationScene: Cannot return - state bridge or scene router not available")

## Public API

func set_crew_members(new_crew: Array) -> void:
	"""Set crew members for equipment generation"""
	crew_members.clear()
	for c in new_crew:
		if c is Character and _validate_character_for_equipment(c):
			crew_members.append(c)
	_update_crew_display()
	_update_generation_buttons()
	print("EquipmentGenerationScene: Set %d valid crew members" % crew_members.size())

func get_equipment_data() -> Dictionary:
	"""Get generated equipment data"""
	return equipment_data.duplicate()

func is_generation_complete() -> bool:
	"""Check if equipment generation is complete"""
	return not equipment_data.is_empty() and not generation_in_progress