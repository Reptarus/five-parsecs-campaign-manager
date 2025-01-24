@tool
extends "res://tests/fixtures/game_test.gd"

const SaveLoadUI = preload("res://src/ui/screens/SaveLoadUI.gd")

var save_load_ui: SaveLoadUI
var mock_game_state: GameState
var save_selected_signal_emitted := false
var load_selected_signal_emitted := false
var cancelled_signal_emitted := false
var last_save_name: String
var last_save_data: Dictionary

func before_each() -> void:
	mock_game_state = GameState.new()
	add_child(mock_game_state)
	
	save_load_ui = SaveLoadUI.new()
	add_child(save_load_ui)
	await save_load_ui.ready
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	save_load_ui.queue_free()
	mock_game_state.queue_free()

func _reset_signals() -> void:
	save_selected_signal_emitted = false
	load_selected_signal_emitted = false
	cancelled_signal_emitted = false
	last_save_name = ""
	last_save_data = {}

func _connect_signals() -> void:
	save_load_ui.save_selected.connect(_on_save_selected)
	save_load_ui.load_selected.connect(_on_load_selected)
	save_load_ui.cancelled.connect(_on_cancelled)

func _on_save_selected(save_name: String) -> void:
	save_selected_signal_emitted = true
	last_save_name = save_name

func _on_load_selected(save_data: Dictionary) -> void:
	load_selected_signal_emitted = true
	last_save_data = save_data

func _on_cancelled() -> void:
	cancelled_signal_emitted = true

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(save_load_ui, "SaveLoadUI should be initialized")
	assert_false(save_load_ui.is_saving, "Should not be in saving state initially")
	assert_false(save_load_ui.is_loading, "Should not be in loading state initially")

# Save Tests
func test_save_game() -> void:
	watch_signals(save_load_ui)
	
	# Setup mock save data
	mock_game_state.campaign = {
		"name": "Test Campaign",
		"credits": 1000
	}
	
	save_load_ui.save_name_input.text = "test_save"
	save_load_ui._on_save_pressed()
	
	assert_signal_emitted(save_load_ui, "save_completed")
	assert_true(save_load_ui.save_exists("test_save"),
		"Save file should exist after saving")

# Load Tests
func test_load_game() -> void:
	watch_signals(save_load_ui)
	
	# Create a mock save first
	mock_game_state.campaign = {
		"name": "Test Campaign",
		"credits": 1000
	}
	save_load_ui.save_name_input.text = "test_save"
	save_load_ui._on_save_pressed()
	
	# Clear game state
	mock_game_state.campaign = null
	
	# Test loading
	save_load_ui.select_save("test_save")
	save_load_ui._on_load_pressed()
	
	assert_signal_emitted(save_load_ui, "load_completed")
	assert_not_null(mock_game_state.campaign,
		"Campaign should be loaded into game state")
	assert_eq(mock_game_state.campaign.name, "Test Campaign",
		"Should load correct campaign data")

# Save List Tests
func test_save_list_updates() -> void:
	# Create multiple saves
	var save_names = ["save1", "save2", "save3"]
	for save_name in save_names:
		save_load_ui.save_name_input.text = save_name
		save_load_ui._on_save_pressed()
	
	save_load_ui._refresh_save_list()
	
	for save_name in save_names:
		assert_true(save_load_ui.save_list.has_item(save_name),
			"Save list should show all saves")

# Validation Tests
func test_save_name_validation() -> void:
	# Test empty name
	save_load_ui.save_name_input.text = ""
	assert_false(save_load_ui._validate_save_name(),
		"Should reject empty save names")
	
	# Test invalid characters
	save_load_ui.save_name_input.text = "test/save"
	assert_false(save_load_ui._validate_save_name(),
		"Should reject names with invalid characters")
	
	# Test valid name
	save_load_ui.save_name_input.text = "valid_save_name"
	assert_true(save_load_ui._validate_save_name(),
		"Should accept valid save names")

# Delete Tests
func test_delete_save() -> void:
	# Create a save first
	save_load_ui.save_name_input.text = "test_delete"
	save_load_ui._on_save_pressed()
	
	watch_signals(save_load_ui)
	save_load_ui.select_save("test_delete")
	save_load_ui._on_delete_pressed()
	
	assert_signal_emitted(save_load_ui, "save_deleted")
	assert_false(save_load_ui.save_exists("test_delete"),
		"Save should be deleted")

# Error Cases Tests
func test_error_cases() -> void:
	# Test loading non-existent save
	watch_signals(save_load_ui)
	save_load_ui.select_save("non_existent_save")
	save_load_ui._on_load_pressed()
	
	assert_signal_not_emitted(save_load_ui, "load_completed",
		"Should not emit load_completed for non-existent save")
	
	# Test overwriting existing save
	save_load_ui.save_name_input.text = "existing_save"
	save_load_ui._on_save_pressed()
	save_load_ui._on_save_pressed() # Try to save again
	
	assert_signal_emitted(save_load_ui, "save_overwritten",
		"Should emit overwrite signal for existing save")

# Navigation Tests
func test_navigation() -> void:
	watch_signals(get_tree())
	
	save_load_ui._on_back_pressed()
	assert_signal_emitted(get_tree(), "change_scene_to_file")

# Performance Tests
func test_rapid_operations() -> void:
	var start_time := Time.get_ticks_msec()
	
	# Test rapid save list refreshes
	for i in range(10):
		save_load_ui._refresh_save_list()
		await get_tree().process_frame
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000,
		"Should handle rapid save list refreshes efficiently")

# Cleanup Tests
func test_cleanup() -> void:
	# Create some test saves
	save_load_ui.save_name_input.text = "cleanup_test"
	save_load_ui._on_save_pressed()
	
	save_load_ui.cleanup()
	
	assert_eq(save_load_ui.save_name_input.text, "",
		"Should clear save name input")
	assert_false(save_load_ui.is_saving,
		"Should reset saving state")
	assert_false(save_load_ui.is_loading,
		"Should reset loading state")

func test_initial_setup() -> void:
	assert_not_null(save_load_ui)
	assert_not_null(save_load_ui.save_list)
	assert_not_null(save_load_ui.save_name_input)
	assert_not_null(save_load_ui.save_button)
	assert_not_null(save_load_ui.load_button)
	assert_not_null(save_load_ui.cancel_button)

func test_save_mode() -> void:
	save_load_ui.set_mode(GameEnums.EditMode.CREATE)
	
	assert_true(save_load_ui.save_name_input.visible)
	assert_true(save_load_ui.save_button.visible)
	assert_false(save_load_ui.load_button.visible)

func test_load_mode() -> void:
	save_load_ui.set_mode(GameEnums.EditMode.VIEW)
	
	assert_false(save_load_ui.save_name_input.visible)
	assert_false(save_load_ui.save_button.visible)
	assert_true(save_load_ui.load_button.visible)

func test_save_selection() -> void:
	save_load_ui.set_mode(GameEnums.EditMode.CREATE)
	save_load_ui.save_name_input.text = "Test Save"
	
	save_load_ui.save_button.emit_signal("pressed")
	
	assert_true(save_selected_signal_emitted)
	assert_eq(last_save_name, "Test Save")

func test_load_selection() -> void:
	save_load_ui.set_mode(GameEnums.EditMode.VIEW)
	
	var test_save_data = {
		"name": "Test Save",
		"date": "2024-01-01",
		"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
	}
	
	save_load_ui.add_save_data(test_save_data)
	save_load_ui.select_save(0)
	save_load_ui.load_button.emit_signal("pressed")
	
	assert_true(load_selected_signal_emitted)
	assert_eq(last_save_data, test_save_data)

func test_save_list_population() -> void:
	var test_saves = [
		{
			"name": "Save 1",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		},
		{
			"name": "Save 2",
			"date": "2024-01-02",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.CUSTOM
		}
	]
	
	save_load_ui.populate_save_list(test_saves)
	
	assert_eq(save_load_ui.save_list.item_count, 2)
	assert_eq(save_load_ui.get_save_data(0).name, "Save 1")
	assert_eq(save_load_ui.get_save_data(1).name, "Save 2")

func test_save_deletion() -> void:
	var test_save = {
		"name": "Test Save",
		"date": "2024-01-01",
		"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
	}
	
	save_load_ui.add_save_data(test_save)
	assert_eq(save_load_ui.save_list.item_count, 1)
	
	save_load_ui.delete_save(0)
	assert_eq(save_load_ui.save_list.item_count, 0)

func test_cancellation() -> void:
	save_load_ui.cancel_button.emit_signal("pressed")
	
	assert_true(cancelled_signal_emitted)

func test_save_sorting() -> void:
	var test_saves = [
		{
			"name": "Save 2",
			"date": "2024-01-02",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		},
		{
			"name": "Save 1",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		}
	]
	
	save_load_ui.populate_save_list(test_saves)
	save_load_ui.sort_saves_by_date()
	
	assert_eq(save_load_ui.get_save_data(0).date, "2024-01-02")
	assert_eq(save_load_ui.get_save_data(1).date, "2024-01-01")

func test_save_filtering() -> void:
	var test_saves = [
		{
			"name": "Standard Save",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.STANDARD
		},
		{
			"name": "Custom Save",
			"date": "2024-01-01",
			"campaign_type": GameEnums.FiveParcsecsCampaignType.CUSTOM
		}
	]
	
	save_load_ui.populate_save_list(test_saves)
	save_load_ui.filter_saves_by_type(GameEnums.FiveParcsecsCampaignType.STANDARD)
	
	assert_eq(save_load_ui.save_list.item_count, 1)
	assert_eq(save_load_ui.get_save_data(0).name, "Standard Save")