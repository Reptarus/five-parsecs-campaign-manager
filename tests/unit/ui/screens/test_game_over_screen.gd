@tool
extends GameTest

const TestedClass: GDScript = preload("res://src/ui/screens/GameOverScreen.gd")

var _instance: Control = null
var victory_achieved_signal_emitted: bool = false
var last_victory_data: Dictionary = {}

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	_instance = TestedClass.new()
	if not _instance:
		push_error("Failed to create game over screen instance")
		return
	add_child_autofree(_instance)
	track_test_node(_instance)
	
	_connect_signals()
	_reset_signals()
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(_instance):
		remove_child(_instance)
		_instance.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	_instance = null
	
	# Let parent handle remaining cleanup
	await super.after_each()
	
	# Clear any tracked resources
	_tracked_resources.clear()

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("victory_achieved"):
		_instance.connect("victory_achieved", _on_victory_achieved)

func _reset_signals() -> void:
	victory_achieved_signal_emitted = false
	last_victory_data = {}

func _on_victory_achieved(victory_data: Dictionary) -> void:
	victory_achieved_signal_emitted = true
	last_victory_data = victory_data

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(_instance, "GameOverScreen should be initialized")
	assert_false(_get_property_safe(_instance, "visible", true), "Screen should be hidden initially")

# Display Tests
func test_show_game_over() -> void:
	# Setup mock campaign data
	var campaign_data: Dictionary = {
		"name": "Test Campaign",
		"victory_points": 100,
		"total_battles": 10,
		"crew_members": [
			{"character_name": "Test Character", "kills": 5}
		]
	}
	_set_property_safe(_game_state, "campaign", campaign_data)
	
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	assert_true(_get_property_safe(_instance, "visible", false), "Screen should be visible after game over")
	
	var victory_points_label: Label = _get_node_safe(_instance, "StatsContainer/VictoryPointsLabel")
	var battles_label: Label = _get_node_safe(_instance, "StatsContainer/BattlesLabel")
	
	assert_not_null(victory_points_label, "Victory points label should exist")
	assert_not_null(battles_label, "Battles label should exist")
	
	var points_text: String = _get_property_safe(victory_points_label, "text", "")
	var battles_text: String = _get_property_safe(battles_label, "text", "")
	
	assert_eq(points_text, "Victory Points: 100", "Should display correct victory points")
	assert_eq(battles_text, "Total Battles: 10", "Should display correct battle count")

# Victory Condition Tests
func test_victory_display() -> void:
	# Set up victory state in game state
	_set_property_safe(_game_state, "victory_achieved", true)
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	assert_not_null(victory_label, "Victory label should exist")
	assert_not_null(defeat_label, "Defeat label should exist")
	
	var victory_visible: bool = _get_property_safe(victory_label, "visible", false)
	var defeat_visible: bool = _get_property_safe(defeat_label, "visible", true)
	
	assert_true(victory_visible, "Victory label should be visible for victory")
	assert_false(defeat_visible, "Defeat label should be hidden for victory")

func test_defeat_display() -> void:
	# Set up defeat state in game state
	_set_property_safe(_game_state, "victory_achieved", false)
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	assert_not_null(victory_label, "Victory label should exist")
	assert_not_null(defeat_label, "Defeat label should exist")
	
	var victory_visible: bool = _get_property_safe(victory_label, "visible", false)
	var defeat_visible: bool = _get_property_safe(defeat_label, "visible", true)
	
	assert_true(defeat_visible, "Defeat label should be visible for defeat")
	assert_false(victory_visible, "Victory label should be hidden for defeat")

# Navigation Tests
func test_navigation_buttons() -> void:
	watch_signals(get_tree())
	
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var restart_button: Button = _get_node_safe(_instance, "ButtonContainer/RestartButton")
	var main_menu_button: Button = _get_node_safe(_instance, "ButtonContainer/MainMenuButton")
	
	assert_not_null(restart_button, "Restart button should exist")
	assert_not_null(main_menu_button, "Main menu button should exist")
	
	# Test restart button
	_call_node_method(restart_button, "emit_signal", ["pressed"])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "scene_restarted", "Scene restart signal should be emitted")
	
	# Test main menu button
	_call_node_method(main_menu_button, "emit_signal", ["pressed"])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "main_menu_requested", "Main menu signal should be emitted")

# Stats Display Tests
func test_stats_display() -> void:
	var campaign_data: Dictionary = {
		"stats": {
			"enemies_defeated": 20,
			"credits_earned": 1000,
			"missions_completed": 5
		}
	}
	_set_property_safe(_game_state, "campaign", campaign_data)
	
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var stats_container: Control = _get_node_safe(_instance, "StatsContainer")
	var enemies_defeated_label: Label = _get_node_safe(_instance, "StatsContainer/EnemiesDefeatedLabel")
	var credits_earned_label: Label = _get_node_safe(_instance, "StatsContainer/CreditsEarnedLabel")
	
	assert_not_null(stats_container, "Stats container should exist")
	assert_true(_get_property_safe(stats_container, "visible", false), "Stats container should be visible")
	
	assert_not_null(enemies_defeated_label, "Enemies defeated label should exist")
	assert_not_null(credits_earned_label, "Credits earned label should exist")
	
	var enemies_text: String = _get_property_safe(enemies_defeated_label, "text", "")
	var credits_text: String = _get_property_safe(credits_earned_label, "text", "")
	
	assert_eq(enemies_text, "Enemies Defeated: 20", "Should display correct enemies defeated")
	assert_eq(credits_text, "Credits Earned: 1000", "Should display correct credits earned")

# Performance Tests
func test_rapid_visibility_changes() -> void:
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(100):
		_call_node_method(_instance, "show")
		_call_node_method(_instance, "hide")
		await get_tree().process_frame
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should handle rapid visibility changes efficiently")

# Error Cases Tests
func test_null_campaign_data() -> void:
	_set_property_safe(_game_state, "campaign", null)
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_points_label: Label = _get_node_safe(_instance, "StatsContainer/VictoryPointsLabel")
	
	assert_true(_get_property_safe(_instance, "visible", false), "Screen should still show with null campaign data")
	assert_not_null(victory_points_label, "Victory points label should exist")
	assert_eq(_get_property_safe(victory_points_label, "text", ""), "Victory Points: 0", "Should show default values for null campaign")

# Cleanup Tests
func test_cleanup() -> void:
	_call_node_method(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	_call_node_method(_instance, "cleanup")
	await get_tree().process_frame
	
	assert_false(_get_property_safe(_instance, "visible", true), "Screen should be hidden after cleanup")
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	assert_not_null(victory_label, "Victory label should exist")
	assert_not_null(defeat_label, "Defeat label should exist")
	
	var victory_visible: bool = _get_property_safe(victory_label, "visible", true)
	var defeat_visible: bool = _get_property_safe(defeat_label, "visible", true)
	
	assert_false(victory_visible, "Victory label should be hidden after cleanup")
	assert_false(defeat_visible, "Defeat label should be hidden after cleanup")