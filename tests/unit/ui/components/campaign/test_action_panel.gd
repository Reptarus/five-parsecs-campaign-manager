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

func test_panel_initialization():
	assert_not_null(panel)
	assert_true(panel.is_inside_tree())

func test_panel_nodes():
	assert_not_null(panel.get_node("VBoxContainer"))
	assert_not_null(panel.get_node("VBoxContainer/CategoryTabs"))
	assert_not_null(panel.get_node("VBoxContainer/ScrollContainer/ActionContainer"))
	assert_not_null(panel.get_node("VBoxContainer/DescriptionPanel"))

func test_panel_properties():
	assert_eq(panel.current_phase, "")
	assert_eq(panel.selected_action, "")

func test_panel_phase_change():
	panel.set_phase("upkeep")
	assert_eq(panel.current_phase, "upkeep")
	
	panel.set_phase("battle")
	assert_eq(panel.current_phase, "battle")

func test_panel_signals():
	watch_signals(panel)
	panel.emit_signal("action_selected", "test_action")
	assert_signal_emitted(panel, "action_selected")
	
	panel.emit_signal("phase_changed", "battle")
	assert_signal_emitted(panel, "phase_changed")

func test_panel_category_tabs():
	var tabs = panel.get_node("VBoxContainer/CategoryTabs")
	assert_not_null(tabs)
	assert_true(tabs.tab_count > 0)
	
	# Test tab switching
	tabs.current_tab = 1
	assert_eq(tabs.current_tab, 1)