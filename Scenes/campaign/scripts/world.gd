class_name World
extends Node

signal world_step_completed

var game_state: GameState
var world_step: WorldStep
var mission_selection_scene = preload("res://Scripts/Missions/MissionSelection.gd")

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	world_step = WorldStep.new(game_state)

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

func choose_task(_member) -> String:
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
		# Instead of choosing randomly, we'll emit a signal to open the mission selection screen
		emit_signal("mission_selection_requested", available_missions)
	else:
		print("No available missions. Generating a random encounter.")
		var random_encounter = game_state.mission_generator.generate_random_encounter()
		game_state.current_mission = random_encounter
		print("Random encounter generated: %s" % random_encounter.title)
		emit_signal("phase_completed")

func get_world_traits() -> Array[String]:
	return game_state.current_location.get_traits()

func serialize() -> Dictionary:
	return {
		"game_state": game_state.serialize()
	}

static func deserialize(data: Dictionary) -> World:
	var world = World.new(GameState.deserialize(data["game_state"]))
	return world

func _ready():
	world_step = WorldStep.new(game_state)
	world_step.phase_completed.connect(_on_phase_completed)
	world_step.mission_selection_requested.connect(_on_mission_selection_requested)

func _on_phase_completed():
	# Handle phase completion logic here
	print("Phase completed")
	
	# Update game state
	game_state.current_turn += 1
	
	# Check for end game conditions
	if game_state.check_end_game_conditions():
		emit_signal("game_over")
		return
	
	# Start the next phase
	world_step.start_next_phase()
	
	# Update UI
	emit_signal("ui_update_requested")

func _on_mission_selection_requested(available_missions: Array):
	var mission_selection = mission_selection_scene.instantiate()
	add_child(mission_selection)
	mission_selection.populate_missions(available_missions)
	mission_selection.mission_selected.connect(_on_mission_selected)

func _on_mission_selected(mission: Mission):
	game_state.current_mission = mission
	game_state.remove_mission(mission)
	emit_signal("phase_completed")
