class_name WorldPhaseUI
extends Control

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
		add_event_log_entry("Upkeep paid: %d credits" % upkeep_cost)
	else:
		add_event_log_entry("Not enough credits to pay upkeep. Crew morale decreases.")
		crew.decrease_morale()
	
	var repair_amount: int = crew.ship.auto_repair()
	add_event_log_entry("Ship auto-repaired %d hull points" % repair_amount)

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
		GlobalEnums.CrewTask.TRADE: _trade(character)
		GlobalEnums.CrewTask.EXPLORE: _explore(character)
		GlobalEnums.CrewTask.TRAIN: _train(character)
		GlobalEnums.CrewTask.RECRUIT: _recruit(character)
		GlobalEnums.CrewTask.FIND_PATRON: _find_patron(character)
		GlobalEnums.CrewTask.REPAIR_KIT: _repair(character)
		GlobalEnums.CrewTask.DECOY: _decoy(character)
		GlobalEnums.CrewTask.TRACK: _track(character)

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

# Implement trade(), explore(), train(), recruit(), find_patron(), and repair() functions here

func determine_job_offers() -> void:
	var available_patrons: Array[Patron] = game_state.patrons.filter(func(p: Patron) -> bool: return p.has_available_jobs())
	for patron in available_patrons:
		var job: Mission = patron.generate_job()
		game_state.add_mission(job)
		add_event_log_entry("New job offer from %s: %s" % [patron.name, job.title])

func assign_equipment() -> void:
	for member in game_state.current_crew.members:
		member.optimize_equipment()
	add_event_log_entry("Equipment has been optimized for all crew members.")

func resolve_rumors() -> void:
	if game_state.rumors.size() > 0:
		var rumor_roll: int = randi() % 6 + 1
		if rumor_roll <= game_state.rumors.size():
			var chosen_rumor: String = game_state.rumors[randi() % game_state.rumors.size()]
			var new_mission: Mission = game_state.mission_generator.generate_mission_from_rumor(chosen_rumor)
			game_state.add_mission(new_mission)
			game_state.remove_rumor(chosen_rumor)
			add_event_log_entry("A rumor has developed into a new mission: %s" % new_mission.title)

func choose_battle() -> void:
	var available_missions: Array = game_state.available_missions
	if available_missions.is_empty():
		add_event_log_entry("No available missions. Generating a random encounter.")
	else:
		mission_selection_requested.emit(available_missions)
		var random_encounter: Mission = game_state.mission_generator.generate_random_encounter()
		game_state.current_mission = random_encounter
		add_event_log_entry("Random encounter generated: %s" % random_encounter.title)
		phase_completed.emit()
