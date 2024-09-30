# StoryTrack.gd
class_name StoryTrack
extends Resource

signal event_triggered(event: StoryEvent)

var story_clock: StoryClock
var story_track_manager: StoryTrackManager
var events: Array[StoryEvent] = []
var current_event_index: int = -1

func _init() -> void:
	story_clock = StoryClock.new()

func initialize(game_state: GameStateManagerNode) -> void:
	story_clock = StoryClock.new()
	story_track_manager = StoryTrackManager.new(game_state)
	_load_events()
	current_event_index = -1

func _load_events() -> void:
	# Load events from a JSON file or create them manually
	var event_data: Array[Dictionary] = [
		{
			"event_id": "foiled",
			"description": "Foiled! Your old rival O'Narr has struck again...",
			"campaign_turn_modifications": {
				"add_rival": "O'Narr",
				"set_forced_action": "look_for_patron"
			},
			"battle_setup": {
				"set_enemy_type": "rival_gang",
				"set_battlefield_size": Vector2i(48, 48)
			},
			"rewards": {
				"add_credits": 5,
				"add_story_points": 1
			},
			"next_event_ticks": 3
		},
		# Add more events here
	]
	
	events = event_data.map(func(data): return StoryEvent.new(data))

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
	var game_state: GameStateManagerNode = GameState
	event.apply_event_effects(game_state)
	event.setup_battle(game_state.current_battle)
	event.apply_rewards(game_state)

func progress_story(current_phase: GlobalEnums.CampaignPhase) -> void:
	var game_state: GameStateManagerNode = GameState
	story_clock.count_down(current_phase == GlobalEnums.CampaignPhase.POST_BATTLE)
	if story_clock.is_event_triggered():
		current_event_index += 1
		if current_event_index < events.size():
			trigger_current_event()
		else:
			# Tutorial completed
			game_state.end_tutorial()

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
