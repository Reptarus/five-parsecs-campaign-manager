extends "res://addons/gut/test.gd"

const DifficultyOption = preload("res://src/ui/components/difficulty/DifficultyOption.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var option: DifficultyOption
var value_changed_signal_emitted := false
var last_difficulty_value: GameEnums.DifficultyLevel

func before_each() -> void:
	option = DifficultyOption.new()
	add_child(option)
	value_changed_signal_emitted = false
	option.value_changed.connect(_on_value_changed)

func after_each() -> void:
	option.queue_free()

func _on_value_changed(difficulty: GameEnums.DifficultyLevel) -> void:
	value_changed_signal_emitted = true
	last_difficulty_value = difficulty

func test_initial_setup() -> void:
	assert_not_null(option)
	assert_not_null(option.option_button)

func test_setup_with_difficulty() -> void:
	var test_difficulty = GameEnums.DifficultyLevel.NORMAL
	var test_tooltip = "Select game difficulty"
	option.setup(test_difficulty, test_tooltip)
	
	assert_eq(option.current_difficulty, test_difficulty)
	assert_eq(option.option_button.tooltip_text, test_tooltip)

func test_difficulty_options() -> void:
	option._setup_options()
	assert_eq(option.option_button.item_count, 5) # EASY, NORMAL, HARD, HARDCORE, ELITE
	
	# Verify option text
	assert_eq(option.option_button.get_item_text(GameEnums.DifficultyLevel.EASY), "Easy")
	assert_eq(option.option_button.get_item_text(GameEnums.DifficultyLevel.NORMAL), "Normal")
	assert_eq(option.option_button.get_item_text(GameEnums.DifficultyLevel.HARD), "Hard")
	assert_eq(option.option_button.get_item_text(GameEnums.DifficultyLevel.HARDCORE), "Hardcore")
	assert_eq(option.option_button.get_item_text(GameEnums.DifficultyLevel.ELITE), "Elite")

func test_get_set_difficulty() -> void:
	var test_difficulty = GameEnums.DifficultyLevel.HARD
	option.set_difficulty(test_difficulty)
	assert_eq(option.get_difficulty(), test_difficulty)

func test_difficulty_change_signal() -> void:
	option._setup_options()
	option._on_option_selected(GameEnums.DifficultyLevel.HARDCORE)
	
	assert_true(value_changed_signal_emitted)
	assert_eq(last_difficulty_value, GameEnums.DifficultyLevel.HARDCORE)