# StoryTrackManager.gd
class_name StoryTrackManager
extends Node

var game_state: GameState
var story_track_position: int = 0
var story_events: Array = []

func _init(_game_state: GameState):
	game_state = _game_state
	load_story_events()

func load_story_events():
	# Load story events from a file or define them here
	story_events = [
		{"title": "Mysterious Signal", "description": "You receive a cryptic transmission from deep space."},
		{"title": "Ancient Artifact", "description": "Your crew uncovers an artifact of unknown origin."},
		{"title": "Corporate Intrigue", "description": "A megacorp offers a lucrative but dangerous contract."},
		# Add more story events...
	]

func advance_story_track() -> void:
	story_track_position += 1
	if story_track_position < story_events.size():
		trigger_story_event(story_events[story_track_position])

func trigger_story_event(event: Dictionary) -> void:
	# Implement the logic for triggering a story event
	print("Story Event: " + event["title"])
	print(event["description"])
	# This could involve adding a special mission, changing game state, etc.

func get_current_story_progress() -> float:
	return float(story_track_position) / story_events.size()
