@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

const CampaignDashboard: GDScript = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")

# Type-safe instance variables
var _instance: Node = null
var campaign_updated_signal_emitted: bool = false
var last_campaign_data: Dictionary = {}

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = GameState.new()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child(_game_state)
	track_test_node(_game_state)
	
	# Initialize dashboard
	_instance = CampaignDashboard.new()
	if not _instance:
		push_error("Failed to create dashboard instance")
		return
	add_child(_instance)
	track_test_node(_instance)
	await _instance.ready
	
	# Watch signals
	if _signal_watcher:
		_signal_watcher.watch_signals(_instance)
		_signal_watcher.watch_signals(_game_state)
	
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	if is_instance_valid(_instance):
		_instance.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
	_instance = null
	_game_state = null
	await super.after_each()

# Type-safe helper methods
func _get_node_safe(parent: Node, path: String) -> Node:
	if not parent:
		push_error("Parent node is null")
		return null
	var node := parent.get_node(path)
	if not node:
		push_error("Failed to get node at path: %s" % path)
	return node

func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not obj or not obj.has_method("get"):
		return default_value
	return obj.get(property) if obj.has(property) else default_value

func _set_property_safe(obj: Object, property: String, value: Variant) -> void:
	if not obj or not obj.has_method("set"):
		return
	if obj.has(property):
		obj.set(property, value)

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

# Test cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Dashboard should be initialized")
	
	var game_state: Node = _get_node_safe(_instance, "GameState")
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	
	assert_not_null(game_state, "Game state should be initialized")
	assert_not_null(phase_manager, "Phase manager should be initialized")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(phase_manager, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.CampaignPhase.UPKEEP, "Should start in upkeep phase")

# Phase Transition Tests
func test_phase_transitions() -> void:
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	assert_not_null(phase_manager, "Phase manager should exist")
	
	if _signal_watcher:
		_signal_watcher.watch_signals(phase_manager)
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_next_phase_pressed", [])
	await get_tree().process_frame
	
	verify_signal_emitted(phase_manager, "phase_changed")
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(phase_manager, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.CampaignPhase.STORY, "Should transition to story phase")
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_next_phase_pressed", [])
	await get_tree().process_frame
	
	current_phase = TypeSafeMixin._call_node_method_int(phase_manager, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.CampaignPhase.CAMPAIGN, "Should transition to campaign phase")

# UI Update Tests
func test_ui_updates() -> void:
	# Setup mock campaign data
	var campaign_data := {
		"credits": 1000,
		"story_points": 5,
		"crew_members": [
			{"character_name": "Test Character"}
		]
	}
	TypeSafeMixin._call_node_method_bool(_game_state, "set_campaign", [campaign_data])
	
	TypeSafeMixin._call_node_method_bool(_instance, "_update_ui", [])
	await get_tree().process_frame
	
	var credits_label: Node = _get_node_safe(_instance, "CreditsLabel")
	var story_points_label: Node = _get_node_safe(_instance, "StoryPointsLabel")
	var crew_list: Node = _get_node_safe(_instance, "CrewList")
	
	assert_not_null(credits_label, "Credits label should exist")
	assert_not_null(story_points_label, "Story points label should exist")
	assert_not_null(crew_list, "Crew list should exist")
	
	var credits_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(credits_label, "get_text", []))
	assert_eq(credits_text, "Credits: 1000", "Credits label should update")
	
	var points_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(story_points_label, "get_text", []))
	assert_eq(points_text, "Story Points: 5", "Story points label should update")
	
	var item_count: int = TypeSafeMixin._call_node_method_int(crew_list, "get_item_count", [])
	assert_eq(item_count, 1, "Crew list should show one member")

# Phase Panel Tests
func test_phase_panel_creation() -> void:
	var panel: Node = TypeSafeMixin._call_node_method(_instance, "_create_phase_panel", [GameEnums.CampaignPhase.UPKEEP]) as Node
	assert_not_null(panel, "Should create upkeep phase panel")
	if panel:
		panel.queue_free()
	
	panel = TypeSafeMixin._call_node_method(_instance, "_create_phase_panel", [GameEnums.CampaignPhase.STORY]) as Node
	assert_not_null(panel, "Should create story phase panel")
	if panel:
		panel.queue_free()

# Event Handler Tests
func test_phase_event_handling() -> void:
	if _signal_watcher:
		_signal_watcher.watch_signals(_instance)
	
	var next_phase_button: Node = _get_node_safe(_instance, "NextPhaseButton")
	assert_not_null(next_phase_button, "Next phase button should exist")
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_phase_event", [ {"type": "UPKEEP_STARTED"}])
	await get_tree().process_frame
	
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(next_phase_button, "is_visible", [])
	assert_true(is_visible, "Next phase button should be visible after upkeep start")
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_phase_completed", [])
	await get_tree().process_frame
	
	var is_disabled: bool = TypeSafeMixin._call_node_method_bool(next_phase_button, "is_disabled", [])
	assert_false(is_disabled, "Next phase button should be enabled after phase completion")

# Navigation Tests
func test_navigation_buttons() -> void:
	if _signal_watcher:
		_signal_watcher.watch_signals(get_tree())
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_manage_crew_pressed", [])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "change_scene_to_file")
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_quit_pressed", [])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "change_scene_to_file")

# Performance Tests
func test_rapid_phase_transitions() -> void:
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	assert_not_null(phase_manager, "Phase manager should exist")
	
	var start_time := Time.get_ticks_msec()
	
	for i in range(10):
		TypeSafeMixin._call_node_method_bool(_instance, "_on_next_phase_pressed", [])
		await get_tree().process_frame
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_lt(duration, 1000, "Should handle rapid phase transitions efficiently")

# Error Boundary Tests
func test_invalid_phase_transitions() -> void:
	var phase_manager: Node = _get_node_safe(_instance, "PhaseManager")
	assert_not_null(phase_manager, "Phase manager should exist")
	
	TypeSafeMixin._call_node_method_bool(phase_manager, "set_current_phase", [GameEnums.CampaignPhase.NONE])
	TypeSafeMixin._call_node_method_bool(_instance, "_on_next_phase_pressed", [])
	await get_tree().process_frame
	
	var current_phase: int = TypeSafeMixin._call_node_method_int(phase_manager, "get_current_phase", [])
	assert_eq(current_phase, GameEnums.CampaignPhase.NONE, "Should not transition from invalid phase")

# Save/Load Tests
func test_save_load_operations() -> void:
	var game_state: Node = _get_node_safe(_instance, "GameState")
	if _signal_watcher:
		_signal_watcher.watch_signals(game_state)
		_signal_watcher.watch_signals(get_tree())
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_save_pressed", [])
	await get_tree().process_frame
	verify_signal_emitted(game_state, "save_campaign")
	
	TypeSafeMixin._call_node_method_bool(_instance, "_on_load_pressed", [])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "change_scene_to_file")