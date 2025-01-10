extends Resource
class_name Campaign

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal campaign_started(campaign_data: Dictionary)
signal campaign_ended(result: Dictionary)
signal phase_changed(new_phase: GameEnums.CampaignPhase)
signal resource_changed(resource_type: GameEnums.ResourceType, amount: int)
signal world_event_triggered(event_type: GameEnums.GlobalEvent)
signal location_changed(new_location: String)
signal event_occurred(event_data: Dictionary)

# Campaign identification
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var creation_date: String = ""
@export var last_saved: String = ""

# Campaign state
@export var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.SETUP
@export var current_turn: int = 1
@export var current_location: String = ""
@export var is_active: bool = true
@export var difficulty_level: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL

# Resources and progress tracking
var resources: Dictionary = {}
var story_progress: Dictionary = {}
var active_missions: Array = []
var completed_missions: Array = []
var campaign_log: Array = []

func _init() -> void:
	_initialize_resources()
	_initialize_story_progress()

func _initialize_resources() -> void:
	resources = {
		GameEnums.ResourceType.CREDITS: 0,
		GameEnums.ResourceType.SUPPLIES: 0,
		GameEnums.ResourceType.REPUTATION: 0,
		GameEnums.ResourceType.STORY_POINT: 0
	}

func _initialize_story_progress() -> void:
	story_progress = {
		"main_quest_stage": 0,
		"side_quests_completed": 0,
		"world_events_resolved": 0,
		"story_milestones": []
	}

func start_campaign(config: Dictionary = {}) -> void:
	campaign_name = config.get("name", "New Campaign")
	difficulty_level = config.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
	creation_date = Time.get_datetime_string_from_system()
	is_active = true
	current_phase = GameEnums.CampaignPhase.SETUP
	
	# Initialize starting resources
	resources[GameEnums.ResourceType.CREDITS] = config.get("starting_credits", 1000)
	resources[GameEnums.ResourceType.SUPPLIES] = config.get("starting_supplies", 5)
	
	campaign_started.emit({
		"name": campaign_name,
		"difficulty": difficulty_level,
		"start_date": creation_date
	})

func end_campaign() -> void:
	is_active = false
	last_saved = Time.get_datetime_string_from_system()
	
	campaign_ended.emit({
		"name": campaign_name,
		"turns_completed": current_turn,
		"missions_completed": completed_missions.size(),
		"final_resources": resources.duplicate()
	})

func advance_phase() -> void:
	var next_phase := _get_next_phase()
	current_phase = next_phase
	phase_changed.emit(next_phase)

func modify_resource(resource_type: GameEnums.ResourceType, amount: int) -> void:
	if resource_type in resources:
		resources[resource_type] += amount
		resource_changed.emit(resource_type, amount)

func trigger_world_event(event_type: GameEnums.GlobalEvent) -> void:
	world_event_triggered.emit(event_type)

func _get_next_phase() -> GameEnums.CampaignPhase:
	match current_phase:
		GameEnums.CampaignPhase.SETUP:
			return GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.UPKEEP:
			return GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.STORY:
			return GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.CAMPAIGN:
			return GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.ADVANCEMENT:
			return GameEnums.CampaignPhase.UPKEEP
		_:
			return GameEnums.CampaignPhase.SETUP

func get_resources() -> Dictionary:
	return resources.duplicate()

func get_story_progress() -> Dictionary:
	return story_progress.duplicate()

func add_campaign_log_entry(entry: Dictionary) -> void:
	entry["timestamp"] = Time.get_unix_time_from_system()
	campaign_log.append(entry)
	event_occurred.emit(entry)

func get_campaign_log() -> Array:
	return campaign_log.duplicate()

func serialize() -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"campaign_id": campaign_id,
		"creation_date": creation_date,
		"last_saved": last_saved,
		"current_phase": current_phase,
		"current_turn": current_turn,
		"current_location": current_location,
		"is_active": is_active,
		"difficulty_level": difficulty_level,
		"resources": resources.duplicate(),
		"story_progress": story_progress.duplicate(),
		"active_missions": active_missions.duplicate(),
		"completed_missions": completed_missions.duplicate(),
		"campaign_log": campaign_log.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	campaign_name = data.get("campaign_name", "")
	campaign_id = data.get("campaign_id", "")
	creation_date = data.get("creation_date", "")
	last_saved = data.get("last_saved", "")
	current_phase = data.get("current_phase", GameEnums.CampaignPhase.SETUP)
	current_turn = data.get("current_turn", 1)
	current_location = data.get("current_location", "")
	is_active = data.get("is_active", true)
	difficulty_level = data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	resources = data.get("resources", {}).duplicate()
	story_progress = data.get("story_progress", {}).duplicate()
	active_missions = data.get("active_missions", []).duplicate()
	completed_missions = data.get("completed_missions", []).duplicate()
	campaign_log = data.get("campaign_log", []).duplicate()