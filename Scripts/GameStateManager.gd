extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal battle_processed(battle_won: bool)
signal tutorial_ended
signal battle_started(battle_instance)

var game_state: GameStateManager

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

var battle_scene: PackedScene = preload("res://Scenes/Scene Container/Battle.tscn")

func _ready() -> void:
    game_state = GameStateManager.new()
    initialize_managers()

func initialize_managers() -> void:
    mission_generator = MissionGenerator.new()
    expanded_faction_manager = ExpandedFactionManager.new()
    equipment_manager = EquipmentManager.new()
    patron_job_manager = PatronJobManager.new()
    fringe_world_strife_manager = FringeWorldStrifeManager.new()
    psionic_manager = PsionicManager.new()
    world_generator = WorldGenerator.new()
    combat_manager = CombatManager.new()

    var managers_to_initialize = [
        mission_generator, expanded_faction_manager, equipment_manager,
        patron_job_manager, fringe_world_strife_manager, psionic_manager,
        world_generator, combat_manager
    ]

    for manager in managers_to_initialize:
        if manager.has_method("initialize"):
            manager.initialize(self)

func get_game_state() -> GameStateManager:
    return game_state

func transition_to_state(new_state: GlobalEnums.CampaignPhase) -> void:
    game_state.current_state = new_state
    state_changed.emit(new_state)

func update_mission_list() -> void:
    game_state.available_missions = mission_generator.generate_missions(game_state)

# ... Other methods, accessing game_state instead of direct properties

func start_battle() -> void:
    var battle_instance = battle_scene.instantiate()
    battle_instance.initialize(self, game_state.current_mission)
    battle_started.emit(battle_instance)
    transition_to_state(GlobalEnums.CampaignPhase.BATTLE)

func end_battle(player_victory: bool, scene_tree: SceneTree) -> void:
    game_state.current_mission.set_completed(player_victory)
    game_state.last_mission_results = "victory" if player_victory else "defeat"
    
    var post_battle_scene = load("res://Scenes/Scene Container/PostBattle.tscn").instantiate()
    post_battle_scene.initialize(self)
    scene_tree.root.add_child(post_battle_scene)
    
    post_battle_scene.execute_post_battle_sequence()
    
    transition_to_state(GlobalEnums.CampaignPhase.POST_BATTLE)
    
    if scene_tree.root.has_node("Battle"):
        scene_tree.root.get_node("Battle").queue_free()

func handle_character_recovery() -> void:
    for character in game_state.current_ship.crew:
        character.health = min(character.health + 20, character.max_health)
        character.stress = max(character.stress - 10, 0)

func end_tutorial() -> void:
    game_state.is_tutorial_active = false
    tutorial_ended.emit()

func process_battle(battle_won: bool) -> void:
    if battle_won:
        game_state.current_mission.complete()
    else:
        game_state.current_mission.fail()
    
    battle_processed.emit(battle_won)
    
    if battle_won:
        handle_character_recovery()
    
    current_battle = null

# ... Add any additional methods that were in the original GameStateManager