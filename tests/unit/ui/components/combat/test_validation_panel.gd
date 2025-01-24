extends "res://tests/fixtures/base_test.gd"

const ValidationPanel = preload("res://src/ui/components/combat/state/state_verification_panel.tscn")

var panel = null
var mock_combat_state = null

func before_each():
	await super.before_each()
	panel = ValidationPanel.instantiate()
	add_child_autofree(panel)
	await panel.ready
	mock_combat_state = create_mock_combat_state()

func after_each():
	await super.after_each()
	panel = null
	mock_combat_state = null

func create_mock_combat_state():
	var state = Node.new()
	track_test_node(state)
	state.is_valid = func(): return true
	return state

func test_initial_setup():
	assert_not_null(panel, "ValidationPanel should be created")
	assert_true(panel.has_node("Container"), "Should have Container node")
	assert_true(panel.has_node("Container/ValidationMessage"), "Should have ValidationMessage node")

func test_validation_message_updates():
	panel._set_validation_message("Test message")
	var message_label = panel.get_node("Container/ValidationMessage")
	assert_eq(message_label.text, "Test message", "Message should be updated")

func test_validation_state_handling():
	panel.set_validation_state(true)
	assert_true(panel.is_valid, "Should be marked as valid")
	assert_false(panel.visible, "Should be hidden when valid")
	
	panel.set_validation_state(false)
	assert_false(panel.is_valid, "Should be marked as invalid")
	assert_true(panel.visible, "Should be visible when invalid")

func test_combat_state_validation():
	panel.validate_combat_state(mock_combat_state)
	assert_true(panel.is_valid, "Should be valid with mock state")