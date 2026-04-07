class_name FPCM_StoryMissionLoader
extends RefCounted

## Story Mission Loader — loads Story Track event JSONs from
## data/story_track_missions/ and converts them to StoryEvent resources.
## Core Rules Appendix V pp.153-160.

const STORY_MISSIONS_PATH := "res://data/story_track_missions/"

## Event ID → filename mapping (7 events, sequential)
const EVENT_FILE_MAP := {
	"foiled": "event_01_foiled",
	"on_the_trail": "event_02_on_the_trail",
	"disrupting_the_plan": "event_03_disrupting_the_plan",
	"enemy_strikes_back": "event_04_enemy_strikes_back",
	"kidnap": "event_05_kidnap",
	"were_coming": "event_06_were_coming",
	"time_to_settle_this": "event_07_time_to_settle_this",
}

## Ordered event IDs (matches Core Rules event sequence)
const EVENT_SEQUENCE: Array[String] = [
	"foiled",
	"on_the_trail",
	"disrupting_the_plan",
	"enemy_strikes_back",
	"kidnap",
	"were_coming",
	"time_to_settle_this",
]

## Cache for loaded events
var _event_cache: Dictionary = {}


## Load a single story event by its event ID. Returns null on failure.
func load_event(event_id: String) -> StoryEvent:
	if _event_cache.has(event_id):
		return _event_cache[event_id]

	var file_name: String = EVENT_FILE_MAP.get(event_id, "")
	if file_name.is_empty():
		push_error("StoryMissionLoader: Unknown event_id '%s'" % event_id)
		return null

	var file_path := STORY_MISSIONS_PATH + file_name + ".json"
	var data := _load_json(file_path)
	if data.is_empty():
		return null

	var event := StoryEvent.new()
	event.load_from_json(data)
	_event_cache[event_id] = event
	return event


## Load event by sequence number (1-7)
func load_event_by_number(number: int) -> StoryEvent:
	if number < 1 or number > EVENT_SEQUENCE.size():
		push_error("StoryMissionLoader: Invalid event number %d" % number)
		return null
	return load_event(EVENT_SEQUENCE[number - 1])


## Load all 7 story events in order. Returns array of StoryEvent.
func load_all_events() -> Array[StoryEvent]:
	var events: Array[StoryEvent] = []
	for event_id: String in EVENT_SEQUENCE:
		var event: StoryEvent = load_event(event_id)
		if event:
			events.append(event)
		else:
			push_warning(
				"StoryMissionLoader: Failed to load event '%s'" % event_id)
	return events


## Get the next event after the given event_id. Returns null if final.
func get_next_event(current_event_id: String) -> StoryEvent:
	var idx: int = EVENT_SEQUENCE.find(current_event_id)
	if idx == -1 or idx + 1 >= EVENT_SEQUENCE.size():
		return null
	return load_event(EVENT_SEQUENCE[idx + 1])


## Check if an event_id is valid
func has_event(event_id: String) -> bool:
	return EVENT_FILE_MAP.has(event_id)


## Get total event count
func get_total_event_count() -> int:
	return EVENT_SEQUENCE.size()


## Check if event is the final Story Track event
func is_final_event(event_id: String) -> bool:
	return event_id == EVENT_SEQUENCE[-1]


## Clear the cache (for testing or reload)
func clear_cache() -> void:
	_event_cache.clear()


## Load and parse a JSON file. Returns empty Dictionary on failure.
func _load_json(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("StoryMissionLoader: Cannot open '%s'" % file_path)
		return {}

	var text := file.get_as_text()
	file.close()

	if text.is_empty():
		push_error("StoryMissionLoader: Empty file '%s'" % file_path)
		return {}

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("StoryMissionLoader: Invalid JSON in '%s'" % file_path)
		return {}

	return parsed
