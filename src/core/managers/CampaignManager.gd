## CampaignManager
## Manages campaign flow, missions, and game progression
@tool
extends Node

## Dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")
const UnifiedStorySystem := preload("res://src/core/story/UnifiedStorySystem.gd")
const BattleStateMachine := preload("res://src/core/battle/state/BattleStateMachine.gd")
const FiveParsecsGameState := preload("res://src/data/resources/GameState/GameState.gd")
const WorldManager := preload("res://src/core/world/WorldManager.gd")

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
signal campaign_victory_achieved(victory_type: int)

## Core Systems
@export var game_state: FiveParsecsGameState
@export var story_system: UnifiedStorySystem
@export var battle_state_machine: BattleStateMachine
@export var world_manager: WorldManager

## Campaign State
var current_phase: int = GameEnums.CampaignPhase.SETUP
var current_mission: StoryQuestData = null
var current_location = null  # Will be set by WorldManager
var campaign_turn: int = 0
var battle_resources: Array[Resource] = []
var is_battle_active := false
var use_expanded_missions: bool = false
var campaign_progress: int = 0
var campaign_milestones: Array[int] = []
var is_tutorial_active: bool = false
var current_tutorial_type: String = ""

## Campaign Configuration
const TURNS_PER_CHAPTER := 10
const MIN_REPUTATION_FOR_PATRONS := 10
const MAX_ACTIVE_MISSIONS := 5

# Campaign configuration defaults
const DEFAULT_CONFIG = {
    "use_expanded_missions": false,
    "difficulty_mode": GameEnums.DifficultyMode.NORMAL,
    "starting_credits": 1000,
    "starting_supplies": 5,
    "enable_permadeath": false,
    "enable_story_events": true,
    "crew_size": 5,
    "victory_condition": GameEnums.CampaignVictoryType.TURNS_20
}

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
    
    if battle_state_machine:
        if not battle_state_machine.battle_ended.is_connected(_on_battle_completed):
            battle_state_machine.battle_ended.connect(_on_battle_completed)

## Setup the campaign manager with required references
func setup(state: FiveParsecsGameState, battle_mgr: BattleStateMachine = null, world_mgr: WorldManager = null) -> void:
    if not state:
        push_error("CampaignManager: Invalid game state provided")
        return
        
    game_state = state
    if battle_mgr:
        battle_state_machine = battle_mgr
    if world_mgr:
        world_manager = world_mgr
    
    # Initialize story system
    if story_system:
        story_system.setup(state, self, world_manager)
    
    current_phase = GameEnums.CampaignPhase.SETUP
    phase_changed.emit(current_phase)
    
    _initialize_campaign()

## Initialize the campaign
func _initialize_campaign() -> void:
    current_phase = GameEnums.CampaignPhase.SETUP
    campaign_turn = 0
    campaign_progress = 0
    campaign_milestones.clear()
    is_tutorial_active = false
    current_tutorial_type = ""
    
    _initialize_starting_location()
    _generate_initial_content()
    _apply_default_config()

## Apply default configuration
func _apply_default_config() -> void:
    use_expanded_missions = DEFAULT_CONFIG.use_expanded_missions
    if game_state:
        game_state.difficulty_mode = DEFAULT_CONFIG.difficulty_mode
        game_state.starting_credits = DEFAULT_CONFIG.starting_credits
        game_state.starting_supplies = DEFAULT_CONFIG.starting_supplies
        game_state.enable_permadeath = DEFAULT_CONFIG.enable_permadeath
        game_state.enable_story_events = DEFAULT_CONFIG.enable_story_events
        game_state.crew_size = DEFAULT_CONFIG.crew_size
        game_state.victory_condition = DEFAULT_CONFIG.victory_condition

## Tutorial management
func start_tutorial(tutorial_type: String = "basic") -> void:
    is_tutorial_active = true
    current_tutorial_type = tutorial_type
    _setup_tutorial_content()

func complete_tutorial() -> void:
    is_tutorial_active = false
    current_tutorial_type = ""
    _cleanup_tutorial_content()

func skip_tutorial() -> void:
    complete_tutorial()
    _advance_to_main_campaign()

## Campaign progression
func check_victory_conditions() -> void:
    if not game_state:
        return
        
    match game_state.victory_condition:
        GameEnums.CampaignVictoryType.TURNS_20:
            if campaign_turn >= 20:
                _trigger_campaign_victory(GameEnums.CampaignVictoryType.TURNS_20)
        GameEnums.CampaignVictoryType.STORY_COMPLETE:
            if _is_story_complete():
                _trigger_campaign_victory(GameEnums.CampaignVictoryType.STORY_COMPLETE)
        GameEnums.CampaignVictoryType.WEALTH:
            if game_state.credits >= 10000:
                _trigger_campaign_victory(GameEnums.CampaignVictoryType.WEALTH)

func _trigger_campaign_victory(victory_type: int) -> void:
    campaign_victory_achieved.emit(victory_type)
    end_campaign()

func _is_story_complete() -> bool:
    return story_system and story_system.is_main_story_complete()

## Campaign state management
func serialize() -> Dictionary:
    return {
        "current_phase": current_phase,
        "campaign_turn": campaign_turn,
        "campaign_progress": campaign_progress,
        "campaign_milestones": campaign_milestones,
        "is_tutorial_active": is_tutorial_active,
        "current_tutorial_type": current_tutorial_type,
        "use_expanded_missions": use_expanded_missions,
        "is_battle_active": is_battle_active,
        "current_location": current_location.serialize() if current_location else null,
        "current_mission": current_mission.serialize() if current_mission else null
    }

func deserialize(data: Dictionary) -> void:
    current_phase = data.get("current_phase", GameEnums.CampaignPhase.SETUP)
    campaign_turn = data.get("campaign_turn", 0)
    campaign_progress = data.get("campaign_progress", 0)
    campaign_milestones = data.get("campaign_milestones", [])
    is_tutorial_active = data.get("is_tutorial_active", false)
    current_tutorial_type = data.get("current_tutorial_type", "")
    use_expanded_missions = data.get("use_expanded_missions", false)
    is_battle_active = data.get("is_battle_active", false)
    
    if data.has("current_location") and data.current_location:
        current_location = world_manager.deserialize_location(data.current_location)
    
    if data.has("current_mission") and data.current_mission:
        current_mission = StoryQuestData.new()
        current_mission.deserialize(data.current_mission)

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
    if battle_state_machine and mission.has_battle_requirement():
        mission.setup_battle(battle_state_machine)
    
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
    if not new_phase in GameEnums.CampaignPhase.values():
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
    if current_mission and battle_state_machine:
        if current_mission.has_battle_requirement():
            battle_state_machine.initialize_combat_system()
            current_mission.setup_battle(battle_state_machine)
        else:
            push_error("Cannot start battle: mission has no battle requirement")
            _advance_phase()
    else:
        push_error("Cannot start battle: missing mission or battle system")
        _advance_phase()

func _handle_post_battle_phase() -> void:
    if battle_state_machine and battle_state_machine.last_battle_results:
        _apply_battle_results(battle_state_machine.last_battle_results)
    
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
        "current_location": current_location.serialize() if current_location else null,
        "is_battle_active": is_battle_active
    }

func deserialize(data: Dictionary) -> void:
    current_phase = GameEnums.CampaignPhase[data.current_phase] if data.has("current_phase") else GameEnums.CampaignPhase.SETUP
    campaign_turn = data.get("campaign_turn", 0)
    
    if data.has("current_mission") and data.current_mission:
        current_mission = StoryQuestData.new()
        current_mission.deserialize(data.current_mission)
    
    if data.has("current_location") and data.current_location:
        current_location = data.current_location  # WorldManager will handle the actual location data
    
    is_battle_active = data.get("is_battle_active", false)
    if is_battle_active and current_mission:
        load_battle_resources()

func _exit_tree() -> void:
    cleanup()

func cleanup() -> void:
    end_battle(false)
    unload_battle_resources()
    game_state = null
    current_mission = null

func setup_battlefield(mission: StoryQuestData) -> bool:
    if not mission or is_battle_active:
        return false
    
    current_mission = mission
    if not load_battle_resources():
        return false
    
    is_battle_active = true
    battle_started.emit(mission)
    return true

func end_battle(victory: bool) -> void:
    if not is_battle_active:
        return
    
    is_battle_active = false
    battle_ended.emit(victory)
    unload_battle_resources()
    current_mission = null

func load_battle_resources() -> bool:
    if not current_mission:
        return false
    
    var resources_to_load = [
        "res://src/game/battle/battlefield_tileset.tres",
        "res://src/game/battle/unit_data.tres",
        "res://src/game/battle/weapon_data.tres"
    ]
    
    battle_resources.clear()
    
    for resource_path in resources_to_load:
        var resource = load(resource_path)
        if not resource:
            push_error("Failed to load battle resource: " + resource_path)
            unload_battle_resources()
            return false
        battle_resources.append(resource)
    
    resources_loaded.emit()
    return true

func unload_battle_resources() -> void:
    for resource in battle_resources:
        if resource and resource.has_method("cleanup"):
            resource.cleanup()
    
    battle_resources.clear()
    resources_unloaded.emit()

func advance_phase() -> void:
    if not game_state:
        return
        
    var next_phase := _get_next_phase()
    if next_phase != current_phase:
        current_phase = next_phase
        phase_changed.emit(current_phase)

func _get_next_phase() -> int:
    match current_phase:
        GameEnums.CampaignPhase.SETUP:
            return GameEnums.CampaignPhase.UPKEEP
        GameEnums.CampaignPhase.UPKEEP:
            return GameEnums.CampaignPhase.WORLD_STEP
        GameEnums.CampaignPhase.WORLD_STEP:
            return GameEnums.CampaignPhase.TRAVEL
        GameEnums.CampaignPhase.TRAVEL:
            return GameEnums.CampaignPhase.PATRONS
        GameEnums.CampaignPhase.PATRONS:
            return GameEnums.CampaignPhase.BATTLE
        GameEnums.CampaignPhase.BATTLE:
            return GameEnums.CampaignPhase.POST_BATTLE
        GameEnums.CampaignPhase.POST_BATTLE:
            return GameEnums.CampaignPhase.MANAGEMENT
        GameEnums.CampaignPhase.MANAGEMENT:
            return GameEnums.CampaignPhase.UPKEEP
        _:
            return GameEnums.CampaignPhase.SETUP