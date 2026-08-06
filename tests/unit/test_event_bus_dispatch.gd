extends GdUnitTestSuite
## The event bus must call EVERY live handler, even when stale ones precede them.
##
## THE BUG THIS EXISTS TO PREVENT
## _dispatch_event() called erase() on the array it was iterating:
##
##     for handler in event_subscribers[event_type]:
##         if handler.is_valid(): handler.call(data)
##         else: event_subscribers[event_type].erase(handler)
##
## Godot's Array docs warn against this. Erasing at index 0 shifts every later element
## left while the iterator still advances, so whatever moved INTO the freed slot is
## skipped.
##
## [stale, live] is the NORMAL state after any World Phase re-entry: WorldPhaseController
## parents the bus to /root (WorldPhaseController.gd:187) so it outlives scene changes,
## SceneRouter frees the controller on every navigation (2-3x per campaign turn), and
## the controller had no _exit_tree() to unsubscribe. So dispatch went:
##   i=0 stale -> erase -> array is [live], size 1 -> i advances to 1 -> loop ends.
## The live handler was never called.
##
## The bus is the ONLY path from the phase components to those handlers, so the first
## publish of each event type after re-entry was swallowed — in Automation mode the
## wizard stalled on that step, and _on_job_accepted's npc_tracker.track_patron_interaction()
## silently never ran. This is the family of Turn-2+ World Phase blockers already
## logged in project memory.
##
## gdUnit4 v6.0.3 compatible.

const EventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")

var _calls: Array[String] = []


func before_test() -> void:
	_calls.clear()


func _bus() -> Node:
	var b = EventBus.new()
	add_child(b)
	auto_free(b)
	return b


func _record(tag: String) -> Callable:
	return func(_data): _calls.append(tag)


class Ephemeral extends Node:
	## Stands in for a WorldPhaseController that SceneRouter later frees.
	var sink: Array
	func handle(_data) -> void:
		sink.append("stale")


func _stale_handler(bus: Node, event_type) -> void:
	## Subscribe a handler owned by a node, then free the node — reproducing exactly
	## what SceneRouter.queue_free() leaves behind on the /root-parented bus.
	var owner_node := Ephemeral.new()
	owner_node.sink = _calls
	add_child(owner_node)
	bus.subscribe_to_event(event_type, owner_node.handle)
	remove_child(owner_node)
	owner_node.free()  # immediate, not queued — the Callable is now invalid


func test_a_live_handler_after_a_stale_one_is_still_called() -> void:
	# The exact production ordering, and the exact case the old loop skipped.
	var bus := _bus()
	var evt = EventBus.TurnEvent.CREW_TASK_RESOLVED

	_stale_handler(bus, evt)
	bus.subscribe_to_event(evt, _record("live"))

	bus._dispatch_event(evt, {})

	assert_array(_calls).override_failure_message(
		"the live handler was skipped — erase-during-iteration is back"
	).contains(["live"])


func test_several_stale_handlers_do_not_hide_the_live_one() -> void:
	# Multiple frees between visits: consecutive erases skip more than one element.
	var bus := _bus()
	var evt = EventBus.TurnEvent.JOB_ACCEPTED

	for i in 3:
		_stale_handler(bus, evt)
	bus.subscribe_to_event(evt, _record("live"))

	bus._dispatch_event(evt, {})

	assert_array(_calls).contains(["live"])


func test_every_live_handler_is_called_once() -> void:
	var bus := _bus()
	var evt = EventBus.TurnEvent.MISSION_PREPARED

	bus.subscribe_to_event(evt, _record("a"))
	_stale_handler(bus, evt)
	bus.subscribe_to_event(evt, _record("b"))

	bus._dispatch_event(evt, {})

	assert_int(_calls.count("a")).is_equal(1)
	assert_int(_calls.count("b")).is_equal(1)


func test_stale_handlers_are_pruned_so_they_do_not_accumulate() -> void:
	# Without cleanup the list grew ~3 dead Callables per turn (~300 by turn 100).
	var bus := _bus()
	var evt = EventBus.TurnEvent.PHASE_COMPLETED

	_stale_handler(bus, evt)
	_stale_handler(bus, evt)
	bus.subscribe_to_event(evt, _record("live"))
	bus._dispatch_event(evt, {})

	var remaining: Array = bus.event_subscribers.get(evt, [])
	assert_int(remaining.size()).override_failure_message(
		"stale handlers survived dispatch: %d still registered" % remaining.size()
	).is_equal(1)


func test_dispatch_with_no_subscribers_is_a_no_op() -> void:
	var bus := _bus()
	bus._dispatch_event(EventBus.TurnEvent.PHASE_TRANSITION_REQUESTED, {})
	assert_array(_calls).is_empty()
