extends "res://tests/fixtures/base_test.gd"

const ActionButton = preload("res://src/scenes/campaign/components/ActionButton.tscn")

var button = null

func before_each():
	await super.before_each()
	button = ActionButton.instantiate()
	add_child_autofree(button)
	await button.ready

func after_each():
	await super.after_each()
	button = null

func test_button_initialization():
	assert_not_null(button)
	assert_true(button.is_inside_tree())

func test_button_nodes():
	assert_not_null(button.get_node("Button"))
	assert_not_null(button.get_node("Button/HBoxContainer/Label"))
	assert_not_null(button.get_node("Button/HBoxContainer/IconRect"))

func test_button_properties():
	assert_eq(button.action_name, "")
	assert_eq(button.action_icon, null)
	assert_true(button.is_enabled)

func test_button_visibility():
	button.visible = false
	assert_false(button.visible)
	
	button.visible = true
	assert_true(button.visible)

func test_button_setup():
	button.setup("Test Action", null, true)
	assert_eq(button.action_name, "Test Action")
	assert_true(button.is_enabled)
	assert_eq(button.get_node("Button/HBoxContainer/Label").text, "Test Action")

func test_button_signals():
	watch_signals(button)
	button.emit_signal("pressed")
	assert_signal_emitted(button, "pressed")
	
	button.emit_signal("action_triggered")
	assert_signal_emitted(button, "action_triggered")