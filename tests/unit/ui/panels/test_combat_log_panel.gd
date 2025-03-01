@tool
extends "res://tests/unit/ui/base/panel_test_base.gd"

const CombatLogPanel: GDScript = preload("res://src/ui/components/combat/log/combat_log_panel.gd")

# Test variables with explicit types
var log_list: ItemList
var clear_button: Button
var filter_options: OptionButton
var auto_scroll_check: CheckBox

# Override _create_panel_instance to provide the specific panel
func _create_panel_instance() -> Control:
	return CombatLogPanel.new()

func before_each() -> void:
	await super.before_each()
	
	# Get required nodes
	log_list = _panel.get_node("LogList")
	clear_button = _panel.get_node("ClearButton")
	filter_options = _panel.get_node("FilterOptions")
	auto_scroll_check = _panel.get_node("AutoScrollCheck")
	
	# Force ready call after setup
	_panel._ready()

func after_each() -> void:
	log_list = null
	clear_button = null
	filter_options = null
	auto_scroll_check = null
	await super.after_each()

func test_initial_setup() -> void:
	assert_not_null(_panel.log_list, "Log list should exist")
	assert_not_null(_panel.clear_button, "Clear button should exist")
	assert_not_null(_panel.filter_options, "Filter options should exist")
	assert_not_null(_panel.auto_scroll_check, "Auto scroll check should exist")
	
	assert_eq(_panel.max_entries, 100, "Should have correct max entries")
	assert_true(_panel.auto_scroll, "Auto scroll should be enabled by default")
	assert_eq(_panel.current_filter, "all", "Current filter should be 'all'")
	assert_eq(_panel.log_entries.size(), 0, "Should start with no entries")

func test_filter_options_setup() -> void:
	for key in _panel.FILTER_OPTIONS:
		var found := false
		for i in range(filter_options.item_count):
			if filter_options.get_item_metadata(i) == key:
				found = true
				break
		assert_true(found, "Filter option '%s' should be in dropdown" % key)

func test_log_entry_addition() -> void:
	var test_message := "Test combat log entry"
	TypeSafeMixin._call_node_method_bool(_panel, "add_log_entry", [test_message])
	
	assert_eq(log_list.get_item_count(), 1, "Should have one log entry")
	assert_true(log_list.get_item_text(0).contains(test_message), "Entry should contain test message")

func test_max_entries_limit() -> void:
	for i in range(_panel.max_entries + 10):
		TypeSafeMixin._call_node_method_bool(_panel, "add_log_entry", ["Entry %d" % i])
	
	assert_eq(log_list.get_item_count(), _panel.max_entries,
		"Should not exceed max entries limit")

func test_clear_functionality() -> void:
	TypeSafeMixin._call_node_method_bool(_panel, "add_log_entry", ["Test entry"])
	TypeSafeMixin._call_node_method_bool(_panel, "clear_log", [])
	
	assert_eq(log_list.get_item_count(), 0, "Should clear all entries")
	assert_eq(_panel.log_entries.size(), 0, "Should clear internal log entries")

func test_filter_functionality() -> void:
	TypeSafeMixin._call_node_method_bool(_panel, "add_log_entry", ["Combat: Attack", "combat"])
	TypeSafeMixin._call_node_method_bool(_panel, "add_log_entry", ["System: Ready", "system"])
	
	TypeSafeMixin._call_node_method_bool(_panel, "set_filter", ["combat"])
	assert_eq(log_list.get_item_count(), 1, "Should show only combat entries")
	
	TypeSafeMixin._call_node_method_bool(_panel, "set_filter", ["all"])
	assert_eq(log_list.get_item_count(), 2, "Should show all entries")

func test_auto_scroll_functionality() -> void:
	TypeSafeMixin._call_node_method_bool(_panel, "set_auto_scroll", [false])
	assert_false(_panel.auto_scroll, "Auto scroll should be disabled")
	
	TypeSafeMixin._call_node_method_bool(_panel, "set_auto_scroll", [true])
	assert_true(_panel.auto_scroll, "Auto scroll should be enabled")

# Add inherited panel tests
func test_panel_structure() -> void:
	await super.test_panel_structure()
	
	# Additional CombatLogPanel-specific structure tests
	assert_true(_panel.has_method("add_log_entry"), "Should have add_log_entry method")
	assert_true(_panel.has_method("clear_log"), "Should have clear_log method")
	assert_true(_panel.has_method("set_filter"), "Should have set_filter method")

func test_panel_theme() -> void:
	await super.test_panel_theme()
	
	# Additional CombatLogPanel-specific theme tests
	assert_true(_panel.has_theme_color("combat_color"), "Should have combat color theme")
	assert_true(_panel.has_theme_color("system_color"), "Should have system color theme")
	assert_true(_panel.has_theme_stylebox("panel"), "Should have panel stylebox")

func test_panel_accessibility() -> void:
	await super.test_panel_accessibility()
	
	# Additional CombatLogPanel-specific accessibility tests
	assert_true(log_list.focus_mode != Control.FOCUS_NONE,
		"Log list should be focusable for keyboard navigation")
	assert_true(clear_button.focus_mode != Control.FOCUS_NONE,
		"Clear button should be focusable")
	assert_true(filter_options.focus_mode != Control.FOCUS_NONE,
		"Filter options should be focusable")