## CampaignManager
## Manages campaign flow, missions, and game progression
@tool
class_name CampaignManager
extends Node

## Dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")
const UnifiedStorySystem := preload("res://src/core/story/UnifiedStorySystem.gd")
const BattleStateManager := preload("res://src/core/battle/state/BattleStateMachine.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const WorldManager := preload("res://src/core/world/WorldManager.gd")
const GameCampaignManager := preload("res://src/core/campaign/GameCampaignManager.gd")
const Campaign = preload("res://src/core/campaign/Campaign.gd")

## Signals
signal campaign_state_changed
signal campaign_phase_changed(old_phase: int, new_phase: int)
signal campaign_event_triggered(event: StoryQuestData)
signal mission_available(mission: StoryQuestData)
signal mission_completed(mission: StoryQuestData, success: bool)
signal battle_started(mission: StoryQuestData)
signal battle_ended(victory: bool)
signal resources_loaded
signal resources_unloaded
signal campaign_started(campaign_data: Dictionary)
signal campaign_ended(campaign_data: Dictionary)
signal phase_changed(new_phase: int)
signal turn_completed
signal campaign_victory_achieved(victory_type: GameEnums.CampaignVictoryType)
signal event_triggered(event_data: Dictionary)
signal campaign_created(campaign_data: Dictionary)
signal campaign_loaded(campaign_data: Dictionary)
signal campaign_saved(campaign_data: Dictionary)
signal campaign_deleted(campaign_id: String)

## Core Systems
@export var game_state: FiveParsecsGameState
@export var story_system: UnifiedStorySystem
@export var battle_state_machine: BattleStateManager
@export var world_manager: WorldManager
@export var campaign_manager: GameCampaignManager

## Campaign State
var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.NONE
var phase_manager: CampaignPhaseManager
var current_mission: StoryQuestData = null
var current_location = null # Will be set by WorldManager
var campaign_turn: int = 0
var battle_resources: Array[Resource] = []
var is_battle_active := false
var use_expanded_missions: bool = false
var campaign_progress: int = 0
var campaign_milestones: Array[int] = []
var is_tutorial_active: bool = false
var current_tutorial_type: String = ""
var active_campaign: Campaign = null
var saved_campaigns: Dictionary = {}

## Campaign Configuration
const TURNS_PER_CHAPTER := 10
const MIN_REPUTATION_FOR_PATRONS := 10
const MAX_ACTIVE_MISSIONS := 5

# Campaign configuration defaults
const DEFAULT_USE_EXPANDED_MISSIONS := false
const DEFAULT_DIFFICULTY := GameEnums.DifficultyLevel.NORMAL
const DEFAULT_STARTING_CREDITS := 1000
const DEFAULT_STARTING_SUPPLIES := 5
const DEFAULT_ENABLE_PERMADEATH := false
const DEFAULT_ENABLE_STORY_EVENTS := true
const DEFAULT_CREW_SIZE := 5
const DEFAULT_VICTORY_CONDITION = GameEnums.CampaignVictoryType.STANDARD

func _ready() -> void:
	if not campaign_manager:
		push_error("CampaignManager: No GameCampaignManager assigned!")
		return
		
	phase_manager = CampaignPhaseManager.new(game_state, campaign_manager)
	phase_manager.phase_changed.connect(_on_phase_changed)
	phase_manager.phase_completed.connect(_on_phase_completed)
	phase_manager.event_triggered.connect(_on_event_triggered)

func start_campaign(config: Dictionary = {}) -> void:
	# Initialize campaign state
	current_phase = GameEnums.CampaignPhase.NONE
	campaign_turn = 0
	is_battle_active = false
	campaign_progress = 0
	campaign_milestones.clear()
	
	# Apply configuration with defaults
	use_expanded_missions = config.get("use_expanded_missions", DEFAULT_USE_EXPANDED_MISSIONS)
	game_state.difficulty_level = config.get("difficulty_level", DEFAULT_DIFFICULTY)
	
	# Initialize resources
	game_state.credits = config.get("starting_credits", DEFAULT_STARTING_CREDITS)
	game_state.supplies = config.get("starting_supplies", DEFAULT_STARTING_SUPPLIES)
	
	# Start with setup phase
	phase_manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	campaign_started.emit({
		"config": config,
		"turn": campaign_turn,
		"phase": current_phase
	})

func end_campaign(victory_type: int = -1) -> void:
	var result = {
		"turns_completed": campaign_turn,
		"final_phase": current_phase,
		"victory_type": victory_type,
		"campaign_progress": campaign_progress
	}
	
	current_phase = GameEnums.CampaignPhase.NONE
	campaign_ended.emit(result)

func change_phase(new_phase: GameEnums.CampaignPhase) -> void:
	if not new_phase in GameEnums.CampaignPhase.values():
		push_error("Invalid campaign phase: %d" % new_phase)
		return
	
	phase_manager.start_phase(new_phase)

func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	var old_phase = current_phase
	current_phase = new_phase
	
	# Emit signals for state changes
	campaign_phase_changed.emit(old_phase, new_phase)
	phase_changed.emit(new_phase)
	
	# Update game state based on phase
	match new_phase:
		GameEnums.CampaignPhase.UPKEEP:
			campaign_turn += 1
			_check_campaign_progress()
		GameEnums.CampaignPhase.BATTLE_SETUP:
			is_battle_active = true
		GameEnums.CampaignPhase.ADVANCEMENT:
			is_battle_active = false

func _on_phase_completed() -> void:
	# Check for campaign end conditions
	if _should_end_campaign():
		var victory_type = _determine_victory_type()
		end_campaign(victory_type)
		return
	
	# Advance to next phase
	var next_phase = phase_manager.phase_state.next_phase
	change_phase(next_phase)

func _on_event_triggered(event_data: Dictionary) -> void:
	match event_data.type:
		"CAMPAIGN_SETUP":
			_handle_campaign_setup_event(event_data)
		"BATTLE_SETUP":
			_handle_battle_setup_event(event_data)
		"BATTLE_RESOLVED":
			_handle_battle_resolution_event(event_data)
		"POST_BATTLE_EVENTS":
			_handle_post_battle_events(event_data)
		"RESOURCE_SHORTAGE":
			_handle_resource_shortage_event(event_data)
		_:
			# Forward other events
			event_triggered.emit(event_data)

func _handle_campaign_setup_event(event_data: Dictionary) -> void:
	# Handle campaign setup completion
	if event_data.has("completed") and event_data.completed:
		phase_manager.phase_actions_completed["setup_completed"] = true

func _handle_battle_setup_event(event_data: Dictionary) -> void:
	var battlefield = event_data.get("battlefield")
	if battlefield:
		battle_started.emit(current_mission)

func _handle_battle_resolution_event(event_data: Dictionary) -> void:
	var results = event_data.get("results", {})
	battle_ended.emit(results.get("victory", false))

func _handle_post_battle_events(event_data: Dictionary) -> void:
	var events = event_data.get("events", [])
	for event in events:
		event_triggered.emit(event)

func _handle_resource_shortage_event(event_data: Dictionary) -> void:
	# Check if shortage is critical
	if _is_critical_shortage(event_data):
		end_campaign()

func _is_critical_shortage(event_data: Dictionary) -> bool:
	# End campaign if we're completely out of supplies
	if event_data.resource == "supplies" and game_state.supplies <= 0:
		return true
	return false

func _should_end_campaign() -> bool:
	# Check various end conditions
	if game_state.crew_members.is_empty():
		return true
	
	if campaign_turn >= game_state.campaign_length:
		return true
	
	if _has_achieved_victory():
		return true
	
	return false

func _has_achieved_victory() -> bool:
	# Check victory conditions
	match game_state.victory_condition:
		GameEnums.CampaignVictoryType.WEALTH_GOAL:
			return game_state.credits >= game_state.victory_requirement
		GameEnums.CampaignVictoryType.REPUTATION_GOAL:
			return game_state.reputation >= game_state.victory_requirement
		GameEnums.CampaignVictoryType.FACTION_DOMINANCE:
			return _check_faction_dominance()
		GameEnums.CampaignVictoryType.STORY_COMPLETE:
			return _check_story_completion()
	return false

func _determine_victory_type() -> int:
	if game_state.crew_members.is_empty():
		return GameEnums.CampaignVictoryType.NONE
	
	if game_state.credits >= game_state.victory_requirement:
		return GameEnums.CampaignVictoryType.WEALTH_GOAL
	
	if game_state.reputation >= game_state.victory_requirement:
		return GameEnums.CampaignVictoryType.REPUTATION_GOAL
	
	if _check_faction_dominance():
		return GameEnums.CampaignVictoryType.FACTION_DOMINANCE
	
	if _check_story_completion():
		return GameEnums.CampaignVictoryType.STORY_COMPLETE
	
	return GameEnums.CampaignVictoryType.NONE

func _check_campaign_progress() -> void:
	# Update progress based on current state
	var old_progress = campaign_progress
	campaign_progress = _calculate_campaign_progress()
	
	# Check for milestone achievements
	for milestone in campaign_milestones:
		if old_progress < milestone and campaign_progress >= milestone:
			_trigger_milestone_event(milestone)

func _calculate_campaign_progress() -> int:
	var progress = 0
	
	# Base progress from turns
	progress += int(float(campaign_turn) / game_state.campaign_length * 50)
	
	# Progress from story completion
	if story_system:
		progress += int(story_system.get_completion_percentage() * 30)
	
	# Progress from achievements
	progress += int(game_state.achievements.size() * 2)
	
	return min(progress, 100)

func _trigger_milestone_event(milestone: int) -> void:
	event_triggered.emit({
		"type": "MILESTONE_REACHED",
		"milestone": milestone,
		"progress": campaign_progress
	})

func _check_faction_dominance() -> bool:
	for faction in game_state.active_factions:
		if faction.influence >= game_state.faction_dominance_threshold:
			return true
	return false

func _check_story_completion() -> bool:
	return false # Implement story completion check

func create_new_campaign(config: Dictionary = {}) -> void:
	var campaign := Campaign.new()
	campaign.campaign_name = config.get("name", "New Campaign")
	campaign.campaign_id = str(Time.get_unix_time_from_system())
	campaign.difficulty_level = config.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
	
	active_campaign = campaign
	saved_campaigns[campaign.campaign_id] = campaign
	
	campaign_created.emit(campaign.serialize())

func load_campaign(campaign_id: String) -> void:
	if campaign_id in saved_campaigns:
		active_campaign = saved_campaigns[campaign_id]
		campaign_loaded.emit(active_campaign.serialize())

func save_campaign() -> void:
	if active_campaign:
		saved_campaigns[active_campaign.campaign_id] = active_campaign
		campaign_saved.emit(active_campaign.serialize())

func delete_campaign(campaign_id: String) -> void:
	if campaign_id in saved_campaigns:
		saved_campaigns.erase(campaign_id)
		campaign_deleted.emit(campaign_id)

func get_active_campaign() -> Campaign:
	return active_campaign

func get_saved_campaigns() -> Array:
	return saved_campaigns.values()

func get_campaign_by_id(campaign_id: String) -> Campaign:
	return saved_campaigns.get(campaign_id)

func serialize() -> Dictionary:
	var serialized_campaigns := {}
	for id in saved_campaigns:
		serialized_campaigns[id] = saved_campaigns[id].serialize()
	
	return {
		"active_campaign_id": active_campaign.campaign_id if active_campaign else "",
		"saved_campaigns": serialized_campaigns
	}

func deserialize(data: Dictionary) -> void:
	saved_campaigns.clear()
	active_campaign = null
	
	var serialized_campaigns: Dictionary = data.get("saved_campaigns", {})
	for campaign_id in serialized_campaigns:
		var campaign := Campaign.new()
		campaign.deserialize(serialized_campaigns[campaign_id])
		saved_campaigns[campaign_id] = campaign
		
		if campaign_id == data.get("active_campaign_id"):
			active_campaign = campaign

func check_victory_conditions() -> void:
	if not active_campaign:
		return
		
	var victory_type := _check_victory_type()
	if victory_type != GameEnums.CampaignVictoryType.NONE:
		campaign_victory_achieved.emit(victory_type)

func _check_victory_type() -> GameEnums.CampaignVictoryType:
	if _check_story_completion():
		return GameEnums.CampaignVictoryType.STORY_COMPLETE
		
	if _check_reputation_threshold():
		return GameEnums.CampaignVictoryType.REPUTATION_THRESHOLD
		
	if _check_credits_threshold():
		return GameEnums.CampaignVictoryType.CREDITS_THRESHOLD
		
	if _check_mission_count():
		return GameEnums.CampaignVictoryType.MISSION_COUNT
		
	return GameEnums.CampaignVictoryType.NONE

func _check_reputation_threshold() -> bool:
	return false # Implement reputation threshold check

func _check_credits_threshold() -> bool:
	return false # Implement credits threshold check

func _check_mission_count() -> bool:
	return false # Implement mission count check