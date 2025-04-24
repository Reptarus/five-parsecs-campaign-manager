@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

## Test suite for the DifficultyOption component
## Tests initialization, signal handling, accessibility, and interactions

const DifficultyOption = preload("res://src/ui/components/difficulty/DifficultyOption.gd")

# Type-safe instance variables
var _last_difficulty_value: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL

## Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return DifficultyOption.new()

## Setup before each test
func before_each() -> void:
	await super.before_each()
	_reset_state()
	_connect_signals()

## Cleanup after each test
func after_each() -> void:
	_reset_state()
	await super.after_each()

## Reset test state to defaults
func _reset_state() -> void:
	_last_difficulty_value = GameEnums.DifficultyLevel.NORMAL

## Connect to component signals
func _connect_signals() -> void:
	if _component and _component.has_signal("value_changed"):
		if _component.value_changed.is_connected(_on_value_changed):
			_component.value_changed.disconnect(_on_value_changed)
		_component.value_changed.connect(_on_value_changed)

## Signal handler for difficulty value changes
func _on_value_changed(difficulty: GameEnums.DifficultyLevel) -> void:
	_last_difficulty_value = difficulty

## Test initial component setup
func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(_component.option_button, "Option button should be correctly referenced")
	assert_eq(_component.current_difficulty, GameEnums.DifficultyLevel.NORMAL,
		"Default difficulty should be NORMAL")

## Test setting up with specific difficulty and tooltip
func test_setup_with_difficulty() -> void:
	var test_difficulty := GameEnums.DifficultyLevel.HARD
	var test_tooltip := "Select game difficulty"
	
	_component._setup_options() # Ensure options are set up first
	_component.setup(test_difficulty, test_tooltip)
	
	assert_eq(_component.current_difficulty, test_difficulty,
		"Current difficulty should match the set difficulty")
	assert_eq(_component.option_button.tooltip_text, test_tooltip,
		"Tooltip text should be set correctly")
	assert_eq(_component.option_button.selected, test_difficulty,
		"Option button selected index should match difficulty level")

## Test available difficulty options
func test_difficulty_options() -> void:
	_component._setup_options()
	assert_eq(_component.option_button.item_count, 5,
		"Should have 5 difficulty options") # EASY, NORMAL, HARD, HARDCORE, ELITE
	
	# Verify option text
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.EASY), "Easy",
		"EASY option text should be 'Easy'")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.NORMAL), "Normal",
		"NORMAL option text should be 'Normal'")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.HARD), "Hard",
		"HARD option text should be 'Hard'")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.HARDCORE), "Hardcore",
		"HARDCORE option text should be 'Hardcore'")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.ELITE), "Elite",
		"ELITE option text should be 'Elite'")

## Test getter and setter for difficulty
func test_get_set_difficulty() -> void:
	_component._setup_options() # Ensure options are set up first
	
	var test_difficulty := GameEnums.DifficultyLevel.HARD
	_component.set_difficulty(test_difficulty)
	
	assert_eq(_component.get_difficulty(), test_difficulty,
		"get_difficulty() should return the set difficulty")
	assert_eq(_component.option_button.selected, test_difficulty,
		"Option button selected index should match the set difficulty")

## Test invalid difficulty handling
func test_invalid_difficulty() -> void:
	# Test with invalid difficulty values
	var invalid_difficulty := -1
	_component.set_difficulty(invalid_difficulty)
	
	# Should not change from default
	assert_eq(_component.get_difficulty(), GameEnums.DifficultyLevel.NORMAL,
		"Invalid difficulty should not change current setting")

## Test difficulty change signal
func test_difficulty_change_signal() -> void:
	_component._setup_options()
	
	watch_signals(_component)
	_component._on_option_selected(GameEnums.DifficultyLevel.HARDCORE)
	
	assert_signal_emitted(_component, "value_changed",
		"value_changed signal should be emitted")
	assert_eq(_last_difficulty_value, GameEnums.DifficultyLevel.HARDCORE,
		"Signal should pass correct difficulty level")

## Test component theme
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for difficulty option
	assert_component_theme_color("font_color")
	assert_component_theme_color("font_hover_color")
	assert_component_theme_font("normal_font")

## Test component layout
func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for difficulty option
	assert_true(_component.option_button.size.x >= 100,
		"Option button should have minimum width")
	assert_true(_component.option_button.size.y >= 30,
		"Option button should have minimum height")

## Test component performance
func test_component_performance() -> void:
	start_performance_monitoring()
	
	_component._setup_options() # Ensure options are set up first
	
	# Perform difficulty option specific operations
	for difficulty in range(GameEnums.DifficultyLevel.EASY, GameEnums.DifficultyLevel.ELITE + 1):
		_component.set_difficulty(difficulty)
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 15
	})

## Test difficulty interaction via the UI
func test_difficulty_interaction() -> void:
	_component._setup_options()
	watch_signals(_component)
	
	# Test each difficulty level
	for difficulty in range(GameEnums.DifficultyLevel.EASY, GameEnums.DifficultyLevel.ELITE + 1):
		_component.option_button.selected = difficulty
		_component.option_button.item_selected.emit(difficulty)
		
		assert_signal_emitted(_component, "value_changed",
			"value_changed signal should be emitted")
		assert_eq(_last_difficulty_value, difficulty,
			"Last difficulty value should match selected difficulty")

## Test proper initialization check
func test_initialization_check() -> void:
	assert_true(_component.is_properly_initialized(),
		"Component should report proper initialization")
	
	# Test with null option button
	var temp_button = _component.option_button
	_component.option_button = null
	
	assert_false(_component.is_properly_initialized(),
		"Component should report improper initialization when option_button is null")
	
	# Restore for cleanup
	_component.option_button = temp_button

## Test accessibility features
func test_accessibility(control: Control = _component) -> void:
	await super.test_accessibility(control)
	
	# Additional accessibility checks for difficulty option
	assert_true(_component.option_button.focus_mode != Control.FOCUS_NONE,
		"Option button should be focusable")
	
	# Test keyboard navigation
	_component._setup_options()
	_component.option_button.grab_focus()
	
	for i in range(_component.option_button.item_count):
		assert_true(_component.option_button.has_focus(),
			"Option button should maintain focus during navigation")
		simulate_component_key_press(KEY_DOWN)
		await get_tree().process_frame
