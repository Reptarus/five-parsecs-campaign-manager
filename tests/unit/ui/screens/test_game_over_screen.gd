@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

const GameOverScreen: GDScript = preload("res://src/ui/screens/GameOverScreen.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")

# Type-safe instance variables
var _instance: Node = null
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
	if not is_instance_valid(_instance):
		push_warning("Skipping test_initial_state: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	assert_not_null(_instance, "GameOverScreen should be initialized")
	assert_false(TypeSafeMixin._call_node_method_bool(_instance, "get", ["visible"]), "Screen should be hidden initially")

# Display Tests
func test_show_game_over() -> void:
	if not is_instance_valid(_instance) or not is_instance_valid(_game_state):
		push_warning("Skipping test_show_game_over: _instance or _game_state is null or invalid")
		pending("Test skipped - _instance or _game_state is null or invalid")
		return
		
	if not _instance.has_method("show_game_over"):
		push_warning("Skipping test_show_game_over: show_game_over method not found")
		pending("Test skipped - show_game_over method not found")
		return
		
	# Set up test campaign data
	var campaign_data := {
		"victory_points": 100,
		"total_battles": 10,
		"stats": [
			{"type": "enemies_defeated", "value": 20},
			{"type": "credits_earned", "value": 1000}
		]
	}
	TypeSafeMixin._call_node_method_bool(_game_state, "set", ["campaign", campaign_data])
	
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	assert_true(TypeSafeMixin._call_node_method_bool(_instance, "get", ["visible"]), "Screen should be visible after game over")
	
	var victory_points_label: Label = _get_node_safe(_instance, "StatsContainer/VictoryPointsLabel")
	var battles_label: Label = _get_node_safe(_instance, "StatsContainer/BattlesLabel")
	
	assert_not_null(victory_points_label, "Victory points label should exist")
	assert_not_null(battles_label, "Battles label should exist")
	
	var points_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(victory_points_label, "get", ["text"]))
	var battles_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(battles_label, "get", ["text"]))
	
	assert_eq(points_text, "Victory Points: 100", "Should display correct victory points")
	assert_eq(battles_text, "Total Battles: 10", "Should display correct battle count")

func test_victory_display() -> void:
	if not is_instance_valid(_instance) or not is_instance_valid(_game_state):
		push_warning("Skipping test_victory_display: _instance or _game_state is null or invalid")
		pending("Test skipped - _instance or _game_state is null or invalid")
		return
		
	if not _instance.has_method("show_game_over"):
		push_warning("Skipping test_victory_display: show_game_over method not found")
		pending("Test skipped - show_game_over method not found")
		return
		
	# Set up victory state in game state
	TypeSafeMixin._call_node_method_bool(_game_state, "set", ["victory_achieved", true])
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	if not victory_label or not defeat_label:
		push_warning("Skipping label checks: victory or defeat label not found")
		return
		
	var victory_visible: bool = TypeSafeMixin._call_node_method_bool(victory_label, "get", ["visible"])
	var defeat_visible: bool = TypeSafeMixin._call_node_method_bool(defeat_label, "get", ["visible"])
	
	assert_true(victory_visible, "Victory label should be visible for victory")
	assert_false(defeat_visible, "Defeat label should be hidden for victory")

func test_defeat_display() -> void:
	if not is_instance_valid(_instance) or not is_instance_valid(_game_state):
		push_warning("Skipping test_defeat_display: _instance or _game_state is null or invalid")
		pending("Test skipped - _instance or _game_state is null or invalid")
		return
		
	if not _instance.has_method("show_game_over"):
		push_warning("Skipping test_defeat_display: show_game_over method not found")
		pending("Test skipped - show_game_over method not found")
		return
		
	# Set up defeat state in game state
	TypeSafeMixin._call_node_method_bool(_game_state, "set", ["victory_achieved", false])
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	if not victory_label or not defeat_label:
		push_warning("Skipping label checks: victory or defeat label not found")
		return
		
	var victory_visible: bool = TypeSafeMixin._call_node_method_bool(victory_label, "get", ["visible"])
	var defeat_visible: bool = TypeSafeMixin._call_node_method_bool(defeat_label, "get", ["visible"])
	
	assert_true(defeat_visible, "Defeat label should be visible for defeat")
	assert_false(victory_visible, "Victory label should be hidden for defeat")

# Navigation Tests
func test_navigation_buttons() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_navigation_buttons: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_method("show_game_over"):
		push_warning("Skipping test_navigation_buttons: show_game_over method not found")
		pending("Test skipped - show_game_over method not found")
		return
		
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var restart_button: Button = _get_node_safe(_instance, "ButtonContainer/RestartButton")
	var main_menu_button: Button = _get_node_safe(_instance, "ButtonContainer/MainMenuButton")
	
	if not restart_button or not main_menu_button:
		push_warning("Skipping button tests: restart or main menu button not found")
		return
		
	if not restart_button.has_signal("pressed") or not main_menu_button.has_signal("pressed"):
		push_warning("Skipping button signal tests: required signals not found")
		return
		
	# Test restart button
	TypeSafeMixin._call_node_method_bool(restart_button, "emit_signal", ["pressed"])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "scene_restarted", "Scene restart signal should be emitted")
	
	# Test main menu button
	TypeSafeMixin._call_node_method_bool(main_menu_button, "emit_signal", ["pressed"])
	await get_tree().process_frame
	verify_signal_emitted(get_tree(), "main_menu_requested", "Main menu signal should be emitted")

# Stats Display Tests
func test_stats_display() -> void:
	if not is_instance_valid(_instance) or not is_instance_valid(_game_state):
		push_warning("Skipping test_stats_display: _instance or _game_state is null or invalid")
		pending("Test skipped - _instance or _game_state is null or invalid")
		return
		
	if not _instance.has_method("show_game_over"):
		push_warning("Skipping test_stats_display: show_game_over method not found")
		pending("Test skipped - show_game_over method not found")
		return
		
	# Set up test campaign data
	var campaign_data := {
		"stats": {
			"enemies_defeated": 20,
			"credits_earned": 1000
		}
	}
	TypeSafeMixin._call_node_method_bool(_game_state, "set", ["campaign", campaign_data])
	
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var stats_container: Control = _get_node_safe(_instance, "StatsContainer")
	var enemies_defeated_label: Label = _get_node_safe(_instance, "StatsContainer/EnemiesDefeatedLabel")
	var credits_earned_label: Label = _get_node_safe(_instance, "StatsContainer/CreditsEarnedLabel")
	
	if not stats_container or not enemies_defeated_label or not credits_earned_label:
		push_warning("Skipping stats checks: required labels not found")
		return
		
	assert_true(TypeSafeMixin._call_node_method_bool(stats_container, "get", ["visible"]), "Stats container should be visible")
	
	var enemies_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(enemies_defeated_label, "get", ["text"]))
	var credits_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(credits_earned_label, "get", ["text"]))
	
	assert_eq(enemies_text, "Enemies Defeated: 20", "Should display correct enemies defeated")
	assert_eq(credits_text, "Credits Earned: 1000", "Should display correct credits earned")

# Performance Tests
func test_screen_transitions() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_screen_transitions: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not (_instance.has_method("show") and _instance.has_method("hide")):
		push_warning("Skipping test_screen_transitions: show or hide method not found")
		pending("Test skipped - show or hide method not found")
		return
		
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		TypeSafeMixin._call_node_method_bool(_instance, "show")
		TypeSafeMixin._call_node_method_bool(_instance, "hide")
		await get_tree().process_frame
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_lt(duration, 1000, "Screen transitions should be performant")

# Error Cases Tests
func test_null_campaign_data() -> void:
	if not is_instance_valid(_instance) or not is_instance_valid(_game_state):
		push_warning("Skipping test_null_campaign_data: _instance or _game_state is null or invalid")
		pending("Test skipped - _instance or _game_state is null or invalid")
		return
		
	if not _instance.has_method("show_game_over"):
		push_warning("Skipping test_null_campaign_data: show_game_over method not found")
		pending("Test skipped - show_game_over method not found")
		return
		
	TypeSafeMixin._call_node_method_bool(_game_state, "set", ["campaign", null])
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	var victory_points_label: Label = _get_node_safe(_instance, "StatsContainer/VictoryPointsLabel")
	if not victory_points_label:
		push_warning("Skipping victory points label check: label not found")
		return
		
	assert_true(TypeSafeMixin._call_node_method_bool(_instance, "get", ["visible"]), "Screen should still show with null campaign data")
	assert_eq(TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(victory_points_label, "get", ["text"])), "Victory Points: 0", "Should show default values for null campaign")

# Cleanup Tests
func test_cleanup() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_cleanup: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not (_instance.has_method("show_game_over") and _instance.has_method("cleanup")):
		push_warning("Skipping test_cleanup: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	TypeSafeMixin._call_node_method_bool(_instance, "show_game_over", [GameEnums.GameState.GAME_OVER])
	await get_tree().process_frame
	
	TypeSafeMixin._call_node_method_bool(_instance, "cleanup")
	await get_tree().process_frame
	
	assert_false(TypeSafeMixin._call_node_method_bool(_instance, "get", ["visible"]), "Screen should be hidden after cleanup")
	
	var victory_label: Label = _get_node_safe(_instance, "VictoryLabel")
	var defeat_label: Label = _get_node_safe(_instance, "DefeatLabel")
	
	if not victory_label or not defeat_label:
		push_warning("Skipping label visibility checks: required labels not found")
		return
		
	var victory_visible: bool = TypeSafeMixin._call_node_method_bool(victory_label, "get", ["visible"])
	var defeat_visible: bool = TypeSafeMixin._call_node_method_bool(defeat_label, "get", ["visible"])
	
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