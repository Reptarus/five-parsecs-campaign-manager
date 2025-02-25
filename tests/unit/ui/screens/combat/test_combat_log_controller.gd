@tool
extends "res://tests/fixtures/base/game_test.gd"

const TestedClass = preload("res://src/ui/components/combat/log/combat_log_controller.gd")

# Test constants
const TEST_LOG_ENTRIES := {
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
var _instance: Node
var _log_updated_signal_emitted := false
var _filter_changed_signal_emitted := false
var _last_log_entry: Dictionary
var _last_filter_state: Dictionary

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.new()
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

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("log_updated"):
		_instance.log_updated.connect(_on_log_updated)
	if _instance.has_signal("filter_changed"):
		_instance.filter_changed.connect(_on_filter_changed)
	if _instance.has_signal("entry_selected"):
		_instance.entry_selected.connect(_on_entry_selected)

func _disconnect_signals() -> void:
	if _instance and not _instance.is_queued_for_deletion():
		if _instance.has_signal("log_updated") and _instance.log_updated.is_connected(_on_log_updated):
			_instance.log_updated.disconnect(_on_log_updated)
		if _instance.has_signal("filter_changed") and _instance.filter_changed.is_connected(_on_filter_changed):
			_instance.filter_changed.disconnect(_on_filter_changed)
		if _instance.has_signal("entry_selected") and _instance.entry_selected.is_connected(_on_entry_selected):
			_instance.entry_selected.disconnect(_on_entry_selected)

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
	assert_false(_log_updated_signal_emitted)
	assert_false(_filter_changed_signal_emitted)
	assert_true(_instance.log_entries.is_empty())
	assert_true(_instance.active_filters.has("combat"))
	
	# Test default filters
	assert_true(_instance.active_filters.combat)
	assert_true(_instance.active_filters.damage)
	assert_true(_instance.active_filters.ability)

func _create_test_entry(entry_type: String) -> Dictionary:
	var entry = TEST_LOG_ENTRIES[entry_type].duplicate()
	entry["timestamp"] = Time.get_datetime_string_from_system()
	return entry

func test_add_log_entry() -> void:
	var test_entry = _create_test_entry("ATTACK")
	
	_instance.add_log_entry(test_entry.type, test_entry)
	
	verify_signal_emitted(_instance, "log_updated")
	assert_true(_log_updated_signal_emitted)
	assert_eq(_last_log_entry.type, test_entry.type)
	assert_false(_instance.log_entries.is_empty())
	
	# Verify entry structure
	var added_entry = _instance.log_entries[0]
	assert_eq(added_entry.type, test_entry.type)
	assert_eq(added_entry.data, test_entry)
	assert_not_null(added_entry.id)
	assert_not_null(added_entry.timestamp)

func test_multiple_entry_types() -> void:
	# Add different types of entries
	_instance.add_log_entry("ATTACK", _create_test_entry("ATTACK"))
	_instance.add_log_entry("HEAL", _create_test_entry("HEAL"))
	_instance.add_log_entry("ABILITY", _create_test_entry("ABILITY"))
	
	assert_eq(_instance.log_entries.size(), 3, "Should have all entries added")
	
	# Verify each entry type is stored correctly
	var types = _instance.log_entries.map(func(entry): return entry.type)
	assert_true("ATTACK" in types, "Should contain attack entry")
	assert_true("HEAL" in types, "Should contain heal entry")
	assert_true("ABILITY" in types, "Should contain ability entry")

func test_filter_change() -> void:
	var test_filters = {
		"combat": false,
		"ability": true,
		"reaction": true
	}
	
	_instance.active_filters = test_filters.duplicate()
	
	verify_signal_emitted(_instance, "filter_changed")
	assert_true(_filter_changed_signal_emitted)
	assert_eq(_last_filter_state, test_filters)

func test_filtered_entries() -> void:
	# Add multiple entry types
	var attack_entry = _create_test_entry("ATTACK")
	var heal_entry = _create_test_entry("HEAL")
	var ability_entry = _create_test_entry("ABILITY")
	
	_instance.add_log_entry("ATTACK", attack_entry)
	_instance.add_log_entry("HEAL", heal_entry)
	_instance.add_log_entry("ABILITY", ability_entry)
	
	# Test filtering by type
	_instance.active_filters["combat"] = false
	assert_false(_instance._should_display_entry(attack_entry))
	assert_true(_instance._should_display_entry(heal_entry))
	assert_true(_instance._should_display_entry(ability_entry))

func test_clear_log() -> void:
	# Add multiple entries before clearing
	_instance.add_log_entry("ATTACK", _create_test_entry("ATTACK"))
	_instance.add_log_entry("HEAL", _create_test_entry("HEAL"))
	assert_eq(_instance.log_entries.size(), 2, "Should have entries before clearing")
	
	_reset_signals()
	_instance.clear_log()
	
	verify_signal_emitted(_instance, "log_updated")
	assert_true(_log_updated_signal_emitted)
	assert_true(_instance.log_entries.is_empty())

# UI Interaction Tests
func test_entry_validation() -> void:
	# Test valid predefined entries
	var attack_entry = _create_test_entry("ATTACK")
	var heal_entry = _create_test_entry("HEAL")
	var ability_entry = _create_test_entry("ABILITY")
	
	assert_true(_instance._should_display_entry(attack_entry))
	assert_true(_instance._should_display_entry(heal_entry))
	assert_true(_instance._should_display_entry(ability_entry))
	
	# Test invalid entry
	var invalid_entry = {
		"type": "invalid_type",
		"data": {}
	}
	assert_false(_instance._should_display_entry(invalid_entry))

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
	assert_false(_instance.active_filters.damage)
	assert_false(_instance.active_filters.ability)
	assert_true(_instance.active_filters.combat)

func test_display_update() -> void:
	# Add multiple entries of different types
	_instance.add_log_entry("ATTACK", _create_test_entry("ATTACK"))
	_instance.add_log_entry("HEAL", _create_test_entry("HEAL"))
	_instance.add_log_entry("ABILITY", _create_test_entry("ABILITY"))
	
	# Update display
	_instance._update_display()
	
	# Verify display is updated with all entries
	assert_eq(_instance.log_entries.size(), 3)
	
	# Verify entries are in correct order (assuming newest first)
	var types = _instance.log_entries.map(func(entry): return entry.type)
	assert_eq(types, ["ABILITY", "HEAL", "ATTACK"])