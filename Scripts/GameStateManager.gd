extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal battle_processed(battle_won: bool)
signal tutorial_ended
signal battle_started(battle_instance)

const BATTLE_SCENE := preload("res://Scenes/Scene Container/Battle.tscn")
const POST_BATTLE_SCENE := preload("res://Scenes/Scene Container/PostBattle.tscn")
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

func _ready() -> void:
	game_state = GameState.new()
	initialize_managers()

func _get(property: StringName):
	return game_state.get(property)

func _set(property: StringName, value) -> bool:
	if game_state.has(property):
		game_state.set(property, value)
		return true
	return false

func _get_property_list() -> Array:
	return game_state.get_property_list()

func get_game_state() -> GameState:
	if game_state == null:
		game_state = GameState.new()
	return game_state

func transition_to_state(new_state: GlobalEnums.CampaignPhase) -> void:
	game_state.current_state = new_state
	state_changed.emit(new_state)

func start_new_game() -> void:
	game_state = GameState.new()
	game_state.current_state = GlobalEnums.CampaignPhase.CREW_CREATION
	get_tree().change_scene_to_file(INITIAL_CREW_CREATION_SCENE)

func start_battle() -> void:
	var battle_instance = BATTLE_SCENE.instantiate()
	battle_instance.initialize(self, game_state.current_mission)
	battle_started.emit(battle_instance)
	transition_to_state(GlobalEnums.CampaignPhase.BATTLE)

func end_battle(player_victory: bool, scene_tree: SceneTree) -> void:
	game_state.current_mission.set_completed(player_victory)
	game_state.last_mission_results = "victory" if player_victory else "defeat"
	
	var post_battle_scene = POST_BATTLE_SCENE.instantiate()
	post_battle_scene.initialize(self)
	scene_tree.root.add_child(post_battle_scene)
	
	post_battle_scene.execute_post_battle_sequence()
	
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
