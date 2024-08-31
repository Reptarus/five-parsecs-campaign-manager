class_name PreBattleLoop
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
	for member in crew.members:
		if member.is_available():
			var task = choose_task(member)
			perform_task(member, task)

func choose_task(character: Character) -> TaskType:
	var available_tasks = TaskType.values()
	return available_tasks[randi() % available_tasks.size()]

func perform_task(character: Character, task: TaskType) -> void:
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

func trade(character: Character) -> void:
	var credits_earned = randi_range(1, 6) * 10
	game_state.current_crew.add_credits(credits_earned)
	print("%s earned %d credits through trading." % [character.name, credits_earned])
	
	if randf() < 0.3:  # 30% chance to find equipment
		var equipment = generate_random_equipment()
		character.inventory.add_item(equipment)
		print("%s acquired %s while trading." % [character.name, equipment.name])

func explore(character: Character) -> void:
	var current_location = game_state.current_crew.current_location
	var exploration_result = randi() % 100
	
	if exploration_result < 20:
		var rumor = generate_rumor()
		game_state.add_rumor(rumor)
		print("%s discovered a rumor: %s" % [character.name, rumor])
	elif exploration_result < 40:
		var credits_found = randi_range(1, 3) * 5
		game_state.current_crew.add_credits(credits_found)
		print("%s found %d credits while exploring." % [character.name, credits_found])
	elif exploration_result < 60:
		var item = generate_random_equipment()
		character.inventory.add_item(item)
		print("%s found %s while exploring." % [character.name, item.name])
	elif exploration_result < 80:
		print("%s had an uneventful exploration of %s." % [character.name, current_location.name])
	else:
		var xp_gained = randi_range(1, 3)
		character.gain_experience(xp_gained)
		print("%s gained %d XP from an interesting discovery." % [character.name, xp_gained])

func train(character: Character) -> void:
	var skill_to_improve = character.get_random_skill()
	var xp_gained = randi_range(1, 3)
	character.improve_skill(skill_to_improve, xp_gained)
	print("%s trained %s and gained %d XP." % [character.name, skill_to_improve, xp_gained])

func recruit(character: Character) -> void:
	if game_state.current_crew.get_member_count() < game_state.current_crew.max_members:
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit = Character.create_random_character()
			game_state.current_crew.add_member(new_recruit)
			print("%s successfully recruited %s to join the crew." % [character.name, new_recruit.name])
		else:
			print("%s couldn't find any suitable recruits." % character.name)
	else:
		print("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.name)

func find_patron(character: Character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron = Patron.new()  # Assuming you have a Patron class
		game_state.add_patron(new_patron)
		print("%s found a new patron: %s" % [character.name, new_patron.name])
	else:
		print("%s couldn't find any patrons offering work." % character.name)

func repair(character: Character) -> void:
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

func rest(character: Character) -> void:
	var stress_recovered = randi_range(1, 3)
	character.reduce_stress(stress_recovered)
	if character.is_injured():
		character.heal(1)
		print("%s rested and recovered 1 health point and %d stress." % [character.name, stress_recovered])
	else:
		print("%s rested and recovered %d stress." % [character.name, stress_recovered])

func generate_random_equipment() -> Equipment:
	var equipment_types = ["Weapon", "Armor", "Gadget", "Medical"]
	var chosen_type = equipment_types[randi() % equipment_types.size()]
	
	match chosen_type:
		"Weapon":
			return generate_random_weapon()
		"Armor":
			return generate_random_armor()
		"Gadget":
			return generate_random_gadget()
		"Medical":
			return generate_random_medical()

func generate_random_weapon() -> Weapon:
	var weapon_names = ["Laser Pistol", "Plasma Rifle", "Gauss Cannon", "Vibro-Blade"]
	var name = weapon_names[randi() % weapon_names.size()]
	var damage = randi_range(1, 4)
	return Weapon.new(name, damage)

func generate_random_armor() -> Armor:
	var armor_names = ["Combat Vest", "Energy Shield", "Nano-weave Suit", "Powered Exoskeleton"]
	var name = armor_names[randi() % armor_names.size()]
	var defense = randi_range(1, 3)
	return Armor.new(name, defense)

func generate_random_gadget() -> Gadget:
	var gadget_names = ["Holo-projector", "Grav-boots", "Cloaking Device", "Neural Implant"]
	var name = gadget_names[randi() % gadget_names.size()]
	return Gadget.new(name)

func generate_random_medical() -> MedicalItem:
	var medical_names = ["Med-kit", "Stim-pack", "Nano-injector", "Trauma Pack"]
	var name = medical_names[randi() % medical_names.size()]
	var healing_value = randi_range(1, 3)
	return MedicalItem.new(name, healing_value)

func generate_rumor() -> String:
	var rumors = [
		"There's talk of a hidden alien artifact on a nearby moon.",
		"A notorious pirate captain is offering big credits for experienced crew.",
		"The local government is secretly funding illegal weapons research.",
		"An abandoned space station has been spotted in the outer reaches of the system.",
		"A wealthy trader is looking for protection on a dangerous cargo run."
	]
	return rumors[randi() % rumors.size()]

func run_pre_battle_loop() -> void:
	print("Beginning pre-battle preparations...")
	assign_crew_tasks(game_state.current_crew)
	process_rumors()
	update_mission_availability()
	print("Pre-battle preparations complete.")

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
