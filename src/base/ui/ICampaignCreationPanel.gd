class_name ICampaignCreationPanel
extends Control

## Base interface for campaign creation panels - Modern Signal-Based Architecture
## 
## Implements Godot 4.x best practices with signal-based communication,
## group registration, and proper scene composition patterns.
## Eliminates dependency injection anti-patterns in favor of loose coupling.

# Import validation for type safety
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

# Required signals that all panels must have
signal panel_ready()
signal panel_completed(panel_data: Dictionary)
signal validation_failed(errors: Array[String])

# New signal-based communication signals
signal panel_registered(panel: Control)
signal campaign_state_requested()
signal panel_data_updated(panel: Control, data: Dictionary)

# State management - no longer injected, received via signals
var campaign_state: Dictionary = {}
var is_panel_valid: bool = false
var is_panel_initialized: bool = false

# Group-based communication
const PANEL_GROUP_NAME: String = "campaign_panels"

## REQUIRED: Validate panel data - must be overridden
func validate_panel() -> ValidationResult:
	push_error("validate_panel() must be implemented in derived class: " + get_class())
	var result = ValidationResult.new()
	result.valid = false
	result.error = "Panel validation not implemented"
	return result

## REQUIRED: Get panel data - must be overridden
func get_panel_data() -> Dictionary:
	push_error("get_panel_data() must be implemented in derived class: " + get_class())
	return {}

## REQUIRED: Reset panel to default state - must be overridden
func reset_panel() -> void:
	push_error("reset_panel() must be implemented in derived class: " + get_class())

## SIGNAL-BASED: Handle campaign state updates from controller
func _on_campaign_state_received(state_data: Dictionary) -> void:
	campaign_state = state_data
	_on_campaign_state_updated(state_data)

## OPTIONAL: Override in derived classes for custom state handling
func _on_campaign_state_updated(state_data: Dictionary) -> void:
	pass

## MODERN GODOT: Group-based initialization - call this in _ready()
func _initialize_panel_registration() -> void:
	# Add to campaign panels group for automatic registration
	add_to_group(PANEL_GROUP_NAME)
	
	# Connect to tree signals for automatic campaign state subscription
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	
	# Emit registration signal
	call_deferred("_emit_panel_registration")

## Helper method to emit panel ready after initialization
func _emit_panel_ready() -> void:
	if not is_panel_initialized:
		is_panel_initialized = true
		panel_ready.emit()

## Helper method to emit panel registration
func _emit_panel_registration() -> void:
	if is_inside_tree():
		panel_registered.emit(self)

## Auto-connect to campaign flow controller when it's added to tree
func _on_node_added(node: Node) -> void:
	if node.has_method("campaign_state_available") and node != self:
		# Found campaign flow controller, connect to its signals
		if not node.campaign_state_available.is_connected(_on_campaign_state_received):
			node.campaign_state_available.connect(_on_campaign_state_received)
		
		# Request initial state
		campaign_state_requested.emit()

## Helper method to validate and emit completion
func _validate_and_emit_completion() -> void:
	var validation = validate_panel()
	is_panel_valid = validation.valid
	
	if validation.valid:
		var panel_data = get_panel_data()
		panel_completed.emit(panel_data)
	else:
		var errors = []
		if validation.error and not validation.error.is_empty():
			errors.append(validation.error)
		if validation.errors and validation.errors.size() > 0:
			errors.append_array(validation.errors)
		validation_failed.emit(errors)

## Helper to check if panel has required data
func has_required_data() -> bool:
	return is_panel_valid

## Get panel completion status
func get_completion_status() -> bool:
	return is_panel_valid

## Get current validation errors
func get_validation_errors() -> Array[String]:
	var validation = validate_panel()
	if validation.valid:
		return []
	
	var errors = []
	if validation.error and not validation.error.is_empty():
		errors.append(validation.error)
	if validation.errors and validation.errors.size() > 0:
		errors.append_array(validation.errors)
	return errors

## Force validation check - useful for UI updates
func force_validation_check() -> void:
	_validate_and_emit_completion()

## Get panel name for display
func get_panel_name() -> String:
	return get_class()

## Get panel description for tooltips/help
func get_panel_description() -> String:
	return "Campaign creation panel"