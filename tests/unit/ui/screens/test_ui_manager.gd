@tool
extends "res://tests/fixtures/game_test.gd"

const UIManager = preload("res://src/ui/screens/UIManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var ui_manager: UIManager
var mock_game_state: FiveParsecsGameState
var screen_changed_signal_emitted := false
var dialog_opened_signal_emitted := false
var dialog_closed_signal_emitted := false
var last_screen_name: String
var last_dialog_name: String
var last_dialog_data: Dictionary

func before_each() -> void:
	mock_game_state = FiveParsecsGameState.new()
	add_child(mock_game_state)
	
	ui_manager = UIManager.new(mock_game_state)
	add_child(ui_manager)
	await ui_manager.ready
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	ui_manager.queue_free()
	mock_game_state.queue_free()

func _reset_signals() -> void:
	screen_changed_signal_emitted = false
	dialog_opened_signal_emitted = false
	dialog_closed_signal_emitted = false
	last_screen_name = ""
	last_dialog_name = ""
	last_dialog_data = {}

func _connect_signals() -> void:
	ui_manager.screen_changed.connect(_on_screen_changed)
	ui_manager.dialog_opened.connect(_on_dialog_opened)
	ui_manager.dialog_closed.connect(_on_dialog_closed)

func _on_screen_changed(screen_name: String) -> void:
	screen_changed_signal_emitted = true
	last_screen_name = screen_name

func _on_dialog_opened(dialog_name: String, dialog_data: Dictionary) -> void:
	dialog_opened_signal_emitted = true
	last_dialog_name = dialog_name
	last_dialog_data = dialog_data

func _on_dialog_closed(dialog_name: String) -> void:
	dialog_closed_signal_emitted = true
	last_dialog_name = dialog_name

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(ui_manager, "UIManager should be initialized")
	assert_eq(ui_manager.current_screen, "",
		"Should start with no screen")

# Screen Management Tests
func test_show_screen() -> void:
	watch_signals(ui_manager)
	
	ui_manager.show_screen("main_menu")
	
	assert_eq(ui_manager.current_screen, "main_menu",
		"Should update current screen")
	assert_signal_emitted(ui_manager, "screen_changed")

func test_hide_screen() -> void:
	ui_manager.show_screen("main_menu")
	watch_signals(ui_manager)
	
	ui_manager.hide_screen("main_menu")
	
	assert_eq(ui_manager.current_screen, "",
		"Should clear current screen")
	assert_signal_emitted(ui_manager, "screen_changed")

# Screen Stack Tests
func test_screen_stack() -> void:
	ui_manager.push_screen("main_menu")
	ui_manager.push_screen("options")
	
	assert_eq(ui_manager.current_screen, "options",
		"Top screen should be current")
	
	ui_manager.pop_screen()
	assert_eq(ui_manager.current_screen, "main_menu",
		"Should return to previous screen")

# Navigation Tests
func test_navigation() -> void:
	watch_signals(ui_manager)
	
	ui_manager.navigate_to("main_menu")
	assert_signal_emitted(ui_manager, "navigation_requested")
	assert_eq(ui_manager.current_screen, "main_menu",
		"Should navigate to requested screen")

# Modal Tests
func test_modal_screens() -> void:
	ui_manager.show_screen("main_menu")
	ui_manager.show_modal("options")
	
	assert_eq(ui_manager.current_screen, "options",
		"Modal should be current screen")
	assert_true(ui_manager.has_modal,
		"Should indicate modal is showing")
	
	ui_manager.hide_modal()
	assert_eq(ui_manager.current_screen, "main_menu",
		"Should return to previous screen after modal")

# Screen Transition Tests
func test_screen_transitions() -> void:
	watch_signals(ui_manager)
	
	ui_manager.transition_to("main_menu")
	assert_signal_emitted(ui_manager, "transition_started")
	
	# Wait for transition
	await get_tree().create_timer(0.1).timeout
	
	assert_eq(ui_manager.current_screen, "main_menu",
		"Should complete transition to new screen")
	assert_signal_emitted(ui_manager, "transition_completed")

# Performance Tests
func test_rapid_screen_changes() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(10):
		ui_manager.show_screen("main_menu")
		ui_manager.show_screen("options")
		await get_tree().process_frame
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000,
		"Should handle rapid screen changes efficiently")

# Error Cases Tests
func test_invalid_screen_operations() -> void:
	# Try to show invalid screen
	ui_manager.show_screen("invalid_screen")
	assert_eq(ui_manager.current_screen, "",
		"Should not change screen for invalid ID")
	
	# Try to pop empty stack
	ui_manager.pop_screen()
	assert_eq(ui_manager.current_screen, "",
		"Should handle empty stack gracefully")

# State Management Tests
func test_screen_state_persistence() -> void:
	var test_data = {"test": "data"}
	
	ui_manager.set_screen_state("main_menu", test_data)
	ui_manager.show_screen("main_menu")
	
	var restored_data = ui_manager.get_screen_state("main_menu")
	assert_eq(restored_data, test_data,
		"Should persist and restore screen state")

# Cleanup Tests
func test_cleanup() -> void:
	ui_manager.show_screen("main_menu")
	ui_manager.show_modal("options")
	
	ui_manager.cleanup()
	
	assert_eq(ui_manager.current_screen, "",
		"Should clear current screen")
	assert_false(ui_manager.has_modal,
		"Should clear modals")
	assert_eq(ui_manager.screen_stack.size(), 0,
		"Should clear screen stack")

func test_screen_navigation() -> void:
	# Test main menu navigation
	ui_manager.show_screen("main_menu")
	assert_true(screen_changed_signal_emitted)
	assert_eq(last_screen_name, "main_menu")
	assert_eq(ui_manager.current_screen, "main_menu")
	
	# Test campaign screen navigation
	_reset_signals()
	ui_manager.show_screen("campaign")
	assert_true(screen_changed_signal_emitted)
	assert_eq(last_screen_name, "campaign")
	assert_eq(ui_manager.current_screen, "campaign")

func test_dialog_management() -> void:
	var test_dialog_data = {
		"title": "Test Dialog",
		"message": "This is a test message",
		"type": "info"
	}
	
	# Test opening dialog
	ui_manager.show_dialog("test_dialog", test_dialog_data)
	assert_true(dialog_opened_signal_emitted)
	assert_eq(last_dialog_name, "test_dialog")
	assert_eq(last_dialog_data, test_dialog_data)
	assert_true(ui_manager.is_dialog_open("test_dialog"))
	
	# Test closing dialog
	_reset_signals()
	ui_manager.close_dialog("test_dialog")
	assert_true(dialog_closed_signal_emitted)
	assert_eq(last_dialog_name, "test_dialog")
	assert_false(ui_manager.is_dialog_open("test_dialog"))

func test_screen_data() -> void:
	var test_screen_data = {
		"campaign_id": "test_campaign",
		"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP
	}
	
	ui_manager.show_screen("campaign", test_screen_data)
	
	assert_true(screen_changed_signal_emitted)
	assert_eq(ui_manager.get_screen_data("campaign"), test_screen_data)

func test_dialog_data_update() -> void:
	var initial_data = {
		"title": "Initial Title",
		"message": "Initial Message"
	}
	
	var updated_data = {
		"title": "Updated Title",
		"message": "Updated Message"
	}
	
	ui_manager.show_dialog("test_dialog", initial_data)
	ui_manager.update_dialog_data("test_dialog", updated_data)
	
	assert_eq(ui_manager.get_dialog_data("test_dialog"), updated_data)

func test_screen_transition_animations() -> void:
	# Test transition to new screen
	ui_manager.show_screen("main_menu")
	assert_true(ui_manager.is_screen_active("main_menu"))
	
	# Test transition animation completion
	await ui_manager.transition_completed
	assert_true(ui_manager.is_screen_visible("main_menu"))
	
	# Test transition to another screen
	ui_manager.show_screen("campaign")
	assert_true(ui_manager.is_screen_transitioning())
	
	await ui_manager.transition_completed
	assert_true(ui_manager.is_screen_visible("campaign"))
	assert_false(ui_manager.is_screen_visible("main_menu"))

func test_error_handling() -> void:
	# Test invalid screen name
	var result = ui_manager.show_screen("invalid_screen")
	assert_false(result)
	assert_eq(ui_manager.get_error(), "Invalid screen name: invalid_screen")
	
	# Test invalid dialog name
	result = ui_manager.show_dialog("invalid_dialog", {})
	assert_false(result)
	assert_eq(ui_manager.get_error(), "Invalid dialog name: invalid_dialog")
	
	# Test closing non-existent dialog
	result = ui_manager.close_dialog("non_existent")
	assert_false(result)
	assert_eq(ui_manager.get_error(), "Dialog not found: non_existent")