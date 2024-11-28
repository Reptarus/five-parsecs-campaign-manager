extends Node

# Preload all required resources
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")
const GameState := preload("res://Resources/GameData/GameState.gd")
const Mission := preload("res://Resources/GameData/Mission.gd")
const MissionGenerator := preload("res://Resources/GameData/MissionGenerator.gd")
const StoryTrack := preload("res://Resources/CampaignManagement/StoryTrack.gd")
const WorldGenerator := preload("res://Resources/GameData/WorldGenerator.gd")
const ExpandedFactionManager := preload("res://Resources/ExpansionContent/ExpandedFactionManager.gd")
const CombatManager := preload("res://Resources/BattlePhase/CombatManager.gd")
const EquipmentManager := preload("res://Resources/CampaignManagement/EquipmentManager.gd")
const PatronJobManager := preload("res://Resources/CampaignManagement/PatronJobManager.gd")
const Battle := preload("res://Resources/BattlePhase/battle.gd")
const TutorialSystem := preload("res://Resources/GameData/TutorialSystem.gd")
const Crew := preload("res://Resources/CrewAndCharacters/Crew.gd")

# Signals
signal state_changed(new_state: GlobalEnums.GameState)
signal battle_ended(victory: bool)
signal tutorial_step_changed(step_id: String)
signal tutorial_completed

# Singleton instance
static var _instance: Node = null

# Game state and managers
var game_state: GameState
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager
var combat_manager: CombatManager
var tutorial_system: TutorialSystem

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

func _setup_android_initialization() -> void:
    call_deferred("_initialize_game_systems")

func _initialize_game_systems() -> void:
    game_state = GameState.new()
    mission_generator = MissionGenerator.new(game_state)
    equipment_manager = EquipmentManager.new()
    patron_job_manager = PatronJobManager.new(game_state)
    story_track = StoryTrack.new()
    world_generator = WorldGenerator.new()
    expanded_faction_manager = ExpandedFactionManager.new()
    combat_manager = CombatManager.new()
    tutorial_system = TutorialSystem.new()
    fringe_world_strife_manager = FringeWorldStrifeManager.new()

    # Initialize game state
    game_state.current_state = GlobalEnums.GameState.SETUP
    game_state.crew = Crew.new()  # Initialize with proper Crew object

static func get_instance() -> Node:
    if _instance == null:
        _instance = Node.new()
    return _instance

func set_captain(captain: Character) -> void:
    if not game_state:
        push_error("Game state not initialized")
        return
    
    game_state.captain = captain
    # Add captain to crew
    if game_state.crew == null:
        game_state.crew = Crew.new()
    
    if not game_state.crew.has_member(captain):
        game_state.crew.add_member(captain)
        game_state.crew.set_captain(captain)
    
    # Emit signal for UI updates
    if game_state.current_state == GlobalEnums.GameState.CAMPAIGN:
        state_changed.emit(GlobalEnums.GameState.CAMPAIGN)

func initialize_campaign(config: Dictionary) -> void:
    if not game_state:
        push_error("Game state not initialized")
        return
        
    game_state.current_state = GlobalEnums.GameState.CAMPAIGN
    # Initialize other campaign-specific data here
    state_changed.emit(GlobalEnums.GameState.CAMPAIGN)