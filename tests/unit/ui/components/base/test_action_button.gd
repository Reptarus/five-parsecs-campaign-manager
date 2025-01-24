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
	assert_not_null(button, "Button should be initialized")
	assert_true(button.is_inside_tree(), "Button should be in scene tree")

func test_button_layout():
	assert_true(button.visible, "Button should be visible by default")
	assert_false(button.disabled, "Button should be enabled by default")

func test_button_signals():
	watch_signals(button)
	button.emit_signal("pressed")
	assert_signal_emitted(button, "pressed")

func test_button_state_updates():
	button.disabled = true
	assert_true(button.disabled, "Button should be disabled after state update")
	
	button.visible = false
	assert_false(button.visible, "Button should be hidden after visibility update")

func test_child_nodes():
	var label = button.get_node_or_null("Label")
	assert_not_null(label, "Button should have a Label node")