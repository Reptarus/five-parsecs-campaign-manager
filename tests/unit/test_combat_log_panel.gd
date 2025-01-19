@tool
extends "res://tests/fixtures/game_test.gd"

const CombatLogPanel := preload("res://src/ui/components/combat/log/combat_log_panel.gd")

# Test variables
var panel: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	panel = CombatLogPanel.new()
	add_child(panel)
	track_test_node(panel)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	panel = null

# Test Methods
func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.entries.size(), 0, "Should start with no entries")

func test_add_entry() -> void:
	watch_signals(panel)
	
	var test_entry = {
		"type": "combat",
		"data": {
			"type": "state_change",
			"state": {"phase": GameEnums.BattlePhase.ACTIVATION}
		}
	}
	
	panel.add_entry(test_entry)
	assert_eq(panel.entries.size(), 1, "Should add entry to panel")
	assert_signal_emitted(panel, "entry_added")

func test_clear_entries() -> void:
	watch_signals(panel)
	
	panel.add_entry({
		"type": "combat",
		"data": {"type": "state_change"}
	})
	
	panel.clear_entries()
	assert_eq(panel.entries.size(), 0, "Should clear all entries")
	assert_signal_emitted(panel, "entries_cleared")

func test_toggle_visibility() -> void:
	watch_signals(panel)
	
	panel.show()
	assert_true(panel.visible, "Panel should be visible after show")
	assert_signal_emitted(panel, "visibility_changed")
	
	panel.hide()
	assert_false(panel.visible, "Panel should be hidden after hide")
	assert_signal_emitted(panel, "visibility_changed")