extends Control
class_name WorldPhaseSummary

## World Phase Summary - Displays recap before battle
## Shows all world phase results and mission briefing

# UI Components
@onready var turn_label: Label = %TurnLabel
@onready var upkeep_section: Label = %UpkeepSection
@onready var crew_tasks_section: Label = %CrewTasksSection
@onready var job_section: Label = %JobSection
@onready var equipment_section: Label = %EquipmentSection
@onready var rumors_section: Label = %RumorsSection
@onready var purchases_section: Label = %PurchasesSection
@onready var events_section: Label = %EventsSection
@onready var mission_objective_label: Label = %MissionObjectiveLabel
@onready var mission_enemy_label: Label = %MissionEnemyLabel
@onready var mission_pay_label: Label = %MissionPayLabel
@onready var mission_danger_label: Label = %MissionDangerLabel
@onready var mission_conditions_label: Label = %MissionConditionsLabel
@onready var proceed_button: Button = %ProceedButton
@onready var back_button: Button = %BackButton

# Data
var world_phase_results: Dictionary = {}
var current_mission: Dictionary = {}

func _ready() -> void:

	_connect_signals()
	_load_data_from_gamestate()
	_populate_summary()
	_populate_mission_briefing()

func _connect_signals() -> void:
	if proceed_button:
		proceed_button.pressed.connect(_on_proceed_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _load_data_from_gamestate() -> void:
	## Load world phase results from GameState
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		push_warning("WorldPhaseSummary: No GameState or campaign found")
		return

	var campaign = game_state.current_campaign

	# Load world phase results
	if "world_phase_results" in campaign:
		world_phase_results = campaign.world_phase_results

	# Load current mission
	if "current_mission" in campaign:
		current_mission = campaign.current_mission

func _populate_summary() -> void:
	## Populate all summary sections with world phase data

	# Turn number
	var game_state = get_node_or_null("/root/GameState")
	var turn_num = 1
	if game_state and game_state.current_campaign:
		turn_num = game_state.current_campaign.get("turn_number", 1)
	if turn_label:
		turn_label.text = "World Phase Complete - Turn %d" % turn_num

	# Upkeep results
	if upkeep_section:
		var upkeep = world_phase_results.get("upkeep_results", {})
		var credits_paid = upkeep.get("credits_paid", 0)
		var repairs = upkeep.get("repairs_paid", 0)
		var medical = upkeep.get("medical_paid", 0)
		upkeep_section.text = "Upkeep: Paid %d credits" % credits_paid
		if repairs > 0:
			upkeep_section.text += ", %d repairs" % repairs
		if medical > 0:
			upkeep_section.text += ", %d medical" % medical

	# Crew tasks
	if crew_tasks_section:
		var tasks = world_phase_results.get("crew_task_results", [])
		if tasks.is_empty():
			crew_tasks_section.text = "Crew Tasks: None assigned"
		else:
			var task_list = []
			for task in tasks:
				if task is Dictionary:
					task_list.append(task.get("task_name", "Unknown task"))
			crew_tasks_section.text = "Crew Tasks: %s" % ", ".join(task_list) if task_list else "Crew Tasks: %d assigned" % tasks.size()

	# Job accepted
	if job_section:
		var job = world_phase_results.get("job_results", {})
		if job.is_empty():
			job_section.text = "Job: None accepted"
		else:
			var patron = job.get("patron_name", job.get("patron", "Unknown"))
			var objective = job.get("objective", "mission")
			var pay = job.get("danger_pay", job.get("pay", 0))
			job_section.text = "Job: %s from %s (+%d cr)" % [objective, patron, pay]

	# Equipment changes
	if equipment_section:
		var equip = world_phase_results.get("equipment_results", {})
		if equip.is_empty():
			equipment_section.text = "Equipment: No changes"
		else:
			equipment_section.text = "Equipment: Assignments updated"

	# Rumors
	if rumors_section:
		var rumors = world_phase_results.get("rumors_results", {})
		var quest_generated = rumors.get("quest_generated", false)
		if quest_generated:
			rumors_section.text = "Rumors: Quest generated!"
		else:
			rumors_section.text = "Rumors: No quest this turn"

	# Purchases
	if purchases_section:
		var purchases = world_phase_results.get("purchase_results", {})
		var items = purchases.get("items_purchased", [])
		if items.is_empty():
			purchases_section.text = "Purchases: None"
		else:
			purchases_section.text = "Purchases: %d items bought" % items.size()

	# Events
	if events_section:
		var campaign_event = world_phase_results.get("campaign_event_results", {})
		var character_event = world_phase_results.get("character_event_results", {})
		var event_texts = []

		if not campaign_event.is_empty():
			event_texts.append(campaign_event.get("name", "Campaign event"))
		if not character_event.is_empty():
			event_texts.append(character_event.get("name", "Character event"))

		if event_texts.is_empty():
			events_section.text = "Events: None occurred"
		else:
			events_section.text = "Events: %s" % ", ".join(event_texts)

func _populate_mission_briefing() -> void:
	## Populate mission briefing panel with current mission data

	if current_mission.is_empty():
		if mission_objective_label:
			mission_objective_label.text = "Objective: No mission selected"
		return

	if mission_objective_label:
		var objective = current_mission.get("objective", "Unknown")
		mission_objective_label.text = "Objective: %s" % objective.capitalize()

	if mission_enemy_label:
		var enemy = current_mission.get("enemy_type", "Unknown Hostiles")
		mission_enemy_label.text = "Enemy: %s" % enemy

	if mission_pay_label:
		var pay = current_mission.get("pay", 0)
		mission_pay_label.text = "Pay: %d credits" % pay

	if mission_danger_label:
		var danger = current_mission.get("danger_level", 1)
		var danger_text = ["Low", "Medium", "High", "Very High", "Extreme"]
		var danger_index = clampi(danger - 1, 0, 4)
		mission_danger_label.text = "Danger: %s (%d)" % [danger_text[danger_index], danger]

	if mission_conditions_label:
		var conditions = []
		var deployment = current_mission.get("deployment_condition", "")
		var sights = current_mission.get("notable_sights", "")

		if deployment and deployment != "":
			conditions.append(deployment)
		if sights and sights != "":
			conditions.append(sights)

		if conditions.is_empty():
			mission_conditions_label.text = "Conditions: Standard"
		else:
			mission_conditions_label.text = "Conditions: %s" % ", ".join(conditions)

func _on_back_pressed() -> void:
	## Navigate back to previous screen
	SceneRouter.navigate_back()

func _on_proceed_pressed() -> void:
	## Transition to PreBattle scene
	SceneRouter.call_deferred("navigate_to", "pre_battle")
