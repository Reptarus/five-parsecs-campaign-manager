# PreBattleLoop.gd
extends Node

enum TaskType { TRADE, EXPLORE, TRAIN, RECRUIT, FIND_PATRON, REPAIR, REST }

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func run_pre_battle_loop() -> void:
	print("Beginning pre-battle preparations...")
	assign_crew_tasks(game_state.current_crew)
	process_rumors()
	update_mission_availability()
	print("Pre-battle preparations complete.")

func assign_crew_tasks(crew: Crew) -> void:
	for member in crew.get_members():
		if member.is_available():
			var task = choose_task(member)
			perform_task(member, task)

func choose_task(character) -> TaskType:
	var available_tasks = TaskType.values()
	return available_tasks[randi() % available_tasks.size()]

func perform_task(character, task: TaskType) -> void:
	match task:
		TaskType.TRADE:
			trade(character)
		TaskType.EXPLORE:
			explore(character)
		TaskType.TRAIN:
			train(character)
		TaskType.RECRUIT:
			recruit(character)
		TaskType.FIND_PATRON:
			find_patron(character)
		TaskType.REPAIR:
			repair(character)
		TaskType.REST:
			rest(character)

func trade(character) -> void:
	var roll = randi() % 100
	if roll < 30:
		var credits_earned = randi() % 6 * 10 + 10
		game_state.current_crew.add_credits(credits_earned)
		print("%s earned %d credits through trading." % [character.get_name(), credits_earned])
	elif roll < 60:
		var item = generate_random_equipment()
		character.get_inventory().add_item(item)
		print("%s acquired %s while trading." % [character.get_name(), item.get_name()])
	else:
		print("%s couldn't find any good deals while trading." % character.get_name())

func explore(character) -> void:
	var roll = randi() % 100
	if roll < 20:
		var rumor = generate_rumor()
		game_state.add_rumor(rumor)
		print("%s discovered a rumor: %s" % [character.get_name(), rumor])
	elif roll < 40:
		var credits_found = randi() % 3 * 5 + 5
		game_state.current_crew.add_credits(credits_found)
		print("%s found %d credits while exploring." % [character.get_name(), credits_found])
	elif roll < 60:
		var item = generate_random_equipment()
		character.get_inventory().add_item(item)
		print("%s found %s while exploring." % [character.get_name(), item.get_name()])
	else:
		print("%s had an uneventful exploration." % character.get_name())

func train(character) -> void:
	var skill_to_improve = character.get_random_skill()
	var xp_gained = randi() % 3 + 1
	character.improve_skill(skill_to_improve, xp_gained)
	print("%s trained %s and gained %d XP." % [character.get_name(), skill_to_improve, xp_gained])

func recruit(character) -> void:
	var crew = game_state.current_crew
	if crew.get_member_count() < crew.get_max_members():
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit = game_state.character_factory.create_random_character()
			crew.add_member(new_recruit)
			print("%s successfully recruited %s to join the crew." % [character.get_name(), new_recruit.get_name()])
		else:
			print("%s couldn't find any suitable recruits." % character.get_name())
	else:
		print("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.get_name())

func find_patron(character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron = game_state.patron_factory.create_random_patron()
		game_state.add_patron(new_patron)
		print("%s found a new patron: %s" % [character.get_name(), new_patron.get_name()])
	else:
		print("%s couldn't find any patrons offering work." % character.get_name())

func repair(character) -> void:
	var item_to_repair = character.get_inventory().get_damaged_item()
	if item_to_repair:
		var repair_success = randf() < 0.7  # 70% chance to successfully repair
		if repair_success:
			item_to_repair.repair()
			print("%s successfully repaired %s." % [character.get_name(), item_to_repair.get_name()])
		else:
			print("%s attempted to repair %s but failed." % [character.get_name(), item_to_repair.get_name()])
	else:
		var ship_repair_amount = randi() % 5 + 1
		game_state.current_crew.get_ship().repair(ship_repair_amount)
		print("%s repaired the ship, restoring %d hull points." % [character.get_name(), ship_repair_amount])

func rest(character) -> void:
	var stress_recovered = randi() % 3 + 1
	character.reduce_stress(stress_recovered)
	if character.is_injured():
		character.heal(1)
		print("%s rested and recovered 1 health point and %d stress." % [character.get_name(), stress_recovered])
	else:
		print("%s rested and recovered %d stress." % [character.get_name(), stress_recovered])

func generate_random_equipment() -> Equipment:
	var equipment_type = randi() % 4  # 0: Weapon, 1: Armor, 2: Gear, 3: Medical
	match equipment_type:
		0: return generate_random_weapon()
		1: return generate_random_armor()
		2: return generate_random_gear()
		3: return generate_random_medical_item()
	return null  # This should never happen

func generate_random_weapon() -> Weapon:
	var weapon_types = ["Pistol", "Rifle", "Shotgun", "Heavy Weapon"]
	var weapon_name = weapon_types[randi() % weapon_types.size()]
	var damage = randi() % 5 + 1
	var range = randi() % 10 + 1
	return Weapon.new(weapon_name, Weapon.WeaponType.MILITARY, range, 1, damage)

func generate_random_armor() -> Equipment:
	var armor_types = ["Light Armor", "Medium Armor", "Heavy Armor"]
	var armor_name = armor_types[randi() % armor_types.size()]
	var defense = randi() % 5 + 1
	return Equipment.new(armor_name, Equipment.Type.ARMOR, defense)

func generate_random_gear() -> Gear:
	var gear_types = ["Medkit", "Repair Kit", "Stealth Field", "Jetpack"]
	var gear_name = gear_types[randi() % gear_types.size()]
	return Gear.new(gear_name, "A useful piece of equipment", "Utility", 1)

func generate_random_medical_item() -> Equipment:
	var medical_types = ["Med-kit", "Stim-pack", "Nano-injector", "Trauma Pack"]
	var name = medical_types[randi() % medical_types.size()]
	var healing_value = randi() % 3 + 1
	return Equipment.new(name, Equipment.Type.CONSUMABLE, healing_value)

func generate_rumor() -> String:
	var rumors = [
		"There's talk of a hidden alien artifact on a nearby moon.",
		"A notorious pirate captain is offering big credits for experienced crew.",
		"The local government is secretly funding illegal weapons research.",
		"An abandoned space station has been spotted in the outer reaches of the system.",
		"A wealthy trader is looking for protection on a dangerous cargo run."
	]
	return rumors[randi() % rumors.size()]

func process_rumors() -> void:
	for rumor in game_state.rumors:
		if randf() < 0.2:  # 20% chance for a rumor to develop into a mission
			var mission = game_state.mission_generator.generate_mission_from_rumor(rumor)
			game_state.add_mission(mission)
			game_state.remove_rumor(rumor)
			print("A rumor has developed into a new mission: %s" % mission.title)

func update_mission_availability() -> void:
	for mission in game_state.available_missions:
		if randf() < 0.1:  # 10% chance for a mission to become unavailable
			game_state.remove_mission(mission)
			print("The mission '%s' is no longer available." % mission.title)

	if game_state.available_missions.size() < 3:
		var new_mission = game_state.mission_generator.generate_mission()
		game_state.add_mission(new_mission)
		print("A new mission has become available: %s" % new_mission.title)
