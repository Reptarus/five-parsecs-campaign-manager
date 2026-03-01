extends Node

## CampaignTurnEventBus
##
## Production Event Bus for Campaign Turn Workflow.
## Centralizes and type-safes campaign turn progression and events, replacing dozens of scattered signals.
## Monitors, debugs, and routes all campaign turn state changes.
## 
## See docs/events/campaign_turn_event_bus.md for usage and event flow examples.


# Event types covering all campaign turn workflow needs
enum TurnEvent {
	# Phase Management
	PHASE_STARTED,
	PHASE_COMPLETED,
	PHASE_TRANSITION_REQUESTED,
	
	# Upkeep Phase Events
	UPKEEP_STARTED,
	UPKEEP_COMPLETED,
	UPKEEP_ERROR,
	
	# Crew Task Events
	CREW_TASK_STARTED,
	CREW_TASK_ASSIGNED,
	CREW_TASK_RESOLVED,
	CREW_TASK_FAILED,
	
	# Job System Events
	JOB_OFFERS_GENERATED,
	JOB_OFFER_SELECTED,
	JOB_ACCEPTED,
	JOB_REJECTED,
	JOB_VALIDATION_STARTED,
	JOB_VALIDATION_COMPLETED,
	
	# Mission Preparation Events
	MISSION_PREP_STARTED,
	MISSION_PREPARED,
	MISSION_VALIDATION_FAILED,
	
	# Automation Events
	AUTOMATION_TOGGLED,
	AUTOMATION_STEP_COMPLETED,
	
	# Real-time Feedback Events
	PROGRESS_UPDATED,
	NOTIFICATION_DISPLAYED,
	CRITICAL_EVENT_HIGHLIGHTED,
	
	# Backend Integration Events
	BACKEND_OPERATION_STARTED,
	BACKEND_OPERATION_COMPLETED,
	BACKEND_ERROR_OCCURRED
}

# Central event signal - all events flow through this
signal turn_event_published(event_type: TurnEvent, data: Dictionary)

# Event monitoring and debugging
var event_history: Array[Dictionary] = []
var max_history_size: int = 100
var debug_mode: bool = false
var event_subscribers: Dictionary = {} # TurnEvent -> Array[Callable]

func _ready() -> void:
	name = "CampaignTurnEventBus"
	print("CampaignTurnEventBus: Initialized - replacing signal hell with type-safe events")

## Public API: Publish events
func publish_event(event_type: TurnEvent, data: Dictionary = {}) -> void:
	## Publish a campaign turn event with optional data payload
	var event_name = TurnEvent.keys()[event_type]
	
	if debug_mode:
		print("CampaignTurnEventBus: Publishing %s with data: %s" % [event_name, data])
	
	# Store event in history for debugging
	var event_record = {
		"timestamp": Time.get_unix_time_from_system(),
		"event_type": event_type,
		"event_name": event_name,
		"data": data.duplicate()
	}
	
	_add_to_history(event_record)
	
	# Emit the event
	turn_event_published.emit(event_type, data)

## Public API: Subscribe to specific event types
func subscribe_to_event(event_type: TurnEvent, handler: Callable) -> void:
	## Subscribe a handler to a specific event type
	if not event_subscribers.has(event_type):
		event_subscribers[event_type] = []
	
	if not event_subscribers[event_type].has(handler):
		event_subscribers[event_type].append(handler)
		
		# Connect to main signal if first subscriber for this event type
		if not turn_event_published.is_connected(_dispatch_event):
			turn_event_published.connect(_dispatch_event)
		
		if debug_mode:
			print("CampaignTurnEventBus: Subscribed handler to %s" % TurnEvent.keys()[event_type])

## Public API: Unsubscribe from events
func unsubscribe_from_event(event_type: TurnEvent, handler: Callable) -> void:
	## Unsubscribe a handler from a specific event type
	if event_subscribers.has(event_type):
		event_subscribers[event_type].erase(handler)
		
		if debug_mode:
			print("CampaignTurnEventBus: Unsubscribed handler from %s" % TurnEvent.keys()[event_type])

## Event Dispatcher - routes events to specific handlers
func _dispatch_event(event_type: TurnEvent, data: Dictionary) -> void:
	## Internal dispatcher - routes events to subscribed handlers
	if event_subscribers.has(event_type):
		for handler in event_subscribers[event_type]:
			if handler.is_valid():
				handler.call(data)
			else:
				# Clean up invalid handlers
				event_subscribers[event_type].erase(handler)

## Debugging and Monitoring
func enable_debug_mode(enabled: bool = true) -> void:
	## Enable debug mode for event monitoring
	debug_mode = enabled
	print("CampaignTurnEventBus: Debug mode %s" % ("enabled" if enabled else "disabled"))

func get_event_history() -> Array[Dictionary]:
	## Get event history for debugging
	return event_history.duplicate()

func get_recent_events(count: int = 10) -> Array[Dictionary]:
	## Get most recent events
	var start_index = max(0, event_history.size() - count)
	return event_history.slice(start_index)

func clear_event_history() -> void:
	## Clear event history
	event_history.clear()
	print("CampaignTurnEventBus: Event history cleared")

## Convenience Methods for Common Events
func publish_upkeep_completed(upkeep_data: Dictionary) -> void:
	## Convenience method for upkeep completion
	publish_event(TurnEvent.UPKEEP_COMPLETED, upkeep_data)

func publish_crew_task_resolved(crew_id: String, task_result: Dictionary) -> void:
	## Convenience method for crew task resolution
	publish_event(TurnEvent.CREW_TASK_RESOLVED, {
		"crew_id": crew_id,
		"result": task_result
	})

func publish_job_accepted(job_id: String, job_data: Dictionary) -> void:
	## Convenience method for job acceptance
	publish_event(TurnEvent.JOB_ACCEPTED, {
		"job_id": job_id,
		"job_data": job_data
	})

func publish_mission_prepared(mission_data: Dictionary) -> void:
	## Convenience method for mission preparation
	publish_event(TurnEvent.MISSION_PREPARED, mission_data)

## Helper Methods
func _add_to_history(event_record: Dictionary) -> void:
	## Add event to history with size management
	event_history.append(event_record)
	
	# Maintain history size limit
	if event_history.size() > max_history_size:
		event_history.pop_front()