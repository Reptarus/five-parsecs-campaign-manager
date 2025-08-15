extends FiveParsecsCampaignPanel

# Enhanced CrewPanel with Coordinator Pattern for campaign creation
# Extends FiveParsecsCampaignPanel for standardized interface and enhanced functionality
# Implements autonomous operation with self-management capabilities

# Import base crew component functionality
const BaseCrewComponent = preload("res://src/base/ui/BaseCrewComponent.gd")
const CharacterClass = preload("res://src/core/character/Character.gd")

# Security validation integration
const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

# Character creator integration
const CharacterCreatorClass = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")

# Enhanced Five Parsecs character generation system - now using static Character methods
const PatronSystem = preload("res://src/core/systems/PatronSystem.gd")
const RivalSystem = preload("res://src/core/rivals/RivalSystem.gd")

# Existing signals for backward compatibility
signal crew_setup_complete(crew_data: Dictionary)
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Dictionary)

# New autonomous signals for coordinator pattern
signal crew_data_complete(data: Dictionary)
signal crew_validation_failed(errors: Array[String])

# Additional crew-specific signals
signal crew_updated(crew: Array)
signal crew_member_selected(member: CharacterClass)

# Granular signals for real-time integration
signal crew_member_added(member_data: Dictionary)
signal crew_composition_changed(composition: Array)

# Enhanced state management and validation logic
var local_crew_data: Dictionary = {
	"members": [],
	"captain": null,
	"patrons": [],
	"rivals": [],
	"starting_equipment": [],
	"is_complete": false
}

# Base crew component properties
var crew_members: Array[CharacterClass] = []
var current_captain: CharacterClass = null
const MIN_CREW_SIZE: int = 1
const MAX_CREW_SIZE: int = 8

# Panel state management - production-ready pattern
var is_panel_initialized: bool = false
var is_crew_complete: bool = false
var last_validation_errors: Array[String] = []
var security_validator: SecurityValidator

# Enhanced Five Parsecs system instances
var patron_system: PatronSystem = null
var rival_system: RivalSystem = null
var generated_patrons: Array[Dictionary] = []
var generated_rivals: Array[Dictionary] = []

# Panel lifecycle signals - Framework Bible compliant
signal panel_data_updated(data: Dictionary)

# PHASE 1 INTEGRATION: InitialCrewCreation connection
var crew_creation_instance: Control = null
var crew_creation_container: Control = null

# UI Components - using safe access pattern
var crew_size_option: OptionButton
var crew_list: ItemList
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button

# UI component references for new standardized structure - using safe node access
@onready var content_area: VBoxContainer = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content")
@onready var crew_container: VBoxContainer = get_node_or_null("CrewContainer")
@onready var crew_summary: Label = get_node_or_null("CrewSummary")
@onready var instructions_label: Label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/Instructions")
@onready var crew_size_option_node: OptionButton = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewSizeSection/CrewSizeOption")
@onready var crew_list_node: ItemList = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewList")
@onready var add_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/AddButton")
@onready var edit_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/EditButton")
@onready var remove_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/RemoveButton")
@onready var randomize_button_node: Button = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewControls/RandomizeButton")
@onready var validation_panel: PanelContainer = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewValidationPanel")
@onready var validation_icon: Label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewValidationPanel/ValidationContent/ValidationIcon")
@onready var validation_text: Label = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewValidationPanel/ValidationContent/ValidationText")

# Five Parsecs UI component references for patron/rival/equipment display
@onready var patron_list: VBoxContainer = %PatronList
@onready var rival_list: VBoxContainer = %RivalList
@onready var equipment_list: VBoxContainer = %EquipmentList

# Character creator integration
var character_creator: SimpleCharacterCreator

var selected_size: int = 4

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("crew") and state_data.crew is Dictionary:
		var crew_data = state_data.crew
		if crew_data.has("members"):
			# Update local crew state from external changes
			local_crew_data.members = crew_data.members
			_update_crew_display()

func _ready() -> void:
	# Set panel info before base initialization
	set_panel_info("Crew Setup", "Set up your initial crew members. Each member will have unique backgrounds, motivations, and attributes.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# Initialize crew-specific functionality
	_initialize_security_validator()
	_initialize_five_parsecs_systems()
	call_deferred("_initialize_components")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup crew-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	security_validator = SecurityValidator.new()

func _initialize_five_parsecs_systems() -> void:
	"""Initialize the Five Parsecs patron and rival systems"""
	print("CrewPanel: Initializing Five Parsecs patron and rival systems...")
	
	# Initialize patron system
	patron_system = PatronSystem.new()
	if patron_system and patron_system.has_method("initialize"):
		var success = patron_system.initialize()
		if success:
			print("CrewPanel: Patron system initialized successfully")
		else:
			push_warning("CrewPanel: Patron system initialization failed")
	else:
		print("CrewPanel: PatronSystem not available, creating basic instance")
		patron_system = PatronSystem.new()
	
	# Initialize rival system
	rival_system = RivalSystem.new()
	if rival_system:
		print("CrewPanel: Rival system initialized successfully")
	else:
		push_warning("CrewPanel: Rival system initialization failed")

func _initialize_components() -> void:
	"""Initialize crew panel with safe component access"""
	# PHASE 1 INTEGRATION: Connect to existing InitialCrewCreation
	_connect_to_crew_creation()
	
	# Initialize existing components
	_initialize_existing_components()
	
	_connect_signals()
	_validate_crew_setup()
	# Don't auto-validate during setup - let user control validation

# PHASE 1 INTEGRATION: Connect to existing InitialCrewCreation with enhanced error handling
func _connect_to_crew_creation() -> void:
	"""Connect to the existing InitialCrewCreation system with production-ready error handling"""
	print("CrewPanel: Connecting to InitialCrewCreation...")
	
	# Safe initialization with comprehensive error handling
	var init_result = _safe_initialize_crew_creation()
	if not init_result.success:
		push_warning("CrewPanel: Falling back to manual crew creation - %s" % init_result.error)
		_create_fallback_crew_interface()
		return
	
	print("CrewPanel: InitialCrewCreation connected successfully")

func _safe_initialize_crew_creation() -> Dictionary:
	"""Safely initialize crew creation with comprehensive error handling"""
	var result = {"success": false, "error": ""}
	
	# Verify base panel structure exists
	var form_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer")
	if not form_container:
		result.error = "Base panel FormContainer not found"
		return result
	
	# Verify scene exists before attempting load
	var scene_path = "res://src/ui/screens/crew/InitialCrewCreation.tscn"
	if not ResourceLoader.exists(scene_path):
		result.error = "InitialCrewCreation.tscn not found at expected path"
		return result
	
	# Attempt to load with error protection
	var crew_scene = load(scene_path)
	if not crew_scene:
		result.error = "Failed to load crew creation scene resource"
		return result
	
	# Safe instantiation with error boundary
	var crew_instance = crew_scene.instantiate()
	if not crew_instance:
		result.error = "Failed to instantiate crew creation scene"
		return result
	
	# Setup container with proper scene structure
	crew_creation_container = Control.new()
	crew_creation_container.name = "CrewCreationContainer"
	crew_creation_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_creation_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_container.add_child(crew_creation_container)
	
	# Add crew instance with proper layout
	crew_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crew_creation_container.add_child(crew_instance)
	crew_creation_instance = crew_instance
	
	# Connect signals and initialize data
	_connect_crew_creation_signals()
	_initialize_crew_creation_data()
	
	result.success = true
	return result

func _create_fallback_crew_interface() -> void:
	"""Create fallback crew interface when InitialCrewCreation unavailable"""
	print("CrewPanel: Creating fallback crew interface")
	
	var form_container = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer")
	if not form_container:
		push_error("CrewPanel: Cannot create fallback - FormContainer not found")
		return
	
	var fallback_container = VBoxContainer.new()
	fallback_container.name = "FallbackCrewInterface"
	form_container.add_child(fallback_container)
	
	# Warning label
	var warning = Label.new()
	warning.text = "⚠️ Using simplified crew creation (InitialCrewCreation.tscn not available)"
	warning.modulate = Color.ORANGE
	fallback_container.add_child(warning)
	
	# Crew size selector
	var size_container = HBoxContainer.new()
	fallback_container.add_child(size_container)
	
	var size_label = Label.new()
	size_label.text = "Crew Size:"
	size_container.add_child(size_label)
	
	var size_spin = SpinBox.new()
	size_spin.min_value = 1
	size_spin.max_value = 8
	size_spin.value = 4
	size_spin.value_changed.connect(_on_fallback_crew_size_changed)
	size_container.add_child(size_spin)
	
	# Generate crew button
	var generate_btn = Button.new()
	generate_btn.text = "Generate Random Crew"
	generate_btn.pressed.connect(_generate_fallback_crew)
	fallback_container.add_child(generate_btn)
	
	# Crew list display
	var crew_list = ItemList.new()
	crew_list.custom_minimum_size.y = 200
	fallback_container.add_child(crew_list)
	crew_list_node = crew_list

func _on_fallback_crew_size_changed(size: int) -> void:
	"""Handle crew size changes in fallback mode"""
	selected_size = size

func _generate_fallback_crew() -> void:
	"""Generate crew using fallback interface"""
	clear_crew()
	
	for i in range(selected_size):
		var character = generate_random_character()
		if character:
			add_crew_member(character)
	
	_update_crew_display()
	# Emit both standard and specialized signals
	emit_data_changed()
	crew_updated.emit(crew_members)
	crew_setup_complete.emit(get_panel_data())

func _connect_crew_creation_signals() -> void:
	"""Connect signals from InitialCrewCreation to panel"""
	if not crew_creation_instance:
		push_warning("CrewPanel: Cannot connect signals - InitialCrewCreation not available")
		return
	
	# Connect crew creation signals
	if crew_creation_instance.has_signal("crew_created"):
		crew_creation_instance.crew_created.connect(_on_crew_created)
		print("CrewPanel: Connected crew_created signal")
	
	if crew_creation_instance.has_signal("character_generated"):
		crew_creation_instance.character_generated.connect(_on_character_generated)
		print("CrewPanel: Connected character_generated signal")
	
	# Connect any other relevant signals
	if crew_creation_instance.has_method("get_crew_state"):
		print("CrewPanel: InitialCrewCreation has get_crew_state method")

func _initialize_crew_creation_data() -> void:
	"""Initialize InitialCrewCreation with current campaign data"""
	if not crew_creation_instance:
		return
	
	# Set crew data if available
	if crew_creation_instance.has_method("set_crew_data"):
		var current_crew_data = _get_current_crew_data()
		crew_creation_instance.set_crew_data(current_crew_data)
		print("CrewPanel: Set crew data in InitialCrewCreation")

func _get_current_crew_data() -> Dictionary:
	"""Get current crew data from local state"""
	return local_crew_data

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation (BaseCampaignPanel compliance)"""
	return _get_current_crew_data()

# InitialCrewCreation signal handlers
func _on_crew_created(crew_data: Dictionary) -> void:
	"""Handle crew creation from InitialCrewCreation"""
	print("CrewPanel: Crew created - %d members" % crew_data.get("size", 0))
	
	# Update local crew data
	_update_crew_data_from_creation()
	
	# Emit signal to coordinator
	crew_data_complete.emit(local_crew_data)
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_crew_update()

func _notify_coordinator_of_crew_update() -> void:
	"""Notify the campaign coordinator of crew state changes"""
	# Try to find the coordinator through the scene tree
	var coordinator = _find_coordinator()
	if coordinator:
		coordinator.update_crew_state(local_crew_data)
		print("CrewPanel: Notified coordinator of crew update")
	else:
		print("CrewPanel: Warning - coordinator not found")

func _find_coordinator() -> Node:
	"""Find the campaign coordinator in the scene tree"""
	# Look for coordinator in parent scenes
	var current = get_parent()
	while current:
		if current.has_method("update_crew_state"):
			return current
		current = current.get_parent()
	
	# Look for autoload singleton
	var coordinator = get_node_or_null("/root/CampaignCreationCoordinator")
	if coordinator:
		return coordinator
	
	return null

func _on_character_generated(character: CharacterClass) -> void:
	"""Handle character generation from InitialCrewCreation"""
	print("CrewPanel: Character generated - %s" % character.name)
	
	# Add character to crew
	crew_members.append(character)
	
	# Update local crew data
	_update_crew_data_from_creation()
	
	# Emit signal to coordinator
	crew_member_added.emit({
		"name": character.name,
		"class": character.character_class,
		"background": character.background_name,
		"motivation": character.motivation_name
	})
	
	# PHASE 2 INTEGRATION: Update coordinator state
	_notify_coordinator_of_crew_update()

func _update_crew_data_from_creation() -> void:
	"""Update local crew data from InitialCrewCreation"""
	if not crew_creation_instance:
		return
	
	# Get crew state from creation if available
	if crew_creation_instance.has_method("get_crew_state"):
		var creation_state = crew_creation_instance.get_crew_state()
		if creation_state:
			local_crew_data = creation_state
			_update_crew_display()
			print("CrewPanel: Updated crew data from creation")

func _initialize_existing_components() -> void:
	"""Initialize existing crew panel components"""
	# Initialize existing component references
	crew_size_option = crew_size_option_node
	crew_list = crew_list_node
	add_button = add_button_node
	edit_button = edit_button_node
	remove_button = remove_button_node
	randomize_button = randomize_button_node

func _connect_signals() -> void:
	"""Connect UI signals with safety checks"""
	if crew_size_option and not crew_size_option.item_selected.is_connected(_on_crew_size_selected):
		crew_size_option.item_selected.connect(_on_crew_size_selected)
	
	if add_button and not add_button.pressed.is_connected(_on_add_member_pressed):
		add_button.pressed.connect(_on_add_member_pressed)
	
	if edit_button and not edit_button.pressed.is_connected(_on_edit_member_pressed):
		edit_button.pressed.connect(_on_edit_member_pressed)
	
	if remove_button and not remove_button.pressed.is_connected(_on_remove_member_pressed):
		remove_button.pressed.connect(_on_remove_member_pressed)
	
	if randomize_button and not randomize_button.pressed.is_connected(_on_randomize_pressed):
		randomize_button.pressed.connect(_on_randomize_pressed)
	
	if crew_list and not crew_list.item_selected.is_connected(_on_crew_member_selected):
		crew_list.item_selected.connect(_on_crew_member_selected)

func _validate_crew_setup() -> void:
	"""Validate crew setup and update completion status"""
	# Update local crew data with current state
	_update_local_crew_data()
	
	var validation_result = validate_panel()
	if validation_result:
		is_crew_complete = true
		local_crew_data.is_complete = true
		crew_data_complete.emit(local_crew_data)
	else:
		is_crew_complete = false
		local_crew_data.is_complete = false

func _update_local_crew_data() -> void:
	"""Update local crew data with patrons, rivals, and equipment"""
	# Update crew members
	local_crew_data.members = crew_members.duplicate()
	local_crew_data.captain = current_captain
	
	# Update patrons and rivals from generated lists
	local_crew_data.patrons = generated_patrons.duplicate()
	local_crew_data.rivals = generated_rivals.duplicate()
	
	# Generate enhanced starting equipment for the crew
	local_crew_data.starting_equipment = _generate_crew_starting_equipment()
	
	print("CrewPanel: Updated crew data - %d members, %d patrons, %d rivals, %d equipment items" % [
		local_crew_data.members.size(),
		local_crew_data.patrons.size(),
		local_crew_data.rivals.size(),
		local_crew_data.starting_equipment.size()
	])

func _update_crew_display() -> void:
	"""Update the crew list display"""
	if not crew_list:
		return
	
	crew_list.clear()
	
	for i in range(crew_members.size()):
		var member = crew_members[i]
		var display_text = "%s - Combat:%d Tough:%d Tech:%d" % [
			member.character_name,
			member.combat,
			member.toughness,
			member.tech
		]
		crew_list.add_item(display_text)
	
	_update_crew_summary()
	_update_button_states()

func _update_crew_summary() -> void:
	"""Update crew summary display"""
	if not crew_summary:
		return
	
	var captain_name = current_captain.character_name if current_captain else "None"
	crew_summary.text = "Crew: %d members | Captain: %s" % [crew_members.size(), captain_name]

func _update_button_states() -> void:
	"""Update button enabled/disabled states"""
	var has_selection = crew_list and not crew_list.get_selected_items().is_empty()
	
	if edit_button:
		edit_button.disabled = not has_selection
	
	if remove_button:
		remove_button.disabled = not has_selection or crew_members.size() <= 1
	
	if add_button:
		add_button.disabled = crew_members.size() >= MAX_CREW_SIZE

# UI Event Handlers
func _on_crew_size_selected(index: int) -> void:
	"""Handle crew size selection"""
	if not crew_size_option:
		return
	
	selected_size = crew_size_option.get_item_id(index)
	_adjust_crew_size()

func _adjust_crew_size() -> void:
	"""Adjust crew size to match selection"""
	var current_size = crew_members.size()
	
	if current_size < selected_size:
		# Add members
		for i in range(selected_size - current_size):
			var character = generate_random_character()
			if character:
				add_crew_member(character)
	elif current_size > selected_size:
		# Remove excess members (preserve captain if possible)
		while crew_members.size() > selected_size:
			var member_to_remove = crew_members.back()
			if member_to_remove != current_captain:
				remove_crew_member(member_to_remove)
			else:
				# Remove a different member instead
				if crew_members.size() > 1:
					remove_crew_member(crew_members[0])
				else:
					break
	
	_update_crew_display()
	crew_updated.emit(crew_members)

func _on_add_member_pressed() -> void:
	"""Handle add crew member button"""
	if crew_members.size() >= MAX_CREW_SIZE:
		return
	
	var character = generate_random_character()
	if character:
		add_crew_member(character)

func _on_edit_member_pressed() -> void:
	"""Handle edit crew member button"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		return
	
	var index = crew_list.get_selected_items()[0]
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		# TODO: Implement character editing

func _on_remove_member_pressed() -> void:
	"""Handle remove crew member button"""
	if not crew_list or crew_list.get_selected_items().is_empty():
		return
	
	if crew_members.size() <= 1:
		return
	
	var index = crew_list.get_selected_items()[0]
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		remove_crew_member(character)
		_update_crew_display()

func _on_randomize_pressed() -> void:
	"""Handle randomize crew button"""
	clear_crew()
	for i in range(selected_size):
		var character = generate_random_character()
		if character:
			add_crew_member(character)
	_update_crew_display()

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	_update_button_states()
	
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		crew_member_selected.emit(character)

# Crew management methods
func add_crew_member(character: CharacterClass) -> bool:
	"""Add a crew member with validation"""
	if not character or not is_instance_valid(character):
		return false
	
	if crew_members.size() >= MAX_CREW_SIZE:
		return false
	
	crew_members.append(character)
	
	# Auto-assign first member as captain if none assigned
	if not current_captain and crew_members.size() == 1:
		set_captain(character)
	
	_emit_crew_updated()
	return true

func remove_crew_member(character: CharacterClass) -> bool:
	"""Remove a crew member with validation"""
	if not character or not is_instance_valid(character):
		return false
	
	var index = crew_members.find(character)
	if index == -1:
		return false
	
	crew_members.remove_at(index)
	
	# If removed character was captain, assign new captain
	if character == current_captain and crew_members.size() > 0:
		set_captain(crew_members[0])
	elif character == current_captain:
		current_captain = null
	
	_emit_crew_updated()
	return true

func clear_crew() -> void:
	"""Clear all crew members"""
	crew_members.clear()
	current_captain = null
	_emit_crew_updated()

func set_captain(character: CharacterClass) -> void:
	"""Set a crew member as captain"""
	if character and character in crew_members:
		# Remove captain status from previous captain
		if current_captain:
			current_captain.character_name = current_captain.character_name.replace(" (Captain)", "")
		
		current_captain = character
		character.character_name = character.character_name.replace(" (Captain)", "") + " (Captain)"
		_emit_crew_updated()

func _emit_crew_updated() -> void:
	"""Emit crew updated signal"""
	crew_updated.emit(crew_members)

func generate_random_character() -> CharacterClass:
	"""Generate a complete Five Parsecs character with backgrounds, motivations, and relationships"""
	print("CrewPanel: Generating complete Five Parsecs character...")
	
	# Use the complete Five Parsecs character generation system
	var character = Character.generate_complete_character()
	
	if not character:
		push_warning("CrewPanel: Five Parsecs character generation failed, using fallback")
		character = _generate_fallback_character()
	else:
		print("CrewPanel: Generated character '%s' - %s %s" % [
			character.character_name,
			_get_background_name(character.background),
			_get_motivation_name(character.motivation)
		])
		
		# Generate patrons and rivals for this character
		_generate_character_relationships(character)
	
	return character

func _generate_fallback_character() -> CharacterClass:
	"""Generate a basic fallback character if the full system fails"""
	var character = CharacterClass.new()
	
	# Generate random name from a pool
	var first_names = ["Alex", "Casey", "Jordan", "Sam", "Taylor", "Morgan", "Riley", "Avery", "Blake", "Cameron"]
	var last_names = ["Smith", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Thomas"]
	
	character.character_name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
	
	# Generate Five Parsecs stats (2d6 divided by 3, rounded up)
	character.combat = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.toughness = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.savvy = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.tech = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.speed = max(1, ceili(float(randi_range(2, 12)) / 3.0))
	character.luck = 1 # Base luck
	
	# Calculate health based on toughness
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Set basic defaults
	character.background = GlobalEnums.Background.MILITARY
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	character.origin = GlobalEnums.Origin.HUMAN
	
	return character

func _generate_character_relationships(character: CharacterClass) -> void:
	"""Generate patrons and rivals for a character based on background and motivation"""
	if not character:
		return
	
	print("CrewPanel: Generating relationships for %s..." % character.character_name)
	
	# Generate patrons based on character background (1-3 patrons per Five Parsecs rules)
	var patron_count = _calculate_starting_patrons(character)
	for i in range(patron_count):
		if patron_system:
			var patron = patron_system.generate_patron()
			if not patron.is_empty():
				# Link patron to character background
				_customize_patron_for_character(patron, character)
				generated_patrons.append(patron)
				print("CrewPanel: Generated patron '%s' for %s" % [patron.get("name", "Unknown"), character.character_name])
	
	# Generate rivals based on character background (0-2 rivals per Five Parsecs rules)
	var rival_count = _calculate_starting_rivals(character)
	for i in range(rival_count):
		if rival_system:
			var rival_params = _get_rival_params_for_character(character)
			var rival = rival_system.create_rival(rival_params)
			if not rival.is_empty():
				generated_rivals.append(rival)
				print("CrewPanel: Generated rival '%s' for %s" % [rival.get("name", "Unknown"), character.character_name])
	
	# Update local crew data with new relationships
	local_crew_data["patrons"] = generated_patrons
	local_crew_data["rivals"] = generated_rivals
	
	# Update UI displays
	call_deferred("refresh_all_displays")

func _calculate_starting_patrons(character: CharacterClass) -> int:
	"""Calculate number of starting patrons based on background and motivation"""
	var base_count = 1
	
	# Background modifiers per Five Parsecs rules
	if character.background == GlobalEnums.Background.MILITARY:
		base_count += 1 # Military connections
	elif character.background == GlobalEnums.Background.NOBLE:
		base_count += 2 # Noble connections
	elif character.background == GlobalEnums.Background.MERCHANT:
		base_count += 1 # Trade connections
	
	# Motivation modifiers
	if character.motivation == GlobalEnums.Motivation.WEALTH:
		base_count += 1 # Wealth seekers have more contacts
	elif character.motivation == GlobalEnums.Motivation.POWER:
		base_count += 1 # Power seekers cultivate connections
	
	return clampi(base_count, 1, 3) # Five Parsecs limit: 1-3 patrons

func _calculate_starting_rivals(character: CharacterClass) -> int:
	"""Calculate number of starting rivals based on background"""
	var base_count = 0
	
	# Background creates enemies per Five Parsecs rules
	if character.background == GlobalEnums.Background.CRIMINAL:
		base_count += 2 # Law enforcement and rival criminals
	elif character.background == GlobalEnums.Background.MILITARY:
		base_count += 1 # Deserters or enemy forces
	elif character.background == GlobalEnums.Background.MERCENARY:
		base_count += 1 # Competing mercenaries
	elif character.background == GlobalEnums.Background.OUTCAST:
		base_count += 1 # Those who cast them out
	
	# Random chance for additional rival
	if randf() < 0.3:
		base_count += 1
	
	return clampi(base_count, 0, 2) # Five Parsecs limit: 0-2 rivals

func _customize_patron_for_character(patron: Dictionary, character: CharacterClass) -> void:
	"""Customize patron based on character background"""
	if not patron or not character:
		return
	
	# Set patron type based on character background
	match character.background:
		GlobalEnums.Background.MILITARY:
			patron["type"] = "MILITARY_COMMAND"
		GlobalEnums.Background.MERCHANT, GlobalEnums.Background.TRADER:
			patron["type"] = "TRADE_GUILD"
		GlobalEnums.Background.ACADEMIC:
			patron["type"] = "RESEARCH_INSTITUTE"
		GlobalEnums.Background.CRIMINAL:
			patron["type"] = "CRIME_SYNDICATE"
		GlobalEnums.Background.NOBLE:
			patron["type"] = "NOBLE_HOUSE"
		_:
			patron["type"] = "LOCAL_AUTHORITY"

func _get_rival_params_for_character(character: CharacterClass) -> Dictionary:
	"""Get rival generation parameters based on character"""
	var params = {}
	
	# Set rival type based on character background
	match character.background:
		GlobalEnums.Background.MILITARY:
			params["type"] = GlobalEnums.EnemyType.RAIDERS
			params["name"] = "Rogue Squadron"
		GlobalEnums.Background.CRIMINAL:
			params["type"] = GlobalEnums.EnemyType.GANGERS
			params["name"] = "Rival Gang"
		GlobalEnums.Background.MERCENARY:
			params["type"] = GlobalEnums.EnemyType.PIRATES
			params["name"] = "Competing Mercs"
		_:
			params["type"] = GlobalEnums.EnemyType.PUNKS
			params["name"] = "Local Hostiles"
	
	params["level"] = randi_range(1, 3) # Starting rival level
	params["reputation"] = randi_range(0, 2) # Starting reputation
	
	return params

func _get_background_name(background_id: int) -> String:
	"""Get human-readable background name"""
	var background_keys = GlobalEnums.Background.keys()
	if background_id >= 0 and background_id < background_keys.size():
		return background_keys[background_id].capitalize()
	return "Unknown"

func _get_motivation_name(motivation_id: int) -> String:
	"""Get human-readable motivation name"""
	var motivation_keys = GlobalEnums.Motivation.keys()
	if motivation_id >= 0 and motivation_id < motivation_keys.size():
		return motivation_keys[motivation_id].capitalize()
	return "Unknown"

func _generate_crew_starting_equipment() -> Array[Dictionary]:
	"""Generate enhanced starting equipment for the entire crew using Five Parsecs rules"""
	var crew_equipment: Array[Dictionary] = []
	
	print("CrewPanel: Generating starting equipment for %d crew members..." % crew_members.size())
	
	# Generate equipment for each crew member using the enhanced system
	for member in crew_members:
		if member and member.has_method("get_meta"):
			# Check if character already has equipment from generation
			var character_equipment = member.get_meta("personal_equipment", {})
			if not character_equipment.is_empty():
				crew_equipment.append({
					"character_name": member.character_name,
					"equipment": character_equipment
				})
				continue
		
		# Use Character to generate equipment for this character
		var equipment = Character.generate_starting_equipment_enhanced(member)
		crew_equipment.append({
			"character_name": member.character_name,
			"equipment": equipment
		})
	
	# Add crew-level starting equipment per Five Parsecs rules
	var crew_level_equipment = _generate_crew_level_equipment()
	if not crew_level_equipment.is_empty():
		crew_equipment.append({
			"character_name": "Crew Shared Equipment",
			"equipment": crew_level_equipment
		})
	
	print("CrewPanel: Generated equipment for %d crew members" % crew_equipment.size())
	
	# Update local crew data with generated equipment
	var equipment_items: Array[String] = []
	for crew_equip in crew_equipment:
		var equip_dict = crew_equip.get("equipment", {})
		for category in ["weapons", "armor", "gear"]:
			if equip_dict.has(category):
				var items = equip_dict[category]
				if typeof(items) == TYPE_ARRAY:
					for item in items:
						equipment_items.append(str(item))
	
	local_crew_data["starting_equipment"] = equipment_items
	
	# Update UI display
	call_deferred("update_equipment_display")
	
	return crew_equipment

func _generate_crew_level_equipment() -> Dictionary:
	"""Generate crew-level shared equipment per Five Parsecs starting rules"""
	var shared_equipment = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 1000
	}
	
	# Five Parsecs starting equipment: 3 military weapons, 3 low-tech weapons
	var military_weapons = ["Combat Rifle", "Assault Rifle", "Battle Dress"]
	var low_tech_weapons = ["Blade", "Pistol", "Hand Weapon"]
	
	# Add military weapons (crew gets 3)
	for i in range(3):
		if i < military_weapons.size():
			shared_equipment.weapons.append(military_weapons[i])
	
	# Add low-tech weapons (crew gets 3)  
	for i in range(3):
		if i < low_tech_weapons.size():
			shared_equipment.weapons.append(low_tech_weapons[i])
	
	# Add basic crew gear
	shared_equipment.gear.append("Comm Unit")
	shared_equipment.gear.append("Scanner")
	shared_equipment.gear.append("Repair Kit")
	
	# Starting credits based on crew size (more crew = more pooled resources)
	shared_equipment.credits = 1000 + (crew_members.size() * 200)
	
	return shared_equipment

func validate_panel() -> bool:
	"""Validate crew panel data"""
	# Clear previous errors
	last_validation_errors = []
	
	# Business rule: Minimum crew size validation
	if crew_members.size() == 0:
		last_validation_errors.append("At least one crew member is required")
		return false
	
	# Business rule: Maximum crew size validation  
	if crew_members.size() > 8: # Five Parsecs maximum
		last_validation_errors.append("Crew cannot exceed 8 members")
		return false
	
	# Business rule: Captain validation
	if not current_captain:
		last_validation_errors.append("A captain must be designated")
		return false
	
	# Business rule: Captain must be crew member
	if current_captain and current_captain not in crew_members:
		last_validation_errors.append("Captain must be a member of the crew")
		return false
	
	# All validations passed
	return true

func cleanup_panel() -> void:
	"""Clean up panel state when navigating away"""
	print("CrewPanel: Cleaning up panel state")
	
	# Clear crew creation instance
	if crew_creation_instance:
		if crew_creation_instance.has_method("cleanup"):
			crew_creation_instance.cleanup()
		crew_creation_instance.queue_free()
		crew_creation_instance = null
	
	# Clear crew creation container
	if crew_creation_container:
		crew_creation_container.queue_free()
		crew_creation_container = null
	
	# Reset local crew data
	local_crew_data = {
		"members": [],
		"captain": null,
		"is_complete": false
	}
	
	# Clear crew members array
	crew_members.clear()
	current_captain = null
	
	print("CrewPanel: Panel cleanup completed")

## Five Parsecs UI Display Functions

func update_patron_display() -> void:
	"""Update patron display section in UI"""
	if not patron_list:
		return
	
	# Clear existing patron display
	for child in patron_list.get_children():
		child.queue_free()
	
	# Display current patrons
	var patrons = local_crew_data.get("patrons", [])
	if patrons.is_empty():
		var no_patrons_label = Label.new()
		no_patrons_label.text = "No patrons yet"
		no_patrons_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		no_patrons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		patron_list.add_child(no_patrons_label)
	else:
		for patron in patrons:
			var patron_container = HBoxContainer.new()
			
			# Patron name and type
			var patron_label = Label.new()
			patron_label.text = "%s (%s)" % [
				patron.get("name", "Unknown Patron"),
				patron.get("type", "Unknown")
			]
			patron_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			patron_container.add_child(patron_label)
			
			# Patron reputation indicator
			var reputation = patron.get("reputation", 0)
			var rep_label = Label.new()
			rep_label.text = "Rep: %d" % reputation
			rep_label.add_theme_color_override("font_color", Color.CYAN if reputation > 0 else Color.WHITE)
			patron_container.add_child(rep_label)
			
			patron_list.add_child(patron_container)

func update_rival_display() -> void:
	"""Update rival display section in UI"""
	if not rival_list:
		return
	
	# Clear existing rival display
	for child in rival_list.get_children():
		child.queue_free()
	
	# Display current rivals
	var rivals = local_crew_data.get("rivals", [])
	if rivals.is_empty():
		var no_rivals_label = Label.new()
		no_rivals_label.text = "No known rivals"
		no_rivals_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		no_rivals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rival_list.add_child(no_rivals_label)
	else:
		for rival in rivals:
			var rival_container = HBoxContainer.new()
			
			# Rival name and type
			var rival_label = Label.new()
			rival_label.text = "%s (%s)" % [
				rival.get("name", "Unknown Rival"),
				_get_enemy_type_name(rival.get("type", 0))
			]
			rival_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rival_container.add_child(rival_label)
			
			# Rival threat level indicator
			var level = rival.get("level", 1)
			var level_label = Label.new()
			level_label.text = "Lvl: %d" % level
			level_label.add_theme_color_override("font_color", Color.RED if level > 2 else Color.ORANGE)
			rival_container.add_child(level_label)
			
			rival_list.add_child(rival_container)

func update_equipment_display() -> void:
	"""Update equipment display section in UI"""
	if not equipment_list:
		return
	
	# Clear existing equipment display
	for child in equipment_list.get_children():
		child.queue_free()
	
	# Display starting equipment
	var equipment = local_crew_data.get("starting_equipment", [])
	if equipment.is_empty():
		var no_equipment_label = Label.new()
		no_equipment_label.text = "No starting equipment"
		no_equipment_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		no_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipment_list.add_child(no_equipment_label)
	else:
		for item in equipment:
			var item_label = Label.new()
			if typeof(item) == TYPE_STRING:
				item_label.text = "• %s" % item
			else:
				item_label.text = "• %s" % str(item)
			equipment_list.add_child(item_label)

func _get_enemy_type_name(type_id: int) -> String:
	"""Get human-readable name for enemy type"""
	var enemy_types = GlobalEnums.EnemyType
	if type_id >= 0 and type_id < enemy_types.size():
		return enemy_types.keys()[type_id]
	return "Unknown"

func refresh_all_displays() -> void:
	"""Refresh all Five Parsecs display sections"""
	update_patron_display()
	update_rival_display()
	update_equipment_display()
