@tool
extends "res://tests/fixtures/base_test.gd"

const CombatLogController := preload("res://src/ui/components/combat/log/combat_log_controller.gd")


var controller: CombatLogController
var _signals_received := {}

func before_each() -> void:
	await super.before_each()
	controller = CombatLogController.new()
	add_child(controller)
	track_test_node(controller)
	watch_signals(controller)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	controller = null
	_signals_received.clear()

func create_test_entry(type: String, data: Dictionary) -> Dictionary:
	return {
		"type": type,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}

func test_initial_state() -> void:
	assert_eq(controller.log_entries.size(), 0, "Should start with no log entries")
	assert_eq(controller.active_filters.size(), 5, "Should have all filter types")
	assert_false(controller.combat_log_panel.visible, "Combat log panel should start hidden")
	assert_eq(controller.get_filter_types().size(), 5, "Should have correct number of filter types")

func test_add_combat_log_entry() -> void:
	var test_entry = create_test_entry("combat", {
		"type": "state_change",
		"state": {"phase": GameEnums.BattlePhase.ACTIVATION}
	})
	
	controller.add_log_entry(test_entry.type, test_entry.data)
	
	assert_eq(controller.log_entries.size(), 1, "Should add entry to log")
	var entry = controller.log_entries[0]
	assert_eq(entry.type, "combat", "Should set correct entry type")
	assert_eq(entry.data.type, "state_change", "Should set correct data type")
	assert_eq(entry.data.state.phase, GameEnums.BattlePhase.ACTIVATION, "Should store state data")
	assert_signal_emitted(controller, "log_entry_added")

func test_add_multiple_entries() -> void:
	var entry_types = ["combat", "status", "override", "terrain", "system"]
	
	for type in entry_types:
		var entry = create_test_entry(type, {"type": "test_%s" % type})
		controller.add_log_entry(entry.type, entry.data)
	
	assert_eq(controller.log_entries.size(), entry_types.size(), "Should add all entries")
	for i in range(entry_types.size()):
		assert_eq(controller.log_entries[i].type, entry_types[i], "Should preserve entry order")

func test_filter_management() -> void:
	# Add entries of different types
	var entry_types = ["combat", "status", "override"]
	for type in entry_types:
		controller.add_log_entry(type, {"type": "test"})
	
	# Test individual filter toggling
	controller._on_filter_changed("combat", false)
	assert_false(controller._should_display_entry(controller.log_entries[0]), "Combat entries should be filtered out")
	assert_true(controller._should_display_entry(controller.log_entries[1]), "Status entries should still be shown")
	assert_signal_emitted(controller, "filter_changed")
	
	# Test multiple filters
	controller._on_filter_changed("status", false)
	assert_false(controller._should_display_entry(controller.log_entries[0]), "Combat entries should remain filtered")
	assert_false(controller._should_display_entry(controller.log_entries[1]), "Status entries should be filtered")
	assert_true(controller._should_display_entry(controller.log_entries[2]), "Override entries should be shown")

func test_filter_persistence() -> void:
	controller._on_filter_changed("combat", false)
	var new_entry = create_test_entry("combat", {"type": "test"})
	controller.add_log_entry(new_entry.type, new_entry.data)
	
	assert_false(controller._should_display_entry(controller.log_entries[0]),
		"New entries should respect existing filters")

func test_log_export() -> void:
	# Add various types of entries
	var test_entries = [
		create_test_entry("combat", {"type": "state_change", "state": {"phase": GameEnums.BattlePhase.ACTIVATION}}),
		create_test_entry("status", {"type": "status_change", "status": "stunned"}),
		create_test_entry("override", {"type": "manual", "value": 5})
	]
	
	for entry in test_entries:
		controller.add_log_entry(entry.type, entry.data)
	
	controller.export_log()
	
	var file = FileAccess.open("user://combat_log_export.json", FileAccess.READ)
	assert_not_null(file, "Export file should be created")
	if file:
		var content = JSON.parse_string(file.get_as_text())
		assert_not_null(content, "Export should contain valid JSON")
		assert_eq(content.entries.size(), test_entries.size(), "Export should contain all entries")
		assert_eq(content.entries[0].type, "combat", "Should preserve entry types")
		assert_eq(content.entries[1].type, "status", "Should preserve entry order")
		file.close()
	assert_signal_emitted(controller, "log_exported")

func test_entry_verification() -> void:
	var test_entries = {
		"combat": {"type": "state_change", "state": {"phase": GameEnums.BattlePhase.ACTIVATION}},
		"status": {"type": "status_change", "status": "stunned"},
		"override": {"type": "manual", "value": 5}
	}
	
	for type in test_entries:
		controller.add_log_entry(type, test_entries[type])
		var entry = controller.log_entries[-1]
		controller._verify_entry(entry)
		assert_signal_emitted(controller, "entry_verified")

func test_combat_state_changes() -> void:
	var test_states = [
		{"phase": GameEnums.BattlePhase.SETUP, "round": 0},
		{"phase": GameEnums.BattlePhase.ACTIVATION, "round": 1},
		{"phase": GameEnums.BattlePhase.CLEANUP, "round": 1}
	]
	
	for state in test_states:
		controller._on_combat_state_changed(state)
		assert_eq(controller.log_entries[-1].type, "combat", "Should log combat state change")
		assert_eq(controller.log_entries[-1].data.state.phase, state.phase, "Should store correct phase")
		assert_eq(controller.log_entries[-1].data.state.round, state.round, "Should store correct round")
		assert_signal_emitted(controller, "log_entry_added")

func test_invalid_operations() -> void:
	# Test adding invalid entry
	controller.add_log_entry("invalid_type", {})
	assert_eq(controller.log_entries.size(), 0, "Should not add entry with invalid type")
	
	# Test invalid filter
	controller._on_filter_changed("invalid_filter", false)
	assert_signal_not_emitted(controller, "filter_changed")
	
	# Test verifying invalid entry
	var invalid_entry = create_test_entry("invalid", {})
	controller._verify_entry(invalid_entry)
	assert_signal_not_emitted(controller, "entry_verified")

func test_large_log_handling() -> void:
	var entry_count = 1000
	var start_time = Time.get_unix_time_from_system()
	
	for i in range(entry_count):
		var entry = create_test_entry("combat", {"type": "test", "index": i})
		controller.add_log_entry(entry.type, entry.data)
	
	var end_time = Time.get_unix_time_from_system()
	var time_taken = end_time - start_time
	
	assert_eq(controller.log_entries.size(), entry_count, "Should handle large number of entries")
	assert_true(time_taken < 1.0, "Should process entries efficiently")