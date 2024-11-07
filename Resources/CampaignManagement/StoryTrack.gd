# StoryTrack.gd
class_name StoryTrack
extends Node

signal event_triggered(event: StoryEvent)

var story_clock: StoryClock
var game_state_manager: GameStateManager
var internal_state: GameState
var events: Array[StoryEvent] = []
var current_event_index: int = -1
var mock_game_state: MockGameState

func _init() -> void:
	story_clock = StoryClock.new()

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm
	internal_state = gsm.game_state
	story_clock = StoryClock.new()
	_load_events()
	current_event_index = -1

func _load_events() -> void:
	var file = FileAccess.open("res://Data/story_events.json", FileAccess.READ)
	if file:
		var event_data: Array = JSON.parse_string(file.get_as_text())
		file.close()
		events = event_data.map(func(data): return StoryEvent.new(data))
	else:
		push_error("Failed to load story events file.")

func start_tutorial() -> void:
	current_event_index = 0
	trigger_current_event()

func trigger_current_event() -> void:
	if current_event_index < 0 or current_event_index >= events.size():
		return
	
	var current_event: StoryEvent = events[current_event_index]
	story_clock.set_ticks(current_event.next_event_ticks)
	
	event_triggered.emit(current_event)
	apply_event_effects(current_event)

func apply_event_effects(event: StoryEvent) -> void:
	if not game_state_manager:
		push_error("GameStateManager not initialized")
		return
	
	event.apply_event_effects(game_state_manager)
	event.setup_battle(game_state_manager.combat_manager)
	event.apply_rewards(game_state_manager)

func progress_story(current_phase: GlobalEnums.CampaignPhase) -> void:
	story_clock.count_down(current_phase == GlobalEnums.CampaignPhase.POST_BATTLE)
	if story_clock.is_event_triggered():
		current_event_index += 1
		if current_event_index < events.size():
			trigger_current_event()
		else:
			# Tutorial completed
			var game_state = mock_game_state.get_internal_game_state()
			if game_state is GameStateManager:
				game_state.is_tutorial_active = false
			else:
				push_error("Unexpected game state type")

func serialize() -> Dictionary:
	return {
		"events": events.map(func(event: StoryEvent) -> Dictionary: return event.serialize()),
		"current_event_index": current_event_index,
		"story_clock": story_clock.serialize()
	}

static func deserialize(data: Dictionary) -> StoryTrack:
	var story_track := StoryTrack.new()
	story_track.events = data["events"].map(func(event_data: Dictionary) -> StoryEvent: return StoryEvent.deserialize(event_data))
	story_track.current_event_index = data["current_event_index"]
	story_track.story_clock = StoryClock.deserialize(data["story_clock"])
	return story_track
