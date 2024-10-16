class_name World
extends Node

signal world_step_completed

<<<<<<< HEAD
var game_state: GameState
=======
# Constants
const BASE_UPKEEP_COST: int = 10
const ADDITIONAL_CREW_COST: int = 2
const LOCAL_EVENT_CHANCE: float = 0.2

# Variables
var game_state_manager: GameStateManager
>>>>>>> parent of 1efa334 (worldphase functionality)
var world_step: WorldStep

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	world_step = WorldStep.new(game_state)

<<<<<<< HEAD
=======
# Initialization and Setup
func _init(_game_state_manager: GameStateManager) -> void:
	game_state_manager = _game_state_manager
	world_step = WorldStep.new(game_state_manager.game_state)
	world_economy_manager = WorldEconomyManager.new(game_state_manager.current_location, game_state_manager.economy_manager)
	world_generator = WorldGenerator.new()
	world_generator.initialize(game_state_manager)

func _ready() -> void:
	world_step.phase_completed.connect(_on_phase_completed)
	world_step.mission_selection_requested.connect(_on_mission_selection_requested)
	world_economy_manager.local_event_triggered.connect(_on_local_event_triggered)
	world_economy_manager.economy_updated.connect(_on_economy_updated)

# Public Methods
>>>>>>> parent of 1efa334 (worldphase functionality)
func execute_world_step() -> void:
	print("Beginning world step...")
	
	handle_upkeep_and_repairs()
	assign_and_resolve_crew_tasks()
	determine_job_offers()
	assign_equipment()
	resolve_rumors()
	choose_battle()
	
	print("World step completed.")
	world_step_completed.emit()

func handle_upkeep_and_repairs() -> void:
	var upkeep_cost = calculate_upkeep_cost()
	if game_state.current_crew.pay_upkeep(upkeep_cost):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		game_state.current_crew.decrease_morale()
	
	var repair_amount = game_state.current_crew.ship.auto_repair()
	print("Ship auto-repaired %d hull points" % repair_amount)

func calculate_upkeep_cost() -> int:
	var crew_size = game_state.current_crew.get_member_count()
	var base_cost = 1  # Base cost for crews of 4-6 members
	var additional_cost = max(0, crew_size - 6)
	return base_cost + additional_cost

func assign_and_resolve_crew_tasks() -> void:
	for member in game_state.current_crew.members:
		if member.is_available():
			var task = choose_task(member)
			world_step.resolve_task(member, task)

func choose_task(character: Character) -> String:
	var available_tasks = ["Trade", "Explore", "Train", "Recruit", "Find Patron", "Repair", "Decoy"]
	return available_tasks[randi() % available_tasks.size()]

func determine_job_offers() -> void:
	var available_patrons = game_state.patrons.filter(func(patron): return patron.has_available_jobs())
	for patron in available_patrons:
		var job = patron.generate_job()
		game_state.add_mission(job)
		print("New job offer from %s: %s" % [patron.name, job.title])

func assign_equipment() -> void:
	for member in game_state.current_crew.members:
		member.optimize_equipment()
	print("Equipment has been optimized for all crew members.")

func resolve_rumors() -> void:
	if game_state.rumors.size() > 0:
		var rumor_roll = randi() % 6 + 1
		if rumor_roll <= game_state.rumors.size():
			var chosen_rumor = game_state.rumors[randi() % game_state.rumors.size()]
			var new_mission = game_state.mission_generator.generate_mission_from_rumor(chosen_rumor)
			game_state.add_mission(new_mission)
			game_state.remove_rumor(chosen_rumor)
			print("A rumor has developed into a new mission: %s" % new_mission.title)

func choose_battle() -> void:
	var available_missions = game_state.available_missions
	if available_missions.size() > 0:
		var chosen_mission = available_missions[randi() % available_missions.size()]
		print("Chosen mission: %s" % chosen_mission.title)
		game_state.current_mission = chosen_mission
	else:
		print("No available missions. Generating a random encounter.")
		var random_encounter = game_state.mission_generator.generate_random_encounter()
		game_state.current_mission = random_encounter
		print("Random encounter generated: %s" % random_encounter.title)

func get_world_traits() -> Array[String]:
	return game_state.current_location.get_traits()

func apply_world_trait_effects() -> void:
	var traits = get_world_traits()
	for trait in traits:
		match trait:
			"Haze":
				game_state.current_battle.visibility = randi() % 6 + 8
			"Overgrown":
				game_state.current_battle.add_vegetation(randi() % 6 + 2)
			"Warzone":
				game_state.current_battle.add_ruins(randi() % 3)
			"Heavily enforced":
				game_state.current_battle.modify_enemy_count(-1)
			"Rampant crime":
				game_state.current_battle.modify_enemy_count(1)
			"Invasion risk":
				game_state.invasion_roll_modifier += 1
			"Imminent invasion":
				game_state.invasion_roll_modifier += 2
			"Lacks starship facilities":
				game_state.max_repair_credits = 3
			"Easy recruiting":
				game_state.recruit_roll_modifier += 1
			"Medical science":
				game_state.accelerated_medical_care_cost = 3
			"Technical knowledge":
				game_state.repair_roll_modifier += 1
			"Opportunities":
				game_state.patron_search_roll_modifier += 1
			"Booming economy":
				game_state.reroll_ones_on_rewards = true
			"Busy markets":
				game_state.enable_extra_trade_action()
			"Bureaucratic mess":
				game_state.enable_departure_roll()
			"Restricted education":
				game_state.advanced_training_difficulty = 6
			"Expensive education":
				game_state.advanced_training_cost = 3
			"Travel restricted":
				game_state.max_explore_actions = 1
			"Unity safe sector":
				game_state.disable_invasion()
			"Gloom":
				game_state.current_battle.visibility = randi() % 6 + 6
			"Bot manufacturing":
				game_state.bot_upgrade_discount = 1
			"Fuel refinery":
				game_state.travel_cost = 3
			"Alien species restricted":
				game_state.restrict_random_alien_species()
			"Weapon licensing":
				game_state.weapon_cost_modifier = 1
			"Import restrictions":
				game_state.disable_item_selling()
			"Military outpost":
				game_state.invasion_roll_modifier += 2
				game_state.war_progress_modifier += 2
			"Dangerous":
				game_state.current_battle.modify_enemy_count(1)
			"Shipyards":
				game_state.ship_component_discount = 2
			"Barren":
				game_state.current_battle.disable_plant_features()
			"Vendetta system":
				game_state.rival_chance_range = 2
			"Free trade zone":
				game_state.enable_double_trade_rolls()
			"Corporate state":
				game_state.patron_search_roll_modifier += 2
				game_state.set_all_patrons_corporate()
			"Adventurous population":
				game_state.enable_extra_recruit_option()
			"Frozen":
				game_state.current_battle.enable_ice_sliding()
			"Flat":
				game_state.current_battle.disable_elevated_terrain()
			"Fuel shortage":
				game_state.travel_cost += randi() % 3 + 1
			"Reflective dust":
				game_state.current_battle.add_energy_weapon_penalty()
			"High cost":
				game_state.upkeep_crew_size_modifier = 2
			"Interdiction":
				game_state.set_stay_duration(randi() % 3 + 1)
			"Null zone":
				game_state.disable_teleportation()
			"Crystals":
				game_state.current_battle.add_crystals(randi() % 6 + randi() % 6)
			"Fog":
				game_state.current_battle.add_fog_penalty()

func serialize() -> Dictionary:
	return {
		"game_state": game_state.serialize()
	}

static func deserialize(data: Dictionary) -> World:
	var world = World.new(GameState.deserialize(data["game_state"]))
	return world
