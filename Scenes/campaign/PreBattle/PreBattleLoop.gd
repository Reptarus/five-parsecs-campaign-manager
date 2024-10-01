# PreBattleLoop.gd
extends Node

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func run_pre_battle_loop() -> void:
	print_debug("Beginning pre-battle preparations...")
	assign_crew_tasks(game_state.current_crew)
	process_rumors()
	update_mission_availability()
	print_debug("Pre-battle preparations complete.")

func assign_crew_tasks(crew: Crew) -> void:
	for member in crew.get_members():
		if member.is_available():
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

func trade(character: Character) -> void:
	var roll := GameManager.roll_dice(1, 100)
	if roll < 30:
		var credits_earned := GameManager.roll_dice(1, 6) * 10 + 10
		game_state.add_credits(credits_earned)
		print_debug("%s earned %d credits through trading." % [character.get_name(), credits_earned])
	elif roll < 60:
		var item := generate_random_equipment()
		character.add_equipment(item)
		print_debug("%s acquired %s while trading." % [character.get_name(), item.get_name()])
	else:
		print_debug("%s couldn't find any good deals while trading." % character.get_name())

func explore(character: Character) -> void:
	var roll := GameManager.roll_dice(1, 100)
	if roll < 20:
		var rumor := generate_rumor()
		game_state.add_rumor(rumor)
		print_debug("%s discovered a rumor: %s" % [character.get_name(), rumor])
	elif roll < 40:
		var credits_found := GameManager.roll_dice(1, 3) * 5 + 5
		game_state.add_credits(credits_found)
		print_debug("%s found %d credits while exploring." % [character.get_name(), credits_found])
	elif roll < 60:
		var item := generate_random_equipment()
		character.add_equipment(item)
		print_debug("%s found %s while exploring." % [character.get_name(), item.get_name()])
	else:
		print_debug("%s had an uneventful exploration." % character.get_name())

func train(character: Character) -> void:
	var skill_to_improve: GlobalEnums.SkillType = character.get_random_skill()
	var xp_gained := GameManager.roll_dice(1, 3)
	character.improve_skill(skill_to_improve, xp_gained)
	print_debug("%s trained %s and gained %d XP." % [character.get_name(), GlobalEnums.SkillType.keys()[skill_to_improve], xp_gained])

func recruit(character: Character) -> void:
	var crew: Crew = game_state.current_crew
	if crew.get_member_count() < crew.get_max_members():
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit: Character = game_state.character_factory.create_random_character()
			crew.add_member(new_recruit)
			print_debug("%s successfully recruited %s to join the crew." % [character.get_name(), new_recruit.get_name()])
		else:
			print_debug("%s couldn't find any suitable recruits." % character.get_name())
	else:
		print_debug("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.get_name())

func find_patron(character: Character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron: Patron = game_state.patron_factory.create_random_patron()
		game_state.add_patron(new_patron)
		print_debug("%s found a new patron: %s" % [character.get_name(), new_patron.get_name()])
	else:
		print_debug("%s couldn't find any patrons offering work." % character.get_name())

func repair(character: Character) -> void:
	var item_to_repair: Equipment = character.get_damaged_equipment()
	if item_to_repair:
		var repair_success: bool = randf() < 0.7  # 70% chance to successfully repair
		if repair_success:
			item_to_repair.repair()
			print_debug("%s successfully repaired %s." % [character.get_name(), item_to_repair.get_name()])
		else:
			print_debug("%s attempted to repair %s but failed." % [character.get_name(), item_to_repair.get_name()])
	else:
		var ship_repair_amount := GameManager.roll_dice(1, 5)
		game_state.current_ship.repair(ship_repair_amount)
		print_debug("%s repaired the ship, restoring %d hull points." % [character.get_name(), ship_repair_amount])

func rest(character: Character) -> void:
	var stress_recovered := GameManager.roll_dice(1, 3)
	character.reduce_stress(stress_recovered)
	if character.is_injured():
		character.heal(1)
		print_debug("%s rested and recovered 1 health point and %d stress." % [character.get_name(), stress_recovered])
	else:
		print_debug("%s rested and recovered %d stress." % [character.get_name(), stress_recovered])

func generate_random_equipment() -> Equipment:
	var equipment_type := GameManager.roll_dice(1, 4) - 1
	match equipment_type:
		0: return generate_random_weapon()
		1: return generate_random_armor()
		2: return generate_random_gear()
		3: return generate_random_medical_item()
	return null  # This should never happen

func generate_random_weapon() -> Weapon:
	var weapon_types := GlobalEnums.WeaponType.values()
	var weapon_type_index := GameManager.roll_dice(1, weapon_types.size()) - 1
	var weapon_type: GlobalEnums.WeaponType = weapon_types[weapon_type_index]
	var damage := GameManager.roll_dice(1, 5)
	var weapon_range := GameManager.roll_dice(1, 10)
	return Weapon.new(GlobalEnums.WeaponType.keys()[weapon_type_index], weapon_type, weapon_range, 1, damage)

func generate_random_armor() -> Equipment:
	var armor_types := GlobalEnums.ArmorType.values()
	var armor_type_index := GameManager.roll_dice(1, armor_types.size()) - 1
	var _armor_type: GlobalEnums.ArmorType = armor_types[armor_type_index]
	var defense := GameManager.roll_dice(1, 5)
	return Equipment.new(GlobalEnums.ArmorType.keys()[armor_type_index], GlobalEnums.ItemType.ARMOR, defense)

func generate_random_gear() -> Gear:
	var gear_types: Array[String] = ["Medkit", "Repair Kit", "Stealth Field", "Jetpack"]
	var gear_name: String = gear_types[GameManager.roll_dice(1, gear_types.size()) - 1]
	return Gear.new(gear_name, "A useful piece of equipment", Gear.GearType.UTILITY, 1)

func generate_random_medical_item() -> Equipment:
	var medical_types: Array[String] = ["Med-kit", "Stim-pack", "Nano-injector", "Trauma Pack"]
	var item_name: String = medical_types[GameManager.roll_dice(1, medical_types.size()) - 1]
	var healing_value: int = GameManager.roll_dice(1, 3)
	return Equipment.new(item_name, GlobalEnums.ItemType.CONSUMABLE, healing_value)

func generate_rumor() -> String:
	var rumors := [
		"There's talk of a hidden alien artifact on a nearby moon.",
		"A notorious pirate captain is offering big credits for experienced crew.",
		"The local government is secretly funding illegal weapons research.",
		"An abandoned space station has been spotted in the outer reaches of the system.",
		"A wealthy trader is looking for protection on a dangerous cargo run."
	]
	return rumors[GameManager.roll_dice(1, rumors.size()) - 1]

func process_rumors() -> void:
	for rumor in game_state.rumors:
		if randf() < 0.2:  # 20% chance for a rumor to develop into a mission
			var mission: Mission = game_state.mission_generator.generate_mission_from_rumor(rumor)
			game_state.add_mission(mission)
			game_state.remove_rumor(rumor)
			print_debug("A rumor has developed into a new mission: %s" % mission.title)

func update_mission_availability() -> void:
	for mission in game_state.available_missions:
		if randf() < 0.1:  # 10% chance for a mission to become unavailable
			game_state.remove_mission(mission)
			print_debug("The mission '%s' is no longer available." % mission.title)
	if game_state.available_missions.size() < 3:
		var new_mission: Mission = game_state.mission_generator.generate_mission()
		game_state.add_mission(new_mission)
		print_debug("A new mission has become available: %s" % new_mission.title)
