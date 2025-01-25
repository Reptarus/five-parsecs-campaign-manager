@tool
extends "res://tests/fixtures/game_test.gd"

const GameOverScreen = preload("res://src/ui/screens/GameOverScreen.gd")

var game_over_screen: GameOverScreen = null
var mock_game_state: GameState = null

func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize mock game state
	mock_game_state = GameState.new()
	add_child_autofree(mock_game_state)
	track_test_node(mock_game_state)
	
	# Initialize game over screen
	game_over_screen = GameOverScreen.new()
	add_child_autofree(game_over_screen)
	track_test_node(game_over_screen)
	await game_over_screen.ready
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(game_over_screen):
		remove_child(game_over_screen)
		game_over_screen.queue_free()
	
	if is_instance_valid(mock_game_state):
		remove_child(mock_game_state)
		mock_game_state.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	game_over_screen = null
	mock_game_state = null
	
	# Let parent handle remaining cleanup
	await super.after_each()
	
	# Clear any tracked resources
	_tracked_resources.clear()

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(game_over_screen, "GameOverScreen should be initialized")
	assert_false(game_over_screen.visible, "Screen should be hidden initially")

# Display Tests
func test_show_game_over() -> void:
	# Setup mock campaign data
	mock_game_state.campaign = {
		"name": "Test Campaign",
		"victory_points": 100,
		"total_battles": 10,
		"crew_members": [
			{"character_name": "Test Character", "kills": 5}
		]
	}
	
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	
	assert_true(game_over_screen.visible,
		"Screen should be visible after game over")
	assert_eq(game_over_screen.victory_points_label.text, "Victory Points: 100",
		"Should display correct victory points")
	assert_eq(game_over_screen.battles_label.text, "Total Battles: 10",
		"Should display correct battle count")

# Victory Condition Tests
func test_victory_display() -> void:
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	assert_true(game_over_screen.victory_label.visible,
		"Victory label should be visible for victory")
	assert_false(game_over_screen.defeat_label.visible,
		"Defeat label should be hidden for victory")

func test_defeat_display() -> void:
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	assert_true(game_over_screen.defeat_label.visible,
		"Defeat label should be visible for defeat")
	assert_false(game_over_screen.victory_label.visible,
		"Victory label should be hidden for defeat")

# Navigation Tests
func test_navigation_buttons() -> void:
	watch_signals(get_tree())
	
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	
	# Test restart button
	game_over_screen._on_restart_pressed()
	assert_signal_emitted(get_tree(), "scene_restarted")
	
	# Test main menu button
	game_over_screen._on_main_menu_pressed()
	assert_signal_emitted(get_tree(), "main_menu_requested")

# Stats Display Tests
func test_stats_display() -> void:
	mock_game_state.campaign = {
		"stats": {
			"enemies_defeated": 20,
			"credits_earned": 1000,
			"missions_completed": 5
		}
	}
	
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	
	assert_true(game_over_screen.stats_container.visible,
		"Stats container should be visible")
	assert_eq(game_over_screen.enemies_defeated_label.text, "Enemies Defeated: 20",
		"Should display correct enemies defeated")
	assert_eq(game_over_screen.credits_earned_label.text, "Credits Earned: 1000",
		"Should display correct credits earned")

# Performance Tests
func test_rapid_visibility_changes() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		game_over_screen.show()
		game_over_screen.hide()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000,
		"Should handle rapid visibility changes efficiently")

# Error Cases Tests
func test_null_campaign_data() -> void:
	mock_game_state.campaign = null
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	
	assert_true(game_over_screen.visible,
		"Screen should still show with null campaign data")
	assert_eq(game_over_screen.victory_points_label.text, "Victory Points: 0",
		"Should show default values for null campaign")

# Cleanup Tests
func test_cleanup() -> void:
	game_over_screen.show_game_over(GameEnums.GameState.GAME_OVER)
	game_over_screen.cleanup()
	
	assert_false(game_over_screen.visible,
		"Screen should be hidden after cleanup")
	assert_false(game_over_screen.victory_label.visible,
		"Victory label should be hidden after cleanup")
	assert_false(game_over_screen.defeat_label.visible,
		"Defeat label should be hidden after cleanup")