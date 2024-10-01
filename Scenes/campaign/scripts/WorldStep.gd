class_name WorldStep
extends Node

signal mission_selection_requested(available_missions: Array[Mission])
signal phase_completed

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func execute_world_step() -> void:
	handle_upkeep_and_repairs()
	assign_and_resolve_crew_tasks()
	determine_job_offers()
	assign_equipment()
	resolve_rumors()
	choose_battle()

func handle_upkeep_and_repairs() -> void:
	var crew: Crew = game_state.current_crew
	var upkeep_cost: int = calculate_upkeep_cost(crew)

	if crew.pay_upkeep(upkeep_cost):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		crew.decrease_morale()
	
	var repair_amount: int = crew.ship.auto_repair()
	print("Ship auto-repaired %d hull points" % repair_amount)

func calculate_upkeep_cost(crew: Crew) -> int:
	var base_cost: int = 1  # Base cost for crews of 4-6 members
	var additional_cost: int = maxi(0, crew.get_member_count() - 6)
	return base_cost + additional_cost

func assign_and_resolve_crew_tasks() -> void:
	var crew: Crew = game_state.current_crew
	for member in crew.members:
		if member.is_available():
			var task: GlobalEnums.CrewTask = choose_task(member)
			resolve_task(member, task)

func choose_task(_character: Character) -> GlobalEnums.CrewTask:
	var available_tasks: Array[GlobalEnums.CrewTask] = [
		GlobalEnums.CrewTask.TRADE,
		GlobalEnums.CrewTask.EXPLORE,
		GlobalEnums.CrewTask.TRAIN,
		GlobalEnums.CrewTask.RECRUIT,
		GlobalEnums.CrewTask.FIND_PATRON,
		GlobalEnums.CrewTask.REPAIR_KIT
	]
	return available_tasks[randi() % available_tasks.size()]

func resolve_task(character: Character, task: GlobalEnums.CrewTask) -> void:
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

func trade(character: Character) -> void:
	var roll: int = randi() % 100
	if roll < 30:
		var credits_earned: int = randi_range(1, 6) * 10
		game_state.current_crew.add_credits(credits_earned)
		print("%s earned %d credits through trading." % [character.name, credits_earned])
	elif roll < 60:
		var item: Equipment = generate_random_equipment()
		if character.inventory != null:
			character.inventory.append(item)
			print("%s acquired %s while trading." % [character.name, item.name])
		else:
			print("%s couldn't add item to inventory." % character.name)
	else:
		print("%s couldn't find any good deals while trading." % character.name)

func explore(character: Character) -> void:
	var roll: int = randi() % 100
	if roll < 20:
		var rumor: String = generate_rumor()
		game_state.add_rumor(rumor)
		print("%s discovered a rumor: %s" % [character.name, rumor])
	elif roll < 40:
		var credits_found: int = randi_range(1, 3) * 5
		game_state.current_crew.add_credits(credits_found)
		print("%s found %d credits while exploring." % [character.name, credits_found])
	elif roll < 60:
		var item: Equipment = generate_random_equipment()
		character.inventory.append(item)
		print("%s found %s while exploring." % [character.name, item.name])
	else:
		print("%s had an uneventful exploration." % character.name)

func train(character: Character) -> void:
	var skill_to_improve: GlobalEnums.SkillType = character.get_random_skill()
	var xp_gained: int = randi_range(1, 3)
	character.improve_skill(skill_to_improve, xp_gained)
	print("%s trained %s and gained %d XP." % [character.name, GlobalEnums.SkillType.keys()[skill_to_improve], xp_gained])

func recruit(character: Character) -> void:
	var crew: Crew = game_state.current_crew
	if crew.get_member_count() < crew.max_members:
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit: Character = Character.new()
			crew.add_member(new_recruit)
			print("%s successfully recruited %s to join the crew." % [character.name, new_recruit.name])
		else:
			print("%s couldn't find any suitable recruits." % character.name)
	else:
		print("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.name)

func find_patron(character: Character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron: Patron = Patron.new()
		game_state.add_patron(new_patron)
		print("%s found a new patron: %s" % [character.name, new_patron.name])
	else:
		print("%s couldn't find any patrons offering work." % character.name)

func repair(character: Character) -> void:
	var item_to_repair: Equipment = null
	for item_dict in character.inventory:
		var item = Equipment.new()
		item.from_dictionary(item_dict)
		if item.is_damaged:
			item_to_repair = item
			break
	if item_to_repair != null:
		var repair_success = character.attempt_repair()  # Assuming this method exists and returns a boolean
		var xp_gained: int = 1  # Base XP for attempting a repair
		if repair_success:
			xp_gained += 2  # Additional XP for successful repair
		character.add_xp(xp_gained)
		print("%s gained %d XP from the repair attempt." % [character.name, xp_gained])

		# Check for potential upgrades after gaining XP
		character.advancement.check_for_upgrades()

	else:
		print("%s has no damaged equipment to repair." % character.name)

func generate_random_equipment() -> Equipment:
	var equipment_manager = EquipmentManager.new()
	var equipment_types = [
		GlobalEnums.ItemType.WEAPON,
		GlobalEnums.ItemType.ARMOR,
		GlobalEnums.ItemType.GEAR,
		GlobalEnums.ItemType.CONSUMABLE
	]
	var random_type = equipment_types[randi() % equipment_types.size()]
	var equipment_list = equipment_manager.get_equipment_by_type(random_type)
	
	if equipment_list.is_empty():
		push_warning("No equipment found for type: " + str(random_type))
		return null
	
	var random_equipment = equipment_list[randi() % equipment_list.size()]
	return random_equipment.create_copy()

func generate_rumor() -> String:
	var rumors: Array[String] = [
		"There's talk of a hidden alien artifact on a nearby moon.",
		"A notorious pirate captain is offering big credits for experienced crew.",
		"The local government is secretly funding illegal weapons research.",
		"An abandoned space station has been spotted in the outer reaches of the system.",
		"A wealthy trader is looking for protection on a dangerous cargo run."
	]
	return rumors[randi() % rumors.size()]

func determine_job_offers() -> void:
	var available_patrons: Array[Patron] = game_state.patrons.filter(func(p: Patron) -> bool: return p.has_available_jobs())
	for patron in available_patrons:
		var job: Mission = patron.generate_job()
		game_state.add_mission(job)
		print("New job offer from %s: %s" % [patron.name, job.title])

func assign_equipment() -> void:
	for member in game_state.current_crew.members:
		member.optimize_equipment()
	print("Equipment has been optimized for all crew members.")

func resolve_rumors() -> void:
	if game_state.rumors.size() > 0:
		var rumor_roll: int = randi() % 6 + 1
		if rumor_roll <= game_state.rumors.size():
			var chosen_rumor: String = game_state.rumors[randi() % game_state.rumors.size()]
			var new_mission: Mission = game_state.mission_generator.generate_mission_from_rumor(chosen_rumor)
			game_state.add_mission(new_mission)
			game_state.remove_rumor(chosen_rumor)
			print("A rumor has developed into a new mission: %s" % new_mission.title)

func choose_battle() -> void:
	var available_missions: Array[Mission] = game_state.available_missions
	if available_missions.size() > 0:
		mission_selection_requested.emit(available_missions)
	else:
		print("No available missions. Generating a random encounter.")
		var random_encounter: Mission = game_state.mission_generator.generate_random_encounter()
		game_state.current_mission = random_encounter
		print("Random encounter generated: %s" % random_encounter.title)
		phase_completed.emit()
