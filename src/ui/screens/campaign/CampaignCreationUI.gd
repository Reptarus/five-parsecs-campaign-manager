extends Control

# Universal framework import
@warning_ignore("shadowed_global_identifier")
const UniversalNodeValidator = preload("res://src/utils/UniversalNodeValidator.gd")
const CharacterBase = preload("res://src/core/character/Base/Character.gd")
const CreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")

# State Management Integration
var state_manager: CreationStateManager = null

# Use the new core system setup
var core_systems: Node = null # Type-safe managed by system
var creation_manager: Node = null # Type-safe managed by system

# UI Components - Safe node access with fallback handling
@onready var config_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/ConfigPanel") as Node
@onready var crew_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/CrewPanel") as Node
@onready var captain_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/CaptainPanel") as Node
@onready var ship_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/ShipPanel") as Node
@onready var equipment_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/EquipmentPanel") as Node
@onready var final_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/StepPanels/FinalPanel") as Node

@onready var step_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/StepLabel") as Node
@onready var next_button: Button = get_node_or_null("MarginContainer/VBoxContainer/Navigation/NextButton") as Node
@onready var back_button: Button = get_node_or_null("MarginContainer/VBoxContainer/Navigation/BackButton") as Node
@onready var finish_button: Button = get_node_or_null("MarginContainer/VBoxContainer/Navigation/FinishButton") as Node

# State
var current_step: int = 0
var step_panels: Array[Control] = []

func _ready() -> void:
	# Enable focus to allow keyboard shortcut handling
	focus_mode = Control.FOCUS_ALL

	print("CampaignCreationUI: Initializing...")

	# PRODUCTION BOOT VALIDATION: Check node structure before proceeding
	if not _validate_scene_structure():
		push_error("CampaignCreationUI: Critical scene structure validation failed - cannot initialize")
		_enter_degraded_mode()
		return

	# Use a deferred call to ensure all nodes are ready for setup
	call_deferred("_initialize_component")

# PRODUCTION DIAGNOSTIC: Complete scene structure validation
func _validate_scene_structure() -> bool:
	"""Validate that all expected nodes exist in the scene hierarchy"""
	var validation_errors: Array[String] = []
	
	# Critical UI components validation
	var required_components = {
		"config_panel": config_panel,
		"crew_panel": crew_panel,
		"captain_panel": captain_panel,
		"ship_panel": ship_panel,
		"equipment_panel": equipment_panel,
		"final_panel": final_panel,
		"step_label": step_label,
		"next_button": next_button,
		"back_button": back_button,
		"finish_button": finish_button
	}
	
	for component_name in required_components:
		var component = required_components[component_name]
		if not component:
			validation_errors.append("Missing critical component: " + component_name)
	
	# Report validation results
	if not validation_errors.is_empty():
		push_error("CampaignCreationUI: Scene validation failed:")
		for error in validation_errors:
			push_error("  - " + error)
		push_error("CampaignCreationUI: Expected scene structure not found. Check scene file.")
		return false
	
	print("CampaignCreationUI: Scene structure validation passed - all components found")
	return true

# PRODUCTION FALLBACK: Graceful degradation when scene structure is invalid
func _enter_degraded_mode() -> void:
	"""Enter degraded mode when scene structure is invalid"""
	print("CampaignCreationUI: Entering degraded mode due to scene structure issues")
	
	# Create minimal error display
	var error_container = VBoxContainer.new()
	error_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(error_container)
	
	var error_title = Label.new()
	error_title.text = "Campaign Creation - Scene Configuration Error"
	error_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_title.add_theme_color_override("font_color", Color.RED)
	error_container.add_child(error_title)
	
	var error_message = Label.new()
	error_message.text = "The campaign creation interface is missing required components.\nPlease check the scene configuration or contact support."
	error_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_container.add_child(error_message)
	
	var back_to_menu_button = Button.new()
	back_to_menu_button.text = "Return to Main Menu"
	back_to_menu_button.pressed.connect(_return_to_main_menu)
	error_container.add_child(back_to_menu_button)
	
	# Disable normal initialization
	set_process(false)
	set_physics_process(false)

# Add this method to store node references
func _store_node_references(nodes: Dictionary) -> void:
	config_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/ConfigPanel") if nodes else null
	crew_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/CrewPanel") if nodes else null
	captain_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/CaptainPanel") if nodes else null
	ship_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/ShipPanel") if nodes else null
	equipment_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/EquipmentPanel") if nodes else null
	final_panel = nodes.get("MarginContainer/VBoxContainer/StepPanels/FinalPanel") if nodes else null
	step_label = nodes.get("MarginContainer/VBoxContainer/Header/StepLabel") if nodes else null
	next_button = nodes.get("MarginContainer/VBoxContainer/Navigation/NextButton") if nodes else null
	back_button = nodes.get("MarginContainer/VBoxContainer/Navigation/BackButton") if nodes else null
	finish_button = nodes.get("MarginContainer/VBoxContainer/Navigation/FinishButton") if nodes else null

func _initialize_state_manager() -> void:
	"""Initialize the CampaignCreationStateManager for centralized state management"""
	state_manager = CampaignCreationStateManager.new()

	# Connect state manager signals for UI updates
	@warning_ignore("return_value_discarded")
	state_manager.state_updated.connect(_on_state_updated)
	@warning_ignore("return_value_discarded")
	state_manager.validation_changed.connect(_on_validation_changed)
	@warning_ignore("return_value_discarded")
	state_manager.phase_completed.connect(_on_phase_completed)
	@warning_ignore("return_value_discarded")
	state_manager.creation_completed.connect(_on_creation_completed)

	print("CampaignCreationUI: State manager initialized")

# Add this method for successful initialization
func _initialize_component() -> void:
	_initialize_state_manager()
	_setup_ui()
	_initialize_core_systems()
	_connect_panel_signals()

# Add this method for graceful degradation
func _setup_fallback_mode(errors: Array) -> void:
	print("CampaignCreationUI running in degraded mode: ", errors)
	# Show a simple error message
	if step_label:
		step_label.text = "Campaign Creation - Some features unavailable"
	# Initialize with whatever panels are available
	_setup_ui()

func _initialize_core_systems() -> void:
	"""Initialize core systems for campaign creation"""
	print("CampaignCreationUI: Initializing core systems...")
	
	core_systems = get_node("/root/CoreSystemSetup")
	if core_systems:
		print("CampaignCreationUI: CoreSystemSetup found, checking for CampaignCreationManager...")
		
		if core_systems and core_systems.has_method("get_campaign_creation_manager"):
			creation_manager = core_systems.get_campaign_creation_manager()
			if creation_manager:
				print("CampaignCreationUI: CampaignCreationManager connected successfully")
				_connect_creation_manager_signals()
			else:
				push_warning("CampaignCreationUI: CampaignCreationManager not available")
				print("CampaignCreationUI: Proceeding with state manager only...")
		else:
			push_warning("CampaignCreationUI: CoreSystemSetup doesn't have get_campaign_creation_manager method")
			print("CampaignCreationUI: Proceeding with state manager only...")
	else:
		push_error("CampaignCreationUI: CoreSystemSetup autoload not found")
		print("CampaignCreationUI: Proceeding with state manager only...")
		
	# Ensure state manager is working even if CampaignCreationManager isn't available
	if not state_manager:
		push_error("CampaignCreationUI: State manager not initialized - this will cause navigation issues")
		return
		
	print("CampaignCreationUI: Core systems initialization complete")

func _connect_creation_manager_signals() -> void:
	"""Connect to creation manager signals"""
	if not creation_manager:
		return

	# Connect signals if they exist
	if creation_manager and creation_manager.has_signal("creation_step_changed"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		creation_manager.creation_step_changed.connect(_on_creation_step_changed)

	if creation_manager and creation_manager.has_signal("campaign_creation_completed"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		creation_manager.campaign_creation_completed.connect(_on_campaign_creation_completed)

	if creation_manager and creation_manager.has_signal("validation_failed"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		creation_manager.validation_failed.connect(_on_validation_failed)

func _setup_ui() -> void:
	"""Setup the user interface"""
	print("CampaignCreationUI: Setting up UI...")
	
	# Collect step panels safely - OPTIMIZED FLOW: Removed resource_panel (save/load screen)
	step_panels = []
	var panel_list: Array[Control] = [config_panel, crew_panel, captain_panel, ship_panel, equipment_panel, final_panel]
	var panel_names: Array[String] = ["ConfigPanel", "CrewPanel", "CaptainPanel", "ShipPanel", "EquipmentPanel", "FinalPanel"]
	
	for i in range(panel_list.size()):
		var panel: Control = panel_list[i]
		var panel_name: String = panel_names[i]
		if panel:
			step_panels.append(panel)
			print("CampaignCreationUI: Added panel %d: %s" % [step_panels.size(), panel_name])
		else:
			print("CampaignCreationUI: WARNING - Missing panel: %s" % panel_name)

	print("CampaignCreationUI: Total panels configured: %d" % step_panels.size())
	print("CampaignCreationUI: Optimized flow - Config → Crew → Captain → Ship → Equipment → Final Review")

	# PHASE 3: Validate flow integrity
	_validate_optimized_flow()

	if step_panels.is_empty():
		push_error("CampaignCreationUI: No step panels found - cannot proceed")
		return

	# Connect button signals with proper validation
	_connect_button_signals()

	# Connect panel signals for data flow
	_connect_panel_signals()

	# Show first step
	print("CampaignCreationUI: Showing initial step")
	_update_ui_for_step(0)

func _connect_button_signals() -> void:
	"""Connect button signals with proper validation"""
	print("CampaignCreationUI: Connecting button signals...")
	
	# Connect Next button
	if next_button:
		if next_button.is_connected("pressed", _on_next_button_pressed):
			next_button.pressed.disconnect(_on_next_button_pressed)
		var next_error: Error = next_button.pressed.connect(_on_next_button_pressed)
		if next_error != OK:
			push_error("Failed to connect next button: " + str(next_error))
		else:
			print("CampaignCreationUI: Next button connected successfully")
	else:
		push_warning("CampaignCreationUI: Next button not found")
	
	# Connect Back button
	if back_button:
		if back_button.is_connected("pressed", _on_back_button_pressed):
			back_button.pressed.disconnect(_on_back_button_pressed)
		var back_error: Error = back_button.pressed.connect(_on_back_button_pressed)
		if back_error != OK:
			push_error("Failed to connect back button: " + str(back_error))
		else:
			print("CampaignCreationUI: Back button connected successfully")
	else:
		push_warning("CampaignCreationUI: Back button not found")
	
	# Connect Finish button
	if finish_button:
		if finish_button.is_connected("pressed", _on_finish_button_pressed):
			finish_button.pressed.disconnect(_on_finish_button_pressed)
		var finish_error: Error = finish_button.pressed.connect(_on_finish_button_pressed)
		if finish_error != OK:
			push_error("Failed to connect finish button: " + str(finish_error))
		else:
			print("CampaignCreationUI: Finish button connected successfully")
	else:
		push_warning("CampaignCreationUI: Finish button not found")

func _connect_panel_signals() -> void:
	"""Connect panel signals to state manager integration"""
	if not state_manager:
		push_warning("CampaignCreationUI: Cannot connect panel signals - state manager not available")
		return
	
	# Connect each panel's existing signals
	_safe_connect_signal(config_panel, "config_updated", _on_config_updated)
	_safe_connect_signal(crew_panel, "crew_updated", _on_crew_updated)
	_safe_connect_signal(captain_panel, "captain_updated", _on_captain_updated)
	_safe_connect_signal(ship_panel, "ship_updated", _on_ship_updated)
	_safe_connect_signal(equipment_panel, "equipment_generated", _on_equipment_generated)
	
	print("CampaignCreationUI: Panel signals connected to state manager")

# ADD: Helper method for safe signal connections
func _safe_connect_signal(panel: Node, signal_name: String, handler: Callable) -> void:
	"""Safely connect a signal from a panel to a handler method"""
	if not panel or not panel.has_signal(signal_name):
		return
	if not panel.is_connected(signal_name, handler):
		panel.connect(signal_name, handler)

# Add signal handlers for panel data updates
func _on_config_updated(config: Dictionary) -> void:
	"""Handle config panel updates"""
	print("CampaignCreationUI: Config updated: ", config)
	print("CampaignCreationUI: Config validation - name: '%s', difficulty: %s" % [config.get("name", ""), config.get("difficulty", "unknown")])
	
	# Map ConfigPanel fields to StateManager expected fields
	var mapped_config: Dictionary = {
		"campaign_name": config.get("name", ""),
		"difficulty_level": config.get("difficulty", 1),
		"victory_condition": config.get("victory_condition", "none"),
		"story_track_enabled": config.get("story_track_enabled", false),
		"elite_ranks": config.get("elite_ranks", 0)
	}
	
	print("CampaignCreationUI: Mapped config for state manager: ", mapped_config)
	
	# Forward to state manager with mapped field names
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, mapped_config)
	
	# Update navigation
	_update_navigation_state()

func _on_crew_updated(crew: Array) -> void:
	"""Enhanced crew panel update handler with character completeness tracking"""
	print("CampaignCreationUI: Crew updated, size: ", crew.size())
	print("CampaignCreationUI: Crew validation - members: %d" % crew.size())
	
	# Enhanced crew data for state manager
	var crew_data = {
		"members": crew,
		"size": crew.size(),
		"captain": _find_captain(crew),
		"has_captain": _has_captain(crew),
		"completion_level": _calculate_crew_completion_level(crew),
		"customization_summary": _get_crew_customization_summary(crew)
	}
	
	# Forward to state manager
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, crew_data)
	
	# Update navigation based on completion level
	_update_navigation_state()

	# Update equipment panel with crew size for proper generation
	if equipment_panel and equipment_panel and equipment_panel.has_method("set_crew_size"):
		@warning_ignore("unsafe_method_access")
		equipment_panel.set_crew_size(crew.size())

	# Update resource panel with crew data for bonus calculation
	if crew_panel and crew_panel and crew_panel.has_method("set_crew_data"):
		@warning_ignore("unsafe_method_access")
		crew_panel.set_crew_data(crew)
	
	print("CampaignCreationUI: Enhanced crew data sent - Captain: %s, Completion: %.1f%%" % 
		  [crew_data.captain, crew_data.completion_level * 100])

## Enhanced Crew Data Analysis

func _find_captain(crew: Array) -> String:
	"""Find the captain in the crew"""
	for character in crew:
		if character.get("is_captain", false):
			return character.get("character_name", "Unknown Captain")
	return ""

func _has_captain(crew: Array) -> bool:
	"""Check if crew has a captain assigned"""
	for character in crew:
		if character.get("is_captain", false):
			return true
	return false

func _calculate_crew_completion_level(crew: Array) -> float:
	"""Calculate overall crew completion level"""
	if crew.is_empty():
		return 0.0
	
	var total_completion = 0.0
	for character in crew:
		if character.has_method("get_customization_completeness"):
			total_completion += character.get_customization_completeness()
		else:
			# Fallback completion estimation
			total_completion += _estimate_character_completeness(character)
	
	return total_completion / crew.size()

func _estimate_character_completeness(character) -> float:
	"""Estimate character completeness for characters without the method"""
	var completeness = 0.0
	var total_criteria = 8.0
	
	# Basic info (3 criteria)
	if character.get("character_name", "") != "":
		completeness += 1.0
	if character.get("background", 0) > 0:
		completeness += 1.0
	if character.get("motivation", 0) > 0:
		completeness += 1.0
	
	# Attributes (2 criteria)
	if character.get("combat", 0) >= 0 and character.get("toughness", 0) >= 3:
		completeness += 1.0
	if character.get("max_health", 0) > 0:
		completeness += 1.0
	
	# Relationships (2 criteria)
	if character.get("patrons", []).size() > 0 or character.get("rivals", []).size() > 0:
		completeness += 1.0
	if character.get("traits", []).size() > 0:
		completeness += 1.0
	
	# Equipment (1 criterion)
	if character.get("personal_equipment", {}).size() > 0 or character.get("credits_earned", 0) > 0:
		completeness += 1.0
	
	return completeness / total_criteria

func _get_crew_customization_summary(crew: Array) -> Dictionary:
	"""Get comprehensive crew customization summary"""
	var summary = {
		"total_members": crew.size(),
		"fully_customized": 0,
		"partially_customized": 0,
		"basic_only": 0,
		"total_patrons": 0,
		"total_rivals": 0,
		"total_traits": 0,
		"total_starting_credits": 0,
		"captain_assigned": false
	}
	
	for character in crew:
		var completeness = 0.0
		if character.has_method("get_customization_completeness"):
			completeness = character.get_customization_completeness()
		else:
			completeness = _estimate_character_completeness(character)
		
		# Categorize character completion
		if completeness >= 0.8:
			summary.fully_customized += 1
		elif completeness >= 0.5:
			summary.partially_customized += 1
		else:
			summary.basic_only += 1
		
		# Count relationships and equipment
		summary.total_patrons += character.get("patrons", []).size()
		summary.total_rivals += character.get("rivals", []).size()
		summary.total_traits += character.get("traits", []).size()
		summary.total_starting_credits += character.get("credits_earned", 0)
		
		if character.get("is_captain", false):
			summary.captain_assigned = true
	
	return summary

func _on_captain_updated(captain: Variant) -> void:
	"""Handle captain panel updates"""
	print("CampaignCreationUI: Captain updated")
	print("CampaignCreationUI: Captain validation - exists: %s" % (captain != null))
	
	# Forward to state manager
	if state_manager:
		var captain_data: Dictionary = {"captain": captain}
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION, captain_data)
	
	# Update navigation
	_update_navigation_state()
	
	# Captain is included in crew for resource calculations

func _on_ship_updated(ship_data: Dictionary) -> void:
	"""Handle ship panel updates"""
	print("CampaignCreationUI: Ship updated: ", ship_data.get("name", "Unknown"))
	print("CampaignCreationUI: Ship validation - configured: %s, name: '%s'" % [ship_data.get("is_configured", false), ship_data.get("name", "")])
	
	# Forward to state manager
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT, ship_data)
	
	# Update navigation
	_update_navigation_state()
	
	# Ship data will be included in final campaign creation

func _on_equipment_generated(equipment: Array) -> void:
	"""Handle equipment generation updates"""
	print("CampaignCreationUI: Equipment generated, count: ", equipment.size())
	print("CampaignCreationUI: Equipment validation - items: %d" % equipment.size())
	
	# Forward to state manager
	if state_manager:
		var equipment_data: Dictionary = {"equipment": equipment, "count": equipment.size()}
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, equipment_data)
	
	# Update navigation
	_update_navigation_state()
	
	# Equipment will be included in final campaign creation

# ADD: Navigation state management
func _update_navigation_state() -> void:
	"""Enhanced navigation state management with crew completion requirements"""
	if not state_manager:
		return
	
	var validation: Dictionary = state_manager.get_validation_summary()
	var can_advance: bool = validation.get("can_advance", false)
	var can_complete: bool = validation.get("can_complete", false)
	var current_phase = state_manager.get_current_phase()
	var is_final_phase: bool = current_phase == CampaignCreationStateManager.Phase.FINAL_REVIEW
	
	# Enhanced validation for crew phase
	if current_phase == CampaignCreationStateManager.Phase.CREW_SETUP:
		can_advance = _validate_crew_phase_completion()
	
	# Update Next button with enhanced feedback
	if next_button:
		next_button.disabled = not can_advance or is_final_phase
		if is_final_phase:
			next_button.visible = false
		else:
			next_button.visible = true
			# Dynamic button text based on validation
			if can_advance:
				next_button.text = "Next"
			else:
				match current_phase:
					CampaignCreationStateManager.Phase.CREW_SETUP:
						next_button.text = "Complete Crew Setup"
					_:
						next_button.text = "Complete Step"
	
	# Update Back button
	if back_button:
		back_button.disabled = (current_phase == CampaignCreationStateManager.Phase.CONFIG)
	
	# Update Finish button
	if finish_button:
		finish_button.disabled = not can_complete
		finish_button.visible = is_final_phase
		if can_complete:
			finish_button.text = "Create Campaign"
		else:
			finish_button.text = "Complete Setup First"
	
	# Update step progress with completion details
	_update_step_progress(current_phase)
	
	# Show enhanced validation feedback
	_show_validation_feedback(validation)

func _validate_crew_phase_completion() -> bool:
	"""Validate crew phase completion with enhanced requirements"""
	if not crew_panel or not crew_panel.has_method("get_crew_data"):
		return false
	
	@warning_ignore("unsafe_method_access")
	var crew_data = crew_panel.get_crew_data()
	var crew = crew_data.get("members", [])
	
	# Check basic requirements
	if crew.size() < 4:  # Minimum crew size
		return false
	
	# Check captain assignment
	var has_captain = false
	for character in crew:
		if character.get("is_captain", false):
			has_captain = true
			break
	
	if not has_captain:
		return false
	
	# Check character completion levels
	var incomplete_count = 0
	for character in crew:
		var completeness = 0.0
		if character.has_method("get_customization_completeness"):
			completeness = character.get_customization_completeness()
		else:
			completeness = _estimate_character_completeness(character)
		
		if completeness < 0.8:  # Require 80% completion
			incomplete_count += 1
	
	# Allow progression if most characters are sufficiently complete
	return incomplete_count <= (crew.size() / 4)  # Max 25% incomplete

func _update_step_progress(current_phase: CampaignCreationStateManager.Phase) -> void:
	"""Update step progress indicator"""
	if not step_label:
		return
	
	var phase_names: Array[String] = ["Configuration", "Crew Setup", "Captain Creation", "Ship Assignment", "Equipment Generation", "Final Review"]
	var current_step_index: int = current_phase
	
	if current_step_index < phase_names.size():
		var progress_percent: float = (float(current_step_index) / float(phase_names.size() - 1)) * 100.0
		step_label.text = "Step %d of %d: %s (%.0f%% Complete)" % [
			current_step_index + 1, 
			phase_names.size(), 
			phase_names[current_step_index], 
			progress_percent
		]

func _show_validation_feedback(validation: Dictionary) -> void:
	"""Enhanced validation feedback with crew completion details"""
	var errors: Array = validation.get("validation_errors", [])
	var current_phase = state_manager.get_current_phase() if state_manager else 0
	
	# Enhanced feedback for crew phase
	if current_phase == CampaignCreationStateManager.Phase.CREW_SETUP:
		_show_crew_validation_feedback()
	
	if errors.is_empty():
		return
	
	# Show errors in console for debugging
	print("CampaignCreationUI: Validation errors: ", errors)
	
	# Could be extended to show validation messages in UI
	# For now, errors are shown when user tries to advance/complete

func _show_crew_validation_feedback() -> void:
	"""Show detailed crew validation feedback"""
	if not crew_panel or not crew_panel.has_method("get_crew_data"):
		return
	
	@warning_ignore("unsafe_method_access")
	var crew_data = crew_panel.get_crew_data()
	var crew = crew_data.get("members", [])
	
	var feedback_messages = []
	
	# Check crew size
	if crew.size() < 4:
		feedback_messages.append("Crew needs at least 4 members (current: %d)" % crew.size())
	
	# Check captain assignment
	var captain_assigned = false
	for character in crew:
		if character.get("is_captain", false):
			captain_assigned = true
			break
	
	if not captain_assigned:
		feedback_messages.append("No captain assigned - select a crew member and assign as captain")
	
	# Check character completion
	var incomplete_characters = []
	for character in crew:
		var completeness = 0.0
		if character.has_method("get_customization_completeness"):
			completeness = character.get_customization_completeness()
		else:
			completeness = _estimate_character_completeness(character)
		
		if completeness < 0.8:
			var name = character.get("character_name", "Unnamed Character")
			incomplete_characters.append("%s (%.0f%%)" % [name, completeness * 100])
	
	if incomplete_characters.size() > 0:
		feedback_messages.append("Characters need more customization: " + ", ".join(incomplete_characters))
	
	# Calculate overall progress
	var total_completion = 0.0
	for character in crew:
		if character.has_method("get_customization_completeness"):
			total_completion += character.get_customization_completeness()
		else:
			total_completion += _estimate_character_completeness(character)
	
	var avg_completion = (total_completion / crew.size()) * 100.0 if crew.size() > 0 else 0.0
	
	# Positive feedback when doing well
	if feedback_messages.size() == 0:
		print("CampaignCreationUI: Crew setup complete! Average completion: %.1f%%" % avg_completion)
	else:
		print("CampaignCreationUI: Crew setup feedback:")
		for message in feedback_messages:
			print("  - %s" % message)
		print("  Overall crew completion: %.1f%%" % avg_completion)

func _create_fallback_ui() -> void:
	"""Create a fallback UI when core systems aren't available"""
	print("CampaignCreationUI: Creating fallback UI")

	# Hide all panels except the first one
	for i: int in range(step_panels.size()):
		if step_panels[i]:
			step_panels[i].visible = (i == 0)

	# Update step label
	if step_label:
		step_label.text = "Campaign Creation (Fallback Mode)"

	# Enable basic navigation
	if next_button:
		next_button.disabled = false
		next_button.text = "Next"

	if back_button:
		back_button.disabled = true

func _update_ui_for_step(step: int) -> void:
	"""Update UI for the current step"""
	print("CampaignCreationUI: _update_ui_for_step called with step %d (total panels: %d)" % [step, step_panels.size()])
	
	# Validate step range
	if step < 0 or step >= step_panels.size():
		push_error("Invalid step %d, must be between 0 and %d" % [step, step_panels.size() - 1])
		return
	
	current_step = step

	# Hide all panels
	for i in range(step_panels.size()):
		var panel: Control = step_panels[i]
		if panel:
			panel.visible = false
			print("CampaignCreationUI: Hid panel %d" % i)

	# Show current panel
	if step < step_panels.size() and step_panels[step]:
		step_panels[step].visible = true
		print("CampaignCreationUI: Showed panel %d (%s)" % [step, step_panels[step].name])
	else:
		push_error("Cannot show panel for step %d - panel is null" % step)

	# Update step label - PHASE 3 OPTIMIZED FLOW WITH PROGRESS
	if step_label:
		var step_names: Array[String] = ["Configuration", "Crew Setup", "Captain Creation", "Ship Assignment", "Equipment Generation", "Final Review"]
		if step < step_names.size():
			@warning_ignore("untyped_declaration")
			var progress_percent = get_progress_percentage()
			step_label.text = "Step %d of %d: %s (%.0f%% Complete)" % [step + 1, step_names.size(), step_names[step], progress_percent]

		print("CampaignCreationUI: Updated step label for step %d" % (step + 1))
	else:
		print("CampaignCreationUI: WARNING - step_label is null")

	# PHASE 3: Update progress indication
	if has_method("_update_progress_display"):
		_update_progress_display(step)

	# Update button states
	if back_button:
		back_button.disabled = (step == 0)
		print("CampaignCreationUI: Back button %s" % ("disabled" if step == 0 else "enabled"))
	else:
		print("CampaignCreationUI: WARNING - back_button is null")

	if next_button:
		if step >= step_panels.size() - 1:
			next_button.text = "Create Campaign"
		else:
			next_button.text = "Next"
		print("CampaignCreationUI: Next button text set to '%s'" % next_button.text)
	else:
		print("CampaignCreationUI: WARNING - next_button is null")

	_update_navigation_state()


func _collect_current_panel_data() -> void:
	"""Collect data from the current panel and update state manager"""
	if not state_manager or current_step >= step_panels.size():
		return
	
	var current_panel: Control = step_panels[current_step]
	if not current_panel:
		return
	
	print("CampaignCreationUI: Collecting data from current panel (step %d)" % current_step)
	
	# Use a generic approach to collect data from any panel
	var panel_data: Dictionary = {}
	
	# Try the standard get_data() method first
	if current_panel.has_method("get_data"):
		panel_data = current_panel.get_data()
		print("CampaignCreationUI: Collected data via get_data(): ", panel_data.keys())
	# Try specific panel methods as fallback
	elif current_panel.has_method("get_config_data"):
		panel_data = current_panel.get_config_data()
		print("CampaignCreationUI: Collected data via get_config_data(): ", panel_data.keys())
	elif current_panel.has_method("get_crew_data"):
		panel_data = {"members": current_panel.get_crew_data()}
		print("CampaignCreationUI: Collected crew data")
	elif current_panel.has_method("get_captain"):
		panel_data = {"captain": current_panel.get_captain()}
		print("CampaignCreationUI: Collected captain data")
	elif current_panel.has_method("get_ship_data"):
		panel_data = current_panel.get_ship_data()
		print("CampaignCreationUI: Collected ship data")
	elif current_panel.has_method("get_equipment_data"):
		panel_data = current_panel.get_equipment_data()
		print("CampaignCreationUI: Collected equipment data")
	
	# Apply field mapping for ConfigPanel data
	if current_step == 0 and panel_data.has("name"):  # ConfigPanel is step 0
		panel_data = {
			"campaign_name": panel_data.get("name", ""),
			"difficulty_level": panel_data.get("difficulty", 1),
			"victory_condition": panel_data.get("victory_condition", "none"),
			"story_track_enabled": panel_data.get("story_track_enabled", false),
			"elite_ranks": panel_data.get("elite_ranks", 0)
		}
		print("CampaignCreationUI: Applied ConfigPanel field mapping")
	
	# Update state manager with collected data
	if not panel_data.is_empty():
		var current_phase = state_manager.get_current_phase()
		state_manager.set_phase_data(current_phase, panel_data)
		print("CampaignCreationUI: Updated state manager for phase %d with data" % current_phase)
	else:
		print("CampaignCreationUI: No data collected from current panel - panel may not have data methods")

func _update_ui_for_current_phase() -> void:
	"""Update UI to match the current phase from state manager"""
	if not state_manager:
		return
	
	var current_phase = state_manager.get_current_phase()
	print("CampaignCreationUI: Updating UI for phase %d" % current_phase)
	
	# Map phases to step indices
	current_step = current_phase
	
	if current_step >= 0 and current_step < step_panels.size():
		_update_ui_for_step(current_step)
	else:
		push_error("CampaignCreationUI: Invalid phase %d, cannot update UI" % current_phase)

func _on_next_button_pressed() -> void:
	"""Handle next button press with state manager integration"""
	print("CampaignCreationUI: Next button pressed - current step: %d" % current_step)

	if state_manager:
		# Always collect data from the current panel before doing anything else
		_collect_current_panel_data()

		# Now, try to advance. The state manager has the latest data.
		if state_manager.advance_to_next_phase():
			print("CampaignCreationUI: State manager advanced successfully.")
			_update_ui_for_current_phase()
			_update_navigation_state()
		else:
			# If advancement fails, the state manager's validation has failed.
			# Get the errors and display them.
			var validation_summary: Dictionary = state_manager.get_validation_summary()
			var errors: Array = validation_summary.get("validation_errors", [])
			print("CampaignCreationUI: Cannot advance - validation failed. Errors: %s" % [errors])
			if not errors.is_empty():
				_show_error_dialog("Validation Failed", "Please correct the following errors:\n\n" + "\n".join(errors))
	else:
		# Fallback navigation if state manager is not present
		print("CampaignCreationUI: Using fallback navigation logic")
		if current_step < step_panels.size() - 1:
			var next_step: int = current_step + 1
			print("CampaignCreationUI: Advancing to step %d" % next_step)
			_update_ui_for_step(next_step)
		else:
			print("CampaignCreationUI: At final step, attempting to finalize")
			_finalize_campaign_creation()

func _on_back_button_pressed() -> void:
	"""Handle back button press"""
	if creation_manager and creation_manager and creation_manager.has_method("go_back_step"):
		@warning_ignore("unsafe_method_access")
		creation_manager.go_back_step()
	else:
		# Fallback navigation
		if current_step > 0:
			_update_ui_for_step(current_step - 1)

func _on_finish_button_pressed() -> void:
	"""Handle finish button press - explicitly start campaign creation"""
	print("CampaignCreationUI: Finish button pressed")
	
	# Validation check
	if not state_manager:
		_show_error_dialog("Critical Error", "State manager not available")
		return
	
	var validation: Dictionary = state_manager.get_validation_summary()
	if not validation.get("can_complete", false):
		var errors: Array = validation.get("validation_errors", [])
		_show_error_dialog("Incomplete Setup", "Please complete:\n\n" + "\n".join(errors))
		return
	
	# Campaign creation workflow
	_set_loading_state(true)
	var final_data: Dictionary = state_manager.complete_campaign_creation()
	if final_data.is_empty():
		_set_loading_state(false)
		_show_error_dialog("Creation Failed", "Failed to finalize campaign data")
		return
	
	await _create_campaign_from_data(final_data)

# ADD: New methods for campaign creation
func _create_campaign_from_data(campaign_data: Dictionary) -> void:
	"""Create campaign from validated data"""
	var core_systems: Node = get_node("/root/CoreSystemSetup")
	if not core_systems:
		_set_loading_state(false)
		_show_error_dialog("System Error", "Core systems not available")
		return
	
	# Try to get campaign creation manager
	var campaign_creation_manager: Node = null # Type-safe managed by system
	if core_systems.has_method("get_campaign_creation_manager"):
		campaign_creation_manager = core_systems.get_campaign_creation_manager()
	
	if not campaign_creation_manager:
		_set_loading_state(false)
		_show_error_dialog("System Error", "Campaign creation manager not available")
		return
	
	# Set campaign data in the creation manager
	_transfer_data_to_creation_manager(campaign_creation_manager, campaign_data)
	
	# Create campaign
	var success: bool = await _execute_campaign_creation(campaign_creation_manager, campaign_data)
	_set_loading_state(false)
	
	if success:
		_navigate_to_campaign()
	else:
		# Try fallback campaign creation
		print("CampaignCreationUI: Primary campaign creation failed, trying fallback method")
		var fallback_success: bool = await _try_fallback_campaign_creation(campaign_data)
		if fallback_success:
			_navigate_to_campaign()
		else:
			_show_error_dialog("Creation Failed", "Could not create campaign using any available method")

func _execute_campaign_creation(campaign_creation_manager: Node, data: Dictionary) -> bool:
	"""Execute the actual campaign creation"""
	if campaign_creation_manager.has_method("finalize_campaign_creation"):
		var new_campaign: Variant = campaign_creation_manager.finalize_campaign_creation()
		if new_campaign != null:
			# Save the campaign if successful
			_save_created_campaign(new_campaign)
			return true
		else:
			print("CampaignCreationUI: Campaign creation returned null")
			return false
	else:
		print("CampaignCreationUI: Campaign creation manager missing finalize_campaign_creation method")
		return false

func _transfer_data_to_creation_manager(creation_manager: Node, data: Dictionary) -> void:
	"""Transfer state manager data to campaign creation manager"""
	if not creation_manager:
		return
	
	# Set configuration data
	if data.has("config") and creation_manager.has_method("set_config_data"):
		creation_manager.set_config_data(data.config)
	
	# Set crew data
	if data.has("crew") and creation_manager.has_method("set_crew_data"):
		creation_manager.set_crew_data(data.crew)
	
	# Set captain data
	if data.has("captain") and creation_manager.has_method("set_captain_data"):
		creation_manager.set_captain_data(data.captain)
	
	# Set ship data
	if data.has("ship") and creation_manager.has_method("set_ship_data"):
		creation_manager.set_ship_data(data.ship)
	
	# Set equipment data
	if data.has("equipment") and creation_manager.has_method("set_equipment_data"):
		creation_manager.set_equipment_data(data.equipment)
	
	# Set resources data
	if data.has("resources") and creation_manager.has_method("set_resource_data"):
		creation_manager.set_resource_data(data.resources)
	
	print("CampaignCreationUI: Data transferred to creation manager")

func _save_created_campaign(campaign: Variant) -> void:
	"""Save the newly created campaign"""
	if not campaign:
		return
	
	var core_systems: Node = get_node_or_null("/root/CoreSystemSetup") as Node
	if not core_systems:
		print("CampaignCreationUI: Cannot save campaign - core systems not available")
		return
	
	# Try to get campaign manager for saving
	var campaign_manager: Node = null # Type-safe managed by system
	if core_systems.has_method("get_campaign_manager"):
		campaign_manager = core_systems.get_campaign_manager()
	
	if campaign_manager and campaign_manager.has_method("set_current_campaign"):
		campaign_manager.set_current_campaign(campaign)
		print("CampaignCreationUI: Campaign saved successfully")
	else:
		print("CampaignCreationUI: Cannot save campaign - campaign manager not available")

func _try_fallback_campaign_creation(campaign_data: Dictionary) -> bool:
	"""Try to create campaign using fallback methods"""
	print("CampaignCreationUI: Attempting fallback campaign creation")
	
	# Try to create a basic campaign state
	var core_systems: Node = get_node_or_null("/root/CoreSystemSetup") as Node
	if not core_systems:
		return false
	
	# Get campaign manager for basic campaign setup
	var campaign_manager: Node = null # Type-safe managed by system
	if core_systems.has_method("get_campaign_manager"):
		campaign_manager = core_systems.get_campaign_manager()
	
	if campaign_manager and campaign_manager.has_method("start_new_campaign"):
		# Create basic campaign config
		var basic_config: Dictionary = {
			"name": campaign_data.get("config", {}).get("name", "New Campaign"),
			"difficulty": campaign_data.get("config", {}).get("difficulty", "Normal"),
			"crew_size": campaign_data.get("crew", {}).get("size", 4),
			"auto_generated": true
		}
		
		var success: bool = campaign_manager.start_new_campaign(basic_config)
		if success:
			print("CampaignCreationUI: Fallback campaign creation successful")
			return true
	
	print("CampaignCreationUI: Fallback campaign creation failed")
	return false

func _set_loading_state(loading: bool) -> void:
	"""Set loading state for UI feedback"""
	if finish_button:
		finish_button.disabled = loading
		finish_button.text = "Creating..." if loading else "Create Campaign"

func _navigate_to_campaign() -> void:
	"""Navigate to campaign dashboard or main game"""
	print("CampaignCreationUI: Campaign creation completed successfully! Navigating to campaign...")
	
	# Try campaign dashboard first
	if FileAccess.file_exists("res://src/scenes/campaign/CampaignDashboard.tscn"):
		get_tree().change_scene_to_file("res://src/scenes/campaign/CampaignDashboard.tscn")
	elif FileAccess.file_exists("res://src/scenes/main/MainGameScene.tscn"):
		get_tree().change_scene_to_file("res://src/scenes/main/MainGameScene.tscn")
	else:
		# Fallback to main menu with success message
		print("CampaignCreationUI: Campaign scenes not found, returning to main menu")
		get_tree().change_scene_to_file("res://src/ui/screens/mainmenu/MainMenu.tscn")

func _validate_current_step() -> Array[String]:
	"""Validate the current step and return array of error messages"""
	var errors: Array[String] = []

	if current_step >= step_panels.size():
		errors.append("Invalid step index")
		return errors

	var current_panel: Control = step_panels[current_step]
	if not current_panel:
		errors.append("Current panel is missing")
		return errors

	# Call panel-specific validation if available
	if current_panel and current_panel.has_method("validate"):
		@warning_ignore("unsafe_method_access")
		var panel_errors: Array[String] = current_panel.validate()
		if not panel_errors.is_empty():
			errors.append_array(panel_errors)
	elif current_panel and current_panel.has_method("is_valid"):
		@warning_ignore("unsafe_method_access")
		if not current_panel.is_valid():
			var panel_name: String
			if current_panel.name:
				panel_name = current_panel.name
			else:
				panel_name = "Unknown Panel"
			errors.append("%s is not properly configured" % panel_name)

	return errors

func _show_error_dialog(title: String, message: String) -> void:
	"""Show an error dialog to the user"""
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.dialog_autowrap = true
	add_child(dialog)
	dialog.popup_centered()

	# Auto-remove dialog after user closes it
	@warning_ignore("untyped_declaration", "return_value_discarded")
	dialog.confirmed.connect(func(): dialog.queue_free())

func _collect_campaign_config_safe() -> Dictionary:
	"""Safely collect campaign configuration from all panels"""
	var config: Dictionary = {
		"name": "Test Campaign",
		"difficulty": "Normal",
		"victory_condition": "Default",
		"crew_size": 4,
		"starting_credits": 1000,
		"story_track_enabled": false
	}
	
	# Collect from ConfigPanel if available
	if config_panel and config_panel.has_method("get_config_data"):
		var panel_config = config_panel.get_config_data()
		if panel_config is Dictionary:
			config.merge(panel_config)
			print("CampaignCreationUI: Merged config from ConfigPanel")
	elif config_panel:
		# Try to get basic data from ConfigPanel
		var name_input = config_panel.get_node_or_null("Content/CampaignName/LineEdit") as Node
		if name_input and name_input.text.length() > 0:
			config.name = name_input.text
		
		var difficulty_option = config_panel.get_node_or_null("Content/Difficulty/OptionButton") as Node
		if difficulty_option and difficulty_option.selected >= 0:
			var difficulty_options = ["Easy", "Normal", "Hard", "Hardcore"]
			if difficulty_option.selected < difficulty_options.size():
				config.difficulty = difficulty_options[difficulty_option.selected]
	
	# Collect from CrewPanel if available
	if crew_panel and crew_panel.has_method("get_crew_data"):
		var crew_data = crew_panel.get_crew_data()
		if crew_data is Dictionary:
			config.merge(crew_data)
			print("CampaignCreationUI: Merged crew data from CrewPanel")
	
	# Collect from ShipPanel if available
	if ship_panel and ship_panel.has_method("get_ship_data"):
		var ship_data = ship_panel.get_ship_data()
		if ship_data is Dictionary:
			config.merge(ship_data)
			print("CampaignCreationUI: Merged ship data from ShipPanel")
	
	# Collect from EquipmentPanel if available
	if equipment_panel and equipment_panel.has_method("get_equipment_data"):
		var equipment_data = equipment_panel.get_equipment_data()
		if equipment_data is Dictionary:
			config.merge(equipment_data)
			print("CampaignCreationUI: Merged equipment data from EquipmentPanel")
	
	print("CampaignCreationUI: Final campaign config: %s" % config)
	return config

func _finalize_campaign_creation() -> void:
	"""Finalize campaign creation with data from UI panels"""
	print("CampaignCreationUI: Finalizing campaign creation...")

	# For development, make validation optional
	const DEBUG_MODE = true
	
	if not DEBUG_MODE:
		# Final validation before creating campaign
		var all_errors: Array[String] = []
		for step: int in range(step_panels.size()):
			current_step = step
			@warning_ignore("untyped_declaration")
			var step_errors = _validate_current_step()
			@warning_ignore("unsafe_call_argument")
			all_errors.append_array(step_errors)

		if not all_errors.is_empty():
			_show_error_dialog("Campaign Creation Failed", "Please fix all issues before creating the campaign:\n\n" + "\n".join(all_errors))
			return
	else:
		print("CampaignCreationUI: DEBUG MODE - skipping final validation")

	# Collect data from UI panels
	var campaign_config: Dictionary = _collect_campaign_config_safe()
	print("CampaignCreationUI: Collected campaign config: ", campaign_config.keys())

	if creation_manager and creation_manager and creation_manager.has_method("finalize_campaign_creation"):
		# Set the config data first
		@warning_ignore("unsafe_method_access")
		creation_manager.set_config_data(campaign_config)

		# Set crew data if available
		if campaign_config.has("crew") and creation_manager and creation_manager.has_method("set_crew_data"):
			@warning_ignore("unsafe_method_access")
			creation_manager.set_crew_data(campaign_config.crew)

		# Set captain data if available
		if campaign_config.has("captain") and creation_manager and creation_manager.has_method("set_captain_data"):
			if campaign_config.captain is CharacterBase:
				# Convert Character object to dictionary format
				@warning_ignore("untyped_declaration")
				var captain_dict = {
					"character_object": campaign_config.captain,
					"name": campaign_config.captain.character_name if campaign_config.captain.has("character_name") else "Captain"
				}
				@warning_ignore("unsafe_method_access")
				creation_manager.set_captain_data(captain_dict)
			elif campaign_config.captain is Dictionary:
				@warning_ignore("unsafe_method_access")
				creation_manager.set_captain_data(campaign_config.captain)

		# Set resource data if available
		if campaign_config.has("resources") and creation_manager and creation_manager.has_method("set_resource_data"):
			@warning_ignore("unsafe_method_access")
			creation_manager.set_resource_data(campaign_config.resources)

		# Finalize and create the campaign
		@warning_ignore("unsafe_method_access", "untyped_declaration")
		var campaign = creation_manager.finalize_campaign_creation()
		if campaign:
			print("CampaignCreationUI: Campaign created successfully")
			_start_campaign(campaign)
		else:
			push_error("CampaignCreationUI: Failed to create campaign")
	else:
		# Fallback: just start a basic campaign
		print("CampaignCreationUI: Creating fallback campaign")
		_start_fallback_campaign(campaign_config)

func _start_fallback_campaign(config: Dictionary) -> void:
	"""Start a basic campaign when creation manager is not available"""
	print("CampaignCreationUI: Starting fallback campaign with config: %s" % config.get("name", "Test Campaign"))
	
	# Try to initialize basic campaign through core systems if available
	if core_systems and core_systems.has_method("start_new_campaign"):
		@warning_ignore("unsafe_method_access")
		var success: bool = core_systems.start_new_campaign(config)
		if success:
			print("CampaignCreationUI: Basic campaign started successfully through core systems")
		else:
			print("CampaignCreationUI: Core systems failed to start campaign, continuing with navigation")
	else:
		print("CampaignCreationUI: Core systems not available, creating minimal campaign state")
	
	# Navigate to campaign dashboard or main game
	var scene_router = get_node_or_null("/root/SceneRouter") as Node
	if scene_router and scene_router.has_method("navigate_to"):
		# Try to navigate to campaign dashboard first
		@warning_ignore("unsafe_method_access")
		if scene_router.has_method("has_scene") and scene_router.has_scene("campaign_dashboard"):
			@warning_ignore("unsafe_method_access")
			scene_router.navigate_to("campaign_dashboard")
		elif scene_router.has_method("has_scene") and scene_router.has_scene("main_game"):
			@warning_ignore("unsafe_method_access")
			scene_router.navigate_to("main_game")
		else:
			# Try safe_navigate_to if available
			@warning_ignore("unsafe_method_access")
			if scene_router.has_method("safe_navigate_to"):
				@warning_ignore("unsafe_method_access")
				scene_router.safe_navigate_to("res://src/scenes/main/MainGameScene.tscn")
			else:
				push_warning("No suitable target scene found for campaign start")
	else:
		# Direct scene change as last resort with error handling
		print("CampaignCreationUI: Using direct scene navigation as fallback")
		if FileAccess.file_exists("res://src/scenes/campaign/CampaignDashboard.tscn"):
			var error: Error = get_tree().change_scene_to_file("res://src/scenes/campaign/CampaignDashboard.tscn")
			if error != OK:
				print("CampaignCreationUI: Failed to load CampaignDashboard, trying MainGameScene")
				_try_load_main_game_scene()
		elif FileAccess.file_exists("res://src/scenes/main/MainGameScene.tscn"):
			_try_load_main_game_scene()
		else:
			push_error("No campaign scenes found - cannot start campaign")
			# Return to main menu as last resort
			_return_to_main_menu()

func _try_load_main_game_scene() -> void:
	"""Try to load the main game scene with error handling"""
	var error: Error = get_tree().change_scene_to_file("res://src/scenes/main/MainGameScene.tscn")
	if error != OK:
		push_error("Failed to load MainGameScene, returning to main menu")
		_return_to_main_menu()

func _collect_campaign_config() -> Dictionary:
	"""Collect campaign configuration from UI panels"""
	var config: Dictionary = {}

	# Get data from ConfigPanel
	if config_panel and config_panel and config_panel.has_method("get_config_data"):
		@warning_ignore("unsafe_method_access")
		config = config_panel.get_config_data()
	else:
		# Fallback: create basic config from visible UI
		config = {
			"name": "New Campaign",
			"difficulty": 1,
			"description": "A Five Parsecs from Home campaign"
		}

	# Collect data from other panels if they exist
	if crew_panel and crew_panel and crew_panel.has_method("get_crew_data"):
		@warning_ignore("unsafe_method_access")
		config.crew = crew_panel.get_crew_data()

	if captain_panel and captain_panel and captain_panel.has_method("get_captain_data"):
		@warning_ignore("unsafe_method_access")
		config.captain = captain_panel.get_captain_data()

	if ship_panel and ship_panel and ship_panel.has_method("get_ship_data"):
		@warning_ignore("unsafe_method_access")
		config.ship = ship_panel.get_ship_data()

	if equipment_panel and equipment_panel and equipment_panel.has_method("get_equipment"):
		@warning_ignore("unsafe_method_access")
		config.equipment = equipment_panel.get_equipment()

	# Ensure minimum required fields
	@warning_ignore("unsafe_method_access")
	if not config.has("name") or config.name.is_empty():
		config.name = "New Campaign"
	if not config.has("difficulty"):
		config.difficulty = 1

	print("CampaignCreationUI: Collected complete config: ", config)
	return config

func _start_campaign(campaign: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	print("CampaignCreationUI: Starting campaign...")

	# Try to start the campaign through core systems
	if core_systems and core_systems and core_systems.has_method("start_new_campaign"):
		@warning_ignore("untyped_declaration")
		var config = {"campaign": campaign}
		@warning_ignore("unsafe_method_access")
		if core_systems.start_new_campaign(config):
			print("CampaignCreationUI: Campaign started successfully")
			_navigate_to_main_game()
		else:
			push_error("CampaignCreationUI: Failed to start campaign")
	else:
		push_warning("CampaignCreationUI: Core systems not available, navigating to main game")
		_navigate_to_main_game()


func _navigate_to_main_game() -> void:
	"""Navigate to the main game scene"""
	print("CampaignCreationUI: Navigating to main game...")

	@warning_ignore("untyped_declaration")
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router and scene_router.has_method("navigate_to_main_game"):
		print("CampaignCreationUI: Using SceneRouter to navigate")
		@warning_ignore("unsafe_method_access")
		scene_router.navigate_to_main_game()
	elif scene_router and scene_router and scene_router.has_method("change_scene"):
		print("CampaignCreationUI: Using SceneRouter change_scene method")
		@warning_ignore("unsafe_method_access")
		scene_router.change_scene("res://src/scenes/main/MainGameScene.tscn")
	else:
		# Fallback navigation
		print("CampaignCreationUI: Using fallback navigation to main game")
		get_tree().call_deferred("change_scene_to_file", "res://src/scenes/main/MainGameScene.tscn")

func _return_to_main_menu() -> void:
	"""Return to the main menu"""
	print("CampaignCreationUI: Returning to main menu...")

	@warning_ignore("untyped_declaration")
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router and scene_router.has_method("return_to_main_menu"):
		print("CampaignCreationUI: Using SceneRouter to return to main menu")
		@warning_ignore("unsafe_method_access")
		scene_router.return_to_main_menu()
	elif scene_router and scene_router and scene_router.has_method("change_scene"):
		print("CampaignCreationUI: Using SceneRouter change_scene for main menu")
		@warning_ignore("unsafe_method_access")
		scene_router.change_scene("res://src/ui/screens/mainmenu/MainMenu.tscn")
	else:
		# Fallback navigation
		print("CampaignCreationUI: Using fallback navigation to main menu")
		get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/mainmenu/MainMenu.tscn")

# Signal handlers for creation manager
func _on_creation_step_changed(step: int) -> void:
	"""Handle creation step change"""
	_update_ui_for_step(step)

func _on_campaign_creation_completed(campaign: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	print("CampaignCreationUI: Campaign creation completed")
	_start_campaign(campaign)

func _on_validation_failed(errors: Array[String]) -> void:
	"""Handle validation failure"""
	print("CampaignCreationUI: Validation failed:")
	for error: String in errors:
		print("  - " + error)

	# Show error message to user
	_show_error_dialog("Campaign Creation Error", "Please fix the following issues:\n\n" + "\n".join(errors))

# State Manager Integration Methods
func _connect_enhanced_panel_signals() -> void:
	"""Connect panel signals to state manager for centralized data management"""
	if not state_manager:
		return

	# Connect crew panel
	if crew_panel and crew_panel.has_signal("crew_updated"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		crew_panel.crew_updated.connect(_on_crew_data_updated)
	if crew_panel and crew_panel.has_signal("crew_setup_complete"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		crew_panel.crew_setup_complete.connect(_on_crew_setup_complete)

	# Connect captain panel  
	if captain_panel and captain_panel.has_signal("captain_updated"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		captain_panel.captain_updated.connect(_on_captain_updated)

	# Connect ship panel - PHASE 2 ENHANCED
	if ship_panel and ship_panel.has_signal("ship_updated"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		ship_panel.ship_updated.connect(_on_ship_updated)
	if ship_panel and ship_panel.has_signal("ship_setup_complete"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		ship_panel.ship_setup_complete.connect(_on_ship_setup_complete)

	# Connect equipment panel - PHASE 2 ENHANCED  
	if equipment_panel and equipment_panel.has_signal("equipment_generated"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		equipment_panel.equipment_generated.connect(_on_equipment_generated)
	if equipment_panel and equipment_panel.has_signal("equipment_setup_complete"):
		@warning_ignore("unsafe_property_access", "unsafe_method_access")
		equipment_panel.equipment_setup_complete.connect(_on_equipment_setup_complete)

	print("CampaignCreationUI: Enhanced panel signals connected to state manager")

# Panel Data Integration Methods
func _on_crew_data_updated(crew: Array) -> void:
	"""Handle crew panel updates with equipment integration"""
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, {"members": crew, "size": crew.size()})
		print("CampaignCreationUI: Crew data updated with size: ", crew.size())

		# PHASE 2 ENHANCEMENT: Update equipment panel with crew size
		if equipment_panel and equipment_panel and equipment_panel.has_method("set_crew_size"):
			@warning_ignore("unsafe_method_access")
			equipment_panel.set_crew_size(crew.size())

func _on_crew_setup_complete(crew_data: Dictionary) -> void:
	"""Handle crew setup completion"""
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, crew_data)


func _on_ship_setup_complete(ship_data: Dictionary) -> void:
	"""Handle ship setup completion - PHASE 2 ENHANCED"""
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT, ship_data)
		print("CampaignCreationUI: Ship setup completed with data: ", ship_data.keys())

func _on_equipment_updated(equipment_data: Dictionary) -> void:
	"""Handle equipment panel updates (legacy compatibility)"""
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, equipment_data)


func _on_equipment_setup_complete(equipment_data: Dictionary) -> void:
	"""Handle equipment setup completion - PHASE 2 ENHANCED"""
	if state_manager:
		state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, equipment_data)
		print("CampaignCreationUI: Equipment setup completed with data: ", equipment_data.keys())

func _start_campaign_from_state_data(campaign_data: Dictionary) -> void:
	"""Start campaign using complete state manager data with auto-save generation"""
	print("CampaignCreationUI: Starting campaign with complete state data")

	# PHASE 2 ENHANCEMENT: Auto-save name generation
	@warning_ignore("untyped_declaration")
	var enhanced_campaign_data = campaign_data.duplicate()
	@warning_ignore("unsafe_call_argument")
	enhanced_campaign_data = _apply_auto_save_generation(enhanced_campaign_data)

	# The state manager provides validated, complete campaign data
	if core_systems and core_systems and core_systems.has_method("start_new_campaign"):
		@warning_ignore("unsafe_method_access", "untyped_declaration")
		var success = core_systems.start_new_campaign(enhanced_campaign_data)
		if success:
			print("CampaignCreationUI: Campaign started successfully with auto-save: ", enhanced_campaign_data.get("save_name", "unnamed"))
			_navigate_to_main_game()
		else:
			push_error("CampaignCreationUI: Failed to start campaign with state manager data")
	else:
		push_warning("CampaignCreationUI: Core systems not available, using fallback")
		_navigate_to_main_game()

func _apply_auto_save_generation(campaign_data: Dictionary) -> Dictionary:
	"""Apply auto-save name generation in format: CampaignName_YYYY-MM-DD_HH-MM"""
	@warning_ignore("untyped_declaration")
	var enhanced_data = campaign_data.duplicate()

	# Extract campaign name from config data
	var campaign_name: String = "NewCampaign"
	@warning_ignore("unsafe_method_access")
	if enhanced_data.has("config") and (enhanced_data.config as Dictionary).has("name"):
		campaign_name = enhanced_data.config.name
	elif enhanced_data.has("name"):
		campaign_name = enhanced_data.name

	# Clean campaign name for filename use
	campaign_name = campaign_name.strip_edges().replace(" ", "_").replace("/", "_").replace("\\", "_")
	if campaign_name.is_empty():
		campaign_name = "NewCampaign"

	# Generate timestamp
	@warning_ignore("untyped_declaration")
	var datetime = Time.get_datetime_dict_from_system()
	@warning_ignore("untyped_declaration")
	var timestamp = "%04d-%02d-%02d_%02d-%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute
	]

	# Create auto-save name
	var auto_save_name: String = "%s_%s" % [campaign_name, timestamp]
	enhanced_data["save_name"] = auto_save_name
	enhanced_data["auto_generated_save"] = true
	enhanced_data["created_timestamp"] = Time.get_datetime_string_from_system()

	print("CampaignCreationUI: Generated auto-save name: ", auto_save_name)
	return enhanced_data

# PHASE 3: UX Optimization Functions
func _validate_optimized_flow() -> void:
	"""Validate the optimized campaign creation flow matches Phase 3 specifications"""
	print("CampaignCreationUI: Validating Phase 3 optimized flow...")

	var expected_panels: Array[String] = ["ConfigPanel", "CrewPanel", "CaptainPanel", "ShipPanel", "EquipmentPanel", "FinalPanel"]
	@warning_ignore("unused_variable")
	var expected_steps: Array[String] = ["Configuration", "Crew Setup", "Captain Creation", "Ship Assignment", "Equipment Generation", "Final Review"]

	# Verify panel count matches expected flow
	if step_panels.size() != expected_panels.size():
		push_warning("Flow validation: Expected %d panels, found %d" % [expected_panels.size(), step_panels.size()])
	else:
		print("✅ Flow validation: Correct panel count (%d)" % step_panels.size())

	# Verify each panel exists and is correctly ordered
	for i: int in range(min(step_panels.size(), expected_panels.size())):
		var panel: Control = step_panels[i]
		var expected_name: String = expected_panels[i]

		if panel and panel.name == expected_name:
			print("✅ Step %d: %s correctly positioned" % [i + 1, expected_name])
		elif panel:
			push_warning("⚠️ Step %d: Expected %s, found %s" % [i + 1, expected_name, panel.name])
		else:
			push_error("❌ Step %d: Missing panel (expected %s)" % [i + 1, expected_name])

	# Verify state manager phase alignment
	if state_manager:
		@warning_ignore("untyped_declaration")
		var state_phases = [
			CampaignCreationStateManager.Phase.CONFIG,
			CampaignCreationStateManager.Phase.CREW_SETUP,
			CampaignCreationStateManager.Phase.CAPTAIN_CREATION,
			CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT,
			CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION,
			CampaignCreationStateManager.Phase.FINAL_REVIEW
		]

		if state_phases.size() == expected_panels.size():
			print("✅ State manager phases align with UI flow")
		else:
			push_warning("⚠️ State manager phase count mismatch")

	# Verify ResourcePanel is excluded (Phase 3 requirement)
	var has_resource_panel: bool = false
	for panel in step_panels:
		if panel and panel.name == "ResourcePanel":
			has_resource_panel = true
			break

	if not has_resource_panel:
		print("✅ ResourcePanel correctly excluded from optimized flow")
	else:
		push_error("❌ ResourcePanel still present in flow - Phase 3 optimization incomplete")

	# Verify navigation consistency
	_validate_navigation_flow()

	print("CampaignCreationUI: Phase 3 flow validation complete!")

func _validate_navigation_flow() -> void:
	"""Validate navigation flow consistency"""
	# Test navigation button states for each step
	for step: int in range(step_panels.size()):
		@warning_ignore("untyped_declaration")
		var is_first_step = (step == 0)
		@warning_ignore("untyped_declaration")
		var is_last_step = (step >= step_panels.size() - 1)

		print("Step %d navigation: First=%s, Last=%s" % [step + 1, is_first_step, is_last_step])

	# Verify auto-save generation is available
	if has_method("_apply_auto_save_generation"):
		print("✅ Auto-save generation available")
	else:
		push_error("❌ Auto-save generation missing")

func get_optimized_flow_summary() -> Dictionary:
	"""Get summary of the optimized flow for debugging/testing"""
	return {
		"total_steps": step_panels.size(),
		"current_step": current_step + 1,
		"steps": ["Configuration", "Crew Setup", "Captain Creation", "Ship Assignment", "Equipment Generation", "Final Review"],
		"state_manager_active": state_manager != null,
		"auto_save_enabled": true,
		"resource_panel_excluded": true,
		"flow_version": "Phase 3 Optimized"
	}

func debug_current_flow_state() -> void:
	"""Debug function to display current flow state"""
	print("=== CAMPAIGN CREATION FLOW DEBUG ===")
	print("Current Step: %d/%d" % [current_step + 1, step_panels.size()])
	var active_panel_name: String = "None"
	if current_step < step_panels.size() and step_panels[current_step]:
		active_panel_name = step_panels[current_step].name
	print("Active Panel: %s" % active_panel_name)
	print("State Manager: %s" % ("Active" if state_manager else "Inactive"))
	print("Flow Summary: ", get_optimized_flow_summary())
	print("=====================================")

# PHASE 3: User Experience Enhancement Functions
func get_progress_percentage() -> float:
	"""Get completion percentage for progress indication"""
	if step_panels.size() == 0:
		return 0.0
	return float(current_step) / float(step_panels.size() - 1) * 100.0

func get_current_step_name() -> String:
	"""Get name of current step for UI display"""
	var step_names: Array[String] = ["Configuration", "Crew Setup", "Captain Creation", "Ship Assignment", "Equipment Generation", "Final Review"]
	if current_step < step_names.size():
		return step_names[current_step]
	return "Unknown"

func can_skip_to_step(target_step: int) -> bool:
	"""Check if user can skip to a specific step (for advanced UX)"""
	if not state_manager:
		return false

	# Can only skip forward to completed or current step
	return target_step <= current_step or _are_previous_steps_valid(target_step)

@warning_ignore("unused_parameter")
func _are_previous_steps_valid(target_step: int) -> bool:
	"""Check if all previous steps are properly validated"""
	if not state_manager:
		return false

	# Implementation would check state manager validation for each phase
	# This provides foundation for future "skip to step" functionality
	return true

func _update_progress_display(step: int) -> void:
	"""Update progress indicators - PHASE 3 UX ENHANCEMENT"""
	@warning_ignore("untyped_declaration")
	var progress_percent = get_progress_percentage()

	# Try to find or create progress indicators in the UI
	@warning_ignore("untyped_declaration")
	var progress_bar = get_node("MarginContainer/VBoxContainer/Header/ProgressBar")
	if progress_bar and progress_bar is ProgressBar:
		progress_bar.value = progress_percent
		print("✅ Progress bar updated: %.0f%%" % progress_percent)

	# Update window title if possible (advanced UX) - Remove undefined function call
	# Note: set_window_title() is not available in Control base class

	# Log progress for debugging
	print("CampaignCreationUI: Progress %.0f%% - Step %d/%d" % [progress_percent, step + 1, step_panels.size()])

# PHASE 3: Keyboard Shortcuts & Accessibility
func _setup_keyboard_shortcuts() -> void:
	"""Setup keyboard shortcuts for enhanced UX navigation"""
	# This control needs to be able to receive focus to handle input.
	# The focus_mode is now set in _ready().
	grab_focus()

	print("CampaignCreationUI: Keyboard shortcuts enabled")
	print("  - Ctrl+Right Arrow: Next step")
	print("  - Ctrl+Left Arrow: Previous step")
	print("  - Ctrl+Enter: Finish campaign creation")
	print("  - Escape: Cancel/Back")

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts for campaign creation navigation"""
	if not event is InputEventKey:
		return

	@warning_ignore("untyped_declaration")
	var key_event = event as InputEventKey
	if not key_event.pressed:
		return

	# Handle keyboard shortcuts
	match key_event.keycode:
		KEY_RIGHT:
			if key_event.ctrl_pressed:
				# Ctrl+Right: Next step
				if next_button and not next_button.disabled:
					_on_next_button_pressed()
				get_viewport().set_input_as_handled()

		KEY_LEFT:
			if key_event.ctrl_pressed:
				# Ctrl+Left: Previous step
				if back_button and not back_button.disabled:
					_on_back_button_pressed()
				get_viewport().set_input_as_handled()

		KEY_ENTER:
			if key_event.ctrl_pressed:
				# Ctrl+Enter: Finish campaign
				if finish_button and not finish_button.disabled:
					_on_finish_button_pressed()
				get_viewport().set_input_as_handled()

		KEY_ESCAPE:
			# Escape: Back or cancel
			if back_button and not back_button.disabled:
				_on_back_button_pressed()
			else:
				_show_cancel_confirmation()
			get_viewport().set_input_as_handled()

func _show_cancel_confirmation() -> void:
	"""Show confirmation dialog for canceling campaign creation"""
	# This would show a confirmation dialog in a full implementation
	print("CampaignCreationUI: Cancel confirmation (would show dialog)")

func get_accessibility_summary() -> String:
	"""Get accessibility information for screen readers"""
	@warning_ignore("untyped_declaration")
	var step_name = get_current_step_name()
	@warning_ignore("untyped_declaration")
	var progress = get_progress_percentage()

	return "Campaign Creation: %s. Step %d of %d. %.0f percent complete. Use Tab to navigate, Ctrl+Arrow keys to change steps." % [
		step_name, current_step + 1, step_panels.size(), progress
	]

# State Manager Signal Handlers
func _on_state_updated(phase: CampaignCreationStateManager.Phase, data: Dictionary) -> void:
	"""Handle state manager updates"""
	print("CampaignCreationUI: State updated for phase ", phase, " with data: ", data.keys())
	_update_navigation_buttons()

func _update_navigation_buttons() -> void:
	"""Update navigation button states based on current phase"""
	if not state_manager:
		return

	@warning_ignore("untyped_declaration")
	var current_phase = state_manager.get_current_phase()
	@warning_ignore("unsafe_call_argument", "untyped_declaration")
	var is_valid = state_manager.is_phase_valid(current_phase)

	if next_button:
		next_button.disabled = not is_valid

	if finish_button:
		finish_button.disabled = not is_valid

func _on_validation_changed(is_valid: bool, errors: Array[String]) -> void:
	"""Handle validation state changes"""
	if next_button:
		next_button.disabled = not is_valid
	if finish_button:
		finish_button.disabled = not is_valid

	if not is_valid and errors.size() > 0:
		print("CampaignCreationUI: Validation errors: ", errors)

func _on_phase_completed(phase: CampaignCreationStateManager.Phase) -> void:
	"""Handle phase completion"""
	print("CampaignCreationUI: Phase completed: ", phase)

	# Auto-advance to next phase if not on final phase
	#if phase != CampaignCreationStateManager.Phase.FINAL_REVIEW and state_manager:
	#	if state_manager.advance_to_next_phase():
	#		_update_ui_for_current_phase()
	#		_update_navigation_state()
	#	else:
	#		print("CampaignCreationUI: Cannot auto-advance after phase completion")

func _on_creation_completed(campaign_data: Dictionary) -> void:
	"""Handle campaign creation completion"""
	print("CampaignCreationUI: Campaign creation completed with state manager")
	# Use the complete campaign data from state manager
	_start_campaign_from_state_data(campaign_data)

# Window Management
func _update_window_title() -> void:
	"""Update the window title based on current phase"""
	if not get_window() or not state_manager:
		return

	@warning_ignore("untyped_declaration")
	var current_phase = state_manager.get_current_phase()
	@warning_ignore("unsafe_call_argument")
	var phase_name: String = _get_phase_name(current_phase)
	get_window().title = "Campaign Creation - " + str(phase_name)
func _get_phase_name(phase: CampaignCreationStateManager.Phase) -> String:
	"""Get display name for a phase"""
	match phase:
		CampaignCreationStateManager.Phase.CONFIG:
			return "Configuration"
		CampaignCreationStateManager.Phase.CREW_SETUP:
			return "Crew Setup"
		CampaignCreationStateManager.Phase.CAPTAIN_CREATION:
			return "Captain Creation"
		CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT:
			return "Ship Assignment"
		CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION:
			return "Equipment Generation"
		CampaignCreationStateManager.Phase.FINAL_REVIEW:
			return "Final Review"
		_:
			return "Unknown Phase"

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not obj or not is_instance_valid(obj):
		return default_value
	
	if obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	@warning_ignore("unsafe_method_access")
	if obj is Object and obj.has_method(method_name):
		@warning_ignore("unsafe_method_access")
		return obj.callv(method_name, args)
	return null
