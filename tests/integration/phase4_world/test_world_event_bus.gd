extends GdUnitTestSuite
## Phase 4: World Phase Integration Tests - Part 1: Event Bus
## Tests CampaignTurnEventBus publish/subscribe mechanics for world phase events
## gdUnit4 v6.0.1 compatible (UI mode required)
## HIGH BUG DISCOVERY PROBABILITY - Event system foundation

# System under test
var EventBusClass
var event_bus = null

# Test helper
var HelperClass
var helper = null

# Event tracking
var received_events: Array = []
var event_handler_called: bool = false

func before():
	"""Suite-level setup - runs once before all tests"""
	EventBusClass = load("res://src/core/events/CampaignTurnEventBus.gd")
	HelperClass = load("res://tests/helpers/WorldPhaseTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh event bus for each test"""
	event_bus = auto_free(helper.create_test_event_bus())
	received_events.clear()
	event_handler_called = false

func after_test():
	"""Test-level cleanup"""
	helper.clear_event_history(event_bus)
	event_bus = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	EventBusClass = null

# ============================================================================
# Event Subscription Tests (3 tests)
# ============================================================================

func test_subscribe_to_world_phase_events():
	"""Can subscribe handler to world phase event types"""
	var handler = func(_event_type, _data): event_handler_called = true

	# Subscribe to UPKEEP_COMPLETED event
	event_bus.subscribe_to_event(EventBusClass.TurnEvent.UPKEEP_COMPLETED, handler)

	# Verify subscription registered
	var subscriber_count = helper.count_event_subscribers(
		event_bus,
		EventBusClass.TurnEvent.UPKEEP_COMPLETED
	)

	assert_that(subscriber_count).is_equal(1)

func test_unsubscribe_from_events():
	"""Can unsubscribe handler from events"""
	var handler = func(_event_type, _data): event_handler_called = true

	# Subscribe then unsubscribe
	event_bus.subscribe_to_event(EventBusClass.TurnEvent.JOB_ACCEPTED, handler)
	event_bus.unsubscribe_from_event(EventBusClass.TurnEvent.JOB_ACCEPTED, handler)

	# Verify subscription removed
	var subscriber_count = helper.count_event_subscribers(
		event_bus,
		EventBusClass.TurnEvent.JOB_ACCEPTED
	)

	assert_that(subscriber_count).is_equal(0)

func test_multiple_subscribers_same_event():
	"""Multiple handlers can subscribe to same event type"""
	var handler1 = func(_event_type, _data): pass
	var handler2 = func(_event_type, _data): pass
	var handler3 = func(_event_type, _data): pass

	# Subscribe multiple handlers to MISSION_PREPARED
	event_bus.subscribe_to_event(EventBusClass.TurnEvent.MISSION_PREPARED, handler1)
	event_bus.subscribe_to_event(EventBusClass.TurnEvent.MISSION_PREPARED, handler2)
	event_bus.subscribe_to_event(EventBusClass.TurnEvent.MISSION_PREPARED, handler3)

	var subscriber_count = helper.count_event_subscribers(
		event_bus,
		EventBusClass.TurnEvent.MISSION_PREPARED
	)

	assert_that(subscriber_count).is_equal(3)

# ============================================================================
# Event Publishing Tests (4 tests)
# ============================================================================

func test_publish_upkeep_completed_event():
	"""Publishing UPKEEP_COMPLETED event stores in history"""
	var upkeep_data = {"credits_spent": 6, "fuel_consumed": 2}

	event_bus.publish_event(EventBusClass.TurnEvent.UPKEEP_COMPLETED, upkeep_data)

	# Check event appears in history
	var events = helper.get_published_events(event_bus, EventBusClass.TurnEvent.UPKEEP_COMPLETED)

	assert_that(events.size()).is_equal(1)
	assert_that(events[0]["event_type"]).is_equal(EventBusClass.TurnEvent.UPKEEP_COMPLETED)
	assert_that(events[0]["data"]["credits_spent"]).is_equal(6)

func test_publish_job_accepted_event():
	"""Publishing JOB_ACCEPTED event includes job data payload"""
	var job_data = helper.create_mock_job_data("job_001", "Test Patron", 5, 2)

	event_bus.publish_event(EventBusClass.TurnEvent.JOB_ACCEPTED, {"job_data": job_data})

	var events = helper.get_published_events(event_bus, EventBusClass.TurnEvent.JOB_ACCEPTED)

	assert_that(events.size()).is_equal(1)
	assert_that(events[0]["data"]["job_data"]["id"]).is_equal("job_001")
	assert_that(events[0]["data"]["job_data"]["pay"]).is_equal(5)

func test_publish_mission_prepared_event():
	"""Publishing MISSION_PREPARED event includes crew assignments"""
	var assignments = {
		"crew_001": ["weapon_001", "armor_001"],
		"crew_002": ["weapon_002"]
	}

	event_bus.publish_event(
		EventBusClass.TurnEvent.MISSION_PREPARED,
		{"crew_assignments": assignments}
	)

	var events = helper.get_published_events(event_bus, EventBusClass.TurnEvent.MISSION_PREPARED)

	assert_that(events.size()).is_equal(1)
	assert_that(events[0]["data"]["crew_assignments"].has("crew_001")).is_true()
	assert_that(events[0]["data"]["crew_assignments"]["crew_001"].size()).is_equal(2)

func test_publish_phase_transition_event():
	"""Publishing PHASE_TRANSITION_REQUESTED includes phase data"""
	var transition_data = {
		"from_phase": "world_phase",
		"to_phase": "battle_phase",
		"world_results": {"job_accepted": true}
	}

	event_bus.publish_event(
		EventBusClass.TurnEvent.PHASE_TRANSITION_REQUESTED,
		transition_data
	)

	var events = helper.get_published_events(
		event_bus,
		EventBusClass.TurnEvent.PHASE_TRANSITION_REQUESTED
	)

	assert_that(events.size()).is_equal(1)
	assert_that(events[0]["data"]["from_phase"]).is_equal("world_phase")
	assert_that(events[0]["data"]["to_phase"]).is_equal("battle_phase")

# ============================================================================
# Event History & Debugging Tests (3 tests)
# ============================================================================

func test_event_history_tracking():
	"""Events stored in history (max 100 limit)"""
	# Publish 5 different events
	event_bus.publish_event(EventBusClass.TurnEvent.UPKEEP_STARTED, {})
	event_bus.publish_event(EventBusClass.TurnEvent.UPKEEP_COMPLETED, {})
	event_bus.publish_event(EventBusClass.TurnEvent.CREW_TASK_STARTED, {})
	event_bus.publish_event(EventBusClass.TurnEvent.JOB_OFFERS_GENERATED, {})
	event_bus.publish_event(EventBusClass.TurnEvent.MISSION_PREP_STARTED, {})

	# Get all events (no type filter)
	var all_events = helper.get_published_events(event_bus)

	assert_that(all_events.size()).is_equal(5)
	# Each event should have required fields
	for event in all_events:
		assert_that(event.has("timestamp")).is_true()
		assert_that(event.has("event_type")).is_true()
		assert_that(event.has("event_name")).is_true()
		assert_that(event.has("data")).is_true()

func test_get_recent_events():
	"""Can retrieve recent event history filtered by type"""
	# Publish mix of events
	event_bus.publish_event(EventBusClass.TurnEvent.UPKEEP_COMPLETED, {"test": 1})
	event_bus.publish_event(EventBusClass.TurnEvent.JOB_ACCEPTED, {"test": 2})
	event_bus.publish_event(EventBusClass.TurnEvent.UPKEEP_COMPLETED, {"test": 3})
	event_bus.publish_event(EventBusClass.TurnEvent.MISSION_PREPARED, {"test": 4})

	# Get only UPKEEP_COMPLETED events
	var upkeep_events = helper.get_published_events(
		event_bus,
		EventBusClass.TurnEvent.UPKEEP_COMPLETED
	)

	assert_that(upkeep_events.size()).is_equal(2)
	assert_that(upkeep_events[0]["data"]["test"]).is_equal(1)
	assert_that(upkeep_events[1]["data"]["test"]).is_equal(3)

func test_debug_mode_logging():
	"""Debug mode enabled shows event publication details"""
	# Enable debug mode
	event_bus.debug_mode = true

	# Publish event (should log to console)
	event_bus.publish_event(EventBusClass.TurnEvent.JOB_ACCEPTED, {"job_id": "test_job"})

	# Verify debug mode flag
	assert_that(event_bus.debug_mode).is_true()

	# Verify event still published correctly
	var events = helper.get_published_events(event_bus, EventBusClass.TurnEvent.JOB_ACCEPTED)
	assert_that(events.size()).is_equal(1)
