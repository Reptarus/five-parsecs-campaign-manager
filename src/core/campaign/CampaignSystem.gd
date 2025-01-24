@tool
class_name FiveParcsecsCampaignSystem
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParcsecsCampaign = preload("res://src/core/campaign/Campaign.gd")
const GameState = preload("res://src/core/state/GameState.gd")

## Signals
signal campaign_created(campaign: FiveParcsecsCampaign)
signal campaign_loaded(campaign: FiveParcsecsCampaign)
signal campaign_saved(save_data: Dictionary)
signal campaign_deleted(campaign_id: String)
signal story_progressed(progress: int)
signal resources_changed(total_resources: int)
signal reputation_changed(reputation: int)
signal missions_completed(completed_missions: int)

## Variables
var campaign_type: int = GameEnums.FiveParcsecsCampaignType.STANDARD
var total_resources: int = 0
var reputation: int = 0
var completed_missions: int = 0
var active_crew: Array[Dictionary] = []
var active_rivals: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var story_progress: int = 0
var active_campaign: FiveParcsecsCampaign = null
var game_state: GameState = null

## Constructor
func _init(state: GameState = null) -> void:
    game_state = state if state else GameState.new()
    if not game_state:
        push_error("Failed to initialize GameState")
        return

## Get the total number of completed missions
func get_completed_missions_count() -> int:
    return completed_missions

## Get the total resources
func get_total_resources() -> int:
    return total_resources

## Get current reputation
func get_reputation() -> int:
    return reputation

## Get number of active crew members
func get_active_crew_count() -> int:
    return active_crew.size()

## Get number of active rivals
func get_active_rivals_count() -> int:
    return active_rivals.size()

## Check if crew has exploration capability
func has_exploration_capability() -> bool:
    for crew_member in active_crew:
        if crew_member.get("skills", []).has("exploration"):
            return true
    return false

## Check if crew has advanced equipment
func has_advanced_equipment() -> bool:
    for item in equipment:
        if item.get("tier", 0) >= 2:
            return true
    return false

## Check if there is story progress
func has_story_progress() -> bool:
    return story_progress > 0

## Add resources
func add_resources(amount: int) -> void:
    total_resources += amount
    resources_changed.emit(total_resources)

## Add reputation
func add_reputation(amount: int) -> void:
    reputation += amount
    reputation_changed.emit(reputation)

## Complete a mission
func complete_mission() -> void:
    completed_missions += 1
    missions_completed.emit(completed_missions)

## Add crew member
func add_crew_member(member: Dictionary) -> void:
    active_crew.append(member)

## Add rival
func add_rival(rival: Dictionary) -> void:
    active_rivals.append(rival)

## Add equipment
func add_equipment(item: Dictionary) -> void:
    equipment.append(item)

## Advance story progress
func advance_story() -> void:
    story_progress += 1
    story_progressed.emit(story_progress)

func create_campaign(config: Dictionary) -> FiveParcsecsCampaign:
    var campaign = FiveParcsecsCampaign.new()
    campaign.campaign_name = config.get("name", "New Campaign")
    campaign.difficulty = config.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
    campaign.victory_condition = config.get("victory_condition", GameEnums.FiveParcsecsCampaignVictoryType.STANDARD)
    campaign.crew_size = config.get("crew_size", GameEnums.CrewSize.FOUR)
    campaign.use_story_track = config.get("use_story_track", true)
    
    active_campaign = campaign
    campaign_created.emit(campaign)
    return campaign

func load_campaign(save_data: Dictionary) -> FiveParcsecsCampaign:
    var campaign = FiveParcsecsCampaign.new()
    campaign.deserialize(save_data)
    active_campaign = campaign
    campaign_loaded.emit(campaign)
    return campaign

func save_campaign() -> void:
    if not active_campaign:
        push_error("No active campaign to save")
        return
    
    var save_data = active_campaign.serialize()
    campaign_saved.emit(save_data)

func delete_campaign(campaign_id: String) -> void:
    if not campaign_id:
        push_error("Invalid campaign ID")
        return
    
    # Add deletion logic here
    campaign_deleted.emit(campaign_id)

func get_active_campaign() -> FiveParcsecsCampaign:
    return active_campaign

func _exit_tree() -> void:
    if active_campaign:
        active_campaign.queue_free()
    if game_state and game_state.get_parent() == null:
        game_state.queue_free()