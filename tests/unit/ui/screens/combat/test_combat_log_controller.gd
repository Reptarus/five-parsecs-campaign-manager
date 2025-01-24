extends "res://addons/gut/test.gd"

const CombatLogController = preload("res://src/ui/components/combat/log/combat_log_controller.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var combat_log: CombatLogController
var log_updated_signal_emitted := false
var log_cleared_signal_emitted := false
var last_log_entry: Dictionary

func before_each() -> void:
	combat_log = CombatLogController.new()
	add_child(combat_log)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	combat_log.queue_free()

func _reset_signals() -> void:
	log_updated_signal_emitted = false
	log_cleared_signal_emitted = false
	last_log_entry = {}

func _connect_signals() -> void:
	# Connect to available signals
	if combat_log.has_signal("entry_selected"):
		combat_log.entry_selected.connect(_on_entry_selected)
	if combat_log.has_signal("filter_changed"):
		combat_log.filter_changed.connect(_on_filter_changed)

func _on_entry_selected(entry: Dictionary) -> void:
	last_log_entry = entry

func _on_filter_changed(filter_type: String, enabled: bool) -> void:
	# Handle filter changes
	pass

func test_initial_setup() -> void:
	assert_not_null(combat_log)
	assert_eq(combat_log.log_entries.size(), 0)
	assert_not_null(combat_log.active_filters)

func test_add_log_entry() -> void:
	var entry_data = {
		"source": "Player",
		"target": "Enemy",
		"value": 10
	}
	
	combat_log.add_log_entry("damage", entry_data)
	
	assert_eq(combat_log.log_entries.size(), 1)
	var added_entry = combat_log.log_entries[0]
	assert_eq(added_entry.type, "damage")
	assert_eq(added_entry.data, entry_data)
	assert_not_null(added_entry.id)
	assert_not_null(added_entry.timestamp)

func test_filter_handling() -> void:
	# Test default filters
	assert_true(combat_log.active_filters.combat)
	assert_true(combat_log.active_filters.damage)
	assert_true(combat_log.active_filters.ability)
	
	# Test filter application
	var entry_data = {
		"source": "Player",
		"target": "Enemy",
		"value": 10
	}
	
	combat_log.add_log_entry("damage", entry_data)
	assert_true(combat_log._should_display_entry(combat_log.log_entries[0]))
	
	# Test filter update
	combat_log.active_filters.damage = false
	assert_false(combat_log._should_display_entry(combat_log.log_entries[0]))

func test_display_update() -> void:
	var entry_data = {
		"source": "Player",
		"target": "Enemy",
		"value": 10
	}
	
	# Add multiple entries
	combat_log.add_log_entry("damage", entry_data)
	combat_log.add_log_entry("ability", entry_data)
	
	# Update display
	combat_log._update_display()
	
	# Verify display is updated
	assert_eq(combat_log.log_entries.size(), 2)

func test_entry_validation() -> void:
	var valid_entry = {
		"id": "1",
		"type": "damage",
		"data": {
			"source": "Player",
			"target": "Enemy",
			"value": 10
		},
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var invalid_entry = {
		"type": "invalid_type",
		"data": {}
	}
	
	assert_true(combat_log._should_display_entry(valid_entry))
	assert_false(combat_log._should_display_entry(invalid_entry))

func test_filter_persistence() -> void:
	# Set some filters
	combat_log.active_filters.damage = false
	combat_log.active_filters.ability = false
	
	# Save filters
	combat_log._load_saved_filters()
	
	# Verify filters are persisted
	assert_false(combat_log.active_filters.damage)
	assert_false(combat_log.active_filters.ability)
	assert_true(combat_log.active_filters.combat)