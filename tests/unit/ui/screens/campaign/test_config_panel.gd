@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

const ConfigPanel = preload("res://src/ui/screens/campaign/panels/ConfigPanel.tscn")

var panel: Node = null

func before_each() -> void:
	panel = ConfigPanel.instantiate()
	if not panel:
		push_error("Failed to instantiate config panel")
		return
		
	add_child(panel)
	watch_signals(panel)
	await panel.ready
	await get_tree().process_frame

func after_each() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = null

func test_initial_setup() -> void:
	assert_not_null(panel, "Config panel should be created")
	# Verify required nodes are present
	assert_not_null(panel.get_node("NameInput") as LineEdit, "Should have NameInput node")
	assert_not_null(panel.get_node("SeedInput") as LineEdit, "Should have SeedInput node")
	assert_not_null(panel.get_node("DifficultySelector") as OptionButton, "Should have DifficultySelector node")

func test_signal_connections() -> void:
	watch_signals(panel)
	_call_node_method_bool(panel, "emit_signal", ["config_updated"])
	assert_signal_emitted(panel, "config_updated")

func test_state_management() -> void:
	var test_config: Dictionary = {
		"name": "Test Campaign",
		"seed": "12345",
		"difficulty": 1
	}
	_call_node_method_bool(panel, "set_config", [test_config])
	var current_config: Dictionary = _call_node_method(panel, "get_config", []) as Dictionary
	assert_eq(current_config.name, test_config.name)
	assert_eq(current_config.seed, test_config.seed)
	assert_eq(current_config.difficulty, test_config.difficulty)

func test_input_validation() -> void:
	# Test name validation
	var name_input: LineEdit = panel.get_node("NameInput") as LineEdit
	_call_node_method_bool(name_input, "set_text", [""])
	assert_false(_call_node_method_bool(panel, "is_valid", []), "Empty name should be invalid")
	
	# Test seed validation
	var seed_input: LineEdit = panel.get_node("SeedInput") as LineEdit
	_call_node_method_bool(seed_input, "set_text", ["invalid_seed"])
	assert_false(_call_node_method_bool(panel, "is_valid", []), "Invalid seed should be invalid")

func test_ui_updates() -> void:
	_call_node_method_bool(panel, "set_error", ["Test error"])
	assert_true(_call_node_method_bool(panel, "has_error", []), "Error should be displayed")
	_call_node_method_bool(panel, "clear_error", [])
	assert_false(_call_node_method_bool(panel, "has_error", []), "Error should be cleared")