extends "res://addons/gut/test.gd"

const CampaignDashboard = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var dashboard: CampaignDashboard
var phase_changed_signal_emitted := false
var resource_updated_signal_emitted := false
var event_logged_signal_emitted := false
var last_phase: GameEnums.FiveParcsecsCampaignPhase
var last_resource_type: GameEnums.ResourceType
var last_resource_value: int
var last_event_data: Dictionary

func before_each() -> void:
	dashboard = CampaignDashboard.new()
	add_child(dashboard)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	dashboard.queue_free()

func _reset_signals() -> void:
	phase_changed_signal_emitted = false
	resource_updated_signal_emitted = false
	event_logged_signal_emitted = false
	last_phase = GameEnums.FiveParcsecsCampaignPhase.SETUP
	last_resource_type = GameEnums.ResourceType.NONE
	last_resource_value = 0
	last_event_data = {}

func _connect_signals() -> void:
	dashboard.phase_changed.connect(_on_phase_changed)
	dashboard.resource_updated.connect(_on_resource_updated)
	dashboard.event_logged.connect(_on_event_logged)

func _on_phase_changed(new_phase: GameEnums.FiveParcsecsCampaignPhase) -> void:
	phase_changed_signal_emitted = true
	last_phase = new_phase

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

func _on_event_logged(event_data: Dictionary) -> void:
	event_logged_signal_emitted = true
	last_event_data = event_data

func test_initial_setup() -> void:
	assert_not_null(dashboard)
	assert_not_null(dashboard.phase_indicator)
	assert_not_null(dashboard.resource_display)
	assert_not_null(dashboard.event_log)
	assert_eq(dashboard.current_phase, GameEnums.FiveParcsecsCampaignPhase.SETUP)

func test_phase_change() -> void:
	var test_phase = GameEnums.FiveParcsecsCampaignPhase.UPKEEP
	dashboard.set_phase(test_phase)
	
	assert_true(phase_changed_signal_emitted)
	assert_eq(last_phase, test_phase)
	assert_eq(dashboard.current_phase, test_phase)
	assert_eq(dashboard.phase_indicator.current_phase, test_phase)

func test_resource_update() -> void:
	var test_type = GameEnums.ResourceType.CREDITS
	var test_value = 100
	dashboard.update_resource(test_type, test_value)
	
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_type, test_type)
	assert_eq(last_resource_value, test_value)
	assert_eq(dashboard.get_resource_value(test_type), test_value)

func test_event_logging() -> void:
	var test_event = {
		"title": "Test Event",
		"description": "Test event description",
		"category": "test",
		"phase": "setup"
	}
	
	dashboard.log_event(test_event)
	
	assert_true(event_logged_signal_emitted)
	assert_eq(last_event_data.title, test_event.title)
	assert_eq(last_event_data.description, test_event.description)
	assert_eq(last_event_data.category, test_event.category)

func test_campaign_state() -> void:
	# Test initial state
	var initial_state = dashboard.get_campaign_state()
	assert_not_null(initial_state)
	assert_eq(initial_state.phase, GameEnums.FiveParcsecsCampaignPhase.SETUP)
	
	# Test state after updates
	dashboard.set_phase(GameEnums.FiveParcsecsCampaignPhase.UPKEEP)
	dashboard.update_resource(GameEnums.ResourceType.CREDITS, 100)
	
	var updated_state = dashboard.get_campaign_state()
	assert_eq(updated_state.phase, GameEnums.FiveParcsecsCampaignPhase.UPKEEP)
	assert_eq(updated_state.resources[GameEnums.ResourceType.CREDITS], 100)

func test_multiple_resources() -> void:
	var test_resources = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 50,
		GameEnums.ResourceType.TECH_PARTS: 25
	}
	
	for resource_type in test_resources:
		dashboard.update_resource(resource_type, test_resources[resource_type])
		assert_eq(dashboard.get_resource_value(resource_type), test_resources[resource_type])

func test_phase_transitions() -> void:
	var phases = [
		GameEnums.FiveParcsecsCampaignPhase.SETUP,
		GameEnums.FiveParcsecsCampaignPhase.UPKEEP,
		GameEnums.FiveParcsecsCampaignPhase.STORY,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP
	]
	
	for phase in phases:
		dashboard.set_phase(phase)
		assert_eq(dashboard.current_phase, phase)
		assert_eq(dashboard.phase_indicator.current_phase, phase)
		_reset_signals()

func test_event_history() -> void:
	var test_events = [
		{"title": "Event 1", "description": "Description 1", "category": "test", "phase": "setup"},
		{"title": "Event 2", "description": "Description 2", "category": "test", "phase": "upkeep"},
		{"title": "Event 3", "description": "Description 3", "category": "test", "phase": "story"}
	]
	
	for event in test_events:
		dashboard.log_event(event)
		_reset_signals()
	
	var history = dashboard.get_event_history()
	assert_eq(history.size(), test_events.size())

func test_resource_validation() -> void:
	# Test invalid resource type
	var invalid_type = -1
	dashboard.update_resource(invalid_type, 100)
	assert_false(resource_updated_signal_emitted)
	
	# Test negative values
	dashboard.update_resource(GameEnums.ResourceType.CREDITS, -50)
	assert_true(resource_updated_signal_emitted)
	assert_eq(dashboard.get_resource_value(GameEnums.ResourceType.CREDITS), -50)