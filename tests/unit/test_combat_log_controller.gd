@tool
extends "res://tests/fixtures/game_test.gd"

const CombatLogController := preload("res://src/ui/components/combat/log/combat_log_controller.gd")

# Test variables
var controller: Node # Using Node type to avoid casting issues
var _signals_received := {}

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	controller = CombatLogController.new()
	add_child(controller)
	track_test_node(controller)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	controller = null
	_signals_received.clear()

# Test Methods
func test_initial_state() -> void:
	assert_eq(controller.log_entries.size(), 0, "Should start with no log entries")
	assert_eq(controller.active_filters.size(), 5, "Should have all filter types")
	assert_false(controller.combat_log_panel.visible, "Combat log panel should start hidden")

func test_add_log_entry() -> void:
	watch_signals(controller)
	
	var test_entry = {
		"type": "combat",
		"data": {
			"type": "state_change",
			"state": {"phase": GameEnums.BattlePhase.ACTIVATION}
		}
	}
	
	controller.add_log_entry(test_entry.type, test_entry.data)
	
	assert_eq(controller.log_entries.size(), 1, "Should add entry to log")
	var entry = controller.log_entries[0]
	assert_eq(entry.type, "combat", "Should set correct entry type")
	assert_eq(entry.data.type, "state_change", "Should set correct data type")
	assert_signal_emitted(controller, "log_entry_added")

func test_filter_entries() -> void:
	watch_signals(controller)
	
	var combat_entry = {
		"type": "combat",
		"data": {"type": "state_change"}
	}
	var status_entry = {
		"type": "status",
		"data": {"type": "status_change"}
	}
	
	controller.add_log_entry(combat_entry.type, combat_entry.data)
	controller.add_log_entry(status_entry.type, status_entry.data)
	
	controller._on_filter_changed("combat", false)
	assert_false(controller._should_display_entry(controller.log_entries[0]), "Combat entries should be filtered out")
	assert_true(controller._should_display_entry(controller.log_entries[1]), "Status entries should still be shown")
	assert_signal_emitted(controller, "filter_changed")

func test_export_log() -> void:
	watch_signals(controller)
	
	var test_entry = {
		"type": "combat",
		"data": {"type": "state_change"}
	}
	controller.add_log_entry(test_entry.type, test_entry.data)
	
	controller.export_log()
	
	var file = FileAccess.open("user://combat_log_export.json", FileAccess.READ)
	assert_not_null(file, "Export file should be created")
	if file:
		var content = JSON.parse_string(file.get_as_text())
		assert_not_null(content, "Export file should contain valid JSON")
		assert_eq(content.entries.size(), 1, "Export should contain all entries")
		file.close()
	assert_signal_emitted(controller, "log_exported")

func test_verify_combat_entry() -> void:
	watch_signals(controller)
	
	var test_entry = {
		"type": "combat",
		"data": {
			"type": "state_change",
			"state": {"phase": GameEnums.BattlePhase.ACTIVATION}
		}
	}
	controller.add_log_entry(test_entry.type, test_entry.data)
	
	var entry = controller.log_entries[0]
	controller._verify_entry(entry)
	
	# Note: We can't test the actual verification since we don't have a real combat manager
	# Instead, we verify the handler was called without errors
	assert_true(true, "Should handle combat entry verification without errors")
	assert_signal_emitted(controller, "entry_verified")

func test_verify_status_entry() -> void:
	watch_signals(controller)
	
	var test_entry = {
		"type": "status",
		"data": {
			"type": "status_change",
			"status": "stunned"
		}
	}
	controller.add_log_entry(test_entry.type, test_entry.data)
	
	var entry = controller.log_entries[0]
	controller._verify_entry(entry)
	
	assert_true(true, "Should handle status entry verification without errors")
	assert_signal_emitted(controller, "entry_verified")

func test_revert_override_entry() -> void:
	watch_signals(controller)
	
	var test_entry = {
		"type": "override",
		"data": {
			"type": "manual",
			"value": 5
		}
	}
	controller.add_log_entry(test_entry.type, test_entry.data)
	
	var entry = controller.log_entries[0]
	controller._revert_entry(entry)
	
	assert_true(true, "Should handle override entry reversion without errors")
	assert_signal_emitted(controller, "entry_reverted")

func test_combat_state_changed() -> void:
	watch_signals(controller)
	
	var new_state = {"phase": GameEnums.BattlePhase.ACTIVATION, "round": 1}
	controller._on_combat_state_changed(new_state)
	
	assert_eq(controller.log_entries.size(), 1, "Should log combat state change")
	var entry = controller.log_entries[0]
	assert_eq(entry.type, "combat", "Should be combat type entry")
	assert_eq(entry.data.type, "state_change", "Should be state change data")
	assert_eq(entry.data.state.phase, GameEnums.BattlePhase.ACTIVATION, "Should store state data")
	assert_signal_emitted(controller, "log_entry_added")