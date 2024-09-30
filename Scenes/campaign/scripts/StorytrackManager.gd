# StoryTrackManager.gd
class_name StoryTrackManager
extends Node

signal story_event_triggered(event: Dictionary)
signal story_track_advanced(new_position: int)

var game_state: GameState
var story_track_position: int = 0
var story_events: Array = []
var tutorial_mission_track: Array = []

func _init(_game_state: GameState):
	game_state = _game_state
	load_story_events()
	load_tutorial_mission_track()

func load_story_events() -> void:
	var file = FileAccess.open("res://Data/story_events.json", FileAccess.READ)
	if file:
		story_events = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		push_error("Failed to load story events file.")

func load_tutorial_mission_track() -> void:
	tutorial_mission_track = [
		{
			"title": "First Steps",
			"description": "Learn the basics of crew management and navigation.",
			"objective": "Complete your first patrol mission."
		},
		{
			"title": "Market Dealings",
			"description": "Visit a local market to buy equipment and hire crew.",
			"objective": "Purchase one item and recruit one new crew member."
		},
		{
			"title": "Rival Encounter",
			"description": "Face your first rival in combat.",
			"objective": "Defeat a rival crew in battle."
		},
		{
			"title": "Patron Job",
			"description": "Accept and complete a job from a patron.",
			"objective": "Successfully complete a patron mission."
		},
		{
			"title": "Fringe World Strife",
			"description": "Navigate the dangers of a fringe world in conflict.",
			"objective": "Resolve a fringe world strife event."
		}
	]

func advance_story_track() -> void:
	story_track_position += 1
	if story_track_position < story_events.size():
		trigger_story_event(story_events[story_track_position])
	story_track_advanced.emit(story_track_position)

func trigger_story_event(event: Dictionary) -> void:
	match event.type:
		GlobalEnums.Type.OPPORTUNITY:
			game_state.add_opportunity(event)
		GlobalEnums.Type.PATRON:
			game_state.add_patron_job(event)
		GlobalEnums.Type.QUEST:
			game_state.add_quest(event)
		GlobalEnums.Type.RIVAL:
			game_state.add_rival(event)
		_:
			push_warning("Unknown story event type: " + str(event.type))
	
	story_event_triggered.emit(event)

func get_current_story_progress() -> float:
	return float(story_track_position) / story_events.size()

func get_next_tutorial_mission() -> Dictionary:
	if tutorial_mission_track.is_empty():
		return {}
	return tutorial_mission_track.pop_front()

func is_tutorial_complete() -> bool:
	return tutorial_mission_track.is_empty()

func roll_for_story_advancement() -> void:
	var roll = game_state.roll_dice(4, 6)
	var advancement = roll.count(6)
	for i in range(advancement):
		advance_story_track()

func check_story_track_effects() -> void:
	var current_event = story_events[story_track_position]
	if "effect" in current_event:
		match current_event.effect:
			"add_credits":
				game_state.add_credits(current_event.amount)
			"remove_credits":
				game_state.remove_credits(current_event.amount)
			"add_item":
				game_state.add_to_ship_stash(current_event.item)
			"remove_item":
				game_state.remove_from_ship_stash(current_event.item)
			"change_reputation":
				game_state.change_reputation(current_event.faction, current_event.amount)
			_:
				push_warning("Unknown story effect: " + current_event.effect)

func handle_story_point() -> void:
	roll_for_story_advancement()
	check_story_track_effects()
	if not is_tutorial_complete():
		var next_tutorial = get_next_tutorial_mission()
		game_state.add_mission(next_tutorial)
