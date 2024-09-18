class_name WorldStep
extends Node

var game_state: GameState

signal mission_selection_requested(available_missions)

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
	var crew = game_state.current_crew
	var upkeep_cost = calculate_upkeep_cost(crew)

	if crew.pay_upkeep(upkeep_cost):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		crew.decrease_morale()
	
	var repair_amount = crew.ship.auto_repair()
	print("Ship auto-repaired %d hull points" % repair_amount)

func calculate_upkeep_cost(crew: Crew) -> int:
	var base_cost = 1  # Base cost for crews of 4-6 members
	var additional_cost = max(0, crew.get_member_count() - 6)
	return base_cost + additional_cost

func assign_and_resolve_crew_tasks() -> void:
	var crew = game_state.current_crew
	for member in crew.members:
		if member.is_available():
			var task = choose_task(member)
			resolve_task(member, task)

func choose_task(_character) -> String:
	var available_tasks = ["Trade", "Explore", "Train", "Recruit", "Find Patron", "Repair"]
	return available_tasks[randi() % available_tasks.size()]

func resolve_task(character, task: String) -> void:
	match task:
		"Trade":
			trade(character)
		"Explore":
			explore(character)
		"Train":
			train(character)
		"Recruit":
			recruit(character)
		"Find Patron":
			find_patron(character)
		"Repair":
			repair(character)

func trade(character) -> void:
	var roll = randi() % 100
	if roll < 30:
		var credits_earned = randi_range(1, 6) * 10
		game_state.current_crew.add_credits(credits_earned)
		print("%s earned %d credits through trading." % [character.name, credits_earned])
	elif roll < 60:
		var item = generate_random_equipment()
		character.inventory.add_item(item)
		print("%s acquired %s while trading." % [character.name, item.name])
	else:
		print("%s couldn't find any good deals while trading." % character.name)

func explore(character) -> void:
	var roll = randi() % 100
	if roll < 20:
		var rumor = generate_rumor()
		game_state.add_rumor(rumor)
		print("%s discovered a rumor: %s" % [character.name, rumor])
	elif roll < 40:
		var credits_found = randi_range(1, 3) * 5
		game_state.current_crew.add_credits(credits_found)
		print("%s found %d credits while exploring." % [character.name, credits_found])
	elif roll < 60:
		var item = generate_random_equipment()
		character.inventory.add_item(item)
		print("%s found %s while exploring." % [character.name, item.name])
	else:
		print("%s had an uneventful exploration." % character.name)

func train(character) -> void:
	var skill_to_improve = character.get_random_skill()
	var xp_gained = randi_range(1, 3)
	character.improve_skill(skill_to_improve, xp_gained)
	print("%s trained %s and gained %d XP." % [character.name, skill_to_improve, xp_gained])

func recruit(character) -> void:
	var crew = game_state.current_crew
	if crew.get_member_count() < crew.max_members:
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit = preload("res://Scripts/Characters/Character.gd").new()
			crew.add_member(new_recruit)
			print("%s successfully recruited %s to join the crew." % [character.name, new_recruit.name])
		else:
			print("%s couldn't find any suitable recruits." % character.name)
	else:
		print("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.name)

func find_patron(character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron = Patron.new()  # Assuming Patron is a custom class
		game_state.add_patron(new_patron)
		print("%s found a new patron: %s" % [character.name, new_patron.name])
	else:
		print("%s couldn't find any patrons offering work." % character.name)

func repair(character) -> void:
	var item_to_repair = character.inventory.get_damaged_item()
	if item_to_repair:
		var repair_success = randf() < 0.7  # 70% chance to successfully repair
		if repair_success:
			item_to_repair.repair()
			print("%s successfully repaired %s." % [character.name, item_to_repair.name])
		else:
			print("%s attempted to repair %s but failed." % [character.name, item_to_repair.name])
	else:
		var ship_repair_amount = randi_range(1, 5)
		game_state.current_crew.ship.repair(ship_repair_amount)
		print("%s repaired the ship, restoring %d hull points." % [character.name, ship_repair_amount])

func generate_random_equipment() -> Equipment:
	# Implement logic to generate random equipment
	return Equipment.new()  # Placeholder implementation

func generate_rumor() -> String:
	var rumors = [
		"There's talk of a hidden alien artifact on a nearby moon.",
		"A notorious pirate captain is offering big credits for experienced crew.",
		"The local government is secretly funding illegal weapons research.",
		"An abandoned space station has been spotted in the outer reaches of the system.",
		"A wealthy trader is looking for protection on a dangerous cargo run."
	]
	return rumors[randi() % rumors.size()]

func determine_job_offers() -> void:
	var available_patrons = game_state.patrons.filter(func(p): return p.has_available_jobs())
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
		# Instead of choosing randomly, we'll emit a signal to open the mission selection screen
		emit_signal("mission_selection_requested", available_missions)
	else:
		print("No available missions. Generating a random encounter.")
		var random_encounter = game_state.mission_generator.generate_random_encounter()
		game_state.current_mission = random_encounter
		print("Random encounter generated: %s" % random_encounter.title)
		emit_signal("phase_completed")
