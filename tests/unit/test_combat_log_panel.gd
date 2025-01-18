@tool
extends "../fixtures/base_test.gd"

const CombatLogPanel := preload("res://src/ui/components/combat/log/combat_log_panel.gd")

var panel: Node
var _signals_received := {}

func before_each() -> void:
	panel = CombatLogPanel.new()
	add_child_autoqfree(panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.log_entries.size(), 0, "Should start with no entries")
	assert_eq(panel.active_filters.size(), 5, "Should have all filter types")

func test_add_log_entry() -> void:
	var test_entry = {
		"type": "combat",
		"data": {
			"type": "state_change",
			"state": {"phase": GameEnums.BattlePhase.ACTIVATION}
		}
	}
	
	panel.add_log_entry(test_entry)
	
	assert_eq(panel.log_entries.size(), 1, "Should add entry to log")
	var entry = panel.log_entries[0]
	assert_eq(entry.type, "combat", "Should set correct entry type")
	assert_eq(entry.data.type, "state_change", "Should set correct data type")

func test_filter_entries() -> void:
	var combat_entry = {
		"type": "combat",
		"data": {"type": "state_change"}
	}
	var status_entry = {
		"type": "status",
		"data": {"type": "status_change"}
	}
	
	panel.add_log_entry(combat_entry)
	panel.add_log_entry(status_entry)
	
	panel._on_filter_changed("combat", false)
	assert_false(panel._should_display_entry(panel.log_entries[0]), "Combat entries should be filtered out")
	assert_true(panel._should_display_entry(panel.log_entries[1]), "Status entries should still be shown")

func test_clear_log() -> void:
	var test_entry = {
		"type": "combat",
		"data": {"type": "state_change"}
	}
	panel.add_log_entry(test_entry)
	
	panel.clear_log()
	
	assert_eq(panel.log_entries.size(), 0, "Should clear all entries")

func test_export_log() -> void:
	var test_entry = {
		"type": "combat",
		"data": {"type": "state_change"}
	}
	panel.add_log_entry(test_entry)
	
	watch_signals(panel)
	panel.export_log()
	
	assert_signal_emitted(panel, "log_exported")

func test_toggle_visibility() -> void:
	watch_signals(panel)
	panel.toggle_visibility()
	
	assert_true(panel.visible, "Panel should be visible")
	assert_signal_emitted(panel, "visibility_changed")
	
	panel.toggle_visibility()
	assert_false(panel.visible, "Panel should be hidden")

func test_filter_by_type() -> void:
	var combat_entry = {
		"type": "combat",
		"data": {"type": "state_change"}
	}
	var status_entry = {
		"type": "status",
		"data": {"type": "status_change"}
	}
	var effect_entry = {
		"type": "effect",
		"data": {"type": "buff_applied"}
	}
	
	panel.add_log_entry(combat_entry)
	panel.add_log_entry(status_entry)
	panel.add_log_entry(effect_entry)
	
	panel.filter_by_type("combat", true)
	panel.filter_by_type("status", false)
	panel.filter_by_type("effect", false)
	
	var visible_entries = panel.get_visible_entries()
	assert_eq(visible_entries.size(), 1, "Should only show combat entries")
	assert_eq(visible_entries[0].type, "combat", "Should be combat entry")

func test_search_entries() -> void:
	var test_entry = {
		"type": "combat",
		"data": {
			"type": "state_change",
			"message": "Unit moved to position"
		}
	}
	panel.add_log_entry(test_entry)
	
	panel.search_text = "moved"
	var search_results = panel.get_visible_entries()
	assert_eq(search_results.size(), 1, "Should find entry with matching text")
	
	panel.search_text = "attack"
	search_results = panel.get_visible_entries()
	assert_eq(search_results.size(), 0, "Should not find entries without matching text")