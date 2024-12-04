extends Node

## Main game state manager that handles all core game systems and state transitions
##
## This singleton class manages the overall game state, campaign progression,
## battle system, and coordinates between various game subsystems.

# Define manager classes first
class CampaignManager extends Node:
    signal phase_changed(new_phase: int)
    func _init() -> void:
        name = "CampaignManager"

class BattleManager extends Node:
    signal phase_changed(new_phase: int)
    func _init() -> void:
        name = "BattleManager"

class MissionManager extends Node:
    func _init() -> void:
        name = "MissionManager"

class EquipmentManager extends Node:
    func _init() -> void:
        name = "EquipmentManager"

class PatronJobManager extends Node:
    func _init() -> void:
        name = "PatronJobManager"

## Manager for handling fringe world instability and related events
class FringeWorldStrifeManager extends Node:
    signal strife_level_changed(new_level: int)
    signal unity_progress_changed(progress: float)
    
    var strife_level: int = GlobalEnums.FringeWorldInstability.STABLE
    var unity_progress: float = 0.0
    
    func _init() -> void:
        name = "FringeWorldStrifeManager"
    
    func set_game_state(state: GameState) -> void:
        # Initialize with game state
        pass
    
    func update_strife() -> void:
        pass

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
var current_battle: Battle
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager
var combat_manager: CombatManager
var tutorial_system: TutorialSystem
var fringe_world_strife_manager: FringeWorldStrifeManager

# Manager variables with proper typing
var campaign_manager: CampaignManager
var battle_manager: BattleManager
var mission_manager: MissionManager
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var fringe_world_manager: FringeWorldStrifeManager

# Add scene requirements dictionary
const REQUIRED_MANAGERS = {
    "main_menu": [],
    "campaign_setup": ["campaign_manager"],
    "campaign_dashboard": [
        "campaign_manager",
        "mission_manager",
        "equipment_manager",
        "patron_job_manager"
    ],
    "battle": [
        "battle_manager",
        "equipment_manager"
    ]
}

# Add current scene tracking
var current_scene: String = ""
var initialized_managers: Dictionary = {}

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
    story_track = StoryTrack.new()
    world_generator = WorldGenerator.new()
    expanded_faction_manager = ExpandedFactionManager.new()
    combat_manager = CombatManager.new()
    tutorial_system = TutorialSystem.new()
    fringe_world_strife_manager = FringeWorldStrifeManager.new()
    add_child(fringe_world_strife_manager)
    fringe_world_strife_manager.set_game_state(game_state)

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

func _on_campaign_phase_changed(new_phase: int) -> void:
    if campaign_manager:
        # Handle campaign phase change
        pass

func _on_battle_phase_changed(new_phase: int) -> void:
    if battle_manager:
        handle_battle_phase(new_phase)

func _on_strife_level_changed(new_level: int) -> void:
    if fringe_world_manager:
        # Handle strife level change
        pass

func _on_unity_progress_changed(progress: float) -> void:
    if fringe_world_manager:
        # Handle unity progress change
        pass

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

# Add scene-aware initialization
func initialize_for_scene(scene_name: String) -> void:
    current_scene = scene_name
    
    # Cleanup managers not needed for this scene
    _cleanup_unused_managers(scene_name)
    
    # Initialize required managers for this scene
    if REQUIRED_MANAGERS.has(scene_name):
        for manager in REQUIRED_MANAGERS[scene_name]:
            _initialize_manager(manager)

func _initialize_manager(manager_name: String) -> void:
    # Skip if already initialized
    if initialized_managers.has(manager_name):
        return
        
    match manager_name:
        "campaign_manager":
            campaign_manager = CampaignManager.new()
            add_child(campaign_manager)
            initialized_managers[manager_name] = campaign_manager
            
        "battle_manager":
            battle_manager = BattleManager.new()
            add_child(battle_manager)
            initialized_managers[manager_name] = battle_manager
            
        "mission_manager":
            mission_manager = MissionManager.new()
            add_child(mission_manager)
            initialized_managers[manager_name] = mission_manager
            
        "equipment_manager":
            equipment_manager = EquipmentManager.new()
            add_child(equipment_manager)
            initialized_managers[manager_name] = equipment_manager
            
        "patron_job_manager":
            patron_job_manager = PatronJobManager.new()
            add_child(patron_job_manager)
            initialized_managers[manager_name] = patron_job_manager

func _cleanup_unused_managers(new_scene: String) -> void:
    var required = REQUIRED_MANAGERS.get(new_scene, [])
    var to_remove = []
    
    for manager_name in initialized_managers:
        if not manager_name in required:
            to_remove.append(manager_name)
    
    for manager_name in to_remove:
        var manager = initialized_managers[manager_name]
        if is_instance_valid(manager):
            manager.queue_free()
        initialized_managers.erase(manager_name)

# Add a method to check if a manager is available
func has_manager(manager_name: String) -> bool:
    return initialized_managers.has(manager_name)

# Get a manager instance if available
func get_manager(manager_name: String) -> Node:
    return initialized_managers.get(manager_name)