extends "res://addons/gut/test.gd"

const CampaignCreationUI = preload("res://src/ui/screens/campaign/CampaignCreationUI.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var creation_ui: CampaignCreationUI
var campaign_created_signal_emitted := false
var campaign_cancelled_signal_emitted := false
var last_campaign_data: Dictionary

func before_each() -> void:
	creation_ui = CampaignCreationUI.new()
	add_child(creation_ui)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	creation_ui.queue_free()

func _reset_signals() -> void:
	campaign_created_signal_emitted = false
	campaign_cancelled_signal_emitted = false
	last_campaign_data = {}

func _connect_signals() -> void:
	creation_ui.campaign_created.connect(_on_campaign_created)
	creation_ui.campaign_cancelled.connect(_on_campaign_cancelled)

func _on_campaign_created(campaign_data: Dictionary) -> void:
	campaign_created_signal_emitted = true
	last_campaign_data = campaign_data

func _on_campaign_cancelled() -> void:
	campaign_cancelled_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(creation_ui)
	assert_not_null(creation_ui.name_input)
	assert_not_null(creation_ui.difficulty_selector)
	assert_not_null(creation_ui.type_selector)
	assert_not_null(creation_ui.create_button)
	assert_not_null(creation_ui.cancel_button)

func test_campaign_creation() -> void:
	var test_name = "Test Campaign"
	var test_difficulty = GameEnums.DifficultyLevel.NORMAL
	var test_type = GameEnums.FiveParcsecsCampaignType.STANDARD
	
	creation_ui.set_campaign_name(test_name)
	creation_ui.set_difficulty(test_difficulty)
	creation_ui.set_campaign_type(test_type)
	
	creation_ui.create_campaign()
	
	assert_true(campaign_created_signal_emitted)
	assert_eq(last_campaign_data.name, test_name)
	assert_eq(last_campaign_data.difficulty, test_difficulty)
	assert_eq(last_campaign_data.type, test_type)

func test_campaign_cancellation() -> void:
	creation_ui.cancel_creation()
	
	assert_true(campaign_cancelled_signal_emitted)

func test_name_validation() -> void:
	# Test empty name
	creation_ui.set_campaign_name("")
	assert_false(creation_ui.is_valid_campaign_name())
	
	# Test valid name
	creation_ui.set_campaign_name("Valid Campaign")
	assert_true(creation_ui.is_valid_campaign_name())
	
	# Test name with special characters
	creation_ui.set_campaign_name("Campaign#1")
	assert_true(creation_ui.is_valid_campaign_name())

func test_difficulty_selection() -> void:
	var difficulties = [
		GameEnums.DifficultyLevel.EASY,
		GameEnums.DifficultyLevel.NORMAL,
		GameEnums.DifficultyLevel.HARD
	]
	
	for difficulty in difficulties:
		creation_ui.set_difficulty(difficulty)
		assert_eq(creation_ui.get_selected_difficulty(), difficulty)

func test_campaign_type_selection() -> void:
	var types = [
		GameEnums.FiveParcsecsCampaignType.STANDARD,
		GameEnums.FiveParcsecsCampaignType.STORY,
		GameEnums.FiveParcsecsCampaignType.CUSTOM
	]
	
	for type in types:
		creation_ui.set_campaign_type(type)
		assert_eq(creation_ui.get_selected_campaign_type(), type)

func test_create_button_state() -> void:
	# Test with invalid name
	creation_ui.set_campaign_name("")
	assert_true(creation_ui.create_button.disabled)
	
	# Test with valid name
	creation_ui.set_campaign_name("Valid Campaign")
	assert_false(creation_ui.create_button.disabled)

func test_default_values() -> void:
	assert_eq(creation_ui.get_campaign_name(), "")
	assert_eq(creation_ui.get_selected_difficulty(), GameEnums.DifficultyLevel.NORMAL)
	assert_eq(creation_ui.get_selected_campaign_type(), GameEnums.FiveParcsecsCampaignType.STANDARD)

func test_campaign_data_validation() -> void:
	# Test with invalid data
	var invalid_data = creation_ui.get_campaign_data()
	assert_false(creation_ui.is_valid_campaign_data(invalid_data))
	
	# Test with valid data
	creation_ui.set_campaign_name("Valid Campaign")
	creation_ui.set_difficulty(GameEnums.DifficultyLevel.NORMAL)
	creation_ui.set_campaign_type(GameEnums.FiveParcsecsCampaignType.STANDARD)
	
	var valid_data = creation_ui.get_campaign_data()
	assert_true(creation_ui.is_valid_campaign_data(valid_data))

func test_ui_reset() -> void:
	# Set some values
	creation_ui.set_campaign_name("Test Campaign")
	creation_ui.set_difficulty(GameEnums.DifficultyLevel.HARD)
	creation_ui.set_campaign_type(GameEnums.FiveParcsecsCampaignType.STORY)
	
	# Reset UI
	creation_ui.reset()
	
	# Verify default values
	assert_eq(creation_ui.get_campaign_name(), "")
	assert_eq(creation_ui.get_selected_difficulty(), GameEnums.DifficultyLevel.NORMAL)
	assert_eq(creation_ui.get_selected_campaign_type(), GameEnums.FiveParcsecsCampaignType.STANDARD)