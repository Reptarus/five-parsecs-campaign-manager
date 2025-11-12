class_name CaptainPanel
extends FiveParsecsCampaignPanel

## Enhanced Captain Creation Panel for Five Parsecs Campaign Manager
## Uses FiveParsecsCampaignPanel base class for proper integration
## Implements complete captain generation with Five Parsecs rules

# Captain-specific imports
const Character = preload("res://src/core/character/Character.gd")
const SimpleCharacterCreator = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")

# Captain-specific signals
signal captain_created(captain_data: Dictionary)
signal captain_customization_requested(captain: Character)
signal captain_data_updated(captain_data: Dictionary)
signal step_completed(step_name: String)

# State management
var captain: Character = null
var creation_method: String = ""
var captain_bonuses: Dictionary = {
	"leadership": 0,
	"experience": 100,
	"starting_gear": []
}

# UI References (safe access pattern with proper node paths)
@onready var captain_display_container: VBoxContainer = $"ContentMargin/MainContent/FormContent/FormContainer/Content"
@onready var main_form_container: VBoxContainer = $"ContentMargin/MainContent/FormContent/FormContainer/Content"

# UI Component references with unique names
@onready var captain_name_input: LineEdit = %CaptainNameInput
@onready var background_option: OptionButton = %BackgroundOption
@onready var motivation_option: OptionButton = %MotivationOption
@onready var advanced_creation_button: Button = %AdvancedCreationButton
@onready var continue_button: Button = %ContinueButton

var panel_data: Dictionary = {}
var character_creator: Node = null
var current_captain: Character = null

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info(
		"Captain Creation",
		"Create your ship's captain. Stats: Combat, Reactions, Toughness, Savvy, Tech, Move."
	)
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")
	
	# Validate node references
	_validate_node_references()
	
	print("CaptainPanel: Enhanced captain creation ready")

# PHASE 4 FIX: Override coordinator set callback to check access after coordinator is available
func _on_coordinator_set() -> void:
	"""Called when coordinator is set - now we can safely check coordinator access"""
	print("\n==== [PANEL: CaptainPanel] COORDINATOR ACCESS CHECK ====")
	
	var coordinator = get_coordinator()
	if coordinator:
		print("  ✅ Coordinator Access: true")
		print("    Coordinator Type: %s" % coordinator.get_class())
		print("    Has get_current_panel: %s" % coordinator.has_method("get_current_panel"))
		print("    Has set_current_panel: %s" % coordinator.has_method("set_current_panel"))
	else:
		# Try alternative methods to find coordinator
		var campaign_ui = owner if owner != null else get_parent().get_parent()
		var has_coordinator = campaign_ui != null and campaign_ui.has_method("get_coordinator")
		print("  ⚠️  Coordinator Access: false")
		print("    Fallback check via owner: %s" % has_coordinator)
		if has_coordinator:
			var fallback_coord = campaign_ui.get_coordinator()
			print("    Fallback coordinator available: %s" % (fallback_coord != null))

func _validate_node_references() -> void:
	"""Validate all critical node references are available"""
	if OS.is_debug_build():
		assert(main_form_container != null, "main_form_container not found - check scene structure")
		if character_creator == null:
			push_warning("CaptainPanel: character_creator not found - advanced creation disabled")
		print("CaptainPanel: Node references validated")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup captain-specific content"""
	_create_captain_interface()
	_setup_ui()
	_connect_signals()
	_initialize_character_creator()

func _create_captain_interface() -> void:
	"""Create comprehensive captain creation interface using base panel structure"""
	if not content_container:
		push_error("CaptainPanel: FormContainer not found in base panel")
		return
	
	var main_container = VBoxContainer.new()
	main_container.name = "CaptainCreationContainer"
	content_container.add_child(main_container)
	
	# Creation method selection
	_add_creation_methods(main_container)
	
	# Captain preview area
	_add_captain_preview(main_container)
	
	# Advanced options
	_add_advanced_options(main_container)

func _add_creation_methods(container: VBoxContainer) -> void:
	"""Add captain creation method buttons"""
	var methods_label = Label.new()
	methods_label.text = "Choose Captain Creation Method:"
	methods_label.add_theme_font_size_override("font_size", 16)
	container.add_child(methods_label)
	
	var button_container = GridContainer.new()
	button_container.columns = 2
	container.add_child(button_container)
	
	var methods = [
		{
			"id": "random",
			"text": "Random Captain",
			"tooltip": "Generate a captain with random stats and background",
			"method": "_generate_random_captain"
		},
		{
			"id": "custom",
			"text": "Custom Build",
			"tooltip": "Manually allocate stats and choose background",
			"method": "_create_custom_captain"
		},
		{
			"id": "veteran",
			"text": "Veteran Template",
			"tooltip": "Start with an experienced captain template",
			"method": "_use_veteran_template"
		},
		{
			"id": "import",
			"text": "Import Character",
			"tooltip": "Import an existing character as captain",
			"method": "_import_character"
		}
	]
	
	for method_data in methods:
		var btn = Button.new()
		btn.text = method_data.text
		btn.tooltip_text = method_data.tooltip
		btn.custom_minimum_size.x = 150
		btn.pressed.connect(Callable(self, method_data.method))
		button_container.add_child(btn)

func _add_captain_preview(container: VBoxContainer) -> void:
	"""Add captain preview display area"""
	var preview_label = Label.new()
	preview_label.text = "Captain Preview:"
	preview_label.add_theme_font_size_override("font_size", 16)
	container.add_child(preview_label)
	
	captain_display_container = VBoxContainer.new()
	captain_display_container.name = "CaptainDisplay"
	container.add_child(captain_display_container)
	
	# Initial empty state
	var empty_label = Label.new()
	empty_label.text = "Choose a creation method to generate your captain"
	empty_label.modulate = Color.GRAY
	captain_display_container.add_child(empty_label)

func _add_advanced_options(container: VBoxContainer) -> void:
	"""Add advanced captain options"""
	var advanced_label = Label.new()
	advanced_label.text = "Advanced Options:"
	container.add_child(advanced_label)
	
	var options_container = HBoxContainer.new()
	container.add_child(options_container)
	
	# Leadership bonus
	var leadership_check = CheckBox.new()
	leadership_check.text = "Natural Leader (+1 to crew morale)"
	leadership_check.toggled.connect(_on_leadership_toggled)
	options_container.add_child(leadership_check)
	
	# Extra experience
	var xp_container = HBoxContainer.new()
	options_container.add_child(xp_container)
	
	var xp_label = Label.new()
	xp_label.text = "Starting XP:"
	xp_container.add_child(xp_label)
	
	var xp_spin = SpinBox.new()
	xp_spin.min_value = 100
	xp_spin.max_value = 500
	xp_spin.value = 100
	xp_spin.step = 50
	xp_spin.value_changed.connect(_on_xp_changed)
	xp_container.add_child(xp_spin)

func _setup_ui() -> void:
	# Original setup preserved for compatibility
	_setup_background_options()
	_setup_motivation_options()

func _setup_background_options() -> void:
	"""Setup background options from Five Parsecs rules"""
	if not background_option:
		return
	
	background_option.clear()
	
	# Five Parsecs Background Table (from core rules)
	var backgrounds = [
		{"name": "Peaceful, High-Tech Colony", "bonus": {"savvy": 1}, "credits": "1D6"},
		{"name": "Giant, Overcrowded, Dystopian City", "bonus": {"speed": 1}},
		{"name": "Low-Tech Colony", "gear": ["Low-tech Weapon"]},
		{"name": "Mining Colony", "bonus": {"toughness": 1}},
		{"name": "Military Brat", "bonus": {"combat": 1}},
		{"name": "Space Station", "gear": ["Gear"]},
		{"name": "Military Outpost", "bonus": {"reactions": 1}},
		{"name": "Drifter", "gear": ["Gear"]},
		{"name": "Lower Megacity Class", "gear": ["Low-tech Weapon"]},
		{"name": "Wealthy Merchant Family", "credits": "2D6"},
		{"name": "Frontier Gang", "bonus": {"combat": 1}},
		{"name": "Religious Cult", "patron": true, "story_points": 1},
		{"name": "War-Torn Hell-Hole", "bonus": {"reactions": 1}, "gear": ["Military Weapon"]},
		{"name": "Tech Guild", "bonus": {"savvy": 1}, "credits": "1D6", "gear": ["High-tech Weapon"]},
		{"name": "Subjugated Colony on Alien World", "gear": ["Gadget"]},
		{"name": "Long-Term Space Mission", "bonus": {"savvy": 1}},
		{"name": "Research Outpost", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"name": "Primitive or Regressed World", "bonus": {"toughness": 1}, "gear": ["Low-tech Weapon"]},
		{"name": "Orphan Utility Program", "patron": true, "story_points": 1},
		{"name": "Isolationist Enclave", "rumors": 2},
		{"name": "Comfortable Megacity Class", "credits": "1D6"},
		{"name": "Industrial World", "gear": ["Gear"]},
		{"name": "Bureaucrat", "credits": "1D6"},
		{"name": "Wasteland Nomads", "bonus": {"reactions": 1}, "gear": ["Low-tech Weapon"]},
		{"name": "Alien Culture", "gear": ["High-tech Weapon"]}
	]
	
	for i in range(backgrounds.size()):
		var background = backgrounds[i]
		background_option.add_item(background.name, i)
	
	background_option.select(0) # Default to first option

func _setup_motivation_options() -> void:
	"""Setup motivation options from Five Parsecs rules"""
	if not motivation_option:
		return
	
	motivation_option.clear()
	
	# Five Parsecs Motivation Table (from core rules)
	var motivations = [
		{"name": "Wealth", "credits": "1D6"},
		{"name": "Fame", "story_points": 1},
		{"name": "Glory", "bonus": {"combat": 1}, "gear": ["Military Weapon"]},
		{"name": "Survival", "bonus": {"toughness": 1}},
		{"name": "Escape", "bonus": {"speed": 1}},
		{"name": "Adventure", "credits": "1D6", "gear": ["Low-tech Weapon"]},
		{"name": "Truth", "rumors": 1, "story_points": 1},
		{"name": "Technology", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"name": "Discovery", "bonus": {"savvy": 1}, "gear": ["Gear"]},
		{"name": "Loyalty", "patron": true, "story_points": 1},
		{"name": "Revenge", "xp_bonus": 2, "rival": true},
		{"name": "Romance", "rumors": 1, "story_points": 1},
		{"name": "Faith", "rumors": 1, "story_points": 1},
		{"name": "Political", "patron": true, "story_points": 1},
		{"name": "Power", "xp_bonus": 2, "rival": true},
		{"name": "Order", "patron": true, "story_points": 1},
		{"name": "Freedom", "xp_bonus": 2}
	]
	
	for i in range(motivations.size()):
		var motivation = motivations[i]
		motivation_option.add_item(motivation.name, i)
	
	motivation_option.select(0) # Default to first option

func _connect_signals() -> void:
	if captain_name_input:
		captain_name_input.text_changed.connect(_on_captain_name_changed)
	if background_option:
		background_option.item_selected.connect(_on_background_changed)
	if motivation_option:
		motivation_option.item_selected.connect(_on_motivation_changed)
	if continue_button and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if advanced_creation_button and not advanced_creation_button.pressed.is_connected(_on_advanced_creation_pressed):
		advanced_creation_button.pressed.connect(_on_advanced_creation_pressed)

func _initialize_character_creator() -> void:
	"""Initialize character creator for advanced captain creation"""
	print("CaptainPanel: Starting character creator initialization")
	
	# Try to load the SimpleCharacterCreator scene
	var character_creator_scene = preload("res://src/ui/screens/character/SimpleCharacterCreator.tscn")
	print("CaptainPanel: Scene preloaded: ", character_creator_scene != null)
	
	if character_creator_scene:
		character_creator = character_creator_scene.instantiate()
		print("CaptainPanel: Scene instantiated: ", character_creator != null)
		
		if character_creator:
			print("CaptainPanel: Character creator class: ", character_creator.get_class())
			print("CaptainPanel: Character creator script: ", character_creator.get_script())
			
			# Add as child but keep hidden
			add_child(character_creator)
			character_creator.visible = false
			
			# Connect character creator signals
			if character_creator.has_signal("character_created"):
				character_creator.character_created.connect(_on_character_created)
				print("CaptainPanel: Connected character_created signal")
			if character_creator.has_signal("character_edited"):
				character_creator.character_edited.connect(_on_character_edited)
				print("CaptainPanel: Connected character_edited signal")
			if character_creator.has_signal("creation_cancelled"):
				character_creator.creation_cancelled.connect(_on_character_creation_cancelled)
				print("CaptainPanel: Connected creation_cancelled signal")
			
			print("CaptainPanel: Character creator initialized successfully")
		else:
			push_warning("CaptainPanel: Failed to instantiate character creator")
	else:
		push_warning("CaptainPanel: Character creator scene not found")

func _on_captain_name_changed(new_text: String) -> void:
	panel_data["captain_name"] = new_text
	
	# Create captain object if it doesn't exist to enable validation
	if not current_captain:
		current_captain = Character.new()
		current_captain.is_captain = true
	current_captain.character_name = new_text
	
	panel_data_changed.emit(get_panel_data())

func _on_background_changed(index: int) -> void:
	"""Handle background selection with Five Parsecs rules"""
	var backgrounds = [
		{"id": "peaceful_high_tech", "name": "Peaceful, High-Tech Colony", "bonus": {"savvy": 1}, "credits": "1D6"},
		{"id": "dystopian_city", "name": "Giant, Overcrowded, Dystopian City", "bonus": {"speed": 1}},
		{"id": "low_tech_colony", "name": "Low-Tech Colony", "gear": ["Low-tech Weapon"]},
		{"id": "mining_colony", "name": "Mining Colony", "bonus": {"toughness": 1}},
		{"id": "military_brat", "name": "Military Brat", "bonus": {"combat": 1}},
		{"id": "space_station", "name": "Space Station", "gear": ["Gear"]},
		{"id": "military_outpost", "name": "Military Outpost", "bonus": {"reactions": 1}},
		{"id": "drifter", "name": "Drifter", "gear": ["Gear"]},
		{"id": "lower_megacity", "name": "Lower Megacity Class", "gear": ["Low-tech Weapon"]},
		{"id": "wealthy_merchant", "name": "Wealthy Merchant Family", "credits": "2D6"},
		{"id": "frontier_gang", "name": "Frontier Gang", "bonus": {"combat": 1}},
		{"id": "religious_cult", "name": "Religious Cult", "patron": true, "story_points": 1},
		{"id": "war_torn", "name": "War-Torn Hell-Hole", "bonus": {"reactions": 1}, "gear": ["Military Weapon"]},
		{"id": "tech_guild", "name": "Tech Guild", "bonus": {"savvy": 1}, "credits": "1D6", "gear": ["High-tech Weapon"]},
		{"id": "alien_colony", "name": "Subjugated Colony on Alien World", "gear": ["Gadget"]},
		{"id": "space_mission", "name": "Long-Term Space Mission", "bonus": {"savvy": 1}},
		{"id": "research_outpost", "name": "Research Outpost", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"id": "primitive_world", "name": "Primitive or Regressed World", "bonus": {"toughness": 1}, "gear": ["Low-tech Weapon"]},
		{"id": "orphan_program", "name": "Orphan Utility Program", "patron": true, "story_points": 1},
		{"id": "isolationist", "name": "Isolationist Enclave", "rumors": 2},
		{"id": "comfortable_megacity", "name": "Comfortable Megacity Class", "credits": "1D6"},
		{"id": "industrial_world", "name": "Industrial World", "gear": ["Gear"]},
		{"id": "bureaucrat", "name": "Bureaucrat", "credits": "1D6"},
		{"id": "wasteland_nomads", "name": "Wasteland Nomads", "bonus": {"reactions": 1}, "gear": ["Low-tech Weapon"]},
		{"id": "alien_culture", "name": "Alien Culture", "gear": ["High-tech Weapon"]}
	]
	
	if index >= 0 and index < backgrounds.size():
		var background = backgrounds[index]
		panel_data["captain_background"] = background.id
		panel_data["captain_background_name"] = background.name
		panel_data["captain_background_data"] = background
		
		# Update captain object if it exists
		if current_captain:
			current_captain.background = background.id
		
		print("CaptainPanel: Selected background: %s" % background.name)
		panel_data_changed.emit(get_panel_data())

func _on_motivation_changed(index: int) -> void:
	"""Handle motivation selection with Five Parsecs rules"""
	var motivations = [
		{"id": "wealth", "name": "Wealth", "credits": "1D6"},
		{"id": "fame", "name": "Fame", "story_points": 1},
		{"id": "glory", "name": "Glory", "bonus": {"combat": 1}, "gear": ["Military Weapon"]},
		{"id": "survival", "name": "Survival", "bonus": {"toughness": 1}},
		{"id": "escape", "name": "Escape", "bonus": {"speed": 1}},
		{"id": "adventure", "name": "Adventure", "credits": "1D6", "gear": ["Low-tech Weapon"]},
		{"id": "truth", "name": "Truth", "rumors": 1, "story_points": 1},
		{"id": "technology", "name": "Technology", "bonus": {"savvy": 1}, "gear": ["Gadget"]},
		{"id": "discovery", "name": "Discovery", "bonus": {"savvy": 1}, "gear": ["Gear"]},
		{"id": "loyalty", "name": "Loyalty", "patron": true, "story_points": 1},
		{"id": "revenge", "name": "Revenge", "xp_bonus": 2, "rival": true},
		{"id": "romance", "name": "Romance", "rumors": 1, "story_points": 1},
		{"id": "faith", "name": "Faith", "rumors": 1, "story_points": 1},
		{"id": "political", "name": "Political", "patron": true, "story_points": 1},
		{"id": "power", "name": "Power", "xp_bonus": 2, "rival": true},
		{"id": "order", "name": "Order", "patron": true, "story_points": 1},
		{"id": "freedom", "name": "Freedom", "xp_bonus": 2}
	]
	
	if index >= 0 and index < motivations.size():
		var motivation = motivations[index]
		panel_data["captain_motivation"] = motivation.id
		panel_data["captain_motivation_name"] = motivation.name
		panel_data["captain_motivation_data"] = motivation
		
		# Update captain object if it exists
		if current_captain:
			current_captain.motivation = motivation.id
		
		print("CaptainPanel: Selected motivation: %s" % motivation.name)
		panel_data_changed.emit(get_panel_data())

func _on_continue_pressed() -> void:
	print("CaptainPanel: Continue button pressed")
	_validate_and_complete()

func _on_advanced_creation_pressed() -> void:
	"""Enhanced advanced creation with comprehensive error handling and null safety"""
	print("CaptainPanel: Advanced creation button pressed")
	
	# Validate critical dependencies with specific error messaging
	if not character_creator:
		push_error("CaptainPanel: Character creator not initialized - cannot start advanced creation")
		_show_error_fallback("Character creator unavailable. Please try reloading the panel.")
		return
	
	# Use null-safe container reference with multiple fallback strategies
	var form_container = main_form_container
	if not form_container or not is_instance_valid(form_container):
		# Fallback 1: Try alternative node paths
		var fallback_paths = [
			"ContentMargin/MainContent/FormContent/FormContainer/Content",
			"Content",
			"FormContainer/Content"
		]
		
		for path in fallback_paths:
			form_container = get_node_or_null(path)
			if form_container and is_instance_valid(form_container):
				print("CaptainPanel: Found form container via fallback path: %s" % path)
				break
		
		# Fallback 2: Hide individual elements if no container found
		if not form_container:
			push_warning("CaptainPanel: No form container found - using individual element strategy")
			_hide_form_elements_individually()
		else:
			form_container.visible = false
	else:
		form_container.visible = false
	
	# Initialize character creator with validation and error recovery
	character_creator.visible = true
	print("CaptainPanel: Initializing character creator...")
	
	# Prepare captain data with validation
	var captain_data = null
	if current_captain and is_instance_valid(current_captain):
		if current_captain.has_method("to_dictionary"):
			captain_data = current_captain.to_dictionary()
			print("CaptainPanel: Passing existing captain data for editing")
		else:
			push_warning("CaptainPanel: Current captain exists but lacks serialization method")
	
	# Execute character creation with comprehensive error handling
	var creation_success = false
	
	# Use Godot's error handling pattern
	if character_creator.has_method("start_creation"):
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN)
		if captain_data:
			# Pass existing data for editing if available
			if character_creator.has_method("load_character_data"):
				character_creator.load_character_data(captain_data)
			elif character_creator.has_method("edit_character") and current_captain:
				character_creator.edit_character(current_captain)
		creation_success = true
		print("CaptainPanel: Advanced creation started successfully")
	else:
		push_error("CaptainPanel: Character creator missing start_creation method")
		creation_success = false
	
	# Handle creation failure with graceful recovery
	if not creation_success:
		_restore_simple_form()
		_show_error_fallback("Advanced creation failed. Falling back to simple form.")

func _hide_form_elements_individually() -> void:
	"""Fallback strategy: Hide form elements when container is unavailable"""
	var elements_to_hide = [
		captain_name_input,
		background_option,
		motivation_option,
		advanced_creation_button,
		continue_button
	]
	
	var hidden_count = 0
	for element in elements_to_hide:
		if element and is_instance_valid(element):
			element.visible = false
			hidden_count += 1
	
	print("CaptainPanel: Hidden %d form elements individually" % hidden_count)

func _restore_simple_form() -> void:
	"""Restore simple form with comprehensive error recovery"""
	print("CaptainPanel: Restoring simple form visibility")
	
	# Try to restore main container first
	var form_container = main_form_container
	if form_container and is_instance_valid(form_container):
		form_container.visible = true
	else:
		# Fallback: show individual elements
		print("CaptainPanel: Using individual element restoration")
		_show_form_elements_individually()
	
	# Safely hide character creator
	if character_creator and is_instance_valid(character_creator):
		character_creator.visible = false

func _show_form_elements_individually() -> void:
	"""Fallback strategy: Show form elements when container is unavailable"""
	var elements_to_show = [
		captain_name_input,
		background_option,
		motivation_option,
		advanced_creation_button,
		continue_button
	]
	
	var shown_count = 0
	for element in elements_to_show:
		if element and is_instance_valid(element):
			element.visible = true
			shown_count += 1
	
	print("CaptainPanel: Showed %d form elements individually" % shown_count)

func _show_error_fallback(message: String) -> void:
	"""Display error message with multiple notification strategies"""
	print("CaptainPanel: Error fallback - %s" % message)
	
	# Strategy 1: Use validation_failed signal if available
	if has_signal("validation_failed"):
		validation_failed.emit(["Advanced creation error: " + message])
	
	# Strategy 2: Use validation_failed signal if available (from base panel)
	if has_signal("validation_failed"):
		validation_failed.emit([message])
	
	# Strategy 3: Fallback to console warning
	push_warning("CaptainPanel: " + message)

func _on_character_created(character: Character) -> void:
	"""Handle character creation completion"""
	print("CaptainPanel: Character created: %s" % character.character_name)
	current_captain = character
	
	# Update panel data with character info
	panel_data["captain_character"] = character
	panel_data["captain_name"] = character.character_name
	
	# Hide character creator and show simple form
	character_creator.visible = false
	main_form_container.visible = true
	
	# Update UI with character data
	_update_ui_from_character()
	
	# Emit data change
	panel_data_changed.emit(get_panel_data())

func _on_character_edited(character: Character) -> void:
	"""Handle character editing completion"""
	print("CaptainPanel: Character edited: %s" % character.character_name)
	current_captain = character
	
	# Update panel data
	panel_data["captain_character"] = character
	panel_data["captain_name"] = character.character_name
	
	# Hide character creator and show simple form
	character_creator.visible = false
	main_form_container.visible = true
	
	# Update UI with character data
	_update_ui_from_character()
	
	# Emit data change
	panel_data_changed.emit(get_panel_data())

func _on_character_creation_cancelled() -> void:
	"""Handle character creation cancellation"""
	print("CaptainPanel: Character creation cancelled")
	
	# Hide character creator and show simple form
	character_creator.visible = false
	main_form_container.visible = true

func _update_ui_from_character() -> void:
	"""Update UI elements with character data"""
	if not current_captain:
		return
	
	# Update name input
	if captain_name_input:
		captain_name_input.text = current_captain.character_name
	
	# Update background and motivation if available
	if current_captain.has_method("get_background"):
		var background = current_captain.get_background()
		var backgrounds = ["SOLDIER", "SCOUT", "SCOUNDREL", "SCHOLAR", "SCIENTIST", "STRANGE"]
		var index = backgrounds.find(background)
		if index >= 0 and background_option:
			background_option.select(index)
	
	if current_captain.has_method("get_motivation"):
		var motivation = current_captain.get_motivation()
		var motivations = ["REVENGE", "WEALTH", "KNOWLEDGE", "POWER", "SURVIVAL"]
		var index = motivations.find(motivation)
		if index >= 0 and motivation_option:
			motivation_option.select(index)

func _validate_and_complete() -> void:
	"""Validate captain data and complete step"""
	var errors = []
	
	# Check if we have a captain (either from simple form or character creator)
	if not current_captain and panel_data.get("captain_name", "").strip_edges().is_empty():
		errors.append("Captain name is required")
	
	# If we have a character creator captain, use that
	if current_captain:
		panel_data["captain_character"] = current_captain
		panel_data["captain_name"] = current_captain.character_name
		print("CaptainPanel: Using character creator captain")
	elif not panel_data.get("captain_name", "").strip_edges().is_empty():
		# Create a basic captain from form data
		_create_basic_captain()
		print("CaptainPanel: Created basic captain from form")
	
	if errors.is_empty():
		print("CaptainPanel: Captain validation passed")
		panel_completed.emit(get_panel_data())
	else:
		print("CaptainPanel: Captain validation failed: %s" % str(errors))
		# Could show errors in UI here

func _create_basic_captain() -> void:
	"""Create a basic captain from form data with Five Parsecs rules"""
	var Character = preload("res://src/core/character/Character.gd")
	current_captain = Character.new()
	
	# Set basic properties from form
	current_captain.character_name = panel_data.get("captain_name", "Captain")
	current_captain.background = panel_data.get("captain_background", "military_brat")
	current_captain.motivation = panel_data.get("captain_motivation", "revenge")
	
	# Generate base stats using Five Parsecs method (2d6/3 rounded up)
	current_captain.combat = _generate_five_parsecs_stat()
	current_captain.toughness = _generate_five_parsecs_stat()
	current_captain.savvy = _generate_five_parsecs_stat()
	current_captain.tech = _generate_five_parsecs_stat()
	current_captain.speed = _generate_five_parsecs_stat()
	current_captain.reactions = _generate_five_parsecs_stat()
	current_captain.luck = 2 # Captains start with 2 luck
	
	# Apply background bonuses
	_apply_background_bonuses(current_captain)
	
	# Apply motivation bonuses
	_apply_motivation_bonuses(current_captain)
	
	# Set health based on toughness (Five Parsecs rules)
	current_captain.max_health = current_captain.toughness + 3 # Captains get +1 extra
	current_captain.health = current_captain.max_health
	
	# Store captain data
	panel_data["captain_character"] = current_captain
	panel_data["captain_stats"] = {
		"combat": current_captain.combat,
		"toughness": current_captain.toughness,
		"savvy": current_captain.savvy,
		"tech": current_captain.tech,
		"speed": current_captain.speed,
		"reactions": current_captain.reactions,
		"luck": current_captain.luck,
		"health": current_captain.health,
		"max_health": current_captain.max_health
	}
	
	print("CaptainPanel: Created captain with stats: %s" % str(panel_data["captain_stats"]))

func _generate_five_parsecs_stat() -> int:
	"""Generate a stat using Five Parsecs method (2d6/3 rounded up)"""
	var roll = _roll_2d6()
	return ceili(float(roll) / 3.0)

func _apply_background_bonuses(character: Character) -> void:
	"""Apply background bonuses from Five Parsecs rules"""
	var background_data = panel_data.get("captain_background_data", {})
	var bonuses = background_data.get("bonus", {})
	
	for stat in bonuses:
		var bonus_value = bonuses[stat]
		match stat:
			"combat":
				character.combat += bonus_value
			"toughness":
				character.toughness += bonus_value
			"savvy":
				character.savvy += bonus_value
			"tech":
				character.tech += bonus_value
			"speed":
				character.speed += bonus_value
			"reactions":
				character.reactions += bonus_value
	
	print("CaptainPanel: Applied background bonuses: %s" % str(bonuses))

func _apply_motivation_bonuses(character: Character) -> void:
	"""Apply motivation bonuses from Five Parsecs rules"""
	var motivation_data = panel_data.get("captain_motivation_data", {})
	var bonuses = motivation_data.get("bonus", {})
	
	for stat in bonuses:
		var bonus_value = bonuses[stat]
		match stat:
			"combat":
				character.combat += bonus_value
			"toughness":
				character.toughness += bonus_value
			"savvy":
				character.savvy += bonus_value
			"tech":
				character.tech += bonus_value
			"speed":
				character.speed += bonus_value
			"reactions":
				character.reactions += bonus_value
	
	print("CaptainPanel: Applied motivation bonuses: %s" % str(bonuses))

func _roll_2d6() -> int:
	"""Roll 2d6 for Five Parsecs stats"""
	return randi_range(1, 6) + randi_range(1, 6)

func _update_ui_from_data() -> void:
	if captain_name_input and panel_data.has("captain_name"):
		captain_name_input.text = panel_data["captain_name"]
	
	if background_option and panel_data.has("captain_background"):
		var backgrounds = ["SOLDIER", "SCOUT", "SCOUNDREL", "SCHOLAR", "SCIENTIST", "STRANGE"]
		var index = backgrounds.find(panel_data["captain_background"])
		if index >= 0:
			background_option.select(index)
	
	if motivation_option and panel_data.has("captain_motivation"):
		var motivations = ["REVENGE", "WEALTH", "KNOWLEDGE", "POWER", "SURVIVAL"]
		var index = motivations.find(panel_data["captain_motivation"])
		if index >= 0:
			motivation_option.select(index)
	
	# Restore character if available
	if panel_data.has("captain_character") and panel_data["captain_character"]:
		current_captain = panel_data["captain_character"]
		_update_ui_from_character()

func cleanup_panel() -> void:
	"""Clean up panel state when navigating away"""
	print("CaptainPanel: Cleaning up panel state")
	
	# Clear character creator
	if character_creator:
		if character_creator.has_method("cleanup"):
			character_creator.cleanup()
		character_creator.visible = false
	
	# Reset panel data
	panel_data = {
		"captain_name": "",
		"captain_background": "",
		"captain_motivation": "",
		"captain_character": null,
		"captain_stats": {},
		"is_complete": false
	}
	
	# Clear current captain
	current_captain = null
	
	# Reset UI components if available
	if captain_name_input:
		captain_name_input.text = ""
	if background_option:
		background_option.select(0)
	if motivation_option:
		motivation_option.select(0)
	
	# Show simple form, hide character creator
	if main_form_container:
		main_form_container.visible = true
	if character_creator:
		character_creator.visible = false
	
	print("CaptainPanel: Panel cleanup completed")

# Enhanced Captain Generation Methods - Production Ready
func _generate_random_captain() -> void:
	"""Generate random captain with Five Parsecs rules and captain bonuses"""
	creation_method = "random"
	
	captain = Character.new()
	
	# Five Parsecs captain generation (enhanced stats)
	captain.character_name = _generate_captain_name()
	captain.combat = _roll_captain_stat() + 1 # Captain bonus
	captain.reactions = _roll_captain_stat() + 1 # Captain bonus
	captain.toughness = _roll_captain_stat()
	captain.savvy = _roll_captain_stat() + 1 # Captain bonus
	captain.tech = _roll_captain_stat()
	captain.speed = 4 # Standard movement
	captain.luck = 2 # Captain gets extra luck
	
	# Set captain-specific properties
	captain.is_captain = true
	captain.experience = captain_bonuses.experience
	
	# Generate background and motivation using existing system
	_apply_background_and_motivation()
	
	# Update display
	_update_captain_display()
	
	# COMPREHENSIVE DEBUG OUTPUT - Captain Data Creation
	print("\n==== [PANEL: CaptainPanel] CAPTAIN DATA CREATED ====")
	print("  Panel Phase: 2 of 7 (Captain Creation)")
	print("  Creation Method: %s" % creation_method)
	print("  === CAPTAIN DATA BEING SAVED ===")
	print("    Captain Name: '%s'" % captain.character_name)
	print("    Stats: Combat:%d Reactions:%d Toughness:%d Savvy:%d Tech:%d Move:%d" % [
		captain.combat, captain.reactions, captain.toughness, captain.savvy, captain.tech, captain.move
	])
	print("    Experience: %d XP" % captain.experience)
	print("    Background: '%s'" % captain.background)
	print("    Motivation: '%s'" % captain.motivation)
	print("    Is Captain: %s" % captain.is_captain)
	print("    Captain Bonuses: %s" % captain_bonuses)
	
	var panel_data_result = get_panel_data()
	print("  === FORMATTED PANEL DATA ===")
	print("    Panel Data Keys: %s" % str(panel_data_result.keys()))
	print("    Is Complete: %s" % panel_data_result.get("is_complete", false))
	print("    Validation Status: %s" % validate_panel())
	
	# Emit both data changed and captain created signals
	panel_data_changed.emit(panel_data_result)
	captain_created.emit(panel_data_result)
	captain_data_updated.emit(panel_data_result)
	
	print("  === SIGNAL EMISSIONS ===")
	print("    panel_data_changed signal emitted")
	print("    captain_created signal emitted")
	print("    captain_data_updated signal emitted")
	print("==== [PANEL: CaptainPanel] CAPTAIN CREATION COMPLETE ====\n")
	
	print("CaptainPanel: Random captain generated - %s" % captain.character_name)

func _use_veteran_template() -> void:
	"""Apply veteran captain template with superior stats"""
	creation_method = "veteran"
	
	captain = Character.new()
	captain.character_name = _generate_captain_name()
	
	# Veteran stats (higher baseline for experienced captains)
	captain.combat = 4
	captain.reactions = 4
	captain.toughness = 3
	captain.savvy = 5 # High savvy for leadership
	captain.tech = 3
	captain.speed = 4
	captain.luck = 3 # Higher luck from experience
	
	# Veteran bonuses
	captain.is_captain = true
	captain.experience = 250 # More starting XP
	captain.skills = ["Leadership", "Tactics", "Negotiation"]
	
	_update_captain_display()
	
	# Emit both data changed and captain created signals
	panel_data_changed.emit(get_panel_data())
	captain_created.emit(get_panel_data())
	captain_data_updated.emit(get_panel_data())
	
	print("CaptainPanel: Veteran captain created - %s" % captain.character_name)

func _create_custom_captain() -> void:
	"""Open custom captain builder interface"""
	creation_method = "custom"
	push_warning("CaptainPanel: Custom captain builder will be implemented in next phase")

func _import_character() -> void:
	"""Import existing character as captain"""
	creation_method = "import"
	push_warning("CaptainPanel: Character import will be implemented in next phase")

func _roll_captain_stat() -> int:
	"""Roll captain stat using Five Parsecs rules (2d6/3)"""
	randomize()
	var roll = randi_range(2, 12) # 2d6
	return max(1, int(ceil(float(roll) / 3.0)))

func _generate_captain_name() -> String:
	"""Generate appropriate captain name"""
	var first_names = [
		"Marcus", "Sarah", "Chen", "Alexei", "Zara", "Diego", "Naomi", "Viktor",
		"Elena", "Kai", "Juno", "Rex", "Nova", "Phoenix", "Orion", "Vega"
	]
	var last_names = [
		"Steele", "Vega", "Cross", "Raven", "Storm", "Hunter", "Wolf", "Hawk",
		"Kane", "Stone", "Drake", "Frost", "Vale", "Quinn", "Sharp", "Black"
	]
	
	randomize()
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _update_captain_display() -> void:
	"""Update captain preview display"""
	if not captain or not captain_display_container:
		return
	
	# Clear previous display
	for child in captain_display_container.get_children():
		child.queue_free()
	
	# Create info display
	var info_container = VBoxContainer.new()
	captain_display_container.add_child(info_container)
	
	# Name and title
	var name_label = Label.new()
	name_label.text = "Captain %s" % captain.character_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = Color.GOLD
	info_container.add_child(name_label)
	
	# Creation method
	var method_label = Label.new()
	method_label.text = "Created via: %s" % creation_method.capitalize()
	method_label.modulate = Color.LIGHT_GRAY
	info_container.add_child(method_label)
	
	# Stats grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	info_container.add_child(stats_grid)
	
	var stats = {
		"Combat": captain.combat,
		"Reactions": captain.reactions,
		"Toughness": captain.toughness,
		"Savvy": captain.savvy,
		"Tech": captain.tech,
		"Speed": captain.speed,
		"Luck": captain.luck
	}
	
	for stat_name in stats:
		var label = Label.new()
		label.text = stat_name + ":"
		stats_grid.add_child(label)
		
		var value = Label.new()
		value.text = str(stats[stat_name])
		if stats[stat_name] >= 4:
			value.modulate = Color.GREEN
		elif stats[stat_name] <= 2:
			value.modulate = Color.ORANGE
		stats_grid.add_child(value)
	
	# Experience and skills
	if captain.experience > 100:
		var xp_label = Label.new()
		xp_label.text = "Experience: %d XP" % captain.experience
		xp_label.modulate = Color.CYAN
		info_container.add_child(xp_label)
	
	if captain.skills and captain.skills.size() > 0:
		var skills_label = Label.new()
		skills_label.text = "Skills: " + ", ".join(captain.skills)
		skills_label.modulate = Color.LIGHT_GREEN
		info_container.add_child(skills_label)

func _apply_background_and_motivation() -> void:
	"""Apply Five Parsecs background and motivation using existing data"""
	if not captain:
		return
	
	var backgrounds = [
		"Mining Colony", "High-Tech Colony", "Military Family", "Merchant Family",
		"Space Station", "Frontier World", "Corporate Sector", "Academic Institution"
	]
	
	randomize()
	captain.background_name = backgrounds[randi() % backgrounds.size()]

# Event handlers for advanced options
func _on_leadership_toggled(enabled: bool) -> void:
	"""Handle leadership bonus toggle"""
	captain_bonuses.leadership = 1 if enabled else 0
	if captain:
		_update_captain_display()

func _on_xp_changed(value: float) -> void:
	"""Handle experience change"""
	captain_bonuses.experience = int(value)
	if captain:
		captain.experience = int(value)
		_update_captain_display()

# Panel validation and data methods (FiveParsecsCampaignPanel interface)
func validate_panel() -> bool:
	"""Validate captain creation (overrides base class)"""
	# Accept either a created captain OR filled form data
	if current_captain and not current_captain.character_name.is_empty():
		print("CaptainPanel: Validation passed for captain: %s" % current_captain.character_name)
		return true
	
	# Check form data as fallback
	if panel_data.has("captain_name") and not panel_data["captain_name"].strip_edges().is_empty():
		print("CaptainPanel: Validation passed for form data with name: %s" % panel_data["captain_name"])
		return true
	
	print("CaptainPanel: Validation failed - no captain name provided")
	return false

func get_panel_data() -> Dictionary:
	"""Get captain data for campaign (overrides base class)"""
	if not current_captain:
		return {
			"is_complete": false,
			"name": captain_name_input.text if captain_name_input else "",
			"captain_character": null
		}
	
	return {
		"captain": {
			"name": current_captain.character_name,
			"combat": current_captain.combat,
			"reactions": current_captain.reactions,
			"toughness": current_captain.toughness,
			"savvy": current_captain.savvy,
			"tech": current_captain.tech,
			"move": current_captain.move,
			"experience": current_captain.experience,
			"background": current_captain.background,
			"motivation": current_captain.motivation,
			"is_captain": true,
			"creation_method": creation_method if creation_method else "manual",
			"bonuses": captain_bonuses
		},
		"name": current_captain.character_name,
		"captain_character": current_captain,
		"is_complete": validate_panel()
	}

func set_panel_data(data: Dictionary) -> void:
	"""Set captain data from campaign state (overrides base class)"""
	if data.has("captain") and data.captain is Dictionary:
		var captain_data = data.captain
		# Load existing captain data if available
		if captain_data.has("name") and not captain_data.name.is_empty():
			captain = Character.new()
			captain.character_name = captain_data.get("name", "")
			captain.combat = captain_data.get("combat", 1)
			captain.reactions = captain_data.get("reactions", 1)
			captain.toughness = captain_data.get("toughness", 1)
			captain.savvy = captain_data.get("savvy", 1)
			captain.tech = captain_data.get("tech", 1)
			captain.speed = captain_data.get("speed", 4)
			captain.luck = captain_data.get("luck", 1)
			captain.experience = captain_data.get("experience", 100)
			captain.skills = captain_data.get("skills", [])
			captain.background_name = captain_data.get("background", "")
			captain.is_captain = true
			creation_method = captain_data.get("creation_method", "loaded")
			captain_bonuses = captain_data.get("bonuses", captain_bonuses)
			
			_update_captain_display()

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: CaptainPanel] INITIALIZATION ====")
	print("  Phase: 2 of 7 (Captain Creation)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# PHASE 4 FIX: Defer coordinator check until coordinator is actually set
	print("  Coordinator Access: [Will check after coordinator is set]")
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = CampaignManager
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var campaign_state_service = get_node_or_null("/root/CampaignStateService")
	var scene_router = get_node_or_null("/root/SceneRouter")
	var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	
	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    CampaignStateService: %s" % (campaign_state_service != null))
	print("    SceneRouter: %s" % (scene_router != null))
	print("    CampaignPhaseManager: %s" % (campaign_phase_manager != null))
	
	# Check current captain data
	print("  === INITIAL CAPTAIN DATA ===")
	print("    Current Captain: %s" % (current_captain != null))
	if current_captain:
		print("      Captain Name: '%s'" % current_captain.character_name)
		print("      Captain Stats: C:%d R:%d T:%d S:%d T:%d M:%d" % [
			current_captain.combat, current_captain.reactions, current_captain.toughness,
			current_captain.savvy, current_captain.tech, current_captain.move
		])
	print("    Panel Data Keys: %s" % str(panel_data.keys()))
	print("    Creation Method: '%s'" % creation_method)
	print("    Captain Bonuses: %s" % captain_bonuses)
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Captain Name Input: %s" % (captain_name_input != null))
	print("    Background Option: %s" % (background_option != null))
	print("    Motivation Option: %s" % (motivation_option != null))
	print("    Advanced Creation Button: %s" % (advanced_creation_button != null))
	print("    Continue Button: %s" % (continue_button != null))
	print("    Character Creator: %s" % (character_creator != null))
	
	print("==== [PANEL: CaptainPanel] INIT COMPLETE ====\n")

# ============ SIGNAL BRIDGE COMPATIBILITY ============
# CRITICAL FIX: Add missing _on_campaign_state_updated method for signal bridge

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Handle campaign state updates from coordinator - CRITICAL for signal bridge"""
	print("CaptainPanel: Received campaign state update with keys: %s" % str(state_data.keys()))
	
	# Handle captain phase specific data if available
	var captain_data = state_data.get("captain", {})
	if captain_data.has("character_name") or captain_data.has("name"):
		print("CaptainPanel: Captain data found in state - syncing...")
		_sync_with_state_data(captain_data)
	
	# Handle config data that might affect captain creation
	var config_data = state_data.get("config", {})
	if config_data.size() > 0:
		print("CaptainPanel: Config data found - checking for captain-relevant settings...")
		# Could be used for difficulty settings, custom rules, etc.
	
	# Refresh panel if needed
	call_deferred("_refresh_panel_state")

func _sync_with_state_data(captain_data: Dictionary) -> void:
	"""Sync captain panel with campaign state data"""
	if captain_data.has("character_name") and captain_name_input:
		captain_name_input.text = captain_data.get("character_name", "")
		print("CaptainPanel: Synced captain name from state")
	
	if captain_data.has("background") and background_option:
		var background = captain_data.get("background", "")
		# Set background option if it exists
		print("CaptainPanel: Background data available: %s" % background)
	
	if captain_data.has("motivation") and motivation_option:
		var motivation = captain_data.get("motivation", "")
		print("CaptainPanel: Motivation data available: %s" % motivation)

func _refresh_panel_state() -> void:
	"""Refresh the panel state after receiving updates"""
	if is_inside_tree():
		validate_panel()
		print("CaptainPanel: State refreshed after campaign update")
