# Tests for the UpkeepPhaseUI functionality
@tool
extends GameTest

const UpkeepPhaseUI = preload("res://src/ui/screens/campaign/UpkeepPhaseUI.gd")

var phase_ui: UpkeepPhaseUI
var phase_completed_signal_emitted := false
var resource_updated_signal_emitted := false
var last_resource_type: GameEnums.ResourceType = GameEnums.ResourceType.NONE
var last_resource_value: int = 0

# Type-safe property access
func _get_ui_property(property: String, default_value: Variant = null) -> Variant:
	if not phase_ui:
		push_error("Trying to access property '%s' on null phase UI" % property)
		return default_value
	if not property in phase_ui:
		push_error("Phase UI missing required property: %s" % property)
		return default_value
	return phase_ui.get(property)

func _set_ui_property(property: String, value: Variant) -> void:
	if not phase_ui:
		push_error("Trying to set property '%s' on null phase UI" % property)
		return
	if not property in phase_ui:
		push_error("Phase UI missing required property: %s" % property)
		return
	phase_ui.set(property, value)

# Type-safe test lifecycle
func before_each() -> void:
	await super.before_each()
	phase_ui = UpkeepPhaseUI.new()
	add_child_autofree(phase_ui)
	track_test_node(phase_ui)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	if phase_ui:
		phase_ui.queue_free()
		phase_ui = null
	await super.after_each()

# Type-safe signal handling
func _reset_signals() -> void:
	phase_completed_signal_emitted = false
	resource_updated_signal_emitted = false
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0

func _connect_signals() -> void:
	if not phase_ui:
		return
		
	if phase_ui.has_signal("phase_completed"):
		phase_ui.connect("phase_completed", _on_phase_completed)
	if phase_ui.has_signal("resource_updated"):
		phase_ui.connect("resource_updated", _on_resource_updated)

func _disconnect_signals() -> void:
	if not phase_ui:
		return
		
	if phase_ui.has_signal("phase_completed") and phase_ui.is_connected("phase_completed", _on_phase_completed):
		phase_ui.disconnect("phase_completed", _on_phase_completed)
	if phase_ui.has_signal("resource_updated") and phase_ui.is_connected("resource_updated", _on_resource_updated):
		phase_ui.disconnect("resource_updated", _on_resource_updated)

func _on_phase_completed() -> void:
	phase_completed_signal_emitted = true

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

# Type-safe test methods
func test_initial_setup() -> void:
	assert_not_null(phase_ui, "Phase UI should exist")
	
	var resource_panel: Node = _get_ui_property("resource_panel")
	var action_panel: Node = _get_ui_property("action_panel")
	var status_panel: Node = _get_ui_property("status_panel")
	
	assert_not_null(resource_panel, "Resource panel should exist")
	assert_not_null(action_panel, "Action panel should exist")
	assert_not_null(status_panel, "Status panel should exist")

func test_upkeep_costs() -> void:
	var test_resources := {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50
	}
	
	# Set initial resources
	for resource_type in test_resources:
		var value: int = test_resources[resource_type]
		_call_node_method(phase_ui, "update_resource", [resource_type, value])
		
		var resource_values: Dictionary = _get_ui_property("resource_values", {})
		var current_value: int = resource_values.get(resource_type, 0)
		assert_eq(current_value, value, "Resource %s should be set correctly" % resource_type)
	
	# Apply upkeep costs
	_call_node_method(phase_ui, "apply_upkeep_costs")
	
	# Verify resources were reduced
	var resource_values: Dictionary = _get_ui_property("resource_values", {})
	for resource_type in test_resources:
		var new_value: int = resource_values.get(resource_type, 0)
		var original_value: int = test_resources[resource_type]
		assert_true(new_value < original_value, "Resource %s should be reduced after upkeep" % resource_type)

func test_maintenance_action() -> void:
	# Set up initial resources
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.CREDITS, 1000])
	_reset_signals()
	
	# Perform maintenance
	_call_node_method(phase_ui, "perform_maintenance")
	
	assert_true(resource_updated_signal_emitted, "Resource updated signal should be emitted")
	assert_eq(last_resource_type, GameEnums.ResourceType.CREDITS, "Credits should be updated")
	assert_true(last_resource_value < 1000, "Credits should be reduced")

func test_resupply_action() -> void:
	# Set up initial resources
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.CREDITS, 1000])
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.SUPPLIES, 0])
	_reset_signals()
	
	# Perform resupply
	_call_node_method(phase_ui, "perform_resupply")
	
	assert_true(resource_updated_signal_emitted, "Resource updated signal should be emitted")
	assert_eq(last_resource_type, GameEnums.ResourceType.SUPPLIES, "Supplies should be updated")
	assert_true(last_resource_value > 0, "Supplies should be increased")

func test_phase_completion() -> void:
	# Complete all required actions
	_call_node_method(phase_ui, "perform_maintenance")
	_call_node_method(phase_ui, "perform_resupply")
	_call_node_method(phase_ui, "apply_upkeep_costs")
	
	# Check phase completion
	_call_node_method(phase_ui, "complete_phase")
	assert_true(phase_completed_signal_emitted, "Phase completed signal should be emitted")

func test_insufficient_resources() -> void:
	# Set up insufficient resources
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.CREDITS, 0])
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.SUPPLIES, 0])
	
	# Try to perform actions
	_call_node_method(phase_ui, "perform_maintenance")
	assert_false(resource_updated_signal_emitted, "Should not update resources when insufficient")
	
	_call_node_method(phase_ui, "perform_resupply")
	assert_false(resource_updated_signal_emitted, "Should not update resources when insufficient")

func test_status_updates() -> void:
	# Verify initial status
	assert_false(_get_ui_property("is_maintenance_complete"), "Maintenance should not start complete")
	assert_false(_get_ui_property("is_resupply_complete"), "Resupply should not start complete")
	assert_false(_get_ui_property("is_upkeep_complete"), "Upkeep should not start complete")
	
	# Complete actions and verify status
	_call_node_method(phase_ui, "perform_maintenance")
	assert_true(_get_ui_property("is_maintenance_complete"), "Maintenance should be complete")
	
	_call_node_method(phase_ui, "perform_resupply")
	assert_true(_get_ui_property("is_resupply_complete"), "Resupply should be complete")
	
	_call_node_method(phase_ui, "apply_upkeep_costs")
	assert_true(_get_ui_property("is_upkeep_complete"), "Upkeep should be complete")

func test_action_availability() -> void:
	# Test initial action availability
	assert_true(_get_ui_property("can_perform_maintenance"), "Should be able to perform maintenance initially")
	assert_true(_get_ui_property("can_perform_resupply"), "Should be able to perform resupply initially")
	
	# Set insufficient resources
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.CREDITS, 0])
	
	# Verify actions are unavailable
	assert_false(_get_ui_property("can_perform_maintenance"), "Should not be able to perform maintenance without credits")
	assert_false(_get_ui_property("can_perform_resupply"), "Should not be able to perform resupply without credits")

func test_resource_validation() -> void:
	# Test invalid resource type
	var invalid_type = -1
	_call_node_method(phase_ui, "update_resource", [invalid_type, 100])
	assert_false(resource_updated_signal_emitted, "Should not emit signal for invalid resource type")
	
	# Test negative values
	_call_node_method(phase_ui, "update_resource", [GameEnums.ResourceType.CREDITS, -50])
	assert_true(resource_updated_signal_emitted, "Should emit signal even for negative values")
	var resource_values: Dictionary = _get_ui_property("resource_values", {})
	assert_eq(resource_values.get(GameEnums.ResourceType.CREDITS, 0), -50,
		"Should allow negative resource values")

func test_phase_reset() -> void:
	# Complete some actions
	_call_node_method(phase_ui, "perform_maintenance")
	_call_node_method(phase_ui, "perform_resupply")
	
	# Reset phase
	_call_node_method(phase_ui, "reset_phase")
	
	# Verify everything is reset
	assert_false(_get_ui_property("is_maintenance_complete"), "Maintenance should be reset")
	assert_false(_get_ui_property("is_resupply_complete"), "Resupply should be reset")
	assert_false(_get_ui_property("is_upkeep_complete"), "Upkeep should be reset")