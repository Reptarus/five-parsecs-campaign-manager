extends "res://tests/fixtures/base_test.gd"

const ActionPanel = preload("res://src/scenes/campaign/components/ActionPanel.tscn")

var panel = null

func before_each():
	await super.before_each()
	panel = ActionPanel.instantiate()
	add_child_autofree(panel)
	await panel.ready

func after_each():
	await super.after_each()
	panel = null

func test_initial_setup():
	assert_not_null(panel, "Action panel should be instantiated")
	assert_true(panel.is_inside_tree(), "Panel should be in scene tree")
	assert_true(panel.visible, "Panel should be visible by default")

func test_layout():
	assert_true(panel.has_node("Container"), "Panel should have container node")
	var container = panel.get_node("Container")
	assert_not_null(container, "Container node should exist")
	assert_true(container.visible, "Container should be visible")
	assert_true(container is Control, "Container should be a Control node")

func test_signals():
	watch_signals(panel)
	panel.emit_signal("action_selected")
	assert_signal_emitted(panel, "action_selected")
	
	panel.emit_signal("panel_closed")
	assert_signal_emitted(panel, "panel_closed")

func test_state_updates():
	panel.visible = false
	assert_false(panel.visible, "Panel should be hidden after visibility update")
	
	panel.visible = true
	assert_true(panel.visible, "Panel should be visible after visibility update")
	
	var container = panel.get_node("Container")
	container.custom_minimum_size = Vector2(200, 300)
	assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")

func test_child_management():
	var container = panel.get_node("Container")
	var test_child = Button.new()
	container.add_child(test_child)
	
	assert_true(test_child.is_inside_tree(), "Added child should be in scene tree")
	assert_true(container.get_children().has(test_child), "Container should have the added child")
	
	test_child.queue_free()
	await get_tree().process_frame
	assert_false(container.get_children().has(test_child), "Container should remove freed children")