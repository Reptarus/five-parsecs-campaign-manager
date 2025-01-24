extends "res://addons/gut/test.gd"

const EventLog = preload("res://src/scenes/campaign/components/EventLog.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var log: EventLog
var event_added_signal_emitted := false
var event_cleared_signal_emitted := false
var last_event_data: EventLog.EventData

func before_each() -> void:
	log = EventLog.new()
	add_child(log)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	log.queue_free()

func _reset_signals() -> void:
	event_added_signal_emitted = false
	event_cleared_signal_emitted = false
	last_event_data = null

func _connect_signals() -> void:
	log.event_added.connect(_on_event_added)
	log.events_cleared.connect(_on_events_cleared)

func _on_event_added(event_data: EventLog.EventData) -> void:
	event_added_signal_emitted = true
	last_event_data = event_data

func _on_events_cleared() -> void:
	event_cleared_signal_emitted = true

func test_initial_setup() -> void:
	assert_not_null(log)
	assert_not_null(log.event_list)
	assert_eq(log.get_event_count(), 0)

func test_add_event() -> void:
	var test_event = EventLog.EventData.new(
		"Test Event",
		"Test event description",
		"test",
		"test_phase",
		EventLog.EventPriority.NORMAL
	)
	
	log.add_event(test_event)
	
	assert_true(event_added_signal_emitted)
	assert_eq(last_event_data.title, test_event.title)
	assert_eq(last_event_data.description, test_event.description)
	assert_eq(log.get_event_count(), 1)

func test_clear_events() -> void:
	# Add some test events first
	var test_events = [
		EventLog.EventData.new("Test 1", "Description 1", "test", "test_phase"),
		EventLog.EventData.new("Test 2", "Description 2", "test", "test_phase")
	]
	
	for event in test_events:
		log.add_event(event)
	
	log.clear()
	
	assert_true(event_cleared_signal_emitted)
	assert_eq(log.get_event_count(), 0)

func test_event_filtering() -> void:
	var test_events = [
		EventLog.EventData.new("Combat Event", "Combat description", "combat", "test_phase"),
		EventLog.EventData.new("Story Event", "Story description", "story", "test_phase")
	]
	
	for event in test_events:
		log.add_event(event)
	
	var combat_events = log.get_events_by_category("combat")
	var story_events = log.get_events_by_category("story")
	
	assert_eq(combat_events.size(), 1)
	assert_eq(story_events.size(), 1)
	assert_true(combat_events[0].title == "Combat Event")
	assert_true(story_events[0].title == "Story Event")

func test_event_sorting() -> void:
	var first_event = EventLog.EventData.new(
		"First Event",
		"First description",
		"test",
		"test_phase"
	)
	first_event.timestamp = 1000
	
	var second_event = EventLog.EventData.new(
		"Second Event",
		"Second description",
		"test",
		"test_phase"
	)
	second_event.timestamp = 2000
	
	log.add_event(first_event)
	log.add_event(second_event)
	
	var events = log.get_all_events()
	assert_eq(events.size(), 2)
	assert_eq(events[0].timestamp, 2000) # Most recent first
	assert_eq(events[1].timestamp, 1000)

func test_invalid_event_handling() -> void:
	var invalid_event = EventLog.EventData.new(
		"", # Invalid empty title
		"Description",
		"test",
		"test_phase"
	)
	
	log.add_event(invalid_event)
	
	assert_false(event_added_signal_emitted)
	assert_eq(log.get_event_count(), 0)

func test_duplicate_event_handling() -> void:
	var test_event = EventLog.EventData.new(
		"Duplicate Event",
		"Test description",
		"test",
		"test_phase"
	)
	
	log.add_event(test_event)
	_reset_signals()
	log.add_event(test_event) # Try to add the same event again
	
	assert_false(event_added_signal_emitted) # Should not emit signal for duplicate
	assert_eq(log.get_event_count(), 1) # Should still only have one event

func test_event_limit() -> void:
	# Add more events than the maximum limit
	for i in range(log.max_events + 5):
		var event = EventLog.EventData.new(
			"Event %d" % i,
			"Description %d" % i,
			"test",
			"test_phase"
		)
		event.timestamp = Time.get_unix_time_from_system() + i
		log.add_event(event)
	
	assert_eq(log.get_event_count(), log.max_events)
	var events = log.get_all_events()
	assert_true(events[0].title.begins_with("Event %d" % (log.max_events + 4)))