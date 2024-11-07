extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal battle_processed(battle_won: bool)
signal tutorial_ended
signal battle_started(battle_instance)
signal settings_changed

const BATTLE_SCENE := preload("res://Resources/BattlePhase/Scenes/Battle.tscn")
const POST_BATTLE_SCENE := preload("res://Resources/BattlePhase/PreBattle.tscn")
const INITIAL_CREW_CREATION_SCENE := "res://Scenes/Management/InitialCrewCreation.tscn"

var game_state: GameState
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var current_battle: Battle
var fringe_world_strife_manager: FringeWorldStrifeManager
var psionic_manager: PsionicManager
var story_track: StoryTrack
var world_generator: WorldGenerator
var expanded_faction_manager: ExpandedFactionManager
var combat_manager: CombatManager
var battle_state_machine: BattleStateMachine
var campaign_state_machine: CampaignStateMachine
var main_game_state_machine: MainGameStateMachine

var settings: Dictionary = {
	"disable_tutorial_popup": false
}

func _ready() -> void:
	game_state = GameState.new()
	initialize_managers()
	initialize_state_machines()
	_load_settings()

func initialize_managers() -> void:
	mission_generator = MissionGenerator.new(self)
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new(game_state)
	fringe_world_strife_manager = FringeWorldStrifeManager.new()
	psionic_manager = PsionicManager.new()
	story_track = StoryTrack.new()
	world_generator = WorldGenerator.new()
	expanded_faction_manager = ExpandedFactionManager.new()
	combat_manager = CombatManager.new()

func initialize_state_machines() -> void:
	battle_state_machine = BattleStateMachine.new()
	campaign_state_machine = CampaignStateMachine.new()
	main_game_state_machine = MainGameStateMachine.new()
	
	battle_state_machine.initialize(self)
	campaign_state_machine.initialize(self)
	main_game_state_machine.initialize(self)

func get_current_campaign_phase() -> GlobalEnums.CampaignPhase:
	return game_state.current_state

func transition_to_state(new_state: GlobalEnums.CampaignPhase) -> void:
	game_state.current_state = new_state
	state_changed.emit(new_state)

func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			settings = json.get_data()

func save_settings() -> void:
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
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
