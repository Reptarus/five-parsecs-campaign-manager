@tool
extends GameTest

const TestedClass: GDScript = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")

var _instance: Node = null
var campaign_updated_signal_emitted: bool = false
var last_campaign_data: Dictionary = {}

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("campaign_updated"):
		_instance.connect("campaign_updated", _on_campaign_updated)

func _reset_signals() -> void:
	campaign_updated_signal_emitted = false
	last_campaign_data = {}

func _on_campaign_updated(campaign_data: Dictionary) -> void:
	campaign_updated_signal_emitted = true
	last_campaign_data = campaign_data

func before_each() -> void:
	await super.before_each()
	
	_instance = TestedClass.new()
	if not _instance:
		push_error("Failed to create dashboard instance")
		return
	add_child_autofree(_instance)
	track_test_node(_instance)
	
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	if is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await get_tree().process_frame
	await super.after_each()

# Basic State Tests
func test_initial_state() -> void:
	var game_state: Node = _get_node_safe(_instance, "GameState")
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	
	assert_not_null(game_state, "Game state should be initialized")
	assert_not_null(phase_manager, "Phase manager should be initialized")
	
	var current_phase: int = _get_property_safe(phase_manager, "current_phase", -1)
	assert_eq(current_phase, GameEnums.CampaignPhase.UPKEEP,
		"Should start in upkeep phase")

# Phase Transition Tests
func test_phase_transitions() -> void:
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	assert_not_null(phase_manager, "Phase manager should exist")
	
	watch_signals(phase_manager)
	
	_call_node_method(_instance, "_on_next_phase_pressed")
	await get_tree().process_frame
	
	verify_signal_emitted(phase_manager, "phase_changed")
	
	var current_phase: int = _get_property_safe(phase_manager, "current_phase", -1)
	assert_eq(current_phase, GameEnums.CampaignPhase.STORY,
		"Should transition to story phase")
	
	_call_node_method(_instance, "_on_next_phase_pressed")
	await get_tree().process_frame
	
	current_phase = _get_property_safe(phase_manager, "current_phase", -1)
	assert_eq(current_phase, GameEnums.CampaignPhase.CAMPAIGN,
		"Should transition to campaign phase")

# UI Update Tests
func test_ui_updates() -> void:
	# Setup mock campaign data
	var campaign_data: Dictionary = {
		"credits": 1000,
		"story_points": 5,
		"crew_members": [
			{"character_name": "Test Character"}
		]
	}
	_set_property_safe(_game_state, "campaign", campaign_data)
	
	_call_node_method(_instance, "_update_ui")
	await get_tree().process_frame
	
	var credits_label: Node = _get_node_safe(_instance, "CreditsLabel")
	var story_points_label: Node = _get_node_safe(_instance, "StoryPointsLabel")
	var crew_list: Node = _get_node_safe(_instance, "CrewList")
	
	assert_not_null(credits_label, "Credits label should exist")
	assert_not_null(story_points_label, "Story points label should exist")
	assert_not_null(crew_list, "Crew list should exist")
	
	var credits_text: String = _get_property_safe(credits_label, "text", "")
	assert_eq(credits_text, "Credits: 1000",
		"Credits label should update")
	
	var points_text: String = _get_property_safe(story_points_label, "text", "")
	assert_eq(points_text, "Story Points: 5",
		"Story points label should update")
	
	var item_count: int = _call_node_method_int(crew_list, "get_item_count")
	assert_eq(item_count, 1,
		"Crew list should show one member")

# Phase Panel Tests
func test_phase_panel_creation() -> void:
	var panel: Node = _call_node_method(_instance, "_create_phase_panel", [GameEnums.CampaignPhase.UPKEEP])
	assert_not_null(panel, "Should create upkeep phase panel")
	panel.queue_free()
	
	panel = _call_node_method(_instance, "_create_phase_panel", [GameEnums.CampaignPhase.STORY])
	assert_not_null(panel, "Should create story phase panel")
	panel.queue_free()

# Event Handler Tests
func test_phase_event_handling() -> void:
	watch_signals(_instance)
	
	var next_phase_button: Node = _get_node_safe(_instance, "NextPhaseButton")
	assert_not_null(next_phase_button, "Next phase button should exist")
	
	_call_node_method(_instance, "_on_phase_event", [ {"type": "UPKEEP_STARTED"}])
	await get_tree().process_frame
	
	var is_visible: bool = _get_property_safe(next_phase_button, "visible", false)
	assert_true(is_visible,
		"Next phase button should be visible after upkeep start")
	
	_call_node_method(_instance, "_on_phase_completed")
	await get_tree().process_frame
	
	var is_disabled: bool = _get_property_safe(next_phase_button, "disabled", true)
	assert_false(is_disabled,
		"Next phase button should be enabled after phase completion")

# Navigation Tests
func test_navigation_buttons() -> void:
	watch_signals(get_tree())
	
	_call_node_method(_instance, "_on_manage_crew_pressed")
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "change_scene_to_file")
	
	_call_node_method(_instance, "_on_quit_pressed")
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "change_scene_to_file")

# Performance Tests
func test_rapid_phase_transitions() -> void:
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	assert_not_null(phase_manager, "Phase manager should exist")
	
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(10):
		_call_node_method(_instance, "_on_next_phase_pressed")
		await get_tree().process_frame
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_true(duration < 1000,
		"Should handle rapid phase transitions efficiently")

# Error Boundary Tests
func test_invalid_phase_transitions() -> void:
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	assert_not_null(phase_manager, "Phase manager should exist")
	
	_set_property_safe(phase_manager, "current_phase", GameEnums.CampaignPhase.NONE)
	_call_node_method(_instance, "_on_next_phase_pressed")
	await get_tree().process_frame
	
	var current_phase: int = _get_property_safe(phase_manager, "current_phase", -1)
	assert_eq(current_phase, GameEnums.CampaignPhase.NONE,
		"Should not transition from invalid phase")

# Save/Load Tests
func test_save_load_operations() -> void:
	var game_state: Node = _get_node_safe(_instance, "GameState")
	watch_signals(game_state)
	watch_signals(get_tree())
	
	_call_node_method(_instance, "_on_save_pressed")
	await get_tree().process_frame
	verify_signal_emitted(game_state, "save_campaign")
	
	_call_node_method(_instance, "_on_load_pressed")
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "change_scene_to_file")