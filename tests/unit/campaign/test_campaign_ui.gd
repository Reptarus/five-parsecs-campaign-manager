extends "res://addons/gut/test.gd"

const CampaignUI = preload("res://src/scenes/campaign/CampaignUI.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var ui: CampaignUI
var phase_changed_signal_emitted := false
var resource_updated_signal_emitted := false
var event_occurred_signal_emitted := false
var last_phase: GameEnums.CampaignPhase
var last_resource_type: GameEnums.ResourceType
var last_resource_value: int
var last_event_data: Dictionary

func before_each() -> void:
	ui = CampaignUI.new()
	add_child(ui)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	ui.queue_free()

func _reset_signals() -> void:
	phase_changed_signal_emitted = false
	resource_updated_signal_emitted = false
	event_occurred_signal_emitted = false
	last_phase = GameEnums.CampaignPhase.SETUP
	last_resource_type = GameEnums.ResourceType.CREDITS
	last_resource_value = 0
	last_event_data = {}

func _connect_signals() -> void:
	ui.phase_changed.connect(_on_phase_changed)
	ui.resource_updated.connect(_on_resource_updated)
	ui.event_occurred.connect(_on_event_occurred)

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	phase_changed_signal_emitted = true
	last_phase = new_phase

func _on_resource_updated(resource_type: GameEnums.ResourceType, new_value: int) -> void:
	resource_updated_signal_emitted = true
	last_resource_type = resource_type
	last_resource_value = new_value

func _on_event_occurred(event_data: Dictionary) -> void:
	event_occurred_signal_emitted = true
	last_event_data = event_data

func test_initial_setup() -> void:
	assert_not_null(ui)
	assert_eq(ui._current_phase, GameEnums.CampaignPhase.SETUP)
	assert_not_null(ui._layout)

func test_phase_change() -> void:
	var new_phase = GameEnums.CampaignPhase.UPKEEP
	ui._on_phase_changed(new_phase)
	
	assert_true(phase_changed_signal_emitted)
	assert_eq(last_phase, new_phase)
	assert_eq(ui._current_phase, new_phase)

func test_resource_update() -> void:
	var resource_type = GameEnums.ResourceType.CREDITS
	var new_value = 100
	ui._on_resource_updated(resource_type, new_value)
	
	assert_true(resource_updated_signal_emitted)
	assert_eq(last_resource_type, resource_type)
	assert_eq(last_resource_value, new_value)

func test_event_logging() -> void:
	var test_event = {
		"id": "test_event",
		"title": "Test Event",
		"description": "Test event description",
		"category": "test"
	}
	
	ui._on_event_occurred(test_event)
	
	assert_true(event_occurred_signal_emitted)
	assert_eq(last_event_data.id, test_event.id)
	assert_eq(last_event_data.title, test_event.title)
	assert_eq(last_event_data.description, test_event.description)
	assert_eq(last_event_data.category, test_event.category)

func test_phase_action_handling() -> void:
	# Test crew creation action
	ui._handle_crew_creation()
	assert_eq(get_tree().current_scene.scene_file_path, "res://src/scenes/character/CrewCreation.tscn")
	
	# Test campaign selection action
	ui._handle_campaign_selection()
	assert_eq(get_tree().current_scene.scene_file_path, "res://src/scenes/campaign/CampaignSelection.tscn")
	
	# Test resource management action
	ui._handle_resource_management()
	assert_eq(get_tree().current_scene.scene_file_path, "res://src/scenes/resource/ResourceManagement.tscn")

func test_ui_components_setup() -> void:
	ui._setup_ui_components()
	
	# Test resource panel setup
	var credits_label = ui.resource_panel.get_node("credits_label")
	var supplies_label = ui.resource_panel.get_node("supplies_label")
	var reputation_label = ui.resource_panel.get_node("reputation_label")
	var tech_parts_label = ui.resource_panel.get_node("tech_parts_label")
	
	assert_not_null(credits_label)
	assert_not_null(supplies_label)
	assert_not_null(reputation_label)
	assert_not_null(tech_parts_label)
	
	assert_eq(credits_label.text, "Credits: 0")
	assert_eq(supplies_label.text, "Supplies: 0")
	assert_eq(reputation_label.text, "Reputation: 0")
	assert_eq(tech_parts_label.text, "Tech Parts: 0")