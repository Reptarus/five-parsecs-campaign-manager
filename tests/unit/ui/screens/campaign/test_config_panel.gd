extends "res://tests/fixtures/base_test.gd"

const ConfigPanel = preload("res://src/ui/screens/campaign/panels/ConfigPanel.tscn")

var panel = null

func before_each():
	await super.before_each()
	panel = ConfigPanel.instantiate()
	add_child_autofree(panel)
	await panel.ready

func after_each():
	await super.after_each()
	panel = null

func test_initial_setup():
	assert_not_null(panel, "Config panel should be created")
	# Verify required nodes are present
	assert_not_null(panel.get_node("NameInput"), "Should have NameInput node")
	assert_not_null(panel.get_node("SeedInput"), "Should have SeedInput node")
	assert_not_null(panel.get_node("DifficultySelector"), "Should have DifficultySelector node")

func test_signal_connections():
	watch_signals(panel)
	panel.emit_signal("config_updated")
	assert_signal_emitted(panel, "config_updated")

func test_state_management():
	var test_config = {
		"name": "Test Campaign",
		"seed": "12345",
		"difficulty": 1
	}
	panel.set_config(test_config)
	var current_config = panel.get_config()
	assert_eq(current_config.name, test_config.name)
	assert_eq(current_config.seed, test_config.seed)
	assert_eq(current_config.difficulty, test_config.difficulty)

func test_input_validation():
	# Test name validation
	panel.get_node("NameInput").text = ""
	assert_false(panel.is_valid(), "Empty name should be invalid")
	
	# Test seed validation
	panel.get_node("SeedInput").text = "invalid_seed"
	assert_false(panel.is_valid(), "Invalid seed should be invalid")

func test_ui_updates():
	panel.set_error("Test error")
	assert_true(panel.has_error(), "Error should be displayed")
	panel.clear_error()
	assert_false(panel.has_error(), "Error should be cleared")