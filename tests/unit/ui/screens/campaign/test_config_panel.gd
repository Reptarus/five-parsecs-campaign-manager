@tool
extends "res://tests/fixtures/base/game_test.gd"

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
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.get_node("NameInput"), "LineEdit"), "Should have NameInput node")
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.get_node("SeedInput"), "LineEdit"), "Should have SeedInput node")
	assert_not_null(TypeSafeMixin._safe_cast_to_node(panel.get_node("DifficultySelector"), "OptionButton"), "Should have DifficultySelector node")

func test_signal_connections() -> void:
	watch_signals(panel)
	TypeSafeMixin._safe_method_call_bool(panel, "emit_signal", ["config_updated"])
	assert_signal_emitted(panel, "config_updated")

func test_state_management() -> void:
	var test_config: Dictionary = {
		"name": "Test Campaign",
		"seed": "12345",
		"difficulty": 1
	}
	TypeSafeMixin._safe_method_call_bool(panel, "set_config", [test_config])
	var current_config: Dictionary = TypeSafeMixin._safe_method_call_dict(panel, "get_config", [], {})
	assert_eq(current_config.name, test_config.name)
	assert_eq(current_config.seed, test_config.seed)
	assert_eq(current_config.difficulty, test_config.difficulty)

func test_input_validation() -> void:
	# Test name validation
	var name_input: LineEdit = TypeSafeMixin._safe_cast_to_node(panel.get_node("NameInput"), "LineEdit")
	TypeSafeMixin._safe_method_call_bool(name_input, "set_text", [""])
	assert_false(TypeSafeMixin._safe_method_call_bool(panel, "is_valid", []), "Empty name should be invalid")
	
	# Test seed validation
	var seed_input: LineEdit = TypeSafeMixin._safe_cast_to_node(panel.get_node("SeedInput"), "LineEdit")
	TypeSafeMixin._safe_method_call_bool(seed_input, "set_text", ["invalid_seed"])
	assert_false(TypeSafeMixin._safe_method_call_bool(panel, "is_valid", []), "Invalid seed should be invalid")

func test_ui_updates() -> void:
	TypeSafeMixin._safe_method_call_bool(panel, "set_error", ["Test error"])
	assert_true(TypeSafeMixin._safe_method_call_bool(panel, "has_error", []), "Error should be displayed")
	TypeSafeMixin._safe_method_call_bool(panel, "clear_error", [])
	assert_false(TypeSafeMixin._safe_method_call_bool(panel, "has_error", []), "Error should be cleared")