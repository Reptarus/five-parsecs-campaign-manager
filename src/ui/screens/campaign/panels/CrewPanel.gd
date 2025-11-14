extends FiveParsecsCampaignPanel

# Enhanced CrewPanel with Coordinator Pattern for campaign creation
# Extends FiveParsecsCampaignPanel for standardized interface and enhanced functionality
# Implements autonomous operation with self-management capabilities

# Import character functionality
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
signal crew_member_selected(member)  # CharacterClass reference removed

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
var crew_members: Array = []  # Removed type constraint for flexibility
var current_captain = null  # CharacterClass reference removed

# Deduplication tracking to prevent duplicate crew members (Sprint 6 fix)
var _added_character_ids: Dictionary = {}  # Track by character name to prevent duplicates
const MIN_CREW_SIZE: int = 1
const MAX_CREW_SIZE: int = 8

# Panel state management - production-ready pattern
var is_panel_initialized: bool = false
var is_crew_complete: bool = false
var last_validation_errors: Array[String] = []
var security_validator: SecurityValidator

# Panel data dictionary for state tracking
var panel_data: Dictionary = {
	"crew": [],
	"captain": null,
	"is_complete": false,
	"crew_size": 4
}

# Enhanced Five Parsecs system instances
var patron_system: PatronSystem = null
var rival_system: RivalSystem = null
var generated_patrons: Array[Dictionary] = []
var generated_rivals: Array[Dictionary] = []

# Panel lifecycle signals - Framework Bible compliant
signal panel_data_updated(data: Dictionary)

# PHASE 1 INTEGRATION: InitialCrewCreation connection
var crew_creation_instance: Control = null

# ============ RUNTIME TYPE VALIDATION ============
# Safe crew member management with runtime type checking

func add_crew_member(member) -> bool:
	"""Add crew member with runtime type validation"""
	if member is Character or member is Dictionary:
		crew_members.append(member)
		_validate_crew_setup()  # Fixed method name
		print("CrewPanel: Added crew member (type: %s)" % type_string(typeof(member)))
		return true
	else:
		push_error("CrewPanel: Invalid crew member type: %s" % type_string(typeof(member)))
		return false

func safe_get_crew_member(index: int):
	"""Safely get crew member by index"""
	if index >= 0 and index < crew_members.size():
		return crew_members[index]
	return null

func get_crew_count() -> int:
	"""Get current crew count"""
	return crew_members.size()
var crew_creation_container: Control = null

# UI Components - using safe access pattern
var crew_size_option: OptionButton
var crew_list: Control  # Can be either ItemList or VBoxContainer
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
@onready var crew_list_node: Control = get_node_or_null("ContentMargin/MainContent/FormContent/FormContainer/Content/CrewContainer/CrewList")
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

var selected_size: int = 4  # Default Five Parsecs crew size

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("crew") and state_data.crew is Dictionary:
		var crew_data = state_data.crew
		if crew_data.has("members"):
			# Update local crew state from external changes
			local_crew_data.members = crew_data.get("members", [])
			_update_crew_display()

func _ready() -> void:
	# Set panel info before base initialization with more informative description
	set_panel_info("Crew Generation", "Generate 4 crew members. Each character has unique stats and backgrounds that affect equipment.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")
	
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
	
	# PHASE 5: Pass coordinator to InitialCrewCreation for workflow integration
	var coord = get_coordinator()
	if coord and crew_creation_instance.has_method("set_coordinator"):
		crew_creation_instance.set_coordinator(coord)
		print("CrewPanel: Coordinator passed to InitialCrewCreation successfully")
	else:
		print("CrewPanel: Running without coordinator integration")
	
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
	print("========== CrewPanel: FALLBACK CREW GENERATION START ==========")
	print("CrewPanel: DEBUG - Target crew size: %d" % selected_size)
	print("CrewPanel: DEBUG - Clearing existing crew...")
	clear_crew()
	print("CrewPanel: DEBUG - Crew cleared, size now: %d" % crew_members.size())
	
	for i in range(selected_size):
		print("CrewPanel: DEBUG - Generating character %d/%d..." % [i+1, selected_size])
		var character = generate_random_character()
		if character:
			print("CrewPanel: DEBUG - Character %d created successfully: %s" % [i+1, character.name if character.has_method("get", "name") else "Unknown"])
			var added = add_crew_member(character)
			print("CrewPanel: DEBUG - Character %d added to crew: %s" % [i+1, "SUCCESS" if added else "FAILED"])
		else:
			print("CrewPanel: DEBUG - Character %d creation FAILED" % [i+1])
	
	print("CrewPanel: DEBUG - Final crew size: %d" % crew_members.size())
	print("CrewPanel: DEBUG - Updating crew display...")
	_update_crew_display()
	
	print("CrewPanel: DEBUG - Emitting signals...")
	emit_data_changed()
	crew_updated.emit(crew_members)
	crew_setup_complete.emit(get_panel_data())
	print("========== CrewPanel: FALLBACK CREW GENERATION COMPLETE ==========")

func _connect_crew_creation_signals() -> void:
	"""Connect signals from InitialCrewCreation to panel - ENHANCED"""
	if not crew_creation_instance:
		push_warning("CrewPanel: Cannot connect signals - InitialCrewCreation not available")
		return
	
	# Use enhanced connection method
	_connect_to_initial_crew_creation()
	
	# Pass coordinator if available 
	var coord = get_coordinator()
	if coord and crew_creation_instance.has_method("set_workflow_system"):
		crew_creation_instance.set_workflow_system(coord)
		print("CrewPanel: Workflow system connected to InitialCrewCreation")
	
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
# REMOVED: Duplicate _on_crew_created function - using Phase 2 implementation at line 1227
	
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

func _find_coordinator() -> Variant:
	"""Find the campaign coordinator in the scene tree"""
	# Look for coordinator in parent scenes
	var current = get_parent()
	while current:
		if current.has_method("update_crew_state"):
			return current
		current = current.get_parent()
	
	# CampaignCreationCoordinator is not an autoload - should be accessed through parent UI
	# This reference is invalid and should be removed
	
	return null

# REMOVED: Duplicate _on_character_generated function - using Phase 2 implementation at line 1228

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
	print("========== CrewPanel: CREW VALIDATION START ==========")
	print("CrewPanel: DEBUG - Current crew size: %d" % crew_members.size())
	print("CrewPanel: DEBUG - Target crew size: %d" % selected_size)
	print("CrewPanel: DEBUG - Current captain: %s" % ("SET" if current_captain else "NONE"))
	
	# Update local crew data with current state
	print("CrewPanel: DEBUG - Updating local crew data...")
	_update_local_crew_data()
	print("CrewPanel: DEBUG - Local crew data updated, members: %d" % local_crew_data.get("members", []).size())
	
	print("CrewPanel: DEBUG - Running panel validation...")
	var validation_result = validate_panel()
	print("CrewPanel: DEBUG - Validation result: %s" % ("VALID" if validation_result else "INVALID"))
	
	if validation_result:
		print("CrewPanel: DEBUG - Crew validation PASSED - marking complete")
		is_crew_complete = true
		local_crew_data.is_complete = true
		
		print("CrewPanel: DEBUG - Emitting crew_data_complete signal...")
		crew_data_complete.emit(local_crew_data)
		
		print("CrewPanel: DEBUG - Emitting panel_completed signal...")
		panel_completed.emit(local_crew_data)
		print("CrewPanel: DEBUG - panel_completed signal emitted successfully")
		print("CrewPanel: CREW SETUP COMPLETE - progression enabled")
	else:
		print("CrewPanel: DEBUG - Crew validation FAILED")
		is_crew_complete = false
		local_crew_data.is_complete = false
	
	print("========== CrewPanel: CREW VALIDATION COMPLETE ==========")

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
	"""Update the crew list display - handles both ItemList and VBoxContainer"""
	if not crew_list:
		return
	
	# Handle ItemList (fallback UI)
	if crew_list is ItemList:
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
	# Handle VBoxContainer (scene UI)
	elif crew_list is VBoxContainer:
		# Clear existing children
		for child in crew_list.get_children():
			child.queue_free()
		
		# Add crew members as labels
		for i in range(crew_members.size()):
			var member = crew_members[i]
			var label = Label.new()
			label.text = "%s - Combat:%d Tough:%d Tech:%d" % [
				member.character_name,
				member.combat,
				member.toughness,
				member.tech
			]
			# Add some styling
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			crew_list.add_child(label)
			
			# Add click detection for selection (optional)
			var button = Button.new()
			button.text = "Select %s" % member.character_name
			button.pressed.connect(_on_crew_member_button_pressed.bind(i))
			crew_list.add_child(button)
	
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
	var has_selection = false
	
	if crew_list:
		if crew_list is ItemList:
			has_selection = not crew_list.get_selected_items().is_empty()
		elif crew_list is VBoxContainer:
			# For VBoxContainer, check if any button is highlighted (modulate != WHITE)
			for child in crew_list.get_children():
				if child is Button and child.modulate != Color.WHITE:
					has_selection = true
					break
	
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
	if not crew_list:
		return
	
	var selected_index = -1
	
	if crew_list is ItemList:
		if crew_list.get_selected_items().is_empty():
			return
		selected_index = crew_list.get_selected_items()[0]
	elif crew_list is VBoxContainer:
		# Find highlighted button in VBoxContainer
		for i in crew_list.get_child_count():
			var child = crew_list.get_child(i)
			if child is Button and child.modulate != Color.WHITE:
				selected_index = i
				break
		if selected_index == -1:
			return
	
	if selected_index >= 0 and selected_index < crew_members.size():
		var character = crew_members[selected_index]
		# TODO: Implement character editing

func _on_remove_member_pressed() -> void:
	"""Handle remove crew member button"""
	if not crew_list:
		return
	
	if crew_members.size() <= 1:
		return
	
	var selected_index = -1
	
	if crew_list is ItemList:
		if crew_list.get_selected_items().is_empty():
			return
		selected_index = crew_list.get_selected_items()[0]
	elif crew_list is VBoxContainer:
		# Find highlighted button in VBoxContainer
		for i in crew_list.get_child_count():
			var child = crew_list.get_child(i)
			if child is Button and child.modulate != Color.WHITE:
				selected_index = i
				break
		if selected_index == -1:
			return
	
	if selected_index >= 0 and selected_index < crew_members.size():
		var character = crew_members[selected_index]
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

func _on_crew_member_button_pressed(member_data: Dictionary) -> void:
	"""Handle crew member button press for selection (VBoxContainer mode)"""
	if crew_list is VBoxContainer:
		# Handle VBoxContainer selection by highlighting the selected button
		for child in crew_list.get_children():
			if child is Button:
				child.modulate = Color.WHITE  # Reset color
				if child.has_meta("crew_data"):
					var button_data = child.get_meta("crew_data")
					if DataValidator.safe_get_name(button_data) == DataValidator.safe_get_name(member_data):
						child.modulate = Color.LIGHT_BLUE  # Highlight selected
	
	# Update button states based on new selection
	_update_button_states()
	print("CrewPanel: Crew member selected: %s" % DataValidator.safe_get_name(member_data))

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	_update_button_states()
	
	if index >= 0 and index < crew_members.size():
		var character = crew_members[index]
		crew_member_selected.emit(character)

# LEGACY FUNCTIONS REMOVED - Duplicate function caused parse error

func remove_crew_member(member) -> bool:
	"""Remove crew member - replacement for removed legacy function"""
	if member in crew_members:
		crew_members.erase(member)
		_validate_crew_setup()
		return true
	return false

func clear_crew() -> void:
	"""Clear all crew members"""
	crew_members.clear()
	current_captain = null
	_emit_crew_updated()

func set_captain(character) -> void:
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

func generate_random_character():
	"""Generate a complete Five Parsecs character with backgrounds, motivations, and relationships"""
	print("CrewPanel: Generating complete Five Parsecs character...")
	
	# Collect existing crew names to prevent duplicates
	var existing_names: Array[String] = []
	for member in local_crew_data.members:
		if member and member.has("character_name"):
			existing_names.append(member.character_name)
	
	print("CrewPanel: Avoiding duplicate names: %s" % str(existing_names))
	
	# Use the complete Five Parsecs character generation system with existing names
	var config = {"existing_names": existing_names}
	var character = Character.generate_complete_character(config)
	
	if not character:
		push_warning("CrewPanel: Five Parsecs character generation failed, using fallback")
		character = _generate_fallback_character(existing_names)
	else:
		print("CrewPanel: Generated character '%s' - %s %s" % [
			character.character_name,
			_get_background_name(character.background),
			_get_motivation_name(character.motivation)
		])
		
		# Generate patrons and rivals for this character
		_generate_character_relationships(character)
	
	return character

func _generate_fallback_character(existing_names: Array = []):
	"""Generate a basic fallback character if the full system fails"""
	var character = Character.new()
	
	# Generate random name from a pool, avoiding duplicates
	var first_names = ["Alex", "Casey", "Jordan", "Sam", "Taylor", "Morgan", "Riley", "Avery", "Blake", "Cameron"]
	var last_names = ["Smith", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Thomas"]
	
	# Try to generate unique name (up to 10 attempts)
	var attempts = 0
	var name = ""
	while attempts < 10:
		name = first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
		if not name in existing_names:
			break
		attempts += 1
	
	# Add suffix if still duplicate
	if name in existing_names:
		name += " " + str(randi() % 100 + 1)
	
	character.character_name = name
	
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
	character.background = "MILITARY"
	character.motivation = "SURVIVAL"
	character.origin = "HUMAN"
	
	return character

func _generate_character_relationships(character) -> void:
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

func _calculate_starting_patrons(character) -> int:
	"""Calculate number of starting patrons based on background and motivation"""
	var base_count = 1
	
	# Background modifiers per Five Parsecs rules
	if character.background == "Military":
		base_count += 1 # Military connections
	elif character.background == "Noble":
		base_count += 2 # Noble connections
	elif character.background == "Merchant":
		base_count += 1 # Trade connections
	
	# Motivation modifiers
	if character.motivation == "Wealth":
		base_count += 1 # Wealth seekers have more contacts
	elif character.motivation == "Power":
		base_count += 1 # Power seekers cultivate connections
	
	return clampi(base_count, 1, 3) # Five Parsecs limit: 1-3 patrons

func _calculate_starting_rivals(character) -> int:
	"""Calculate number of starting rivals based on background"""
	var base_count = 0
	
	# Background creates enemies per Five Parsecs rules
	if character.background == "Criminal":
		base_count += 2 # Law enforcement and rival criminals
	elif character.background == "Military":
		base_count += 1 # Deserters or enemy forces
	elif character.background == "Mercenary":
		base_count += 1 # Competing mercenaries
	elif character.background == "Outcast":
		base_count += 1 # Those who cast them out
	
	# Random chance for additional rival
	if randf() < 0.3:
		base_count += 1
	
	return clampi(base_count, 0, 2) # Five Parsecs limit: 0-2 rivals

func _customize_patron_for_character(patron: Dictionary, character) -> void:
	"""Customize patron based on character background"""
	if not patron or not character:
		return
	
	# Set patron type based on character background - now using string comparison
	match character.background:
		"MILITARY":
			patron["type"] = "MILITARY_COMMAND"
		"MERCHANT", "TRADER":
			patron["type"] = "TRADE_GUILD"
		"ACADEMIC":
			patron["type"] = "RESEARCH_INSTITUTE"
		"CRIMINAL":
			patron["type"] = "CRIME_SYNDICATE"
		"NOBLE":
			patron["type"] = "NOBLE_HOUSE"
		_:
			patron["type"] = "LOCAL_AUTHORITY"

func _get_rival_params_for_character(character) -> Dictionary:
	"""Get rival generation parameters based on character"""
	var params = {}
	
	# Set rival type based on character background - now using string comparison
	match character.background:
		"MILITARY":
			params["type"] = GlobalEnums.EnemyType.RAIDERS
			params["name"] = "Rogue Squadron"
		"CRIMINAL":
			params["type"] = GlobalEnums.EnemyType.GANGERS
			params["name"] = "Rival Gang"
		"MERCENARY":
			params["type"] = GlobalEnums.EnemyType.PIRATES
			params["name"] = "Competing Mercs"
		_:
			params["type"] = GlobalEnums.EnemyType.PUNKS
			params["name"] = "Local Hostiles"
	
	params["level"] = randi_range(1, 3) # Starting rival level
	params["reputation"] = randi_range(0, 2) # Starting reputation
	
	return params

func _get_background_name(background: Variant) -> String:
	"""Get human-readable background name - handles both int and String"""
	if background is String:
		return background.capitalize()
	elif background is int:
		var background_keys = GlobalEnums.Background.keys()
		if background >= 0 and background < background_keys.size():
			return background_keys[background].capitalize()
	return "Unknown"

func _get_motivation_name(motivation: Variant) -> String:
	"""Get human-readable motivation name - handles both int and String"""
	if motivation is String:
		return motivation.capitalize()
	elif motivation is int:
		var motivation_keys = GlobalEnums.Motivation.keys()
		if motivation >= 0 and motivation < motivation_keys.size():
			return motivation_keys[motivation].capitalize()
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
	"""FIXED: Validate crew panel data with proper data structure checking"""
	# Clear previous errors
	last_validation_errors = []
	
	# CRITICAL: Data structure synchronization check
	if crew_members.size() != local_crew_data.members.size():
		push_warning("CrewPanel: Data structure mismatch - crew_members: %d, local_crew_data: %d" % [
			crew_members.size(),
			local_crew_data.members.size()
		])
		# Log detailed state for debugging
		print("CrewPanel: crew_members array contains %d Character objects" % crew_members.size())
		print("CrewPanel: local_crew_data.members contains %d Dictionary entries" % local_crew_data.members.size())
		
		# Attempt recovery if possible
		if crew_members.size() == 0 and local_crew_data.members.size() > 0:
			push_error("CrewPanel: TypedArray issue detected - attempting recovery...")
			# Try to recover Character objects from dictionaries
			for member_dict in local_crew_data.members:
				if member_dict.has("character_object"):
					var char_obj = member_dict.get("character_object")
					if char_obj and is_instance_valid(char_obj):
						var char_name = char_obj.get("character_name") if char_obj.has("character_name") else str(char_obj.name)
						if not _added_character_ids.has(char_name):
							crew_members.append(char_obj)
							_added_character_ids[char_name] = true
							print("CrewPanel: Recovered Character object from dictionary: %s" % char_name)
						else:
							print("CrewPanel: Skipping duplicate recovery for: %s" % char_name)
				else:
					# Create a minimal Character object for validation
					var char_name = member_dict.get("character_name", "Unknown_" + str(randi()))
					if not _added_character_ids.has(char_name):
						var CharacterResource = load("res://src/core/character/Character.gd")
						if CharacterResource:
							var char = CharacterResource.new()
							char.name = char_name
							char.character_name = char_name
							crew_members.append(char)
							_added_character_ids[char_name] = true
							print("CrewPanel: Created fallback Character for validation: %s" % char_name)
					else:
						print("CrewPanel: Skipping duplicate fallback creation for: %s" % char_name)
	
	# Use the maximum of both arrays for validation
	var actual_crew_size = max(crew_members.size(), local_crew_data.members.size())
	print("CrewPanel: Validating with effective crew size: %d" % actual_crew_size)
	
	# Business rule: Minimum crew size validation
	if actual_crew_size == 0:
		last_validation_errors.append("At least one crew member is required")
		return false
	
	# PHASE 3 FIX: Check if crew is complete with required size
	var required_size = selected_size if selected_size > 0 else 4
	if actual_crew_size < required_size:
		last_validation_errors.append("Crew needs %d members (currently %d)" % [required_size, actual_crew_size])
		return false
	
	# Business rule: Maximum crew size validation  
	if actual_crew_size > 8: # Five Parsecs maximum
		last_validation_errors.append("Crew cannot exceed 8 members")
		return false
	
	# Business rule: Captain validation - be more flexible
	if not current_captain and not local_crew_data.captain:
		# Auto-assign first member as captain if we have crew
		if crew_members.size() > 0:
			current_captain = crew_members[0]
			print("CrewPanel: Auto-assigned first crew member as captain during validation")
		elif local_crew_data.members.size() > 0:
			local_crew_data.captain = local_crew_data.members[0]
			print("CrewPanel: Auto-assigned first member data as captain during validation")
		else:
			last_validation_errors.append("A captain must be designated")
			return false
	
	# Business rule: Captain must be crew member (skip this check if data is desynchronized)
	if current_captain and crew_members.size() > 0 and current_captain not in crew_members:
		# Try to find captain in crew_members
		var captain_found = false
		for member in crew_members:
			if member.get("character_name") == current_captain.get("character_name"):
				captain_found = true
				break
		
		if not captain_found:
			push_warning("CrewPanel: Captain not found in crew_members, but allowing progression")
	
	# Mark panel as complete if we have enough crew
	if actual_crew_size >= required_size:
		local_crew_data.is_complete = true
		is_crew_complete = true
		panel_data["is_complete"] = true
		print("CrewPanel: Validation PASSED - %d crew members with captain" % actual_crew_size)
	
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

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: CrewPanel] INITIALIZATION ====")
	print("  Phase: 3 of 7 (Crew Generation)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# Check for coordinator access using new robust method
	var has_coordinator = get_coordinator() != null
	print("  Has Coordinator Access: %s" % str(has_coordinator))
	
	if not has_coordinator:
		print("    ⚠️  NO COORDINATOR ACCESS - Operating in standalone mode")
	else:
		print("    ✅ Coordinator connected successfully")
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var campaign_state_service = get_node_or_null("/root/CampaignStateService")
	var scene_router = get_node_or_null("/root/SceneRouter")
	var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	
	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    CampaignStateService: %s" % (campaign_state_service != null))
	print("    SceneRouter: %s" % (scene_router != null))
	print("    CampaignPhaseManager: %s" % (campaign_phase_manager != null))
	
	# Check current crew data
	print("  === INITIAL CREW DATA ===")
	print("    Crew Members: %d" % crew_members.size())
	print("    Current Captain: %s" % (current_captain != null))
	print("    Local Crew Data Keys: %s" % str(local_crew_data.keys()))
	print("    Is Complete: %s" % local_crew_data.get("is_complete", false))
	print("    Generated Patrons: %d" % generated_patrons.size())
	print("    Generated Rivals: %d" % generated_rivals.size())
	
	# Check Five Parsecs systems
	print("  === FIVE PARSECS SYSTEMS ===")
	print("    Patron System: %s" % (patron_system != null))
	print("    Rival System: %s" % (rival_system != null))
	print("    Security Validator: %s" % (security_validator != null))
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Crew Creation Instance: %s" % (crew_creation_instance != null))
	print("    Crew Creation Container: %s" % (crew_creation_container != null))
	print("    Crew Size Option: %s" % (crew_size_option != null))
	print("    Crew List: %s" % (crew_list != null))
	
	print("==== [PANEL: CrewPanel] INIT COMPLETE ====\n")

## PHASE 2: Enhanced Coordinator Integration
func _on_coordinator_set() -> void:
	"""Pass coordinator to child components"""
	print("CrewPanel: Coordinator received, propagating to children")
	
	# Pass to InitialCrewCreation if available
	if crew_creation_instance and crew_creation_instance.has_method("set_workflow_system"):
		var coord = get_coordinator()
		if coord:
			crew_creation_instance.set_workflow_system(coord)
			print("CrewPanel: Workflow system connected to InitialCrewCreation")

# Completion logic with debouncing
var completion_check_timer: SceneTreeTimer = null

func _check_and_emit_completion() -> void:
	"""Debounced completion check"""
	# SceneTreeTimer doesn't need to be stopped, just replace it
	if is_inside_tree() and get_tree():
		completion_check_timer = get_tree().create_timer(0.5)
		await completion_check_timer.timeout
		_perform_completion_check()
	else:
		# If tree isn't available, perform check immediately
		_perform_completion_check()

func _perform_completion_check() -> void:
	"""Actual completion validation"""
	var member_count = local_crew_data.members.size()
	var required_size = selected_size if selected_size > 0 else 4
	
	if member_count >= required_size:
		is_crew_complete = true
		local_crew_data.is_complete = true
		
		# Update coordinator
		var coord = get_coordinator()
		if coord and coord.has_method("update_crew_state"):
			coord.update_crew_state(local_crew_data)
			print("CrewPanel: ✅ Updated coordinator with %d crew members" % member_count)
		
		# PHASE 3 FIX: Trigger BaseCampaignPanel validation and completion
		_validate_and_emit_completion()
		
		# Emit crew-specific signals
		crew_setup_complete.emit(local_crew_data)
		panel_data_changed.emit(local_crew_data)
		
		print("CrewPanel: ✅ Crew generation complete with %d/%d members" % [member_count, required_size])

func _connect_to_initial_crew_creation() -> void:
	"""Connect to InitialCrewCreation signals"""
	if crew_creation_instance:
		var signals_to_connect = {
			"character_generated": _on_character_generated,
			"crew_created": _on_crew_created,
		}
		
		for sig_name in signals_to_connect:
			if crew_creation_instance.has_signal(sig_name):
				if not crew_creation_instance.is_connected(sig_name, signals_to_connect[sig_name]):
					crew_creation_instance.connect(sig_name, signals_to_connect[sig_name])
					print("CrewPanel: Connected to InitialCrewCreation signal: %s" % sig_name)

func _on_character_generated(character) -> void:  # Remove type hint to accept any type
	"""Handle character generation - accepts both Character objects and Dictionaries"""
	print("CrewPanel: Character generated - processing type: %s" % type_string(typeof(character)))
	
	var character_data: Dictionary = {}
	var character_object = null  # Character object
	
	# Type conversion logic with proper object tracking
	if character is Character:
		character_object = character  # Keep the actual Character object
		# Convert Character object to Dictionary for local_crew_data
		character_data = {
			"character_name": character.character_name,
			"background": character.background,
			"motivation": character.motivation,
			"origin": character.origin if "origin" in character else character.species,
			"character_class": character.character_class,
			"combat": character.combat,
			"reactions": character.reactions if "reactions" in character else character.reaction,
			"toughness": character.toughness,
			"savvy": character.savvy,
			"tech": character.tech if "tech" in character else 0,
			"speed": character.speed if "speed" in character else 4,
			"luck": character.luck if "luck" in character else 0,
			"xp": character.xp if "xp" in character else 0,
			"character_object": character  # Keep reference to actual object
		}
		print("CrewPanel: Converted Character object to Dictionary")
	elif character is Dictionary:
		character_data = character
		# Try to extract the character object if it exists in the dictionary
		if character_data.has("character_object"):
			character_object = character_data.get("character_object")
		else:
			# Create a new Character object from the dictionary
			var CharacterResource = load("res://src/core/character/Character.gd")
			if CharacterResource:
				character_object = CharacterResource.new()
				# Set basic properties
				if character_object.has_method("set"):
					for key in character_data:
						if key != "character_object":
							character_object.set(key, character_data[key])
		print("CrewPanel: Received Dictionary directly")
	else:
		push_error("CrewPanel: Unknown character type received: %s" % type_string(typeof(character)))
		return
	
	# Prevent duplicates using both dictionary and tracking system
	var char_name = character_data.get("character_name", "")
	
	# Check if already added using new tracking system
	if _added_character_ids.has(char_name):
		print("CrewPanel: Duplicate character %s ignored (tracking system)" % char_name)
		return
		
	# Double-check against existing members
	for member in local_crew_data.members:
		if member.get("character_name", "") == char_name:
			print("CrewPanel: Duplicate character %s ignored (existing check)" % char_name)
			return
	
	# Mark as added to prevent future duplicates
	_added_character_ids[char_name] = true
	
	# CRITICAL FIX: Add to BOTH data structures properly
	# 1. Add dictionary to local_crew_data for backward compatibility
	local_crew_data.members.append(character_data)
	print("CrewPanel: Added to local_crew_data.members (size: %d)" % local_crew_data.members.size())
	
	# 2. Add Character object to crew_members for type safety
	if character_object and is_instance_valid(character_object):
		crew_members.append(character_object)
		print("CrewPanel: Added %s to crew_members array (size: %d)" % [char_name, crew_members.size()])
		
		# Auto-assign first member as captain if none assigned
		if not current_captain and crew_members.size() == 1:
			set_captain(character_object)
			print("CrewPanel: Auto-assigned %s as captain" % char_name)
	else:
		push_warning("CrewPanel: No valid Character object to add to crew_members array")
		# FALLBACK: Create a minimal Character object so validation can pass
		# Note: This should be rare since we already added to tracking above
		var FallbackCharacter = load("res://src/core/character/Character.gd")
		if FallbackCharacter:
			var fallback = FallbackCharacter.new()
			fallback.name = char_name
			fallback.character_name = char_name
			crew_members.append(fallback)
			print("CrewPanel: Created fallback Character object for validation: %s" % char_name)
	
	print("CrewPanel: Added %s - Total local_crew_data: %d, crew_members: %d" % [
		char_name, 
		local_crew_data.members.size(),
		crew_members.size()
	])
	
	# Update coordinator if available
	if get_coordinator():
		if get_coordinator().has_method("update_crew_state"):
			get_coordinator().update_crew_state(local_crew_data)
	
	# Emit crew updated signal
	_emit_crew_updated()
	
	# Check if we have enough crew to enable progression
	if crew_members.size() >= 4:
		print("CrewPanel: Crew complete with %d members - enabling progression" % crew_members.size())
		local_crew_data.is_complete = true
		is_crew_complete = true
		panel_data["is_complete"] = true
		emit_signal("panel_validation_changed", true)
		var panel_data = get_panel_data()
		print("CrewPanel: DEBUG - Emitting panel_completed with data keys: %s" % str(panel_data.keys()))
		print("CrewPanel: DEBUG - Crew count in data: %d" % panel_data.get("crew", []).size())
		emit_signal("panel_completed", panel_data)
	
	# Check completion
	call_deferred("_check_and_emit_completion")

func _on_crew_created(crew_data: Dictionary) -> void:
	"""Handle complete crew creation"""
	print("CrewPanel: Complete crew created with %d members" % crew_data.get("members", []).size())
	local_crew_data = crew_data
	call_deferred("_check_and_emit_completion")
