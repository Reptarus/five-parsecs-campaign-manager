@tool
extends Resource
class_name FiveParsecsCampaign

## Five Parsecs Campaign Implementation
## Manages campaign state and progression for Five Parsecs from Home

const FiveParsecsGameEnums = preload("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")
const FiveParsecsCrew = preload("res://src/game/campaign/crew/FiveParsecsCrew.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal campaign_started
signal campaign_ended
signal turn_advanced(turn_number: int)
signal reputation_changed(new_reputation: int)

@export var campaign_name: String = ""
@export var difficulty: int = 2
@export var victory_condition: int = 0
@export var crew_size: int = 4
@export var use_story_track: bool = true
@export var starting_reputation: int = 0
@export var current_turn: int = 1
@export var credits: int = 1000

var campaign_crew: FiveParsecsCrew
var campaign_state: Dictionary = {}

func _init() -> void:
	campaign_crew = FiveParsecsCrew.new()

func start_campaign() -> void:
	campaign_started.emit()

func end_campaign() -> void:
	campaign_ended.emit()

func advance_turn() -> void:
	current_turn += 1
	turn_advanced.emit(current_turn)

func modify_reputation(amount: int) -> void:
	starting_reputation += amount
	reputation_changed.emit(starting_reputation)

func serialize() -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"difficulty": difficulty,
		"victory_condition": victory_condition,
		"crew_size": crew_size,
		"use_story_track": use_story_track,
		"starting_reputation": starting_reputation,
		"current_turn": current_turn,
		"credits": credits,
		"campaign_state": campaign_state
	}

func deserialize(data: Dictionary) -> void:
	campaign_name = data.get("campaign_name", "")
	difficulty = data.get("difficulty", 2)
	victory_condition = data.get("victory_condition", 0)
	crew_size = data.get("crew_size", 4)
	use_story_track = data.get("use_story_track", true)
	starting_reputation = data.get("starting_reputation", 0)
	current_turn = data.get("current_turn", 1)
	credits = data.get("credits", 1000)
	campaign_state = data.get("campaign_state", {})
