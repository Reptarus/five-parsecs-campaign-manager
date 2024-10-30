class_name WorldPhaseUI
extends Control

var step_manager: WorldStepManager
var mission_manager: MissionManager
var job_generator: JobGenerator
var special_mission_generator: SpecialMissionGenerator

@onready var main_content = $MarginContainer/VBoxContainer/HSplitContainer/MainContent
@onready var step_label = $MarginContainer/VBoxContainer/StepLabel
@onready var next_button = $MarginContainer/VBoxContainer/NextButton
@onready var event_log = $MarginContainer/VBoxContainer/EventLog/ScrollContainer/EventLogText

func _ready() -> void:
	step_manager = WorldStepManager.new()
	step_manager.initialize(get_node("/root/GameStateManager"))
	
	mission_manager = MissionManager.new(step_manager.game_state)
	job_generator = JobGenerator.new(step_manager.game_state)
	special_mission_generator = SpecialMissionGenerator.new(step_manager.game_state)
	
	step_manager.step_completed.connect(_on_step_completed)
	step_manager.phase_completed.connect(_on_phase_completed)
	
	next_button.pressed.connect(_on_next_button_pressed)
	show_current_step()

func show_current_step() -> void:
	step_label.text = WorldStepManager.WorldStep.keys()[step_manager.current_step]
	clear_main_content()
	update_step_content()

func clear_main_content() -> void:
	for child in main_content.get_children():
		child.queue_free()

func update_step_content() -> void:
	match step_manager.current_step:
		WorldStepManager.WorldStep.UPKEEP:
				show_upkeep_ui()
		WorldStepManager.WorldStep.SHIP_REPAIRS:
				show_repairs_ui()
		WorldStepManager.WorldStep.LOAN_CHECK:
				show_loan_ui()
		WorldStepManager.WorldStep.CREW_TASKS:
				show_crew_tasks_ui()
		WorldStepManager.WorldStep.JOB_OFFERS:
				show_job_offers_ui()
		WorldStepManager.WorldStep.EQUIPMENT:
				show_equipment_ui()
		WorldStepManager.WorldStep.RUMORS:
				show_rumors_ui()
		WorldStepManager.WorldStep.BATTLE_PREP:
				show_battle_prep_ui()

func show_upkeep_ui() -> void:
	var upkeep_panel = preload("res://Scenes/world_phase/UpkeepPanel.tscn").instantiate()
	main_content.add_child(upkeep_panel)
	upkeep_panel.set_upkeep_cost(step_manager.world_economy_manager.calculate_upkeep())
	log_event("Calculating upkeep costs...")

func show_repairs_ui() -> void:
	var repairs_panel = preload("res://Scenes/world_phase/RepairsPanel.tscn").instantiate()
	main_content.add_child(repairs_panel)
	repairs_panel.set_ship_status(step_manager.game_state.current_ship)
	log_event("Checking ship status for repairs...")

func show_loan_ui() -> void:
	var loan_panel = preload("res://Scenes/world_phase/LoanPanel.tscn").instantiate()
	main_content.add_child(loan_panel)
	loan_panel.set_loan_status(step_manager.game_state.current_ship)
	log_event("Checking loan enforcement...")

func show_crew_tasks_ui() -> void:
	var tasks_panel = preload("res://Resources/WorldPhase/CrewTasksPanel.tscn").instantiate()
	main_content.add_child(tasks_panel)
	
	# Create and initialize the task manager
	var task_manager = CrewTaskManager.new(step_manager.game_state)
	tasks_panel.initialize(step_manager.game_state.current_crew.members, task_manager)
	
	# Connect to handle task completion
	tasks_panel.task_completed.connect(_on_crew_task_completed)
	log_event("Assigning crew tasks...")

func _on_crew_task_completed(character: Character, result: Dictionary) -> void:
	if "credits" in result["rewards"]:
		step_manager.game_state.add_credits(result["rewards"]["credits"])
	
	if "experience" in result["rewards"]:
		character.gain_experience(result["rewards"]["experience"])
	
	if "story_points" in result["rewards"]:
		step_manager.game_state.add_story_points(result["rewards"]["story_points"])
	
	if "morale_loss" in result["rewards"]:
		character.decrease_morale()
	
	log_event("Task completed by " + character.name + ": " + result["outcome"])

func show_job_offers_ui() -> void:
	var jobs_panel = preload("res://Scenes/world_phase/JobOffersPanel.tscn").instantiate()
	main_content.add_child(jobs_panel)
	
	# Generate standard jobs
	var standard_jobs = job_generator.generate_jobs(3)
	step_manager.game_state.available_missions.append_array(standard_jobs)
	
	# Generate patron jobs if available
	if step_manager.game_state.has_active_patrons():
		var patron_jobs = job_generator.generate_jobs(2, JobGenerator.JobType.PATRON)
		step_manager.game_state.available_missions.append_array(patron_jobs)
	
	# Generate special missions if eligible
	if job_generator._check_red_zone_eligibility():
		var special_mission = special_mission_generator.generate_special_mission(
			SpecialMissionGenerator.MissionTier.RED_ZONE if step_manager.game_state.current_crew.has_red_zone_license 
			else SpecialMissionGenerator.MissionTier.NORMAL
		)
		if special_mission:
			step_manager.game_state.available_missions.append(special_mission)
	
	jobs_panel.populate_jobs(step_manager.game_state.available_missions)
	jobs_panel.mission_selected.connect(_on_mission_selected)
	log_event("Checking available job offers...")

func _on_mission_selected(mission: Mission) -> void:
	mission_manager.accept_mission(mission)
	log_event("Accepted mission: " + mission.title)

func show_equipment_ui() -> void:
	var equipment_panel = preload("res://Scenes/world_phase/EquipmentPanel.tscn").instantiate()
	main_content.add_child(equipment_panel)
	equipment_panel.initialize(step_manager.game_state.equipment_manager)
	log_event("Managing equipment...")

func show_rumors_ui() -> void:
	var rumors_panel = preload("res://Scenes/world_phase/RumorsPanel.tscn").instantiate()
	main_content.add_child(rumors_panel)
	rumors_panel.populate_rumors(step_manager.game_state.get_current_rumors())
	log_event("Investigating local rumors...")

func show_battle_prep_ui() -> void:
	var battle_prep_panel = preload("res://Scenes/world_phase/BattlePrepPanel.tscn").instantiate()
	main_content.add_child(battle_prep_panel)
	battle_prep_panel.initialize(step_manager.game_state)
	log_event("Preparing for battle...")

func _on_next_button_pressed() -> void:
	step_manager.process_step()

func _on_step_completed(step: int) -> void:
	if step < WorldStepManager.WorldStep.size() - 1:
		step_manager.advance_step()
		show_current_step()
	else:
		_on_phase_completed()

func _on_phase_completed() -> void:
	get_tree().get_root().get_node("GameStateManager").advance_phase()

func log_event(message: String) -> void:
	event_log.append_text("\n" + message)