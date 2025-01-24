extends "res://addons/gut/test.gd"

const UpkeepPhaseUI = preload("res://src/ui/screens/campaign/UpkeepPhaseUI.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var phase_ui: UpkeepPhaseUI
var phase_completed_signal_emitted := false
var resource_updated_signal_emitted := false
var last_resource_type: GameEnums.ResourceType
var last_resource_value: int

func before_each() -> void:
	phase_ui = UpkeepPhaseUI.new()
	add_child(phase_ui)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	phase_ui.queue_free()

func _reset_signals() -> void:
	phase_completed_signal_emitted = false
	resource_updated_signal_emitted = false
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0

func _connect_signals() -> void:
	phase_ui.phase_completed.connect(_on_phase_completed)
	phase_ui.resource_updated.connect(_on_resource_updated)

func _on_phase_completed() -> void:
	phase_completed_signal_emitted = true

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

func test_initial_setup() -> void:
	assert_not_null(phase_ui)
	assert_not_null(phase_ui.resource_panel)
	assert_not_null(phase_ui.action_panel)
	assert_not_null(phase_ui.status_panel)

func test_upkeep_costs() -> void:
	var test_resources = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50
	}
	
	# Set initial resources
	for resource_type in test_resources:
		phase_ui.update_resource(resource_type, test_resources[resource_type])
		assert_eq(phase_ui.get_resource_value(resource_type), test_resources[resource_type])
	
	# Apply upkeep costs
	phase_ui.apply_upkeep_costs()
	
	# Verify resources were reduced
	for resource_type in test_resources:
		var new_value = phase_ui.get_resource_value(resource_type)
		assert_true(new_value < test_resources[resource_type])

func test_maintenance_action() -> void:
	# Set up initial resources
	phase_ui.update_resource(GameEnums.ResourceType.CREDITS, 1000)
	_reset_signals()
	
	# Perform maintenance
	phase_ui.perform_maintenance()
	
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_type, GameEnums.ResourceType.CREDITS)
	assert_true(last_resource_value < 1000)

func test_resupply_action() -> void:
	# Set up initial resources
	phase_ui.update_resource(GameEnums.ResourceType.CREDITS, 1000)
	phase_ui.update_resource(GameEnums.ResourceType.SUPPLIES, 0)
	_reset_signals()
	
	# Perform resupply
	phase_ui.perform_resupply()
	
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_type, GameEnums.ResourceType.SUPPLIES)
	assert_true(last_resource_value > 0)

func test_phase_completion() -> void:
	# Complete all required actions
	phase_ui.perform_maintenance()
	phase_ui.perform_resupply()
	phase_ui.apply_upkeep_costs()
	
	# Check phase completion
	phase_ui.complete_phase()
	assert_true(phase_completed_signal_emitted)

func test_insufficient_resources() -> void:
	# Set up insufficient resources
	phase_ui.update_resource(GameEnums.ResourceType.CREDITS, 0)
	phase_ui.update_resource(GameEnums.ResourceType.SUPPLIES, 0)
	
	# Try to perform actions
	phase_ui.perform_maintenance()
	assert_false(resource_updated_signal_emitted)
	
	phase_ui.perform_resupply()
	assert_false(resource_updated_signal_emitted)

func test_status_updates() -> void:
	# Verify initial status
	assert_false(phase_ui.is_maintenance_complete())
	assert_false(phase_ui.is_resupply_complete())
	assert_false(phase_ui.is_upkeep_complete())
	
	# Complete actions and verify status
	phase_ui.perform_maintenance()
	assert_true(phase_ui.is_maintenance_complete())
	
	phase_ui.perform_resupply()
	assert_true(phase_ui.is_resupply_complete())
	
	phase_ui.apply_upkeep_costs()
	assert_true(phase_ui.is_upkeep_complete())

func test_action_availability() -> void:
	# Test initial action availability
	assert_true(phase_ui.can_perform_maintenance())
	assert_true(phase_ui.can_perform_resupply())
	
	# Set insufficient resources
	phase_ui.update_resource(GameEnums.ResourceType.CREDITS, 0)
	
	# Verify actions are unavailable
	assert_false(phase_ui.can_perform_maintenance())
	assert_false(phase_ui.can_perform_resupply())

func test_resource_validation() -> void:
	# Test invalid resource type
	var invalid_type = -1
	phase_ui.update_resource(invalid_type, 100)
	assert_false(resource_updated_signal_emitted)
	
	# Test negative values
	phase_ui.update_resource(GameEnums.ResourceType.CREDITS, -50)
	assert_true(resource_updated_signal_emitted)
	assert_eq(phase_ui.get_resource_value(GameEnums.ResourceType.CREDITS), -50)

func test_phase_reset() -> void:
	# Complete some actions
	phase_ui.perform_maintenance()
	phase_ui.perform_resupply()
	
	# Reset phase
	phase_ui.reset_phase()
	
	# Verify everything is reset
	assert_false(phase_ui.is_maintenance_complete())
	assert_false(phase_ui.is_resupply_complete())
	assert_false(phase_ui.is_upkeep_complete())