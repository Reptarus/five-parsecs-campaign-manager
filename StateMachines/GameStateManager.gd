extends Node

# Preload all required resources
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")
const GameStateResource := preload("res://Resources/GameData/GameState.gd")
const Mission := preload("res://Resources/GameData/Mission.gd") 
const MissionGenerator := preload("res://Resources/GameData/MissionGenerator.gd")
const StoryTrack := preload("res://Resources/CampaignManagement/StoryTrack.gd")
const WorldGenerator := preload("res://Resources/GameData/WorldGenerator.gd")
const ExpandedFactionManager := preload("res://Resources/ExpansionContent/ExpandedFactionManager.gd")
const CombatManager := preload("res://Resources/BattlePhase/CombatManager.gd")
const DeploymentManager := preload("res://Resources/GameData/EnemyDeploymentManager.gd")
const EquipmentManager := preload("res://Resources/CampaignManagement/EquipmentManager.gd")
const TerrainGenerator := preload("res://Resources/GameData/TerrainGenerator.gd")
const PatronJobManager := preload("res://Resources/CampaignManagement/PatronJobManager.gd")
const Battle := preload("res://Resources/BattlePhase/battle.gd")
const TutorialSystem := preload("res://Resources/GameData/TutorialSystem.gd")

# Remove FringeWorldStrifeManager since it doesn't exist yet
# We'll create a basic version of it
class FringeWorldStrifeManager extends Node:
	var strife_level: int = GlobalEnums.FringeWorldInstability.STABLE
	
	func update_strife() -> void:
		# Basic implementation
		pass

# Scene constants
const BATTLE_SCENE: PackedScene = preload("res://Resources/BattlePhase/Scenes/Battle.tscn")
const POST_BATTLE_SCENE: PackedScene = preload("res://Resources/BattlePhase/PreBattle.tscn")
const INITIAL_CREW_CREATION_SCENE: String = "res://Scenes/Management/InitialCrewCreation.tscn"

# Signals
signal state_changed(new_state: GlobalEnums.GameState)
signal battle_ended(victory: bool)
signal tutorial_step_changed(step_id: String)
signal tutorial_track_completed(track_id: String)
signal tutorial_step_completed
signal tutorial_completed
signal settings_changed

# Singleton instance
static var instance: GameStateManager

# Game state and managers
var game_state: GameStateResource
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle
var fringe_world_strife_manager: FringeWorldStrifeManager
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager
var combat_manager: CombatManager
var tutorial_system: TutorialSystem

# State machines
var battle_state: LocalBattleStateMachine
var campaign_state: LocalCampaignStateMachine
var main_game_state: LocalMainGameStateMachine

# Settings with default values
var settings: Dictionary = {
	"disable_tutorial_popup": false,
	"difficulty": GlobalEnums.DifficultyMode.NORMAL,
	"enable_permadeath": true,
	"enable_tutorials": true
}

# Tutorial tracking
var current_tutorial_type: GlobalEnums.TutorialType = GlobalEnums.TutorialType.QUICK_START
var current_tutorial_stage: GlobalEnums.TutorialStage = GlobalEnums.TutorialStage.INTRODUCTION
var current_tutorial_track: GlobalEnums.TutorialTrack = GlobalEnums.TutorialTrack.CORE_RULES
var completed_tutorials: Dictionary = {}

# File path constants
const SETTINGS_FILE_PATH := "user://settings.save"
const SAVE_GAME_FILE_PATH := "user://savegame.json"

func _init() -> void:
	if instance != null:
		push_error("GameStateManager already exists!")
		return
	instance = self

static func get_instance() -> GameStateManager:
	return instance

func _ready() -> void:
	game_state = GameStateResource.new()
	initialize_managers()
	initialize_state_machines()
	_load_settings()
	_initialize_tutorial_system()

func _initialize_tutorial_system() -> void:
	tutorial_system = TutorialSystem.new()
	add_child(tutorial_system)
	
	# Connect tutorial signals
	tutorial_system.tutorial_step_changed.connect(_on_tutorial_step_changed)
	tutorial_system.tutorial_completed.connect(_on_tutorial_completed)
	tutorial_system.tutorial_step_completed.connect(_on_tutorial_step_completed)
	tutorial_system.tutorial_track_completed.connect(_on_tutorial_track_completed)

func initialize_managers() -> void:
	mission_generator = MissionGenerator.new(game_state)
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new(game_state)
	fringe_world_strife_manager = FringeWorldStrifeManager.new()
	story_track = StoryTrack.new()
	world_generator = WorldGenerator.new()
	expanded_faction_manager = ExpandedFactionManager.new()
	combat_manager = CombatManager.new()

func initialize_state_machines() -> void:
	battle_state = LocalBattleStateMachine.new()
	campaign_state = LocalCampaignStateMachine.new()
	main_game_state = LocalMainGameStateMachine.new()
	
	add_child(battle_state)
	add_child(campaign_state)
	add_child(main_game_state)
	
	battle_state.setup(self)
	campaign_state.setup(self)
	main_game_state.setup(self)

func get_current_game_state() -> GlobalEnums.GameState:
	return main_game_state.current_state

func get_current_campaign_phase() -> GlobalEnums.CampaignPhase:
	return main_game_state.current_campaign_phase

func transition_to_state(new_state: GlobalEnums.GameState) -> void:
	game_state.current_state = new_state
	state_changed.emit(new_state)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
		
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open settings file")
		return
		
	var json := JSON.new()
	var parse_result: Error = json.parse(file.get_as_text())
	if parse_result == OK:
		var data = json.get_data()
		if data is Dictionary:
			settings = data
		else:
			push_error("Invalid settings data format")

func save_settings() -> void:
	var file: FileAccess = FileAccess.open("user://settings.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	settings_changed.emit()

func _handle_battle_setup() -> void:
	if current_battle:
		current_battle.setup_battlefield()

func _handle_battle_round() -> void:
	if current_battle:
		current_battle.process_round()

func _handle_battle_cleanup() -> void:
	if current_battle:
		current_battle.cleanup()

func handle_game_over(victory: bool) -> void:
	print("Game %s!" % ("Won" if victory else "Over"))
	game_state.current_state = GlobalEnums.GameState.GAME_OVER
	state_changed.emit(GlobalEnums.GameState.GAME_OVER)

func get_game_state() -> GameStateResource:
	return game_state

func get_current_ship() -> Ship:
	return game_state.current_ship

func is_objective_completed() -> bool:
	return game_state.current_objective.is_completed()

func get_casualties_this_round() -> int:
	return game_state.current_battle.casualties

func get_panic_range() -> int:
	return game_state.current_battle.panic_range

func get_random_enemy() -> Character:
	var enemies: Array = game_state.current_battle.enemies
	return enemies[randi() % enemies.size()] if not enemies.is_empty() else null

func remove_enemy(enemy: Character) -> void:
	var enemies: Array = game_state.current_battle.enemies
	if enemy in enemies:
		enemies.erase(enemy)
		print("Enemy removed: ", enemy.name)

class LocalBattleStateMachine extends Node:
	var current_state: int = GlobalEnums.BattlePhase.SETUP
	var game_manager: GameStateManager
	
	func setup(manager: GameStateManager) -> void:
		game_manager = manager
		
	func transition_to(new_state: int) -> void:
		if new_state not in GlobalEnums.BattlePhase.values():
			push_error("Invalid battle phase state: %d" % new_state)
			return
			
		current_state = new_state
		match current_state:
			GlobalEnums.BattlePhase.SETUP:
				game_manager._handle_battle_setup()
			GlobalEnums.BattlePhase.COMBAT:
				game_manager._handle_battle_round()
			GlobalEnums.BattlePhase.CLEANUP:
				game_manager._handle_battle_cleanup()

class LocalCampaignStateMachine extends Node:
	var current_state: int = GlobalEnums.CampaignPhase.UPKEEP
	var game_manager: GameStateManager
	
	func setup(manager: GameStateManager) -> void:
		game_manager = manager

class LocalMainGameStateMachine extends Node:
	var current_state: int = GlobalEnums.GameState.SETUP
	var current_campaign_phase: int = GlobalEnums.CampaignPhase.WORLD_STEP
	var game_manager: GameStateManager
	
	func setup(manager: GameStateManager) -> void:
		game_manager = manager

# Crew Management Functions
func get_crew() -> Array:
	return game_state.current_ship.crew if game_state and game_state.current_ship else []

func add_crew_member(character: CrewMember) -> void:
	if game_state and game_state.current_ship:
		game_state.current_ship.add_crew_member(character)

func remove_crew_member(character: CrewMember) -> void:
	if game_state and game_state.current_ship:
		game_state.current_ship.remove_crew_member(character)

# Game State Management
func start_new_game() -> void:
	game_state = GameStateResource.new()
	transition_to_state(GlobalEnums.GameState.SETUP)

func load_game() -> void:
	if FileAccess.file_exists("user://savegame.json"):
		var file = FileAccess.open("user://savegame.json", FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			var save_data = json.get_data()
			game_state.deserialize(save_data)
			transition_to_state(GlobalEnums.GameState.CAMPAIGN)

func save_game() -> void:
	if game_state:
		var save_data = game_state.serialize()
		var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(save_data))
		file.close()

# Tutorial Management
func start_tutorial_campaign(tutorial_type: GlobalEnums.TutorialType, track: GlobalEnums.TutorialTrack = GlobalEnums.TutorialTrack.CORE_RULES) -> void:
	current_tutorial_type = tutorial_type
	current_tutorial_track = track
	current_tutorial_stage = GlobalEnums.TutorialStage.INTRODUCTION
	game_state.is_tutorial_active = true
	
	tutorial_system.start_tutorial(tutorial_type)
	
	match tutorial_type:
		GlobalEnums.TutorialType.QUICK_START:
			_setup_quick_start_tutorial()
		GlobalEnums.TutorialType.ADVANCED:
			_setup_advanced_tutorial()
		GlobalEnums.TutorialType.BATTLE:
			_setup_battle_tutorial()
		GlobalEnums.TutorialType.CAMPAIGN:
			_setup_campaign_tutorial()
		GlobalEnums.TutorialType.STORY:
			_setup_story_tutorial()

func _setup_quick_start_tutorial() -> void:
	# Basic setup with predefined crew and simple mission
	var setup = {
		"crew_size": 3,
		"difficulty": GlobalEnums.DifficultyMode.EASY,
		"mission_type": GlobalEnums.MissionType.TUTORIAL,
		"victory_condition": GlobalEnums.VictoryConditionType.TURNS
	}
	_configure_tutorial_campaign(setup)

func _setup_advanced_tutorial() -> void:
	# More complex setup with full crew management
	var setup = {
		"crew_size": 5,
		"difficulty": GlobalEnums.DifficultyMode.NORMAL,
		"mission_type": GlobalEnums.MissionType.TUTORIAL,
		"enable_advanced_features": true
	}
	_configure_tutorial_campaign(setup)

func advance_tutorial_stage() -> void:
	var current_stage = current_tutorial_stage
	current_tutorial_stage = GlobalEnums.TutorialStage.values()[(current_stage + 1) % GlobalEnums.TutorialStage.size()]
	
	if current_tutorial_stage == GlobalEnums.TutorialStage.INTRODUCTION:
		# We've wrapped around, tutorial is complete
		complete_current_tutorial()

func complete_current_tutorial() -> void:
	if not completed_tutorials.has(current_tutorial_track):
		completed_tutorials[current_tutorial_track] = []
	completed_tutorials[current_tutorial_track].append(current_tutorial_type)
	
	game_state.is_tutorial_active = false
	tutorial_completed.emit()
	
	# Transition to appropriate game phase
	if current_tutorial_type == GlobalEnums.TutorialType.QUICK_START:
		_start_world_phase()
	else:
		transition_to_state(GlobalEnums.GameState.CAMPAIGN)

func reset_turn_specific_data() -> void:
	game_state.reset_turn_specific_data()
	mission_generator.refresh_available_missions()
	patron_job_manager.refresh_available_jobs()
	fringe_world_strife_manager.update_strife()

func advance_campaign_phase() -> void:
	var current_phase = campaign_state.current_state
	if game_state.is_tutorial_active:
		story_track.progress_story(current_phase)
	else:
		var phases = GlobalEnums.CampaignPhase.values()
		var next_phase_index = (phases.find(current_phase) + 1) % phases.size()
		campaign_state.current_state = phases[next_phase_index]

func _setup_battle_tutorial() -> void:
	var setup = {
		"enemy_count": 2,
		"terrain_type": GlobalEnums.TerrainType.CITY,
		"objective": GlobalEnums.MissionObjective.DEFEND,
		"mission_type": GlobalEnums.MissionType.TUTORIAL,
		"difficulty": GlobalEnums.DifficultyMode.EASY
	}
	_configure_tutorial_campaign(setup)

func _setup_campaign_tutorial() -> void:
	var setup = {
		"crew_size": 4,
		"difficulty": GlobalEnums.DifficultyMode.NORMAL,
		"victory_condition": GlobalEnums.VictoryConditionType.TURNS,
		"mission_type": GlobalEnums.MissionType.TUTORIAL,
		"enable_faction_mechanics": false
	}
	_configure_tutorial_campaign(setup)

func _setup_story_tutorial() -> void:
	var layout = story_track.get_story_layout("introduction")
	var setup = {
		"type": GlobalEnums.MissionType.TUTORIAL,
		"story_elements": layout.story_elements,
		"battlefield": layout.terrain,
		"objectives": layout.objectives,
		"enemies": layout.enemies,
		"crew_size": 3
	}
	_configure_tutorial_campaign(setup)

func _configure_tutorial_campaign(setup: Dictionary) -> void:
	# Configure game state
	game_state.crew_size = setup.get("crew_size", 4)
	game_state.difficulty_mode = setup.get("difficulty", GlobalEnums.DifficultyMode.NORMAL)
	game_state.victory_condition = setup.get("victory_condition", GlobalEnums.VictoryConditionType.TURNS)
	
	# Initialize tutorial mission
	var mission = Mission.new()
	mission.initialize_tutorial(setup)
	
	# Set up initial crew if needed
	if game_state.current_ship.crew.is_empty():
		var character_creation = load("res://Resources/CharacterCreationLogic.gd").new()
		var tutorial_character = character_creation.create_tutorial_character()
		game_state.current_ship.add_crew_member(tutorial_character)
	
	# Start tutorial phase
	transition_to_state(GlobalEnums.GameState.TUTORIAL)
	_start_tutorial_phase()

func _on_tutorial_step_changed(step_id: String) -> void:
	tutorial_step_changed.emit(step_id)

func _on_tutorial_completed(track_id: String) -> void:
	tutorial_completed.emit()
	game_state.is_tutorial_active = false
	_start_world_phase()

func _on_tutorial_step_completed() -> void:
	tutorial_step_completed.emit()

func _on_tutorial_track_completed(track_id: String) -> void:
	tutorial_track_completed.emit(track_id)

func _start_world_phase() -> void:
	if not game_state:
		push_error("Game state not initialized")
		return
		
	game_state.current_state = GlobalEnums.GameState.CAMPAIGN
	main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.WORLD_STEP
	
	# Initialize world phase systems
	world_generator.generate_current_world()
	expanded_faction_manager.update_factions()
	mission_generator.refresh_available_missions()
	patron_job_manager.refresh_available_jobs()
	
	# Emit state change
	state_changed.emit(GlobalEnums.GameState.CAMPAIGN)

func _start_tutorial_phase() -> void:
	if not game_state:
		push_error("Game state not initialized")
		return
		
	game_state.current_state = GlobalEnums.GameState.TUTORIAL
	game_state.is_tutorial_active = true
	
	# Initialize tutorial specific settings
	settings["difficulty"] = GlobalEnums.DifficultyMode.EASY
	settings["enable_tutorials"] = true
	
	# Setup initial tutorial state
	match current_tutorial_type:
		GlobalEnums.TutorialType.QUICK_START:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.CREW_CREATION
		GlobalEnums.TutorialType.BATTLE:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.BATTLE
		GlobalEnums.TutorialType.CAMPAIGN:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.WORLD_STEP
		_:
			main_game_state.current_campaign_phase = GlobalEnums.CampaignPhase.CREW_CREATION
	
	# Emit state change
	state_changed.emit(GlobalEnums.GameState.TUTORIAL)
