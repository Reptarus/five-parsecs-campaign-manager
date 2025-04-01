@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe constants with explicit typing
const TestedClass: GDScript = preload("res://src/ui/components/combat/log/combat_log_controller.gd")

# Test constants with explicit typing
const TEST_LOG_ENTRIES: Dictionary = {
	"ATTACK": {
		"type": "ATTACK",
		"source": "Player",
		"target": "Enemy",
		"damage": 10
	},
	"HEAL": {
		"type": "HEAL",
		"source": "Medic",
		"target": "Player",
		"amount": 20
	},
	"ABILITY": {
		"type": "ABILITY",
		"source": "Player",
		"ability_name": "Fireball"
	}
}

# Type-safe instance variables
var _instance: Node = null
var _log_updated_signal_emitted: bool = false
var _filter_changed_signal_emitted: bool = false
var _last_log_entry: Dictionary = {}
var _last_filter_state: Dictionary = {}

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.new()
	if not _instance:
		push_error("Failed to create combat log controller instance")
		return
	add_child_autofree(_instance)
	track_test_node(_instance)
	_connect_signals()
	_reset_signals()
	await stabilize_engine()

func after_each() -> void:
	_disconnect_signals()
	if is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await super.after_each()

# Type-safe signal handling
func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("log_updated"):
		_instance.log_updated.connect(self._on_log_updated)
	if _instance.has_signal("filter_changed"):
		_instance.filter_changed.connect(self._on_filter_changed)
	if _instance.has_signal("entry_selected"):
		_instance.entry_selected.connect(self._on_entry_selected)

func _disconnect_signals() -> void:
	if _instance and not _instance.is_queued_for_deletion():
		if _instance.has_signal("log_updated") and _instance.log_updated.is_connected(self._on_log_updated):
			_instance.log_updated.disconnect(self._on_log_updated)
		if _instance.has_signal("filter_changed") and _instance.filter_changed.is_connected(self._on_filter_changed):
			_instance.filter_changed.disconnect(self._on_filter_changed)
		if _instance.has_signal("entry_selected") and _instance.entry_selected.is_connected(self._on_entry_selected):
			_instance.entry_selected.disconnect(self._on_entry_selected)

func _reset_signals() -> void:
	_log_updated_signal_emitted = false
	_filter_changed_signal_emitted = false
	_last_log_entry = {}
	_last_filter_state = {}

func _on_log_updated(entry: Dictionary) -> void:
	_log_updated_signal_emitted = true
	_last_log_entry = entry

func _on_filter_changed(filters: Dictionary) -> void:
	_filter_changed_signal_emitted = true
	_last_filter_state = filters

func _on_entry_selected(entry: Dictionary) -> void:
	_last_log_entry = entry

# Core Functionality Tests
func test_initial_state() -> void:
	assert_false(_log_updated_signal_emitted, "Log updated signal should not be emitted initially")
	assert_false(_filter_changed_signal_emitted, "Filter changed signal should not be emitted initially")
	assert_true(_instance.log_entries.is_empty(), "Log entries should be empty initially")
	assert_true("combat" in _instance.active_filters, "Default filters should include combat")
	
	# Test default filters
	assert_true(_instance.active_filters.combat, "Combat filter should be active by default")
	assert_true(_instance.active_filters.damage, "Damage filter should be active by default")
	assert_true(_instance.active_filters.ability, "Ability filter should be active by default")

func _create_test_entry(entry_type: String) -> Dictionary:
	var entry: Dictionary = TEST_LOG_ENTRIES[entry_type].duplicate()
	entry["timestamp"] = Time.get_datetime_string_from_system()
	return entry

func test_add_log_entry() -> void:
	var test_entry: Dictionary = _create_test_entry("ATTACK")
	
	_instance.add_log_entry(test_entry.type, test_entry)
	
	verify_signal_emitted(_instance, "log_updated", "Log updated signal should be emitted")
	assert_true(_log_updated_signal_emitted, "Log updated signal should be emitted")
	assert_eq(_last_log_entry.type, test_entry.type, "Last log entry should match test entry type")
	assert_false(_instance.log_entries.is_empty(), "Log entries should not be empty after adding entry")
	
	# Verify entry structure
	var added_entry: Dictionary = _instance.log_entries[0]
	assert_eq(added_entry.type, test_entry.type, "Entry type should match")
	assert_eq(added_entry.data, test_entry, "Entry data should match")
	assert_not_null(added_entry.id, "Entry should have ID")
	assert_not_null(added_entry.timestamp, "Entry should have timestamp")

func test_multiple_entry_types() -> void:
	# Add different types of entries
	_instance.add_log_entry("ATTACK", _create_test_entry("ATTACK"))
	_instance.add_log_entry("HEAL", _create_test_entry("HEAL"))
	_instance.add_log_entry("ABILITY", _create_test_entry("ABILITY"))
	
	assert_eq(_instance.log_entries.size(), 3, "Should have all entries added")
	
	# Verify each entry type is stored correctly
	var types: Array = _instance.log_entries.map(func(entry: Dictionary) -> String: return entry.type)
	assert_true("ATTACK" in types, "Should contain attack entry")
	assert_true("HEAL" in types, "Should contain heal entry")
	assert_true("ABILITY" in types, "Should contain ability entry")

func test_filter_change() -> void:
	var test_filters: Dictionary = {
		"combat": false,
		"ability": true,
		"reaction": true
	}
	
	_instance.active_filters = test_filters.duplicate()
	
	verify_signal_emitted(_instance, "filter_changed", "Filter changed signal should be emitted")
	assert_true(_filter_changed_signal_emitted, "Filter changed signal should be emitted")
	assert_eq(_last_filter_state, test_filters, "Filter state should match test filters")

func test_filtered_entries() -> void:
	# Add multiple entry types
	var attack_entry: Dictionary = _create_test_entry("ATTACK")
	var heal_entry: Dictionary = _create_test_entry("HEAL")
	var ability_entry: Dictionary = _create_test_entry("ABILITY")
	
	_instance.add_log_entry("ATTACK", attack_entry)
	_instance.add_log_entry("HEAL", heal_entry)
	_instance.add_log_entry("ABILITY", ability_entry)
	
	# Test filtering by type
	_instance.active_filters["combat"] = false
	assert_false(_instance._should_display_entry(attack_entry), "Attack entry should be filtered out")
	assert_true(_instance._should_display_entry(heal_entry), "Heal entry should be displayed")
	assert_true(_instance._should_display_entry(ability_entry), "Ability entry should be displayed")

func test_clear_log() -> void:
	# Add multiple entries before clearing
	_instance.add_log_entry("ATTACK", _create_test_entry("ATTACK"))
	_instance.add_log_entry("HEAL", _create_test_entry("HEAL"))
	assert_eq(_instance.log_entries.size(), 2, "Should have entries before clearing")
	
	_reset_signals()
	_instance.clear_log()
	
	verify_signal_emitted(_instance, "log_updated", "Log updated signal should be emitted after clearing")
	assert_true(_log_updated_signal_emitted, "Log updated signal should be emitted after clearing")
	assert_true(_instance.log_entries.is_empty(), "Log entries should be empty after clearing")

# UI Interaction Tests
func test_entry_validation() -> void:
	# Test valid predefined entries
	var attack_entry: Dictionary = _create_test_entry("ATTACK")
	var heal_entry: Dictionary = _create_test_entry("HEAL")
	var ability_entry: Dictionary = _create_test_entry("ABILITY")
	
	assert_true(_instance._should_display_entry(attack_entry), "Attack entry should be displayed")
	assert_true(_instance._should_display_entry(heal_entry), "Heal entry should be displayed")
	assert_true(_instance._should_display_entry(ability_entry), "Ability entry should be displayed")
	
	# Test invalid entry
	var invalid_entry: Dictionary = {
		"type": "invalid_type",
		"data": {}
	}
	assert_false(_instance._should_display_entry(invalid_entry), "Invalid entry should not be displayed")

func test_filter_persistence() -> void:
	# Set some filters
	_instance.active_filters.damage = false
	_instance.active_filters.ability = false
	
	# Save filters
	_instance._save_filters()
	
	# Reset filters
	_instance.active_filters.damage = true
	_instance.active_filters.ability = true
	
	# Load filters
	_instance._load_saved_filters()
	
	# Verify filters are persisted
	assert_false(_instance.active_filters.damage, "Damage filter should remain disabled after reload")
	assert_false(_instance.active_filters.ability, "Ability filter should remain disabled after reload")
	assert_true(_instance.active_filters.combat, "Combat filter should remain enabled after reload")

func test_display_update() -> void:
	# Add multiple entries of different types
	_instance.add_log_entry("ATTACK", _create_test_entry("ATTACK"))
	_instance.add_log_entry("HEAL", _create_test_entry("HEAL"))
	_instance.add_log_entry("ABILITY", _create_test_entry("ABILITY"))
	
	# Update display
	_instance._update_display()
	
	# Verify display is updated with all entries
	assert_eq(_instance.log_entries.size(), 3, "Should have all entries in display")
	
	# Verify entries are in correct order (assuming newest first)
	var types: Array[String] = []
	for entry in _instance.log_entries:
		types.append(entry.type as String)
	assert_eq(types, ["ABILITY", "HEAL", "ATTACK"], "Entries should be in correct order")