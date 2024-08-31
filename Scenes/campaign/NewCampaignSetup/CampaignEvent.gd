extends Node

signal event_occurred(event: Event)

var events: Array[Event] = []

func _ready() -> void:
	_load_events()

func trigger_random_event() -> void:
	if events.is_empty():
		print("Error: No events available.")
		return

	var random_event: Event = events[randi() % events.size()]
	event_occurred.emit(random_event)

func _load_events() -> void:
	# Placeholder for loading events from a file or database
	var event1 = Event.new()
	event1.title = "Unexpected Delay"
	event1.description = "Your ship encounters a meteor storm, causing a delay in your journey."
	events.append(event1)

	var event2 = Event.new()
	event2.title = "Lucky Find"
	event2.description = "While exploring, you stumble upon a cache of valuable resources."
	events.append(event2)

class Event:
	var title: String
	var description: String
