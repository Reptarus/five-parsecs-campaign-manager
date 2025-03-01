## Event Log Test Suite
## Tests the functionality of the campaign event logging system
@tool
extends GameTest

# Type-safe script references
const EventLog := preload("res://src/scenes/campaign/components/EventLog.gd")

# Type-safe instance variables
var _event_log: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	_event_log = EventLog.new()
	add_child(_event_log)
	
	# Initialize the event log
	TypeSafeMixin._call_node_method_bool(_event_log, "initialize", [])
	watch_signals(_event_log)
	
	await stabilize_engine()

func after_each() -> void:
	_event_log = null
	await super.after_each()

# Event Creation Tests
func test_event_creation() -> void:
	watch_signals(_event_log)
	
	var event_data := {
		"type": GameEnums.EventCategory.COMBAT,
		"description": "Test combat event",
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [event_data])
	assert_true(success, "Should add event successfully")
	verify_signal_emitted(_event_log, "event_added")
	
	var events: Array = TypeSafeMixin._call_node_method_array(_event_log, "get_events", [])
	assert_eq(events.size(), 1, "Should have one event")
	assert_eq(events[0].type, GameEnums.EventCategory.COMBAT, "Event type should match")

# Event Filtering Tests
func test_event_filtering() -> void:
	watch_signals(_event_log)
	
	var events := [
		{
			"type": GameEnums.EventCategory.COMBAT,
			"description": "Combat with pirates",
			"timestamp": Time.get_unix_time_from_system() - 3600
		},
		{
			"type": GameEnums.EventCategory.COMBAT,
			"description": "Battle with mercenaries",
			"timestamp": Time.get_unix_time_from_system() - 1800
		},
		{
			"type": GameEnums.EventCategory.EQUIPMENT,
			"description": "Acquired new weapon",
			"timestamp": Time.get_unix_time_from_system() - 900
		}
	]
	
	for event in events:
		TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [event])
	
	# Filter by type
	var combat_events: Array = TypeSafeMixin._call_node_method_array(_event_log, "get_events_by_type", [GameEnums.EventCategory.COMBAT])
	assert_eq(combat_events.size(), 2, "Should have two combat events")
	
	var equipment_events: Array = TypeSafeMixin._call_node_method_array(_event_log, "get_events_by_type", [GameEnums.EventCategory.EQUIPMENT])
	assert_eq(equipment_events.size(), 1, "Should have one equipment event")

# Event Sorting Tests
func test_event_sorting() -> void:
	watch_signals(_event_log)
	
	var events := [
		{
			"type": GameEnums.EventCategory.COMBAT,
			"description": "Old event",
			"timestamp": Time.get_unix_time_from_system() - 3600
		},
		{
			"type": GameEnums.EventCategory.COMBAT,
			"description": "Recent event",
			"timestamp": Time.get_unix_time_from_system()
		}
	]
	
	for event in events:
		TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [event])
	
	var sorted_events: Array = TypeSafeMixin._call_node_method_array(_event_log, "get_sorted_events", [])
	assert_eq(sorted_events[0].description, "Recent event", "Recent event should be first")
	assert_eq(sorted_events[1].description, "Old event", "Old event should be last")

# Event Clearing Tests
func test_event_clearing() -> void:
	watch_signals(_event_log)
	
	var event_data := {
		"type": GameEnums.EventCategory.COMBAT,
		"description": "Test event",
		"timestamp": Time.get_unix_time_from_system()
	}
	TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [event_data])
	
	# Clear events
	TypeSafeMixin._call_node_method_bool(_event_log, "clear_events", [])
	verify_signal_emitted(_event_log, "events_cleared")
	
	var events: Array = TypeSafeMixin._call_node_method_array(_event_log, "get_events", [])
	assert_eq(events.size(), 0, "Should have no events after clearing")

# Event Validation Tests
func test_invalid_event_data() -> void:
	watch_signals(_event_log)
	
	var invalid_event := {
		"type": 999, # Invalid event type
		"description": "Invalid event"
		# Missing timestamp
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [invalid_event])
	assert_false(success, "Should not add invalid event")
	verify_signal_not_emitted(_event_log, "event_added")
	
	# Test null event data
	success = TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [null])
	assert_false(success, "Should not add null event")
	verify_signal_not_emitted(_event_log, "event_added")

# Event Search Tests
func test_event_search() -> void:
	watch_signals(_event_log)
	
	var events := [
		{
			"type": GameEnums.EventCategory.COMBAT,
			"description": "Combat with pirates",
			"timestamp": Time.get_unix_time_from_system() - 3600
		},
		{
			"type": GameEnums.EventCategory.EQUIPMENT,
			"description": "Acquired new weapon",
			"timestamp": Time.get_unix_time_from_system() - 900
		}
	]
	
	for event in events:
		TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [event])
	
	# Search by keyword
	var combat_results: Array = TypeSafeMixin._call_node_method_array(_event_log, "search_events", ["pirates"])
	assert_eq(combat_results.size(), 1, "Should find one event with 'pirates'")
	
	var weapon_results: Array = TypeSafeMixin._call_node_method_array(_event_log, "search_events", ["weapon"])
	assert_eq(weapon_results.size(), 1, "Should find one event with 'weapon'")

# Event Persistence Tests
func test_event_persistence() -> void:
	watch_signals(_event_log)
	
	var event_data := {
		"type": GameEnums.EventCategory.SPECIAL,
		"description": "Test persistence",
		"timestamp": Time.get_unix_time_from_system()
	}
	TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [event_data])
	
	# Save events
	var save_success: bool = TypeSafeMixin._call_node_method_bool(_event_log, "save_events", [])
	assert_true(save_success, "Should save events successfully")
	verify_signal_emitted(_event_log, "events_saved")
	
	# Clear and load events
	TypeSafeMixin._call_node_method_bool(_event_log, "clear_events", [])
	var load_success: bool = TypeSafeMixin._call_node_method_bool(_event_log, "load_events", [])
	assert_true(load_success, "Should load events successfully")
	verify_signal_emitted(_event_log, "events_loaded")
	
	var loaded_events: Array = TypeSafeMixin._call_node_method_array(_event_log, "get_events", [])
	assert_eq(loaded_events.size(), 1, "Should have one event after loading")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_event_log)
	
	var incomplete_event := {
		"type": GameEnums.EventCategory.EQUIPMENT
		# Missing description and timestamp
	}
	
	var success: bool = TypeSafeMixin._call_node_method_bool(_event_log, "add_event", [incomplete_event])
	assert_false(success, "Should not add event with missing fields")
	verify_signal_not_emitted(_event_log, "event_added")
	
	# Test loading from invalid source
	success = TypeSafeMixin._call_node_method_bool(_event_log, "load_events_from_file", ["invalid_path.json"])
	assert_false(success, "Should handle invalid file path gracefully")
	verify_signal_not_emitted(_event_log, "events_loaded")
