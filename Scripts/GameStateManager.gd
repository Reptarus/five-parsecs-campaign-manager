extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal battle_processed(battle_won: bool)
signal tutorial_ended
signal battle_started(battle_instance)
signal settings_changed

const BATTLE_SCENE := preload("res://Scenes/Scene Container/Battle.tscn")
const POST_BATTLE_SCENE := preload("res://Scenes/Scene Container/PostBattle.tscn")
const INITIAL_CREW_CREATION_SCENE := "res://Scenes/Management/InitialCrewCreation.tscn"

const CAMPAIGN_STATE_MACHINE = preload("res://StateMachines/CampaignStateMachine.gd")
const BATTLE_STATE_MACHINE = preload("res://StateMachines/BattleStateMachine.gd")
const MAIN_GAME_STATE_MACHINE = preload("res://StateMachines/MainGameStateMachine.gd")

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

var main_game_state_machine: MainGameStateMachine
var campaign_state_machine: CampaignStateMachine
var battle_state_machine: BattleStateMachine

var settings: Dictionary = {
	"disable_tutorial_popup": false
}

var temp_data: Dictionary = {}

func _ready() -> void:
	load_settings()
	game_state = GameState.new()
	game_state.crew = Crew.new()
	game_state.crew.initialize()  # Assuming you have an initialize method in Crew
	game_state.current_mission = Mission.new()  # Make sure current_mission is initialized
	initialize_managers()
	initialize_state_machines()

func initialize_managers() -> void:
	mission_generator = MissionGenerator.new()
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new()
	fringe_world_strife_manager = FringeWorldStrifeManager.new()
	psionic_manager = PsionicManager.new()
	story_track = StoryTrack.new()
	world_generator = WorldGenerator.new()
	world_generator.initialize(self)
	expanded_faction_manager = ExpandedFactionManager.new(game_state)
	combat_manager = CombatManager.new()
	combat_manager.initialize(self, game_state.current_mission, get_current_battlefield())

func initialize_state_machines() -> void:
	main_game_state_machine = MainGameStateMachine.new()
	main_game_state_machine.initialize(self)
	
	campaign_state_machine = CampaignStateMachine.new()
	campaign_state_machine.call("initialize", self)
	
	battle_state_machine = BattleStateMachine.new()
	battle_state_machine.call("initialize", self)

func _get(property: StringName):
	if property in game_state:
		return game_state.get(property)
	return null

func _set(property: StringName, value) -> bool:
	if property in game_state:
		game_state.set(property, value)
		return true
	return false

func _get_property_list() -> Array:
	return game_state.get_property_list()

func get_game_state() -> GlobalEnums.CampaignPhase:
	return game_state.current_state

func get_current_campaign_phase() -> GlobalEnums.CampaignPhase:
	return game_state.current_state

func transition_to_state(new_state: GlobalEnums.CampaignPhase) -> void:
	game_state.current_state = new_state
	state_changed.emit(new_state)

func start_new_game() -> void:
	game_state = GameState.new()
	game_state.crew = Crew.new()
	game_state.current_state = GlobalEnums.CampaignPhase.CREW_CREATION
	get_tree().change_scene_to_file(INITIAL_CREW_CREATION_SCENE)

func start_battle() -> void:
	var battle_instance = BATTLE_SCENE.instantiate()
	battle_instance.call("initialize", self, game_state.current_mission)
	battle_started.emit(battle_instance)
	transition_to_state(GlobalEnums.CampaignPhase.BATTLE)

func end_battle(player_victory: bool, scene_tree: SceneTree) -> void:
	game_state.current_mission.set_completed(player_victory)
	game_state.last_mission_results = "victory" if player_victory else "defeat"
	
	var post_battle_scene = POST_BATTLE_SCENE.instantiate()
	post_battle_scene.call("initialize", self)
	scene_tree.root.add_child(post_battle_scene)
	
	post_battle_scene.call("execute_post_battle_sequence")
	
	transition_to_state(GlobalEnums.CampaignPhase.POST_BATTLE)
	
	if scene_tree.root.has_node("Battle"):
		scene_tree.root.get_node("Battle").queue_free()

func process_battle(battle_won: bool) -> void:
	if battle_won:
		game_state.current_mission.complete()
		handle_character_recovery()
	else:
		game_state.current_mission.fail()
	
	battle_processed.emit(battle_won)
	current_battle = null

func handle_character_recovery() -> void:
	for character in game_state.current_ship.crew:
		character.health = min(character.health + 20, character.max_health)
		character.stress = max(character.stress - 10, 0)

func end_tutorial() -> void:
	game_state.is_tutorial_active = false
	tutorial_ended.emit()

func serialize() -> Dictionary:
	return game_state.serialize()

func deserialize(data: Dictionary) -> void:
	game_state.deserialize(data)

func check_victory_conditions() -> bool:
	return game_state.check_victory_conditions()

func save_settings() -> void:
	var config = ConfigFile.new()
	for key in settings.keys():
		config.set_value("Settings", key, settings[key])
	
	var err = config.save("user://settings.cfg")
	if err != OK:
		push_error("Failed to save settings: " + str(err))
	else:
		settings_changed.emit()

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		push_warning("Failed to load settings, using defaults: " + str(err))
		return
	
	for key in settings.keys():
		if config.has_section_key("Settings", key):
			settings[key] = config.get_value("Settings", key)
	
	settings_changed.emit()

func get_setting(key: String):
	return settings.get(key)

func set_setting(key: String, value) -> void:
	if key in settings:
		settings[key] = value
		save_settings()
	else:
		push_warning("Attempted to set unknown setting: " + key)

func get_current_battlefield() -> TileMap:
	# Implement this method to return the current battlefield TileMap
	# This might involve getting it from the current mission, scene, or elsewhere
	# For now, we'll return null as a placeholder
	return null

func get_current_ship():
	if game_state and game_state.current_ship:
		return game_state.current_ship
	push_error("Current ship is not set in game state")
	return null

func get_crew() -> Array[CrewMember]:
	var current_ship = get_current_ship()
	if current_ship and current_ship.crew:
		return current_ship.crew.get_characters()
	else:
		push_warning("No crew available in current ship")
		return []
