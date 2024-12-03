extends Node

## Main game state manager that handles all core game systems and state transitions
##
## This singleton class manages the overall game state, campaign progression,
## battle system, and coordinates between various game subsystems.

# Preload all required resources
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")
const GameState := preload("res://Resources/GameData/GameState.gd")
const Mission := preload("res://Resources/GameData/Mission.gd")
const StoryTrack := preload("res://Resources/CampaignManagement/StoryTrack.gd")
const WorldGenerator := preload("res://Resources/GameData/WorldGenerator.gd")
const ExpandedFactionManager := preload("res://Resources/ExpansionContent/ExpandedFactionManager.gd")
const CombatManager := preload("res://Resources/BattlePhase/CombatManager.gd")
const Battle := preload("res://Resources/BattlePhase/battle.gd")
const TutorialSystem := preload("res://Resources/GameData/TutorialSystem.gd")
const Crew := preload("res://Resources/CrewAndCharacters/Crew.gd")

# Signals for major game events
signal state_changed(new_state: int)
signal battle_ended(victory: bool)
signal tutorial_step_changed(step_id: String)
signal tutorial_completed
signal campaign_victory_achieved(victory_type: int)
signal campaign_progress_updated(progress: Dictionary)
signal mission_completed(mission: Mission)
signal crew_updated(crew: Crew)

# Singleton instance
static var _instance: Node = null

# Game state and managers
var game_state: GameState
var mission_generator: Node  # Will be set to MissionGenerator at runtime
var equipment_manager: Node  # Will be set to EquipmentManager at runtime
var patron_job_manager: Node  # Will be set to PatronJobManager at runtime
var current_battle: Battle
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager
var combat_manager: CombatManager
var tutorial_system: TutorialSystem

## Manager for handling fringe world instability and related events
class FringeWorldStrifeManager extends Node:
    var strife_level: int = GlobalEnums.FringeWorldInstability.STABLE
    
    func update_strife() -> void:
        pass

var fringe_world_strife_manager: FringeWorldStrifeManager

func _init() -> void:
    if _instance != null:
        push_error("GameStateManager already exists!")
        return
    _instance = self

func _ready() -> void:
    if OS.get_name() == "Android":
        _setup_android_initialization()
    else:
        _initialize_game_systems()

## Defers initialization for Android platform to avoid startup issues
func _setup_android_initialization() -> void:
    call_deferred("_initialize_game_systems")

## Initializes all core game systems and managers
func _initialize_game_systems() -> void:
    _create_core_systems()
    _initialize_game_state()
    _connect_signals()

## Creates instances of all core game systems
func _create_core_systems() -> void:
    game_state = GameState.new()
    mission_generator = Node.new()  # Will be replaced with proper type at runtime
    equipment_manager = Node.new()  # Will be replaced with proper type at runtime
    patron_job_manager = Node.new()  # Will be replaced with proper type at runtime
    story_track = StoryTrack.new()
    world_generator = WorldGenerator.new()
    expanded_faction_manager = ExpandedFactionManager.new()
    combat_manager = CombatManager.new()
    tutorial_system = TutorialSystem.new()
    fringe_world_strife_manager = FringeWorldStrifeManager.new()

## Initializes the base game state
func _initialize_game_state() -> void:
    game_state.current_state = GlobalEnums.GameState.SETUP
    game_state.crew = Crew.new()

## Connects all necessary signals between systems
func _connect_signals() -> void:
    combat_manager.battle_ended.connect(_on_battle_ended)
    tutorial_system.tutorial_step_completed.connect(_on_tutorial_step_completed)
    story_track.story_completed.connect(_on_story_completed)

## Returns the singleton instance of GameStateManager
static func get_instance() -> Node:
    if _instance == null:
        _instance = Node.new()
    return _instance

## Handles different battle phases
func handle_battle_phase(phase: int) -> void:
    match phase:
        GlobalEnums.BattlePhase.SETUP:
            _handle_battle_setup()
        GlobalEnums.BattlePhase.DEPLOYMENT:
            _handle_battle_deployment()
        GlobalEnums.BattlePhase.BATTLE:
            _handle_battle_round()
        GlobalEnums.BattlePhase.RESOLUTION:
            _handle_battle_resolution()
        GlobalEnums.BattlePhase.CLEANUP:
            _handle_battle_cleanup()

## Checks if a campaign victory condition has been met
func check_campaign_victory(campaign_victory_condition: int) -> bool:
    match campaign_victory_condition:
        GlobalEnums.CampaignVictoryType.WEALTH_GOAL:
            if game_state.credits >= 5000:
                campaign_victory_achieved.emit(campaign_victory_condition)
                return true
        GlobalEnums.CampaignVictoryType.REPUTATION_GOAL:
            if game_state.reputation >= 10:
                campaign_victory_achieved.emit(campaign_victory_condition)
                return true
        GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE:
            if game_state.dominant_faction_influence >= 15:
                campaign_victory_achieved.emit(campaign_victory_condition)
                return true
        GlobalEnums.CampaignVictoryType.STORY_COMPLETE:
            if story_track.is_completed():
                campaign_victory_achieved.emit(campaign_victory_condition)
                return true
        GlobalEnums.CampaignVictoryType.SURVIVAL:
            if game_state.campaign_turn >= 20:
                campaign_victory_achieved.emit(campaign_victory_condition)
                return true
    return false

## Updates and emits the current campaign progress
func update_campaign_progress() -> void:
    var progress = {
        "turn": game_state.campaign_turn,
        "credits": game_state.credits,
        "reputation": game_state.reputation,
        "faction_influence": game_state.dominant_faction_influence,
        "story_progress": story_track.get_progress(),
        "completed_missions": game_state.completed_missions.size()
    }
    campaign_progress_updated.emit(progress)

## Handles mission completion and rewards
func complete_mission(mission: Mission) -> void:
    game_state.completed_missions.append(mission)
    game_state.update_mission_rewards(mission)
    mission_completed.emit(mission)
    update_campaign_progress()

## Updates the crew and emits the crew_updated signal
func update_crew(crew: Crew) -> void:
    game_state.crew = crew
    crew_updated.emit(crew)

# Signal handlers
func _on_battle_ended(victory: bool) -> void:
    battle_ended.emit(victory)
    if current_battle:
        _handle_battle_cleanup()

func _on_tutorial_step_completed(step_id: String) -> void:
    tutorial_step_changed.emit(step_id)
    if tutorial_system.is_completed():
        tutorial_completed.emit()

func _on_story_completed() -> void:
    check_campaign_victory(GlobalEnums.CampaignVictoryType.STORY_COMPLETE)

# Battle phase handlers
func _handle_battle_setup() -> void:
    if current_battle:
        current_battle.setup_battle(game_state.current_mission)

func _handle_battle_deployment() -> void:
    if current_battle:
        current_battle.handle_deployment()

func _handle_battle_round() -> void:
    if current_battle:
        current_battle.process_round()

func _handle_battle_resolution() -> void:
    if current_battle:
        current_battle.resolve_battle()

func _handle_battle_cleanup() -> void:
    if current_battle:
        current_battle.cleanup()
        current_battle = null