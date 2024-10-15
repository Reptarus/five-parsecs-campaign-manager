class_name WorldPhaseUI
extends Control

signal mission_selection_requested(available_missions: Array[Mission])
signal phase_completed

# Onready variables
@onready var background: TextureRect = $Background
@onready var top_bar: HBoxContainer = $MarginContainer/VBoxContainer/TopBar
@onready var step_indicator: HBoxContainer = $MarginContainer/VBoxContainer/StepIndicator
@onready var main_content: Control = $MarginContainer/VBoxContainer/HSplitContainer/MainContent
@onready var side_panel: Control = $MarginContainer/VBoxContainer/HSplitContainer/SidePanel
@onready var event_log: Control = $EventLog
@onready var crew_status_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/SidePanel/CrewStatus/CrewStatusList
@onready var ship_status_info: RichTextLabel = $MarginContainer/VBoxContainer/HSplitContainer/SidePanel/ShipStatus/ShipStatusInfo
@onready var credits_info: Control = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/UpkeepPanel/CreditsInfo
@onready var ship_repair_options: Control = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/UpkeepPanel/ShipRepairOptions
@onready var medical_care_options: Control = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/UpkeepPanel/MedicalCareOptions
@onready var crew_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel/CrewList
@onready var task_assignment: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel/TaskAssignment
@onready var resolve_task_button: Button = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel/ResolveTask

# Member variables
var current_step: int = 0
var game_state: GameState
var debug_mode: bool = false
var test_repair_value: int = 5
var character_creation_data: CharacterCreationData
var test_crew: Array[Character] = []
var test_ship: Ship
var credits_label: Label
var game_state_manager: GameStateManager
var mission_manager: MissionManager
var patron_job_manager: PatronJobManager

func _ready() -> void:
	event_log = $EventLog
	if event_log == null:
		push_error("EventLog node not found. Event logging will not function.")
	
	initialize_game_state()
	initialize_ui()
	connect_signals()
	start_world_phase()
	add_debug_commands()

func initialize_game_state() -> void:
	game_state = GameState.new()
	game_state.crew = Crew.new()
	game_state.crew.initialize()
	character_creation_data = CharacterCreationData.new()
	generate_test_crew()
	generate_test_ship()
	
	# Use the global GameStateManager
	GameStateManager.game_state = game_state
	GameStateManager.initialize_managers()
	GameStateManager.initialize_state_machines()
	mission_manager = MissionManager.new(GameStateManager)
	patron_job_manager = PatronJobManager.new()

func initialize_ui() -> void:
	update_step_indicator()
	update_side_panel()
	clear_event_log()
	update_crew_status()
	update_ship_status()
	credits_label = Label.new()
	credits_info.add_child(credits_label)
	update_credits_display()

func connect_signals() -> void:
	connect_top_bar_buttons()
	connect_step_buttons()
	resolve_task_button.pressed.connect(resolve_crew_tasks)
	crew_list.item_selected.connect(func(_index): assign_crew_task())

func connect_top_bar_buttons() -> void:
	var buttons = {
		"BackButton": on_back_pressed,
		"OptionsButton": on_options_pressed,
		"NextButton": on_next_pressed
	}
	
	for button_name in buttons:
		var button = top_bar.get_node_or_null(button_name)
		if button:
			button.pressed.connect(buttons[button_name])
		else:
			push_warning("%s not found in TopBar" % button_name)

func connect_step_buttons() -> void:
	for i in range(4):
		var step_button = step_indicator.get_node_or_null("Step%dButton" % (i + 1))
		if step_button:
			step_button.pressed.connect(func(): on_step_button_pressed(i))
		else:
			push_warning("Step button %d not found" % (i + 1))

func start_world_phase() -> void:
	current_step = 0
	update_step_indicator()
	show_current_step()

func show_current_step() -> void:
	hide_all_panels()
	match current_step:
		0: show_upkeep_panel()
		1: show_crew_tasks_panel()
		2: show_job_offers_panel()
		3: show_mission_prep_panel()
	update_step_indicator()
	update_crew_status()
	update_ship_status()

func hide_all_panels() -> void:
	for panel in main_content.get_children():
		panel.hide()

func show_upkeep_panel() -> void:
	var upkeep_panel = main_content.get_node_or_null("UpkeepPanel")
	if upkeep_panel:
		upkeep_panel.show()
		update_credits_display()
		show_ship_repair_options()
		show_medical_care_options()
	else:
		push_warning("UpkeepPanel not found")

func show_crew_tasks_panel() -> void:
	var crew_tasks_panel = main_content.get_node_or_null("CrewTasksPanel")
	if crew_tasks_panel:
		crew_tasks_panel.show()
		populate_crew_tasks()
	else:
		push_warning("CrewTasksPanel not found")

func show_job_offers_panel() -> void:
	var job_offers_panel = main_content.get_node_or_null("JobOffersPanel")
	if job_offers_panel:
		job_offers_panel.show()
		populate_patron_list()
	else:
		push_warning("JobOffersPanel not found")

func show_mission_prep_panel() -> void:
	var mission_prep_panel = main_content.get_node_or_null("MissionPrepPanel")
	if mission_prep_panel:
		mission_prep_panel.show()
		display_mission_details()
		show_equipment_list()
	else:
		push_warning("MissionPrepPanel not found")

func update_step_indicator() -> void:
	for i in range(4):
		var step_button = step_indicator.get_node_or_null("Step%dButton" % (i + 1))
		if step_button:
			step_button.disabled = (i != current_step)

func update_side_panel() -> void:
	# TODO: Implement side panel update logic
	pass

func clear_event_log() -> void:
	if event_log == null:
		push_warning("Event log is null. Make sure it's properly initialized.")
		return
	
	var event_log_text = event_log.get_node_or_null("ScrollContainer/EventLogText")
	if event_log_text:
		event_log_text.clear()  # Assuming event_log_text is a TextEdit or similar
	else:
		push_warning("EventLogText node not found. Unable to clear event log.")

func add_event_log_entry(entry: String) -> void:
	if event_log == null:
		push_warning("Event log is null. Make sure it's properly initialized.")
		return
	
	var event_log_text = event_log.get_node_or_null("ScrollContainer/EventLogText")
	if event_log_text:
		event_log_text.append_text(entry + "\n")
	else:
		push_warning("EventLogText node not found. Unable to add event log entry.")

func on_back_pressed() -> void:
	if current_step > 0:
		current_step -= 1
		show_current_step()
	else:
		show_confirmation_dialog("Are you sure you want to exit the World Phase?", exit_world_phase)

func on_options_pressed() -> void:
	# TODO: Implement options menu
	pass

func on_next_pressed() -> void:
	if current_step < 3:
		current_step += 1
		show_current_step()
	else:
		show_confirmation_dialog("Are you sure you want to end the World Phase?", finish_world_phase)

func on_step_button_pressed(step: int) -> void:
	current_step = step
	show_current_step()

func execute_world_step() -> void:
	handle_upkeep_and_repairs()
	assign_and_resolve_crew_tasks()
	determine_job_offers()
	assign_equipment(game_state.current_crew, game_state.available_equipment)
	resolve_rumors()
	choose_battle()

func handle_upkeep_and_repairs() -> void:
	var upkeep_cost = game_state.crew.calculate_upkeep_cost(game_state.crew)
	if game_state.crew.pay_upkeep(upkeep_cost):
		add_event_log_entry("Paid %d credits for upkeep." % upkeep_cost)
	else:
		add_event_log_entry("Not enough credits to pay for upkeep!")
	
	update_credits_display()
	update_crew_status()
	update_ship_status()

func calculate_upkeep_cost(crew: Crew) -> int:
	var base_cost: int = 1  # Base cost for crews of 4-6 members
	var additional_cost: int = maxi(0, crew.get_member_count() - 6)
	return base_cost + additional_cost

func assign_and_resolve_crew_tasks() -> void:
	var crew: Crew = game_state.current_crew
	for member in crew.get_characters():
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

# Task resolution methods
func _trade(character: Character) -> void:
	add_event_log_entry("%s engaged in trade." % character.name)

func _explore(character: Character) -> void:
	add_event_log_entry("%s explored the area." % character.name)

func _train(character: Character) -> void:
	add_event_log_entry("%s underwent training." % character.name)

func _recruit(character: Character) -> void:
	add_event_log_entry("%s attempted to recruit new members." % character.name)

func _find_patron(character: Character) -> void:
	add_event_log_entry("%s searched for a new patron." % character.name)

func _repair(character: Character) -> void:
	add_event_log_entry("%s repaired equipment." % character.name)

func _decoy(character: Character) -> void:
	add_event_log_entry("%s acted as a decoy." % character.name)

func _track(character: Character) -> void:
	add_event_log_entry("%s tracked a target." % character.name)

func determine_job_offers() -> void:
	var available_patrons: Array[Patron] = game_state.patrons.filter(func(p: Patron) -> bool: return p.has_available_jobs())
	for patron in available_patrons:
		var job: Mission = patron.generate_job()
		game_state.add_mission(job)
		add_event_log_entry("New job offer from %s: %s" % [patron.name, job.title])

func assign_equipment(item: Equipment, character: Character) -> void:
	if character.equip_item(item):
		add_event_log_entry("%s equipped %s" % [character.name, item.name])
	else:
		add_event_log_entry("Failed to equip %s to %s" % [item.name, character.name])

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

# Debug functions
func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	add_event_log_entry("Debug mode: %s" % ("Enabled" if enabled else "Disabled"))

func set_test_repair_value(value: int) -> void:
	test_repair_value = value
	add_event_log_entry("Test repair value set to: %d" % value)

func add_debug_commands() -> void:
	var debug_button = Button.new()
	debug_button.text = "Debug"
	debug_button.pressed.connect(show_debug_menu)
	top_bar.add_child(debug_button)

func show_debug_menu() -> void:
	var debug_menu = PopupMenu.new()
	debug_menu.add_item("Toggle Debug Mode")
	debug_menu.add_item("Set Test Repair Value")
	debug_menu.add_item("Show Test Crew Info")
	debug_menu.add_item("Test Crew Tasks")
	debug_menu.add_item("Simulate Status Changes")
	debug_menu.add_item("Print Game State Debug")
	debug_menu.add_item("Force Patron Encounter")
	debug_menu.add_item("Simulate Rival Actions")
	debug_menu.add_item("Instantly Complete All Tasks")
	debug_menu.id_pressed.connect(handle_debug_menu_selection)
	add_child(debug_menu)
	debug_menu.popup_centered()

func handle_debug_menu_selection(id: int) -> void:
	match id:
		0: set_debug_mode(!debug_mode)
		1: show_repair_value_dialog()
		2: show_test_crew_info()
		3: test_crew_tasks()
		4: simulate_status_changes()
		5: print_game_state_debug()
		6: force_patron_encounter()
		7: simulate_rival_actions()
		8: instantly_complete_all_tasks()

func show_repair_value_dialog() -> void:
	var dialog = AcceptDialog.new()
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Enter repair value"
	dialog.add_child(line_edit)
	dialog.add_button("Set", true, "set_value")
	dialog.confirmed.connect(func(): set_test_repair_value(int(line_edit.text)))
	add_child(dialog)
	dialog.popup_centered()

func show_test_crew_info() -> void:
	var dialog = AcceptDialog.new()
	var crew_info = "Test Crew Information:\n\n"
	for character in test_crew:
		crew_info += "%s (%s)\n" % [character.name, GlobalEnums.Class.keys()[character.character_class]]
		crew_info += "  Species: %s\n" % GlobalEnums.Species.keys()[character.species]
		crew_info += "  Background: %s\n" % GlobalEnums.Background.keys()[character.background]
		crew_info += "  Motivation: %s\n" % GlobalEnums.Motivation.keys()[character.motivation]
	dialog.dialog_text = crew_info
	add_child(dialog)
	dialog.popup_centered()

func generate_test_crew() -> void:
	print("Generating test crew")
	test_crew = character_creation_data.generate_test_crew()
	# Clear existing characters and add new ones
	game_state.crew._characters.clear()
	for character in test_crew:
		game_state.crew.add_character(character)
	print("Test crew generated. Number of characters: ", game_state.crew.get_characters().size())

# Add this function to test crew tasks
func test_crew_tasks() -> void:
	for character in test_crew:
		var task = choose_task(character)
		resolve_task(character, task)
		add_event_log_entry("%s performed task: %s" % [character.name, GlobalEnums.CrewTask.keys()[task]])

func generate_test_ship() -> void:
	test_ship = Ship.new()
	test_ship.name = "USS Testerprise"
	
	# Add components
	var engine = EngineComponent.new("Basic Engine", "ENGINE", 1, 0)
	test_ship.add_component(engine)
	
	var weapons = WeaponsComponent.new("Laser Cannon", "WEAPONS", 1, 0)
	test_ship.add_component(weapons)
	
	var medbay = MedicalBayComponent.new("Basic Medbay", "MEDICAL_BAY", 1, 0)
	test_ship.add_component(medbay)
	
	var hull = HullComponent.new("Standard Hull", "HULL", 1, 0)
	test_ship.add_component(hull)
	
	# Set other properties
	test_ship.set_hull_integrity(75)
	test_ship.fuel = 80
	test_ship.cargo_capacity = 100
	test_ship.current_cargo = 30
	
	game_state.current_ship = test_ship

func update_crew_status() -> void:
	print("Updating crew status")
	crew_status_list.clear()
	var characters = game_state.crew.get_characters()
	print("Number of characters: ", characters.size())
	
	if characters.is_empty():
		crew_status_list.add_item("No crew members available")
		return
	
	for character in characters:
		print("Processing character: ", character.name)
		var status_text = """
{name} ({class})
Status: {status}
Morale: {morale}%
Combat Skill: +{combat_skill}
Reactions: {reactions}
""".format({
			"name": character.name,
			"class": GlobalEnums.Class.keys()[character.character_class],
			"status": character.status if "status" in character else "Unknown",
			"morale": character.morale,
			"combat_skill": character.combat_skill,
			"reactions": character.reactions
		})
		crew_status_list.add_item(status_text.strip_edges())
	
	print("Crew status update complete")

func update_ship_status() -> void:
	if test_ship:
		var status_text = """
		Ship: %s
		Hull Integrity: %d%%
		Fuel: %d%%
		Cargo: %d / %d
		""" % [
			test_ship.name,
			test_ship.hull_integrity,
			test_ship.fuel,
			test_ship.current_cargo,
			test_ship.cargo_capacity
		]
		ship_status_info.text = status_text
	else:
		ship_status_info.text = "No ship data available."

func simulate_status_changes() -> void:
	for character in test_crew:
		character.morale -= randi() % 10
		character.morale = max(character.morale, 0)
	
	test_ship.hull_integrity -= randi() % 5
	test_ship.fuel -= randi() % 10
	test_ship.current_cargo += randi() % 20
	test_ship.hull_integrity = max(test_ship.hull_integrity, 0)
	test_ship.fuel = max(test_ship.fuel, 0)
	test_ship.current_cargo = min(test_ship.current_cargo, test_ship.cargo_capacity)
	
	update_crew_status()
	update_ship_status()
	add_event_log_entry("Status changes simulated.")

func update_credits_display() -> void:
	var credits = GameStateManager.game_state.crew.get_credits()
	credits_label.text = "Credits: %d" % credits

func populate_crew_tasks() -> void:
	# Clear existing items
	crew_list.clear()  # Assuming crew_list is an ItemList or similar
	for character in GameStateManager.game_state.crew.get_characters():
		crew_list.add_item(character.name)
	
	# Clear existing tasks
	task_assignment.clear()  # Assuming task_assignment is an OptionButton or similar
	for task in GlobalEnums.CrewTask.keys():
		task_assignment.add_item(task)

func assign_crew_task() -> void:
	var selected_character = crew_list.get_selected_items()[0]
	var selected_task = task_assignment.get_selected_id()
	GameStateManager.game_state.crew.assign_task(selected_character, GlobalEnums.CrewTask.values()[selected_task])
	add_event_log_entry("%s assigned to %s" % [GameStateManager.game_state.crew.get_character(selected_character).name, GlobalEnums.CrewTask.keys()[selected_task]])

func resolve_crew_tasks() -> void:
	game_state.crew.resolve_tasks()
	update_crew_status()
	add_event_log_entry("Crew tasks resolved.")

func print_game_state_debug() -> void:
	print("--- Game State Debug ---")
	print("Current step: ", current_step)
	print("Number of crew members: ", game_state.crew.get_characters().size())
	print("Current ship: ", "Available" if game_state.current_ship else "Not available")
	print("Credits: ", game_state.crew.get_credits())
	print("------------------------")

func show_ship_repair_options() -> void:
	var ship = GameStateManager.game_state.current_ship
	var repair_cost = calculate_repair_cost(ship)
	
	# Clear existing options
	for child in ship_repair_options.get_children():
		child.queue_free()
	
	# Add new repair option
	var repair_button = Button.new()
	repair_button.text = "Repair Ship (Cost: %d credits)" % repair_cost
	repair_button.connect("pressed", Callable(self, "repair_ship"))
	ship_repair_options.add_child(repair_button)

func show_medical_care_options() -> void:
	var crew = GameStateManager.game_state.crew
	
	# Clear existing options
	for child in medical_care_options.get_children():
		child.queue_free()
	
	for character in crew.get_injured_characters():
		var care_cost = calculate_medical_care_cost(character)
		var care_button = Button.new()
		care_button.text = "Heal %s (Cost: %d credits)" % [character.name, care_cost]
		care_button.connect("pressed", Callable(self, "provide_medical_care").bind(character))
		medical_care_options.add_child(care_button)

func pay_crew_upkeep() -> void:
	var crew = GameStateManager.game_state.crew
	var upkeep_cost = crew.calculate_upkeep_cost(crew)
	if crew.pay_upkeep(upkeep_cost):
		add_event_log_entry("Paid %d credits for crew upkeep." % upkeep_cost)
	else:
		add_event_log_entry("Not enough credits to pay for crew upkeep!")
	update_credits_display()

func repair_ship() -> void:
	var ship = GameStateManager.game_state.current_ship
	var repair_cost = calculate_repair_cost(ship)
	if GameStateManager.game_state.crew.pay_upkeep(repair_cost):
		ship.repair(ship.max_hull - ship.current_hull)
		add_event_log_entry("Repaired ship for %d credits." % repair_cost)
	else:
		add_event_log_entry("Not enough credits to repair the ship!")
	update_credits_display()
	update_ship_status()

func provide_medical_care(character: Character) -> void:
	var care_cost = calculate_medical_care_cost(character)
	if GameStateManager.game_state.crew.pay_upkeep(care_cost):
		character.heal()
		add_event_log_entry("Provided medical care to %s for %d credits." % [character.name, care_cost])
	else:
		add_event_log_entry("Not enough credits to provide medical care!")
	update_credits_display()
	update_crew_status()

func populate_patron_list() -> void:
	var patron_list = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel/PatronList
	patron_list.clear()
	for patron in GameStateManager.patrons:
		patron_list.add_item(patron.name)

func on_patron_selected(index: int) -> void:
	var patron = GameStateManager.patrons[index]
	var job_details = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel/JobDetails
	job_details.clear()
	job_details.append_bbcode("[b]Patron: %s[/b]\n" % patron.name)
	job_details.append_bbcode("Type: %s\n" % GlobalEnums.Faction.keys()[patron.type])
	job_details.append_bbcode("Relationship: %d\n\n" % patron.relationship)
	
	for mission in patron.missions:
		job_details.append_bbcode("[u]Job: %s[/u]\n" % mission.title)
		job_details.append_bbcode("Description: %s\n" % mission.description)
		job_details.append_bbcode("Reward: %d credits\n" % mission.rewards.get("credits", 0))
		job_details.append_bbcode("Difficulty: %d\n\n" % mission.difficulty)

func accept_job() -> void:
	var patron_list = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel/PatronList
	var selected_patron = patron_list.get_selected_items()[0]
	var patron = GameStateManager.patrons[selected_patron]
	var mission = patron.missions[0]  # Assuming only one mission per patron for simplicity
	
	patron_job_manager.accept_job(mission)
	add_event_log_entry("Accepted job: %s from %s" % [mission.title, patron.name])

func display_mission_details() -> void:
	var mission_details = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/MissionPrepPanel/MissionDetails
	var current_mission = GameStateManager.game_state.current_mission
	
	mission_details.clear()
	mission_details.append_bbcode("[b]Mission: %s[/b]\n" % current_mission.title)
	mission_details.append_bbcode("Description: %s\n" % current_mission.description)
	mission_details.append_bbcode("Objective: %s\n" % current_mission.get_objective_description())
	mission_details.append_bbcode("Difficulty: %d\n" % current_mission.difficulty)
	mission_details.append_bbcode("Reward: %d credits\n" % current_mission.rewards.get("credits", 0))

func show_equipment_list() -> void:
	var equipment_list = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/MissionPrepPanel/EquipmentList
	equipment_list.clear()
	
	for item in GameStateManager.game_state.current_ship.get_ship_stash():
		equipment_list.add_item(item.name)

func ready_for_mission() -> void:
	add_event_log_entry("Mission preparation complete. Ready for deployment.")
	# Implement any final checks or state updates here

func finish_world_phase() -> void:
	# Perform any necessary cleanup or state saving
	phase_completed.emit()

func exit_world_phase() -> void:
	# Implement logic to exit the World Phase, possibly returning to a main menu
	pass

func calculate_repair_cost(ship: Ship) -> int:
	return (ship.max_hull - ship.current_hull) * 10  # Example calculation

func calculate_medical_care_cost(character: Character) -> int:
	return character.get_injuries().size() * 50  # Example calculation

func force_patron_encounter() -> void:
	var random_patron = GameStateManager.patrons[randi() % GameStateManager.patrons.size()]
	var jobs = patron_job_manager.generate_patron_jobs()
	if not jobs.is_empty():
		var job = jobs[0]
		random_patron.add_mission(job)
		add_event_log_entry("Forced patron encounter: %s offers a new job." % random_patron.name)
	else:
		push_warning("No job generated for forced patron encounter.")

func simulate_rival_actions() -> void:
	for rival in GameStateManager.rivals:
		rival.increase_strength()
		add_event_log_entry("Rival %s increased in strength." % rival.name)

func instantly_complete_all_tasks() -> void:
	for character in GameStateManager.game_state.crew.get_characters():
		character.resolve_task()
	add_event_log_entry("All crew tasks instantly completed.")

func show_confirmation_dialog(message: String, confirm_action: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.confirmed.connect(confirm_action)
	add_child(dialog)
	dialog.popup_centered()

func assign_task(character_index: int, task: GlobalEnums.CrewTask) -> void:
	GameStateManager.game_state.crew.assign_task(character_index, task)
