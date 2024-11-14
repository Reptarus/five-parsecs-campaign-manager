# StoryTrack.gd
class_name StoryTrack
extends Node

signal event_triggered(event: StoryEvent)
signal story_point_added(total: int)
signal story_point_spent(total: int)
signal story_milestone_reached(milestone: int)

const StoryClock = preload("res://Resources/CampaignManagement/StoryClock.gd")
const StoryEvent = preload("res://Resources/CampaignManagement/StoryEvent.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

var story_clock: StoryClock
var game_state_manager: GameStateManager
var internal_state: GameState
var events: Array[StoryEvent] = []
var current_event_index: int = -1
var story_points: int = 0
var milestones_reached: Array[int] = []

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

func progress_story(phase: GlobalEnums.CampaignPhase) -> void:
	match phase:
		GlobalEnums.CampaignPhase.UPKEEP:
			# Handle upkeep phase
			pass
		GlobalEnums.CampaignPhase.BATTLE:
			# Handle battle phase
			pass

func add_story_point() -> void:
	story_points += 1
	story_point_added.emit(story_points)
	check_milestones()

func spend_story_point() -> bool:
	if story_points > 0:
		story_points -= 1
		story_point_spent.emit(story_points)
		return true
	return false

func check_milestones() -> void:
	var new_milestone = story_points / 5
	if new_milestone > 0 and not new_milestone in milestones_reached:
		milestones_reached.append(new_milestone)
		story_milestone_reached.emit(new_milestone)

func serialize() -> Dictionary:
	return {
		"story_points": story_points,
		"milestones_reached": milestones_reached,
		"current_event_index": current_event_index,
		"story_clock": story_clock.serialize() if story_clock else {}
	}

func deserialize(data: Dictionary) -> void:
	story_points = data.get("story_points", 0)
	milestones_reached = data.get("milestones_reached", [])
	current_event_index = data.get("current_event_index", -1)
	if data.has("story_clock"):
		story_clock.deserialize(data["story_clock"])
