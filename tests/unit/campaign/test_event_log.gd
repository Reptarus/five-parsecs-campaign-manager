@tool
extends "res://tests/fixtures/game_test.gd"

const EventLog = preload("res://src/scenes/campaign/components/EventLog.gd")

var log: EventLog

func before_each() -> void:
	await super.before_each()
	log = EventLog.new()
	add_child_autofree(log)
	watch_signals(log)
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	log = null

func test_initial_setup() -> void:
	assert_not_null(log, "Event log should be initialized")
	assert_not_null(log.event_list, "Event list should be initialized")
	assert_eq(log.get_event_count(), 0, "Event count should start at 0")

func test_add_event() -> void:
	var test_event = EventLog.EventData.new(
		"Test Event",
		"Test event description",
		"test",
		"test_phase",
		EventLog.EventPriority.NORMAL
	)
	
	log.add_event(test_event)
	
	var event_added = await assert_async_signal(log, "event_added")
	assert_true(event_added, "Event added signal should be emitted")
	
	# Get signal data
	var signal_data = await wait_for_signal(log, "event_added")
	var event_data = signal_data[0]
	assert_eq(event_data.title, test_event.title, "Event title should match")
	assert_eq(event_data.description, test_event.description, "Event description should match")
	assert_eq(log.get_event_count(), 1, "Event count should be 1")

func test_clear_events() -> void:
	# Add some test events first
	var test_events = [
		EventLog.EventData.new("Test 1", "Description 1", "test", "test_phase"),
		EventLog.EventData.new("Test 2", "Description 2", "test", "test_phase")
	]
	
	for event in test_events:
		log.add_event(event)
		var event_added = await assert_async_signal(log, "event_added")
		assert_true(event_added, "Event added signal should be emitted")
	
	log.clear()
	var events_cleared = await assert_async_signal(log, "events_cleared")
	assert_true(events_cleared, "Events cleared signal should be emitted")
	assert_eq(log.get_event_count(), 0, "Event count should be 0 after clear")

func test_event_filtering() -> void:
	var test_events = [
		EventLog.EventData.new("Combat Event", "Combat description", "combat", "test_phase"),
		EventLog.EventData.new("Story Event", "Story description", "story", "test_phase")
	]
	
	for event in test_events:
		log.add_event(event)
		var event_added = await assert_async_signal(log, "event_added")
		assert_true(event_added, "Event added signal should be emitted")
	
	var combat_events = log.get_events_by_category("combat")
	var story_events = log.get_events_by_category("story")
	
	assert_eq(combat_events.size(), 1, "Should have one combat event")
	assert_eq(story_events.size(), 1, "Should have one story event")
	assert_eq(combat_events[0].title, "Combat Event", "Combat event title should match")
	assert_eq(story_events[0].title, "Story Event", "Story event title should match")

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
	var first_added = await assert_async_signal(log, "event_added")
	assert_true(first_added, "First event added signal should be emitted")
	
	log.add_event(second_event)
	var second_added = await assert_async_signal(log, "event_added")
	assert_true(second_added, "Second event added signal should be emitted")
	
	var events = log.get_all_events()
	assert_eq(events.size(), 2, "Should have two events")
	assert_eq(events[0].timestamp, 2000, "Most recent event should be first")
	assert_eq(events[1].timestamp, 1000, "Older event should be second")

func test_invalid_event_handling() -> void:
	var invalid_event = EventLog.EventData.new(
		"", # Invalid empty title
		"Description",
		"test",
		"test_phase"
	)
	
	log.add_event(invalid_event)
	
	var event_added = await assert_async_signal(log, "event_added", 0.5) # Short timeout since we expect no signal
	assert_false(event_added, "Event added signal should not be emitted for invalid event")
	assert_eq(log.get_event_count(), 0, "Invalid event should not be added")

func test_duplicate_event_handling() -> void:
	var test_event = EventLog.EventData.new(
		"Duplicate Event",
		"Test description",
		"test",
		"test_phase"
	)
	
	log.add_event(test_event)
	var first_added = await assert_async_signal(log, "event_added")
	assert_true(first_added, "First event added signal should be emitted")
	
	log.add_event(test_event) # Try to add the same event again
	var duplicate_added = await assert_async_signal(log, "event_added", 0.5) # Short timeout since we expect no signal
	assert_false(duplicate_added, "Event added signal should not be emitted for duplicate")
	assert_eq(log.get_event_count(), 1, "Should still only have one event")

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
		var event_added = await assert_async_signal(log, "event_added")
		assert_true(event_added, "Event added signal should be emitted")
	
	assert_eq(log.get_event_count(), log.max_events, "Event count should not exceed max limit")
	var events = log.get_all_events()
	assert_true(events[0].title.begins_with("Event %d" % (log.max_events + 4)),
		"Most recent event should be at the top")
