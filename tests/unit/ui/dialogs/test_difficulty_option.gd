@tool
extends ComponentTestBase

const DifficultyOption := preload("res://src/ui/components/difficulty/DifficultyOption.gd")

# Type-safe instance variables
var _last_difficulty_value: GameEnums.DifficultyLevel

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return DifficultyOption.new()

func before_each() -> void:
	await super.before_each()
	_reset_state()
	_connect_signals()

func after_each() -> void:
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_difficulty_value = GameEnums.DifficultyLevel.NORMAL

func _connect_signals() -> void:
	_component.value_changed.connect(_on_value_changed)

func _on_value_changed(difficulty: GameEnums.DifficultyLevel) -> void:
	_last_difficulty_value = difficulty

func test_initial_setup() -> void:
	await test_component_structure()
	
	# Additional component-specific checks
	assert_not_null(_component.option_button)

func test_setup_with_difficulty() -> void:
	var test_difficulty := GameEnums.DifficultyLevel.NORMAL
	var test_tooltip := "Select game difficulty"
	_component.setup(test_difficulty, test_tooltip)
	
	assert_eq(_component.current_difficulty, test_difficulty)
	assert_eq(_component.option_button.tooltip_text, test_tooltip)

func test_difficulty_options() -> void:
	_component._setup_options()
	assert_eq(_component.option_button.item_count, 5) # EASY, NORMAL, HARD, HARDCORE, ELITE
	
	# Verify option text
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.EASY), "Easy")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.NORMAL), "Normal")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.HARD), "Hard")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.HARDCORE), "Hardcore")
	assert_eq(_component.option_button.get_item_text(GameEnums.DifficultyLevel.ELITE), "Elite")

func test_get_set_difficulty() -> void:
	var test_difficulty := GameEnums.DifficultyLevel.HARD
	_component.set_difficulty(test_difficulty)
	assert_eq(_component.get_difficulty(), test_difficulty)

func test_difficulty_change_signal() -> void:
	_component._setup_options()
	_component._on_option_selected(GameEnums.DifficultyLevel.HARDCORE)
	
	assert_signal_emitted(_component, "value_changed")
	assert_eq(_last_difficulty_value, GameEnums.DifficultyLevel.HARDCORE)

# Additional tests using base class functionality
func test_component_theme() -> void:
	await super.test_component_theme()
	
	# Additional theme checks for difficulty option
	assert_component_theme_color("font_color")
	assert_component_theme_color("font_hover_color")
	assert_component_theme_font("normal_font")

func test_component_layout() -> void:
	await super.test_component_layout()
	
	# Additional layout checks for difficulty option
	assert_true(_component.option_button.size.x >= 100,
		"Option button should have minimum width")
	assert_true(_component.option_button.size.y >= 30,
		"Option button should have minimum height")

func test_component_performance() -> void:
	start_performance_monitoring()
	
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

func test_difficulty_interaction() -> void:
	_component._setup_options()
	
	# Test each difficulty level
	for difficulty in range(GameEnums.DifficultyLevel.EASY, GameEnums.DifficultyLevel.ELITE + 1):
		_component.option_button.selected = difficulty
		_component.option_button.item_selected.emit(difficulty)
		
		assert_signal_emitted(_component, "value_changed")
		assert_eq(_last_difficulty_value, difficulty)

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