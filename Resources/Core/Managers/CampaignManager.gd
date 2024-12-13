## CampaignManager
## Manages campaign flow, missions, and game progression
class_name CampaignManager
extends Node

## Dependencies
const GameEnums := preload("../Systems/GlobalEnums.gd")
const StoryQuestData := preload("../Story/StoryQuestData.gd")
const UnifiedStorySystem := preload("../Story/UnifiedStorySystem.gd")
const FiveParcecsSystem := preload("../../Battle/Core/FiveParcecsSystem.gd")
const GameState := preload("../GameState/GameState.gd")
const WorldManager := preload("../World/WorldManager.gd")

## Signals
signal campaign_state_changed
signal campaign_phase_changed(old_phase: int, new_phase: int)
signal campaign_event_triggered(event: StoryQuestData)
signal mission_available(mission: StoryQuestData)
signal mission_completed(mission: StoryQuestData, success: bool)

## Core Systems
@export var game_state: GameState
@export var story_system: UnifiedStorySystem
@export var battle_system: FiveParcecsSystem
@export var world_manager: WorldManager

## Campaign State
var current_phase: int = GameEnums.CampaignPhase.SETUP
var current_mission: StoryQuestData = null
var current_location = null  # Will be set by WorldManager
var campaign_turn: int = 0

## Campaign Configuration
const TURNS_PER_CHAPTER := 10
const MIN_REPUTATION_FOR_PATRONS := 10
const MAX_ACTIVE_MISSIONS := 5

func _ready() -> void:
    if not story_system:
        story_system = UnifiedStorySystem.new()
        add_child(story_system)
    _connect_signals()

## Connect all required signals
func _connect_signals() -> void:
    if story_system:
        if not story_system.story_event_triggered.is_connected(_on_story_event):
            story_system.story_event_triggered.connect(_on_story_event)
        if not story_system.quest_completed.is_connected(_on_quest_completed):
            story_system.quest_completed.connect(_on_quest_completed)
    
    if battle_system:
        if not battle_system.battle_ended.is_connected(_on_battle_completed):
            battle_system.battle_ended.connect(_on_battle_completed)

## Setup the campaign manager with required references
func setup(state: GameState, battle_mgr: FiveParcecsSystem, world_mgr: WorldManager) -> void:
    if not state:
        push_error("CampaignManager: Invalid game state provided")
        return
        
    game_state = state
    battle_system = battle_mgr
    world_manager = world_mgr
    
    # Initialize story system
    if story_system:
        story_system.setup(state, self, world_manager)
    
    _initialize_campaign()

## Initialize the campaign
func _initialize_campaign() -> void:
    current_phase = GameEnums.CampaignPhase.SETUP
    campaign_turn = 0
    
    _initialize_starting_location()
    _generate_initial_content()

## Initialize the starting location
func _initialize_starting_location() -> void:
    if world_manager:
        current_location = world_manager.generate_starting_location()

## Generate initial content for the campaign
func _generate_initial_content() -> void:
    if story_system:
        story_system.generate_initial_quests()

## Check if a mission can be started
func can_start_mission(mission: StoryQuestData) -> bool:
    if not mission or current_mission:
        return false
    
    if not game_state:
        return false
    
    # Check prerequisites
    return mission.check_prerequisites(game_state)

## Check if a mission can be added to available missions
func can_add_mission(mission: StoryQuestData) -> bool:
    if not mission or not game_state:
        return false
    
    var available_missions = game_state.get_available_missions()
    return available_missions.size() < MAX_ACTIVE_MISSIONS

## Start a new mission
func start_mission(mission: StoryQuestData) -> bool:
    if not can_start_mission(mission):
        return false
        
    current_mission = mission
    
    # Prepare battle system
    if battle_system and mission.has_battle_requirement():
        mission.setup_battle(battle_system)
    
    # Change to battle phase
    change_phase(GameEnums.CampaignPhase.BATTLE)
    return true

## Complete current mission
func complete_mission(success: bool) -> void:
    if not current_mission:
        return
        
    if success:
        current_mission.complete(campaign_turn)
        story_system.complete_quest(current_mission)
        _apply_mission_rewards(current_mission)
    else:
        current_mission.fail(campaign_turn)
        story_system.fail_quest(current_mission)
        _apply_mission_penalties(current_mission)
    
    mission_completed.emit(current_mission, success)
    current_mission = null
    change_phase(GameEnums.CampaignPhase.POST_BATTLE)

## Change campaign phase
func change_phase(new_phase: int) -> void:
    if not GameEnums.CampaignPhase.values().has(new_phase):
        push_error("Invalid campaign phase: %d" % new_phase)
        return
        
    var old_phase = current_phase
    current_phase = new_phase
    
    match new_phase:
        GameEnums.CampaignPhase.UPKEEP:
            _handle_upkeep_phase()
        GameEnums.CampaignPhase.BATTLE:
            _handle_battle_phase()
        GameEnums.CampaignPhase.POST_BATTLE:
            _handle_post_battle_phase()
        GameEnums.CampaignPhase.MANAGEMENT:
            _handle_management_phase()
    
    campaign_phase_changed.emit(old_phase, new_phase)

## Handle story event
func handle_story_event(event: StoryQuestData) -> void:
    if not event:
        push_error("Invalid story event")
        return
        
    # Apply event effects
    if game_state:
        event.apply_effects(game_state)
    
    # Generate related content
    if story_system:
        var related_missions = story_system.generate_related_quests(event)
        for mission in related_missions:
            if can_add_mission(mission):
                game_state.add_available_mission(mission)
    
    campaign_event_triggered.emit(event)

## Signal handlers
func _on_story_event(event: StoryQuestData) -> void:
    handle_story_event(event)

func _on_quest_completed(quest: StoryQuestData) -> void:
    if quest == current_mission:
        complete_mission(true)

func _on_battle_completed(results: Dictionary) -> void:
    if current_mission:
        complete_mission(results.get("victory", false))

## Phase handlers
func _handle_upkeep_phase() -> void:
    _process_upkeep()
    _advance_phase()

func _handle_battle_phase() -> void:
    if current_mission and battle_system:
        if current_mission.has_battle_requirement():
            battle_system.initialize_combat_system()
            current_mission.setup_battle(battle_system)
        else:
            push_error("Cannot start battle: mission has no battle requirement")
            _advance_phase()
    else:
        push_error("Cannot start battle: missing mission or battle system")
        _advance_phase()

func _handle_post_battle_phase() -> void:
    if battle_system and battle_system.last_battle_results:
        _apply_battle_results(battle_system.last_battle_results)
    
    _update_campaign_state()
    _advance_phase()

func _handle_management_phase() -> void:
    if game_state and game_state.crew_manager:
        game_state.crew_manager.process_crew_actions()
    
    _update_available_content()
    _advance_phase()

## Helper functions
func _process_upkeep() -> void:
    if game_state:
        game_state.process_resource_consumption()
    _update_relationships()
    _process_world_events()

## Update relationships between factions and NPCs
func _update_relationships() -> void:
    if game_state:
        game_state.update_relationships()

## Update available content
func _update_available_content() -> void:
    if story_system:
        story_system.update_available_quests()

## Advance to next phase
func _advance_phase() -> void:
    var next_phase = (current_phase + 1) % GameEnums.CampaignPhase.size()
    change_phase(next_phase)

## Update campaign state
func _update_campaign_state() -> void:
    if world_manager:
        world_manager.update_world_state()
    if story_system:
        story_system.update_story_state()

## Process world events
func _process_world_events() -> void:
    if not story_system or not game_state:
        return
        
    if randf() < 0.2:  # 20% chance per turn
        var event = story_system.generate_random_event()
        if event:
            handle_story_event(event)

## Apply battle results
func _apply_battle_results(results: Dictionary) -> void:
    if not game_state:
        return
        
    # Record battle results in current mission
    if current_mission:
        current_mission.record_battle_result(results)
    
    # Apply casualties
    if results.has("casualties") and game_state.crew_manager:
        game_state.crew_manager.apply_casualties(results.casualties)
    
    # Apply reputation changes
    if results.has("reputation"):
        game_state.modify_reputation(results.reputation)

## Apply mission rewards
func _apply_mission_rewards(mission: StoryQuestData) -> void:
    if not game_state or not mission or not mission.rewards:
        return
        
    # Apply resource rewards
    if mission.rewards.has("credits"):
        game_state.modify_credits(mission.rewards.credits)
    
    if mission.rewards.has("reputation"):
        game_state.modify_reputation(mission.rewards.reputation)
    
    # Apply story points
    if mission.rewards.has("story_points"):
        story_system.add_story_points(mission.rewards.story_points)

## Apply mission penalties
func _apply_mission_penalties(mission: StoryQuestData) -> void:
    if not game_state or not mission:
        return
        
    # Apply reputation penalty
    game_state.modify_reputation(-2)
    
    # Apply story point penalty
    story_system.add_story_points(-1)

## Serialization
func serialize() -> Dictionary:
    return {
        "current_phase": GameEnums.CampaignPhase.keys()[current_phase],
        "campaign_turn": campaign_turn,
        "current_mission": current_mission.serialize() if current_mission else null,
        "current_location": current_location.serialize() if current_location else null
    }

func deserialize(data: Dictionary) -> void:
    current_phase = GameEnums.CampaignPhase[data.current_phase] if data.has("current_phase") else GameEnums.CampaignPhase.SETUP
    campaign_turn = data.get("campaign_turn", 0)
    
    if data.has("current_mission") and data.current_mission:
        current_mission = StoryQuestData.new()
        current_mission.deserialize(data.current_mission)
    
    if data.has("current_location") and data.current_location:
        current_location = data.current_location  # WorldManager will handle the actual location data