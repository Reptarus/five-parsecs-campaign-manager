extends Control

## Travel Phase UI for Five Parsecs Campaign Manager
## Handles upkeep and travel decisions for the campaign turn flow

signal phase_completed()
signal upkeep_completed()
signal travel_completed()

# UI References
@onready var step_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StepLabel
@onready var tab_container: TabContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer
@onready var upkeep_details: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Upkeep/UpkeepDetails
@onready var upkeep_button: Button = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Upkeep/UpkeepButton
@onready var travel_options: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Travel/TravelOptions
@onready var travel_event_details: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/Travel/TravelEventDetails
@onready var log_book: RichTextLabel = $LogBook
@onready var back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/BackButton
@onready var next_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/NextButton

# State tracking
var campaign_data: Resource = null
var is_upkeep_completed: bool = false
var travel_decision_made: bool = false
var current_step: int = 0

# Manager references
var alpha_manager: Node = null
var campaign_manager: Node = null
var upkeep_system: Node = null

func _ready() -> void:
	_initialize_managers()
	_setup_ui()
	_connect_additional_signals()
	_setup_travel_icons()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null

	if alpha_manager and alpha_manager.has_method("get_upkeep_system"):
		upkeep_system = alpha_manager.get_upkeep_system()

func _setup_ui() -> void:
	"""Setup initial UI state"""
	tab_container.current_tab = 0 # Start with upkeep tab
	step_label.text = "Step 1: Upkeep Phase"
	next_button.disabled = true
	_update_upkeep_display()

func _connect_additional_signals() -> void:
	"""Connect any additional signals needed"""
	if upkeep_system and upkeep_system.has_signal("upkeep_calculated"):
		upkeep_system.upkeep_calculated.connect(_on_upkeep_calculated)
	
	# Connect to CampaignPhaseManager for campaign flow integration
	var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if campaign_phase_manager:
		# Connect UI completion signal to phase manager
		phase_completed.connect(campaign_phase_manager._on_travel_phase_completed)
		print("TravelPhaseUI: Connected to CampaignPhaseManager")
	else:
		push_warning("TravelPhaseUI: CampaignPhaseManager not found - phase transitions may not work")

func setup_phase(data: Resource) -> void:
	"""Setup the travel phase with campaign data"""
	campaign_data = data
	_reset_phase_state()
	_update_upkeep_display()
	_add_log_entry("Travel Phase started")

func _reset_phase_state() -> void:
	"""Reset phase state for new campaign turn"""
	is_upkeep_completed = false
	travel_decision_made = false
	current_step = 0
	tab_container.current_tab = 0
	step_label.text = "Step 1: Upkeep Phase"
	next_button.disabled = true

func _update_upkeep_display() -> void:
	"""Update the upkeep information display"""
	if not upkeep_system or not campaign_data:
		upkeep_button.text = "Perform Upkeep (No Data)"
		upkeep_button.disabled = true
		return

	# Clear existing upkeep details
	for child in upkeep_details.get_children():
		child.queue_free()

	# Get upkeep costs
	var upkeep_costs = upkeep_system.calculate_upkeep_costs(campaign_data)

	var total_cost = upkeep_costs.get("total_cost", 0)

	var crew_cost = upkeep_costs.get("crew_cost", 0)

	var ship_cost = upkeep_costs.get("ship_cost", 0)
	var current_credits = campaign_data.get_meta("credits", 0) if campaign_data else 0

	# Create upkeep cost display
	var cost_label: Label = Label.new()
	cost_label.text = "Upkeep Costs:\n• Crew: %d credits\n• Ship: %d credits\n• Total: %d credits" % [crew_cost, ship_cost, total_cost]
	upkeep_details.add_child(cost_label)

	var credits_label: Label = Label.new()
	credits_label.text = "Current Credits: %d" % current_credits
	upkeep_details.add_child(credits_label)

	# Update button state
	if current_credits >= total_cost:
		upkeep_button.text = "Pay Upkeep (%d credits)" % total_cost
		upkeep_button.disabled = false
	else:
		upkeep_button.text = "Insufficient Credits (%d needed)" % total_cost
		upkeep_button.disabled = true

func _add_log_entry(text: String) -> void:
	"""Add an entry to the log book"""
	var timestamp = Time.get_datetime_string_from_system()
	log_book.append_text("[%s] %s\n" % [timestamp, text])

# Signal handlers

func _on_upkeep_button_pressed() -> void:
	"""Handle upkeep button press"""
	if not upkeep_system or not campaign_data:
		_add_log_entry("Error: Cannot perform upkeep - missing data")
		return

	var result: Variant = upkeep_system.perform_upkeep(campaign_data)

	if result.get("success", false):
		is_upkeep_completed = true
		upkeep_button.text = "Upkeep Complete ✓"
		upkeep_button.disabled = true
		_add_log_entry("Upkeep completed successfully")
		_advance_to_travel()
	else:
		var error: int = result.get("error", "Unknown error")
		_add_log_entry("Upkeep failed: %s" % error)

func _advance_to_travel() -> void:
	"""Advance to travel step"""
	current_step = 1
	step_label.text = "Step 2: Travel Decision"
	tab_container.current_tab = 1
	upkeep_completed.emit()

func _on_stay_button_pressed() -> void:
	"""Handle stay in current location"""
	travel_decision_made = true
	_add_log_entry("Decided to stay in current location")
	_complete_travel_phase()

func _on_travel_button_pressed() -> void:
	"""Handle travel to new location"""
	travel_decision_made = true
	_add_log_entry("Decided to travel to new location")
	# TODO: Add travel event generation
	_complete_travel_phase()

func _on_next_event_button_pressed() -> void:
	"""Generate next travel event"""
	_add_log_entry("Travel event generated") # TODO: Implement actual event generation

func _complete_travel_phase() -> void:
	"""Complete the travel phase"""
	next_button.disabled = false
	travel_completed.emit() # warning: return value discarded (intentional)
	_add_log_entry("Travel phase completed")

func _on_back_button_pressed() -> void:
	"""Handle back button press"""
	# Go back to previous phase or step
	if current_step > 0:
		current_step -= 1
		if current_step == 0:
			tab_container.current_tab = 0
			step_label.text = "Step 1: Upkeep Phase"

func _on_next_button_pressed() -> void:
	"""Handle next button press"""
	if is_upkeep_completed and travel_decision_made:
		phase_completed.emit() # warning: return value discarded (intentional)
		_add_log_entry("Travel phase complete - advancing to World phase")

func _on_upkeep_calculated(costs: Dictionary) -> void:
	"""Handle upkeep calculation completion"""
	_update_upkeep_display()

func get_phase_status() -> Dictionary:
	"""Get the current phase status"""
	return {
		"upkeep_completed": is_upkeep_completed,
		"travel_decision_made": travel_decision_made,
		"current_step": current_step,
		"can_advance": is_upkeep_completed and travel_decision_made
	}

func load_campaign_data(data: Resource) -> void:
	"""Load campaign data for this phase"""
	campaign_data = data
	_update_upkeep_display()


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

## Setup travel phase icons for enhanced visual navigation
func _setup_travel_icons() -> void:
	"""Setup icons for travel phase buttons to improve visual clarity"""
	# Phase 2: Travel Phase Icons Integration
	
	# Next Button (primary travel action) - icon_campaign_travel.svg
	if next_button:
		next_button.icon = preload("res://assets/basic icons/icon_campaign_travel.svg")
		next_button.expand_icon = true
		next_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("TravelPhaseUI: Travel phase icon applied to next button successfully")
	else:
		push_warning("TravelPhaseUI: Next button not found for icon assignment")