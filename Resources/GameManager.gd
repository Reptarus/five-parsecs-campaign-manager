# GameManager.gd
class_name GameManager
extends Node

signal game_state_changed(new_state: GameState.State)

var game_state: GameState
var ui_manager: UIManager
var combat_manager: CombatManager
var world_generator: WorldGenerator
var terrain_generator: TerrainGenerator

func _init(_game_state: GameState, _ui_manager: UIManager):
	game_state = _game_state
	ui_manager = _ui_manager
	combat_manager = CombatManager.new(game_state)
	world_generator = WorldGenerator.new(game_state)
	terrain_generator = TerrainGenerator.new(game_state)

func start_new_game():
	game_state.change_state(GameState.State.CREW_CREATION)
	ui_manager.change_screen("campaign_setup")

func start_campaign_turn():
	game_state.change_state(GameState.State.CAMPAIGN_TURN)
	game_state.advance_turn()
	ui_manager.change_screen("world_view")


func start_mission(mission: Mission):
	game_state.current_mission = mission
	game_state.change_state(GameState.State.MISSION)
	ui_manager.change_screen("battle")
	combat_manager.setup_battle(mission)

func end_mission(victory: bool):
	game_state.change_state(GameState.State.POST_MISSION)
	ui_manager.change_screen("post_battle")
	process_mission_results(victory)

func process_mission_results(victory: bool):
	if victory:
		game_state.add_credits(game_state.current_mission.reward)
		game_state.current_crew.gain_experience(game_state.current_mission.xp_reward)
	else:
		game_state.current_crew.apply_casualties()
	
	game_state.remove_mission(game_state.current_mission)
	game_state.current_mission = null

func generate_new_world():
	var new_world = world_generator.generate_world()
	game_state.available_locations.append(new_world)

func travel_to_world(world: Location):
	game_state.current_location = world
	ui_manager.update_world_info()

func recruit_crew_member(character: Character):
	game_state.current_crew.add_member(character)
	ui_manager.update_crew_info()

func upgrade_character(character: Character, upgrade: String):
	character.apply_upgrade(upgrade)
	ui_manager.update_crew_info()

func buy_equipment(item: Equipment):
	if game_state.remove_credits(item.cost):
		game_state.current_crew.add_equipment(item)
		ui_manager.update_crew_info()

func sell_equipment(item: Equipment):
	game_state.add_credits(item.sell_value)
	game_state.current_crew.remove_equipment(item)
	ui_manager.update_crew_info()

func handle_game_over(victory: bool):
	ui_manager.show_game_over_screen(victory)
	game_state_changed.emit(GameState.State.MAIN_MENU)

func generate_battlefield():
	terrain_generator.generate_terrain()
	terrain_generator.generate_features()
	terrain_generator.generate_cover()
	terrain_generator.generate_loot()
	terrain_generator.generate_enemies()
	terrain_generator.generate_npcs()
	terrain_generator.generate_events()
	terrain_generator.generate_encounters()
	terrain_generator.generate_missions()
