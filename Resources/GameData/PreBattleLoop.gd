# PreBattleLoop.gd
extends Node

signal preparation_complete
signal deployment_ready
signal equipment_assigned

const PREPARATION_TIME := 3
const MAX_EQUIPMENT_PER_CHARACTER := 4

var game_state_manager: GameStateManager
var deployment_manager: Node
var equipment_manager: EquipmentManager
var terrain_generator: TerrainGenerator

func _init(_game_state_manager: GameStateManager) -> void:
	if not _game_state_manager:
		push_error("GameStateManager is required for PreBattleLoop")
		return
	game_state_manager = _game_state_manager
	_initialize_managers()

func _initialize_managers() -> void:
	deployment_manager = load("res://Resources/GameData/EnemyDeploymentManager.gd").new(game_state_manager)
	equipment_manager = game_state_manager.equipment_manager
	terrain_generator = TerrainGenerator.new()

func prepare_battle(mission: Mission) -> void:
	if not validate_mission(mission):
		push_error("Invalid mission for battle preparation")
		return
		
	var terrain = terrain_generator.generate_terrain(
		GlobalEnums.TerrainType.CITY,
		mission.terrain_type
	)
	deployment_manager.setup_deployment_zones(
		terrain,
		mission.deployment_type
	)
	
	equipment_manager.prepare_equipment_loadout(
		game_state_manager.game_state.active_crew,
		mission.difficulty
	)
	
	preparation_complete.emit()

func validate_mission(mission: Mission) -> bool:
	return (
		mission != null and
		mission.terrain_type in GlobalEnums.TerrainType.values() and
		mission.deployment_type in GlobalEnums.DeploymentType.values()
	)

func run_pre_battle_loop() -> void:
	print_debug("Beginning pre-battle preparations...")
	assign_crew_tasks(Array[Character])
	process_rumors()
	update_mission_availability()
	print_debug("Pre-battle preparations complete.")

func assign_crew_tasks(crew: Array[Character]) -> void:
	for member in crew:
		if member.status == GlobalEnums.CharacterStatus.HEALTHY:
			var task = choose_task(member)
			perform_task(member, task)

func choose_task(_character: Character) -> GlobalEnums.CrewTask:
	var available_tasks = GlobalEnums.CrewTask.values()
	return available_tasks[randi() % available_tasks.size()]

func perform_task(character: Character, task: GlobalEnums.CrewTask) -> void:
	match task:
		GlobalEnums.CrewTask.TRADE:
			trade(character)
		GlobalEnums.CrewTask.EXPLORE:
			explore(character)
		GlobalEnums.CrewTask.TRAIN:
			train(character)
		GlobalEnums.CrewTask.RECRUIT:
			recruit(character)
		GlobalEnums.CrewTask.FIND_PATRON:
			find_patron(character)
		GlobalEnums.CrewTask.REPAIR_KIT:
			repair(character)
		GlobalEnums.CrewTask.DECOY:
			rest(character)
		GlobalEnums.CrewTask.REST:
			rest(character)

func trade(character: Character) -> void:
	var roll := randi() % 100 + 1
	if roll < 30:
		var credits_earned := (randi() % 6 + 1) * 10 + 10
		game_state_manager.game_state.add_credits(credits_earned)
		print_debug("%s earned %d credits through trading." % [character.name, credits_earned])
	elif roll < 60:
		var item := generate_random_equipment()
		game_state_manager.get_current_ship().add_to_cargo(item)
		print_debug("%s acquired %s while trading." % [character.name, item.name])
	else:
		print_debug("%s couldn't find any good deals while trading." % character.name)

func explore(character: Character) -> void:
	var roll := randi() % 100 + 1
	if roll < 20:
		var rumor := generate_rumor()
		game_state_manager.game_state.add_rumor(rumor)
		print_debug("%s discovered a rumor: %s" % [character.name, rumor])
	elif roll < 40:
		var credits_found := (randi() % 3 + 1) * 5 + 5
		game_state_manager.game_state.add_credits(credits_found)
		print_debug("%s found %d credits while exploring." % [character.name, credits_found])
	elif roll < 60:
		var item := generate_random_equipment()
		game_state_manager.get_current_ship().add_to_cargo(item)
		print_debug("%s found %s while exploring." % [character.name, item.name])
	else:
		print_debug("%s had an uneventful exploration." % character.name)

func train(character: Character) -> void:
	var skill_to_improve: GlobalEnums.SkillType = GlobalEnums.SkillType.values()[randi() % GlobalEnums.SkillType.size()]
	var xp_gained := randi() % 3 + 1
	character.improve_skill(skill_to_improve, xp_gained)
	print_debug("%s trained %s and gained %d XP." % [character.name, GlobalEnums.SkillType.keys()[skill_to_improve], xp_gained])
func recruit(character: Character) -> void:
	var ship = game_state_manager.get_current_ship()
	if ship.crew.size() < ship.max_crew_size:
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit: CrewMember = game_state_manager.game_state.character_factory.create_random_character()
			ship.crew.append(new_recruit)
			print_debug("%s successfully recruited %s to join the crew." % [character.name, new_recruit.name])
		else:
			print_debug("%s couldn't find any suitable recruits." % character.name)
	else:
		print_debug("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.name)

func find_patron(character: Character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron: Patron = game_state_manager.patron_job_manager.create_random_patron()
		game_state_manager.game_state.add_patron(new_patron)
		print_debug("%s found a new patron: %s" % [character.name, new_patron.name])
	else:
		print_debug("%s couldn't find any patrons offering work." % character.name)

func repair(character: Character) -> void:
	var item_to_repair: Equipment = character.get_damaged_equipment()
	if item_to_repair:
		var repair_success: bool = randf() < 0.7  # 70% chance to successfully repair
		if repair_success:
			item_to_repair.repair()
			print_debug("%s successfully repaired %s." % [character.name, item_to_repair.name])
		else:
			print_debug("%s attempted to repair %s but failed." % [character.name, item_to_repair.name])
	else:
		var ship_repair_amount := randi() % 5 + 1
		game_state_manager.game_state.current_ship.repair(ship_repair_amount)
		print_debug("%s repaired the ship, restoring %d hull points." % [character.name, ship_repair_amount])

func rest(character: Character) -> void:
	var stress_recovered := randi() % 3 + 1
	character.reduce_stress(stress_recovered)
	if character.status == GlobalEnums.CharacterStatus.INJURED:
		character.heal(1)
		print_debug("%s rested and recovered 1 health point and %d stress." % [character.name, stress_recovered])
	else:
		print_debug("%s rested and recovered %d stress." % [character.name, stress_recovered])

func generate_random_equipment() -> Equipment:
	var equipment_type := randi() % 4
	match equipment_type:
		0: return generate_random_weapon()
		1: return generate_random_armor()
		2: return generate_random_gear()
		3: return generate_random_medical_item()
	return null  # This should never happen

func generate_random_weapon() -> Weapon:
	var weapon_types := GlobalEnums.WeaponType.values()
	var weapon_type: GlobalEnums.WeaponType = weapon_types[randi() % weapon_types.size()]
	var damage := randi() % 5 + 1
	var weapon_range := randi() % 10 + 1
	return Weapon.new(GlobalEnums.WeaponType.keys()[weapon_type], weapon_type, weapon_range, 1, damage)

func generate_random_armor() -> Equipment:
	var armor_types := GlobalEnums.ArmorType.values()
	var armor_type: GlobalEnums.ArmorType = armor_types[randi() % armor_types.size()]
	var defense := randi() % 5 + 1
	return Equipment.new(GlobalEnums.ArmorType.keys()[armor_type], GlobalEnums.ItemType.ARMOR, defense)

func generate_random_gear() -> Equipment:
	var gear_types: Array[String] = ["Medkit", "Repair Kit", "Stealth Field", "Jetpack"]
	var gear_name: String = gear_types[randi() % gear_types.size()]
	return Equipment.new(gear_name, GlobalEnums.ItemType.GEAR, 1)

func generate_random_medical_item() -> Equipment:
	var medical_types: Array[String] = ["Med-kit", "Stim-pack", "Nano-injector", "Trauma Pack"]
	var item_name: String = medical_types[randi() % medical_types.size()]
	var healing_value: int = randi() % 3 + 1
	return Equipment.new(item_name, GlobalEnums.ItemType.CONSUMABLE, healing_value)

func generate_rumor() -> String:
	var rumors := [
		"There's talk of a hidden alien artifact on a nearby moon.",
		"A notorious pirate captain is offering big credits for experienced crew.",
		"The local government is secretly funding illegal weapons research.",
		"An abandoned space station has been spotted in the outer reaches of the system.",
		"A wealthy trader is looking for protection on a dangerous cargo run."
	]
	return rumors[randi() % rumors.size()]

func process_rumors() -> void:
	for rumor in game_state_manager.game_state.rumors:
		if randf() < 0.2:  # 20% chance for a rumor to develop into a mission
			var mission: Mission = game_state_manager.mission_generator.generate_mission_from_rumor(rumor)
			game_state_manager.game_state.add_mission(mission)
			game_state_manager.game_state.remove_rumor(rumor)
			print_debug("A rumor has developed into a new mission: %s" % mission.title)

func update_mission_availability() -> void:
	for mission in game_state_manager.game_state.available_missions:
		if randf() < 0.1:  # 10% chance for a mission to become unavailable
			game_state_manager.game_state.remove_mission(mission)
			print_debug("The mission '%s' is no longer available." % mission.title)
	if game_state_manager.game_state.available_missions.size() < 3:
		var new_mission: Mission = game_state_manager.mission_generator.generate_mission(
			GlobalEnums.MissionType.OPPORTUNITY
		)
		game_state_manager.game_state.add_mission(new_mission)
		print_debug("A new mission has become available: %s" % new_mission.title)
