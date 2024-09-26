# GameManager.gd
class_name GameManager
extends Node

signal game_state_changed(new_state: GlobalEnums.CampaignPhase)

@export var mob_scene: PackedScene
@export var battle_scene: PackedScene
@export var game_over_scene: PackedScene  # Add this line

var game_state: GameStateManager
var ui_manager: UIManager
var combat_manager: CombatManager
var world_generator: WorldGenerator
var terrain_generator: TerrainGenerator
var mission_generator: MissionGenerator
var equipment_manager: EquipmentManager
var patron_job_manager: PatronJobManager
var fringe_world_strife_manager: FringeWorldStrifeManager
var psionic_manager: PsionicManager
var expanded_faction_manager: ExpandedFactionManager

func _init(_game_state: GameStateManager, _ui_manager: UIManager):
	game_state = _game_state
	ui_manager = _ui_manager
	initialize_managers()

func initialize_managers():
	combat_manager = CombatManager.new()
	world_generator = WorldGenerator.new()
	terrain_generator = TerrainGenerator.new()
	mission_generator = MissionGenerator.new()
	equipment_manager = EquipmentManager.new()
	patron_job_manager = PatronJobManager.new()
	fringe_world_strife_manager = FringeWorldStrifeManager.new()
	psionic_manager = PsionicManager.new()
	expanded_faction_manager = ExpandedFactionManager.new()

	var managers_to_initialize = [
		combat_manager, world_generator, terrain_generator, mission_generator,
		equipment_manager, patron_job_manager, fringe_world_strife_manager,
		psionic_manager, expanded_faction_manager
	]

	for manager in managers_to_initialize:
		if manager.has_method("initialize"):
			manager.initialize(game_state)
			
func start_new_game():
	game_state.change_state(GlobalEnums.CampaignPhase.CREW_CREATION)
	ui_manager.change_screen("campaign_setup")
	game_state.set_crew_size(5)  # Default crew size, can be adjusted

func start_campaign_turn():
	game_state.change_state(GlobalEnums.CampaignPhase.UPKEEP)
	game_state.advance_turn()
	ui_manager.change_screen("world_view")
	game_state.update_mission_list()

func start_mission(mission: Mission):
	if mission.start_mission(game_state.get_current_crew().members):
		game_state.current_mission = mission
		game_state.change_state(GlobalEnums.CampaignPhase.MISSION)
		ui_manager.change_screen("battle")
		combat_manager.setup_battle(mission)
		generate_battlefield()
	else:
		ui_manager.show_message("Cannot start mission. Check crew requirements.")

func end_mission(victory: bool):
	game_state.change_state(GlobalEnums.CampaignPhase.POST_BATTLE)
	ui_manager.change_screen("post_battle")
	process_mission_results(victory)

func process_mission_results(victory: bool):
	var rewards = game_state.current_mission.get_reward()
	if victory:
		game_state.add_credits(rewards.credits)
		game_state.current_crew.gain_experience(rewards.xp)
		handle_loot(rewards.loot)
	else:
		game_state.current_crew.apply_casualties()
	
	game_state.remove_mission(game_state.current_mission)
	game_state.current_mission = null
	check_campaign_progress()

func generate_new_world():
	var new_world = world_generator.generate_world()
	game_state.available_locations.append(new_world)

func travel_to_world(world: Location):
	game_state.current_location = world
	ui_manager.update_world_info()
	fringe_world_strife_manager.update_world_strife(world)

func recruit_crew_member(character: Character):
	if game_state.current_crew.can_add_member():
		game_state.current_crew.add_member(character)
		ui_manager.update_crew_info()
	else:
		ui_manager.show_message("Crew is at maximum capacity.")

func upgrade_character(character: Character, upgrade: String):
	if character.can_apply_upgrade(upgrade):
		character.apply_upgrade(upgrade)
		ui_manager.update_crew_info()
	else:
		ui_manager.show_message("Upgrade not available for this character.")

func buy_equipment(item: Equipment):
	if game_state.remove_credits(item.cost):
		game_state.current_crew.add_equipment(item)
		ui_manager.update_crew_info()
	else:
		ui_manager.show_message("Not enough credits to buy this item.")

func sell_equipment(item: Equipment):
	game_state.add_credits(item.sell_value)
	game_state.current_crew.remove_equipment(item)
	ui_manager.update_crew_info()

func handle_game_over(victory: bool):
	ui_manager.show_game_over_screen(victory)
	game_state_changed.emit(GlobalEnums.CampaignPhase.MAIN_MENU)
	get_tree().change_scene_to(game_over_scene)  # Add this line

func generate_battlefield():
	var battlefield_size = Vector2(24, 24)  # 24" x 24" battlefield as per rules
	terrain_generator.generate_terrain(battlefield_size)
	terrain_generator.generate_features()
	terrain_generator.generate_cover()
	terrain_generator.generate_loot()
	terrain_generator.generate_enemies()
	terrain_generator.generate_npcs()
	combat_manager.place_objectives()

func handle_loot(loot: Array):
	for item in loot:
		if item is Equipment:
			game_state.add_to_ship_stash(item)
	ui_manager.update_inventory()

func check_campaign_progress():
	if game_state.check_victory_conditions():
		handle_game_over(true)
	elif game_state.check_defeat_conditions():
		handle_game_over(false)

func roll_dice(num_dice: int, sides: int) -> int:
	var total := 0
	for i in range(num_dice):
		total += randi() % sides + 1
	return total

func handle_player_action(action: String, params: Dictionary = {}):
	match action:
		"move":
			combat_manager.handle_move(params.character, params.new_position)
		"attack":
			combat_manager.handle_attack(params.attacker, params.target)
		"end_turn":
			combat_manager.handle_end_turn()
		# Add more actions as needed

func start_battle(scene_tree: SceneTree):
	var battle_instance = battle_scene.instantiate()
	battle_instance.initialize(game_state, game_state.current_mission)
	scene_tree.root.add_child(battle_instance)
	game_state.change_state(GlobalEnums.CampaignPhase.BATTLE)
