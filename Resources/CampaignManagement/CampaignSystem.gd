class_name CampaignSystem
extends Node

# Signals
signal campaign_started
signal campaign_turn_completed
signal campaign_phase_changed(phase: GlobalEnums.CampaignPhase)
signal campaign_victory_achieved(victory_type: GlobalEnums.VictoryConditionType)

# Core components
var game_state: GameState
var game_state_manager: GameStateManager
var campaign_turn_manager: CampaignTurnManager
var story_track: StoryTrack
var world_manager: WorldManager
var mission_manager: MissionManager
var faction_manager: FactionManager

# Campaign state
var current_phase: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.UPKEEP
var use_expanded_missions: bool = false

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    game_state_manager = get_node("/root/GameStateManager") as GameStateManager
    if not game_state_manager:
        push_error("GameStateManager not found in scene tree")
        return
    
    _initialize_managers()

func _initialize_managers() -> void:
    # Load manager scripts
    var CampaignTurnManagerScript = load("res://Resources/GameData/CampaignTurnManager.gd")
    var StoryTrackScript = load("res://Resources/CampaignManagement/StoryTrack.gd")
    var WorldManagerScript = load("res://Resources/GameData/WorldManager.gd")
    var MissionManagerScript = load("res://Resources/GameData/MissionManager.gd")
    var FactionManagerScript = load("res://Resources/GameData/FactionManager.gd")
    
    # Initialize managers with proper type casting
    campaign_turn_manager = CampaignTurnManagerScript.new(game_state)
    story_track = StoryTrackScript.new()
    story_track.initialize(game_state_manager)
    
    world_manager = WorldManagerScript.new(game_state)
    mission_manager = MissionManagerScript.new(game_state)
    faction_manager = FactionManagerScript.new(game_state)

func start_campaign(config: Dictionary) -> void:
    # Initialize campaign with configuration
    game_state.initialize_campaign(config)
    
    # Setup initial game state
    current_phase = GlobalEnums.CampaignPhase.UPKEEP
    use_expanded_missions = config.get("use_expanded_missions", false)
    
    # Start first turn
    campaign_started.emit()
    start_new_turn()

func start_new_turn() -> void:
    game_state.campaign_turn += 1
    campaign_turn_manager.start_campaign_turn()
    advance_phase()

func advance_phase() -> void:
    var phases = GlobalEnums.CampaignPhase.values()
    var current_index = phases.find(current_phase)
    current_phase = phases[(current_index + 1) % phases.size()]
    campaign_phase_changed.emit(current_phase)
    
    process_current_phase()

func process_current_phase() -> void:
    match current_phase:
        GlobalEnums.CampaignPhase.UPKEEP:
            process_upkeep_phase()
        GlobalEnums.CampaignPhase.WORLD_STEP:
            process_world_phase()
        GlobalEnums.CampaignPhase.TRAVEL:
            process_travel_phase()
        GlobalEnums.CampaignPhase.PATRONS:
            process_patron_phase()
        GlobalEnums.CampaignPhase.BATTLE:
            process_battle_phase()
        GlobalEnums.CampaignPhase.POST_BATTLE:
            process_post_battle_phase()

# Phase processing methods
func process_upkeep_phase() -> void:
    # Handle crew upkeep, ship maintenance, etc.
    pass

func process_world_phase() -> void:
    # Handle world events, resource updates, etc.
    world_manager.process_world_events()

func process_travel_phase() -> void:
    # Handle travel between locations
    pass

func process_patron_phase() -> void:
    # Handle patron jobs and relationships
    faction_manager.process_faction_events()

func process_battle_phase() -> void:
    # Handle battle setup and execution
    pass

func process_post_battle_phase() -> void:
    # Handle battle aftermath and rewards
    pass

# Campaign state checks
func check_victory_conditions() -> void:
    if game_state.check_victory_conditions():
        campaign_victory_achieved.emit(game_state.victory_condition.type) 