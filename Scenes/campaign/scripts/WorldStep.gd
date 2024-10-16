class_name WorldStep
extends Node

<<<<<<< HEAD
var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state
=======
signal mission_selection_requested(available_missions: Array[Mission])
signal phase_completed

@onready var background = $Background
@onready var top_bar = $TopBar
@onready var step_indicator = $StepIndicator
@onready var main_content = $MainContent
@onready var side_panel = $SidePanel
@onready var event_log = $EventLog

var current_step: int = 0
var game_state: GameState

func _ready() -> void:
	initialize_ui()
	connect_signals()
	start_world_phase()

func initialize_ui() -> void:
	update_step_indicator()
	update_side_panel()
	clear_event_log()

func connect_signals() -> void:
	$TopBar/BackButton.pressed.connect(on_back_pressed)
	$TopBar/OptionsButton.pressed.connect(on_options_pressed)
	$TopBar/NextButton.pressed.connect(on_next_pressed)
	
	for i in range(4):
		get_node("StepIndicator/Step%dButton" % (i + 1)).pressed.connect(on_step_button_pressed.bind(i))

func start_world_phase() -> void:
	current_step = 0
	show_current_step()

func show_current_step() -> void:
	hide_all_panels()
	match current_step:
		0: show_upkeep_panel()
		1: show_crew_tasks_panel()
		2: show_job_offers_panel()
		3: show_mission_prep_panel()
	update_step_indicator()

func hide_all_panels() -> void:
	for panel in main_content.get_children():
		panel.hide()

func show_upkeep_panel() -> void:
	$MainContent/UpkeepPanel.show()
	handle_upkeep_and_repairs()

func show_crew_tasks_panel() -> void:
	$MainContent/CrewTasksPanel.show()
	assign_and_resolve_crew_tasks()

func show_job_offers_panel() -> void:
	$MainContent/JobOffersPanel.show()
	determine_job_offers()

func show_mission_prep_panel() -> void:
	$MainContent/MissionPrepPanel.show()
	assign_equipment()

func update_step_indicator() -> void:
	for i in range(4):
		get_node("StepIndicator/Step%dButton" % (i + 1)).disabled = (i != current_step)

func update_side_panel() -> void:
	# Update crew and ship status
	pass

func clear_event_log() -> void:
	$EventLog/EventLogText.clear()

func add_event_log_entry(entry: String) -> void:
	$EventLog/EventLogText.append_text(entry + "\n")

func on_back_pressed() -> void:
	if current_step > 0:
		current_step -= 1
		show_current_step()

func on_options_pressed() -> void:
	# Show options menu
	pass

func on_next_pressed() -> void:
	if current_step < 3:
		current_step += 1
		show_current_step()
	else:
		execute_world_step()

func on_step_button_pressed(step: int) -> void:
	current_step = step
	show_current_step()
>>>>>>> parent of 1efa334 (worldphase functionality)

func execute_world_step() -> void:
	handle_upkeep_and_repairs()
	assign_and_resolve_crew_tasks()
	determine_job_offers()
	assign_equipment()
	resolve_rumors()
	choose_battle()

func handle_upkeep_and_repairs() -> void:
<<<<<<< HEAD
	var crew = game_state.current_crew
	var upkeep_cost = calculate_upkeep_cost(crew)

	if crew.pay_upkeep(upkeep_cost):
		print("Upkeep paid: %d credits" % upkeep_cost)
	else:
		print("Not enough credits to pay upkeep. Crew morale decreases.")
		crew.decrease_morale()
	
	var repair_amount = crew.ship.auto_repair()
	print("Ship auto-repaired %d hull points" % repair_amount)
=======
	var crew: Crew = game_state.current_crew
	var upkeep_cost: int = calculate_upkeep_cost(crew)

	if crew.pay_upkeep(upkeep_cost):
		add_event_log_entry("Upkeep paid: %d credits" % upkeep_cost)
	else:
		add_event_log_entry("Not enough credits to pay upkeep. Crew morale decreases.")
		crew.decrease_morale()
	
	var repair_amount: int = crew.ship.auto_repair()
	add_event_log_entry("Ship auto-repaired %d hull points" % repair_amount)
>>>>>>> parent of 1efa334 (worldphase functionality)

func calculate_upkeep_cost(crew: Crew) -> int:
	var base_cost = 1  # Base cost for crews of 4-6 members
	var additional_cost = max(0, crew.get_member_count() - 6)
	return base_cost + additional_cost

func assign_and_resolve_crew_tasks() -> void:
<<<<<<< HEAD
	var crew = game_state.current_crew
=======
	var crew: Crew = game_state.current_crew
>>>>>>> parent of 1efa334 (worldphase functionality)
	for member in crew.members:
		if member.is_available():
			var task = choose_task(member)
			resolve_task(member, task)

func choose_task(character: Character) -> String:
	var available_tasks = ["Trade", "Explore", "Train", "Recruit", "Find Patron", "Repair"]
	return available_tasks[randi() % available_tasks.size()]

func resolve_task(character: Character, task: String) -> void:
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

<<<<<<< HEAD
func trade(character: Character) -> void:
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

func explore(character: Character) -> void:
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

func train(character: Character) -> void:
	var skill_to_improve = character.get_random_skill()
	var xp_gained = randi_range(1, 3)
	character.improve_skill(skill_to_improve, xp_gained)
	print("%s trained %s and gained %d XP." % [character.name, skill_to_improve, xp_gained])

func recruit(character: Character) -> void:
	var crew = game_state.current_crew
	if crew.get_member_count() < crew.max_members:
		if randf() < 0.4:  # 40% chance to find a recruit
			var new_recruit = Character.create_random_character()
			crew.add_member(new_recruit)
			print("%s successfully recruited %s to join the crew." % [character.name, new_recruit.name])
		else:
			print("%s couldn't find any suitable recruits." % character.name)
	else:
		print("The crew is already at maximum capacity. %s couldn't recruit anyone." % character.name)

func find_patron(character: Character) -> void:
	if randf() < 0.3:  # 30% chance to find a patron
		var new_patron = Patron.new()
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
=======
func _trade(character: Character) -> void:
	# Implement trade logic
	add_event_log_entry("%s engaged in trade." % character.name)

func _explore(character: Character) -> void:
	# Implement explore logic
	add_event_log_entry("%s explored the area." % character.name)

func _train(character: Character) -> void:
	# Implement train logic
	add_event_log_entry("%s underwent training." % character.name)

func _recruit(character: Character) -> void:
	# Implement recruit logic
	add_event_log_entry("%s attempted to recruit new members." % character.name)

func _find_patron(character: Character) -> void:
	# Implement find patron logic
	add_event_log_entry("%s searched for a new patron." % character.name)

func _repair(character: Character) -> void:
	# Implement repair logic
	add_event_log_entry("%s repaired equipment." % character.name)

func _decoy(character: Character) -> void:
	# Implement decoy logic
	add_event_log_entry("%s acted as a decoy." % character.name)

func _track(character: Character) -> void:
	# Implement track logic
	add_event_log_entry("%s tracked a target." % character.name)
>>>>>>> parent of 1efa334 (worldphase functionality)

# Implement trade(), explore(), train(), recruit(), find_patron(), and repair() functions here

func determine_job_offers() -> void:
	var available_patrons = game_state.patrons.filter(func(p): return p.has_available_jobs())
	for patron in available_patrons:
		var job = patron.generate_job()
		game_state.add_mission(job)
		print("New job offer from %s: %s" % [patron.name, job.title])

func assign_equipment() -> void:
	for member in game_state.current_crew.members:
		member.optimize_equipment()
<<<<<<< HEAD
	print("Equipment has been optimized for all crew members.")
=======
	add_event_log_entry("Equipment has been optimized for all crew members.")
>>>>>>> parent of 1efa334 (worldphase functionality)

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
		# Here you would typically start the battle preparation phase
	else:
<<<<<<< HEAD
		print("No available missions. Generating a random encounter.")
		var random_encounter = game_state.mission_generator.generate_random_encounter()
		print("Random encounter generated: %s" % random_encounter.title)
=======
		mission_selection_requested.emit(available_missions)
		var random_encounter: Mission = game_state.mission_generator.generate_random_encounter()
		game_state.current_mission = random_encounter
		add_event_log_entry("Random encounter generated: %s" % random_encounter.title)
		phase_completed.emit()
>>>>>>> parent of 1efa334 (worldphase functionality)
