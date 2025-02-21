@tool
extends GameTest

const TestedClass = preload("res://src/ui/components/combat/log/combat_log_controller.gd")

var _instance: Node
var _log_updated_signal_emitted := false
var _filter_changed_signal_emitted := false
var _last_log_entry: Dictionary
var _last_filter_state: Dictionary

func before_each() -> void:
	_instance = TestedClass.new()
	add_child(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_instance.queue_free()
	_instance = null

func _connect_signals() -> void:
	if _instance.has_signal("log_updated"):
		_instance.log_updated.connect(_on_log_updated)
	if _instance.has_signal("filter_changed"):
		_instance.filter_changed.connect(_on_filter_changed)

func _disconnect_signals() -> void:
	if _instance and not _instance.is_queued_for_deletion():
		if _instance.has_signal("log_updated") and _instance.log_updated.is_connected(_on_log_updated):
			_instance.log_updated.disconnect(_on_log_updated)
		if _instance.has_signal("filter_changed") and _instance.filter_changed.is_connected(_on_filter_changed):
			_instance.filter_changed.disconnect(_on_filter_changed)

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

func test_initial_state() -> void:
	assert_false(_log_updated_signal_emitted)
	assert_false(_filter_changed_signal_emitted)
	assert_true(_instance.log_entries.is_empty())
	assert_true(_instance.active_filters.has("combat"))

func test_add_log_entry() -> void:
	var test_entry = {
		"type": "combat",
		"message": "Test combat log entry",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	_instance.add_log_entry(test_entry.type, test_entry)
	
	verify_signal_emitted(_instance, "log_updated")
	assert_true(_log_updated_signal_emitted)
	assert_eq(_last_log_entry.type, test_entry.type)
	assert_false(_instance.log_entries.is_empty())

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
	var combat_entry = {
		"type": "combat",
		"message": "Combat entry",
		"timestamp": Time.get_datetime_string_from_system()
	}
	var ability_entry = {
		"type": "ability",
		"message": "Ability entry",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	_instance.add_log_entry(combat_entry.type, combat_entry)
	_instance.add_log_entry(ability_entry.type, ability_entry)
	
	_instance.active_filters["combat"] = false
	assert_false(_instance._should_display_entry(combat_entry))
	assert_true(_instance._should_display_entry(ability_entry))

func test_clear_log() -> void:
	var test_entry = {
		"type": "combat",
		"message": "Test entry",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	_instance.add_log_entry(test_entry.type, test_entry)
	_reset_signals()
	
	_instance.clear_log()
	
	verify_signal_emitted(_instance, "log_updated")
	assert_true(_log_updated_signal_emitted)
	assert_true(_instance.log_entries.is_empty())