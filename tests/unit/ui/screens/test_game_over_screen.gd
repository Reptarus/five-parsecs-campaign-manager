@tool
extends GameTest

const GameOverScreen: GDScript = preload("res://src/ui/screens/GameOverScreen.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")

# Type-safe instance variables
var _instance: Node = null
var _game_state: Node = null
var victory_achieved_signal_emitted: bool = false
var last_victory_data: Dictionary = {}

# Type-safe lifecycle methods
func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = GameState.new()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child(_game_state)
	track_test_node(_game_state)
	
	# Initialize game over screen
	_instance = GameOverScreen.new()
	if not _instance:
		push_error("Failed to create game over screen")
		return
	add_child(_instance)
	track_test_node(_instance)
	await _instance.ready
	
	# Watch signals
	if _signal_watcher:
		_signal_watcher.watch_signals(_instance)
		_signal_watcher.watch_signals(get_tree())
	
	_connect_signals()
	_reset_signals()
	
	await stabilize_engine()

func after_each() -> void:
	if is_instance_valid(_instance):
		_instance.queue_free()
	if is_instance_valid(_game_state):
		_game_state.queue_free()
	_instance = null
	_game_state = null
	await super.after_each()
	
	# Clear any tracked resources
	_tracked_resources.clear()

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

# Test cases
func test_initial_state() -> void:
	assert_not_null(_instance, "GameOverScreen should be initialized")
	assert_false(TypeSafeMixin._safe_method_call_bool(_instance, "get", ["visible"]), "Screen should be hidden initially")

# Display Tests
func test_show_game_over() -> void:
	# Set up test campaign data
	var campaign_data := {
		"victory_points": 100,
		"total_battles": 10,
		"stats": [
			{"type": "enemies_defeated", "value": 20},
			{"type": "credits_earned", "value": 1000}
		]
	}
	TypeSafeMixin._safe_method_call_bool(_game_state, "set", ["campaign", campaign_data])
	
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	assert_true(TypeSafeMixin._safe_method_call_bool(_instance, "get", ["visible"]), "Screen should be visible after game over")
	
	var victory_points_label: Label = _get_node_safe(_instance, "StatsContainer/VictoryPointsLabel")
	var battles_label: Label = _get_node_safe(_instance, "StatsContainer/BattlesLabel")
	
	assert_not_null(victory_points_label, "Victory points label should exist")
	assert_not_null(battles_label, "Battles label should exist")
	
	var points_text: String = TypeSafeMixin._safe_method_call_string(victory_points_label, "get", ["text"])
	var battles_text: String = TypeSafeMixin._safe_method_call_string(battles_label, "get", ["text"])
	
	assert_eq(points_text, "Victory Points: 100", "Should display correct victory points")
	assert_eq(battles_text, "Total Battles: 10", "Should display correct battle count")

func test_victory_display() -> void:
	# Set up victory state in game state
	TypeSafeMixin._safe_method_call_bool(_game_state, "set", ["victory_achieved", true])
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	assert_not_null(victory_label, "Victory label should exist")
	assert_not_null(defeat_label, "Defeat label should exist")
	
	var victory_visible: bool = TypeSafeMixin._safe_method_call_bool(victory_label, "get", ["visible"])
	var defeat_visible: bool = TypeSafeMixin._safe_method_call_bool(defeat_label, "get", ["visible"])
	
	assert_true(victory_visible, "Victory label should be visible for victory")
	assert_false(defeat_visible, "Defeat label should be hidden for victory")

func test_defeat_display() -> void:
	# Set up defeat state in game state
	TypeSafeMixin._safe_method_call_bool(_game_state, "set", ["victory_achieved", false])
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	assert_not_null(victory_label, "Victory label should exist")
	assert_not_null(defeat_label, "Defeat label should exist")
	
	var victory_visible: bool = TypeSafeMixin._safe_method_call_bool(victory_label, "get", ["visible"])
	var defeat_visible: bool = TypeSafeMixin._safe_method_call_bool(defeat_label, "get", ["visible"])
	
	assert_true(defeat_visible, "Defeat label should be visible for defeat")
	assert_false(victory_visible, "Victory label should be hidden for defeat")

# Navigation Tests
func test_navigation_buttons() -> void:
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var restart_button: Button = _get_node_safe(_instance, "ButtonContainer/RestartButton")
	var main_menu_button: Button = _get_node_safe(_instance, "ButtonContainer/MainMenuButton")
	
	assert_not_null(restart_button, "Restart button should exist")
	assert_not_null(main_menu_button, "Main menu button should exist")
	
	# Test restart button
	TypeSafeMixin._safe_method_call_bool(restart_button, "emit_signal", ["pressed"])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "scene_restarted", "Scene restart signal should be emitted")
	
	# Test main menu button
	TypeSafeMixin._safe_method_call_bool(main_menu_button, "emit_signal", ["pressed"])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "main_menu_requested", "Main menu signal should be emitted")

# Stats Display Tests
func test_stats_display() -> void:
	# Set up test campaign data
	var campaign_data := {
		"stats": {
			"enemies_defeated": 20,
			"credits_earned": 1000
		}
	}
	TypeSafeMixin._safe_method_call_bool(_game_state, "set", ["campaign", campaign_data])
	
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var stats_container: Control = _get_node_safe(_instance, "StatsContainer")
	var enemies_defeated_label: Label = _get_node_safe(_instance, "StatsContainer/EnemiesDefeatedLabel")
	var credits_earned_label: Label = _get_node_safe(_instance, "StatsContainer/CreditsEarnedLabel")
	
	assert_not_null(stats_container, "Stats container should exist")
	assert_true(TypeSafeMixin._safe_method_call_bool(stats_container, "get", ["visible"]), "Stats container should be visible")
	
	assert_not_null(enemies_defeated_label, "Enemies defeated label should exist")
	assert_not_null(credits_earned_label, "Credits earned label should exist")
	
	var enemies_text: String = TypeSafeMixin._safe_method_call_string(enemies_defeated_label, "get", ["text"])
	var credits_text: String = TypeSafeMixin._safe_method_call_string(credits_earned_label, "get", ["text"])
	
	assert_eq(enemies_text, "Enemies Defeated: 20", "Should display correct enemies defeated")
	assert_eq(credits_text, "Credits Earned: 1000", "Should display correct credits earned")

# Performance Tests
func test_screen_transitions() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		TypeSafeMixin._safe_method_call_bool(_instance, "show")
		TypeSafeMixin._safe_method_call_bool(_instance, "hide")
		await get_tree().process_frame
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_lt(duration, 1000, "Screen transitions should be performant")

# Error Cases Tests
func test_null_campaign_data() -> void:
	TypeSafeMixin._safe_method_call_bool(_game_state, "set", ["campaign", null])
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_points_label: Label = _get_node_safe(_instance, "StatsContainer/VictoryPointsLabel")
	
	assert_true(TypeSafeMixin._safe_method_call_bool(_instance, "get", ["visible"]), "Screen should still show with null campaign data")
	assert_not_null(victory_points_label, "Victory points label should exist")
	assert_eq(TypeSafeMixin._safe_method_call_string(victory_points_label, "get", ["text"]), "Victory Points: 0", "Should show default values for null campaign")

# Cleanup Tests
func test_cleanup() -> void:
	TypeSafeMixin._safe_method_call_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	TypeSafeMixin._safe_method_call_bool(_instance, "cleanup")
	await get_tree().process_frame
	
	assert_false(TypeSafeMixin._safe_method_call_bool(_instance, "get", ["visible"]), "Screen should be hidden after cleanup")
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	assert_not_null(victory_label, "Victory label should exist")
	assert_not_null(defeat_label, "Defeat label should exist")
	
	var victory_visible: bool = TypeSafeMixin._safe_method_call_bool(victory_label, "get", ["visible"])
	var defeat_visible: bool = TypeSafeMixin._safe_method_call_bool(defeat_label, "get", ["visible"])
	
	assert_false(victory_visible, "Victory label should be hidden after cleanup")
	assert_false(defeat_visible, "Defeat label should be hidden after cleanup")

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